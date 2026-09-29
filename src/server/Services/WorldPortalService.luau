--!strict
--[[ Portais entre as ilhas do Capítulo 1 (ligados pelo NOME da peça; gerados em tools/gerar_ilha_*_fx.py). ]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldService = require(script.Parent:WaitForChild("WorldService"))
local StoryService = require(script.Parent:WaitForChild("StoryService"))
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))

local WorldPortalService = {}
-- Ordem da bíblia: Porto da Névoa → (Herdeiro da Névoa) → Deserto do Sol → (Sacerdote do Sol Negro) → Rota do Eclipse.
-- Voltar é sempre livre. As flags são gravadas pelo `UnlockFlag` do ato em StoryConfig.
local PORTALS = {
	TutorialToPilares = { Region = "ilha_pilares", Checkpoint = "praia", RequiredFlag = "ilha_pilares_unlocked",
		Locked = "A ruptura para o Deserto do Sol está instável. Derrote o Herdeiro da Névoa nas ruínas ao norte." },
	PilaresToTutorial = { Region = "ilha_tutorial", Checkpoint = "porto" },
	PilaresToSolPartido = { Region = "ilha_sol_partido", Checkpoint = "oasis", RequiredFlag = "ilha_sol_partido_unlocked",
		Locked = "A Rota do Eclipse ainda está fechada. Derrote o Sacerdote do Sol Negro na Câmara (santuário atrás da cachoeira)." },
	SolPartidoToPilares = { Region = "ilha_pilares", Checkpoint = "praia" },
}

local function bind(part: BasePart, destination)
	if part:FindFirstChildOfClass("ProximityPrompt") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Atravessar"
	local region = WorldConfig.GetRegion(destination.Region)
	prompt.ObjectText = if region then region.Name else destination.Region
	prompt.HoldDuration = .5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player: Player)
		if destination.RequiredFlag and not StoryService.HasFlag(player, destination.RequiredFlag) then
			Remotes.GetEvent(Remotes.Events.NotifyStory):FireClient(player, "locked", { text = destination.Locked or "Rota selada." })
			return
		end
		if not WorldService.SetCheckpoint(player, destination.Region, destination.Checkpoint) then return end
		StoryService.ArriveRegion(player, destination.Region)
		local cf = WorldService.SpawnCFrame(player)
		if player.Character and cf then player.Character:PivotTo(cf * CFrame.new(0, 3, 0)) end
	end)
end

local function scan(root: Instance)
	for _, descendant in root:GetDescendants() do
		local destination = PORTALS[descendant.Name]
		if destination and descendant:IsA("BasePart") then bind(descendant, destination) end
	end
end

function WorldPortalService.Start()
	scan(Workspace)
	Workspace.DescendantAdded:Connect(function(descendant: Instance)
		local destination = PORTALS[descendant.Name]
		if destination and descendant:IsA("BasePart") then bind(descendant, destination) end
	end)
end

return WorldPortalService
