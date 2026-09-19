--!strict
--[[
	ShopNpcService (servidor)
	Vendedor da LOJINHA (dono, 2026-09-19): um NPC R6 parado na frente do modelo `Workspace.Lojinha`
	(o dono posiciona a construção onde quiser; o vendedor acha ela pelo nome) com um ProximityPrompt
	"Falar". Quem aperta abre a tela de Loja (o cliente escuta o prompt em ShopController — sem remote).
	O NPC é ancorado, sem Combatant, invulnerável e sem vida na cabeça: é cenário, não alvo.
	Sem `Lojinha` no place = não faz nada (avisa no Studio).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Log = require(Modules:WaitForChild("Log"))

local ShopNpcService = {}

ShopNpcService.ModelName = "Lojinha"
ShopNpcService.PromptName = "ShopPrompt" -- o ShopController procura este nome
ShopNpcService.NpcName = "Vendedor"
ShopNpcService.FrontOffset = 6 -- studs à frente da lojinha (eixo -Z do pivô do modelo)

local function buildNpc(): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn("[ShopNpcService] não consegui criar o rig do vendedor: " .. tostring(model))
		return nil
	end
	model.Name = ShopNpcService.NpcName
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if not humanoid:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = humanoid
		end
		humanoid.DisplayName = "Vendedor"
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 40
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = d.Name ~= "HumanoidRootPart"
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local torso = model:FindFirstChild("Torso") :: BasePart?
	if torso then
		torso.Color = Color3.fromRGB(70, 110, 160)
	end
	model:SetAttribute("Npc", true) -- sem a tag Combatant a Hitbox nunca acerta ele: é cenário
	return model
end

local function placeNpc(shop: Model)
	local existing = Workspace:FindFirstChild(ShopNpcService.NpcName)
	if existing then
		existing:Destroy()
	end
	local npc = buildNpc()
	if not npc then
		return
	end
	local cf, size = shop:GetBoundingBox()
	-- na frente da lojinha, virado para fora (-Z do pivô = frente por convenção; se a arte girar o modelo,
	-- gira junto), com os pés no chão
	local front = cf * CFrame.new(0, -size.Y / 2, -(size.Z / 2 + ShopNpcService.FrontOffset))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { npc, shop }
	local hit = Workspace:Raycast(front.Position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	local groundY = if hit then hit.Position.Y else front.Position.Y
	local look = (cf.Position - front.Position) * Vector3.new(1, 0, 1)
	local facing = if look.Magnitude > 0.1 then -look.Unit else cf.LookVector -- olha para quem chega (costas para a loja)
	npc:PivotTo(CFrame.lookAt(Vector3.new(front.Position.X, groundY + 3, front.Position.Z), Vector3.new(front.Position.X, groundY + 3, front.Position.Z) + facing))
	npc.Parent = Workspace

	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = ShopNpcService.PromptName
		prompt.ActionText = "Falar"
		prompt.ObjectText = "Vendedor"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
	end
	Log.debug(("[ShopNpcService] vendedor na frente de %s"):format(shop:GetFullName()))
end

function ShopNpcService.Start()
	local shop = Workspace:FindFirstChild(ShopNpcService.ModelName, true)
	if shop and shop:IsA("Model") then
		placeNpc(shop)
	elseif RunService:IsStudio() then
		Log.debug("[ShopNpcService] sem modelo 'Lojinha' no Workspace: vendedor não criado")
	end
	-- o dono pode mover/renomear a lojinha em Team Create: reposiciona se ela aparecer depois
	Workspace.DescendantAdded:Connect(function(inst: Instance)
		if inst.Name == ShopNpcService.ModelName and inst:IsA("Model") then
			task.wait(1)
			placeNpc(inst :: Model)
		end
	end)
end

return ShopNpcService
