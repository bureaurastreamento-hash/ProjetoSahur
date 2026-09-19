--[[
	montar_lojinha.luau — roda NO STUDIO (MCP run_code). Idempotente: apaga e refaz `Workspace.LojinhaDecor`.
	Ambientação da LOJINHA (dono, 2026-09-20: "estilizar o ambiente da lojinha / Banheiro.Union"): a
	construção é a Union `Workspace.Banheiro.Union` (quiosque de madeira, aberto na frente/esquerda, parede à
	direita do vendedor). Tudo é posicionado a partir da part `VendedorSpot` (frente = para onde o vendedor
	olha): balcão com mercadorias, estante com poções atrás, toldo listrado e placa "LOJINHA" na frente,
	bandeirinhas, lanternas em postes, caixotes, barris, vasos, tapete. Clona poções/garrafas/louça do kit
	`Moveis taverna` quando existe. Nada do place é movido/apagado. O dono SALVA o place depois.
]]

local Workspace = game:GetService("Workspace")

local spot = Workspace:FindFirstChild("VendedorSpot", true)
assert(spot and spot:IsA("BasePart"), "sem Workspace...VendedorSpot")
local kit = Workspace:FindFirstChild("Moveis taverna")

local old = Workspace:FindFirstChild("LojinhaDecor")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "LojinhaDecor"
root.Parent = Workspace

local ground = spot.Position.Y - spot.Size.Y / 2 -- topo do chão ≈ base da part
local look = Vector3.new(spot.CFrame.LookVector.X, 0, spot.CFrame.LookVector.Z).Unit
local S = CFrame.lookAt(Vector3.new(spot.Position.X, ground, spot.Position.Z), Vector3.new(spot.Position.X, ground, spot.Position.Z) + look)
-- S * CFrame.new(x, y, z): x = direita do vendedor, y = altura a partir do chão, z NEGATIVO = frente (clientes)

local WOOD_DARK = Color3.fromRGB(70, 46, 28)
local WOOD = Color3.fromRGB(125, 86, 50)
local WOOD_LIGHT = Color3.fromRGB(160, 118, 74)
local IRON = Color3.fromRGB(50, 48, 46)
local RED = Color3.fromRGB(170, 40, 40)
local CREAM = Color3.fromRGB(235, 220, 190)

local function part(name, size, cf, color, material, props)
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
	p.Parent = root
	return p
end
local function at(x, y, z, yaw)
	return S * CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
end
local function cyl(name, radius, height, cf, color, material)
	local p = part(name, Vector3.new(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.pi / 2), color, material)
	p.Shape = Enum.PartType.Cylinder
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
local function clone(name, cf, yaw)
	local src = kit and kit:FindFirstChild(name, true)
	if not src then
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
	c:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, (yaw or 0) + math.atan2(-look.X, -look.Z), 0) * pivot.Rotation)
	c.Parent = root
	return c
end

-- ---------------------------------------------------------------------------
-- Balcão na frente do vendedor + mercadorias
-- ---------------------------------------------------------------------------
part("Balcao", Vector3.new(9, 3, 1.6), at(0, 1.5, -3), WOOD, Enum.Material.WoodPlanks)
part("BalcaoTampo", Vector3.new(9.6, 0.3, 2.2), at(0, 3.15, -3), WOOD_DARK, Enum.Material.Wood)
part("BalcaoFriso", Vector3.new(9, 0.4, 0.2), at(0, 2.2, -3.9), WOOD_DARK, Enum.Material.Wood)
-- mercadorias em cima
clone("potion1", at(-3.2, 3.9, -3.2)) ; clone("potion2", at(-2.6, 3.85, -2.7)) ; clone("potion4", at(-2.0, 3.8, -3.3))
clone("Bottle_A_Large_GRP", at(2.6, 4.0, -3.0), 0.3)
clone("Stemware_Glass_Empty", at(3.6, 3.85, -3.4))
clone("Candle_Medium_A", at(0.8, 3.95, -3.3))
-- caixinha de pontos (baú) no canto do balcão
part("Bau", Vector3.new(1.6, 1, 1.1), at(-0.9, 3.8, -2.9), WOOD_DARK, Enum.Material.Wood)
part("BauTampa", Vector3.new(1.7, 0.3, 1.2), at(-0.9, 4.45, -2.9), WOOD, Enum.Material.Wood)
part("BauFecho", Vector3.new(0.3, 0.3, 0.1), at(-0.9, 4.1, -3.5), Color3.fromRGB(220, 180, 70), Enum.Material.Metal)
-- tapete do lado dos clientes
part("Tapete", Vector3.new(8, 0.12, 5), at(0, 0.06, -6.5), Color3.fromRGB(120, 40, 45), Enum.Material.Fabric)
part("TapeteBorda", Vector3.new(6.6, 0.13, 3.6), at(0, 0.065, -6.5), Color3.fromRGB(200, 170, 90), Enum.Material.Fabric)

