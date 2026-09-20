--[[
	montar_hall.luau — roda NO STUDIO (via MCP run_code, DataModel de edição). Idempotente nas peças NOVAS.
	HALL DE ENTRADA da Taberna (dono, 2026-09-25): a sala dentro de `Workspace.cav` a oeste da taberna
	(x 274..325, z 78..110, teto `cav.Part2` a y 18,2; entrada oeste = vão entre `cav.Part5`/`Part6` sob a verga
	`Part7`, z 87,8..98,2; o lado leste abre direto para o salão, entre os pilares z 76/100).
	  - Cria `Workspace.Taberna.Hall` (apaga o anterior): piso de tábuas, tapete corredor, batentes + placa +
	    viga da entrada, PORTAS DE SALOON (duas asas que o SaloonDoorService abre quando alguém passa), tochas,
	    luzes.
	  - REAPROVEITA os móveis que o dono deixou na pilha de `Workspace["Moveis taverna"]` (MOVE, não clona —
	    pedido dele), por NOME + posição aproximada da pilha. Nada é apagado.
	Rodar de novo recoloca tudo nas mesmas posições. O dono salva o place depois (não passa pelo Rojo).
]]

local Workspace = game:GetService("Workspace")

local kit = Workspace:FindFirstChild("Moveis taverna")
local taberna = Workspace:FindFirstChild("Taberna")
assert(kit and taberna, "precisa de Workspace['Moveis taverna'] e Workspace.Taberna")

local FLOOR = -0.3 -- topo do piso do hall (o chão da caverna varia de -0,9 a -0,4)
local X0, X1 = 274.2, 325.4 -- paredes oeste (face interna de Part5/6) e boca do salão
local Z0, Z1 = 77.9, 109.6 -- faces internas das paredes sul (cav.Part) e norte (cav.Part3)
local DOOR_X, DOOR_Z0, DOOR_Z1 = 272.1, 87.8, 98.2 -- vão da entrada (Part5/Part6)

local old = taberna:FindFirstChild("Hall")
if old then
	-- os móveis do dono que já foram movidos para o hall voltam para a pilha ANTES de apagar (senão somem
	-- junto — aconteceu em 25/09 e foi restaurado do backup). Eles guardam PilhaX/PilhaZ para o `find` achar.
	local moveisOld = old:FindFirstChild("Moveis")
	if moveisOld then
		for _, c in moveisOld:GetChildren() do
			c.Parent = kit
		end
	end
	old:Destroy()
end
local hall = Instance.new("Model")
hall.Name = "Hall"
hall.Parent = taberna

local WOOD_DARK = Color3.fromRGB(78, 52, 32)
local WOOD = Color3.fromRGB(120, 84, 50)
local IRON = Color3.fromRGB(55, 52, 50)
local RUG = Color3.fromRGB(122, 32, 34)

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
	p.Parent = parent or hall
	return p
end

-- ---------------------------------------------------------------------------
-- Estrutura: piso, tapete, soleira
-- ---------------------------------------------------------------------------
local estrutura = Instance.new("Folder")
estrutura.Name = "Estrutura"
estrutura.Parent = hall
part("Piso", Vector3.new(X1 - X0 + 0.6, 0.8, Z1 - Z0 + 0.6), CFrame.new((X0 + X1) / 2, FLOOR - 0.4, (Z0 + Z1) / 2), WOOD, Enum.Material.WoodPlanks, estrutura)
-- tapete corredor da porta ao salão
part("Tapete", Vector3.new(X1 - X0 - 3, 0.08, 6), CFrame.new((X0 + X1) / 2, FLOOR + 0.04, 93), RUG, Enum.Material.Fabric, estrutura, { CanCollide = false })
part("TapeteBorda", Vector3.new(X1 - X0 - 3, 0.06, 6.8), CFrame.new((X0 + X1) / 2, FLOOR + 0.03, 93), Color3.fromRGB(196, 160, 70), Enum.Material.Fabric, estrutura, { CanCollide = false })
-- rodapé de pedra nas paredes sul/norte e oeste
part("RodapeSul", Vector3.new(X1 - X0, 1.2, 0.6), CFrame.new((X0 + X1) / 2, FLOOR + 0.5, Z0 + 0.3), Color3.fromRGB(70, 66, 64), Enum.Material.Slate, estrutura)
part("RodapeNorte", Vector3.new(X1 - X0, 1.2, 0.6), CFrame.new((X0 + X1) / 2, FLOOR + 0.5, Z1 - 0.3), Color3.fromRGB(70, 66, 64), Enum.Material.Slate, estrutura)
-- vigas do teto (3, atravessando o hall) — o teto da caverna é liso demais
for _, x in { 284, 299, 314 } do
	part("Viga", Vector3.new(1.4, 1.4, Z1 - Z0), CFrame.new(x, 17.4, (Z0 + Z1) / 2), WOOD_DARK, Enum.Material.Wood, estrutura)
