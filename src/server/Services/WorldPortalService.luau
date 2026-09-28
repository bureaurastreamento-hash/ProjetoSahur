--!strict
--[[ Portais entre as ilhas do Capítulo 1 (ligados pelo NOME da peça; gerados em tools/gerar_ilha_*_fx.py). ]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldService = require(script.Parent:WaitForChild("WorldService"))
local StoryService = require(script.Parent:WaitForChild("StoryService"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local WorldPortalService = {}
local PORTALS = {
	TutorialToPilares = { Region = "ilha_pilares", Checkpoint = "praia" },
	PilaresToTutorial = { Region = "ilha_tutorial", Checkpoint = "porto" },
	PilaresToSolPartido = { Region = "ilha_sol_partido", Checkpoint = "oasis", RequiredFlag = "ilha_sol_partido_unlocked" },
	SolPartidoToPilares = { Region = "ilha_pilares", Checkpoint = "praia" },
}

local function bind(part: BasePart, destination)
	if part:FindFirstChildOfClass("ProximityPrompt") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Atravessar"
	prompt.ObjectText = if destination.Region == "ilha_pilares" then "Ilha dos Pilares · Coliseu"
		elseif destination.Region == "ilha_sol_partido" then "Ilha do Sol Partido" else "Ilha do Alvorecer"
	prompt.HoldDuration = .5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player: Player)
		if destination.RequiredFlag and not StoryService.HasFlag(player, destination.RequiredFlag) then
			Remotes.GetEvent(Remotes.Events.NotifyStory):FireClient(player, "locked", { text = "Derrote o Guardião Fraturado nas ruínas para abrir esta rota." })
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
