--!strict
--[[
	VFXLibrary
	Efeitos COMPOSTOS por código (estilo JJS): meshes de choque/vento/impacto + rajadas de partículas +
	luz, montados na hora a partir de ids. Nada disto depende de Folder/Model no place: os ids das meshes e
	das texturas vieram do pack que o dono puxou (Workspace.Efeitos "EFEITOS 2" + Auras, lidos via MCP em
	2026-09-16) e dos packs antigos; os efeitos de partícula dos packs antigos continuam disponíveis via
	camada { kind = "pack", path = "Packs/..." } (Assets.VFXPack).

	Como usar: FX.SpawnVFX(character, folder, name) procura primeiro VFXLibrary.Effects[folder.."/"..name];
	se existir, toca a composição (FX.PlayComposed). Cores "$primary"/"$secondary" viram a cor do personagem
	(CharacterDefs.Color) — a mesma receita serve para todos; efeitos Shared usam a cor de quem fez.

	Camadas (tabela com kind):
	  mesh  { mesh, color, material?, size0, size1, t, offset?: CFrame, spin?: Vector3 (graus/s), tr0?, tr1?,
	          ease?, delay?, ground? (encosta no chão), up? (eixo Y do mesh = vertical), camera? (olha a câmera) }
	  emit  { texture, color | colorSeq, count, size (n|{a,b}|seq), life {a,b}, speed {a,b}, spread {x,y}?,
	          rot?, rotSpeed?, light?, accel?, drag?, orient?, shape?, flipbook? { layout, mode, fps, fps2 }, zOffset?, delay?, offset?: Vector3,
	          follow? (emissor no HRP, some no fim), duration? (emissão contínua por N s em vez de rajada) }
	  light { color, brightness, range, t, delay?, offset? }
	  pack  { path (Assets.VFXPack: "Packs/..."), delay? }     -- reaproveita VFX dos packs antigos
	  sound { folder, name, delay? }
	Efeito: { lifetime?: number, layers: { camada } }
]]

local VFXLibrary = {}

-- ---------------------------------------------------------------------------
-- Meshes (id, tamanho nativo em studs — SpecialMesh.Scale = tamanho desejado / nativo)
-- ---------------------------------------------------------------------------
export type MeshDef = { id: number, size: Vector3 }
local function M(id: number, x: number, y: number, z: number): MeshDef
	return { id = id, size = Vector3.new(x, y, z) }
end

VFXLibrary.Meshes = {
	-- ondas de choque (a família 5697180xxx é a clássica dos battlegrounds; z = quão "fechada" a curva)
	ShockCurl = M(5697180395, 7.7, 3.5, 6.5),
	ShockOpen = M(5697180926, 7.7, 3.5, 6.5),
	ShockTall = M(5697180789, 9.5, 3.5, 3.2),
	ShockMid = M(5697180531, 9.5, 3.5, 1.5),
	ShockFlat = M(5697179849, 9.5, 3.5, 1.0),
	ShockGround = M(5769820604, 1.4, 0.05, 1.0), -- anel chato no chão
	ShockRing = M(6026280813, 1.0, 0.1, 1.0), -- anel fino
	ShockInward = M(6220387416, 1.9, 2.1, 2.0),
	RingThin = M(5694662480, 7.3, 0.7, 0.7),
	RingDecal = M(2788580235, 433.7, 50, 433.7),
	-- vento / espiral
	Spiral = M(4041733635, 1, 1, 1),
	Tornado = M(5705014362, 2.3, 0.4, 2.4),
	WindGrow = M(3454554153, 10.1, 2.4, 10.0),
	Wind1 = M(4313233873, 11.5, 3.6, 11.7),
	Wind2 = M(4313235782, 9.7, 10.8, 9.7),
	WindNew = M(4461104675, 50, 6.1, 49.5),
	Swirl = M(6553284529, 2.3, 0.7, 2.4),
	SwirlWind = M(6553031952, 2.4, 3.1, 2.3),
	WindA = M(6553036976, 2.9, 3.1, 2.7),
	WindB = M(6553119537, 2.9, 1.4, 2.5),
	Air = M(6553268700, 2.4, 0.5, 2.5),
	LightWind = M(4681227436, 11.1, 8.7, 11.3),
	Whirl = M(903178515, 50, 72.2, 52.8),
	-- impacto
	Smash6 = M(489415572, 2.2, 0.5, 2.5),
	Smash8 = M(489415447, 3.0, 0.5, 3.0),
	Star3D = M(4886514859, 2, 2, 2),
	ExplosionClassic = M(1095708, 1.3, 0.7, 0.8),
	Explosion = M(6553049577, 2.4, 2.5, 2.6),
	ExplosionB = M(6553023590, 2, 2, 2),
	Explosion1 = M(3027924097, 2.3, 2.4, 2.4),
	Explosion2 = M(1254390558, 16.3, 16.3, 16.3),
	FireBall = M(6553027596, 2, 2, 2),
	FireBallB = M(6553177537, 2, 2, 2),
	-- espinhos
	Spike = M(967645205, 1.3, 2.1, 1.3),
	SpikeInverted = M(1826588507, 50, 54.2, 66),
	SpikeBig = M(2620058357, 705.1, 570.5, 670.6),
	SpikeyBall = M(3375161112, 50, 25, 50),
	-- corte
	Slash = M(4572036304, 50, 2.2, 18.4),
	SlashWide = M(2836527412, 7.2, 3.9, 14.5),
	-- esferas
	Sphere = M(5747850601, 5.0, 5.1, 5.0),
	SphereHD = M(1886703108, 6.2, 6.2, 6.1),
	SphereFancy = M(5703278366, 49.6, 50, 49.7),
	SphereWind = M(5703242100, 49.6, 50, 49.6),
	-- raio / glitch
	Thunder = M(6553232712, 3.1, 17.9, 3.6),
	ThunderSpark = M(6553130477, 1.8, 1.6, 2.1),
	ThunderSparkB = M(6553146627, 2.7, 1.8, 3.1),
	ShockElectric = M(903888897, 229.5, 42.7, 286),
	Glitch = M(6553110800, 2.0, 2.4, 2.2),
	GlitchBall = M(6553021063, 2, 2, 2),
	GlitchWind = M(6553151264, 2.5, 2.5, 2.6),
	-- outros
	Leaf = M(5129539702, 5.5, 1.6, 11),
	Beam = M(2865084807, 4.5, 4.5, 50),
	RingPurple = M(6494542261, 23.7, 3.8, 24),
	PoderSphere = M(15864500081, 14.3, 14.4, 14.3),
	PoderWave = M(15864632222, 50, 6.9, 50),
}

-- ---------------------------------------------------------------------------
-- Texturas de partícula (ids das Auras/EFEITOS 2 e packs)
-- ---------------------------------------------------------------------------
VFXLibrary.Textures = {
	Sparks = 8399529129,
	Shockwave = 8944351625,
	Burst = 8944185821,
	Smoke = 13001442470,
	AuraMain = 7857596636,
	BurstRing = 13001447661,
	Flare = 10435576555,
	Flare2 = 8047533775,
	Flare3 = 8133845150,
	SmokeFlip = 10034873151, -- Grid8x8 OneShot
	Shine = 13001449106,
	BurstSoft = 10205180639,
	Bits = 3074825547,
	Flame = 7216850580,
	SmokeSoft = 1084987899,
	SmokeLoop = 12026515010, -- Grid4x4 Loop
	FormAura = 6954174382,
	Lines = 10439119562,
	Flashes = 7385784437,
	SlashA = 15098067965,
	SlashFlip = 15124806555, -- Grid2x2 OneShot
	SlashGlow = 15153511168,
	Spark2 = 14960943986,
	Electric = 243098098,
	Bolt = 6770889554,
	Star = 14834478801,
	Glow = 8625703339,
	Glow2 = 1084970835,
	GroundCrack = 13784241004, -- Grid4x4 OneShot
	GroundCrack2 = 13782885260, -- Grid4x4 OneShot
	ShineSoft = 10399834408,
	Dust = 6862984716,
	Debris = 8747784536,
	Rocks = 8888843522,
	Step = 15930409331, -- Grid8x8 OneShot
	Shockwave2 = 14939528540,
	Ring1 = 10372847108,
	Ring2 = 12363807038,
	Ring3 = 11037478082,
	Bar = 14641385952,
	Specs = 10953167939,
	SmokeBig = 13677961525, -- Grid8x8 OneShot
	Field = 13280232109,
	Spark3 = 8214520142,
}