-- ---------------------------------------------------------------------------
-- Estante atrás do vendedor (poções, garrafas, louça) + lanterna pendurada
-- ---------------------------------------------------------------------------
do
	local z = 3.6
	part("EstanteFundo", Vector3.new(7, 6.5, 0.3), at(0, 3.25, z + 0.6), WOOD_DARK, Enum.Material.WoodPlanks)
	for _, y in { 1.2, 3.0, 4.8 } do
		part("Prateleira", Vector3.new(7, 0.25, 1.4), at(0, y, z), WOOD, Enum.Material.Wood)
	end
	part("EstanteLado", Vector3.new(0.3, 6.5, 1.5), at(-3.5, 3.25, z), WOOD_DARK, Enum.Material.Wood)
	part("EstanteLado", Vector3.new(0.3, 6.5, 1.5), at(3.5, 3.25, z), WOOD_DARK, Enum.Material.Wood)
	clone("potion3", at(-2.6, 1.6, z)) ; clone("potion1", at(-1.8, 1.9, z)) ; clone("Bottle_E_GRP", at(0.2, 1.9, z)) ; clone("Glass_Empty", at(2.2, 1.65, z))
	clone("potion2", at(-2.4, 3.7, z)) ; clone("potion4", at(-1.2, 3.6, z)) ; clone("Bottle_A_Large_GRP", at(1.4, 3.85, z)) ; clone("Bowl_Stack", at(2.7, 3.65, z))
	clone("Plate_Stack", at(-2.2, 5.4, z)) ; clone("potion3", at(0.4, 5.4, z)) ; clone("Stemware_Glass_Empty", at(1.6, 5.4, z)) ; clone("potion1", at(2.6, 5.5, z))
	-- lanterna pendurada do teto (teto da union ≈ 8,3)
	part("Corrente", Vector3.new(0.12, 1.6, 0.12), at(0, 7.4, 0), IRON, Enum.Material.Metal)
	local lamp = part("Lanterna", Vector3.new(1, 1.3, 1), at(0, 6.0, 0), IRON, Enum.Material.Metal)
	part("LanternaVidro", Vector3.new(0.65, 0.85, 0.65), lamp.CFrame, Color3.fromRGB(255, 205, 130), Enum.Material.Neon, { CastShadow = false })
	light(lamp, Color3.fromRGB(255, 195, 120), 1.5, 18)
end

