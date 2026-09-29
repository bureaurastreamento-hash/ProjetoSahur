--!strict
--[[
	FisherService — o PESCADOR de cada ilha (dono, 2026-09-29): NPC num ponto fácil perto da chegada; conversar
	com ele SALVA o spawn (checkpoint) naquela ilha. Portais só levam, não salvam (WorldPortalService).
	Pontos em WorldConfig.Regions[*].Fisher (alturas conferidas por raycast no place).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))
local StoryService = require(script.Parent:WaitForChild("StoryService"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local FisherService = {}
local NAME = "Pescador"

local function spawnFisher(regionId: string, region: WorldConfig.Region, folder: Folder)
	local spot = region.Fisher
	local checkpoint = spot and WorldConfig.GetCheckpoint(regionId, spot.Checkpoint)
	if not spot or not checkpoint then return end
	local ok, npc = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(196, 150, 110)
		desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
		desc.TorsoColor = Color3.fromRGB(60, 110, 150) -- camisa azul de pescador
		desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(90, 70, 50), Color3.fromRGB(90, 70, 50)
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not npc then return end
	npc.Name = "Pescador_" .. regionId
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then npc:Destroy(); return end
	humanoid.DisplayName = NAME .. " · salvar spawn"
	humanoid.NameDisplayDistance = 80
	for _, d in npc:GetDescendants() do
		if d:IsA("BasePart") then d.CanCollide = false end
	end
	root.Anchored = true
	-- olhando para o ponto de chegada
	local look = Vector3.new(checkpoint.Position.X, spot.Position.Y + 3, checkpoint.Position.Z)
	-- pela RAIZ (o pivô do modelo gerado não é o HumanoidRootPart: com PivotTo ele ficava 1.5 enterrado)
	root.CFrame = CFrame.lookAt(spot.Position + Vector3.new(0, 3, 0), look)
	-- vara de pesca (peça simples, só visual)
	local rod = Instance.new("Part")
	rod.Name = "Vara"
	rod.Size = Vector3.new(0.2, 0.2, 7)
	rod.Color = Color3.fromRGB(110, 80, 50)
	rod.Material = Enum.Material.SmoothPlastic
	rod.CanCollide, rod.Anchored, rod.Massless = false, true, true
	rod.CFrame = root.CFrame * CFrame.new(1.6, 0.5, -2.5) * CFrame.Angles(math.rad(35), 0, 0)
	rod.Parent = npc
	npc.Parent = folder
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Salvar spawn aqui"
	prompt.ObjectText = NAME
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player: Player)
		local profile = DataService.GetProfile(player)
		local already = profile ~= nil and profile.world.region == regionId and profile.world.checkpoint == spot.Checkpoint
		if not already and not WorldService.SetCheckpoint(player, regionId, spot.Checkpoint) then return end
		StoryService.Say(player, if already
			then ("Seu spawn já é aqui, em %s. Pode ir sossegado."):format(region.Name)
			else ("Pronto. Se cair por aí, você volta para %s, pertinho de mim."):format(region.Name), NAME)
	end)
end

function FisherService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Pescadores"
	folder.Parent = Workspace
	for regionId, region in WorldConfig.Regions do
		if region.Fisher and region.Available then
			spawnFisher(regionId, region, folder)
		end
	end
end

return FisherService
