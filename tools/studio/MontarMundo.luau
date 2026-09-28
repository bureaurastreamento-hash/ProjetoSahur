--[[
	MontarMundo — TERRENO do arquipélago do Capítulo 1. O Rojo sincroniza este ModuleScript em
	ServerStorage.FerramentasStudio; para (re)gerar, no Studio (MCP run_code ou barra de comando):
	    require(game.ServerStorage.FerramentasStudio.MontarMundo:Clone())
	Terrain não é versionado no git: se o place perder o terreno, rodar de novo (é determinístico).

	O que faz (2026-09-28, dono autorizou o arquipélago):
	  1. Limpa o Terrain e enche o MAR (água de verdade, nado nativo) na área do mundo.
	  2. Ilhas = elipses de WorldConfig.Islands (cópia em ISLANDS abaixo): grama no meio, praia, declive
	     submerso. Altura de TODAS as ilhas numa função só (as regiões do WriteVoxels se sobrepõem).
	  3. MESAS: montanha do santuário (Ilha 2, cachoeira de ~92 studs na face norte), promontório do farol (Ilha 1),
	     dunas (Ilha 3). A montanha do santuário é medida pelas peças reais (SanctShell*/Cascade*).
	  4. ESCAVA o que fica abaixo de y 0: Taberna, interior do santuário + túnel, riacho/lago do jardim.
	Chão das construções = y 0; topo do terreno = TOP (-0.15, sem z-fighting com pisos em 0).
]]
local Workspace = game:GetService("Workspace")
local terrain = Workspace.Terrain
local M = Enum.Material

local TOP = -0.15
local SOLID_OFFSET = 2 -- ver comentário no WriteVoxels
local SEA = -2 -- superfície do mar
local FLOOR = -44 -- fundo do mar
local WORLD = { x0 = -800, x1 = 2240, z0 = -1000, z1 = 880 } -- núcleo (mar fundo com areia no fundo)
local OCEAN = { x0 = -3600, x1 = 5000, z0 = -3600, z1 = 3400 } -- mar raso até o horizonte (borda não aparece)

local ISLANDS = { -- = WorldConfig.Islands
	{ id = "alvorecer", c = Vector3.new(150, 0, -40), rx = 330, rz = 290, grass = M.Grass, seed = 1 },
	{ id = "pilares", c = Vector3.new(910, 0, -500), rx = 320, rz = 290, grass = M.LeafyGrass, seed = 2 },
	{ id = "sol_partido", c = Vector3.new(1700, 0, -130), rx = 340, rz = 290, grass = M.Sand, seed = 3 },
	{ id = "kame", c = Vector3.new(-450, 0, 560), rx = 230, rz = 120, grass = M.Sand, seed = 4 },
}

-- mesa: caixa com topo plano e rampas (margens por lado; 0 = paredão)
type Mesa = { x0: number, x1: number, z0: number, z1: number, top: number, mx: number, mz0: number, mz1: number, mat: Enum.Material }
local MESAS: { Mesa } = {
	-- promontório do farol (Ilha 1)
	{ x0 = -62, x1 = -18, z0 = 186, z1 = 226, top = TOP, mx = 14, mz0 = 8, mz1 = 14, mat = M.Grass },
	-- dunas do Sol Partido
	{ x0 = 1860, x1 = 1930, z0 = -40, z1 = 20, top = 9, mx = 40, mz0 = 40, mz1 = 40, mat = M.Sand },
	{ x0 = 1560, x1 = 1640, z0 = -330, z1 = -280, top = 12, mx = 45, mz0 = 45, mz1 = 45, mat = M.Sand },
	{ x0 = 1960, x1 = 2000, z0 = -260, z1 = -150, top = 16, mx = 30, mz0 = 30, mz1 = 30, mat = M.Sandstone },
}
-- pintura do chão plano (círculos): areia da arena do coliseu (Ilha 2)
local PAINT = {
	{ c = Vector3.new(900, 0, -340), r = 97, mat = M.Sand },
}
local CARVES: { { min: Vector3, max: Vector3 } } = {}

