--!strict
--[[
	RigAnimController (cliente)
	Rigs por peças (BossRigs, atributo BossRig no Model): animação PROCEDURAL nos Motor6D — respiração do
	corpo, cone balançando, barris "pisando" quando anda, cauda ondulando, e um PULSO de ataque (o cone
	"morde": mergulha para a frente e volta) disparado por CombatController/AbilityController.
	Cada cliente anima todos os rigs que vê. Só mexe em C0 (não replica; é visual).

	API: RigAnimController.Pulse(model, strength?) — strength 1 = soco, 2 = habilidade pesada
	     RigAnimController.Pose(model, id)        — pose de HABILIDADE (Devour/Crush/FleshWave/Frenzy),
	                                                 curva no tempo definida em POSES; ids desconhecidos = Pulse(2)
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RigAnimController = {}

type RigAnim = { model: Model, root: BasePart, motors: { [string]: Motor6D }, base: { [string]: CFrame }, phase: number, pulseAt: number, pulseStrength: number, poseId: string?, poseAt: number }

-- Poses de habilidade: função (t em segundos desde o início, set) que aplica offsets NOS MOTORES por cima
-- da animação base; retorna false quando acabou. `ease` = 0→1 suave.
local function ease(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
type Setter = (name: string, cf: CFrame) -> ()
local POSES: { [string]: (t: number, set: Setter) -> boolean } = {
	-- Devorar: investida — corpo baixa e estica, cone abre a boca (levanta) e depois crava para a frente
	Devour = function(t, set)
		if t > 0.9 then
			return false
		end
		local open = ease(t / 0.15) * (1 - ease((t - 0.35) / 0.2)) -- abre até 0,35 s, fecha em 0,55
		local lunge = ease((t - 0.1) / 0.3) * (1 - ease((t - 0.6) / 0.3))
		set("Root", CFrame.new(0, -0.6 * lunge, -1.6 * lunge) * CFrame.Angles(-0.18 * lunge, 0, 0))
		set("Cone", CFrame.Angles(0.5 * open - 0.7 * lunge, 0, 0))
		set("LimbFL", CFrame.new(0, 0, -1.4 * lunge))
		set("LimbFR", CFrame.new(0, 0, -1.4 * lunge))
		set("Tail", CFrame.Angles(-0.5 * lunge, 0, 0))
		return true
	end,
	-- Esmagar: EMPINA (0–0,45 s) e DESABA (0,45–0,7 s) com quique
	Crush = function(t, set)
		if t > 1.1 then
			return false
		end
		local rear = ease(t / 0.45) * (1 - ease((t - 0.45) / 0.12))
		local slam = ease((t - 0.45) / 0.12) * (1 - ease((t - 0.7) / 0.4))
		set("Root", CFrame.new(0, 3.2 * rear - 0.9 * slam, 0.6 * rear) * CFrame.Angles(0.75 * rear - 0.15 * slam, 0, 0))
		set("Cone", CFrame.Angles(0.35 * rear - 0.5 * slam, 0, 0))
		set("LimbFL", CFrame.new(0, 2.0 * rear, -0.8 * rear) * CFrame.Angles(-0.6 * rear, 0, 0))
		set("LimbFR", CFrame.new(0, 2.0 * rear, -0.8 * rear) * CFrame.Angles(-0.6 * rear, 0, 0))
		set("Tail", CFrame.Angles(0.6 * rear - 0.3 * slam, 0, 0))
		return true
	end,
	-- Onda de Carne: INFLA (sobe/encolhe as patas, 0–0,6 s) e ESTOURA (patas abrem, cauda chicoteia)
	FleshWave = function(t, set)
		if t > 1.3 then
			return false
		end
		local inflate = ease(t / 0.6) * (1 - ease((t - 0.65) / 0.1))
		local burst = ease((t - 0.65) / 0.1) * (1 - ease((t - 0.85) / 0.45))
		local wobble = math.sin(t * 40) * 0.05 * inflate
		set("Root", CFrame.new(0, 1.4 * inflate - 0.5 * burst, 0) * CFrame.Angles(wobble, 0, -wobble))
		set("Cone", CFrame.Angles(-0.25 * inflate + 0.3 * burst, 0, 0))
		set("LimbFL", CFrame.new(-1.6 * burst + 0.6 * inflate, 0.8 * inflate, -0.8 * burst) * CFrame.Angles(0, 0, 0.5 * burst))
		set("LimbFR", CFrame.new(1.6 * burst - 0.6 * inflate, 0.8 * inflate, -0.8 * burst) * CFrame.Angles(0, 0, -0.5 * burst))
		set("LimbBL", CFrame.new(-1.6 * burst + 0.6 * inflate, 0.8 * inflate, 0.8 * burst) * CFrame.Angles(0, 0, 0.5 * burst))
		set("LimbBR", CFrame.new(1.6 * burst - 0.6 * inflate, 0.8 * inflate, 0.8 * burst) * CFrame.Angles(0, 0, -0.5 * burst))
		set("Tail", CFrame.Angles(-0.4 * inflate + 0.9 * burst, math.sin(t * 25) * 0.4 * burst, 0))
		return true
	end,
	-- Frenesi: mordidas rápidas (8 × 0,22 s) girando o corpo de um lado para o outro
	Frenzy = function(t, set)
		if t > 2.2 then
			return false
		end
		local on = 1 - ease((t - 1.9) / 0.3)
		local chomp = math.abs(math.sin(t * math.pi / 0.22)) -- 1 mordida por hit
		local sway = math.sin(t * 6) * 0.35
		set("Root", CFrame.new(0, -0.3 * chomp * on, -0.6 * chomp * on) * CFrame.Angles(-0.1 * chomp * on, sway * on, 0))
		set("Cone", CFrame.Angles((0.45 - 0.9 * chomp) * on, 0, math.sin(t * 12) * 0.12 * on))
		set("LimbFL", CFrame.new(0, 0.5 * chomp * on, -0.9 * chomp * on))
		set("LimbFR", CFrame.new(0, 0.5 * (1 - chomp) * on, -0.9 * (1 - chomp) * on))
		set("Tail", CFrame.Angles(0.3 * chomp * on, -sway * 1.5 * on, 0))
		return true
	end,
}
local rigs: { [Model]: RigAnim } = {}

local function trackRig(model: Model)
	if rigs[model] or model:GetAttribute("BossRig") == nil then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local anim: RigAnim = { model = model, root = root, motors = {}, base = {}, phase = math.random() * 6, pulseAt = -10, pulseStrength = 1, poseId = nil, poseAt = 0 }
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

--- Pose de habilidade (ver POSES). Id sem pose = pulso forte.
function RigAnimController.Pose(model: Model, id: string)
	if not POSES[id] then
		RigAnimController.Pulse(model, 2)
		return
	end
	local a = rigs[model]
	if not a then
		trackRig(model)
		a = rigs[model]
	end
	if a then
		a.poseId = id
		a.poseAt = os.clock()
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
		-- pose de habilidade por cima (multiplica o C0 já calculado)
		local poseFn = if a.poseId then POSES[a.poseId] else nil
		if poseFn then
			local function setPose(name: string, cf: CFrame)
				local m = a.motors[name]
				if m then
					m.C0 = m.C0 * cf
				end
			end
			if not poseFn(t - a.poseAt, setPose) then
				a.poseId = nil
			end
		end
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
