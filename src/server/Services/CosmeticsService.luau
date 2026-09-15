--!strict
--[[
	CosmeticsService (servidor)
	Roleta/equipar cosméticos (skins, capas, auras) e emotes; aplica no personagem.
	  RequestCosmetic("roll")        -> gasta RollCost pontos -> item aleatório não possuído (Weight)
	  RequestCosmetic("equip"|"unequip", id) -> perfil (DataService) -> atributos no Player
	  RequestCosmetic("pick_robux", id) -> guarda o item pendente; o cliente abre o produto "pick"
	  Robux: ShopService chama CosmeticsService.OnProduct(player, product) no recibo (giros / pick).
	    CosmeticSkin / CosmeticCape / CosmeticAura (id ou "") -> o cliente desenha capa/aura;
	    a skin placeholder (cor do corpo) é aplicada aqui via BodyColors.
	  RequestEmote(id) -> valida (comprado ou grátis, cooldown, vivo, não caído/stunado) -> NotifyEmote
	    a todos; o cliente toca a animação e, se for cena, a aura/VFX temporários.
	Nada aqui dá vantagem: só visual.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CosmeticsConfig = require(Modules:WaitForChild("CosmeticsConfig"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))

local CosmeticsService = {}

local requestLimiter = RateLimiter.new(5, 1)
local emoteLimiter = RateLimiter.new(3, 1)
local lastEmoteAt: { [Player]: number } = {}

local notifyCosmetics: RemoteEvent
local notifyEmote: RemoteEvent

local ATTR_BY_CATEGORY: { [string]: string } = { skin = "CosmeticSkin", cape = "CosmeticCape", aura = "CosmeticAura" }

local function owns(profile: any, item: CosmeticsConfig.Item, player: Player): boolean
	if item.Weight <= 0 and item.Access == nil then
		return true
	end
	if item.Access == "vip" then
		return player:GetAttribute("Pass_vip") == true or table.find(profile.cosmetics.owned, item.Id) ~= nil
	end
	return table.find(profile.cosmetics.owned, item.Id) ~= nil
end

local function ownsEmote(profile: any, emote: CosmeticsConfig.Emote): boolean
	return emote.Weight <= 0 or table.find(profile.emotes, emote.Id) ~= nil
end

--- Aplica os equipados no personagem atual (atributos + skin placeholder).
local function apply(player: Player)
	local profile = DataService.GetProfile(player)
	local equipped: { [string]: string } = if profile then profile.cosmetics.equipped else {}
	for category, attr in ATTR_BY_CATEGORY do
		local id: string = equipped[category] or ""
		local item = if id ~= "" then CosmeticsConfig.GetItem(id) else nil
		if item and profile and not owns(profile, item, player) then
			id = "" -- perdeu o VIP, por exemplo
		end
		player:SetAttribute(attr, id)
	end
	-- skin placeholder: cor do corpo
	local character = player.Character
	if character then
		local skin = CosmeticsConfig.GetItem(equipped.skin or "")
		local colors = character:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
		colors.Parent = character
		local color = if skin and skin.Color then skin.Color else Color3.fromRGB(163, 162, 165)
		local bc = BrickColor.new(color)
		colors.HeadColor = bc
		colors.TorsoColor = bc
		colors.LeftArmColor = bc
		colors.RightArmColor = bc
		colors.LeftLegColor = bc
		colors.RightLegColor = bc
	end
end

-- Roleta ---------------------------------------------------------------------

type PoolEntry = { id: string, name: string, kind: string, weight: number }
local pendingPick: { [Player]: string } = {} -- id escolhido aguardando o recibo do produto "pick"

local function pool(profile: any, player: Player): { PoolEntry }
	local list: { PoolEntry } = {}
	for _, item in CosmeticsConfig.Items do
		if item.Weight > 0 and item.Access == nil and not owns(profile, item, player) then
			table.insert(list, { id = item.Id, name = item.Name, kind = item.Category, weight = item.Weight })
		end
	end
	for _, emote in CosmeticsConfig.Emotes do
		if emote.Weight > 0 and not ownsEmote(profile, emote) then
			table.insert(list, { id = emote.Id, name = emote.Name, kind = "emote", weight = emote.Weight })
		end
	end
	return list
end

local function grant(profile: any, entry: PoolEntry)
	if entry.kind == "emote" then
		table.insert(profile.emotes, entry.id)
	else
		table.insert(profile.cosmetics.owned, entry.id)
	end
end

--- Um giro: item aleatório ponderado entre os não possuídos. nil = já tem tudo.
local function rollOnce(player: Player, profile: any): PoolEntry?
	local list = pool(profile, player)
	if #list == 0 then
		return nil
	end
	local total = 0
	for _, e in list do
		total += e.weight
	end
	local r = math.random() * total
	for _, e in list do
		r -= e.weight
		if r <= 0 then
			grant(profile, e)
			return e
		end
	end
	grant(profile, list[#list])
	return list[#list]
end

--- Recibo de produto (ShopService): giros ou item escolhido. Retorna false se não entregou.
function CosmeticsService.OnProduct(player: Player, product: any): boolean
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end
	if typeof(product.rolls) == "number" and product.rolls > 0 then
		local got = {}
		for _ = 1, product.rolls do
			local e = rollOnce(player, profile)
			if e then
				table.insert(got, { id = e.id, name = e.name, kind = e.kind })
			end
		end
		DataService.MarkDirty(player)
		notifyCosmetics:FireClient(player, "rolled", { items = got, robux = true })
		return true
	elseif product.pick then
		local id = pendingPick[player]
		local item = if id then CosmeticsConfig.GetItem(id) else nil
		local emote = if id then CosmeticsConfig.GetEmote(id) else nil
		if item then
			table.insert(profile.cosmetics.owned, item.Id)
			profile.cosmetics.equipped[item.Category] = item.Id
		elseif emote then
			table.insert(profile.emotes, emote.Id)
		else
			return false
		end
		pendingPick[player] = nil
		DataService.MarkDirty(player)
		apply(player)
		notifyCosmetics:FireClient(player, "rolled", { items = { { id = id, name = if item then item.Name else (emote :: any).Name, kind = if item then item.Category else "emote" } }, robux = true })
		return true
	end
	return false
end

local function deny(player: Player, reason: string, id: string)
	notifyCosmetics:FireClient(player, "denied", { reason = reason, id = id })
end

local function onRequestCosmetic(player: Player, action: any, id: any)
	if not requestLimiter:Allow(player) or typeof(action) ~= "string" then
		return
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return deny(player, "not_loaded", "")
	end
	if action == "roll" then
		if DataService.IsSessionOnly(player) then
			return deny(player, "not_loaded", "")
		end
		if #pool(profile, player) == 0 then
			return deny(player, "all_owned", "")
		end
		if profile.coins < CosmeticsConfig.RollCost then
			return deny(player, "coins", "")
		end
		profile.coins -= CosmeticsConfig.RollCost
		local e = rollOnce(player, profile)
		DataService.MarkDirty(player)
		if e then
			notifyCosmetics:FireClient(player, "rolled", { items = { { id = e.id, name = e.name, kind = e.kind } } })
			Log.debug(("[CosmeticsService] %s girou a roleta: %s"):format(player.Name, e.id))
		end
		return
	end
	if typeof(id) ~= "string" then
		return
	end
	if action == "pick_robux" then
		local item = CosmeticsConfig.GetItem(id)
		local emote = CosmeticsConfig.GetEmote(id)
		if (item and not owns(profile, item, player) and item.Access == nil) or (emote and not ownsEmote(profile, emote)) then
			pendingPick[player] = id -- o cliente abre o prompt do produto "pick" (ShopService)
			notifyCosmetics:FireClient(player, "pick_pending", { id = id })
		else
			deny(player, if item and item.Access == "vip" then "vip" else "already_owned", id)
		end
		return
	end
	local item = CosmeticsConfig.GetItem(id)
	if not item then
		return
	end
	if action == "equip" then
		if not owns(profile, item, player) then
			return deny(player, if item.Access == "vip" then "vip" else "locked", id)
		end
		profile.cosmetics.equipped[item.Category] = id
		DataService.MarkDirty(player)
		apply(player)
		notifyCosmetics:FireClient(player, "equipped", { id = id, category = item.Category })
	elseif action == "unequip" then
		profile.cosmetics.equipped[item.Category] = nil
		DataService.MarkDirty(player)
		apply(player)
		notifyCosmetics:FireClient(player, "equipped", { id = "", category = item.Category })
	end
end

local function onRequestEmote(player: Player, id: any)
	if not emoteLimiter:Allow(player) or typeof(id) ~= "string" then
		return
	end
	local emote = CosmeticsConfig.GetEmote(id)
	local profile = DataService.GetProfile(player)
	local character = player.Character
	if not emote or not profile or not character or not HealthService.IsAlive(character) then
		return
	end
	if not ownsEmote(profile, emote) then
		return deny(player, "locked", id)
	end
	if CombatService.IsStunned(player) or RagdollService.IsRagdolled(player) then
		return
	end
	local now = os.clock()
	if now - (lastEmoteAt[player] or 0) < CosmeticsConfig.EmoteCooldown then
		return
	end
	lastEmoteAt[player] = now
	notifyEmote:FireAllClients(character, id, true)
end

function CosmeticsService.Init()
	notifyCosmetics = Remotes.GetEvent(Remotes.Events.NotifyCosmetics)
	notifyEmote = Remotes.GetEvent(Remotes.Events.NotifyEmote)
end

function CosmeticsService.Start()
	local ok, ShopService = pcall(require, script.Parent:WaitForChild("ShopService"))
	if ok then
		(ShopService :: any).CosmeticHook = CosmeticsService.OnProduct
	end
	Remotes.GetEvent(Remotes.Events.RequestCosmetic).OnServerEvent:Connect(onRequestCosmetic)
	Remotes.GetEvent(Remotes.Events.RequestEmote).OnServerEvent:Connect(onRequestEmote)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5) -- depois do CharacterService montar o rig
			apply(player)
		end)
		player:GetAttributeChangedSignal("Pass_vip"):Connect(function()
			apply(player)
		end)
		-- perfil pode chegar depois do personagem
		task.spawn(function()
			local waited = 0
			while not DataService.GetProfile(player) and waited < 30 and player.Parent do
				waited += task.wait(0.5)
			end
			if player.Parent then
				apply(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastEmoteAt[player] = nil
		pendingPick[player] = nil
	end)
	Log.debug("[CosmeticsService] pronto")
end

return CosmeticsService
