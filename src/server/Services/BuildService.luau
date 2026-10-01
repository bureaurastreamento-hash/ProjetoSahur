--!strict
-- Arma usa Tool nativo; posse, bônus e maestria são conferidos no servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local BuildConfig = require(Modules.BuildConfig)
local Assets = require(Modules.Assets)
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
	local weaponId = if BuildConfig.Weapon(build.weapon) then build.weapon else BuildConfig.WeaponId
	player:SetAttribute("WeaponMastery", ProgressionConfig.MasteryLevel(profile.mastery[BuildConfig.MasteryKey("weapon", weaponId)] or 0))
	player:SetAttribute("WeaponId", if BuildConfig.Weapon(build.weapon) then build.weapon else nil)
end

local function restoreWeapon(player: Player)
	local profile = DataService.GetProfile(player)
	local weaponId = profile and profile.build.weapon or ""
	local def = BuildConfig.Weapon(weaponId)
	if not profile or not def then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local previous = tools[player]
	if previous and previous.Parent and previous:GetAttribute("WeaponId") == weaponId then return end
	if previous then previous:Destroy() end
	local tool = Instance.new("Tool")
	tool.Name, tool.ToolTip = def.Name, ("%s · %s. Equipe e ataque com os controles normais. Maestria própria."):format(def.Rarity, def.Desc)
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", weaponId)
	-- Representação provisória feita em runtime (cabo + lâmina); nenhum asset da equipe é editado.
	local handle = Instance.new("Part")
	handle.Name, handle.Size = "Handle", Vector3.new(0.3, 1.2, 0.3)
	handle.Material, handle.Color = Enum.Material.Wood, Color3.fromRGB(70, 50, 40)
	handle.CanCollide, handle.CanTouch, handle.Massless = false, false, true
	handle.Parent = tool
	local blade = Instance.new("Part")
	blade.Name, blade.Size = "Lamina", Vector3.new(0.2, def.Length, 0.45)
	blade.Material, blade.Color = def.Material, def.Color
	blade.CanCollide, blade.CanTouch, blade.Massless = false, false, true
	blade.CFrame = handle.CFrame * CFrame.new(0, 0.6 + def.Length / 2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = handle, blade
	weld.Parent = blade
	blade.Parent = tool
	-- Novo visual da Névoa; outros modelos/armas da equipe continuam intactos.
	local visual = if weaponId == "lamina_nevoa" then Assets.GetCombatModel("MistBlade") else nil
	if visual then
		blade:Destroy()
		handle.Transparency = 1
		local clone = visual:Clone()
		clone.Name = "VisualLamina"
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = handle.CFrame * part.CFrame
				part.Anchored, part.CanCollide, part.CanTouch, part.Massless = false, false, false, true
				local joint = Instance.new("WeldConstraint")
				joint.Part0, joint.Part1 = handle, part
				joint.Parent = part
			end
		end
		clone.Parent = tool
		tool:SetAttribute("CombatVisual", "MistBlade")
	end
	if def.Glow and not visual then
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range = def.Color, 1.5, 8
		light.Parent = blade
	end
	tool.Grip = CFrame.new(0, -0.3, 0)
	tools[player] = tool
	tool.Equipped:Connect(function()
		local allowed, reason = AbilityService.CanChangeCharacter(player)
		if not allowed then
			Remotes.GetEvent(Remotes.Events.NotifyStand):FireClient(player, "denied", { text = reason })
			tool.Parent = backpack
			return
		end
		player:SetAttribute("EquippedWeapon", weaponId)
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

--- Equipa uma arma do catálogo (item "arma:<id>" já tirado da mochila por quem chama). A anterior volta para a
--- mochila como item, sem perder a maestria (a maestria é por arma).
function BuildService.EquipWeapon(player: Player, weaponId: string): boolean
	local profile = DataService.GetProfile(player)
	if not profile or not BuildConfig.Weapon(weaponId) then return false end
	local previous = profile.build.weapon
	if previous == weaponId then return false end
	if BuildConfig.Weapon(previous) then
		DataService.AddItem(player, "arma:" .. previous, 1)
	end
	profile.build.weapon = weaponId
	player:SetAttribute("EquippedWeapon", nil)
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
	return profile ~= nil and BuildConfig.Weapon(profile.build.weapon) ~= nil
		and tool ~= nil and player.Character ~= nil and tool.Parent == player.Character
end

function BuildService.M1Multiplier(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then return 1 end
	if BuildService.HasEquippedWeapon(player) then
		local def = BuildConfig.Weapon(profile.build.weapon)
		return if def then def.Damage else BuildConfig.WeaponDamage
	end
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
	local key = if BuildService.HasEquippedWeapon(player) then BuildConfig.MasteryKey("weapon", profile.build.weapon)
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
