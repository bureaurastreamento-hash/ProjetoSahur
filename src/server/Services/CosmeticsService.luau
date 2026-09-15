--!strict
--[[
	CosmeticsService (servidor)
	Compra/equipar cosméticos (skins, capas, auras) e emotes; aplica no personagem.
	  RequestCosmetic(action, id) -> valida moedas/VIP -> perfil (DataService) -> atributos no Player
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
	if item.Cost <= 0 and item.Access == nil then
		return true
	end
	if item.Access == "vip" then
		return player:GetAttribute("Pass_vip") == true
	end
	return table.find(profile.cosmetics.owned, item.Id) ~= nil
end

local function ownsEmote(profile: any, emote: CosmeticsConfig.Emote): boolean
	return emote.Cost <= 0 or table.find(profile.emotes, emote.Id) ~= nil
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

local function deny(player: Player, reason: string, id: string)
	notifyCosmetics:FireClient(player, "denied", { reason = reason, id = id })
end

local function onRequestCosmetic(player: Player, action: any, id: any)
	if not requestLimiter:Allow(player) or typeof(action) ~= "string" or typeof(id) ~= "string" then
		return
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return deny(player, "not_loaded", id)
	end
	if action == "buy_emote" then
		local emote = CosmeticsConfig.GetEmote(id)
		if not emote then
			return
		end
		if ownsEmote(profile, emote) then
			return deny(player, "already_owned", id)
		end
		if profile.coins < emote.Cost then
			return deny(player, "coins", id)
		end
		profile.coins -= emote.Cost
		table.insert(profile.emotes, id)
		DataService.MarkDirty(player)
		notifyCosmetics:FireClient(player, "bought", { id = id })
		Log.debug(("[CosmeticsService] %s comprou emote %s"):format(player.Name, id))
		return
	end
	local item = CosmeticsConfig.GetItem(id)
	if not item then
		return
	end
	if action == "buy" then
		if owns(profile, item, player) then
			return deny(player, "already_owned", id)
		end
		if item.Access == "vip" then
			return deny(player, "vip", id)
		end
		if profile.coins < item.Cost then
			return deny(player, "coins", id)
		end
		profile.coins -= item.Cost
		table.insert(profile.cosmetics.owned, id)
		profile.cosmetics.equipped[item.Category] = id -- comprou = já equipa
		DataService.MarkDirty(player)
		apply(player)
		notifyCosmetics:FireClient(player, "bought", { id = id })
		Log.debug(("[CosmeticsService] %s comprou %s"):format(player.Name, id))
	elseif action == "equip" then
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
	end)
	Log.debug("[CosmeticsService] pronto")
end

return CosmeticsService
