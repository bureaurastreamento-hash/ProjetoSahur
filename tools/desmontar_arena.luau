--[[
	desmontar_arena.luau (Lune) — ~/.rokit/bin/lune run tools/desmontar_arena.luau
	Leva ÚNICA (2026-09-28, dono autorizou): a arena fechada (src/workspace/Arena.rbxm) vira peças do
	arquipélago do Capítulo 1 (ver MAPA_CAPITULO_1.md "Layout do mundo"):
	  - src/workspace/Coliseu.rbxm     — Ilha 2 (Parte 2): piso = ladrilhos do centro da arena (raio 72),
	                                     anel dos 16 pilares em volta.
	  - src/workspace/PecasArena.rbxm  — ficam no mundo: montanha da Taberna (rochas da muralha em volta do
	                                     `cav`, sem mover), Parque A (canto NW) na Ilha 1, 8 árvores (4 Ilha 1, 4 Ilha 2).
	  - src/reserva/ArenaReserva.rbxm  — o resto (muralhas, cercas, estradas, piso restante, Parque B, KOTH):
	                                     ServerStorage.ArenaReserva, nada foi apagado (Parque B = futura Parte 4).
	Lê o original de backups/Arena_original_2026-09-28.rbxm (cópia feita antes) para poder rodar de novo.
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Instance = roblox.Instance

local ORIGINAL = "backups/Arena_original_2026-09-28.rbxm"
if not fs.isFile(ORIGINAL) then
	fs.copy("src/workspace/Arena.rbxm", ORIGINAL)
end
local arena = roblox.deserializeModel(fs.readFile(ORIGINAL))[1]

-- ---------------------------------------------------------------------------
-- Layout (espelhado em WorldConfig / tools/studio/MontarMundo.luau)
local COLISEU = Vector3.new(900, 0, -340) -- Ilha 2
local TILE_RADIUS = 72
local PILLAR_RING = 84
local PARQUE_A_ALVO = Vector3.new(160, 0, -20) -- Ilha 1 (centro XZ do parque)
local TREE_TARGETS = { -- Ilha 1 (4) e Ilha 2 (4), centro XZ de cada árvore
	Vector3.new(300, 0, -260), Vector3.new(250, 0, -230), Vector3.new(60, 0, -260), Vector3.new(420, 0, -120),
	Vector3.new(650, 0, -600), Vector3.new(720, 0, -270), Vector3.new(1120, 0, -660), Vector3.new(760, 0, -700),
}
-- montanha da Taberna: peças da muralha que encostam na caverna (cav) ficam no lugar
local TABERNA_BOX = { x0 = 255, x1 = 410, z0 = 10, z1 = 160 }
-- ---------------------------------------------------------------------------

local function parts(inst)
	local out = {}
	if inst:IsA("BasePart") then
		table.insert(out, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function centerXZ(inst): Vector3
	local list = parts(inst)
	local sx, sz = 0, 0
	for _, p in list do
		sx += p.CFrame.Position.X
		sz += p.CFrame.Position.Z
	end
	return Vector3.new(sx / #list, 0, sz / #list)
end

local function translate(inst, delta: Vector3)
	for _, p in parts(inst) do
		p.CFrame = p.CFrame + delta
	end
end

local function model(name: string, parent)
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

local coliseu = model("Coliseu")
local pecas = model("PecasArena")
local reserva = Instance.new("Folder")
reserva.Name = "ArenaReserva"

-- 1) piso do coliseu: ladrilhos do centro
local piso = model("Piso", coliseu)
local tilesRest = model("LadrilhosRestantes", reserva)
local nTiles = 0
for _, t in parts(arena.Tiles) do
	local p = t.CFrame.Position
	if math.sqrt(p.X * p.X + p.Z * p.Z) <= TILE_RADIUS then
		t.CFrame = t.CFrame + COLISEU
		t.Parent = piso
		nTiles += 1
	else
		t.Parent = tilesRest
	end
end

-- 2) anel dos pilares (cada Model gira para encarar o centro)
local pilares = model("Pilares", coliseu)
local pillarList = arena.Pillars:GetChildren()
for i, pm in pillarList do
	local c = centerXZ(pm)
	local a = (i - 1) / #pillarList * math.pi * 2
	local target = COLISEU + Vector3.new(math.cos(a) * PILLAR_RING, 0, math.sin(a) * PILLAR_RING)
	local rot = CFrame.new(target) * CFrame.Angles(0, -a, 0) * CFrame.new(-c.X, 0, -c.Z)
	for _, p in parts(pm) do
		p.CFrame = rot * p.CFrame
	end
	pm.Name = "Pilar" .. i
	pm.Parent = pilares
end

-- 3) montanha da Taberna (não move) + chão de grama dela
local rochas = model("RochaTaberna", pecas)
for _, wm in arena.Walls:GetChildren() do
	for _, p in parts(wm) do
		local pos, s = p.CFrame.Position, p.Size
		local r = math.max(s.X, s.Z) / 2
		if pos.X + r > TABERNA_BOX.x0 and pos.X - r < TABERNA_BOX.x1 and pos.Z + r > TABERNA_BOX.z0 and pos.Z - r < TABERNA_BOX.z1 then
			-- Slate azulado destoava na ilha aberta com a iluminação cartoon: rocha quente (grama fica verde)
			if p.Material == roblox.Enum.Material.Slate then
				p.Material = roblox.Enum.Material.Rock
				p.Color = roblox.Color3.fromRGB(128, 116, 102)
			end
			p.Parent = rochas
		end
	end
end

-- 4) parques dos cantos: A (z > 0) vai para a Ilha 1; B fica na reserva
for _, cm in arena.Corners:GetChildren() do
	local list = parts(cm)
	if #list > 50 then
		local c = centerXZ(cm)
		if c.Z > 0 then
			translate(cm, PARQUE_A_ALVO - c)
			cm.Name = "ParqueVitoriano"
			cm.Parent = pecas
		else
			cm.Name = "ParqueB_reserva"
			cm.Parent = reserva
		end
	end
end

-- 5) árvores soltas
local arvores = model("Arvores", pecas)
for i, tm in arena.Trees:GetChildren() do
	local target = TREE_TARGETS[i]
	if target then
		translate(tm, target - centerXZ(tm))
		tm.Name = "Arvore" .. i
		tm.Parent = arvores
	end
end

-- 6) o resto vai inteiro para a reserva
for _, g in arena:GetChildren() do
	g.Parent = reserva
end

fs.writeDir("src/reserva")
fs.writeFile("src/workspace/Coliseu.rbxm", roblox.serializeModel({ coliseu }))
fs.writeFile("src/workspace/PecasArena.rbxm", roblox.serializeModel({ pecas }))
fs.writeFile("src/reserva/ArenaReserva.rbxm", roblox.serializeModel({ reserva }))
print(("coliseu: %d ladrilhos, %d pilares | pecas: %d rochas da Taberna | reserva: %d peças"):format(
	nTiles, #pillarList, #rochas:GetChildren(), #parts(reserva)))
