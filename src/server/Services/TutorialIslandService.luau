--!strict
--[[ Popula a Ilha 1 — PORTO DA NÉVOA (BIBLIA_CAMPANHA_CAP1_v0.1.md) sem depender de edição manual no Studio.
     Model/ids continuam "FXTutorialIsland"/"ilha_tutorial" (saves e Rojo). ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local StoryService = require(script.Parent:WaitForChild("StoryService"))

local TutorialIslandService = {}

local function model(): Model?
	local sahur = Workspace:FindFirstChild("Sahur")
	local found = sahur and sahur:FindFirstChild("FXTutorialIsland")
	return if found and found:IsA("Model") then found else nil
end

local function spawnGuide(spot: BasePart)
	local ok, guide = pcall(function()
		local desc = Players:GetHumanoidDescriptionFromUserId(StoryService.GuideUserId)
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not guide then return end
	guide.Name = "Humanoider_20_Guia"
	local humanoid = guide:FindFirstChildOfClass("Humanoid")
	local root = guide:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then guide:Destroy(); return end
	humanoid.DisplayName = "Humanoider_20 · Ancião"
	for _, descendant in guide:GetDescendants() do
		if descendant:IsA("BasePart") then descendant.CanCollide = false end
	end
	root.Anchored = true
	-- pela RAIZ, em pé sobre o topo do marcador (PivotTo deixava 1.7 enterrado: o pivô não é a raiz)
	root.CFrame = spot.CFrame.Rotation + Vector3.new(spot.Position.X, spot.Position.Y + spot.Size.Y / 2 + 3, spot.Position.Z)
	guide.Parent = model()
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Conversar"
	prompt.ObjectText = "Humanoider_20"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player: Player)
		StoryService.TalkToGuide(player)
	end)
end

local function bindTrace(trace: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Investigar"
	prompt.ObjectText = "Brilho metálico"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = trace
	prompt.Triggered:Connect(function(player: Player)
		if not StoryService.DiscoverTrace(player, "carlos_era01") then
			Remotes.GetEvent(Remotes.Events.NotifyQuest):FireClient(player, "toast", { title = "Rastro já registrado", text = "Esta peça já está no seu registro." })
		end
	end)
end

local function populate(island: Model)
	local guideSpot = island:FindFirstChild("HumanoiderSpot", true)
	if guideSpot and guideSpot:IsA("BasePart") then spawnGuide(guideSpot) end
	local trace = island:FindFirstChild("RastroCarlos01", true)
	if trace and trace:IsA("BasePart") then bindTrace(trace) end
	local training = island:FindFirstChild("Treino")
	if training then
		for _, pad in training:GetChildren() do
			if pad:IsA("BasePart") and pad.Name:match("^VagantePad") then
				BotService.Spawn({ CharacterId = "Swift", Name = "Vagante da Fratura", CFrame = pad.CFrame * CFrame.new(0, 3, 0), Behavior = "aggressive", Team = "fx_tutorial", Attributes = { FXEnemy = true, StoryKillKind = "fx_tutorial_enemy" }, Tuning = { SeekRadius = 32 } })
			end
		end
	end
	local bossSpot = island:FindFirstChild("GuardiaoSpawn", true)
	if bossSpot and bossSpot:IsA("BasePart") then
		-- Final da Ilha 1: o Herdeiro da Névoa (poder da máscara + F/X; kit provisório do Dio).
		BotService.Spawn({ CharacterId = "Dio", Name = "Herdeiro da Névoa", CFrame = bossSpot.CFrame * CFrame.new(0, 3, 0), Behavior = "aggressive", Team = "fx_guardian", Attributes = { FXEnemy = true, StoryKillKind = "fx_cap1_boss", MaxHealth = 300, DamageMult = 1.25 }, Tuning = { SeekRadius = 55, AbilityChancePerTick = .18 } })
	end
end

function TutorialIslandService.Start()
	task.defer(function()
		local island = model()
		if island then populate(island) end
	end)
end

return TutorialIslandService