-- ---------------------------------------------------------------------------
-- Receitas (helpers para deixar as definições curtas)
-- ---------------------------------------------------------------------------
export type Layer = { [string]: any }
export type Effect = { lifetime: number?, layers: { Layer } }

local WHITE = Color3.fromRGB(255, 255, 255)
local DARK = Color3.fromRGB(20, 18, 24)
local YELLOW = Color3.fromRGB(255, 220, 90)
local RED = Color3.fromRGB(255, 70, 60)
local ORANGE = Color3.fromRGB(255, 140, 50)
local GOLD = Color3.fromRGB(255, 200, 80)
local BLUE = Color3.fromRGB(90, 170, 255)
local FLESH = Color3.fromRGB(196, 66, 108)
local NEON = Enum.Material.Neon

local function mesh(name: string, color: any, s0: number, s1: number, t: number, extra: Layer?): Layer
	local l: Layer = { kind = "mesh", mesh = name, color = color, material = NEON, size0 = s0, size1 = s1, t = t, tr0 = 0.15, tr1 = 1 }
	if extra then
		for k, v in extra do
			l[k] = v
		end
	end
	return l
end

--- Onda de choque no chão que abre (a marca registrada dos battlegrounds)
local function groundWave(color: any, s0: number, s1: number, t: number, extra: Layer?): Layer
	local l = mesh("ShockCurl", color, s0, s1, t, { ground = true, up = true, spin = Vector3.new(0, 140, 0), ease = "Quart" })
	if extra then
		for k, v in extra do
			l[k] = v
		end
	end
	return l
end

local function ringFlat(color: any, s0: number, s1: number, t: number, extra: Layer?): Layer
	local l = mesh("ShockGround", color, s0, s1, t, { ground = true, up = true, ease = "Quart", tr0 = 0.1 })
	if extra then
		for k, v in extra do
			l[k] = v
		end
	end
	return l
end

local function emit(texture: string, color: any, count: number, extra: Layer?): Layer
	local l: Layer = { kind = "emit", texture = texture, color = color, count = count, size = { 0.8, 1.6 }, life = { 0.3, 0.6 }, speed = { 8, 20 }, spread = { 180, 180 }, light = 1 }
	if extra then
		for k, v in extra do
			l[k] = v
		end
	end
	return l
end

local function light(color: any, brightness: number, range: number, t: number, extra: Layer?): Layer
	local l: Layer = { kind = "light", color = color, brightness = brightness, range = range, t = t }
	if extra then
		for k, v in extra do
			l[k] = v
		end
	end
	return l
end

local function pack(path: string, delay: number?): Layer
	return { kind = "pack", path = path, delay = delay }
end

-- pedaços reutilizáveis
local function sparks(color: any, count: number, extra: Layer?): Layer
	local l = emit("Sparks", color, count, { size = { 0.25, 0.7 }, life = { 0.25, 0.5 }, speed = { 18, 40 }, orient = "VelocityParallel", drag = 3, accel = Vector3.new(0, -30, 0) })
	if extra then
		for k, v in extra do
			l[k] = v
		end
	end
	return l
end
local function smokePuff(count: number, extra: Layer?): Layer
	local l = emit("SmokeFlip", Color3.fromRGB(140, 140, 150), count, { size = { 2, 4 }, life = { 0.5, 0.9 }, speed = { 6, 14 }, light = 0, flipbook = { layout = "Grid8x8", mode = "OneShot", fps = 14, fps2 = 23 }, rot = { -25, 25 }, rotSpeed = { -45, 45 }, drag = 4 })
	if extra then
		for k, v in extra do
			l[k] = v
		end
	end
	return l
end
local function dustRing(color: any, count: number): Layer
	return emit("Dust", color, count, { size = { 3, 6 }, life = { 0.6, 1.0 }, speed = { 12, 26 }, spread = { 0, 0 }, orient = "VelocityPerpendicular", light = 0.4, drag = 5, shape = "Disc", shapeStyle = "Surface", ground = true, rot = { 0, 360 } })
end
local function flash(color: any, size: number, t: number?): Layer
	return emit("Flashes", color, 1, { size = size, life = { t or 0.18, t or 0.18 }, speed = { 0, 0 }, light = 1, zOffset = 1, rot = { 0, 360 } })
end
local function impactStar(color: any, size: number, t: number?): Layer
	return mesh("Smash8", color, size * 0.5, size, t or 0.22, { camera = true, spin = Vector3.new(0, 0, 400), tr0 = 0, ease = "Quart" })
end

-- ---------------------------------------------------------------------------
-- EFEITOS
-- ---------------------------------------------------------------------------
local E: { [string]: Effect } = {}
VFXLibrary.Effects = E

-- ---- Socos --------------------------------------------------------------------------
-- rastro do braço nos socos 1-3 (leve), 4º mais pesado
local function swing(strength: number): Effect
	return {
		lifetime = 0.6,
		layers = {
			mesh("SlashWide", WHITE, 3 * strength, 6.5 * strength, 0.22, { offset = CFrame.new(0.8, 0.6, -2.4) * CFrame.Angles(0, math.rad(20), math.rad(-35)), tr0 = 0.45, ease = "Quad" }),
			emit("Lines", WHITE, math.floor(4 * strength), { size = { 0.6, 1.4 }, life = { 0.12, 0.2 }, speed = { 25, 40 }, spread = { 10, 10 }, orient = "VelocityParallel", offset = Vector3.new(0, 0.5, -2), direction = "forward", light = 0.6 }),
		},
	}
end
E["Shared/Swing_1"] = swing(1)
E["Shared/Swing_2"] = swing(1)
E["Shared/Swing_3"] = swing(1.15)
E["Shared/Swing_4"] = {
	lifetime = 0.8,
	layers = {
		mesh("SlashWide", WHITE, 4, 9, 0.28, { offset = CFrame.new(0.6, 0.5, -2.6) * CFrame.Angles(0, math.rad(15), math.rad(-30)), tr0 = 0.35, ease = "Quad" }),
		mesh("WindGrow", WHITE, 2, 9, 0.35, { offset = CFrame.new(0, 0.2, -2) * CFrame.Angles(math.rad(90), 0, 0), spin = Vector3.new(0, 0, 500), tr0 = 0.5 }),
		emit("Lines", WHITE, 8, { size = { 0.8, 1.8 }, life = { 0.15, 0.25 }, speed = { 30, 50 }, spread = { 12, 12 }, orient = "VelocityParallel", offset = Vector3.new(0, 0.5, -2), direction = "forward", light = 0.8 }),
	},
}
E["Shared/Uppercut"] = {
	lifetime = 0.9,
	layers = {
		mesh("Tornado", WHITE, 3, 9, 0.4, { offset = CFrame.new(0, 1, -2), up = true, spin = Vector3.new(0, 900, 0), tr0 = 0.4 }),
		mesh("SlashWide", WHITE, 3, 8, 0.25, { offset = CFrame.new(0.6, 1.5, -2.5) * CFrame.Angles(math.rad(70), 0, 0), tr0 = 0.3 }),
		emit("Lines", WHITE, 10, { size = { 0.6, 1.6 }, life = { 0.2, 0.35 }, speed = { 30, 55 }, spread = { 8, 8 }, orient = "VelocityParallel", offset = Vector3.new(0, 0, -2), direction = "up" }),
	},
}
E["Shared/Downslam"] = {
	lifetime = 1.2,
	layers = {
		groundWave("$primary", 3, 16, 0.45),
		ringFlat(WHITE, 2, 18, 0.35),
		emit("Debris", Color3.fromRGB(120, 110, 100), 14, { size = { 0.4, 1.0 }, life = { 0.5, 0.9 }, speed = { 15, 30 }, spread = { 40, 40 }, direction = "up", light = 0, accel = Vector3.new(0, -60, 0), ground = true }),
		smokePuff(10, { ground = true }),
	},
}