end

-- ---------------------------------------------------------------------------
-- Entrada: batentes, viga, placa, PORTAS DE SALOON
-- ---------------------------------------------------------------------------
local entrada = Instance.new("Model")
entrada.Name = "Entrada"
entrada.Parent = hall
local jambH = 13.8 -- do piso até a verga (Part7 começa em y 13,5)
for _, z in { DOOR_Z0 - 0.5, DOOR_Z1 + 0.5 } do
	part("Batente", Vector3.new(1.2, jambH, 1.2), CFrame.new(DOOR_X, FLOOR + jambH / 2, z), WOOD_DARK, Enum.Material.Wood, entrada)
end
part("VigaPorta", Vector3.new(1.4, 1.2, DOOR_Z1 - DOOR_Z0 + 2.4), CFrame.new(DOOR_X, 13.0, (DOOR_Z0 + DOOR_Z1) / 2), WOOD_DARK, Enum.Material.Wood, entrada)
-- placa "TABERNA" pendurada acima das portas, dos dois lados
local placa = part("Placa", Vector3.new(0.5, 2.6, 9), CFrame.new(DOOR_X, 10.2, (DOOR_Z0 + DOOR_Z1) / 2), WOOD, Enum.Material.Wood, entrada)
for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(900, 260)
	gui.LightInfluence = 0.6
	gui.Parent = placa
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Antique
	label.Text = "TABERNA"
	label.TextColor3 = Color3.fromRGB(240, 210, 120)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Parent = gui
end
for _, z in { (DOOR_Z0 + DOOR_Z1) / 2 - 3.6, (DOOR_Z0 + DOOR_Z1) / 2 + 3.6 } do
	part("Corrente", Vector3.new(0.2, 1.4, 0.2), CFrame.new(DOOR_X, 12.2, z), IRON, Enum.Material.Metal, entrada)
