--!strict
--[[
	ClanService (servidor)
	Clãs: criar (custa pontos), convidar (só online, mesmo servidor), entrar/sair, cargos
	(líder > oficial > membro), expulsar, cofre de pontos, dissolver. Base da guerra de clã/dominação.

	Persistência: DataStore "Clans_v1", uma chave por clã ("clan_<TAG>"; a TAG é o id único). Toda
	mutação passa por UpdateAsync (vários servidores podem mexer no mesmo clã). O perfil guarda só
	`clanTag` como cache: ao entrar, o registro é lido e, se o jogador não estiver mais nele (expulso em
	outro servidor / clã dissolvido), o cache é limpo.

	Cliente: RequestClan(action, a, b) -> NotifyClan("state"|"invite"|"denied"|"info", data).
	Atributo Player.ClanTag (tag ou "") -> CharacterService.DisplayNameFor põe "[TAG]" no nome.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local ClanConfig = require(Modules:WaitForChild("ClanConfig"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))

type Clan = ClanConfig.Clan

local ClanService = {}

local STORE_NAME = "Clans_v1"
local ATTR_TAG = "ClanTag"

local store: DataStore? = nil
local storeFailed = false
local cache: { [string]: Clan } = {} -- tag -> último registro visto (deste servidor)
local myTag: { [Player]: string? } = {}
local invites: { [Player]: { tag: string, from: string, expiresAt: number } } = {}
local requestLimiter = RateLimiter.new(6, 2)
local notifyClan: RemoteEvent

-- ---------------------------------------------------------------------------
-- DataStore
-- ---------------------------------------------------------------------------

local function getStore(): DataStore?
	if store or storeFailed then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		storeFailed = true
		warn("[ClanService] sem DataStore: " .. tostring(result))
	end
	return store
end

local function keyFor(tag: string): string
	return "clan_" .. tag
end

local function fetch(tag: string): Clan?
	local s = getStore()
	if not s then
		return cache[tag]
	end
	local ok, result = pcall(s.GetAsync, s, keyFor(tag))
	if not ok then
		warn(("[ClanService] GetAsync %s: %s"):format(tag, tostring(result)))
		return cache[tag]
	end
	if typeof(result) == "table" then
		cache[tag] = result :: Clan
		return result :: Clan
	end
	cache[tag] = nil
	return nil
end

--- Mutação atômica: `fn` recebe o registro atual (nil = não existe) e devolve o novo (nil = cancela).
--- Retorna (ok, registro final | mensagem de erro).
local function update(tag: string, fn: (Clan?) -> Clan?): (boolean, any)
	local s = getStore()
	if not s then
		return false, "clãs indisponíveis agora (DataStore)"
	end
	local cancelled = false
	local final: any = nil
	local ok, err = pcall(s.UpdateAsync, s, keyFor(tag), function(old: any): any
		local current: Clan? = if typeof(old) == "table" then old :: Clan else nil
		local new = fn(current)
		if new == nil then
			cancelled = true
			return nil -- nil = não escreve
		end
		final = new
		return new
	end)
	if not ok then
		warn(("[ClanService] UpdateAsync %s: %s"):format(tag, tostring(err)))
		return false, "falha ao salvar o clã; tente de novo"
	end
	if cancelled then
		return false, "cancelado"
	end
	cache[tag] = final :: Clan
	return true, final
end

local function remove(tag: string): boolean
	local s = getStore()
	if not s then
		return false
	end
	local ok, err = pcall(s.RemoveAsync, s, keyFor(tag))
	if not ok then
		warn(("[ClanService] RemoveAsync %s: %s"):format(tag, tostring(err)))
		return false
	end
	cache[tag] = nil
	return true
end

-- ---------------------------------------------------------------------------
-- Estado por jogador
-- ---------------------------------------------------------------------------

local function memberOf(clan: Clan?, player: Player): ClanConfig.Member?
	return if clan then clan.members[tostring(player.UserId)] else nil
end

local function setTag(player: Player, tag: string?)
	myTag[player] = tag
	local profile = DataService.GetProfile(player)
	if profile and profile.clanTag ~= tag then
		profile.clanTag = tag
		DataService.MarkDirty(player)
	end
	player:SetAttribute(ATTR_TAG, tag or "")
	CharacterService.RefreshDisplayName(player)
end

local function pushState(player: Player, clan: Clan?)
	if player.Parent ~= Players then
		return
	end
	local me = memberOf(clan, player)
	notifyClan:FireClient(player, "state", { clan = clan, role = if me then me.role else nil })
end

local function deny(player: Player, reason: string)
	notifyClan:FireClient(player, "denied", { reason = reason })
end

local function info(player: Player, message: string)
	notifyClan:FireClient(player, "info", { message = message })
end

--- Reenvia o estado para todos os membros online (deste servidor) do clã.
local function pushClan(tag: string, clan: Clan?)
	for _, other in Players:GetPlayers() do
		if myTag[other] == tag then
			if clan and memberOf(clan, other) then
				pushState(other, clan)
			else
				setTag(other, nil) -- expulso/dissolvido
				pushState(other, nil)
			end
		end
	end
end

--- Clã atual do jogador (lê o registro; nil se não tem ou saiu).
local function currentClan(player: Player): Clan?
	local tag = myTag[player]
	if not tag then
		return nil
	end
	local clan = fetch(tag)
	if not clan or not memberOf(clan, player) then
		setTag(player, nil)
		return nil
	end
	return clan
end

-- ---------------------------------------------------------------------------
-- Ações
-- ---------------------------------------------------------------------------

local actions: { [string]: (Player, any, any) -> () } = {}

actions.refresh = function(player)
	pushState(player, currentClan(player))
end

actions.create = function(player, rawName, rawTag)
	if DataService.IsSessionOnly(player) then
		return deny(player, "perfil temporário: não dá para fundar clã agora")
	end
	if myTag[player] then
		return deny(player, "você já está em um clã")
	end
	local name, nameErr = ClanConfig.NormalizeName(rawName)
	if not name then
		return deny(player, nameErr :: string)
	end
	local tag, tagErr = ClanConfig.NormalizeTag(rawTag)
	if not tag then
		return deny(player, tagErr :: string)
	end
	local profile = DataService.GetProfile(player)
	if not profile or profile.coins < ClanConfig.CreateCost then
		return deny(player, ("fundar um clã custa %d pontos"):format(ClanConfig.CreateCost))
	end
	local ok, result = update(tag, function(existing)
		if existing then
			return nil -- tag já usada
		end
		return {
			tag = tag,
			name = name,
			leader = player.UserId,
			members = { [tostring(player.UserId)] = { name = player.Name, role = "leader", joinedAt = os.time() } },
			vault = 0,
			wins = 0,
			createdAt = os.time(),
		} :: Clan
	end)
	if not ok then
		return deny(player, if result == "cancelado" then ("a tag %s já existe"):format(tag) else tostring(result))
	end
	DataService.AddCoins(player, -ClanConfig.CreateCost)
	setTag(player, tag)
	DataService.SaveNow(player, "clan_create")
	Log.debug(("[ClanService] %s fundou %s [%s]"):format(player.Name, name, tag))
	info(player, ("Clã %s [%s] fundado!"):format(name, tag))
	pushState(player, result :: Clan)
end

actions.invite = function(player, rawUserId)
	local clan = currentClan(player)
	local me = memberOf(clan, player)
	if not clan or not me then
		return deny(player, "você não está em um clã")
	end
	if ClanConfig.RoleRank(me.role) < ClanConfig.RoleRank("officer") then
		return deny(player, "só líder e oficiais convidam")
	end
	if ClanConfig.MemberCount(clan) >= ClanConfig.MaxMembers then
		return deny(player, "o clã está cheio")
	end
	local target = Players:GetPlayerByUserId(tonumber(rawUserId) or 0)
	if not target or target == player then
		return deny(player, "jogador não está no servidor")
	end
	if myTag[target] then
		return deny(player, target.Name .. " já tem clã")
	end
	local pending = invites[target]
	if pending and os.clock() < pending.expiresAt then
		return deny(player, target.Name .. " já tem um convite aberto")
	end
	invites[target] = { tag = clan.tag, from = player.Name, expiresAt = os.clock() + ClanConfig.InviteSeconds }
	notifyClan:FireClient(target, "invite", { tag = clan.tag, name = clan.name, from = player.Name, seconds = ClanConfig.InviteSeconds })
	info(player, "Convite enviado para " .. target.Name)
end

actions.accept = function(player)
	local inv = invites[player]
	invites[player] = nil
	if not inv or os.clock() >= inv.expiresAt then
		return deny(player, "o convite expirou")
	end
	if myTag[player] then
		return deny(player, "você já está em um clã")
	end
	if DataService.IsSessionOnly(player) then
		return deny(player, "perfil temporário: não dá para entrar em clã agora")
	end
	local ok, result = update(inv.tag, function(clan)
		if not clan or ClanConfig.MemberCount(clan) >= ClanConfig.MaxMembers then
			return nil
		end
		clan.members[tostring(player.UserId)] = { name = player.Name, role = "member", joinedAt = os.time() }
		return clan
	end)
	if not ok then
		return deny(player, if result == "cancelado" then "o clã não existe mais ou está cheio" else tostring(result))
	end
	setTag(player, inv.tag)
	info(player, ("Você entrou em %s [%s]"):format((result :: Clan).name, inv.tag))
	pushClan(inv.tag, result :: Clan)
end

actions.decline = function(player)
	invites[player] = nil
end

actions.leave = function(player)
	local clan = currentClan(player)
	if not clan then
		return deny(player, "você não está em um clã")
	end
	if clan.leader == player.UserId then
		return deny(player, "o líder não sai: passe a liderança (promover) ou dissolva o clã")
	end
	local tag = clan.tag
	local ok, result = update(tag, function(c)
		if not c then
			return nil
		end
		c.members[tostring(player.UserId)] = nil
		return c
	end)
	setTag(player, nil)
	pushState(player, nil)
	if ok then
		pushClan(tag, result :: Clan)
	end
	info(player, "Você saiu do clã")
end

--- Mudança de cargo/expulsão feita por quem manda (líder ou oficial sobre membros).
local function manage(player: Player, rawUserId: any, what: "kick" | "promote" | "demote")
	local clan = currentClan(player)
	local me = memberOf(clan, player)
	if not clan or not me then
		return deny(player, "você não está em um clã")
	end
	local targetId = tostring(tonumber(rawUserId) or 0)
	local target = clan.members[targetId]
	if not target or targetId == tostring(player.UserId) then
		return deny(player, "membro inválido")
	end
	local myRank, theirRank = ClanConfig.RoleRank(me.role), ClanConfig.RoleRank(target.role)
	if what == "promote" then
		-- líder promove membro→oficial e oficial→líder (passa a liderança)
		if me.role ~= "leader" then
			return deny(player, "só o líder promove")
		end
	elseif myRank <= theirRank or myRank < ClanConfig.RoleRank("officer") then
		return deny(player, "sem permissão sobre esse membro")
	end
	local ok, result = update(clan.tag, function(c)
		if not c then
			return nil
		end
		local m = c.members[targetId]
		if not m then
			return nil
		end
		if what == "kick" then
			c.members[targetId] = nil
		elseif what == "promote" then
			if m.role == "member" then
				m.role = "officer"
			elseif m.role == "officer" then
				m.role = "leader"
				c.leader = tonumber(targetId) :: number
				local mine = c.members[tostring(player.UserId)]
				if mine then
					mine.role = "officer"
				end
			end
		elseif what == "demote" then
			if m.role == "officer" then
				m.role = "member"
			end
		end
		return c
	end)
	if not ok then
		return deny(player, tostring(result))
	end
	local victim = Players:GetPlayerByUserId(tonumber(targetId) :: number)
	if what == "kick" and victim then
		setTag(victim, nil)
		pushState(victim, nil)
		info(victim, "Você foi expulso do clã")
	end
	pushClan(clan.tag, result :: Clan)
end

actions.kick = function(player, userId)
	manage(player, userId, "kick")
end
actions.promote = function(player, userId)
	manage(player, userId, "promote")
end
actions.demote = function(player, userId)
	manage(player, userId, "demote")
end

actions.deposit = function(player, rawAmount)
	local clan = currentClan(player)
	if not clan then
		return deny(player, "você não está em um clã")
	end
	local amount = math.floor(tonumber(rawAmount) or 0)
	if amount < ClanConfig.DepositMin then
		return deny(player, ("depósito mínimo: %d pontos"):format(ClanConfig.DepositMin))
	end
	local profile = DataService.GetProfile(player)
	if not profile or profile.coins < amount then
		return deny(player, "pontos insuficientes")
	end
	-- debita antes (se o UpdateAsync falhar, devolve)
	DataService.AddCoins(player, -amount)
	local ok, result = update(clan.tag, function(c)
		if not c or not c.members[tostring(player.UserId)] then
			return nil
		end
		c.vault = (c.vault or 0) + amount
		return c
	end)
	if not ok then
		DataService.AddCoins(player, amount)
		return deny(player, tostring(result))
	end
	DataService.SaveNow(player, "clan_deposit")
	info(player, ("+%d pontos no cofre"):format(amount))
	pushClan(clan.tag, result :: Clan)
end

actions.disband = function(player)
	local clan = currentClan(player)
	if not clan or clan.leader ~= player.UserId then
		return deny(player, "só o líder dissolve o clã")
	end
	local tag = clan.tag
	if not remove(tag) then
		return deny(player, "falha ao dissolver; tente de novo")
	end
	Log.debug(("[ClanService] %s dissolveu [%s]"):format(player.Name, tag))
	pushClan(tag, nil)
	info(player, "Clã dissolvido")
end

-- ---------------------------------------------------------------------------
-- API para outros serviços (guerra de clã)
-- ---------------------------------------------------------------------------

function ClanService.GetTag(player: Player): string?
	return myTag[player]
end

function ClanService.GetClan(player: Player): Clan?
	return currentClan(player)
end

--- Credita pontos no cofre (recompensa de guerra). Retorna false se o clã não existe.
function ClanService.AddToVault(tag: string, amount: number): boolean
	local ok, result = update(tag, function(c)
		if not c then
			return nil
		end
		c.vault = math.max(0, (c.vault or 0) + math.floor(amount))
		return c
	end)
	if ok then
		pushClan(tag, result :: Clan)
	end
	return ok
end

--- +1 guerra vencida.
function ClanService.AddWin(tag: string): boolean
	local ok, result = update(tag, function(c)
		if not c then
			return nil
		end
		c.wins = (c.wins or 0) + 1
		return c
	end)
	if ok then
		pushClan(tag, result :: Clan)
	end
	return ok
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	-- espera o perfil carregar (DataService.load é assíncrono)
	local profile = DataService.GetProfile(player)
	local waited = 0
	while not profile and waited < 15 and player.Parent == Players do
		waited += task.wait(0.5)
		profile = DataService.GetProfile(player)
	end
	if not profile or player.Parent ~= Players then
		return
	end
	local tag = profile.clanTag
	if tag then
		myTag[player] = tag
		local clan = fetch(tag)
		if clan and memberOf(clan, player) then
			setTag(player, tag)
			pushState(player, clan)
			return
		end
		setTag(player, nil) -- expulso/dissolvido enquanto estava fora
	end
	pushState(player, nil)
end

function ClanService.Init()
	notifyClan = Remotes.GetEvent(Remotes.Events.NotifyClan)
end

function ClanService.Start()
	Remotes.GetEvent(Remotes.Events.RequestClan).OnServerEvent:Connect(function(player, action, a, b)
		if not requestLimiter:Allow(player) then
			return
		end
		local fn = if typeof(action) == "string" then actions[action] else nil
		if not fn then
			return
		end
		local ok, err = (pcall :: any)(fn, player, a, b)
		if not ok then
			warn(("[ClanService] %s/%s: %s"):format(player.Name, tostring(action), tostring(err)))
			deny(player, "erro interno; tente de novo")
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		myTag[player] = nil
		invites[player] = nil
	end)
	Log.debug("[ClanService] pronto")
end

return ClanService
