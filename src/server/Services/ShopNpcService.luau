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
	-- Lojinha e Banheiro são a MESMA construção (dono): a caixa é a união dos dois; a "frente" é o
	-- LookVector do pivô da Lojinha (girou o modelo, gira a frente). O vendedor fica fora da caixa,
	-- com os pés no chão de verdade (raycast ignorando a construção).
	local building: { Instance } = { shop }
	local bathroom = Workspace:FindFirstChild("Banheiro", true)
	if bathroom then
		table.insert(building, bathroom)
	end
	local minV, maxV = nil :: Vector3?, nil :: Vector3?
	for _, m in building do
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				local half = d.Size / 2
				local lo, hi = d.Position - half, d.Position + half
				minV = if minV then Vector3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z)) else lo
				maxV = if maxV then Vector3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z)) else hi
			end
		end
	end
	local pivot = shop:GetPivot()
	local center = if minV and maxV then (minV + maxV) / 2 else pivot.Position
	local extent = if minV and maxV then math.max(maxV.X - minV.X, maxV.Z - minV.Z) / 2 else 8
	local lookFlat = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	local look = if lookFlat.Magnitude > 0.1 then lookFlat.Unit else Vector3.new(0, 0, -1)
	local frontPos = center + look * (extent + ShopNpcService.FrontOffset)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { npc }
	for _, m in building do
		table.insert(exclude, m)
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(Vector3.new(frontPos.X, (if maxV then maxV.Y else frontPos.Y) + 20, frontPos.Z), Vector3.new(0, -120, 0), params)
	local groundY = if hit then hit.Position.Y else (if minV then minV.Y else frontPos.Y)
	local stand = Vector3.new(frontPos.X, groundY + 3, frontPos.Z)
	npc:PivotTo(CFrame.lookAt(stand, stand + look)) -- de costas para a loja, olhando para quem chega
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
		if (inst.Name == ShopNpcService.ModelName or inst.Name == "Banheiro") and inst:IsA("Model") then
			task.wait(1)
			local shop = Workspace:FindFirstChild(ShopNpcService.ModelName, true)
			if shop and shop:IsA("Model") then
				placeNpc(shop :: Model)
			end
		end
	end)
end

return ShopNpcService
