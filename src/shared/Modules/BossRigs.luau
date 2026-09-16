--!strict
--[[
	BossRigs
	Bosses construídos com PEÇAS do próprio Roblox (Ball/Cylinder/Block), no estilo dos modelos do
	Jujutsu Shenanigans: nada de mesh externo, rig simples (HumanoidRootPart + Motor6D por membro,
	WeldConstraint dentro de cada membro). Roda no servidor (personagem/NPC) e no cliente (preview).

	Decisão do dono (2026-09-16): o jogo foca em JoJo; primeiro boss = Notorious B.I.G. (Stand de
	Carne Hirose): cone listrado azul/branco, massa de carne rosa, dois olhos amarelos "de grade",
	quatro barris listrados como patas, cauda de carne.

	Estrutura do Model (todas as partes são filhas DIRETAS do Model — a Hitbox exige):
	  HumanoidRootPart (invisível, colide) → Motor6D "Root" → Torso (massa de carne, centro do corpo)
	  Torso → Motor6D "Cone" → Head (base do cone; segmentos/olhos/boca soldados nela)
	  Torso → Motor6D "LimbFL"/"LimbFR"/"LimbBL"/"LimbBR" → barris
	  Torso → Motor6D "Tail" → cauda
	Os Motor6D têm nomes próprios (não "Neck"/"RootJoint") de propósito: animações R6 dos jogadores
	não mexem neles; a animação é PROCEDURAL no cliente (BossController.animateRigs) usando o
	atributo do Model: BossRig = "NotoriousBIG".

	API: BossRigs.Build(id: string, scale: number?) -> Model (Humanoid R6, HRP, atributos BossRig/HitboxScale)
	     BossRigs.Ids -> { "NotoriousBIG" }
]]

local BossRigs = {}

BossRigs.Ids = { "NotoriousBIG" }

-- ---------------------------------------------------------------------------
-- Helpers de construção
-- ---------------------------------------------------------------------------

local SMOOTH = Enum.Material.SmoothPlastic