end
-- lanternas de ferro nos batentes (fora e dentro)
local function lantern(name, cf)
	local base = part(name, Vector3.new(0.8, 1.2, 0.8), cf, IRON, Enum.Material.Metal, entrada)
	local glass = part(name .. "Vidro", Vector3.new(0.5, 0.7, 0.5), cf, Color3.fromRGB(255, 190, 90), Enum.Material.Neon, entrada, { CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 90)
	light.Brightness = 1.4
	light.Range = 14
	light.Shadows = true
	light.Parent = glass
	return base
end
lantern("LanternaSul", CFrame.new(DOOR_X - 1.4, 7.5, DOOR_Z0 - 0.5))
lantern("LanternaNorte", CFrame.new(DOOR_X - 1.4, 7.5, DOOR_Z1 + 0.5))

-- Portas de saloon: duas asas (vão de 10,4 → cada asa 5,0 + folga), do peito ao joelho, dobradiça no batente.
-- Cada asa é um Model com PrimaryPart = "Dobradica" (invisível, no eixo) para o SaloonDoorService girar com PivotTo.
local porta = Instance.new("Model")
porta.Name = "PortaSaloon"
porta:SetAttribute("Hinge", "z") -- eixo das dobradiças corre em z (as asas giram em Y)
porta.Parent = entrada
local WING_W, WING_H, WING_BOTTOM = 5.0, 5.4, FLOOR + 1.9
local function wing(name, hingeZ, dir) -- dir = +1 asa cresce para +z, −1 para −z
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = porta
	local hinge = part("Dobradica", Vector3.new(0.4, WING_H, 0.4), CFrame.new(DOOR_X, WING_BOTTOM + WING_H / 2, hingeZ), IRON, Enum.Material.Metal, m, { CanCollide = false })
	m.PrimaryPart = hinge
	local centerZ = hingeZ + dir * (WING_W / 2 + 0.1)
	-- quadro
	part("QuadroCima", Vector3.new(0.4, 0.5, WING_W), CFrame.new(DOOR_X, WING_BOTTOM + WING_H - 0.25, centerZ), WOOD_DARK, Enum.Material.Wood, m)
	part("QuadroBaixo", Vector3.new(0.4, 0.5, WING_W), CFrame.new(DOOR_X, WING_BOTTOM + 0.25, centerZ), WOOD_DARK, Enum.Material.Wood, m)
	part("QuadroPonta", Vector3.new(0.4, WING_H, 0.5), CFrame.new(DOOR_X, WING_BOTTOM + WING_H / 2, hingeZ + dir * (WING_W - 0.15)), WOOD_DARK, Enum.Material.Wood, m)
	-- ripas inclinadas (veneziana)
	local n = 7
	for i = 1, n do
		local y = WING_BOTTOM + 0.5 + (WING_H - 1) * (i - 0.5) / n
		part("Ripa", Vector3.new(0.15, 0.9, WING_W - 0.7), CFrame.new(DOOR_X, y, centerZ) * CFrame.Angles(0, 0, math.rad(-35)), WOOD, Enum.Material.Wood, m, { CanCollide = false })
	end
	-- ferragem
	part("Ferragem", Vector3.new(0.5, 0.6, 1.6), CFrame.new(DOOR_X, WING_BOTTOM + WING_H / 2, hingeZ + dir * 0.9), IRON, Enum.Material.Metal, m, { CanCollide = false })
	m:SetAttribute("Dir", dir)
	return m
end
wing("AsaSul", DOOR_Z0 + 0.2, 1)
wing("AsaNorte", DOOR_Z1 - 0.2, -1)
-- gatilho: quem entra nele abre as portas (o serviço decide o lado pelo x do jogador)
part("Gatilho", Vector3.new(9, 8, DOOR_Z1 - DOOR_Z0), CFrame.new(DOOR_X, FLOOR + 4, (DOOR_Z0 + DOOR_Z1) / 2), Color3.new(1, 1, 1), Enum.Material.Plastic, porta, { Transparency = 1, CanCollide = false, CanQuery = false })

-- ---------------------------------------------------------------------------
-- Luz: tochas clonadas da Taberna (Suporte/Tocha/Chama) + luminárias da pilha
-- ---------------------------------------------------------------------------
local luz = Instance.new("Folder")
luz.Name = "Luz"
luz.Parent = hall
local function torchAt(x, z, yaw)
	-- copia a tocha da parede oeste do salão (x 325,9 z 62) e leva para (x, z) com giro `yaw`
	local src = {}
	for _, c in taberna.Luz:GetChildren() do
		local p = c:IsA("BasePart") and c or c:FindFirstChildWhichIsA("BasePart", true)
		if p and math.abs(p.Position.Z - 62) < 0.5 and p.Position.X > 325 then
			table.insert(src, c)
		end
	end
	if #src == 0 then
		return
	end
	local origin = CFrame.new(325.9, 0, 62)
	local target = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
	for _, c in src do
		local clone = c:Clone()
		clone.Parent = luz
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = target * origin:ToObjectSpace(d.CFrame)
			end
		end
		if clone:IsA("BasePart") then
			clone.CFrame = target * origin:ToObjectSpace(clone.CFrame)
		end
	end
end
-- a tocha original está na parede que olha para -x; nas paredes sul (olha +z) gira 90, norte (olha -z) gira -90, oeste 180
torchAt(287.5, Z0 + 0.4, 90) -- entre a mesa de entrada e a cristaleira
torchAt(301.5, Z0 + 0.4, 90) -- entre a cristaleira e os painéis
torchAt(283, Z1 - 0.4, -90)
torchAt(306, Z1 - 0.4, -90)
torchAt(X0 + 0.4, 82, 180)
torchAt(X0 + 0.4, 105, 180)
-- luz ambiente quente no centro (as luminárias da pilha são fracas)
for _, x in { 288, 312 } do
	local anchor = part("LuzAmbiente", Vector3.new(0.4, 0.4, 0.4), CFrame.new(x, 12, 93), Color3.new(1, 1, 1), Enum.Material.Plastic, luz, { Transparency = 1, CanCollide = false })
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 200, 130)
	l.Brightness = 0.9
	l.Range = 26
	l.Shadows = false
	l.Parent = anchor
end

-- ---------------------------------------------------------------------------
-- Móveis da pilha do dono: acha por nome (e posição aproximada quando o nome repete) e MOVE.
-- Posições = centro da caixa (bbox) e giro em Y; y = FLOOR + altura/2 salvo `y` explícito.
-- ---------------------------------------------------------------------------
local moveis = Instance.new("Folder")
moveis.Name = "Moveis"
moveis.Parent = hall

local function bbox(inst)
	if inst:IsA("Model") then
		return inst:GetBoundingBox()
	end
	return inst.CFrame, inst.Size
end

