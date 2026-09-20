--!strict
--[[
	StandSilhouette (cliente)
	B4 (dono, 2026-09-24): o Stand NUNCA é um modelo — é uma SILHUETA de luz (peças neon translúcidas em forma
	de R6, maior que o jogador, com a cor do personagem) que flutua atrás/acima do ombro.
	B5 (dono, 2026-09-25): a silhueta é ANIMADA de verdade — rig procedural com cinemática direta usando as
	mesmas convenções de pose do RigPose e os clipes `Stand/Idle|Enter|Exit|Punch` do ProcAnimDefs:
	  - entrada: surge encolhido de trás do ombro (escala + fade) e abre;
	  - idle: flutua respirando, braços cruzados;
	  - rajada (ORA/MUDA): braços socando alternados no ritmo do Interval, tronco inclinado, pernas para trás;
	  - saída: dissolve subindo.
	  - SEGUE o jogador com suavização (posição e rotação com atraso), inclinando na direção do movimento.
	  - proporção por personagem: AwakeningDefs.Stand (StandStyle: Scale/Torso/Arms/Legs/Head/Ears/Anchor).
	Só efeito local: cada cliente monta a própria silhueta em Workspace.CurrentCamera (não replica).
	API: Show(character, color, seconds, { punch = bool?, rate = number?, scale = number?, style = StandStyle? })
	     Hide(character)
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ProcAnimDefs = require(script.Parent:WaitForChild("ProcAnimDefs"))
local AwakeningDefs = require(script.Parent:WaitForChild("AwakeningDefs"))

local StandSilhouette = {}

type Style = AwakeningDefs.StandStyle
type Opts = { punch: boolean?, rate: number?, scale: number?, style: Style? }
type Parts = { [string]: BasePart }
type Entry = {
	model: Model,
	parts: Parts,
	conn: RBXScriptConnection,
	alive: boolean,
	exiting: boolean,
	exitAt: number,
}
local active: { [Model]: Entry } = {}

local ENTER = ProcAnimDefs.Get("Stand/Enter")
local IDLE = ProcAnimDefs.Get("Stand/Idle")
local EXIT = ProcAnimDefs.Get("Stand/Exit")
local PUNCH = ProcAnimDefs.Get("Stand/Punch")

local DEFAULT_ANCHOR = Vector3.new(-0.9, 1.6, 2.6) -- idle: atrás, um pouco à esquerda e acima do ombro
local PUNCH_ANCHOR = Vector3.new(1.5, 1.1, -1.0) -- rajada: ao lado direito e um pouco À FRENTE (os punhos alcançam o Offset da rajada)
local TRANSPARENCY = 0.5
local FOLLOW_POS = 9 -- 1/s: quanto maior, mais colado (posição)
local FOLLOW_ROT = 6 -- 1/s (rotação)
local EXIT_SECONDS = 0.35

-- pivôs das juntas e centros das peças no espaço do TRONCO (R6 base, sem escala)
local PIVOT = {
	Neck = Vector3.new(0, 1, 0),
	["Right Shoulder"] = Vector3.new(1, 0.5, 0),
	["Left Shoulder"] = Vector3.new(-1, 0.5, 0),
	["Right Hip"] = Vector3.new(0.5, -1, 0),
	["Left Hip"] = Vector3.new(-0.5, -1, 0),
}
local LIMB_JOINT: { [string]: string } = {
	Head = "Neck",
	RightArm = "Right Shoulder",
	LeftArm = "Left Shoulder",
	RightLeg = "Right Hip",
	LeftLeg = "Left Hip",
}

type Dims = { torsoW: number, torsoD: number, arm: number, armLen: number, leg: number, legLen: number, head: number }

local function dims(style: Style?): Dims
	local st: Style = style or {}
	local torso = st.Torso or 1
	local arms = st.Arms or 1
	local legs = st.Legs or 1
	return {
		torsoW = torso,
		torsoD = 0.6 + 0.4 * torso,
		arm = arms,
		armLen = 1 + 0.15 * (arms - 1),
		leg = 0.9 + 0.1 * legs,
		legLen = legs,
		head = st.Head or 1,
	}
end

local function angles(rot: Vector3): CFrame
	return CFrame.fromEulerAnglesXYZ(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
end

--- Cinemática direta: coloca cada peça a partir de `base` (CFrame do tronco "neutro") e da pose.
local function applyPose(parts: Parts, d: Dims, scale: number, base: CFrame, pose: ProcAnimDefs.Pose, sizeMul: number)
	local rootJ = pose.RootJoint
	local torsoCF = base * CFrame.new((rootJ and rootJ.off or Vector3.zero) * scale) * angles(rootJ and rootJ.rot or Vector3.zero)
	parts.Torso.CFrame = torsoCF
	parts.Torso.Size = Vector3.new(2 * d.torsoW, 2, d.torsoD) * scale * sizeMul

	-- centro de cada peça no espaço do tronco (já com a largura do tronco/braço)
	local armX = d.torsoW + 0.5 * d.arm
	local centers: { [string]: Vector3 } = {
		Head = Vector3.new(0, 1 + 0.65 * d.head, 0),
		RightArm = Vector3.new(armX, 1 - d.armLen, 0),
		LeftArm = Vector3.new(-armX, 1 - d.armLen, 0),
		RightLeg = Vector3.new(0.5, -1 - d.legLen, 0),
		LeftLeg = Vector3.new(-0.5, -1 - d.legLen, 0),
	}
	local sizes: { [string]: Vector3 } = {
		Head = Vector3.new(1.3, 1.3, 1.3) * d.head,
		RightArm = Vector3.new(d.arm, 2 * d.armLen, d.arm),
		LeftArm = Vector3.new(d.arm, 2 * d.armLen, d.arm),
		RightLeg = Vector3.new(d.leg, 2 * d.legLen, d.leg),
		LeftLeg = Vector3.new(d.leg, 2 * d.legLen, d.leg),
	}
	for name, jointName in LIMB_JOINT do
		local p = parts[name]
		local pivot = PIVOT[jointName]
		if jointName == "Right Shoulder" then
			pivot = Vector3.new(d.torsoW, 0.5, 0)
		elseif jointName == "Left Shoulder" then
			pivot = Vector3.new(-d.torsoW, 0.5, 0)
		end
		local jp = pose[jointName]
		local rot = (jp and jp.rot) or Vector3.zero
		p.CFrame = torsoCF * CFrame.new(pivot * scale) * angles(rot) * CFrame.new((centers[name] - pivot) * scale)
		p.Size = sizes[name] * scale * sizeMul
	end
	-- orelhas de gato (Killer Queen): duas peças nos cantos de cima da cabeça, inclinadas para fora
	for side, name in { [1] = "EarR", [-1] = "EarL" } do
		local ear = parts[name]
		if ear then
			ear.CFrame = parts.Head.CFrame * CFrame.new(side * 0.45 * d.head * scale, 0.8 * d.head * scale, 0) * CFrame.Angles(0, 0, math.rad(-side * 18))
			ear.Size = Vector3.new(0.35, 0.6, 0.3) * d.head * scale * sizeMul
		end
	end
end

local function build(color: Color3, style: Style?): (Model, Parts)
	local model = Instance.new("Model")
	model.Name = "StandSilhouette"
	local parts: Parts = {}
	local names = { "Head", "Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg" }
	if style and style.Ears then
		table.insert(names, "EarR")
		table.insert(names, "EarL")
	end
	for _, name in names do
		local p = Instance.new("Part")
		p.Name = name
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = model
		parts[name] = p
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.6
	light.Range = 12
	light.Parent = parts.Torso
	return model, parts
end

local function setTransparency(parts: Parts, value: number)
	for _, p in parts do
		p.Transparency = value
	end
end

local function finish(character: Model, e: Entry)
	if active[character] == e then
		active[character] = nil
	end
	e.alive = false
	e.conn:Disconnect()
	e.model:Destroy()
end

--- Some com a silhueta (toca a saída: dissolve subindo).
function StandSilhouette.Hide(character: Model)
	local e = active[character]
	if not e or e.exiting then
		return
	end
	e.exiting = true
	e.exitAt = os.clock()
	task.delay(EXIT_SECONDS + 0.05, function()
		finish(character, e)
	end)
end

--- Mostra a silhueta por `seconds` (renova se já estiver visível).
--- punch = braços socando (rajadas); rate = segundos entre golpes (Interval); style = proporção do Stand.
function StandSilhouette.Show(character: Model, color: Color3, seconds: number, opts: Opts?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not IDLE or not ENTER or not EXIT or not PUNCH then
		return
	end
	local o: Opts = opts or {}
	local old = active[character]
	if old then
		finish(character, old)
	end
	local style = o.style
	local d = dims(style)
	local scale = ((style and style.Scale) or 1.3) * (o.scale or 1)
	local punch = o.punch == true
	local anchor = CFrame.new(if punch then PUNCH_ANCHOR else ((style and style.Anchor) or DEFAULT_ANCHOR))
	local model, parts = build(color, style)
	model.Parent = Workspace.CurrentCamera

	local t0 = os.clock()
	local punchSpeed = if punch then PUNCH.duration / (2 * math.max(0.04, o.rate or 0.12)) else 1
	local e: Entry
	local followCF: CFrame = root.CFrame * anchor -- começa no lugar (sem "voar" até o jogador)
	local lastTick = t0

	local conn = RunService.RenderStepped:Connect(function()
		if not e.alive or not root.Parent then
			return
		end
		local now = os.clock()
		local dt = math.min(now - lastTick, 0.1)
		lastTick = now
		local t = now - t0

		-- seguimento suavizado: posição atrasa um pouco; rotação vira devagar; inclina na direção do movimento
		local target = root.CFrame * anchor
		local vel = root.AssemblyLinearVelocity
		local horiz = Vector3.new(vel.X, 0, vel.Z)
		if horiz.Magnitude > 1 then
			local localDir = root.CFrame:VectorToObjectSpace(horiz.Unit)
			local lean = math.min(horiz.Magnitude / 40, 1) * 12
			target = target * CFrame.Angles(math.rad(localDir.Z * lean), 0, math.rad(-localDir.X * lean))
		end
		local aPos = 1 - math.exp(-dt * FOLLOW_POS)
		local aRot = 1 - math.exp(-dt * FOLLOW_ROT)
		local pos = followCF.Position:Lerp(target.Position, aPos)
		followCF = (followCF - followCF.Position):Lerp(target - target.Position, aRot) + pos
		local bob = math.sin(t * 2.0) * 0.12 * scale
		local base = followCF * CFrame.new(0, bob, 0)

		-- clipe atual + entrada/saída (escala e transparência por cima)
		local pose: ProcAnimDefs.Pose
		local sizeMul = 1
		local alphaVis = 1
		if e.exiting then
			local x = math.clamp((now - e.exitAt) / EXIT_SECONDS, 0, 1)
			pose = ProcAnimDefs.Sample(EXIT, x * EXIT.duration)
			sizeMul = 1 + 0.2 * x
			alphaVis = 1 - x * x
		elseif t < ENTER.duration then
			pose = ProcAnimDefs.Sample(ENTER, t)
			local x = t / ENTER.duration
			local back = 1 + 2.2 * (x - 1) * (x - 1) * (x - 1) + 1.2 * (x - 1) * (x - 1) -- Back.Out
			sizeMul = 0.45 + 0.55 * back
			alphaVis = math.min(1, x * 1.6)
			if punch then
				-- na rajada a entrada é mais curta: já mistura o soco
				pose = ProcAnimDefs.Sample(PUNCH, t * punchSpeed)
			end
		elseif punch then
			pose = ProcAnimDefs.Sample(PUNCH, t * punchSpeed)
		else
			pose = ProcAnimDefs.Sample(IDLE, t)
		end
		applyPose(parts, d, scale, base, pose, sizeMul)
		setTransparency(parts, 1 - (1 - TRANSPARENCY) * alphaVis)
	end)
	e = { model = model, parts = parts, conn = conn, alive = true, exiting = false, exitAt = 0 }
	active[character] = e

	task.delay(seconds, function()
		if active[character] == e then
			StandSilhouette.Hide(character)
		end
	end)
	character.AncestryChanged:Once(function()
		if active[character] == e then
			finish(character, e)
		end
	end)
end

return StandSilhouette
