--[[
	montar_arena_antiga.luau — roda DENTRO do Studio (MCP run_code ou barra de comando), no DataModel de edição.

	Transforma os muros que o dono puxou do projeto antigo (Workspace.ArenaAntiga: só as paredes, cinza)
	na arena da GUERRA DE CLÃ: recolore os muros, gera o interior (piso, plataformas, cobertura, tochas,
	bandeiras), os 3 pontos de captura (CapturePoints A/B/C) e os spawns (Spawns/Spawn1 oeste, Spawn2 leste),
	renomeia para Arena_Antiga e move para ServerStorage.Maps (WarService sorteia entre WarConfig.Maps).

	Pode rodar de novo: apaga o Interior/CapturePoints/Spawns gerados antes e refaz (os muros ficam).
	Tudo que ele cria vai dentro de pastas com atributo Gerado=true.
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local maps = ServerStorage:FindFirstChild("Maps")
if not maps then
	maps = Instance.new("Folder")
	maps.Name = "Maps"
	maps.Parent = ServerStorage
end

local arena = Workspace:FindFirstChild("ArenaAntiga") or maps:FindFirstChild("Arena_Antiga")
if not arena then
	error("Workspace.ArenaAntiga (ou ServerStorage.Maps.Arena_Antiga) não encontrado")
end

-- limpa o que foi gerado antes
for _, c in arena:GetChildren() do
	if c:GetAttribute("Gerado") then
		c:Destroy()
	end
end

local cf, size = arena:GetBoundingBox()
local minY = math.huge
local walls = {}
for _, d in arena:GetDescendants() do
	if d:IsA("BasePart") then
		minY = math.min(minY, d.Position.Y - d.Size.Y / 2)
		table.insert(walls, d)
	end
end
local cx, cz = cf.Position.X, cf.Position.Z
local floorY = minY

-- ---------------------------------------------------------------------------
-- Paleta (pedra antiga escura + detalhes)
-- ---------------------------------------------------------------------------
local WALL = { Enum.Material.Slate, Color3.fromRGB(88, 86, 92) }
local WALL_DARK = { Enum.Material.Slate, Color3.fromRGB(70, 68, 76) }
local FLOOR = { Enum.Material.Cobblestone, Color3.fromRGB(96, 94, 96) }
local FLOOR_PATH = { Enum.Material.Slate, Color3.fromRGB(122, 118, 112) }
local PLATFORM = { Enum.Material.Basalt, Color3.fromRGB(64, 64, 70) }
local SAND = { Enum.Material.Sandstone, Color3.fromRGB(150, 134, 104) }
local COVER = { Enum.Material.Basalt, Color3.fromRGB(78, 78, 84) }
local METAL = { Enum.Material.Metal, Color3.fromRGB(52, 50, 50) }
local TEAM = { Color3.fromRGB(70, 140, 255), Color3.fromRGB(255, 80, 80) }

-- muros: recolore com leve variação (não muda geometria)
local rng = Random.new(11)
for _, w in walls do
	local pal = if rng:NextNumber() < 0.3 then WALL_DARK else WALL
	w.Material = pal[1]
	local c = pal[2]
	local v = rng:NextNumber(-0.04, 0.04)
	w.Color = Color3.new(math.clamp(c.R + v, 0, 1), math.clamp(c.G + v, 0, 1), math.clamp(c.B + v, 0, 1))
	w.Anchored = true
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local interior = Instance.new("Folder")
interior.Name = "Interior"
interior:SetAttribute("Gerado", true)
interior.Parent = arena

local function part(name, sz, pos, pal, opts)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = sz
	p.CFrame = CFrame.new(cx + pos.X, floorY + pos.Y, cz + pos.Z) * CFrame.Angles(0, math.rad((opts and opts.yaw) or 0), 0)
	p.Material = pal[1]
	p.Color = pal[2]
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts then
		if opts.shape then
			p.Shape = opts.shape
		end
		if opts.transparency then
			p.Transparency = opts.transparency
		end
		if opts.collide == false then
			p.CanCollide = false
		end
		if opts.shadow == false then
			p.CastShadow = false
		end
	end
	p.Parent = (opts and opts.parent) or interior
	return p
end

local function cylinder(name, radius, height, pos, pal, opts)
	local p = part(name, Vector3.new(height, radius * 2, radius * 2), pos, pal, opts)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(cx + pos.X, floorY + pos.Y, cz + pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

local function light(p, color, brightness, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = p
	return l
end

local function fire(p, color)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color, Color3.fromRGB(100, 20, 0))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.0), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Rate = 14
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(12, 12)
	e.LightEmission = 1
	e.Acceleration = Vector3.new(0, 3, 0)
	e.Parent = p
	return e
end

-- ---------------------------------------------------------------------------
-- Interior (coordenadas relativas ao centro da caixa dos muros; o interior útil fica deslocado para o
-- sul porque o bloco norte dos muros é grosso). Mapa simétrico em X para os dois times.
-- ---------------------------------------------------------------------------
local ZC = 42 -- centro do interior útil (z)
local HX, HZ = 160, 130 -- meio-tamanho do interior (muros: x ±165/175, z −97..183 em relação ao centro da caixa)

-- piso geral (cobre toda a caixa, inclusive por baixo dos muros)
part("Floor", Vector3.new(size.X + 4, 2, size.Z + 4), Vector3.new(0, -1, 0), FLOOR)
-- faixa de areia batida na área de luta
part("FloorArena", Vector3.new(HX * 2, 0.3, HZ * 2), Vector3.new(0, 0.15, ZC), SAND)
-- caminhos de pedra ligando os 3 pontos e os spawns
part("PathEW", Vector3.new(HX * 2 - 20, 0.35, 14), Vector3.new(0, 0.2, ZC), FLOOR_PATH)
part("PathNS", Vector3.new(14, 0.35, HZ * 2 - 20), Vector3.new(0, 0.2, ZC), FLOOR_PATH)

-- ponto central (B): plataforma redonda alta com 4 rampas
cylinder("CenterPlatform", 26, 3, Vector3.new(0, 1.5, ZC), PLATFORM)
cylinder("CenterRing", 20, 3.6, Vector3.new(0, 1.8, ZC), FLOOR_PATH)
for i, ang in ipairs({ 0, 90, 180, 270 }) do
	local r = math.rad(ang)
	local dx, dz = math.cos(r), math.sin(r)
	local ramp = Instance.new("WedgePart")
	ramp.Name = "CenterRamp" .. i
	ramp.Anchored = true
	ramp.Size = Vector3.new(12, 3.4, 14)
	ramp.Material = PLATFORM[1]
	ramp.Color = PLATFORM[2]
	ramp.CFrame = CFrame.new(cx + dx * 33, floorY + 1.7, cz + ZC + dz * 33) * CFrame.Angles(0, -r - math.rad(90), 0) -- lado alto (+Z do wedge) virado para o centro
	ramp.Parent = interior
end
for i = 1, 4 do
	local r = math.rad(45 + (i - 1) * 90)
	local px, pz = math.cos(r) * 23, ZC + math.sin(r) * 23
	cylinder("CenterPillar" .. i, 1.4, 12, Vector3.new(px, 9, pz), COVER)
	local brazier = cylinder("CenterBrazier" .. i, 1.2, 0.8, Vector3.new(px, 15.4, pz), METAL)
	fire(brazier, Color3.fromRGB(255, 150, 60))
	light(brazier, Color3.fromRGB(255, 160, 80), 2, 26)
end

-- plataformas laterais (A oeste, C leste): meia altura, com degraus
for sx, tag in pairs({ [-1] = "W", [1] = "E" }) do
	local px = sx * 105
	part("SidePlatform" .. tag, Vector3.new(44, 2, 44), Vector3.new(px, 1, ZC), PLATFORM)
	part("SideStep" .. tag, Vector3.new(52, 1, 52), Vector3.new(px, 0.5, ZC), FLOOR_PATH)
	-- muretas em L protegendo os lados
	for _, sz in ipairs({ -1, 1 }) do
		part("SideWall" .. tag .. (sz > 0 and "S" or "N"), Vector3.new(18, 4, 2), Vector3.new(px - sx * 8, 4, ZC + sz * 21), COVER)
		part("SideWall2" .. tag .. (sz > 0 and "S" or "N"), Vector3.new(2, 4, 12), Vector3.new(px - sx * 21, 4, ZC + sz * 16), COVER)
	end
end

-- cobertura espalhada (blocos, colunas quebradas, caixotes) em espelho
local covers = {
	{ Vector3.new(55, 3, 5), Vector3.new(-55, 3, ZC - 70), 20 },
	{ Vector3.new(5, 3, 3), Vector3.new(-45, 3, ZC + 75), 0 },
	{ Vector3.new(8, 6, 8), Vector3.new(-70, 3, ZC + 30), 15 },
	{ Vector3.new(8, 6, 8), Vector3.new(-70, 3, ZC - 30), -15 },
	{ Vector3.new(14, 3, 3), Vector3.new(-25, 1.5, ZC + 55), 30 },
	{ Vector3.new(14, 3, 3), Vector3.new(-25, 1.5, ZC - 55), -30 },
	{ Vector3.new(6, 9, 6), Vector3.new(-130, 4.5, ZC + 70), 0 },
	{ Vector3.new(6, 9, 6), Vector3.new(-130, 4.5, ZC - 70), 0 },
	{ Vector3.new(10, 2.5, 4), Vector3.new(-150, 1.25, ZC + 20), 0 },
	{ Vector3.new(10, 2.5, 4), Vector3.new(-150, 1.25, ZC - 20), 0 },
}
for i, c in ipairs(covers) do
	local sz, pos, yaw = c[1], c[2], c[3]
	part(("Cover%dW"):format(i), sz, pos, COVER, { yaw = yaw })
	part(("Cover%dE"):format(i), sz, Vector3.new(-pos.X, pos.Y, pos.Z), COVER, { yaw = -yaw })
end
-- colunas quebradas norte/sul da área central
for i = 1, 6 do
	local px = -100 + (i - 1) * 40
	for _, sz in ipairs({ -1, 1 }) do
		local h = 6 + rng:NextNumber(0, 8)
		cylinder(("BrokenColumn%d%s"):format(i, sz > 0 and "S" or "N"), 2, h, Vector3.new(px, h / 2, ZC + sz * 110), COVER)
	end
end

-- tochas nos muros internos (luz quente) — em volta do interior
for i = 0, 7 do
	local px = -HX + 20 + i * ((HX * 2 - 40) / 7)
	for _, sz in ipairs({ -1, 1 }) do
		local t = cylinder(("WallTorch%d%s"):format(i, sz > 0 and "S" or "N"), 0.4, 2, Vector3.new(px, 9, ZC + sz * (HZ + 2)), METAL)
		fire(t, Color3.fromRGB(255, 140, 50))
		light(t, Color3.fromRGB(255, 150, 80), 1.6, 30)
	end
end

-- bandeiras dos times atrás de cada spawn (mastro + pano)
for teamId, sx in ipairs({ -1, 1 }) do
	local px = sx * (HX - 14)
	cylinder("FlagPole" .. teamId, 0.35, 16, Vector3.new(px, 8, ZC), METAL)
	-- pano no plano ZY: quem olha do centro vê a bandeira de frente
	part("Flag" .. teamId, Vector3.new(0.3, 6, 9), Vector3.new(px, 12.5, ZC + 4.6), { Enum.Material.Fabric, TEAM[teamId] })
	for _, sz in ipairs({ -1, 1 }) do
		part(("Banner%d%s"):format(teamId, sz > 0 and "S" or "N"), Vector3.new(0.3, 12, 5), Vector3.new(px + sx * 8, 14, ZC + sz * 40), { Enum.Material.Fabric, TEAM[teamId] }, { shadow = false })
	end
end

-- ---------------------------------------------------------------------------
-- CapturePoints (A oeste, B centro, C leste) e Spawns
-- ---------------------------------------------------------------------------
local cps = Instance.new("Folder")
cps.Name = "CapturePoints"
cps:SetAttribute("Gerado", true)
cps.Parent = arena
for _, def in ipairs({ { "A", -105, 2.2 }, { "B", 0, 3.2 }, { "C", 105, 2.2 } }) do
	local p = cylinder(def[1], 12, 0.3, Vector3.new(def[2], def[3], ZC), { Enum.Material.Neon, Color3.fromRGB(180, 180, 190) }, { parent = cps, collide = false, shadow = false })
	p.Transparency = 0.35
end

local spawns = Instance.new("Folder")
spawns.Name = "Spawns"
spawns:SetAttribute("Gerado", true)
spawns.Parent = arena
for teamId, sx in ipairs({ -1, 1 }) do
	local p = part("Spawn" .. teamId, Vector3.new(10, 1, 10), Vector3.new(sx * (HX - 30), 0.5, ZC), { Enum.Material.SmoothPlastic, TEAM[teamId] }, { parent = spawns, collide = false, shadow = false })
	p.Transparency = 1
	p.CFrame = CFrame.new(p.Position, p.Position + Vector3.new(-sx, 0, 0)) -- olhando para o centro
end

-- ---------------------------------------------------------------------------
-- Renomeia e guarda em ServerStorage.Maps
-- ---------------------------------------------------------------------------
arena.Name = "Arena_Antiga"
arena.PrimaryPart = nil
arena:SetAttribute("WarOnly", true) -- fora da rotação de rounds do ArenaService
if arena.Parent ~= maps then
	arena.Parent = maps
end
local n = 0
for _, d in arena:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
print(("[montar_arena_antiga] ServerStorage.Maps.Arena_Antiga pronta: %d parts, chão y=%.1f, centro (%.0f, %.0f)"):format(n, floorY, cx, cz))