local props = Workspace.Sahur.ArenaExtras.Props
local function aabb(prefixes: { string }, pad: number): (Vector3?, Vector3?)
	local mn, mx
	for _, p in props:GetChildren() do
		if p:IsA("BasePart") then
			for _, pre in prefixes do
				if p.Name:sub(1, #pre) == pre then
					local e = p.Size / 2
					local a, b = p.Position - e, p.Position + e
					mn = if mn then mn:Min(a) else a
					mx = if mx then mx:Max(b) else b
					break
				end
			end
		end
	end
	if not mn then
		return nil, nil
	end
	return mn - Vector3.new(pad, 0, pad), mx + Vector3.new(pad, 0, pad)
end

-- montanha do santuário: da face da caverna (norte) para trás, alta como a cachoeira
do
	local shellMin, shellMax = aabb({ "SanctShell" }, 0)
	local _, cascadeMax = aabb({ "CascadeFall", "CascadeSheet", "CascadeBasin" }, 0)
	assert(shellMin and shellMax and cascadeMax, "sem SanctShell/Cascade na ArenaExtras (Rojo sincronizou?)")
	table.insert(MESAS, {
		x0 = shellMin.X - 14, x1 = shellMax.X + 14, z0 = shellMin.Z, z1 = shellMax.Z + 16,
		top = cascadeMax.Y + 3, mx = 55, mz0 = 0, mz1 = 60, mat = M.Rock,
	})
	-- interior + túnel da caverna
	local floorMin, floorMax = aabb({ "SanctShellFloor" }, 0)
	local ceilMin = aabb({ "SanctShellCeil" }, 0)
	table.insert(CARVES, { min = Vector3.new(floorMin.X + 2, floorMax.Y, floorMin.Z + 4), max = Vector3.new(floorMax.X - 2, ceilMin.Y, floorMax.Z - 4) })
	local tMin, tMax = aabb({ "SanctTunnel" }, 1)
	table.insert(CARVES, { min = Vector3.new(tMin.X, 0, tMin.Z - 8), max = Vector3.new(tMax.X, tMax.Y + 1, tMax.Z) })
	-- riacho, lago e pedras do jardim ficam abaixo de 0
	for _, pre in { { "Stream" }, { "CascadePool" }, { "GardenSlab" } } do
		local a, b = aabb(pre, 1)
		if a and b then
			table.insert(CARVES, { min = Vector3.new(a.X, a.Y, a.Z), max = Vector3.new(b.X, 3, b.Z) })
		end
	end
end
-- Taberna/Hall (pisos em -0.8 e -0.3, dentro da montanha de pedra)
table.insert(CARVES, { min = Vector3.new(272, -0.8, 20), max = Vector3.new(392, 30, 142) })

-- ---------------------------------------------------------------------------
local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function mesaHeight(m: Mesa, x: number, z: number): number?
	local dx = if x < m.x0 then (m.x0 - x) / math.max(m.mx, 1e-3) elseif x > m.x1 then (x - m.x1) / math.max(m.mx, 1e-3) else 0
	local dz = if z < m.z0 then (if m.mz0 > 0 then (m.z0 - z) / m.mz0 else math.huge) elseif z > m.z1 then (z - m.z1) / math.max(m.mz1, 1e-3) else 0
	local d = math.sqrt(dx * dx + dz * dz)
	if d >= 1 then
		return nil
	end
	return m.top - (m.top - TOP) * smooth(d) - math.noise(x / 23, z / 23) * 3 * smooth(d)
end

--- (altura, material da superfície) do terreno em (x, z); nil = só mar.
local function heightAt(x: number, z: number): (number?, Enum.Material)
	local best, mat = nil, M.Sand
	for _, isl in ISLANDS do
		local dx, dz = (x - isl.c.X) / isl.rx, (z - isl.c.Z) / isl.rz
		local d = math.sqrt(dx * dx + dz * dz)
		d *= 1 + math.noise(x / 90, z / 90, isl.seed) * 0.12
		local h, m
		if d < 0.84 then
			h, m = TOP, isl.grass
			for _, p in PAINT do
				if (Vector3.new(x, 0, z) - p.c).Magnitude <= p.r then
					m = p.mat
				end
			end
		elseif d < 1.0 then
			h, m = TOP + (SEA - 0.8 - TOP) * smooth((d - 0.84) / 0.16), if d < 0.88 and isl.grass ~= M.Sand then isl.grass else M.Sand
		elseif d < 1.3 then
			h, m = (SEA - 0.8) + (-16 - (SEA - 0.8)) * smooth((d - 1.0) / 0.3), M.Sand
		end
		if h and (not best or h > best) then
			best, mat = h, m
		end
	end
	for _, ms in MESAS do
		local h = mesaHeight(ms, x, z)
		if h and (not best or h > best) then
			best, mat = h, if h > TOP + 1.5 then ms.mat else mat
		end
	end
	return best, mat
end

-- 1) mar
terrain:Clear()
local STEP = 512
for x = OCEAN.x0, OCEAN.x1 - 1, 2048 do
	for z = OCEAN.z0, OCEAN.z1 - 1, 2048 do
		local sx, sz = math.min(2048, OCEAN.x1 - x), math.min(2048, OCEAN.z1 - z)
		terrain:FillBlock(CFrame.new(x + sx / 2, SEA - 6, z + sz / 2), Vector3.new(sx, 12, sz), M.Water)
		terrain:FillBlock(CFrame.new(x + sx / 2, SEA - 14, z + sz / 2), Vector3.new(sx, 4, sz), M.Sand)
	end
