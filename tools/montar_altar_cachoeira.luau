--[[
	montar_altar_cachoeira.luau — roda NO STUDIO (MCP run_code). Idempotente: refaz `Workspace.AltarGruta`.
	Dono (2026-09-20): altar ENCOSTADO na muralha sul, escondido atrás de uma CACHOEIRA que cai dela;
	ambientação mesopotâmica + floresta. O santuário (gerar_arena.py) já foi movido: anel termina em z≈341,
	altar em (97.75, 360), arco em z 369, muralha em z≈376.5 (111 studs de altura), chão y≈-0.7.
	Aqui: GRUTA de rocha colada na muralha (paredes, teto, lintel) com pilastras-zigurate de arenito e faixa
	de lápis-lazúli; CACHOEIRA (véu ForceField + névoa + respingos + lago raso) caindo do teto da gruta,
	alimentada por um fio d'água na face da muralha; palmeiras, cipós, juncos, musgo, urnas, tabuletas
	cuneiformes, braseiros em pedestais-zigurate na entrada, tochas dentro. O dono SALVA o place depois.
	Nada do mapa é movido/apagado.
]]

local Workspace = game:GetService("Workspace")

local CX = 97.75
local FRONT_Z = 344 -- boca da gruta
local BACK_Z = 376.4 -- face da muralha
local GROUND = -0.7
local ROOF_Y = 24 -- altura livre dentro
local HALF_W = 24 -- meia largura interna (x 73.75..121.75)

local old = Workspace:FindFirstChild("AltarGruta")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "AltarGruta"
root.Parent = Workspace
local rng = Random.new(7)

local ROCK = Color3.fromRGB(64, 58, 54)
local ROCK_DARK = Color3.fromRGB(48, 44, 42)
local SAND = Color3.fromRGB(196, 168, 118)
local SAND_DARK = Color3.fromRGB(160, 132, 88)
local LAPIS = Color3.fromRGB(32, 62, 160)
local GOLD = Color3.fromRGB(214, 176, 78)
local WATER = Color3.fromRGB(120, 190, 235)
local GREEN = Color3.fromRGB(70, 130, 60)
local GREEN_DARK = Color3.fromRGB(45, 95, 45)
local TRUNK = Color3.fromRGB(110, 80, 50)

