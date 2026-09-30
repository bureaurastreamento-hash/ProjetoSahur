--!strict
--[[
	VillagerService (servidor) — moradores andando pela vila para ela parecer viva (dono, 30/09: "a vila tá muito
	pequena, nem parece de verdade"). Andam entre as BaseParts `VilaWaypoint` (invisíveis) do mapa, param um pouco em
	cada ponto e seguem. NÃO são lutadores: sem tag Combatant/Bot, então golpe nenhum acerta e nenhum sistema de
	combate os vê. Aparência: roupa de cor sorteada sobre o boneco R6 padrão (nada de avatar de jogador real).
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local Log = require(Modules:WaitForChild("Log"))

local VillagerService = {}

VillagerService.Count = 7
local NAMES = { "Moradora", "Morador", "Pescador", "Lavadeira", "Carpinteiro", "Vendedora de peixe", "Aprendiz", "Velho do porto" }
local SKIN = { Color3.fromRGB(234, 192, 160), Color3.fromRGB(198, 150, 110), Color3.fromRGB(150, 104, 72), Color3.fromRGB(110, 76, 52) }
local CLOTH = { Color3.fromRGB(150, 60, 60), Color3.fromRGB(60, 90, 140), Color3.fromRGB(90, 120, 70), Color3.fromRGB(180, 150, 90),
	Color3.fromRGB(120, 100, 140), Color3.fromRGB(200, 200, 190), Color3.fromRGB(90, 70, 50) }

local rng = Random.new()

local function waypoints(): { Vector3 }
	local out = {}
	local sahur = Workspace:FindFirstChild("Sahur")
	if sahur then
		for _, d in sahur:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "VilaWaypoint" then
				table.insert(out, d.Position)
			end
		end
	end
	return out
end

local function makeVillager(i: number, at: Vector3): (Model?, Humanoid?)
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
	desc.TorsoColor = CLOTH[rng:NextInteger(1, #CLOTH)]
	local legs = CLOTH[rng:NextInteger(1, #CLOTH)]
	desc.LeftLegColor, desc.RightLegColor = legs, legs
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		return nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil, nil
	end
	model.Name = NAMES[((i - 1) % #NAMES) + 1]
	humanoid.DisplayName = model.Name
	humanoid.NameDisplayDistance = 25
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = rng:NextNumber(6, 9)
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Players" -- não empurra nem é empurrado por quem passa correndo
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	model:SetAttribute("Villager", true)
	model:PivotTo(CFrame.new(at + Vector3.new(0, 3, 0)))
	model.Parent = Workspace
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return model, humanoid
end

local function wander(model: Model, humanoid: Humanoid, points: { Vector3 })
	while model.Parent and humanoid.Health > 0 do
		local target = points[rng:NextInteger(1, #points)]
		humanoid:MoveTo(target + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)))
		local done = false
		local conn = humanoid.MoveToFinished:Connect(function()
			done = true
		end)
		local t = 0
		while not done and t < 20 and model.Parent do
			task.wait(0.5)
			t += 0.5
		end
		conn:Disconnect()
		task.wait(rng:NextNumber(3, 10)) -- conversa, olha a vitrine...
	end
end

function VillagerService.Start()
	task.defer(function()
		task.wait(4)
		local points = waypoints()
		if #points < 2 then
			return
		end
		for i = 1, VillagerService.Count do
			local model, humanoid = makeVillager(i, points[rng:NextInteger(1, #points)])
			if model and humanoid then
				task.spawn(wander, model, humanoid, points)
			end
		end
		Log.debug(("[VillagerService] %d moradores na vila (%d pontos)"):format(VillagerService.Count, #points))
	end)
end

return VillagerService