local function basePart(model: Model, name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or SMOOTH
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = true
	p.CastShadow = true
	p.Anchored = false
	p.Massless = true
	p.Parent = model
	return p
end

local function ball(model: Model, name: string, diameter: number, pos: Vector3, color: Color3, material: Enum.Material?): Part
	return basePart(model, name, Enum.PartType.Ball, Vector3.new(diameter, diameter, diameter), CFrame.new(pos), color, material)
end

--- Cilindro cujo EIXO aponta na direção `axis` (o eixo nativo do Cylinder é X).
local function cylinder(model: Model, name: string, radius: number, length: number, pos: Vector3, axis: Vector3, color: Color3, material: Enum.Material?): Part
	local look = CFrame.lookAt(pos, pos + axis.Unit)
	local cf = look * CFrame.Angles(0, math.rad(90), 0) -- X do cilindro = LookVector
	return basePart(model, name, Enum.PartType.Cylinder, Vector3.new(length, radius * 2, radius * 2), cf, color, material)
end

local function block(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return basePart(model, name, Enum.PartType.Block, size, cf, color, material)
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

--- Motor6D entre part0 e part1 mantendo as posições atuais (C0 = offset relativo).
local function motor(name: string, part0: BasePart, part1: BasePart): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	m.C1 = CFrame.new()
	m.Parent = part0
	return m
end

-- ---------------------------------------------------------------------------
-- Notorious B.I.G.
-- ---------------------------------------------------------------------------

local BLUE = Color3.fromRGB(92, 124, 214)
local WHITE = Color3.fromRGB(236, 238, 244)
local FLESH = Color3.fromRGB(196, 66, 108)
local FLESH_LIGHT = Color3.fromRGB(224, 104, 140)
local FLESH_DARK = Color3.fromRGB(160, 44, 88)
local YELLOW = Color3.fromRGB(240, 196, 48)
local DARK = Color3.fromRGB(28, 20, 24)
local TOOTH = Color3.fromRGB(240, 236, 220)

-- Blobs de carne em volta do núcleo: (x, y, z, diâmetro, tom). Espelhados à mão para ficar "gordo" e assimétrico.
local BLOBS = {
	{ -3.2, 1.8, 1.2, 4.6, 1 }, { 3.4, 2.0, 0.8, 4.2, 2 }, { 0.4, 3.6, 1.6, 4.0, 1 }, { -1.8, 3.4, -1.0, 3.4, 3 },
	{ 2.2, 3.2, -1.6, 3.6, 1 }, { -4.2, -0.6, -1.4, 4.4, 2 }, { 4.4, -0.4, -1.2, 4.0, 1 }, { -2.6, -1.4, 3.6, 4.4, 3 },
	{ 2.8, -1.2, 3.8, 4.2, 1 }, { 0.2, 0.8, 4.6, 4.6, 2 }, { -0.8, -2.2, 1.0, 4.0, 3 }, { 1.4, -2.4, -1.2, 3.6, 1 },
	{ -3.8, 2.6, 3.2, 3.0, 2 }, { 4.0, 2.4, 3.4, 2.8, 3 }, { 0.6, 4.8, 3.6, 2.4, 2 }, { -1.2, 1.2, -3.8, 3.0, 1 },
	{ 1.6, 0.4, -4.2, 2.8, 3 }, { -4.6, 1.2, -3.4, 2.4, 1 }, { 4.8, 1.0, -3.2, 2.2, 2 },
}
local TONES = { FLESH, FLESH_LIGHT, FLESH_DARK }

local function buildNotoriousBIG(scale: number): Model
	local S = scale
	local model = Instance.new("Model")
	model.Name = "NotoriousBIG"

	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x * S, y * S, z * S)
	end

	-- raiz (invisível, é a única que colide)
	local root = block(model, "HumanoidRootPart", v(9, 7, 11), CFrame.new(0, 0, 0), Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.CastShadow = false

	-- núcleo de carne
	local torso = ball(model, "Torso", 9.5 * S, v(0, 0.2, 0.6), FLESH)
	for i, b in BLOBS do
		local blob = ball(model, "Flesh" .. i, b[4] * S, v(b[1], b[2], b[3]), TONES[b[5]])
		weld(torso, blob)
	end

	-- cone listrado (cabeça): 9 segmentos apontando para cima/frente
	local dir = Vector3.new(0, math.sin(math.rad(38)), -math.cos(math.rad(38))).Unit
	local base = v(0, 1.4, -3.0)
	local head: Part? = nil
	local SEG = 9
	for i = 0, SEG - 1 do
		local t = i / SEG
		local radius = (5.4 * (1 - t) + 0.55) * S
		local length = 1.35 * S
		local center = base + dir * (i * 1.3 * S + length / 2)
		local color = if i % 2 == 0 then BLUE else WHITE
		local seg = cylinder(model, if i == 0 then "Head" else "Cone" .. i, radius, length, center, dir, color)
		if i == 0 then
			head = seg
		else
			weld(head :: Part, seg)
		end
	end
	-- ponta
	local tip = ball(model, "ConeTip", 1.0 * S, base + dir * (SEG * 1.3 * S + 0.3 * S), BLUE)
	weld(head :: Part, tip)

	-- olhos amarelos "de grade" na frente/baixo do cone
	for side, name in { [-1] = "EyeL", [1] = "EyeR" } do
		local eyePos = v(side * 2.3, -0.2, -7.6)
		local eye = cylinder(model, name, 1.35 * S, 0.7 * S, eyePos, Vector3.new(0, 0, -1), YELLOW, Enum.Material.Neon)
		weld(head :: Part, eye)
		for k = -1, 1 do
			local bar = block(model, name .. "Bar" .. (k + 2), v(0.2, 2.3, 0.22), CFrame.new(eyePos + v(k * 0.62, 0, -0.32)), DARK)
			weld(head :: Part, bar)
		end
	end
	-- boca (bloco escuro + dentes)
	local mouth = block(model, "Mouth", v(4.0, 1.3, 0.8), CFrame.new(v(0, -2.2, -7.0)), DARK)
	weld(head :: Part, mouth)
	for k = -2, 1 do
		local tooth = block(model, "Tooth" .. (k + 3), v(0.62, 0.7, 0.5), CFrame.new(v(k * 0.85 + 0.42, -1.95, -7.3)), TOOTH)
		weld(head :: Part, tooth)
	end

	-- patas: 4 barris listrados deitados (eixo para a frente), abertos para fora
	local limbs: { [string]: Part } = {}
	type LimbDef = { name: string, x: number, z: number, yaw: number }
	local limbDefs: { LimbDef } = {
		{ name = "LimbFL", x = -6.0, z = -3.6, yaw = -18 },
		{ name = "LimbFR", x = 6.0, z = -3.6, yaw = 18 },
		{ name = "LimbBL", x = -5.6, z = 3.6, yaw = -8 },
		{ name = "LimbBR", x = 5.6, z = 3.6, yaw = 8 },
	}
	for _, def in limbDefs do
		local name, lx, lz, yaw = def.name, def.x, def.z, def.yaw
		local axis = CFrame.Angles(0, math.rad(yaw), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
		local center = v(lx, -2.5, lz)
		local mid: Part? = nil
		for i = -1, 1 do
			local seg = cylinder(model, name .. (if i == 0 then "" else "Seg" .. (i + 2)), 1.9 * S, 1.35 * S, center + axis * (i * 1.35 * S), axis, if i == 0 then WHITE else BLUE)
			if i == 0 then
				mid = seg
			else
				weld(mid :: Part, seg)
			end
		end
		local cap = cylinder(model, name .. "Cap", 1.55 * S, 0.5 * S, center + axis * (2.2 * S), axis, WHITE)
		weld(mid :: Part, cap)
		limbs[name] = mid :: Part
	end

	-- cauda de carne subindo para trás
	local tailFirst: Part? = nil
	for i, t in { { 0.0, 1.6, 6.8, 3.2 }, { 0.6, 3.0, 9.2, 2.6 }, { 1.3, 4.5, 11.2, 2.1 }, { 2.1, 5.9, 12.8, 1.6 }, { 2.9, 7.0, 14.0, 1.1 } } do
		local seg = ball(model, "Tail" .. i, t[4] * S, v(t[1], t[2], t[3]), if i % 2 == 0 then FLESH_LIGHT else FLESH_DARK)
		if i == 1 then
			tailFirst = seg
		else
			weld(tailFirst :: Part, seg)
		end
	end

	-- juntas
	motor("Root", root, torso)
	motor("Cone", torso, head :: Part)
	for name, part in limbs do
		motor(name, torso, part)
	end
	motor("Tail", torso, tailFirst :: Part)

	-- humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.HipHeight = 0.9 * S -- fundo do HRP (−3,5) até o chão (fundo dos barris −4,4)
	humanoid.AutoRotate = true
	humanoid.BreakJointsOnDeath = false
	humanoid.CameraOffset = Vector3.new(0, 6 * S, 0)
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid

	model.PrimaryPart = root
	model:SetAttribute("BossRig", "NotoriousBIG")
	model:SetAttribute("HitboxScale", 2.2 * S)
	model:SetAttribute("RigScale", S)
	return model
end

local builders: { [string]: (number) -> Model } = {
	NotoriousBIG = buildNotoriousBIG,
}

--- Monta o rig do boss `id` (escala 1 = ~15 studs de largura, ~13 de altura com o cone).
function BossRigs.Build(id: string, scale: number?): Model
	local builder = builders[id]
	assert(builder, ("BossRigs: rig desconhecido '%s'"):format(id))
	return builder(scale or 1)
end

--- Altura do chão até o centro do HRP no rig `id` (para posicionar ao nascer).
function BossRigs.RootHeight(id: string, scale: number?): number
	local S = scale or 1
	if id == "NotoriousBIG" then
		return 4.4 * S
	end
	return 3 * S
end

return BossRigs
