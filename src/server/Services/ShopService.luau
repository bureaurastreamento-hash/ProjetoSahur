--!strict
--[[
	ShopService
	Loja: Developer Products (moedas) e Game Passes (perks), catálogo em ShopConfig.
	  RequestShop("product"|"pass", key) -> MarketplaceService:Prompt...Purchase
	  ProcessReceipt (produto)            -> DataService.RewardCoins (sem multiplicador) + save
	  PromptGamePassPurchaseFinished      -> aplica o perk na hora
	Ao entrar: UserOwnsGamePassAsync para cada passe -> atributo Pass_<key> = true no Player.
	Perks:
	  double_coins   -> Player attr CoinMultiplier = 2 (DataService.RewardCoins lê)
	  all_characters -> DataService.GrantCharacter para todos os personagens
	  vip            -> Player attr XpMultiplier = 1.25 (ProgressionService lê) + tag VIP
	NotifyShop("purchased"|"denied"|"owned", data) para o dono.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local ShopConfig = require(Modules:WaitForChild("ShopConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local ShopService = {}

--- (player, product) -> entregou? Preenchido por CosmeticsService (giros / pick).
ShopService.CosmeticHook = nil :: ((Player, any) -> boolean)?

local shopLimiter = RateLimiter.new(3, 1)
local notifyShop: RemoteEvent
local pending: { [Player]: { [string]: boolean } } = {} -- prompts abertos por jogador

local function passAttr(key: string): string
	return "Pass_" .. key
end

local function applyPerk(player: Player, key: string)
	player:SetAttribute(passAttr(key), true)
	if key == "double_coins" then
		player:SetAttribute("CoinMultiplier", ShopConfig.DoubleCoinsMultiplier)
	elseif key == "vip" then
		player:SetAttribute("XpMultiplier", ShopConfig.VipXpMultiplier)
		player:SetAttribute("NameTag", "VIP")
	elseif key == "private_plus" then
		-- só vale dentro de um servidor privado (VIP server) — em público não muda nada
		if game.PrivateServerId ~= "" then
			player:SetAttribute("DevNoCooldown", true) -- AbilityService/MovementService/CombatService leem
		end
	elseif key == "all_characters" then
		for _, id in CharacterDefs.Order do
			local def = CharacterDefs.Get(id)
			if def and CharacterDefs.AccessOf(def) ~= "early" then
				DataService.GrantCharacter(player, id) -- moedas e VIP; acesso antecipado continua fechado
			end
		end
	end
end

--- Reaplica perks de passes quando o perfil carrega (all_characters precisa do perfil).
local function refreshOwnership(player: Player)
	for _, pass in ShopConfig.Passes do
		if player:GetAttribute("IsDeveloper") == true then
			applyPerk(player, pass.key) -- dono/admin tem tudo (testar VIP, cosméticos, personagens)
			continue
		end
		if pass.gamepassId <= 0 then
			continue
		end
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.gamepassId)
		end)
		if ok and owns then
			applyPerk(player, pass.key)
		elseif not ok then
			warn(("[ShopService] UserOwnsGamePassAsync falhou para %s/%s: %s"):format(player.Name, pass.key, tostring(owns)))
		end
	end
end

function ShopService.OwnsPass(player: Player, key: string): boolean
	return player:GetAttribute(passAttr(key)) == true
end

-- ---------------------------------------------------------------------------
-- Compra
-- ---------------------------------------------------------------------------

local function onRequestShop(player: Player, kind: any, key: any)
	if not shopLimiter:Allow(player) or typeof(kind) ~= "string" or typeof(key) ~= "string" then
		return
	end
	local p = pending[player]
	if p and p[key] then
		return
	end
	if kind == "product" then
		local product = ShopConfig.GetProduct(key)
		if not product or product.productId <= 0 then
			notifyShop:FireClient(player, "denied", { key = key, reason = "unavailable" })
			return
		end
		pending[player] = pending[player] or {}
		pending[player][key] = true
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, product.productId)
		end)
		if not ok then
			warn(("[ShopService] PromptProductPurchase falhou: %s"):format(tostring(err)))
			pending[player][key] = nil
		end
	elseif kind == "pass" then
		local pass = ShopConfig.GetPass(key)
		if not pass or pass.gamepassId <= 0 then
			notifyShop:FireClient(player, "denied", { key = key, reason = "unavailable" })
			return
		end
		if ShopService.OwnsPass(player, key) then
			notifyShop:FireClient(player, "owned", { key = key })
			return
		end
		pending[player] = pending[player] or {}
		pending[player][key] = true
		local ok, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, pass.gamepassId)
		end)
		if not ok then
			warn(("[ShopService] PromptGamePassPurchase falhou: %s"):format(tostring(err)))
			pending[player][key] = nil
		end
	end
end

local function productByAssetId(productId: number): ShopConfig.Product?
	for _, p in ShopConfig.Products do
		if p.productId == productId then
			return p
		end
	end
	return nil
end

local function passByAssetId(gamepassId: number): ShopConfig.Pass?
	for _, p in ShopConfig.Passes do
		if p.gamepassId == gamepassId then
			return p
		end
	end
	return nil
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local product = productByAssetId(receipt.ProductId)
	if not player or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- tenta de novo quando o jogador voltar
	end
	if not DataService.GetProfile(player) or DataService.IsSessionOnly(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- sem DataStore não dá para garantir a entrega
	end
	if product.coins > 0 then
		DataService.AddCoins(player, product.coins) -- compra: sem multiplicador
	end
	if product.rolls or product.pick then
		-- giros / cosmético à escolha: CosmeticsService entrega (registrado no Start)
		local hook = ShopService.CosmeticHook
		if not hook or not hook(player, product) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
	if pending[player] then
		pending[player][product.key] = nil
	end
	local saved = DataService.SaveNow(player, "purchase")
	if not saved then
		warn(("[ShopService] compra de %s por %s não salvou; Roblox vai reenviar o recibo"):format(product.key, player.Name))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Log.debug(("[ShopService] %s comprou %s"):format(player.Name, product.key))
	notifyShop:FireClient(player, "purchased", { key = product.key, coins = product.coins })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function ShopService.Init()
	notifyShop = Remotes.GetEvent(Remotes.Events.NotifyShop)
	MarketplaceService.ProcessReceipt = processReceipt
end

function ShopService.Start()
	Remotes.GetEvent(Remotes.Events.RequestShop).OnServerEvent:Connect(onRequestShop)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamepassId: number, purchased: boolean)
		local pass = passByAssetId(gamepassId)
		if not pass then
			return
		end
		if pending[player] then
			pending[player][pass.key] = nil
		end
		if purchased then
			applyPerk(player, pass.key)
			Log.debug(("[ShopService] %s comprou o passe %s"):format(player.Name, pass.key))
			notifyShop:FireClient(player, "purchased", { key = pass.key })
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, purchased: boolean)
		local player = Players:GetPlayerByUserId(userId)
		local product = productByAssetId(productId)
		if player and product and not purchased and pending[player] then
			pending[player][product.key] = nil
		end
	end)

	DataService.ProfileLoaded.Event:Connect(function(player: Player)
		task.spawn(refreshOwnership, player)
	end)
	Players.PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("IsDeveloper"):Connect(function()
			task.spawn(refreshOwnership, player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)

	local active = 0
	for _, p in ShopConfig.Products do
		if p.productId > 0 then
			active += 1
		end
	end
	for _, p in ShopConfig.Passes do
		if p.gamepassId > 0 then
			active += 1
		end
	end
	Log.debug(("[ShopService] pronto (%d item(ns) com id configurado)"):format(active))
end

return ShopService