-- ---- Acertos ------------------------------------------------------------------------
E["Shared/Hit"] = {
	lifetime = 0.7,
	layers = {
		impactStar("$primary", 5.5, 0.2),
		flash(WHITE, 4, 0.12),
		sparks("$primary", 10),
		emit("Lines", WHITE, 6, { size = { 0.5, 1.2 }, life = { 0.12, 0.2 }, speed = { 28, 45 }, spread = { 180, 180 }, orient = "VelocityParallel" }),
		light("$primary", 3, 12, 0.25),
	},
}
E["Shared/Crit"] = {
	lifetime = 1.0,
	layers = {
		impactStar(RED, 9, 0.3),
		mesh("ShockInward", RED, 10, 2, 0.25, { camera = true, tr0 = 0.2 }),
		flash(WHITE, 7, 0.15),
		sparks(RED, 24),
		emit("Lines", RED, 12, { size = { 0.6, 1.6 }, life = { 0.15, 0.3 }, speed = { 40, 70 }, orient = "VelocityParallel" }),
		light(RED, 6, 18, 0.4),
	},
}
E["Shared/BlackFlash"] = {
	lifetime = 1.6,
	layers = {
		flash(DARK, 12, 0.25),
		mesh("ShockInward", DARK, 16, 3, 0.35, { camera = true, tr0 = 0.1 }),
		impactStar(RED, 12, 0.4),
		mesh("Sphere", RED, 1, 14, 0.45, { tr0 = 0.3, ease = "Quart" }),
		emit("Lines", RED, 24, { size = { 0.8, 2.2 }, life = { 0.2, 0.4 }, speed = { 50, 90 }, orient = "VelocityParallel", light = 1 }),
		emit("Lines", DARK, 24, { size = { 0.8, 2.2 }, life = { 0.2, 0.4 }, speed = { 50, 90 }, orient = "VelocityParallel", light = 0 }),
		sparks(RED, 30),
		light(RED, 8, 24, 0.6),
		pack("Packs/OfficialJJS/Hakari/RoughImpact"),
	},
}
E["Shared/FinisherHit"] = {
	lifetime = 1.3,
	layers = {
		impactStar("$primary", 9, 0.3),
		mesh("ShockOpen", WHITE, 3, 14, 0.4, { camera = true, tr0 = 0.3, ease = "Quart" }),
		flash(WHITE, 8, 0.15),
		sparks("$primary", 24),
		emit("Lines", WHITE, 14, { size = { 0.7, 1.8 }, life = { 0.15, 0.3 }, speed = { 45, 80 }, orient = "VelocityParallel" }),
		smokePuff(8),
		light("$primary", 6, 20, 0.45),
	},
}
E["Shared/Finisher"] = { -- rastro do 4º soco (no atacante)
	lifetime = 0.8,
	layers = {
		mesh("Wind1", WHITE, 2, 10, 0.35, { offset = CFrame.new(0, 0, -2) * CFrame.Angles(math.rad(90), 0, 0), spin = Vector3.new(0, 0, 400), tr0 = 0.45 }),
		emit("Lines", WHITE, 10, { size = { 0.8, 1.8 }, life = { 0.15, 0.25 }, speed = { 30, 50 }, spread = { 12, 12 }, orient = "VelocityParallel", offset = Vector3.new(0, 0.5, -2), direction = "forward" }),
	},
}
E["Shared/WallSplat"] = {
	lifetime = 1.6,
	layers = {
		mesh("ShockFlat", Color3.fromRGB(200, 195, 190), 4, 18, 0.45, { camera = true, tr0 = 0.2 }),
		emit("GroundCrack", Color3.fromRGB(230, 225, 215), 1, { size = 14, life = { 0.9, 0.9 }, speed = { 0, 0 }, flipbook = { layout = "Grid4x4", mode = "OneShot", fps = 32, fps2 = 32 }, light = 0, orient = "FacingCamera", zOffset = 0.5 }),
		emit("Debris", Color3.fromRGB(130, 125, 120), 18, { size = { 0.4, 1.1 }, life = { 0.6, 1.0 }, speed = { 15, 35 }, light = 0, accel = Vector3.new(0, -60, 0) }),
		smokePuff(12),
		flash(WHITE, 8, 0.12),
		light(WHITE, 4, 16, 0.3),
	},
}
E["Shared/Block"] = {
	lifetime = 0.6,
	layers = {
		mesh("ShockRing", BLUE, 3, 7, 0.25, { offset = CFrame.new(0, 0.5, -1.5) * CFrame.Angles(math.rad(90), 0, 0), tr0 = 0.2 }),
		emit("Sparks", BLUE, 10, { size = { 0.2, 0.5 }, life = { 0.2, 0.4 }, speed = { 10, 25 }, spread = { 60, 60 }, orient = "VelocityParallel", offset = Vector3.new(0, 0.5, -1.5), direction = "forward" }),
		light(BLUE, 2, 10, 0.2),
	},
}
E["Shared/Parry"] = {
	lifetime = 1.0,
	layers = {
		mesh("ShockRing", YELLOW, 2, 14, 0.35, { offset = CFrame.new(0, 0.5, -1.5) * CFrame.Angles(math.rad(90), 0, 0), tr0 = 0, ease = "Quart" }),
		mesh("ShockInward", YELLOW, 12, 2, 0.3, { camera = true, tr0 = 0.2 }),
		flash(WHITE, 8, 0.15),
		emit("Sparks", YELLOW, 24, { size = { 0.3, 0.8 }, life = { 0.3, 0.6 }, speed = { 25, 50 }, orient = "VelocityParallel", drag = 3 }),
		emit("Lines", WHITE, 12, { size = { 0.6, 1.4 }, life = { 0.15, 0.3 }, speed = { 40, 60 }, orient = "VelocityParallel" }),
		light(YELLOW, 6, 20, 0.4),
	},
}
E["Shared/GuardBreak"] = {
	lifetime = 1.2,
	layers = {
		mesh("Glitch", BLUE, 4, 12, 0.3, { camera = true, tr0 = 0.1 }),
		mesh("ShockRing", BLUE, 6, 2, 0.25, { offset = CFrame.new(0, 0.5, -1.5) * CFrame.Angles(math.rad(90), 0, 0), tr0 = 0.2 }),
		emit("Lines", BLUE, 20, { size = { 0.8, 2 }, life = { 0.2, 0.4 }, speed = { 30, 60 }, orient = "VelocityParallel" }),
		emit("Rocks", BLUE, 16, { size = { 0.4, 1.0 }, life = { 0.5, 0.9 }, speed = { 15, 30 }, light = 0.5, accel = Vector3.new(0, -50, 0) }),
		flash(BLUE, 7, 0.15),
		light(BLUE, 5, 16, 0.4),
	},
}
E["Shared/Stun"] = {
	lifetime = 1.3,
	layers = {
		emit("Star", YELLOW, 6, { size = { 0.5, 0.8 }, life = { 1.0, 1.2 }, speed = { 3, 5 }, spread = { 80, 80 }, direction = "up", offset = Vector3.new(0, 2.6, 0), follow = true, rotSpeed = { 60, 120 }, light = 1, drag = 2 }),
		pack("Packs/OfficialJJS/Damage/Dizzy"),
	},
}
E["Shared/Ragdoll"] = {
	lifetime = 1.5,
	layers = {
		emit("Lines", WHITE, 12, { size = { 0.6, 1.4 }, life = { 0.3, 0.5 }, speed = { 8, 16 }, orient = "VelocityParallel", follow = true, duration = 0.6, rate = 30, light = 0.6 }),
		pack("Packs/OfficialJJS/Damage/RagdollWind"),
	},
}
E["Shared/RagdollCancel"] = {
	lifetime = 0.9,
	layers = {
		ringFlat("$primary", 2, 12, 0.35),
		mesh("Tornado", "$primary", 3, 8, 0.35, { up = true, spin = Vector3.new(0, 800, 0), tr0 = 0.4, offset = CFrame.new(0, -1, 0) }),
		emit("Lines", "$primary", 12, { size = { 0.6, 1.4 }, life = { 0.2, 0.35 }, speed = { 25, 45 }, spread = { 20, 20 }, direction = "up", orient = "VelocityParallel" }),
		light("$primary", 3, 14, 0.3),
	},
}
E["Shared/Dash"] = {
	lifetime = 0.9,
	layers = {
		mesh("WindGrow", WHITE, 3, 9, 0.35, { offset = CFrame.new(0, 0, 1.5) * CFrame.Angles(math.rad(90), 0, 0), spin = Vector3.new(0, 0, 600), tr0 = 0.5 }),
		mesh("Air", WHITE, 3, 7, 0.3, { offset = CFrame.new(0, 0, 2) * CFrame.Angles(math.rad(90), 0, 0), tr0 = 0.5 }),
		emit("Step", WHITE, 1, { size = 4, life = { 0.5, 0.5 }, speed = { 0, 0 }, flipbook = { layout = "Grid8x8", mode = "OneShot", fps = 1, fps2 = 1 }, light = 0.5, orient = "VelocityPerpendicular", ground = true, rot = { 0, 360 } }),
		smokePuff(5, { ground = true, size = { 1.5, 3 } }),
	},
}

