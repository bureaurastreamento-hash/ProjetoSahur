--!strict
--[[
	TradeService (servidor)
	Trocas entre jogadores no VENDEDOR (TradeConfig). Fluxo:
	  RequestTrade("invite", userId)  -> quem propõe está perto do vendedor -> alvo recebe NotifyTrade("invite")
	  RequestTrade("accept"|"decline") -> aceitar exige o alvo perto do vendedor -> "start" para os dois
	  RequestTrade("add"|"remove", kind, id) / ("points"|"event_points", n) -> muda a oferta; zera os
	    "pronto" dos dois; "state" para os dois com as duas ofertas
	  RequestTrade("ready", bool) -> os dois prontos = readyAt; "confirm" só vale ConfirmDelay depois
	  RequestTrade("confirm")     -> os dois confirmados -> revalida TUDO (posse, saldo, o outro não tem)
	    -> transfere (CosmeticsService.Remove/Grant, personagens, pontos) -> SaveNow nos dois -> "end"
	  RequestTrade("cancel")      -> "end" (cancelled) para os dois
	Sair do servidor cancela. Perfil sem DataStore (sessionOnly) não troca: sem garantia de salvar.
	Nada é entregue antes da revalidação final; se alguém perdeu o item no meio, a troca falha inteira.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local TradeConfig = require(Modules:WaitForChild("TradeConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local CosmeticsService = require(script.Parent:WaitForChild("CosmeticsService"))
local ShopNpcService = require(script.Parent:WaitForChild("ShopNpcService"))

local TradeService = {}

type Offer = { items: { TradeConfig.Item }, points: number, eventPoints: number }
type Trade = {
	a: Player,
	b: Player,
	offers: { [Player]: Offer },
	ready: { [Player]: boolean },
	confirmed: { [Player]: boolean },
	readyAt: number, -- os.clock() em que os dois ficaram prontos (0 = não)
	closed: boolean,
}
type Invite = { from: Player, target: Player }

local limiter = RateLimiter.new(8, 1)
local notifyTrade: RemoteEvent
local trades: { [Player]: Trade } = {}
local invitesByTarget: { [Player]: Invite } = {}
local invitesByFrom: { [Player]: Invite } = {}
local forceCharacter: ((Player, string) -> ())? = nil

local function notify(player: Player, event: string, data: any)
	notifyTrade:FireClient(player, event, data)
end

local function deny(player: Player, reason: string)
	notify(player, "denied", { reason = reason })
end

local function nearVendor(player: Player): boolean
	return player:GetAttribute("IsDeveloper") == true or ShopNpcService.DistanceTo(player) <= TradeConfig.VendorRange
end

local function other(trade: Trade, player: Player): Player
	return if trade.a == player then trade.b else trade.a
end

local function newOffer(): Offer
	return { items = {}, points = 0, eventPoints = 0 }
end

local function serialize(offer: Offer): any
	local items = {}
	for _, it in offer.items do
		table.insert(items, { kind = it.kind, id = it.id, name = it.name })
	end
	return { items = items, points = offer.points, eventPoints = offer.eventPoints }
end

--- Manda o estado completo para os dois (cada um recebe "mine"/"theirs" do seu ponto de vista).
local function broadcast(trade: Trade)
	for _, p in { trade.a, trade.b } do
		local o = other(trade, p)
		notify(p, "state", {
			other = o.Name,
			mine = serialize(trade.offers[p]),
			theirs = serialize(trade.offers[o]),
			myReady = trade.ready[p] == true,
			theirReady = trade.ready[o] == true,
			myConfirmed = trade.confirmed[p] == true,
			theirConfirmed = trade.confirmed[o] == true,
			confirmAt = if trade.readyAt > 0 then workspace:GetServerTimeNow() + math.max(0, TradeConfig.ConfirmDelay - (os.clock() - trade.readyAt)) else 0,
		})
	end
end

local function unready(trade: Trade)
	trade.ready = {}
	trade.confirmed = {}
	trade.readyAt = 0
end

local function close(trade: Trade, reason: string, extra: any?)
	if trade.closed then
		return
	end
	trade.closed = true
	trades[trade.a] = nil
	trades[trade.b] = nil
	for _, p in { trade.a, trade.b } do
		local data = { reason = reason, other = other(trade, p).Name }
		if extra then
			for k, v in extra do
				data[k] = v
			end
		end
		notify(p, "end", data)
	end
	Log.debug(("[TradeService] troca %s/%s fechada: %s"):format(trade.a.Name, trade.b.Name, reason))
end

local function closeInvite(invite: Invite, reason: string)
	if invitesByTarget[invite.target] ~= invite then
		return
	end
	invitesByTarget[invite.target] = nil
	invitesByFrom[invite.from] = nil
	notify(invite.from, "invite_closed", { reason = reason, other = invite.target.Name })
	notify(invite.target, "invite_closed", { reason = reason, other = invite.from.Name })
end

-- ---------------------------------------------------------------------------
-- Validação
-- ---------------------------------------------------------------------------

local function hasItem(player: Player, it: TradeConfig.Item): boolean
	if it.kind == "character" then
		local profile = DataService.GetProfile(player)
		return profile ~= nil and table.find(profile.unlockedCharacters, it.id) ~= nil
	end
	return CosmeticsService.Owns(player, it.id)
end

local function receiverHas(player: Player, it: TradeConfig.Item): boolean
	if it.kind == "character" then
		return DataService.HasCharacter(player, it.id)
	end
	return CosmeticsService.Owns(player, it.id)
end

--- Confere que `player` ainda pode entregar a própria oferta e que `receiver` pode receber.
local function validOffer(player: Player, receiver: Player, offer: Offer): (boolean, string)
	local profile = DataService.GetProfile(player)
	if not profile or DataService.IsSessionOnly(player) then
		return false, "not_loaded"
	end
	if offer.points > profile.coins or offer.eventPoints > profile.eventPoints then
		return false, "coins"
	end
	local tradeable = TradeConfig.Tradeable(profile)
	for _, it in offer.items do
		local found = false
		for _, t in tradeable do
			if t.kind == it.kind and t.id == it.id then
				found = true
				break
			end
		end
		if not found or not hasItem(player, it) then
			return false, "lost_item"
		end
		if receiverHas(receiver, it) then
			return false, "other_owns"
		end
	end
	return true, "ok"
end

-- ---------------------------------------------------------------------------
-- Execução
-- ---------------------------------------------------------------------------

local function giveItem(from: Player, to: Player, it: TradeConfig.Item)
	if it.kind == "character" then
		local profile = DataService.GetProfile(from)
		if profile then
			local index = table.find(profile.unlockedCharacters, it.id)
			if index then
				table.remove(profile.unlockedCharacters, index)
				DataService.MarkDirty(from)
			end
		end
		if from:GetAttribute("CharacterId") == it.id and forceCharacter then
			forceCharacter(from, CharacterDefs.DefaultCharacter) -- perdeu o personagem em uso: volta ao inicial
		end
		DataService.GrantCharacter(to, it.id)
	else
		CosmeticsService.Remove(from, it.id)
		CosmeticsService.Grant(to, it.id, "trade")
	end
end

local function execute(trade: Trade): (boolean, string)
	local okA, reasonA = validOffer(trade.a, trade.b, trade.offers[trade.a])
	if not okA then
		return false, reasonA
	end
	local okB, reasonB = validOffer(trade.b, trade.a, trade.offers[trade.b])
	if not okB then
		return false, reasonB
	end
	for _, pair in { { trade.a, trade.b }, { trade.b, trade.a } } do
		local from, to = pair[1], pair[2]
		local offer = trade.offers[from]
		for _, it in offer.items do
			giveItem(from, to, it)
		end
		if offer.points > 0 then
			DataService.AddCoins(from, -offer.points)
			DataService.AddCoins(to, offer.points)
		end
		if offer.eventPoints > 0 then
			DataService.AddEventPoints(from, -offer.eventPoints)
			DataService.AddEventPoints(to, offer.eventPoints)
		end
	end
	-- salva os dois já; se um falhar, o autosave tenta de novo (a troca já aconteceu na memória dos dois)
	task.spawn(DataService.SaveNow, trade.a, "trade")
	task.spawn(DataService.SaveNow, trade.b, "trade")
	Log.debug(("[TradeService] troca concluída: %s <-> %s"):format(trade.a.Name, trade.b.Name))
	return true, "done"
end

-- ---------------------------------------------------------------------------
-- Pedidos
-- ---------------------------------------------------------------------------

local function invite(from: Player, userId: any)
	if trades[from] or invitesByFrom[from] then
		return deny(from, "busy")
	end
	if not nearVendor(from) then
		return deny(from, "far")
	end
	if DataService.IsSessionOnly(from) then
		return deny(from, "not_loaded")
	end
	local target = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if not target or target == from then
		return deny(from, "unknown")
	end
	if trades[target] or invitesByTarget[target] then
		return deny(from, "target_busy")
	end
	local inv: Invite = { from = from, target = target }
	invitesByTarget[target] = inv
	invitesByFrom[from] = inv
	local expiresAt = workspace:GetServerTimeNow() + TradeConfig.InviteTimeout
	notify(target, "invite", { fromName = from.Name, fromUserId = from.UserId, expiresAt = expiresAt })
	notify(from, "invite_sent", { targetName = target.Name, expiresAt = expiresAt })
	task.delay(TradeConfig.InviteTimeout, function()
		closeInvite(inv, "expired")
	end)
end

local function accept(player: Player)
	local inv = invitesByTarget[player]
	if not inv then
		return
	end
	local from = inv.from
	if not from.Parent or trades[from] then
		return closeInvite(inv, "unavailable")
	end
	if not nearVendor(player) then
		return deny(player, "far") -- convite continua de pé: vai até o vendedor e aceita
	end
	if DataService.IsSessionOnly(player) then
		closeInvite(inv, "unavailable")
		return deny(player, "not_loaded")
	end
	invitesByTarget[player] = nil
	invitesByFrom[from] = nil
	local trade: Trade = {
		a = from,
		b = player,
		offers = { [from] = newOffer(), [player] = newOffer() },
		ready = {},
		confirmed = {},
		readyAt = 0,
		closed = false,
	}
	trades[from] = trade
	trades[player] = trade
	notify(from, "start", { other = player.Name })
	notify(player, "start", { other = from.Name })
	broadcast(trade)
end

local function changeOffer(player: Player, trade: Trade, action: string, a: any, b: any)
	local offer = trade.offers[player]
	if action == "add" or action == "remove" then
		if typeof(a) ~= "string" or typeof(b) ~= "string" then
			return
		end
		local idx = nil
		for i, it in offer.items do
			if it.kind == a and it.id == b then
				idx = i
				break
			end
		end
		if action == "remove" then
			if idx then
				table.remove(offer.items, idx)
			end
		else
			if idx then
				return
			end
			if #offer.items >= TradeConfig.MaxItemsPerSide then
				return deny(player, "full")
			end
			local it: TradeConfig.Item = { kind = a, id = b, name = TradeConfig.NameOf(a, b) }
			if not hasItem(player, it) then
				return deny(player, "lost_item")
			end
			local profile = DataService.GetProfile(player)
			local allowed = false
			for _, t in TradeConfig.Tradeable(profile) do
				if t.kind == a and t.id == b then
					allowed = true
					break
				end
			end
			if not allowed then
				return deny(player, "not_tradeable")
			end
			if receiverHas(other(trade, player), it) then
				return deny(player, "other_owns")
			end
			table.insert(offer.items, it)
		end
	elseif action == "points" or action == "event_points" then
		local n = if typeof(a) == "number" then math.floor(a) else nil
		if not n or n < 0 or n ~= n or n > TradeConfig.MaxPoints then
			return
		end
		local profile = DataService.GetProfile(player)
		if not profile then
			return
		end
		if action == "points" then
			offer.points = math.min(n, profile.coins)
		else
			offer.eventPoints = math.min(n, profile.eventPoints)
		end
	end
	unready(trade)
	broadcast(trade)
end

local function onRequest(player: Player, action: any, a: any, b: any)
	if not limiter:Allow(player) or typeof(action) ~= "string" then
		return
	end
	if action == "invite" then
		return invite(player, a)
	elseif action == "accept" then
		return accept(player)
	elseif action == "decline" then
		local inv = invitesByTarget[player]
		if inv then
			closeInvite(inv, "declined")
		end
		return
	end
	local trade = trades[player]
	if not trade then
		if action == "cancel" then
			local inv = invitesByFrom[player]
			if inv then
				closeInvite(inv, "cancelled")
			end
		end
		return
	end
	if action == "cancel" then
		close(trade, "cancelled", { by = player.Name })
	elseif action == "add" or action == "remove" or action == "points" or action == "event_points" then
		changeOffer(player, trade, action, a, b)
	elseif action == "ready" then
		local on = a == true
		if trade.ready[player] == on then
			return
		end
		trade.ready[player] = on
		trade.confirmed = {}
		if trade.ready[trade.a] and trade.ready[trade.b] then
			trade.readyAt = os.clock()
		else
			trade.readyAt = 0
		end
		broadcast(trade)
	elseif action == "confirm" then
		if trade.readyAt <= 0 or os.clock() - trade.readyAt < TradeConfig.ConfirmDelay then
			return deny(player, "not_ready")
		end
		trade.confirmed[player] = true
		if trade.confirmed[trade.a] and trade.confirmed[trade.b] then
			local ok, reason = execute(trade)
			if ok then
				close(trade, "done")
			else
				-- alguém perdeu algo no meio: volta para a mesa com o motivo, sem entregar nada
				unready(trade)
				notify(trade.a, "denied", { reason = reason })
				notify(trade.b, "denied", { reason = reason })
				broadcast(trade)
			end
		else
			broadcast(trade)
		end
	end
end

function TradeService.Init()
	notifyTrade = Remotes.GetEvent(Remotes.Events.NotifyTrade)
end

function TradeService.Start()
	local ok, AdminService = pcall(require, script.Parent:WaitForChild("AdminService"))
	if ok then
		forceCharacter = function(player: Player, id: string)
			(AdminService :: any).ForceCharacter(player, id)
		end
	end
	Remotes.GetEvent(Remotes.Events.RequestTrade).OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
		local trade = trades[player]
		if trade then
			close(trade, "left", { by = player.Name })
		end
		local inv = invitesByTarget[player] or invitesByFrom[player]
		if inv then
			closeInvite(inv, "unavailable")
		end
	end)
	Log.debug("[TradeService] pronto")
end

return TradeService