--- Acha um filho do kit por nome perto de (x, z) (raio 4 studs), o mais próximo.
local function find(name, x, z)
	local best, bestD
	for _, c in kit:GetChildren() do
		if c.Name == name then
			local ok, cf = pcall(bbox, c)
			if ok then
				local d = (Vector2.new(cf.Position.X, cf.Position.Z) - Vector2.new(x, z)).Magnitude
				if (not bestD or d < bestD) and d < 6 then
					best, bestD = c, d
				end
			end
		end
	end
	-- o que já foi colocado numa rodada anterior está na pilha de novo, longe da posição original: acha pelo atributo
	if not best then
		for _, c in kit:GetChildren() do
			if c.Name == name and c:GetAttribute("PilhaX") == x and c:GetAttribute("PilhaZ") == z then
				best = c
			end
		end
	end
	return best
end

local placed, missing = 0, {}
--- Move `inst` para que o centro da bbox fique em (x, y, z) girado `yaw` (graus). y nil = apoiado no piso.
local function place(name, px, pz, x, z, yaw, y, onTop)
	local inst = find(name, px, pz)
	if not inst then
		table.insert(missing, name .. "@" .. px .. "," .. pz)
		return nil
	end
	local cf, size = bbox(inst)
	local pivot = inst:GetPivot()
	local offset = cf:ToObjectSpace(pivot)
	local rotated = CFrame.Angles(0, math.rad(yaw), 0)
	-- altura da caixa depois do giro em Y não muda
	local cy = if y then y else FLOOR + size.Y / 2
	if onTop then
		cy = onTop + size.Y / 2
	end
	local target = CFrame.new(x, cy, z) * rotated
	inst:PivotTo(target * offset)
	inst:SetAttribute("PilhaX", px)
	inst:SetAttribute("PilhaZ", pz)
	inst.Parent = moveis
	placed += 1
	return inst, size
end

-- PAREDE SUL (z ≈ 78): cristaleira, mesa de entrada com abajur, painéis, balcão de recepção
place("DiningRoom_Hutch", 301.3, 92.9, 296, Z0 + 1.6, 0) -- cristaleira A (MeshPart)
place("Meshes/Furniture_Foyer_Entry_Table", 328.8, 101.7, 281.5, Z0 + 3.0, 0)
place("Table_Lamp_SG_On", 318.1, 105.3, 281.5, Z0 + 3.0, 0, nil, FLOOR + 3.1)
place("Model", 300.8, 96.5, 305.5, Z0 + 0.35, 180, 5.2) -- painel alto A (5,6 × 7,1; a frente é −z)
place("Model", 300.8, 96.4, 311.5, Z0 + 0.35, 180, 5.2) -- painel alto B (o segundo, a y 7,8 na pilha)
-- balcão de recepção: dois gaveteiros + pia-armário, tampo = a peça longa "Model" (8,4 × 1,9 × 1,5)
place("Kitchen_Cabinet_Drawer", 322.5, 92.7, 316.0, Z0 + 1.7, 0)
place("Furniture_Kitchen_LowerCabinetDoors_Sink", 318.7, 92.8, 319.0, Z0 + 1.7, 0)
place("Kitchen_Cabinet_Drawer", 325.7, 92.8, 322.0, Z0 + 1.7, 0)
place("Model", 321.0, 102.1, 319.0, Z0 + 0.9, 0, 7.6) -- prateleira/viga acima do balcão
place("Furniture_Bar_UpperCabinetSingle", 324.4, 89.9, 314.3, Z0 + 0.95, 0, 6.6)
place("Furniture_Kitchen_UpperSmallEndCabinet_Mirrored", 320.0, 89.7, 324.0, Z0 + 1.0, 0, 6.2)
-- em cima do balcão (topo ≈ FLOOR + 3,1)
local TOP = FLOOR + 3.1
place("Bankers_Lamp_on", 315.7, 105.1, 316.0, Z0 + 1.6, 0, nil, TOP)
place("Radio", 310.6, 104.6, 318.6, Z0 + 1.7, 90, nil, TOP)
place("Bottle_A_Large_GRP", 319.8, 106.8, 320.3, Z0 + 1.3, 0, nil, TOP)
place("Bottle_E_GRP", 321.9, 106.9, 320.9, Z0 + 2.1, 0, nil, TOP)
place("Glass_Empty", 322.2, 109.6, 321.4, Z0 + 1.4, 0, nil, TOP)
place("Stemware_Glass_Empty", 321.3, 109.5, 321.8, Z0 + 2.0, 0, nil, TOP)
place("Prop_RavenTaxidermy_R", 313.4, 104.5, 322.6, Z0 + 1.6, 0, nil, TOP)
place("Candle_Tall_B", 325.4, 106.8, 317.4, Z0 + 2.4, 0, nil, TOP)
place("Candle_Medium_A", 323.7, 106.7, 317.0, Z0 + 1.1, 0, nil, TOP)
-- poções na prateleira acima do balcão (topo ≈ 8,55)
local SHELF = 7.6 + 0.95
place("potion1", 322.3, 108.1, 316.5, Z0 + 0.9, 0, nil, SHELF)
place("potion2", 322.3, 108.8, 317.4, Z0 + 0.9, 0, nil, SHELF)
place("potion3", 321.4, 108.8, 318.2, Z0 + 0.9, 0, nil, SHELF)
place("potion4", 321.3, 108.0, 319.1, Z0 + 0.9, 0, nil, SHELF)
-- gavetas soltas viram caixotes ao lado do balcão, com louça em cima
place("Drawer_02", 309.6, 101.9, 312.2, Z0 + 1.5, 0)
place("Drawer_03", 312.1, 102.0, 312.2, Z0 + 1.5, 0, nil, FLOOR + 0.5)
place("Plate_Stack", 315.0, 107.0, 312.0, Z0 + 1.4, 0, nil, FLOOR + 1.2)
place("Plate_Stack", 313.2, 107.1, 312.6, Z0 + 1.9, 15, nil, FLOOR + 1.2)
place("Bowl_Stack", 316.7, 107.0, 311.4, Z0 + 2.1, 0, nil, FLOOR + 1.2)
place("Bowl_Stack", 318.2, 107.0, 312.0, Z0 + 2.1, 0, nil, FLOOR + 2.3)
place("DinnerwareSet_1", 324.3, 108.5, 313.9, Z0 + 1.3, 0, nil, FLOOR + 1.2)