-- ---- Despertar / transformação ---------------------------------------------------------
E["Shared/Awakening_Charge"] = {
	lifetime = 5.2,
	layers = {
		emit("Flare", "$primary", 0, { duration = 5, rate = 18, size = { 2, 0.4 }, sizeSeq = { { 0, 2 }, { 1, 0.4 } }, life = { 0.4, 0.65 }, speed = { 5, 20 }, spread = { 0, 180 }, rot = { 180, 180 }, orient = "VelocityParallel", accel = Vector3.new(0, 100, 0), drag = 1, follow = true, offset = Vector3.new(0, -2.5, 0), direction = "up", light = 1 }),
		emit("Bits", "$primary", 0, { duration = 5, rate = 40, size = { 0.5, 0.9 }, life = { 0.35, 0.5 }, speed = { 0.01, 0.01 }, accel = Vector3.new(0, 25, 0), follow = true, offset = Vector3.new(0, -1, 0), light = 1, shape = "Box", shapeSize = Vector3.new(4, 5, 4) }),
		emit("Specs", "$primary", 0, { duration = 5, rate = 60, size = { 0.1, 0.35 }, life = { 0.5, 1 }, speed = { 1, 15 }, spread = { 360, 360 }, rotSpeed = { -300, 300 }, follow = true, light = 1, drag = 5 }),
		mesh("ShockGround", "$primary", 10, 2, 4.8, { ground = true, up = true, spin = Vector3.new(0, 60, 0), tr0 = 0.5, tr1 = 0.2, ease = "Sine" }),
		light("$primary", 4, 22, 5, { fadeIn = true }),
	},
}
E["Shared/Awakening_Burst"] = {
	lifetime = 2.2,
	layers = {
		groundWave("$primary", 4, 34, 0.7),
		groundWave(WHITE, 2, 22, 0.5, { delay = 0.05 }),
		ringFlat("$primary", 3, 40, 0.6),
		mesh("Sphere", WHITE, 2, 22, 0.4, { tr0 = 0.2, ease = "Quart" }),
		mesh("Tornado", "$primary", 4, 16, 0.6, { up = true, spin = Vector3.new(0, 900, 0), tr0 = 0.3, offset = CFrame.new(0, 1, 0) }),
		emit("BurstRing", WHITE, 1, { size = 1, sizeSeq = { { 0, 0 }, { 1, 40 } }, life = { 0.35, 0.35 }, speed = { 0, 0 }, light = 1, orient = "FacingCamera" }),
		emit("Smoke", Color3.fromRGB(140, 140, 150), 25, { size = { 2, 5 }, life = { 1, 2.5 }, speed = { 10, 30 }, light = 0.3, drag = 2, ground = true }),
		emit("Lines", "$primary", 30, { size = { 1, 2.5 }, life = { 0.3, 0.5 }, speed = { 50, 90 }, orient = "VelocityParallel" }),
		sparks("$primary", 40),
		flash(WHITE, 16, 0.2),
		light("$primary", 10, 40, 1.0),
	},
}
E["Shared/AwakenedSwing"] = { -- faíscas na cor a cada soco durante o modo despertado
	lifetime = 0.6,
	layers = {
		sparks("$primary", 14, { size = { 0.25, 0.6 }, life = { 0.2, 0.4 }, speed = { 12, 28 } }),
		emit("Flare", "$primary", 2, { size = { 1.5, 2.5 }, life = { 0.12, 0.18 }, speed = { 0, 0 }, light = 1, orient = "FacingCamera" }),
		light("$primary", 3, 10, 0.2),
	},
}
E["Shared/Awakening"] = { -- aura do modo despertado (segue o personagem)
	lifetime = 20,
	layers = {
		emit("AuraMain", "$primary", 0, { duration = 19.5, rate = 22, size = { 6, 6.4 }, life = { 0.25, 0.25 }, speed = { 6, 6 }, spread = { 10, 10 }, rot = { -5, 5 }, orient = "FacingCameraWorldUp", follow = true, offset = Vector3.new(0, -2.6, 0), direction = "up", light = 0.4, zOffset = -0.8, trSeq = { { 0, 1 }, { 0.68, 0.56 }, { 1, 1 } }, lockedToPart = true }),
		emit("Bits", "$primary", 0, { duration = 19.5, rate = 12, size = { 0.5, 0.9 }, life = { 0.35, 0.5 }, speed = { 0.01, 0.01 }, accel = Vector3.new(0, 25, 0), follow = true, offset = Vector3.new(0, -1, 0), light = 1, shape = "Box", shapeSize = Vector3.new(4, 5, 4) }),
		emit("Flame", "$primary", 0, { duration = 19.5, rate = 25, size = { 0.3, 0.3 }, life = { 0.6, 0.9 }, speed = { 4, 8 }, spread = { 20, 20 }, direction = "up", follow = true, offset = Vector3.new(0, -2, 0), light = 1, shape = "Box", shapeSize = Vector3.new(3, 1, 2), trSeq = { { 0, 1 }, { 0.2, 0 }, { 0.8, 0 }, { 1, 1 } } }),
		-- anel de energia no chão girando e pulsando (visível de longe: "esse aí está despertado")
		mesh("ShockGround", "$primary", 7, 8, 19.5, { ground = true, up = true, tr0 = 0.55, tr1 = 0.6, ease = "Sine", follow = true }), -- sem spin: soldado no root
		light("$primary", 2.5, 18, 19.5),
	},
}
E["Shared/Transform"] = { -- virando o boss (2,5 s)
	lifetime = 2.8,
	layers = {
		emit("Flare2", FLESH, 0, { duration = 2.4, rate = 20, size = { 2, 0 }, sizeSeq = { { 0, 2 }, { 1, 0 } }, life = { 0.4, 0.6 }, speed = { 10, 15 }, spread = { 0, 180 }, rot = { 180, 180 }, orient = "VelocityParallel", accel = Vector3.new(0, 70, 0), follow = true, offset = Vector3.new(0, -2.5, 0), direction = "up", light = 1 }),
		emit("SmokeLoop", FLESH, 0, { duration = 2.4, rate = 25, size = { 1.5, 2.5 }, life = { 0.75, 0.75 }, speed = { 0.25, 0.25 }, flipbook = { layout = "Grid4x4", mode = "Loop", fps = 25, fps2 = 25 }, follow = true, light = 1, shape = "Box", shapeSize = Vector3.new(4, 6, 4), rotSpeed = { -100, 100 } }),
		mesh("ShockGround", FLESH, 12, 3, 2.3, { ground = true, up = true, spin = Vector3.new(0, 90, 0), tr0 = 0.4, tr1 = 0.1, ease = "Sine" }),
		light(FLESH, 5, 22, 2.4, { fadeIn = true }),
	},
}

