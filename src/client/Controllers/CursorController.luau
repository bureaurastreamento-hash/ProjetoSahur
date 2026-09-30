--!strict
--[[
	CursorController (cliente)
	Troca o ponteiro nativo por dois cursores desenhados com Frames (sem imagem para subir no grupo):
	  - mouse SOLTO: triângulo branco cheio, ponta para cima (a ponta é onde o clique acontece);
	  - SHIFT LOCK (mouse preso no centro, MouseBehavior.LockCenter): seta em "V" branca, grossa e vazada
	    (triângulo de cabeça para baixo sem a base), com a ponta no centro da tela.
	Decide pelo estado real do mouse (não pelo MovementController), então cutscene/menus que soltam o mouse já
	voltam para o triângulo. Branco puro, sem contorno, cantos/pontas arredondados (cartoon; pedido do dono 30/09). Some no toque, no controle e no menu
	do Roblox (Esc), devolvendo o ponteiro nativo.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CursorController = {}

local BRANCO = Color3.new(1, 1, 1)

-- triângulo (mouse solto): cantos arredondados (raio TRI_RAIO), estilo cartoon
local TRI_ALTURA, TRI_BASE, TRI_RAIO = 18, 16, 3
-- seta em V (shift lock): traços com pontas redondas
local V_LARGURA, V_ALTURA, V_ESPESSURA = 22, 12, 4

local gui: ScreenGui
local triangulo: Frame
local seta: Frame

local function novoFrame(parent: Instance, nome: string): Frame
	local f = Instance.new("Frame")
	f.Name = nome
	f.BorderSizePixel = 0
	f.BackgroundColor3 = BRANCO
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Parent = parent
	return f
end

local function redondo(f: Frame)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
end

local function distSegmento(p: Vector2, a: Vector2, b: Vector2): number
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function cruz(a: Vector2, b: Vector2): number
	return a.X * b.Y - a.Y * b.X
end

-- Triângulo de cantos redondos = triângulo menor "inflado" pelo raio; desenhado em linhas de 1 px (a forma é
-- convexa, então cada linha é um trecho só). (0,0) do container = ponta de cima (onde o clique acontece).
local function desenharTriangulo(parent: Instance)
	local r = TRI_RAIO
	local meia = TRI_BASE / 2 - r * 1.1
	local a, b, c = Vector2.new(0, r), Vector2.new(-meia, TRI_ALTURA - r), Vector2.new(meia, TRI_ALTURA - r)
	local function dentro(p: Vector2): boolean
		local s1, s2, s3 = cruz(b - a, p - a), cruz(c - b, p - b), cruz(a - c, p - c)
		if (s1 >= 0 and s2 >= 0 and s3 >= 0) or (s1 <= 0 and s2 <= 0 and s3 <= 0) then
			return true
		end
		return math.min(distSegmento(p, a, b), distSegmento(p, b, c), distSegmento(p, c, a)) <= r
	end
	for y = 0, TRI_ALTURA - 1 do
		local largura = 0
		for x = 0, TRI_BASE, 0.5 do
			if dentro(Vector2.new(x, y + 0.5)) then
				largura = x
			end
		end
		if largura > 0 then
			local l = novoFrame(parent, "L" .. y)
			l.AnchorPoint = Vector2.new(0.5, 0)
			l.Size = UDim2.fromOffset(math.max(1, math.floor(largura * 2 + 0.5)), 1)
			l.Position = UDim2.fromOffset(0, y)
		end
	end
end

-- Traço grosso de a até b com pontas redondas (Frame girado + UICorner em pílula).
local function traco(parent: Instance, a: Vector2, b: Vector2)
	local d = b - a
	local f = novoFrame(parent, "Traco")
	f.Size = UDim2.fromOffset(d.Magnitude + V_ESPESSURA, V_ESPESSURA)
	local meio = (a + b) / 2
	f.Position = UDim2.fromOffset(meio.X, meio.Y)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
	redondo(f)
end

-- V: dois traços das pontas de cima até a ponta de baixo; (0,0) do container = ponta de baixo (centro da tela).
local function desenharSeta(parent: Instance)
	local ponta = Vector2.new(0, -V_ESPESSURA / 2)
	traco(parent, Vector2.new(-V_LARGURA / 2 + V_ESPESSURA / 2, -V_ALTURA), ponta)
	traco(parent, Vector2.new(V_LARGURA / 2 - V_ESPESSURA / 2, -V_ALTURA), ponta)
end

local function container(nome: string): Frame
	local f = Instance.new("Frame")
	f.Name = nome
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(0, 0)
	f.Visible = false
	f.Parent = gui
	return f
end

local function usarProprio(): boolean
	if GuiService.MenuIsOpen or not UserInputService.MouseEnabled then
		return false
	end
	local ultimo = UserInputService:GetLastInputType()
	return ultimo ~= Enum.UserInputType.Touch and ultimo.Name:sub(1, 7) ~= "Gamepad"
end

function CursorController.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "CursorGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	triangulo = container("Triangulo")
	desenharTriangulo(triangulo)

	seta = container("Seta")
	desenharSeta(seta)

	RunService:BindToRenderStep("SahurCursor", Enum.RenderPriority.Last.Value, function()
		local proprio = usarProprio()
		UserInputService.MouseIconEnabled = not proprio
		if not proprio then
			triangulo.Visible = false
			seta.Visible = false
			return
		end
		local preso = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		local pos = if preso then gui.AbsoluteSize / 2 else UserInputService:GetMouseLocation()
		triangulo.Visible = not preso
		seta.Visible = preso
		local alvo = if preso then seta else triangulo
		alvo.Position = UDim2.fromOffset(math.floor(pos.X + 0.5), math.floor(pos.Y + 0.5))
	end)
end

return CursorController
