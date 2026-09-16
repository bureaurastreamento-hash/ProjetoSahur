--!strict
--[[
	RigAnimController (cliente)
	Rigs por peças (BossRigs, atributo BossRig no Model): animação PROCEDURAL nos Motor6D — respiração do
	corpo, cone balançando, barris "pisando" quando anda, cauda ondulando, e um PULSO de ataque (o cone
	"morde": mergulha para a frente e volta) disparado por CombatController/AbilityController.
	Cada cliente anima todos os rigs que vê. Só mexe em C0 (não replica; é visual).

	API: RigAnimController.Pulse(model, strength?) — strength 1 = soco, 2 = habilidade pesada
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RigAnimController = {}

type RigAnim = { model: Model, root: BasePart, motors: { [string]: Motor6D }, base: { [string]: CFrame }, phase: number, pulseAt: number, pulseStrength: number }
local rigs: { [Model]: RigAnim } = {}

local function trackRig(model: Model)
	if rigs[model] or model:GetAttribute("BossRig") == nil then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local anim: RigAnim = { model = model, root = root, motors = {}, base = {}, phase = math.random() * 6, pulseAt = -10, pulseStrength = 1 }
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			anim.motors[d.Name] = d
			anim.base[d.Name] = d.C0
		end
	end
	rigs[model] = anim
end

--- Pulso de ataque no rig (mordida): dispara em quem bate com o rig.
function RigAnimController.Pulse(model: Model, strength: number?)
	local a = rigs[model]
	if not a then
		trackRig(model)
		a = rigs[model]
	end
	if a then
		a.pulseAt = os.clock()
		a.pulseStrength = strength or 1
	end
end

local function animateRigs()
	local t = os.clock()
	for model, a in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		local v = a.root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local walk = math.clamp(speed / 12, 0, 1)
		local tt = t + a.phase
		local breathe = math.sin(tt * 1.6) * 0.12
		local step = tt * 7
		-- pulso: 0→1 rápido (0,08 s) e volta (0,3 s)
		local since = t - a.pulseAt
		local pulse = 0
		if since >= 0 and since < 0.4 then
			pulse = if since < 0.08 then since / 0.08 else 1 - (since - 0.08) / 0.32
			pulse *= a.pulseStrength
		end
		local function set(name: string, cf: CFrame)
			local m = a.motors[name]
			local b = a.base[name]
			if m and b then
				m.C0 = b * cf
			end
		end
		set("Root", CFrame.new(0, breathe + math.abs(math.sin(step)) * 0.35 * walk, -pulse * 1.2) * CFrame.Angles(-pulse * 0.12, 0, math.sin(step) * 0.05 * walk))
		set("Cone", CFrame.Angles(math.sin(tt * 1.2) * 0.04 - walk * 0.08 - pulse * 0.55, math.sin(tt * 0.9) * 0.05, math.sin(step) * 0.06 * walk))
		set("LimbFL", CFrame.new(0, math.max(0, math.sin(step)) * 0.9 * walk, math.sin(step) * 0.8 * walk - pulse * 0.8) * CFrame.Angles(math.sin(step) * 0.3 * walk, 0, 0))
		set("LimbBR", CFrame.new(0, math.max(0, math.sin(step)) * 0.9 * walk, math.sin(step) * 0.8 * walk) * CFrame.Angles(math.sin(step) * 0.3 * walk, 0, 0))
		set("LimbFR", CFrame.new(0, math.max(0, -math.sin(step)) * 0.9 * walk, -math.sin(step) * 0.8 * walk - pulse * 0.8) * CFrame.Angles(-math.sin(step) * 0.3 * walk, 0, 0))
		set("LimbBL", CFrame.new(0, math.max(0, -math.sin(step)) * 0.9 * walk, -math.sin(step) * 0.8 * walk) * CFrame.Angles(-math.sin(step) * 0.3 * walk, 0, 0))
		set("Tail", CFrame.Angles(math.sin(tt * 2.2) * 0.12 + pulse * 0.4, math.sin(tt * 1.7) * 0.25 + math.sin(step) * 0.1 * walk, 0))
	end
end

function RigAnimController.Start()
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("BossRig") ~= nil then
			trackRig(d)
		end
	end
	Workspace.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("Model") and d:GetAttribute("BossRig") ~= nil then
			task.defer(trackRig, d)
		end
	end)
	RunService.Heartbeat:Connect(animateRigs)
end

return RigAnimController