-- ---- Brawler --------------------------------------------------------------------------
E["Brawler/ShoulderBash"] = {
	lifetime = 0.9,
	layers = {
		mesh("WindGrow", ORANGE, 3, 10, 0.4, { offset = CFrame.new(0, 0, 1.5) * CFrame.Angles(math.rad(90), 0, 0), spin = Vector3.new(0, 0, 700), tr0 = 0.4 }),
		emit("Lines", ORANGE, 14, { size = { 0.8, 1.8 }, life = { 0.2, 0.35 }, speed = { 30, 55 }, spread = { 15, 15 }, orient = "VelocityParallel", offset = Vector3.new(0, 0, 2), direction = "back" }),
		smokePuff(6, { ground = true }),
	},
}
E["Brawler/ShoulderBash_Hit"] = {
	lifetime = 1.4,
	layers = {
		impactStar(ORANGE, 9, 0.3),
		groundWave(ORANGE, 3, 16, 0.5),
		emit("Debris", Color3.fromRGB(120, 110, 100), 16, { size = { 0.4, 1.0 }, life = { 0.5, 0.9 }, speed = { 15, 35 }, light = 0, accel = Vector3.new(0, -60, 0), ground = true }),
		smokePuff(10, { ground = true }),
		flash(WHITE, 8, 0.15),
		light(ORANGE, 5, 18, 0.4),
	},
}
E["Brawler/GroundSlam"] = {
	lifetime = 1.6,
	layers = {
		groundWave(ORANGE, 4, 26, 0.6),
		groundWave(WHITE, 2, 18, 0.45, { delay = 0.06 }),
		ringFlat(ORANGE, 2, 30, 0.5),
		emit("GroundCrack2", ORANGE, 1, { size = 22, life = { 1.2, 1.2 }, speed = { 0, 0 }, flipbook = { layout = "Grid4x4", mode = "OneShot", fps = 32, fps2 = 32 }, light = 0.8, orient = "VelocityPerpendicular", ground = true, rot = { 0, 360 } }),
		emit("Debris", Color3.fromRGB(120, 110, 100), 24, { size = { 0.5, 1.3 }, life = { 0.6, 1.1 }, speed = { 20, 45 }, spread = { 50, 50 }, direction = "up", light = 0, accel = Vector3.new(0, -70, 0), ground = true }),
		dustRing(Color3.fromRGB(170, 150, 120), 16),
		flash(ORANGE, 10, 0.15),
		light(ORANGE, 6, 26, 0.5),
	},
}
E["Brawler/GroundSlam_Hit"] = E["Shared/FinisherHit"]
E["Brawler/Rampage"] = {
	lifetime = 2.0,
	layers = {
		mesh("Sphere", ORANGE, 2, 22, 0.5, { tr0 = 0.3, ease = "Quart" }),
		groundWave(ORANGE, 4, 30, 0.7),
		groundWave(RED, 3, 22, 0.55, { delay = 0.08 }),
		mesh("SpikeyBall", ORANGE, 4, 20, 0.45, { spin = Vector3.new(0, 300, 0), tr0 = 0.3, ground = true, up = true }),
		emit("GroundCrack", ORANGE, 1, { size = 26, life = { 1.4, 1.4 }, speed = { 0, 0 }, flipbook = { layout = "Grid4x4", mode = "OneShot", fps = 32, fps2 = 32 }, light = 1, orient = "VelocityPerpendicular", ground = true }),
		emit("Rocks", Color3.fromRGB(140, 120, 100), 30, { size = { 0.6, 1.6 }, life = { 0.7, 1.2 }, speed = { 25, 55 }, spread = { 60, 60 }, direction = "up", light = 0, accel = Vector3.new(0, -70, 0), ground = true }),
		flash(WHITE, 14, 0.2),
		light(ORANGE, 8, 32, 0.7),
	},
}
E["Brawler/Rampage_Hit"] = E["Shared/FinisherHit"]