-- PAREDE NORTE (z ≈ 109,6): piano com candelabro, aparador, cristaleira B, estante, lambri
place("Piano", 305.0, 102.7, 299.0, Z1 - 2.6, 0)
place("Candelabra", 321.1, 105.2, 297.0, Z1 - 2.6, 0, nil, FLOOR + 4.1)
place("Ritual_Candle_Group_B", 323.8, 105.4, 301.5, Z1 - 2.6, 0, nil, FLOOR + 4.1)
place("Ritual_Candle_Group_D_Off", 325.9, 105.3, 302.6, Z1 - 2.2, 0, nil, FLOOR + 4.1)
place("Model", 313.7, 89.7, 306.8, Z1 - 1.3, 180) -- aparador (5,8 × 3,5 × 2,2)
place("Model", 311.4, 92.9, 315.0, Z1 - 1.6, 180) -- cristaleira B (Model com o mesh)
place("Shelf", 330.1, 89.9, 291.5, Z1 - 0.6, 0)
place("Wall_Panel 10x4pt5", 319.8, 96.7, 281.5, Z1 - 0.5, 90, FLOOR + 1.85)
place("Wall_Panel_SM", 313.0, 96.8, 287.7, Z1 - 0.5, 90, FLOOR + 1.85)
place("Joint_Cap", 314.5, 102.1, 293.0, Z1 - 0.6, 0)
-- PAREDE OESTE (x ≈ 274,2, ao lado da porta): quadros/painéis pequenos e a fachada
place("Model", 306.8, 96.5, X0 + 0.3, 83.5, 90, 5.0) -- painel pequeno A
place("Model", 306.7, 96.5, X0 + 0.3, 102.5, 90, 5.0) -- painel pequeno B
place("Island-Facade", 310.4, 96.7, X0 + 0.4, 80.5, 90)
-- coluna alta junto da boca do salão (lado norte) e viga da entrada por dentro
place("Newel_Post_Tall", 327.3, 96.7, 322.5, 105.0, 0)
place("Ceiling_Beam_10M", 317.8, 99.1, X0 + 1.4, 93, 90, 12.6)
-- luminárias penduradas no teto
place("CeilingLight", 305.0, 100.5, 288, 93, 0, 14.5)
place("Pantry_Light", 300.4, 103.4, 312, 93, 0, 15.5)
place("CanLight", 300.5, 100.5, 300, 93, 0, 17.6)
-- pia pequena (mesh branco sem textura): canto noroeste, atrás da porta, fora do caminho
place("SmallerSink-LowerCabinet", 328.9, 93.1, X0 + 1.5, Z1 - 1.4, 0)

print(("[montar_hall] %d móveis colocados; faltaram: %s"):format(placed, if #missing > 0 then table.concat(missing, ", ") else "nenhum"))
print("[montar_hall] Hall montado em Workspace.Taberna.Hall — SALVAR o place")
