--!strict
-- Mantém os callbacks/validações existentes; troca somente o mecanismo de apresentação/input.
local Workspace = game:GetService("Workspace")
local Service = {}
local function configure(item: Instance)
	if not item:IsA("ProximityPrompt") then return end
	item.HoldDuration = 0
	item.Style = Enum.ProximityPromptStyle.Custom
	item.KeyboardKeyCode = Enum.KeyCode.None
	item.GamepadKeyCode = Enum.KeyCode.None
	item.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	-- Só o controller envia InputHoldBegin após Mouse1; clique nativo não captura a câmera.
	item.ClickablePrompt = false
	-- O cliente exige mira/visibilidade no alvo; o pivô do NPC fica encoberto pelo próprio corpo.
	item.RequiresLineOfSight = false
end
function Service.Init()
	for _, item in Workspace:GetDescendants() do configure(item) end
	Workspace.DescendantAdded:Connect(function(item)
		if item:IsA("ProximityPrompt") then task.defer(configure, item) end
	end)
end
return Service