-- ---- Swift ----------------------------------------------------------------------------
E["Swift/Blink"] = {
	lifetime = 0.9,
	layers = {
		mesh("GlitchBall", BLUE, 6, 1, 0.3, { camera = true, tr0 = 0.2 }),
		emit("Lines", BLUE, 16, { size = { 0.5, 1.4 }, life = { 0.15, 0.3 }, speed = { 30, 60 }, orient = "VelocityParallel" }),
		emit("Glow", WHITE, 1, { size = 6, sizeSeq = { { 0, 6 }, { 1, 0 } }, life = { 0.25, 0.25 }, speed = { 0, 0 }, light = 1 }),
		light(BLUE, 4, 14, 0.25),
	},
}
E["Swift/SweepKick"] = {
	lifetime = 0.8,
	layers = {
		mesh("Slash", BLUE, 4, 12, 0.3, { offset = CFrame.new(0, -1.5, -2) * CFrame.Angles(0, 0, 0), spin = Vector3.new(0, 500, 0), tr0 = 0.3, up = true }),
		mesh("ShockRing", BLUE, 3, 10, 0.3, { ground = true, up = true, tr0 = 0.2 }),
		emit("Lines", BLUE, 10, { size = { 0.6, 1.4 }, life = { 0.15, 0.25 }, speed = { 25, 45 }, spread = { 30, 30 }, orient = "VelocityParallel", offset = Vector3.new(0, -1, -2), direction = "forward" }),
	},
}
E["Swift/SweepKick_Hit"] = E["Shared/Hit"]
E["Swift/TimeDome"] = { -- abertura do Domínio do Tempo (a cúpula fica por conta do AbilityController)
	lifetime = 1.6,
	layers = {
		groundWave(BLUE, 4, 46, 0.7),
		ringFlat(WHITE, 3, 44, 0.6, { delay = 0.05 }),
		mesh("Sphere", BLUE, 2, 44, 0.5, { tr0 = 0.5, ease = "Quart" }),
		emit("Glow", WHITE, 1, { size = 8, sizeSeq = { { 0, 8 }, { 1, 0 } }, life = { 0.3, 0.3 }, speed = { 0, 0 }, light = 1 }),
		sparks(BLUE, 30),
		light(BLUE, 8, 40, 0.8),
	},
}
E["Swift/TimeDome_Break"] = { -- cúpula quebrando
	lifetime = 1.4,
	layers = {
		mesh("Sphere", WHITE, 40, 52, 0.35, { tr0 = 0.6, ease = "Quart" }),
		emit("Lines", BLUE, 40, { size = { 1, 2.5 }, life = { 0.4, 0.7 }, speed = { 40, 80 }, orient = "VelocityParallel", spread = { 360, 360 } }),
		sparks(WHITE, 30),
		flash(WHITE, 20, 0.2),
		light(BLUE, 8, 50, 0.6),
	},
}
E["Swift/TimeDome_Hit"] = E["Shared/Hit"]
E["Swift/Tempest"] = {
	lifetime = 2.6,
	layers = {
		mesh("Tornado", BLUE, 4, 16, 2.2, { up = true, spin = Vector3.new(0, 1000, 0), tr0 = 0.35, tr1 = 1, ease = "Sine", offset = CFrame.new(0, 0.5, 0) }),
		mesh("Wind2", WHITE, 3, 14, 2.2, { up = true, spin = Vector3.new(0, -700, 0), tr0 = 0.5, ease = "Sine" }),
		ringFlat(BLUE, 2, 14, 0.4),
		emit("Lines", BLUE, 0, { duration = 2.0, rate = 40, size = { 0.6, 1.6 }, life = { 0.3, 0.5 }, speed = { 15, 30 }, spread = { 0, 0 }, orient = "VelocityPerpendicular", shape = "Disc", shapeStyle = "Surface", light = 0.8, drag = 2, follow = true }),
		emit("Bits", BLUE, 0, { duration = 2.0, rate = 12, size = { 0.5, 1.0 }, life = { 0.5, 0.9 }, speed = { 10, 20 }, rotSpeed = { -300, 300 }, light = 0.3, follow = true, drag = 1 }),
		light(BLUE, 4, 20, 2.2),
	},
}
E["Swift/Tempest_Hit"] = E["Shared/Hit"]

-- ---- Mystic ---------------------------------------------------------------------------
local PURPLE = Color3.fromRGB(170, 110, 255)
E["Mystic/ArcaneBolt"] = {
	lifetime = 0.8,
	layers = {
		mesh("SphereHD", PURPLE, 1, 5, 0.25, { offset = CFrame.new(0, 0.5, -3), tr0 = 0.2 }),
		mesh("ShockRing", PURPLE, 1, 8, 0.3, { offset = CFrame.new(0, 0.5, -3) * CFrame.Angles(math.rad(90), 0, 0), tr0 = 0.2 }),
		emit("Specs", PURPLE, 18, { size = { 0.15, 0.4 }, life = { 0.3, 0.6 }, speed = { 5, 15 }, rotSpeed = { -300, 300 }, light = 1, offset = Vector3.new(0, 0.5, -3) }),
		light(PURPLE, 3, 12, 0.3, { offset = Vector3.new(0, 0.5, -3) }),
	},
}
E["Mystic/ArcaneBolt_Hit"] = {
	lifetime = 1.0,
	layers = {
		mesh("Explosion", PURPLE, 2, 10, 0.35, { spin = Vector3.new(200, 300, 0), tr0 = 0.2 }),
		mesh("ShockInward", PURPLE, 10, 2, 0.3, { camera = true, tr0 = 0.2 }),
		emit("Sparks", PURPLE, 20, { size = { 0.2, 0.6 }, life = { 0.3, 0.6 }, speed = { 15, 35 }, orient = "VelocityParallel", drag = 3 }),
		emit("Specs", WHITE, 12, { size = { 0.15, 0.4 }, life = { 0.4, 0.8 }, speed = { 5, 20 }, rotSpeed = { -300, 300 }, light = 1 }),
		flash(WHITE, 6, 0.12),
		light(PURPLE, 5, 16, 0.4),
	},
}
E["Mystic/Mend"] = {
	lifetime = 1.6,
	layers = {
		mesh("ShockRing", Color3.fromRGB(120, 255, 180), 8, 2, 0.6, { ground = true, up = true, tr0 = 0.2, ease = "Sine" }),
		mesh("Sphere", Color3.fromRGB(120, 255, 180), 1, 8, 0.6, { tr0 = 0.5, ease = "Sine" }),
		emit("Specs", Color3.fromRGB(150, 255, 190), 0, { duration = 1.2, rate = 40, size = { 0.15, 0.4 }, life = { 0.6, 1.0 }, speed = { 3, 6 }, spread = { 30, 30 }, direction = "up", follow = true, offset = Vector3.new(0, -2, 0), light = 1, shape = "Box", shapeSize = Vector3.new(4, 1, 4) }),
		emit("Flare", Color3.fromRGB(120, 255, 180), 8, { size = { 1.5, 0.3 }, sizeSeq = { { 0, 1.5 }, { 1, 0.3 } }, life = { 0.5, 0.7 }, speed = { 6, 12 }, spread = { 0, 180 }, rot = { 180, 180 }, orient = "VelocityParallel", accel = Vector3.new(0, 40, 0), follow = true, offset = Vector3.new(0, -2.5, 0), direction = "up", light = 1 }),
		light(Color3.fromRGB(120, 255, 180), 4, 16, 1.2),
	},
}
E["Mystic/Meteor"] = { -- aviso no chão (no ponto)
	lifetime = 1.4,
	layers = {
		ringFlat(PURPLE, 14, 12, 1.2, { tr0 = 0.3, tr1 = 0.3, ease = "Sine", spin = Vector3.new(0, 120, 0) }),
		mesh("ShockRing", PURPLE, 2, 12, 0.5, { ground = true, up = true, tr0 = 0.2 }),
		emit("Specs", PURPLE, 0, { duration = 1.1, rate = 30, size = { 0.15, 0.4 }, life = { 0.5, 0.9 }, speed = { 3, 8 }, spread = { 0, 0 }, direction = "up", ground = true, shape = "Disc", shapeStyle = "Surface", shapeSize = Vector3.new(12, 0.5, 12), light = 1 }),
		light(PURPLE, 3, 20, 1.2),
	},
}
E["Mystic/Meteor_Hit"] = {
	lifetime = 2.4,
	layers = {
		mesh("Explosion2", PURPLE, 4, 24, 0.5, { spin = Vector3.new(100, 200, 0), tr0 = 0.2 }),
		mesh("Sphere", WHITE, 2, 18, 0.35, { tr0 = 0.3 }),
		groundWave(PURPLE, 4, 30, 0.7),
		ringFlat(WHITE, 3, 32, 0.5),
		mesh("FireBall", PURPLE, 6, 16, 0.6, { spin = Vector3.new(0, 400, 0), tr0 = 0.3, offset = CFrame.new(0, 2, 0) }),
		emit("Smoke", Color3.fromRGB(90, 70, 120), 26, { size = { 3, 6 }, life = { 1, 2.2 }, speed = { 10, 30 }, light = 0.4, drag = 2, ground = true }),
		emit("Rocks", Color3.fromRGB(110, 90, 130), 26, { size = { 0.5, 1.4 }, life = { 0.7, 1.3 }, speed = { 25, 55 }, spread = { 60, 60 }, direction = "up", light = 0.2, accel = Vector3.new(0, -70, 0), ground = true }),
		sparks(PURPLE, 30),
		flash(WHITE, 16, 0.2),
		light(PURPLE, 10, 36, 0.8),
		pack("Packs/ShadowBattlegroundsfull/MeteoricCombination/FinalImpact2"),
	},
}

