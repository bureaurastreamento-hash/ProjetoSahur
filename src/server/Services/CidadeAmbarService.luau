--!strict
-- Não monta cidade nem desloca a reserva. Aguarda mapa/limites/chão/marcadores reais.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Config = require(Modules.CidadeAmbarConfig)
local WorldConfig = require(Modules.WorldConfig)
local MapRegistration = require(script.Parent.Parent.Modules.CampaignMapRegistration)
local EnemyConfig = require(Modules.EnemyConfig)
local StoryService = require(script.Parent.StoryService)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)
local BotService = require(script.Parent.BotService)
local Service = {}
local active: Model? = nil

function Service.Interact(player: Player, marker: BasePart): boolean
	local region = WorldConfig.GetRegion(Config.Region)
	local profile = DataService.GetProfile(player)
	if not profile or not region or not region.Available or not profile.story.flags.cidade_ambar_unlocked
		or not StoryService.CanInteract(player, marker, 14) or StoryService.RegionOf(player) ~= Config.Region then return false end
	if marker.Name == "AmbarHumanoider" then
		if StoryService.Wants(player, "fx_ambar_confrontar") and (profile.story.counters.fx_ambar_foto or 0) >= 1 then
			StoryService.SetFlag(player, "carlos_nome_revelado")
			if not StoryService.ProgressOnce(player, "fx_ambar_confrontar", marker.Name, true) then return false end
			StoryService.Say(player, Config.Revelation)
			return true
		end
		StoryService.TalkToGuide(player)
		return false
	end
	local action = Config.Interactions[marker.Name]
	if not action then return false end
	if action.Kind == "fx_ambar_padrao" and ((profile.story.counters.fx_ambar_cena or 0) < 2
		or (profile.story.counters.fx_ambar_depoimento or 0) < 1) then return false end
	-- A contrapista pode ser revista após outra acusação errada, sem refazer as cenas.
	local key = if action.Kind == "fx_ambar_contrapista" then action.Kind else marker.Name
	if not StoryService.ProgressOnce(player, action.Kind, key, true) then return false end
	StoryService.Say(player, action.Text, action.Title)
	return true
end

local function prompt(marker: BasePart, action: string, title: string, callback: (Player) -> ()): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText, p.ObjectText = action, title
	p.MaxActivationDistance, p.HoldDuration, p.RequiresLineOfSight = 11, 0.5, false
	p.Parent = marker
	p.Triggered:Connect(callback)
	return p
end

-- Pessoas paradas nos marcadores (o prompt continua no marcador). R6, ancoradas, sem colisão, dentro do mapa:
-- somem junto com ele. Humanoider usa o avatar do guia; os demais, roupa de cor neutra.
local PEOPLE = {
	AmbarHumanoider = { Name = "Humanoider_20 · Ancião", Guide = true },
	AmbarMorador1 = { Name = "Moradora", Torso = Color3.fromRGB(150, 60, 60), Legs = Color3.fromRGB(70, 60, 50) },
	AmbarMorador2 = { Name = "Feirante", Torso = Color3.fromRGB(90, 120, 70), Legs = Color3.fromRGB(60, 70, 90) },
	AmbarTestemunha = { Name = "Testemunha", Torso = Color3.fromRGB(180, 150, 90), Legs = Color3.fromRGB(50, 50, 60) },
} :: { [string]: { Name: string, Guide: boolean?, Torso: Color3?, Legs: Color3? } }

local function standPerson(marker: BasePart, info: { Name: string, Guide: boolean?, Torso: Color3?, Legs: Color3? }, map: Model)
	local ok, npc = pcall(function()
		local desc = if info.Guide then Players:GetHumanoidDescriptionFromUserId(StoryService.GuideUserId) else Instance.new("HumanoidDescription")
		if not info.Guide then
			local skin = Color3.fromRGB(198, 150, 110)
			desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
			desc.TorsoColor = info.Torso or skin
			desc.LeftLegColor, desc.RightLegColor = info.Legs or skin, info.Legs or skin
			desc.Shirt, desc.Pants = 3670737444, 398633812
		end
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not npc then warn("[CidadeAmbar] NPC não criado em " .. marker.Name); return end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then npc:Destroy(); return end
	npc.Name, humanoid.DisplayName = marker.Name .. "_NPC", info.Name
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, d in npc:GetDescendants() do
		if d:IsA("BasePart") then d.CanCollide = false elseif d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
	root.Anchored = true
	-- pela RAIZ, em pé sobre o topo do marcador (PivotTo enterra: o pivô não é a raiz)
	root.CFrame = marker.CFrame.Rotation + marker.Position + Vector3.new(0, marker.Size.Y / 2 + 3, 0)
	npc.Parent = map
end

-- Limites explícitos do mapa, não inferidos da arte. Área elíptica em XZ como as ilhas anteriores.
function Service.BindMap(map: Model): boolean
	if active or map.Name ~= Config.Map or not map:IsDescendantOf(Workspace) then return false end
	local prompts: { ProximityPrompt } = {}
	local names = { "AmbarHumanoider", "AmbarCheckpoint", "AmbarToSolPartido" }
	for name in Config.Interactions do table.insert(names, name) end
	local markers = MapRegistration.Bind(map, { Region = Config.Region, Center = "AmbarCentro", Spawn = "AmbarSpawn", Boss = "AmbarBossSpawn", Markers = names }, function()
		active = nil
		for _, p in prompts do p:Destroy() end
		for _, bot in BotService.List() do
			if bot:GetAttribute("StoryKillKind") == "fx_ambar_boss" then BotService.Remove(bot) end
		end
	end)
	if not markers then return false end
	active = map
	for name, info in PEOPLE do
		local marker = markers[name]
		if marker then task.spawn(standPerson, marker, info, map) end
	end
	for name, marker in markers do
		local action = Config.Interactions[name]
		if action or name == "AmbarHumanoider" then
			table.insert(prompts, prompt(marker, "Investigar / conversar", if action then action.Title else "Humanoider_20", function(player) Service.Interact(player, marker) end))
		end
	end
	table.insert(prompts, prompt(markers.AmbarCheckpoint, "Salvar chegada", "Checkpoint · Cidade Âmbar", function(player)
		if active == map and StoryService.CanInteract(player, markers.AmbarCheckpoint, 14)
			and StoryService.RegionOf(player) == Config.Region and StoryService.HasFlag(player, "cidade_ambar_unlocked") then
			WorldService.SetCheckpoint(player, Config.Region, "chegada")
		end
	end))
	-- Kit de combate provisório existente; ocultação/memória/duplicação próprias continuam pendentes.
	BotService.Spawn(EnemyConfig.Options(5, { HomeMap = map, CharacterId = "Swift", Name = "O Homem Sem Sombra", CFrame = markers.AmbarBossSpawn.CFrame * CFrame.new(0, 3, 0),
		Behavior = "aggressive", Team = "fx_ambar", Attributes = { FXEnemy = true, StoryKillKind = "fx_ambar_boss", MaxHealth = 650, DamageMult = 1.5 },
		Tuning = { SeekRadius = 55, AbilityChancePerTick = .22, BlockChancePerTick = .3 } }))

	return true
end

function Service.Start()
	local function tryMap()
		if active then return end
		local map = Workspace:FindFirstChild(Config.Map, true)
		if map and map:IsA("Model") then Service.BindMap(map) end
	end
	task.defer(tryMap)
	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant.Name == Config.Map or descendant.Name:match("^Ambar") then task.defer(tryMap) end
	end)
end
return Service
