--!strict
--[[
	CursorController (cliente)
	Troca o ponteiro nativo por dois cursores desenhados com Frames (sem imagem para subir no grupo):
	  - mouse SOLTO: triângulo branco cheio, ponta para cima (a ponta é onde o clique acontece);
	  - SHIFT LOCK (mouse preso no centro, MouseBehavior.LockCenter): seta em "V" branca, grossa e vazada
	    (triângulo de cabeça para baixo sem a base), com a ponta no centro da tela.
	Decide pelo estado real do mouse (não pelo MovementController), então cutscene/menus que soltam o mouse já
	voltam para o triângulo. Contorno escuro leve para aparecer em céu/areia. Some no toque, no controle e no menu
	do Roblox (Esc), devolvendo o ponteiro nativo.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CursorController = {}

local BRANCO = Color3.new(1, 1, 1)
local CONTORNO = Color3.new(0, 0, 0)
local CONTORNO_TRANSP = 0.55

-- triângulo (mouse solto)
local TRI_ALTURA, TRI_BASE = 16, 14
-- seta em V (shift lock)
local V_LARGURA, V_ALTURA, V_ESPESSURA = 20, 12, 3

local gui: ScreenGui
local triangulo: Frame
local seta: Frame

local function novoFrame(parent: Instance, nome: string, cor: Color3, transp: number): Frame
	local f = Instance.new("Frame")
	f.Name = nome
	f.BorderSizePixel = 0
	f.BackgroundColor3 = cor
	f.BackgroundTransparency = transp
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Parent = parent
	return f
end

-- Triângulo cheio de linhas de 1 px; (0,0) do container = ponta de cima.
local function desenharTriangulo(parent: Instance, altura: number, base: number, cor: Color3, transp: number, dy: number)
	for i = 0, altura - 1 do
		local w = math.max(1, math.floor(base * (i + 1) / altura + 0.5))
		local linha = novoFrame(parent, "L" .. i, cor, transp)
		linha.AnchorPoint = Vector2.new(0.5, 0)
		linha.Size = UDim2.fromOffset(w, 1)
		linha.Position = UDim2.fromOffset(0, i + dy)
	end
end

-- Segmento grosso de a até b (Frame girado em volta do centro).
local function linha(parent: Instance, a: Vector2, b: Vector2, espessura: number, cor: Color3, transp: number)
	local d = b - a
	local f = novoFrame(parent, "Traco", cor, transp)
	f.Size = UDim2.fromOffset(d.Magnitude + espessura * 0.5, espessura)
	local meio = (a + b) / 2
	f.Position = UDim2.fromOffset(meio.X, meio.Y)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
end

-- V: dois traços das pontas de cima até a ponta de baixo; (0,0) do container = ponta de baixo (centro da tela).
local function desenharSeta(parent: Instance, espessura: number, cor: Color3, transp: number)
	local ponta = Vector2.new(0, -espessura * 0.6)
	linha(parent, Vector2.new(-V_LARGURA / 2, -V_ALTURA - espessura * 0.6), ponta, espessura, cor, transp)
	linha(parent, Vector2.new(V_LARGURA / 2, -V_ALTURA - espessura * 0.6), ponta, espessura, cor, transp)
	local junta = novoFrame(parent, "Junta", cor, transp)
	junta.Size = UDim2.fromOffset(espessura, espessura)
	junta.Rotation = 45
	junta.Position = UDim2.fromOffset(ponta.X, ponta.Y)
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
	desenharTriangulo(triangulo, TRI_ALTURA + 3, TRI_BASE + 4, CONTORNO, CONTORNO_TRANSP, -2) -- contorno atrás
	desenharTriangulo(triangulo, TRI_ALTURA, TRI_BASE, BRANCO, 0, 0)

	seta = container("Seta")
	desenharSeta(seta, V_ESPESSURA + 2, CONTORNO, CONTORNO_TRANSP)
	desenharSeta(seta, V_ESPESSURA, BRANCO, 0)

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
