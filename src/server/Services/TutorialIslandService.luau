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

local function investigate(part: BasePart, action: string, object: string, onUse: (Player) -> ())
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = action, object
	prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0.6, 10, false
	prompt.Parent = part
	prompt.Triggered:Connect(onUse)
end

local function toast(player: Player, title: string, text: string)
	Remotes.GetEvent(Remotes.Events.NotifyQuest):FireClient(player, "toast", { title = title, text = text })
end

-- NPC parado (sobreviventes da fenda): rig R6 padrão, posicionado pela RAIZ (PivotTo deixava enterrado).
local function staticNpc(spot: BasePart, name: string, lying: boolean, parent: Instance)
	local ok, npc = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if not ok or not npc then return end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then npc:Destroy(); return end
	npc.Name = name
	humanoid.DisplayName = name
	for _, d in npc:GetDescendants() do
		if d:IsA("BasePart") then d.CanCollide = false end
	end
	root.Anchored = true
	local top = spot.Position.Y + spot.Size.Y / 2
	root.CFrame = if lying then CFrame.new(spot.Position.X, top + 1, spot.Position.Z) * CFrame.Angles(math.rad(-90), 0, 0)
		else CFrame.new(spot.Position.X, top + 3, spot.Position.Z)
	npc.Parent = parent
end

-- Missões 0, 3 (fenda + Eco), 4 (Máscara) e a rachadura da escolha final (BIBLIA_CAMPANHA_CAP1).
local function populateStory(story: Instance)
	local function find(name: string): BasePart?
		local p = story:FindFirstChild(name)
		return if p and p:IsA("BasePart") then p else nil
	end
	local destrocos, pertence, estrutura = find("M0_Destrocos"), find("M0_Pertence"), find("M0_Estrutura")
	if destrocos then
		investigate(destrocos, "Examinar", "Destroços", function(player)
			StoryService.Progress(player, "fx_m0_destrocos", 1)
		end)
	end
	if pertence then
		investigate(pertence, "Pegar", "Sua bolsa", function(player)
			if StoryService.Progress(player, "fx_m0_pertence", 1) then
				toast(player, "É sua", "Uma bolsa com as suas coisas. Molhada, mas inteira. Como você.")
			end
		end)
	end
	if estrutura then
		investigate(estrutura, "Tocar", "Estrutura enterrada", function(player)
			if StoryService.Wants(player, "fx_m0_estrutura") then
				-- por menos de um segundo, um lugar completamente diferente (StoryController)
				Remotes.GetEvent(Remotes.Events.NotifyStory):FireClient(player, "distort", {})
				task.delay(1.2, function() StoryService.Progress(player, "fx_m0_estrutura", 1) end)
			end
		end)
	end
	local saida = find("FendaSaida")
	if saida then
		investigate(saida, "Investigar", "Fenda estreita", function(player)
			StoryService.SetFlag(player, "fenda_saida")
			toast(player, "Uma passagem estreita", "Dá para sair da fenda por aqui, sem cruzar o centro. Pode servir.")
		end)
	end
	local rachadura = find("RachaduraCapela")
	if rachadura then
		investigate(rachadura, "Investigar", "Rachadura na parede", function(player)
			StoryService.SetFlag(player, "passagem_capela")
			toast(player, "Uma passagem na capela", "A rachadura dá para o porão da capela. Se ela desabar, isto é uma saída.")
		end)
	end
	local ferido, sobrevivente = find("SobreviventeFeridoSpot"), find("SobreviventeSpot")
	if ferido then staticNpc(ferido, "Sobrevivente ferido", true, story) end
	if sobrevivente then staticNpc(sobrevivente, "Sobrevivente", false, story) end
	local mascara = find("MascaraSpawn")
	if mascara then
		BotService.Spawn({ CharacterId = "Jotaro", Name = "Portador da Máscara", CFrame = mascara.CFrame * CFrame.new(0, 3, 0), Behavior = "aggressive",
			Team = "fx_mascara", Attributes = { FXEnemy = true, StoryKillKind = "fx_mascara_boss", MaxHealth = 240, DamageMult = 1.1 },
			Tuning = { SeekRadius = 40, AbilityChancePerTick = .15 } })
	end
end

local function populate(island: Model)
	local story = island:FindFirstChild("Historia")
	if story then populateStory(story) end
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