end
for x = WORLD.x0, WORLD.x1 - 1, STEP do
	for z = WORLD.z0, WORLD.z1 - 1, STEP do
		local sx, sz = math.min(STEP, WORLD.x1 - x), math.min(STEP, WORLD.z1 - z)
		terrain:FillBlock(CFrame.new(x + sx / 2, (FLOOR + SEA) / 2, z + sz / 2), Vector3.new(sx, SEA - FLOOR, sz), M.Water)
		terrain:FillBlock(CFrame.new(x + sx / 2, FLOOR - 2, z + sz / 2), Vector3.new(sx, 4, sz), M.Sand)
	end
end

-- 2) ilhas (WriteVoxels em fatias de 32 colunas; altura de todas as ilhas/mesas em cada coluna)
local R = 4
local Y0 = FLOOR - 4
local voxels = 0
for _, isl in ISLANDS do
	local Y1 = if isl.id == "pilares" then 112 else 28 -- só a Ilha 2 tem a montanha da cachoeira
	local x0 = math.floor((isl.c.X - isl.rx * 1.35) / R) * R
	local x1 = math.ceil((isl.c.X + isl.rx * 1.35) / R) * R
	local z0 = math.floor((isl.c.Z - isl.rz * 1.35) / R) * R
	local z1 = math.ceil((isl.c.Z + isl.rz * 1.35) / R) * R
	local ny, nz = (Y1 - Y0) / R, (z1 - z0) / R
	for cx0 = x0, x1 - R, 32 * R do
		local cx1 = math.min(cx0 + 32 * R, x1)
		local nx = (cx1 - cx0) / R
		local mats, occs = table.create(nx), table.create(nx)
		for ix = 1, nx do
			local mcol, ocol = table.create(ny), table.create(ny)
			for iy = 1, ny do
				mcol[iy], ocol[iy] = table.create(nz, M.Air), table.create(nz, 0)
			end
			mats[ix], occs[ix] = mcol, ocol
			local x = cx0 + (ix - 0.5) * R
			for iz = 1, nz do
				local z = z0 + (iz - 0.5) * R
				local h, surf = heightAt(x, z)
				-- o terreno suave desenha a superfície sólida ~2 studs ACIMA da ocupação escrita (medido:
				-- ocupação até -0.15 => chão em 1.84); a água não tem esse desvio
				h = (h or FLOOR) - SOLID_OFFSET
				for iy = 1, ny do
					local yb = Y0 + (iy - 1) * R
					local yt = yb + R
					if yt <= h then
						mcol[iy][iz] = if h - yt < R then surf elseif surf == M.Sand then M.Sandstone else M.Rock
						ocol[iy][iz] = 1
					elseif yb < h then
						mcol[iy][iz] = surf
						ocol[iy][iz] = (h - yb) / R
					elseif yb < SEA then
						mcol[iy][iz] = M.Water
						ocol[iy][iz] = math.min(1, (SEA - yb) / R)
					end
				end
			end
		end
		terrain:WriteVoxels(Region3.new(Vector3.new(cx0, Y0, z0), Vector3.new(cx1, Y1, z1)), R, mats, occs)
		voxels += nx * ny * nz
		task.wait()
	end
end

-- 3) escavações
for _, c in CARVES do
	c = { min = c.min - Vector3.new(0, SOLID_OFFSET, 0), max = c.max }
	local size = c.max - c.min
	terrain:FillBlock(CFrame.new((c.min + c.max) / 2), size, M.Air)
end

-- 4) visual cartoon (combina com a iluminação do EnvironmentService)
terrain.WaterColor = Color3.fromRGB(38, 150, 190)
terrain.WaterTransparency = 0.35
terrain.WaterReflectance = 0.6
terrain.WaterWaveSize = 0.18
terrain.WaterWaveSpeed = 9
terrain:SetMaterialColor(M.Grass, Color3.fromRGB(104, 170, 72))
terrain:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(72, 142, 58))
terrain:SetMaterialColor(M.Sand, Color3.fromRGB(226, 202, 140))
terrain:SetMaterialColor(M.Sandstone, Color3.fromRGB(196, 150, 96))
terrain:SetMaterialColor(M.Rock, Color3.fromRGB(118, 112, 104))

print(("[montar_mundo] mar %dx%d, %d ilhas (%d voxels), %d mesas, %d escavações"):format(
	WORLD.x1 - WORLD.x0, WORLD.z1 - WORLD.z0, #ISLANDS, voxels, #MESAS, #CARVES))

return true