-- ---- Guardian -------------------------------------------------------------------------
E["Guardian/ShieldBash"] = {
	lifetime = 0.9,
	layers = {
		mesh("ShockMid", GOLD, 4, 12, 0.35, { offset = CFrame.new(0, 0, -2) * CFrame.Angles(0, 0, 0), tr0 = 0.3, spin = Vector3.new(0, 0, 300) }),
		mesh("WindGrow", WHITE, 3, 9, 0.35, { offset = CFrame.new(0, 0, 1.5) * CFrame.Angles(math.rad(90), 0, 0), spin = Vector3.new(0, 0, 600), tr0 = 0.5 }),
		emit("Lines", GOLD, 12, { size = { 0.8, 1.8 }, life = { 0.2, 0.35 }, speed = { 30, 55 }, spread = { 12, 12 }, orient = "VelocityParallel", offset = Vector3.new(0, 0, -2), direction = "forward" }),
	},
}
E["Guardian/ShieldBash_Hit"] = E["Shared/FinisherHit"]
E["Guardian/Fortify"] = {
	lifetime = 6.2,
	layers = {
		mesh("SphereFancy", GOLD, 1, 9, 0.5, { tr0 = 0.55, tr1 = 0.55, ease = "Back", follow = true }),
		mesh("SphereFancy", GOLD, 9, 9, 5.5, { tr0 = 0.55, tr1 = 1, ease = "Sine", follow = true, spin = Vector3.new(0, 40, 0), delay = 0.5 }),
		emit("Field", GOLD, 0, { duration = 5.5, rate = 8, size = { 8, 8 }, life = { 0.6, 0.6 }, speed = { 0, 0 }, light = 1, follow = true, orient = "VelocityPerpendicular", rotSpeed = { 60, 80 }, trSeq = { { 0, 0.6 }, { 1, 0.6 } }, lockedToPart = true }),
		emit("Specs", GOLD, 0, { duration = 5.5, rate = 20, size = { 0.15, 0.35 }, life = { 0.5, 1 }, speed = { 1, 4 }, follow = true, light = 1, shape = "Sphere", shapeStyle = "Surface", shapeSize = Vector3.new(8, 8, 8) }),
		light(GOLD, 2.5, 14, 5.8),
	},
}
E["Guardian/Quake"] = {
	lifetime = 2.0,
	layers = {
		groundWave(GOLD, 4, 34, 0.75),
		groundWave(WHITE, 3, 24, 0.6, { delay = 0.06 }),
		ringFlat(GOLD, 2, 36, 0.6),
		mesh("SpikeyBall", Color3.fromRGB(150, 130, 100), 3, 18, 0.5, { ground = true, up = true, spin = Vector3.new(0, 120, 0), tr0 = 0.2, material = Enum.Material.Slate }),
		emit("GroundCrack", GOLD, 1, { size = 30, life = { 1.6, 1.6 }, speed = { 0, 0 }, flipbook = { layout = "Grid4x4", mode = "OneShot", fps = 32, fps2 = 32 }, light = 0.8, orient = "VelocityPerpendicular", ground = true }),
		emit("Rocks", Color3.fromRGB(140, 120, 100), 30, { size = { 0.6, 1.8 }, life = { 0.7, 1.3 }, speed = { 25, 55 }, spread = { 55, 55 }, direction = "up", light = 0, accel = Vector3.new(0, -70, 0), ground = true }),
		dustRing(Color3.fromRGB(170, 150, 120), 20),
		flash(WHITE, 12, 0.2),
		light(GOLD, 7, 30, 0.6),
	},
}
E["Guardian/Quake_Hit"] = E["Shared/FinisherHit"]

-- ---- Sahur ----------------------------------------------------------------------------
local GREEN = Color3.fromRGB(120, 255, 160)
E["Sahur/Bombo"] = E["Brawler/GroundSlam"]
E["Sahur/Bombo_Hit"] = E["Shared/FinisherHit"]
E["Sahur/Toque"] = {
	lifetime = 6.2,
	layers = {
		emit("AuraMain", GREEN, 0, { duration = 5.8, rate = 20, size = { 6, 6.4 }, life = { 0.25, 0.25 }, speed = { 6, 6 }, spread = { 10, 10 }, orient = "FacingCameraWorldUp", follow = true, offset = Vector3.new(0, -2.6, 0), direction = "up", light = 0.4, zOffset = -0.8, trSeq = { { 0, 1 }, { 0.68, 0.56 }, { 1, 1 } }, lockedToPart = true }),
		emit("Bits", GREEN, 0, { duration = 5.8, rate = 14, size = { 0.5, 0.9 }, life = { 0.35, 0.5 }, speed = { 0.01, 0.01 }, accel = Vector3.new(0, 25, 0), follow = true, offset = Vector3.new(0, -1, 0), light = 1, shape = "Box", shapeSize = Vector3.new(4, 5, 4) }),
		ringFlat(GREEN, 2, 14, 0.5),
		light(GREEN, 3, 16, 5.8),
	},
}
E["Sahur/Ritmo"] = {
	lifetime = 2.2,
	layers = {
		mesh("RingPurple", GREEN, 4, 18, 1.8, { up = true, spin = Vector3.new(0, 500, 0), tr0 = 0.35, ease = "Sine", offset = CFrame.new(0, 0.5, 0), follow = true }),
		mesh("Wind1", WHITE, 3, 14, 1.8, { up = true, spin = Vector3.new(0, -400, 0), tr0 = 0.5, ease = "Sine", follow = true }),
		emit("Specs", GREEN, 0, { duration = 1.7, rate = 40, size = { 0.15, 0.4 }, life = { 0.4, 0.8 }, speed = { 8, 20 }, spread = { 0, 0 }, orient = "VelocityPerpendicular", shape = "Disc", shapeStyle = "Surface", light = 1, follow = true }),
		light(GREEN, 3, 18, 1.8),
	},
}
E["Sahur/Ritmo_Hit"] = E["Shared/Hit"]

