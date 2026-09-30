--!strict
-- Apresentação pessoal dos Ecos: apenas NPCs gerados pelo código e prompts opcionais identificados.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Config = require(Modules.SidequestConfig)
local Remotes = require(Modules.RemoteEvents)
local EcoController = {}
local flags: { [string]: boolean } = {}
local lastSignature = ""

local function render(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		local id = instance:GetAttribute("FXSidequestId")
		if typeof(id) ~= "string" then return end
		if id == "deliver" then
			local ready = false
			for _, quest in Config.State(flags) do if quest.ready then ready = true end end
			instance.Enabled = ready
		else
			local quest = Config.Get(id)
			instance.Enabled = quest ~= nil and flags[quest.RequiresFlag] == true and not flags[Config.Key(id, "done")] and not flags[Config.Key(id, "inspected")]
		end
	elseif instance:IsA("Model") and instance:GetAttribute("FXStorySurvivor") == "ferido" then
		-- Este atributo é colocado somente no rig provisório criado por TutorialIslandService.
		local hidden = flags.eco_m3_deixou == true
		for _, child in instance:GetDescendants() do
			if child:IsA("BasePart") then child.LocalTransparencyModifier = if hidden then 1 else 0 end
		end
		local humanoid = instance:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.DisplayDistanceType = if hidden then Enum.HumanoidDisplayDistanceType.None else Enum.HumanoidDisplayDistanceType.Viewer end
	end
end

local function update(profile: any)
	if typeof(profile) ~= "table" or typeof(profile.story) ~= "table" or typeof(profile.story.flags) ~= "table" then return end
	flags = profile.story.flags
	local parts = { tostring(flags.eco_m3_deixou == true) }
	for _, quest in Config.List do
		table.insert(parts, tostring(flags[quest.RequiresFlag] == true))
		table.insert(parts, tostring(flags[Config.Key(quest.Id, "inspected")] == true))
		table.insert(parts, tostring(flags[Config.Key(quest.Id, "done")] == true))
	end
	local signature = table.concat(parts, ":")
	if signature == lastSignature then return end
	lastSignature = signature
	local sahur = Workspace:FindFirstChild("Sahur")
	if sahur then for _, instance in sahur:GetDescendants() do render(instance) end end
end

function EcoController.Start()
	Workspace.DescendantAdded:Connect(function(instance)
		local sahur = Workspace:FindFirstChild("Sahur")
		if sahur and instance:IsDescendantOf(sahur) then render(instance) end
	end)
	Remotes.GetEvent(Remotes.Events.NotifyProfile).OnClientEvent:Connect(update)
	-- A requisição garante um snapshot caso o perfil tenha chegado antes de Start.
	Remotes.GetEvent(Remotes.Events.RequestProfile):FireServer()
end

return EcoController
