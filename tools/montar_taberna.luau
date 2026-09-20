--[[
	montar_taberna.luau — roda NO STUDIO (via MCP run_code, no DataModel de edição). Idempotente.
	Ambientação da TABERNA NA CAVERNA (dono, 2026-09-20): o buraco nas muralhas `Workspace.cav` (sala
	x 325..381, z 28..129, chão y=-1, teto y=26; alcova a oeste x 283..325, z 76..112, teto 18) já tem o
	kit `Workspace["Moveis taverna"]`: o BAR do dono no canto sudoeste (x 325..356, z 26..44, frente para
	o norte com 6 banquetas), o balcão de boticário na parede oeste (z 53..68) e a porta de entrada no
	norte (x 369, z 130). O resto do kit está amontoado na alcova; daqui CLONAMOS o que serve.
	Cria `Workspace.Taberna` (apaga o anterior): piso de tábuas, vigas, lanternas penduradas, mesas
	redondas + banquinhos, mesa longa + bancos, lareira na parede leste, tochas nas paredes, barris,
	tapete, piano (clone), castiçais, louça, quadros, placa na entrada. Nada do kit original é movido ou
	apagado. O dono precisa SALVAR o place depois (não passa pelo Rojo).

	!!! TRAVADO desde 2026-09-25: o dono EDITOU a Taberna e o entorno À MÃO no Studio. Rodar isto de novo
	APAGA o trabalho dele. Só roda se `_G.RECRIAR_TABERNA = true` for setado antes (e com o dono pedindo).
	Backup do estado dele: backups/workspace_dono_2026-09-25.{jsonl,rbxm} (tools/restaurar_workspace.luau).
]]
assert(_G.RECRIAR_TABERNA == true, "montar_taberna: travado — a Taberna é editada à mão pelo dono (ver cabeçalho)")

local Workspace = game:GetService("Workspace")

local X0, X1, Z0, Z1 = 325, 381, 28, 129
local FLOOR, CEIL = -1, 26
local kit = Workspace:FindFirstChild("Moveis taverna")
assert(kit, "sem Workspace['Moveis taverna']")

local old = Workspace:FindFirstChild("Taberna")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "Taberna"
root.Parent = Workspace

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end
local Estrutura, Moveis, Luz, Decor = folder("Estrutura"), folder("Moveis"), folder("Luz"), folder("Decor")

local WOOD_DARK = Color3.fromRGB(78, 52, 32)
local WOOD = Color3.fromRGB(120, 84, 50)
local WOOD_LIGHT = Color3.fromRGB(150, 110, 70)
local IRON = Color3.fromRGB(55, 52, 50)
local STONE = Color3.fromRGB(70, 66, 64)

