--!strict
--[[
	VendorService (servidor)
	Compras no VENDEDOR da Lojinha (VendorConfig): tudo que custa PONTOS ou PONTOS DE EVENTO.
	  RequestVendor("buy", id, "points"|"event") -> valida (perto do vendedor, perfil salvo, não tem,
	    saldo) -> cobra -> entrega (CosmeticsService.Grant / DataService.UnlockCharacter)
	  RequestVendor("roll")                     -> CosmeticsService.RollWithPoints (1 giro por pontos)
	NotifyVendor("bought"|"denied", data) para quem pediu. A Loja do menu (L) fica só com Robux.
	Tudo é só visual/coleção: nada aqui dá vantagem em combate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local VendorConfig = require(Modules:WaitForChild("VendorConfig"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local CosmeticsService = require(script.Parent:WaitForChild("CosmeticsService"))
local ShopNpcService = require(script.Parent:WaitForChild("ShopNpcService"))

local VendorService = {}

local limiter = RateLimiter.new(4, 1)
local notifyVendor: RemoteEvent

local function deny(player: Player, reason: string, id: string?)
	notifyVendor:FireClient(player, "denied", { reason = reason, id = id or "" })
end

--- Perto o bastante do NPC para comprar (com folga sobre o alcance do prompt; dev testa de longe).
local function nearVendor(player: Player): boolean
	if player:GetAttribute("IsDeveloper") == true then
		return true
	end
	return ShopNpcService.DistanceTo(player) <= VendorConfig.Range + 6
end

local function buy(player: Player, id: string, currency: string)
	local entry = VendorConfig.Get(id)
	if not entry or entry.kind == "roll" then
		return deny(player, "unknown", id)
	end
	local profile = DataService.GetProfile(player)
	if not profile or DataService.IsSessionOnly(player) then
		return deny(player, "not_loaded", id)
	end
	local price = if currency == "event" then entry.eventPrice else entry.price
	if not price then
		return deny(player, "unavailable", id)
	end
	if entry.kind == "character" then
		if DataService.HasCharacter(player, id) then
			return deny(player, "already_owned", id)
		end
		if currency ~= "points" then
			return deny(player, "unavailable", id)
		end
		local ok, reason = DataService.UnlockCharacter(player, id) -- cobra o UnlockCost e desbloqueia
		if not ok then
			return deny(player, reason, id)
		end
	else
		if CosmeticsService.Owns(player, id) then
			return deny(player, "already_owned", id)
		end
		if currency == "event" then
			if profile.eventPoints < price then
				return deny(player, "event_points", id)
			end
			DataService.AddEventPoints(player, -price)
		else
			if profile.coins < price then
				return deny(player, "coins", id)
			end
			DataService.AddCoins(player, -price)
		end
		if not CosmeticsService.Grant(player, id, "vendor") then
			-- não deveria acontecer (checamos a posse acima): devolve o que cobrou
			if currency == "event" then
				DataService.AddEventPoints(player, price)
			else
				DataService.AddCoins(player, price)
			end
			return deny(player, "already_owned", id)
		end
	end
	Log.debug(("[VendorService] %s comprou %s por %d %s"):format(player.Name, id, price, currency))
	notifyVendor:FireClient(player, "bought", { id = id, name = entry.name, kind = entry.kind, price = price, currency = currency })
end

local function onRequest(player: Player, action: any, id: any, currency: any)
	if not limiter:Allow(player) or typeof(action) ~= "string" then
		return
	end
	if not nearVendor(player) then
		return deny(player, "far")
	end
	if action == "roll" then
		local ok, reason = CosmeticsService.RollWithPoints(player)
		if not ok then
			deny(player, reason, "roll")
		end
	elseif action == "buy" and typeof(id) == "string" then
		buy(player, id, if currency == "event" then "event" else "points")
	end
end

function VendorService.Init()
	notifyVendor = Remotes.GetEvent(Remotes.Events.NotifyVendor)
end

function VendorService.Start()
	Remotes.GetEvent(Remotes.Events.RequestVendor).OnServerEvent:Connect(onRequest)
	Log.debug(("[VendorService] pronto (%d item(ns) no catálogo)"):format(#VendorConfig.Catalog()))
end

return VendorService
