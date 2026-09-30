--!strict
-- Arma usa Tool nativo; posse, bônus e maestria são conferidos no servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local BuildConfig = require(Modules.BuildConfig)
local Remotes = require(Modules.RemoteEvents)
local ProgressionConfig = require(Modules.ProgressionConfig)
local DataService = require(script.Parent.DataService)
local AbilityService = require(script.Parent.AbilityService)

local BuildService = {}
local tools: { [Player]: Tool? } = {}

function BuildService.Refresh(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local build = profile.build
	player:SetAttribute("InitialRoute", build.route)
	player:SetAttribute("FightingStyle", build.style)
	player:SetAttribute("TechniqueTier", build.techniqueTier)
	player:SetAttribute("StyleMastery", ProgressionConfig.MasteryLevel(profile.mastery[BuildConfig.MasteryKey("style", BuildConfig.StyleId)] or 0))
	player:SetAttribute("WeaponMastery", ProgressionConfig.MasteryLevel(profile.mastery[BuildConfig.MasteryKey("weapon", BuildConfig.WeaponId)] or 0))
end

local function restoreWeapon(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile or profile.build.weapon ~= BuildConfig.WeaponId then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local previous = tools[player]
	if previous and previous.Parent then return end
	local tool = Instance.new("Tool")
	tool.Name, tool.ToolTip = BuildConfig.WeaponName, "Equipe e ataque com os controles normais. Maestria própria."
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", BuildConfig.WeaponId)
	-- Representação provisória feita em runtime; nenhum asset da equipe é editado.
	local handle = Instance.new("Part")
	handle.Name, handle.Size = "Handle", Vector3.new(0.3, 3.5, 0.5)
	handle.Material, handle.Color = Enum.Material.Wood, Color3.fromRGB(144, 103, 66)
	handle.CanCollide, handle.CanTouch, handle.Massless = false, false, true
	handle.Parent = tool
	tool.Grip = CFrame.new(0, -1, 0)
	tools[player] = tool
	tool.Equipped:Connect(function()
		local allowed, reason = AbilityService.CanChangeCharacter(player)
		if not allowed then
			Remotes.GetEvent(Remotes.Events.NotifyStand):FireClient(player, "denied", { text = reason })
			tool.Parent = backpack
			return
		end
		player:SetAttribute("EquippedWeapon", BuildConfig.WeaponId)
	end)
	tool.Unequipped:Connect(function()
		if tools[player] == tool then player:SetAttribute("EquippedWeapon", nil) end
	end)
	tool.Parent = backpack
end

--- Chamado somente após StoryService validar a escolha e os objetivos.
function BuildService.SelectRoute(player: Player, route: string): boolean
	local profile = DataService.GetProfile(player)
	if not profile or profile.build.route ~= "" or not BuildConfig.Routes[route] then return false end
	profile.build.route = route
	if route == "tecnica" then
		profile.build.style = BuildConfig.StyleId
		profile.build.techniqueTier = if profile.story.flags.tecnica_m8_aprendeu then 2 else math.max(1, profile.build.techniqueTier)
	elseif route == "arma" then
		profile.build.weapon = BuildConfig.WeaponId
	elseif profile.story.completed.eco_capela and profile.build.style == "" then
		profile.build.style, profile.build.techniqueTier = BuildConfig.StyleId, 1
	end
	BuildService.Refresh(player)
	DataService.MarkDirty(player)
	restoreWeapon(player)
	return true
end

function BuildService.CompleteIsland(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	if profile.build.route == "manifestacao" and profile.build.style == "" then
		profile.build.style, profile.build.techniqueTier = BuildConfig.StyleId, 1
		DataService.MarkDirty(player)
		BuildService.Refresh(player)
	end
end

function BuildService.LearnTechnique(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	profile.build.style = BuildConfig.StyleId
	profile.build.techniqueTier = if profile.build.route == "tecnica" then 2 else math.max(1, profile.build.techniqueTier)
	BuildService.Refresh(player)
	DataService.MarkDirty(player)
end

function BuildService.HasEquippedWeapon(player: Player): boolean
	local profile = DataService.GetProfile(player)
	local tool = tools[player]
	return profile ~= nil and profile.build.weapon == BuildConfig.WeaponId
		and tool ~= nil and player.Character ~= nil and tool.Parent == player.Character
end

function BuildService.M1Multiplier(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then return 1 end
	if BuildService.HasEquippedWeapon(player) then return BuildConfig.WeaponDamage end
	return BuildConfig.StyleDamage[profile.build.techniqueTier] or 1
end

function BuildService.IncomingMultiplier(player: Player): number
	local profile = DataService.GetProfile(player)
	return if profile then BuildConfig.StyleIncoming[profile.build.techniqueTier] or 1 else 1
end

--- Apenas acertos reais de M1 (chamada de CombatService), sem XP por equipar ou atacar o vazio.
function BuildService.OnM1Hit(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local key = if BuildService.HasEquippedWeapon(player) then BuildConfig.MasteryKey("weapon", BuildConfig.WeaponId)
		elseif profile.build.style ~= "" then BuildConfig.MasteryKey("style", profile.build.style) else nil
	if not key then return end
	profile.mastery[key] = (profile.mastery[key] or 0) + 1
	BuildService.Refresh(player)
	DataService.MarkDirty(player)
end

function BuildService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			local previous = tools[player]
			if previous then previous:Destroy() end
			tools[player] = nil
			player:SetAttribute("EquippedWeapon", nil)
			task.defer(function()
				player:WaitForChild("Backpack", 10)
				if player.Parent == Players then restoreWeapon(player) end
			end)
		end)
		BuildService.Refresh(player)
		restoreWeapon(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	DataService.ProfileLoaded.Event:Connect(function(player: Player)
		BuildService.Refresh(player)
		restoreWeapon(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player) tools[player] = nil end)
	for _, player in Players:GetPlayers() do onPlayer(player) end
end

return BuildService
