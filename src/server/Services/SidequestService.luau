--!strict
-- Investigações pessoais e opcionais. Apenas prompts autoritativos, sem aceitar progresso do cliente.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Config = require(Modules.SidequestConfig)
local Remotes = require(Modules.RemoteEvents)
local DataService = require(script.Parent.DataService)
local StoryService = require(script.Parent.StoryService)
local ProgressionService = require(script.Parent.ProgressionService)
local SidequestService = {}

function SidequestService.Inspect(player: Player, id: string, marker: BasePart): boolean
	local quest = Config.Get(id)
	local profile = DataService.GetProfile(player)
	if not quest or not profile or not StoryService.CanInteract(player, marker, 14)
		or StoryService.RegionOf(player) ~= quest.Region or not profile.story.flags[quest.RequiresFlag] then return false end
	local flags = profile.story.flags
	if flags[Config.Key(id, "done")] or flags[Config.Key(id, "inspected")] then return false end
	flags[Config.Key(id, "inspected")] = true
	DataService.MarkDirty(player)
	StoryService.Refresh(player)
	StoryService.Say(player, quest.Report .. " Leve esta observação ao Humanoider no Porto da Névoa.", "Investigação")
	return true
end

function SidequestService.Deliver(player: Player, marker: BasePart): number
	local profile = DataService.GetProfile(player)
	if not profile or not StoryService.CanInteract(player, marker, 14) or StoryService.RegionOf(player) ~= "ilha_tutorial" then return 0 end
	local delivered = 0
	for _, quest in Config.List do
		local flags = profile.story.flags
		if flags[quest.RequiresFlag] and flags[Config.Key(quest.Id, "inspected")] and not flags[Config.Key(quest.Id, "done")] then
			-- Estado e recompensa pertencem ao mesmo perfil/save; não há yield entre as alterações.
			flags[Config.Key(quest.Id, "done")] = true
			local coins = DataService.RewardCoins(player, quest.Coins)
			ProgressionService.AddXP(player, quest.XP, "sidequest")
			DataService.MarkDirty(player)
			Remotes.GetEvent(Remotes.Events.NotifyQuest):FireClient(player, "toast", { title = quest.Title, text = ("Investigação entregue · %d XP base · +%d moedas"):format(quest.XP, coins) })
			delivered += 1
		end
	end
	StoryService.Refresh(player)
	if delivered == 0 then StoryService.Say(player, "Investigue os arquivos preservados ou a anomalia remanescente, se suas escolhas deram acesso a eles. Depois traga suas observações.") end
	return delivered
end

local function bind(marker: BasePart, action: string, title: string, id: string, use: (Player) -> ())
	local prompt = Instance.new("ProximityPrompt")
	prompt:SetAttribute("FXSidequestId", id)
	prompt.ActionText, prompt.ObjectText = action, title
	prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0.6, 11, false
	prompt.Parent = marker
	prompt.Triggered:Connect(use)
end

function SidequestService.Start()
	task.defer(function()
		local sahur = Workspace:FindFirstChild("Sahur")
		if not sahur then return end
		for _, quest in Config.List do
			local island = sahur:FindFirstChild(quest.Island)
			local marker = island and island:FindFirstChild(quest.Marker, true)
			if marker and marker:IsA("BasePart") then
				bind(marker, "Investigar (opcional)", quest.Title, quest.Id, function(player) SidequestService.Inspect(player, quest.Id, marker) end)
			else
				warn("[SidequestService] marcador indisponível: " .. quest.Marker)
			end
		end
		local island = sahur:FindFirstChild("FXTutorialIsland")
		local guide = island and island:FindFirstChild("HumanoiderSpot", true)
		if guide and guide:IsA("BasePart") then
			bind(guide, "Entregar investigações", "Humanoider_20 · Opcionais", "deliver", function(player) SidequestService.Deliver(player, guide) end)
		end
	end)
end

return SidequestService