local function part(name, size, cf, color, material, parent, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function cylinder(name, radius, height, cf, color, material, parent, props)
	-- cilindro em pé: eixo do Cylinder é X, então gira 90° em Z
	local p = part(name, Vector3.new(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, parent, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function pointLight(parent, color, brightness, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	return l
end

--- Clona um modelo/peça do kit e põe o pivô em `cf` (mantendo a rotação original + yaw).
local function clone(name, cf, yaw, parent)
	local src = kit:FindFirstChild(name, true)
	if not src then
		warn("[taberna] kit sem " .. name)
		return nil
	end
	local c = src:Clone()
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	if c:IsA("BasePart") then
		c.Anchored = true
	end
	local pivot = c:GetPivot()
	c:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, yaw or 0, 0) * pivot.Rotation)
	c.Parent = parent or Decor
	return c
end

-- ---------------------------------------------------------------------------
-- Estrutura: piso, vigas, lambris
-- ---------------------------------------------------------------------------
local cx, cz = (X0 + X1) / 2, (Z0 + Z1) / 2
part("Piso", Vector3.new(X1 - X0 - 0.4, 0.2, Z1 - Z0 - 0.4), CFrame.new(cx, FLOOR + 0.1, cz), Color3.fromRGB(92, 62, 38), Enum.Material.WoodPlanks, Estrutura)
-- rodapé de pedra nas paredes
for _, side in { { X0 + 0.6, cz, Vector3.new(0.8, 1.2, Z1 - Z0) }, { X1 - 0.6, cz, Vector3.new(0.8, 1.2, Z1 - Z0) }, { cx, Z0 + 0.6, Vector3.new(X1 - X0, 1.2, 0.8) }, { cx, Z1 - 0.6, Vector3.new(X1 - X0, 1.2, 0.8) } } do
	part("Rodape", side[3], CFrame.new(side[1], FLOOR + 0.6, side[2]), STONE, Enum.Material.Slate, Estrutura)
end
-- vigas do teto (atravessam em x) + cumeeira em z
for z = Z0 + 12, Z1 - 6, 12 do
	part("Viga", Vector3.new(X1 - X0, 1.4, 1.4), CFrame.new(cx, CEIL - 0.7, z), WOOD_DARK, Enum.Material.Wood, Estrutura)
end
part("Cumeeira", Vector3.new(1.6, 1.6, Z1 - Z0), CFrame.new(cx, CEIL - 1.6, cz), WOOD_DARK, Enum.Material.Wood, Estrutura)
-- pilares de madeira encostados nas paredes (ritmo visual)
for _, z in { 52, 76, 100, 124 } do
	part("Pilar", Vector3.new(1.2, CEIL - FLOOR, 1.2), CFrame.new(X0 + 0.9, (CEIL + FLOOR) / 2, z), WOOD_DARK, Enum.Material.Wood, Estrutura)
	part("Pilar", Vector3.new(1.2, CEIL - FLOOR, 1.2), CFrame.new(X1 - 0.9, (CEIL + FLOOR) / 2, z), WOOD_DARK, Enum.Material.Wood, Estrutura)
end

-- ---------------------------------------------------------------------------
-- Lareira na parede leste (z ≈ 85)
-- ---------------------------------------------------------------------------
local FZ = 85
local hearthX = X1 - 2.5
part("LareiraCorpo", Vector3.new(5, 9, 10), CFrame.new(hearthX, FLOOR + 4.5, FZ), STONE, Enum.Material.Slate, Estrutura)
part("LareiraChamine", Vector3.new(4, CEIL - FLOOR - 9, 6), CFrame.new(hearthX + 0.5, FLOOR + 9 + (CEIL - FLOOR - 9) / 2, FZ), STONE, Enum.Material.Slate, Estrutura)
part("LareiraBoca", Vector3.new(1.5, 5, 6), CFrame.new(X1 - 5.4, FLOOR + 2.5, FZ), Color3.fromRGB(20, 18, 18), Enum.Material.Slate, Estrutura)
part("LareiraMantel", Vector3.new(6, 0.5, 11), CFrame.new(hearthX - 0.3, FLOOR + 9.25, FZ), WOOD_DARK, Enum.Material.Wood, Estrutura)
part("LareiraBase", Vector3.new(4, 0.3, 12), CFrame.new(X1 - 7, FLOOR + 0.35, FZ), STONE, Enum.Material.Cobblestone, Estrutura)
local embers = part("Brasas", Vector3.new(1.2, 0.6, 4), CFrame.new(X1 - 5.4, FLOOR + 0.6, FZ), Color3.fromRGB(255, 120, 30), Enum.Material.Neon, Luz, { CastShadow = false })
local fire = Instance.new("Fire")
fire.Size = 6
fire.Heat = 12
fire.Color = Color3.fromRGB(255, 150, 50)
fire.SecondaryColor = Color3.fromRGB(200, 60, 20)
fire.Parent = embers
pointLight(embers, Color3.fromRGB(255, 150, 70), 2.5, 34)
-- lenha
for i = 0, 2 do
	local log = part("Lenha", Vector3.new(3.2, 0.7, 0.7), CFrame.new(X1 - 5.4 + (i % 2) * 0.5, FLOOR + 0.5 + i * 0.55, FZ) * CFrame.Angles(0, math.pi / 2, 0), WOOD_DARK, Enum.Material.Wood, Decor)
	log.Shape = Enum.PartType.Cylinder
end

-- ---------------------------------------------------------------------------
-- Mesas redondas + banquinhos + castiçal + lanterna pendurada
-- ---------------------------------------------------------------------------
local function stool(pos, parent)
	cylinder("Banquinho", 0.7, 0.25, CFrame.new(pos.X, FLOOR + 1.4, pos.Z), WOOD_LIGHT, Enum.Material.Wood, parent)
	cylinder("BanquinhoPe", 0.18, 1.3, CFrame.new(pos.X, FLOOR + 0.75, pos.Z), WOOD_DARK, Enum.Material.Wood, parent)
end

local function lantern(x, z, hang, parent)
	local top = CEIL - 0.8
	part("Corrente", Vector3.new(0.15, hang, 0.15), CFrame.new(x, top - hang / 2, z), IRON, Enum.Material.Metal, parent)
	local body = part("Lanterna", Vector3.new(1.1, 1.4, 1.1), CFrame.new(x, top - hang - 0.7, z), IRON, Enum.Material.Metal, parent)
	part("LanternaVidro", Vector3.new(0.7, 0.9, 0.7), body.CFrame, Color3.fromRGB(255, 200, 120), Enum.Material.Neon, parent, { CastShadow = false })
	pointLight(body, Color3.fromRGB(255, 190, 110), 1.6, 24)
end

local function roundTable(x, z)
	local m = Instance.new("Model")
	m.Name = "MesaRedonda"
	m.Parent = Moveis
	cylinder("Tampo", 3, 0.3, CFrame.new(x, FLOOR + 3.05, z), WOOD, Enum.Material.Wood, m)
	cylinder("Coluna", 0.45, 2.7, CFrame.new(x, FLOOR + 1.55, z), WOOD_DARK, Enum.Material.Wood, m)
	cylinder("Pe", 1.4, 0.3, CFrame.new(x, FLOOR + 0.35, z), WOOD_DARK, Enum.Material.Wood, m)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		stool(Vector3.new(x + math.cos(a) * 4.2, 0, z + math.sin(a) * 4.2), m)
	end
	lantern(x, z, 9, Luz)
	return m
end

local tables = { { 346, 82 }, { 346, 104 }, { 364, 60 }, { 364, 100 }, { 374, 110 } }
for i, t in tables do
	local m = roundTable(t[1], t[2])
	local top = FLOOR + 3.2
	if i % 2 == 1 then
		clone("Candelabra", CFrame.new(t[1], top + 1.15, t[2]), 0, m)
	else
		clone("Candle_Medium_A", CFrame.new(t[1] - 0.6, top + 0.65, t[2]), 0, m)
		clone("Glass_Empty", CFrame.new(t[1] + 1.2, top + 0.4, t[2] + 0.8), 0, m)
		clone("Bottle_A_Large_GRP", CFrame.new(t[1] + 0.9, top + 0.75, t[2] - 1), 0, m)
	end
end
-- mesa perto do fogo + tapete do kit na frente da lareira
clone("Rug 4", CFrame.new(X1 - 13, FLOOR + 0.26, FZ), 0, Decor)

-- ---------------------------------------------------------------------------
-- Mesa longa (banquete) + bancos, no centro-norte
-- ---------------------------------------------------------------------------
do
	local m = Instance.new("Model")
	m.Name = "MesaLonga"
	m.Parent = Moveis
	local lx, lz = 352, 124 - 6
	part("Tampo", Vector3.new(14, 0.4, 3.6), CFrame.new(lx, FLOOR + 3.1, lz), WOOD, Enum.Material.WoodPlanks, m)
	for _, dx in { -6, 6 } do
		part("Pe", Vector3.new(0.6, 2.9, 3), CFrame.new(lx + dx, FLOOR + 1.45, lz), WOOD_DARK, Enum.Material.Wood, m)
	end
	for _, dz in { -3.2, 3.2 } do
		part("Banco", Vector3.new(13, 0.3, 1.2), CFrame.new(lx, FLOOR + 1.6, lz + dz), WOOD_LIGHT, Enum.Material.Wood, m)
		for _, dx in { -5.5, 5.5 } do
			part("BancoPe", Vector3.new(0.4, 1.45, 1), CFrame.new(lx + dx, FLOOR + 0.72, lz + dz), WOOD_DARK, Enum.Material.Wood, m)
		end
	end
	local top = FLOOR + 3.3
	clone("DinnerwareSet_1", CFrame.new(lx - 4, top + 0.15, lz), 0, m)
	clone("DinnerwareSet_1", CFrame.new(lx + 4, top + 0.15, lz), math.pi, m)
	clone("Candelabra", CFrame.new(lx, top + 1.15, lz), 0, m)
	clone("Bowl_Stack", CFrame.new(lx + 1.5, top + 0.55, lz + 0.9), 0, m)
	clone("Stemware_Glass_Empty", CFrame.new(lx - 1.6, top + 0.55, lz - 0.9), 0, m)
	lantern(lx - 4, lz, 8, Luz)
	lantern(lx + 4, lz, 8, Luz)
end

-- ---------------------------------------------------------------------------
-- Barris (canto sudeste, ao lado do bar) + garrafas
-- ---------------------------------------------------------------------------
local function barrel(x, y, z, parent)
	local b = cylinder("Barril", 1.5, 3.2, CFrame.new(x, y, z), WOOD, Enum.Material.Wood, parent)
	for _, dy in { -1.1, 0, 1.1 } do
		cylinder("Aro", 1.55, 0.25, CFrame.new(x, y + dy, z), IRON, Enum.Material.Metal, parent)
	end
	return b
end
do
	local m = Instance.new("Model")
	m.Name = "Barris"
	m.Parent = Moveis
	local bx, bz = X1 - 3.5, Z0 + 4
	barrel(bx, FLOOR + 1.6, bz, m)
	barrel(bx, FLOOR + 1.6, bz + 3.4, m)
	barrel(bx - 3.4, FLOOR + 1.6, bz, m)
	barrel(bx - 1.7, FLOOR + 4.8, bz + 1.7, m)
	barrel(bx - 8, FLOOR + 1.6, bz, m) -- deitado seria mais bonito, mas em pé fica estável
	clone("bottle", CFrame.new(bx - 1.7, FLOOR + 7.3, bz + 1.7), 0, m)
	clone("bottle", CFrame.new(bx - 3.4, FLOOR + 4.1, bz), 0.4, m)
	clone("Bottle_E_GRP", CFrame.new(bx - 8, FLOOR + 3.8, bz), 0, m)
end

-- ---------------------------------------------------------------------------
-- Tochas nas paredes
-- ---------------------------------------------------------------------------
local function torch(pos, facing, parent)
	-- facing = direção para dentro da sala
	local stick = part("Tocha", Vector3.new(0.3, 2.2, 0.3), CFrame.new(pos + facing * 0.5) * CFrame.Angles(0, 0, 0), WOOD_DARK, Enum.Material.Wood, parent)
	local flame = part("Chama", Vector3.new(0.6, 0.8, 0.6), CFrame.new(pos + facing * 0.5 + Vector3.new(0, 1.4, 0)), Color3.fromRGB(255, 170, 60), Enum.Material.Neon, parent, { CastShadow = false })
	local f = Instance.new("Fire")
	f.Size = 2
	f.Heat = 4
	f.Parent = flame
	pointLight(flame, Color3.fromRGB(255, 170, 80), 1.3, 18)
	part("Suporte", Vector3.new(0.5, 0.5, 0.5), CFrame.new(pos + facing * 0.25 + Vector3.new(0, -0.6, 0)), IRON, Enum.Material.Metal, parent)
	return stick
end
local TY = FLOOR + 7.5
for _, z in { 62, 88, 112 } do
	torch(Vector3.new(X0 + 0.4, TY, z), Vector3.new(1, 0, 0), Luz)
end
for _, z in { 48, 70, 104, 124 } do
	torch(Vector3.new(X1 - 0.4, TY, z), Vector3.new(-1, 0, 0), Luz)
end
for _, x in { 362, 374 } do
	torch(Vector3.new(x, TY, Z0 + 0.4), Vector3.new(0, 0, 1), Luz)
end
for _, x in { 340, 356 } do
	torch(Vector3.new(x, TY, Z1 - 0.4), Vector3.new(0, 0, -1), Luz)
end
-- luz de preenchimento quente (a caverna não recebe céu)
for _, p in { { 345, 60 }, { 365, 80 }, { 350, 110 }, { 370, 115 } } do
	local fill = part("Preenchimento", Vector3.new(0.2, 0.2, 0.2), CFrame.new(p[1], CEIL - 4, p[2]), IRON, Enum.Material.Metal, Luz, { Transparency = 1, CanCollide = false })
	pointLight(fill, Color3.fromRGB(255, 205, 150), 0.5, 40)
end

-- ---------------------------------------------------------------------------
-- Clones do kit: piano no canto noroeste, quadros, corvo, rádio, cabide de louça
-- ---------------------------------------------------------------------------
clone("Piano", CFrame.new(333, FLOOR + 2.05, 119), 0, Decor)
clone("Prop_RavenTaxidermy_R", CFrame.new(hearthX - 0.3, FLOOR + 9.5 + 0.9, FZ + 3), math.pi / 2, Decor) -- no mantel
clone("Radio", CFrame.new(hearthX - 0.3, FLOOR + 9.5 + 0.8, FZ - 3), -math.pi / 2, Decor)
clone("Bankers_Lamp_on", CFrame.new(328.8, 2.0 + 1.2, 101.7), 0, Decor) -- em cima da mesa de entrada do kit
-- quadros na parede oeste (viram para leste) e na parede norte
local fi = 0
for _, m in kit:GetChildren() do
	if m.Name == "Model" and (m:FindFirstChild("PictureFrameC") or m:FindFirstChild("PictureFrameB")) then
		fi += 1
		local c = m:Clone()
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		if fi <= 2 then
			c:PivotTo(CFrame.new(X0 + 0.7, FLOOR + 8, 40 + fi * 10) * CFrame.Angles(0, math.pi / 2, 0))
		else
			c:PivotTo(CFrame.new(348 + (fi - 3) * 12, FLOOR + 9, Z1 - 0.7))
		end
		c.Name = "Quadro"
		c.Parent = Decor
	end
end
-- prateleira com louça atrás do balcão de boticário (parede oeste, z 53..68) — hutch do kit
clone("DiningRoom_Hutch", CFrame.new(X0 + 1.6, FLOOR + 4.45, 74), math.pi / 2, Decor)

-- ---------------------------------------------------------------------------
-- Placa na entrada (fora, na boca do corredor z 129..142, virada para o norte)
-- ---------------------------------------------------------------------------
do
	local sign = part("Placa", Vector3.new(9, 2.4, 0.4), CFrame.new(368.8, FLOOR + 11, 143.2), WOOD_DARK, Enum.Material.Wood, Decor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "TABERNA DA CAVERNA"
	label.Font = Enum.Font.Antique
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(240, 210, 150)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	torch(Vector3.new(362.5, FLOOR + 9, 142.6), Vector3.new(0, 0, 1), Luz)
	torch(Vector3.new(375, FLOOR + 9, 142.6), Vector3.new(0, 0, 1), Luz)
	-- a placa é uma face só: vira para +z (norte), Front = -Z, então gira 180°
	sign.CFrame = sign.CFrame * CFrame.Angles(0, math.pi, 0)
end

local n = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
print(("[taberna] montada: %d peças"):format(n))