local function part(name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	p.Parent = root
	return p
end
local function cyl(name, radius, height, cf, color, material, props)
	local p = part(name, Vector3.new(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function ball(name, r, pos, color, material)
	local p = part(name, Vector3.new(r * 2, r * 2, r * 2), CFrame.new(pos), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end
local function light(parent, color, brightness, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
end
local function fire(parent, size)
	local f = Instance.new("Fire")
	f.Size = size or 4
	f.Heat = 8
	f.Parent = parent
	light(parent, Color3.fromRGB(255, 160, 70), 1.6, 22)
end

-- ---------------------------------------------------------------------------
-- GRUTA (rocha colada na muralha)
-- ---------------------------------------------------------------------------
local depth = BACK_Z - FRONT_Z
local midZ = (FRONT_Z + BACK_Z) / 2
for _, sx in { -1, 1 } do
	local x = CX + sx * (HALF_W + 3)
	part("GrutaParede", Vector3.new(6, ROOF_Y + 6, depth + 2), CFrame.new(x, GROUND + (ROOF_Y + 6) / 2 - 1, midZ + 1), ROCK, Enum.Material.Slate)
	-- pedras irregulares por fora
	for i = 1, 5 do
		ball("GrutaPedra", rng:NextNumber(3, 6), Vector3.new(x + sx * rng:NextNumber(2, 5), GROUND + rng:NextNumber(1, ROOF_Y + 2), FRONT_Z + rng:NextNumber(0, depth)), ROCK_DARK, Enum.Material.Slate)
	end
end
part("GrutaTeto", Vector3.new(HALF_W * 2 + 12, 6, depth + 4), CFrame.new(CX, GROUND + ROOF_Y + 3, midZ + 1), ROCK, Enum.Material.Slate)
for i = 1, 10 do
	ball("GrutaPedraTeto", rng:NextNumber(3, 7), Vector3.new(CX + rng:NextNumber(-HALF_W - 4, HALF_W + 4), GROUND + ROOF_Y + rng:NextNumber(4, 9), FRONT_Z + rng:NextNumber(-2, depth)), ROCK_DARK, Enum.Material.Slate)
end
-- lintel de arenito na boca, com faixa de lápis-lazúli e friso dourado (mesopotâmico)
part("Lintel", Vector3.new(HALF_W * 2 + 6, 4, 3), CFrame.new(CX, GROUND + ROOF_Y - 1, FRONT_Z), SAND, Enum.Material.Sandstone)
part("LintelLapis", Vector3.new(HALF_W * 2 + 6.2, 1.2, 3.1), CFrame.new(CX, GROUND + ROOF_Y - 1, FRONT_Z), LAPIS, Enum.Material.SmoothPlastic)
part("LintelOuro", Vector3.new(HALF_W * 2 + 6.4, 0.3, 3.2), CFrame.new(CX, GROUND + ROOF_Y - 0.3, FRONT_Z), GOLD, Enum.Material.Metal)
part("LintelOuro", Vector3.new(HALF_W * 2 + 6.4, 0.3, 3.2), CFrame.new(CX, GROUND + ROOF_Y - 1.7, FRONT_Z), GOLD, Enum.Material.Metal)
-- pilastras-zigurate nos dois lados da boca (blocos escalonados de arenito)
for _, sx in { -1, 1 } do
	local x = CX + sx * (HALF_W - 1)
	local y = GROUND
	for i, w in { 7, 6, 5, 4.2, 3.6 } do
		local h = 4.4
		part("Zigurate", Vector3.new(w, h, w), CFrame.new(x, y + h / 2, FRONT_Z + 1), if i % 2 == 0 then SAND_DARK else SAND, Enum.Material.Sandstone)
		y += h
	end
end
-- tochas dentro
for _, sx in { -1, 1 } do
	for _, z in { FRONT_Z + 8, FRONT_Z + 20 } do
		local x = CX + sx * (HALF_W - 0.6)
		part("Tocha", Vector3.new(0.35, 2.4, 0.35), CFrame.new(x - sx * 0.6, GROUND + 8, z), TRUNK, Enum.Material.Wood)
		local flame = part("Chama", Vector3.new(0.7, 0.9, 0.7), CFrame.new(x - sx * 0.6, GROUND + 9.5, z), Color3.fromRGB(255, 170, 60), Enum.Material.Neon, { CastShadow = false })
		fire(flame, 2.5)
	end
end

-- ---------------------------------------------------------------------------
-- CACHOEIRA: fio d'água na muralha -> lençol no teto -> véu na boca -> lago + névoa
-- ---------------------------------------------------------------------------
local W = HALF_W * 2 - 8 -- largura do véu
do
	-- fio d'água descendo pela face da muralha até o teto da gruta
	part("AguaMuralha", Vector3.new(W * 0.5, 40, 1), CFrame.new(CX, GROUND + ROOF_Y + 6 + 20, BACK_Z - 0.6), WATER, Enum.Material.ForceField, { CanCollide = false, CanQuery = false, Transparency = 0.15 })
	-- lençol correndo por cima do teto
	part("AguaTeto", Vector3.new(W * 0.8, 0.6, depth + 2), CFrame.new(CX, GROUND + ROOF_Y + 6.3, midZ), WATER, Enum.Material.ForceField, { CanCollide = false, CanQuery = false, Transparency = 0.1 })
	-- véu na boca (2 camadas: uma azul, uma branca por trás), CanCollide false: atravessa
	local h = ROOF_Y + 7
	part("Veu", Vector3.new(W, h, 1.2), CFrame.new(CX, GROUND + h / 2, FRONT_Z - 2.5), WATER, Enum.Material.ForceField, { CanCollide = false, CanQuery = false, Transparency = 0.05 })
	part("VeuBranco", Vector3.new(W + 2, h, 0.6), CFrame.new(CX, GROUND + h / 2, FRONT_Z - 3.4), Color3.fromRGB(225, 240, 255), Enum.Material.ForceField, { CanCollide = false, CanQuery = false, Transparency = 0.45 })
	-- lago raso na base (atravessável)
	part("Lago", Vector3.new(W + 14, 0.5, 18), CFrame.new(CX, GROUND + 0.25, FRONT_Z - 3), Color3.fromRGB(70, 140, 190), Enum.Material.Glass, { CanCollide = false, CanQuery = false, Transparency = 0.35, Reflectance = 0.3 })
	part("LagoBorda", Vector3.new(W + 16, 0.4, 20), CFrame.new(CX, GROUND + 0.1, FRONT_Z - 3), Color3.fromRGB(95, 90, 80), Enum.Material.Pebble, { CanCollide = false })
	-- névoa e respingos onde a água bate
	local mist = part("Nevoa", Vector3.new(W, 0.2, 4), CFrame.new(CX, GROUND + 1, FRONT_Z - 3), WATER, Enum.Material.Plastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Rate = 18
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.LightEmission = 0.2
	e.Parent = mist
	local drops = e:Clone()
	drops.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	drops.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	drops.Lifetime = NumberRange.new(0.5, 0.9)
	drops.Rate = 40
	drops.Speed = NumberRange.new(8, 14)
	drops.Acceleration = Vector3.new(0, -40, 0)
	drops.SpreadAngle = Vector2.new(70, 70)
	drops.Parent = mist
	-- gotas caindo pelo véu (dão movimento além do ForceField)
	local fall = part("Queda", Vector3.new(W, 0.2, 1), CFrame.new(CX, GROUND + h - 1, FRONT_Z - 2.5), WATER, Enum.Material.Plastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	local f = drops:Clone()
	f.Rate = 60
	f.Lifetime = NumberRange.new(1.2, 1.5)
	f.Speed = NumberRange.new(0, 1)
	f.SpreadAngle = Vector2.new(5, 5)
	f.Acceleration = Vector3.new(0, -30, 0)
	f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.2) })
	f.EmissionDirection = Enum.NormalId.Bottom
	f.Parent = fall
	-- som de água (id público de cachoeira; se não tocar, troque em Sounds.model.json e aqui)
	local s = Instance.new("Sound")
	s.Name = "Cachoeira"
	s.SoundId = "rbxassetid://9120386436"
	s.Looped = true
	s.Volume = 0.6
	s.RollOffMaxDistance = 90
	s.RollOffMinDistance = 12
	s.Playing = true
	s.Parent = mist
	light(mist, Color3.fromRGB(150, 200, 255), 0.8, 30)
end

-- ---------------------------------------------------------------------------
-- Mesopotâmia + floresta: pedestais-zigurate com braseiros, urnas, tabuletas, palmeiras, cipós, juncos, musgo
-- ---------------------------------------------------------------------------
local function ziggurat(x, z, tiers, base, step)
	local y = GROUND
	for i = 1, tiers do
		local w = base - (i - 1) * step
		part("Pedestal", Vector3.new(w, 1.6, w), CFrame.new(x, y + 0.8, z), if i % 2 == 0 then SAND_DARK else SAND, Enum.Material.Sandstone)
		y += 1.6
	end
	return y
end
for _, sx in { -1, 1 } do
	local x, z = CX + sx * (HALF_W + 8), FRONT_Z - 14
	local top = ziggurat(x, z, 3, 9, 2.4)
	local bowl = cyl("Braseiro", 1.6, 1.2, CFrame.new(x, top + 0.6, z), Color3.fromRGB(70, 60, 55), Enum.Material.Metal)
	local ember = part("Brasa", Vector3.new(2, 0.3, 2), CFrame.new(x, top + 1.25, z), Color3.fromRGB(255, 120, 40), Enum.Material.Neon, { CastShadow = false })
	fire(ember, 5)
	bowl.Parent = root
end
-- urnas de barro encostadas nas paredes da gruta
for i = 1, 6 do
	local sx = if i % 2 == 0 then 1 else -1
	local x = CX + sx * (HALF_W - 2.5)
	local z = FRONT_Z + 4 + i * 4.5
	cyl("Urna", 1.1, 2.6, CFrame.new(x, GROUND + 1.3, z), Color3.fromRGB(150, 100, 70), Enum.Material.Slate)
	cyl("UrnaBoca", 0.8, 0.5, CFrame.new(x, GROUND + 2.85, z), Color3.fromRGB(120, 80, 55), Enum.Material.Slate)
end
-- tabuletas cuneiformes encostadas (arenito com sulcos escuros)
for i, pos in { { CX - 10, FRONT_Z + 6 }, { CX + 11, FRONT_Z + 9 }, { CX - 14, FRONT_Z + 26 } } do
	local t = part("Tabuleta", Vector3.new(3, 4, 0.5), CFrame.new(pos[1], GROUND + 2, pos[2]) * CFrame.Angles(math.rad(-12), math.rad(20 * i), 0), SAND, Enum.Material.Sandstone)
	for r = 1, 5 do
		part("Cuneiforme", Vector3.new(2.2, 0.18, 0.1), t.CFrame * CFrame.new(rng:NextNumber(-0.2, 0.2), 1.5 - r * 0.6, -0.3), Color3.fromRGB(70, 55, 40), Enum.Material.Slate, { CanCollide = false })
	end
end
-- palmeiras
local function palm(x, z, height)
	local h = height or rng:NextNumber(14, 20)
	local segs = 6
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	local topPos
	for i = 1, segs do
		local y0 = GROUND + (i - 1) * h / segs
		local off = lean * (i / segs) ^ 2 * 2.5
		local c = cyl("Tronco", 0.75 - i * 0.05, h / segs + 0.3, CFrame.new(x + off.X, y0 + h / segs / 2, z + off.Z), TRUNK, Enum.Material.Wood)
		c.Parent = root
		topPos = Vector3.new(x + off.X, y0 + h / segs, z + off.Z)
	end
	for i = 1, 8 do
		local a = i * math.pi / 4 + rng:NextNumber(-0.2, 0.2)
		local leaf = part("Folha", Vector3.new(1.6, 0.15, 7), CFrame.new(topPos) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.8, -3.2) * CFrame.Angles(math.rad(-28), 0, 0), GREEN, Enum.Material.Grass, { CanCollide = false, CanQuery = false })
		leaf.Parent = root
	end
	ball("Coco", 0.45, topPos + Vector3.new(0.5, -0.3, 0.2), Color3.fromRGB(120, 90, 40), Enum.Material.Wood)
end
for _, p in { { CX - 40, FRONT_Z - 6 }, { CX - 46, FRONT_Z - 20 }, { CX + 40, FRONT_Z - 4 }, { CX + 48, FRONT_Z - 18 }, { CX - 34, FRONT_Z + 8 }, { CX + 36, FRONT_Z + 10 }, { CX - 52, FRONT_Z - 40 }, { CX + 54, FRONT_Z - 42 } } do
	palm(p[1], p[2])
end
-- cipós pendurados no lintel
for i = 0, 14 do
	local x = CX - HALF_W + 1 + i * (HALF_W * 2 - 2) / 14
	local len = rng:NextNumber(3, 9)
	cyl("Cipo", 0.12, len, CFrame.new(x + rng:NextNumber(-0.5, 0.5), GROUND + ROOF_Y - 3 - len / 2, FRONT_Z - 1.8), GREEN_DARK, Enum.Material.Grass, { CanCollide = false, CanQuery = false })
	for j = 1, 3 do
		part("CipoFolha", Vector3.new(0.5, 0.08, 0.9), CFrame.new(x + rng:NextNumber(-0.4, 0.4), GROUND + ROOF_Y - 3 - rng:NextNumber(0.5, len), FRONT_Z - 1.8) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), GREEN, Enum.Material.Grass, { CanCollide = false, CanQuery = false })
	end
end
-- juncos em volta do lago
for i = 1, 26 do
	local a = rng:NextNumber(0, math.pi)
	local r = rng:NextNumber(W / 2 + 6, W / 2 + 10)
	local x, z = CX + math.cos(a) * r, FRONT_Z - 3 - math.abs(math.sin(a)) * r * 0.55
	local hgt = rng:NextNumber(2, 4)
	cyl("Junco", 0.08, hgt, CFrame.new(x, GROUND + hgt / 2, z) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8))), GREEN_DARK, Enum.Material.Grass, { CanCollide = false, CanQuery = false })
	ball("JuncoTopo", 0.2, Vector3.new(x, GROUND + hgt, z), Color3.fromRGB(110, 80, 50), Enum.Material.Fabric)
end
-- musgo nas rochas e no chão
for i = 1, 18 do
	local sx = if i % 2 == 0 then 1 else -1
	part("Musgo", Vector3.new(rng:NextNumber(2, 5), 0.15, rng:NextNumber(2, 5)), CFrame.new(CX + sx * rng:NextNumber(HALF_W - 6, HALF_W + 12), GROUND + 0.05, FRONT_Z + rng:NextNumber(-20, depth)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), GREEN_DARK, Enum.Material.Grass, { CanCollide = false, CanQuery = false })
end

local n = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
print(("[altar] gruta + cachoeira montadas: %d peças"):format(n))
