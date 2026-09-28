--!strict
--[[ Popula a Ilha do Alvorecer sem depender de edição manual no Studio. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local StoryService = require(script.Parent:WaitForChild("StoryService"))

local TutorialIslandService = {}
local HUMANOIDER_USER_ID = 3792294725

local function model(): Model?
	local sahur = Workspace:FindFirstChild("Sahur")
	local found = sahur and sahur:FindFirstChild("FXTutorialIsland")
	return if found and found:IsA("Model") then found else nil
end

local function spawnGuide(spot: BasePart)
	local ok, guide = pcall(function()
		local desc = Players:GetHumanoidDescriptionFromUserId(HUMANOIDER_USER_ID)
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
	guide:PivotTo(spot.CFrame * CFrame.new(0, 3, 0))
	guide.Parent = model()
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Conversar"
	prompt.ObjectText = "Humanoider_20"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player: Player)
		local began = StoryService.Begin(player)
		Remotes.GetEvent(Remotes.Events.NotifyQuest):FireClient(player, "dialog", {
			npc = "Humanoider_20", userId = HUMANOIDER_USER_ID, kind = "progress",
			text = if began then "Você caiu longe de casa. Comece no campo de treino: vença três Vagantes e prove que sabe aparar um golpe. Depois siga a trilha até as ruínas." else "Continue seguindo o registro F/X. As ruínas ao norte escondem algo que Carlos não conseguiu levar consigo.",
		})
	end)
end

local function bindTrace(trace: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Investigar"
	prompt.ObjectText = "Eco desconhecido"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = trace
	prompt.Triggered:Connect(function(player: Player)
		local discovered = StoryService.DiscoverTrace(player, "carlos_era01")
		Remotes.GetEvent(Remotes.Events.NotifyQuest):FireClient(player, "toast", {
			title = if discovered then "Rastro de Carlos encontrado" else "Rastro já registrado",
			text = if discovered then "Uma gravação quebrada menciona alguém preparando a F/X por dentro." else "Este eco já está no seu registro.",
		})
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
			if pad:IsA("BasePart") and pad.Name:match("^DummyPad") then
				BotService.Spawn({ CharacterId = "Swift", Name = "Vagante da Fratura", CFrame = pad.CFrame * CFrame.new(0, 3, 0), Behavior = "aggressive", Team = "fx_tutorial", Attributes = { FXEnemy = true, StoryKillKind = "fx_tutorial_enemy" }, Tuning = { SeekRadius = 32 } })
			end
		end
	end
	local bossSpot = island:FindFirstChild("BossSpawn", true)
	if bossSpot and bossSpot:IsA("BasePart") then
		BotService.Spawn({ CharacterId = "Swift", Name = "Guardião Fraturado", CFrame = bossSpot.CFrame * CFrame.new(0, 3, 0), Behavior = "aggressive", Team = "fx_guardian", Attributes = { FXEnemy = true, StoryKillKind = "fx_cap1_boss", MaxHealth = 300, DamageMult = 1.25 }, Tuning = { SeekRadius = 55, AbilityChancePerTick = .18 } })
	end
end

function TutorialIslandService.Start()
	task.defer(function()
		local island = model()
		if island then populate(island) end
	end)
end

return TutorialIslandService