-- ---------------------------------------------------------------------------
-- Frente: toldo listrado, placa, bandeirinhas
-- ---------------------------------------------------------------------------
do
	-- toldo saindo da beira do telhado (y≈8,3) inclinado para fora
	local awning = part("Toldo", Vector3.new(12, 0.25, 4.5), at(0, 8.0, -6.8) * CFrame.Angles(math.rad(-18), 0, 0), RED, Enum.Material.Fabric)
	for i = -2, 2 do
		part("ToldoListra", Vector3.new(1.1, 0.27, 4.5), awning.CFrame * CFrame.new(i * 2.4, 0, 0), CREAM, Enum.Material.Fabric)
	end
	-- borda ondulada (franja)
	part("ToldoFranja", Vector3.new(12, 0.7, 0.2), awning.CFrame * CFrame.new(0, -0.35, 2.25), RED, Enum.Material.Fabric)
	-- placa LOJINHA pendurada na frente do toldo
	local sign = part("Placa", Vector3.new(7, 1.8, 0.35), at(0, 5.6, -9.2), WOOD_DARK, Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "LOJINHA"
	label.Font = Enum.Font.Antique
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(245, 215, 150)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	local gui2 = gui:Clone()
	gui2.Face = Enum.NormalId.Back
	gui2.Parent = sign
	for _, x in { -3, 3 } do
		part("PlacaCorrente", Vector3.new(0.1, 1.6, 0.1), at(x, 7.2, -9.2), IRON, Enum.Material.Metal)
	end
	-- bandeirinhas (varal de triângulos) na beira do telhado, dos dois lados
	local colors = { RED, CREAM, Color3.fromRGB(60, 120, 200), Color3.fromRGB(230, 190, 60) }
	for side = -1, 1, 2 do
		local x0 = side * 7
		part("Varal", Vector3.new(0.06, 0.06, 13), at(x0, 8.2, -1), IRON, Enum.Material.Metal)
		for i = 0, 7 do
			local z = -7 + i * 1.7
			local flag = part("Bandeirinha", Vector3.new(0.05, 0.9, 0.9), at(x0, 7.7, z), colors[(i % #colors) + 1], Enum.Material.Fabric)
			flag.Shape = Enum.PartType.Wedge
			flag.CFrame = at(x0, 7.7, z) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(90), 0)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Fora: lanternas em postes, caixotes, barril, vasos com plantas
-- ---------------------------------------------------------------------------
local function lampPost(x, z)
	cyl("Poste", 0.18, 6, at(x, 3, z), WOOD_DARK, Enum.Material.Wood)
	part("PosteBraco", Vector3.new(0.2, 0.2, 1.4), at(x, 5.9, z + 0.6), WOOD_DARK, Enum.Material.Wood)
	local lamp = part("PosteLanterna", Vector3.new(0.8, 1.1, 0.8), at(x, 5.3, z + 1.2), IRON, Enum.Material.Metal)
	part("PosteVidro", Vector3.new(0.5, 0.7, 0.5), lamp.CFrame, Color3.fromRGB(255, 205, 130), Enum.Material.Neon, { CastShadow = false })
	light(lamp, Color3.fromRGB(255, 195, 120), 1.4, 20)
end
lampPost(-7.5, -8) ; lampPost(7.5, -8)

local function crate(x, y, z, yaw, size)
	local s = size or 1.8
	local c = part("Caixote", Vector3.new(s, s, s), at(x, y + s / 2, z, yaw), WOOD_LIGHT, Enum.Material.WoodPlanks)
	for _, off in { { 0, 0, s / 2 }, { 0, 0, -s / 2 }, { s / 2, 0, 0 }, { -s / 2, 0, 0 } } do
		part("CaixoteRipa", Vector3.new(if off[1] == 0 then s + 0.05 else 0.15, 0.25, if off[1] == 0 then 0.15 else s + 0.05), c.CFrame * CFrame.new(off[1], 0, off[3]), WOOD_DARK, Enum.Material.Wood)
	end
	return c
end
crate(5.8, 0, -2, 0.2) ; crate(5.8, 1.8, -2, -0.3, 1.5) ; crate(4.2, 0, -4.5, 0.6, 1.4)
crate(-6.2, 0, 1.5, 0.1) ; crate(-6.2, 0, 3.5, -0.2, 1.6)
-- barril
do
	cyl("Barril", 1.3, 2.8, at(-5.6, 1.4, -4.8), WOOD, Enum.Material.Wood)
	for _, dy in { -1, 0, 1 } do
		cyl("Aro", 1.35, 0.22, at(-5.6, 1.4 + dy, -4.8), IRON, Enum.Material.Metal)
	end
end
-- vasos com planta
local function plant(x, z)
	local pot = cyl("Vaso", 0.9, 1.3, at(x, 0.65, z), Color3.fromRGB(150, 90, 60), Enum.Material.Slate)
	local top = cyl("VasoTerra", 0.8, 0.2, at(x, 1.35, z), Color3.fromRGB(60, 40, 30), Enum.Material.Ground)
	for i = 0, 5 do
		local a = i * math.pi / 3
		local leaf = part("Folha", Vector3.new(0.5, 1.8, 0.15), at(x + math.cos(a) * 0.35, 2.2, z + math.sin(a) * 0.35) * CFrame.Angles(0, -a, math.rad(25)), Color3.fromRGB(60, 140, 60), Enum.Material.Grass)
		leaf.CanCollide = false
	end
	pot.Parent = root
	top.Parent = root
end
plant(-4.6, -8.5) ; plant(4.6, -8.5) ; plant(-7, 5)

local n = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
		d.CanQuery = d.CanCollide -- decoração não atrapalha hitbox/raycast quando não colide
	end
end
print(("[lojinha] montada: %d peças"):format(n))