-- ---- Overlord -------------------------------------------------------------------------
local MAGENTA = Color3.fromRGB(255, 80, 200)
E["Overlord/Smite"] = {
	lifetime = 1.4,
	layers = {
		mesh("Thunder", MAGENTA, 2, 24, 0.25, { up = true, tr0 = 0.1, offset = CFrame.new(0, 10, -4), spin = Vector3.new(0, 200, 0) }),
		mesh("ThunderSpark", MAGENTA, 3, 12, 0.3, { offset = CFrame.new(0, 1, -4), spin = Vector3.new(300, 300, 0), tr0 = 0.2 }),
		groundWave(MAGENTA, 3, 18, 0.5, { offset = CFrame.new(0, 0, -4) }),
		emit("Electric", MAGENTA, 16, { size = { 1, 3 }, life = { 0.1, 0.3 }, speed = { 0, 40 }, orient = "VelocityParallel", light = 1, offset = Vector3.new(0, 1, -4) }),
		flash(WHITE, 10, 0.12),
		light(MAGENTA, 8, 24, 0.4, { offset = Vector3.new(0, 1, -4) }),
	},
}
E["Overlord/Smite_Hit"] = E["Shared/Crit"]
E["Overlord/Warp"] = E["Swift/Blink"]
E["Overlord/Clutch"] = {
	lifetime = 1.2,
	layers = {
		mesh("ShockInward", MAGENTA, 16, 2, 0.5, { camera = true, tr0 = 0.2, offset = CFrame.new(0, 1, -5) }),
		emit("Specs", MAGENTA, 30, { size = { 0.15, 0.5 }, life = { 0.4, 0.7 }, speed = { -30, -10 }, spread = { 180, 180 }, light = 1, offset = Vector3.new(0, 1, -5), shape = "Sphere", shapeStyle = "Surface", shapeSize = Vector3.new(14, 14, 14), shapeInOut = "Inward" }),
		light(MAGENTA, 5, 18, 0.5, { offset = Vector3.new(0, 1, -5) }),
	},
}
E["Overlord/Clutch_Hit"] = E["Shared/Hit"]
E["Overlord/Cataclysm"] = {
	lifetime = 2.6,
	layers = {
		mesh("Sphere", MAGENTA, 2, 30, 0.6, { tr0 = 0.3, ease = "Quart" }),
		mesh("SphereFancy", DARK, 1, 26, 0.5, { tr0 = 0.4, ease = "Quart", delay = 0.05 }),
		groundWave(MAGENTA, 4, 40, 0.8),
		ringFlat(WHITE, 3, 44, 0.6),
		mesh("Thunder", MAGENTA, 3, 30, 0.35, { up = true, tr0 = 0.1, offset = CFrame.new(0, 12, 0) }),
		emit("Electric", MAGENTA, 30, { size = { 1.5, 4 }, life = { 0.15, 0.35 }, speed = { 0, 60 }, orient = "VelocityParallel", light = 1 }),
		emit("Smoke", Color3.fromRGB(80, 40, 90), 30, { size = { 3, 7 }, life = { 1, 2.4 }, speed = { 10, 35 }, light = 0.4, drag = 2, ground = true }),
		sparks(MAGENTA, 40),
		flash(WHITE, 20, 0.25),
		light(MAGENTA, 12, 44, 1.0),
	},
}
E["Overlord/Cataclysm_Hit"] = E["Shared/FinisherHit"]

-- ---- Big C.H.O.P. (forma de boss) -------------------------------------------------
E["BigChop/Devour"] = {
	lifetime = 1.2,
	layers = {
		mesh("WindGrow", FLESH, 6, 20, 0.5, { offset = CFrame.new(0, 0, 4) * CFrame.Angles(math.rad(90), 0, 0), spin = Vector3.new(0, 0, 500), tr0 = 0.4 }),
		emit("Lines", FLESH, 20, { size = { 1.2, 3 }, life = { 0.25, 0.4 }, speed = { 30, 60 }, spread = { 15, 15 }, orient = "VelocityParallel", offset = Vector3.new(0, 0, 5), direction = "back" }),
		smokePuff(12, { ground = true, size = { 3, 6 } }),
	},
}
E["BigChop/Devour_Hit"] = {
	lifetime = 1.4,
	layers = {
		impactStar(FLESH, 14, 0.35),
		mesh("Explosion", FLESH, 4, 16, 0.4, { spin = Vector3.new(200, 300, 0), tr0 = 0.2 }),
		flash(WHITE, 10, 0.15),
		sparks(FLESH, 30),
		emit("Lines", WHITE, 16, { size = { 0.8, 2 }, life = { 0.2, 0.35 }, speed = { 45, 80 }, orient = "VelocityParallel" }),
		light(FLESH, 6, 22, 0.5),
	},
}
E["BigChop/Crush"] = {
	lifetime = 2.0,
	layers = {
		groundWave(FLESH, 5, 34, 0.7),
		groundWave(WHITE, 3, 24, 0.55, { delay = 0.06 }),
		ringFlat(FLESH, 3, 38, 0.6),
		emit("GroundCrack", FLESH, 1, { size = 32, life = { 1.6, 1.6 }, speed = { 0, 0 }, flipbook = { layout = "Grid4x4", mode = "OneShot", fps = 32, fps2 = 32 }, light = 0.8, orient = "VelocityPerpendicular", ground = true }),
		emit("Rocks", Color3.fromRGB(130, 90, 110), 34, { size = { 0.7, 2 }, life = { 0.7, 1.3 }, speed = { 25, 60 }, spread = { 55, 55 }, direction = "up", light = 0, accel = Vector3.new(0, -70, 0), ground = true }),
		dustRing(Color3.fromRGB(170, 130, 140), 22),
		flash(WHITE, 14, 0.2),
		light(FLESH, 8, 34, 0.6),
	},
}
E["BigChop/Crush_Hit"] = E["Shared/FinisherHit"]
E["BigChop/FleshWave"] = {
	lifetime = 2.4,
	layers = {
		mesh("Sphere", FLESH, 3, 44, 0.8, { tr0 = 0.35, ease = "Quart" }),
		mesh("SphereFancy", Color3.fromRGB(120, 30, 60), 2, 40, 0.7, { tr0 = 0.4, ease = "Quart", delay = 0.05 }),
		groundWave(FLESH, 5, 46, 0.9),
		ringFlat(WHITE, 4, 50, 0.7),
		emit("SmokeLoop", FLESH, 40, { size = { 3, 6 }, life = { 0.9, 1.6 }, speed = { 20, 45 }, flipbook = { layout = "Grid4x4", mode = "Loop", fps = 25, fps2 = 25 }, light = 0.6, drag = 3, ground = true, rotSpeed = { -100, 100 } }),
		sparks(FLESH, 40),
		flash(WHITE, 18, 0.2),
		light(FLESH, 10, 46, 0.9),
	},
}
E["BigChop/FleshWave_Hit"] = E["Shared/FinisherHit"]
E["BigChop/Frenzy"] = {
	lifetime = 2.2,
	layers = {
		mesh("RingPurple", FLESH, 8, 32, 1.9, { up = true, spin = Vector3.new(0, 600, 0), tr0 = 0.3, ease = "Sine", follow = true, offset = CFrame.new(0, 0, 0) }),
		mesh("SpikeyBall", FLESH, 6, 30, 1.9, { up = true, spin = Vector3.new(0, -300, 0), tr0 = 0.4, ease = "Sine", follow = true }),
		emit("SlashFlip", FLESH, 0, { duration = 1.8, rate = 14, size = { 6, 10 }, life = { 0.3, 0.5 }, speed = { 0, 0 }, flipbook = { layout = "Grid2x2", mode = "OneShot", fps = 30, fps2 = 30 }, light = 1, follow = true, rot = { -360, 360 }, shape = "Sphere", shapeStyle = "Surface", shapeSize = Vector3.new(16, 8, 16) }),
		light(FLESH, 6, 30, 1.9),
	},
}
E["BigChop/Frenzy_Hit"] = E["Shared/Hit"]

-- ---- Boss NPC (admin) reaproveita a forma ------------------------------------------------
E["Boss/Swipe"] = E["Shared/Swing_4"]
E["Boss/Swipe_Hit"] = E["BigChop/Devour_Hit"]
E["Boss/Slam"] = E["BigChop/Crush"]
E["Boss/Slam_Hit"] = E["Shared/FinisherHit"]
E["Boss/Shockwave"] = E["BigChop/FleshWave"]
E["Boss/Shockwave_Hit"] = E["Shared/FinisherHit"]
E["Boss/Charge"] = E["BigChop/Devour"]
E["Boss/Charge_Hit"] = E["BigChop/Devour_Hit"]
E["Boss/Leap"] = E["BigChop/Devour"]
E["Boss/Leap_Hit"] = E["BigChop/Crush"]
E["Boss/Roar"] = E["BigChop/Frenzy"]
E["Boss/Roar_Hit"] = E["Shared/Hit"]

--- Efeito por "Pasta/Nome" (nil se não houver composição para ele).
function VFXLibrary.Get(folder: string, name: string): Effect?
	return E[folder .. "/" .. name]
end

--- Lista ordenada das chaves (preview do menu DEV).
function VFXLibrary.Keys(): { string }
	local keys = {}
	for k in E do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

return VFXLibrary
