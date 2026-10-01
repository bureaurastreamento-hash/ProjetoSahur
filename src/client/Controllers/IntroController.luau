--!strict
--[[
	IntroController (cliente) — PRÉ-LANÇAMENTO (LaunchConfig, dono 2026-10-01).
	Quem entra preso ao lobby (atributo PreLaunchLocked do LaunchService) vê:
	  1. TELA DE TÍTULO: "PLAY INTRO" (trailer ao vivo SÓ nesta tela — TrailerController.Dispatch, câmera pelas ilhas
	     + textos + logo, todo mundo escondido) ou "IR PARA O LOBBY"; aviso de transparência (imagens com IA, ideia
	     original) embaixo.
	  2. LOBBY: faixa no topo + botão "APOIAR / SOBRE" → painel com: testar Stand (só na sessão), doar Robux
	     (10/50/100/500/1000), maiores apoiadores, o que vem aí, ver a intro de novo.
	História/objetivos/caçadas/facção ficam escondidos enquanto preso ao lobby.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local LaunchConfig = require(Modules:WaitForChild("LaunchConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local TrailerController = require(script.Parent:WaitForChild("TrailerController"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))

local IntroController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(240, 196, 80)
local INK = Color3.fromRGB(245, 238, 225)
local SUB = Color3.fromRGB(200, 190, 175)
local PANEL = Color3.fromRGB(22, 20, 28)
local PANEL2 = Color3.fromRGB(36, 33, 44)
local FONT_TITLE = Enum.Font.Oswald
local FONT_BODY = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

-- telas do jogo escondidas no lobby (história, escolhas, objetivos, caçadas, facção, quests)
local STORY_GUIS = { FXStoryGui = true, FXChoiceGui = true, GoalsGui = true, HuntGui = true, FactionGui = true, QuestGui = true }

local requestLaunch: RemoteEvent
local gui: ScreenGui? = nil
local titleFrame: Frame? = nil
local lobbyBar: Frame? = nil
local panel: Frame? = nil
local boardList: Frame? = nil
local donatedLabel: TextLabel? = nil
local orbitConn: RBXScriptConnection? = nil
local developerTitlePending = true
local developerShortcut: ScreenGui? = nil
local refreshLock: () -> ()
local playingIntro = false
local boardData: { { name: string, amount: number } } = {}

-- ---------------------------------------------------------------------------
-- Utilidades de UI
-- ---------------------------------------------------------------------------

local function corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = parent
end

local function text(parent: Instance, t: string, font: Enum.Font, size: number, color: Color3, frame: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = t
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	for k, v in (frame or {}) :: any do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function button(parent: Instance, t: string, color: Color3, size: UDim2, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.Size = size
	b.Text = t
	b.Font = FONT_BOLD
	b.TextSize = 16
	b.TextColor3 = if color == GOLD then Color3.fromRGB(30, 22, 10) else INK
	b.Parent = parent
	corner(b)
	b.Activated:Connect(onClick)
	return b
end

local function list(parent: Instance, padding: number, horizontal: boolean?)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Parent = parent
end

-- ---------------------------------------------------------------------------
-- Câmera de fundo da tela de título (órbita lenta no Coliseu)
-- ---------------------------------------------------------------------------

local function startOrbit()
	local camera = Workspace.CurrentCamera
	if not camera or orbitConn then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	local c = LaunchConfig.LobbyCenter + Vector3.new(0, 10, 0)
	orbitConn = RunService.RenderStepped:Connect(function()
		-- vai-e-vem lento POR FORA, no lado norte: Coliseu inteiro com a montanha do santuário ao fundo
		-- (por dentro a câmera passava no meio das colunas; pelo sul a montanha tapa a vista)
		local a = math.rad(80 + 45 * math.sin((os.clock() - t0) * 0.06))
		camera.CFrame = CFrame.lookAt(c + Vector3.new(math.cos(a) * 230, 60, math.sin(a) * 230), c + Vector3.new(0, 5, 0))
	end)
end

local function stopOrbit()
	if orbitConn then
		orbitConn:Disconnect()
		orbitConn = nil
	end
	local camera = Workspace.CurrentCamera
	if camera and not TrailerController.IsActive() then
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- ---------------------------------------------------------------------------
-- Intro ao vivo (só nesta tela)
-- ---------------------------------------------------------------------------

local RAY = RaycastParams.new()
RAY.FilterType = Enum.RaycastFilterType.Exclude

local function ground(p: Vector3): Vector3
	local exclude: { Instance } = {}
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(exclude, pl.Character)
		end
	end
	RAY.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(p + Vector3.new(0, 150, 0), Vector3.new(0, -400, 0), RAY)
	return if hit then hit.Position else p
end

local showLobby: () -> ()

-- Hotbar padrão do Roblox (Tools) escondida no lobby: ficava por cima dos slots de habilidade e no meio do título.
local function applyBackpack()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
end

-- Telas do jogo (HUD, topbar...) escondidas só enquanto a tela de título está aberta; voltam ao ir para o lobby.
local hiddenForTitle: { ScreenGui } = {}
local titleAddedConn: RBXScriptConnection? = nil
local function hideForTitle(g: Instance)
	if g:IsA("ScreenGui") and g.Name ~= "LaunchGui" and g.Enabled then
		g.Enabled = false
		table.insert(hiddenForTitle, g)
	end
end
local function hideOthersForTitle()
	player:SetAttribute("LaunchTitleVisible", true)
	for _, g in playerGui:GetChildren() do
		hideForTitle(g)
	end
	if not titleAddedConn then
		titleAddedConn = playerGui.ChildAdded:Connect(hideForTitle) -- HUD criado depois do título
	end
end
local function restoreAfterTitle()
	player:SetAttribute("LaunchTitleVisible", false)
	if titleAddedConn then
		titleAddedConn:Disconnect()
		titleAddedConn = nil
	end
	for _, g in hiddenForTitle do
		if g.Parent and not (STORY_GUIS[g.Name] and player:GetAttribute("PreLaunchLocked") == true) then
			g.Enabled = true
		end
	end
	table.clear(hiddenForTitle)
end

local function playIntro()
	if playingIntro or TrailerController.IsActive() then
		return
	end
	playingIntro = true
	stopOrbit()
	if titleFrame then
		titleFrame.Visible = false
	end
	local D = TrailerController.Dispatch
	local V = Vector3.new
	local porto = ground(V(30, 0, 228))
	local vila = ground(V(-77, 0, 60))
	local col = ground(LaunchConfig.LobbyCenter)
	local temple = ground(V(1800, 41, -305))
	local fields = ground(V(-470, 8, -60))
	local boss = ground(V(900, 1.5, -581))
	local steps: { { any } } = {
		{ 0, "fade", { to = 1, seconds = 0 } },
		{ 0.3, "title", { style = "card", text = "EVERY ERA BROKE AT ONCE.", seconds = 2.9 } },
		{ 3.4, "shot", { kind = "path", t = 5, pts = { CFrame.new(porto + V(-70, 5, 240)), CFrame.new(porto + V(-40, 10, 160)), CFrame.new(porto + V(-12, 18, 95)) }, look = porto + V(0, 8, -10), fov0 = 50, fov1 = 46, wide = true, hand = 0.15 } },
		{ 3.4, "grade", { preset = "mist", seconds = 0 } },
		{ 3.6, "fade", { to = 0, seconds = 1.6 } },
		{ 4.6, "title", { style = "place", text = "PORT OF MIST", seconds = 2.8, sub = "CHAPTER 1  ·  THE FIRST FRACTURE" } },
		{ 8.4, "grade", { preset = "normal", seconds = 0.4 } },
		{ 8.4, "shot", { kind = "orbit", center = vila + V(0, 4, 0), radius = 46, height = 24, a0 = 200, a1 = 238, t = 3.1, fov0 = 55, fov1 = 52 } },
		{ 8.4, "title", { style = "place", text = "NEW VILLAGE", seconds = 2.4, sub = "PORT OF MIST" } },
		{ 11.4, "grade", { preset = "desert", seconds = 0.3 } },
		{ 11.4, "shot", { kind = "path", t = 3.1, pts = { CFrame.new(col + V(-215, 5, -60)), CFrame.new(col + V(-170, 45, -30)) }, look = col + V(0, 18, 0), fov0 = 50, fov1 = 48, wide = true, ease = "Quad" } },
		{ 11.4, "title", { style = "place", text = "DESERT OF THE SUN", seconds = 2.4, sub = "THE COLOSSEUM AWAITS" } },
		{ 14.4, "grade", { preset = "eclipse", seconds = 0.3 } },
		{ 14.4, "shot", { kind = "orbit", center = temple + V(0, -10, 0), radius = 120, height = 55, a0 = 120, a1 = 150, t = 3.1, fov0 = 50, lookUp = 10 } },
		{ 14.4, "title", { style = "place", text = "ECLIPSE ROUTE", seconds = 2.4, sub = "WHERE THE SUN BROKE" } },
		{ 17.4, "grade", { preset = "dusk", seconds = 0.3 } },
		{ 17.4, "shot", { kind = "orbit", center = fields + V(0, 6, 0), radius = 140, height = 45, a0 = 300, a1 = 328, t = 3.1, fov0 = 52, lookUp = 0 } },
		{ 17.4, "title", { style = "place", text = "MISTFIELDS", seconds = 2.4, sub = "NOTHING HERE IS FROM THIS ERA" } },
		{ 20.4, "grade", { preset = "eclipse", seconds = 0.4 } },
		{ 20.4, "shot", { kind = "orbit", center = col + V(0, 4, 0), radius = 70, height = 14, a0 = 160, a1 = 215, t = 4, fov0 = 48, fov1 = 44, lookUp = 6 } },
		{ 20.8, "title", { style = "card", text = "THE ARROW CHOOSES.", seconds = 2.6, sub = "STANDS  ·  7 RARITIES  ·  NO PITY" } },
		{ 24.4, "grade", { preset = "night", seconds = 0.4 } },
		{ 24.4, "shot", { kind = "path", t = 4, pts = { CFrame.new(boss + V(4, 6, -60)), CFrame.new(boss + V(2, 9, -40)) }, look = boss + V(0, 20, 0), fov0 = 50, fov1 = 44, hand = 0.3 } },
		{ 24.8, "title", { style = "card", text = "HUNT THE ECHOES.", seconds = 2.6, sub = "WORLD BOSSES  ·  LOOT BY DAMAGE RANK" } },
		{ 28.4, "fade", { to = 1, seconds = 0.3 } },
		{ 28.7, "logo", { seconds = 4.2 } },
	}
	D("begin", { format = "h", hideHumanoids = true })
	local t0 = os.clock()
	for _, step in steps do
		local wait = t0 + step[1] - os.clock()
		if wait > 0 then
			task.wait(wait)
		end
		if not playingIntro then
			break
		end
		D(step[2], step[3])
	end
	task.wait(math.max(0, t0 + 33.2 - os.clock()))
	D("end")
	playingIntro = false
	showLobby()
end

-- ---------------------------------------------------------------------------
-- Painel do lobby
-- ---------------------------------------------------------------------------

local function renderBoard()
	local holder = boardList
	if not holder then
		return
	end
	for _, c in holder:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	if #boardData == 0 then
		text(holder, "Seja o primeiro a apoiar!", FONT_BODY, 14, SUB, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1 })
		return
	end
	for i, row in boardData do
		text(holder, ("%d.  %s  —  %d R$"):format(i, row.name, row.amount), FONT_BODY, 14, if i <= 3 then GOLD else INK,
			{ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = i, TextXAlignment = Enum.TextXAlignment.Left })
	end
end

local function section(parent: Instance, title: string, order: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = PANEL2
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Size = UDim2.new(1, -8, 0, 0)
	f.LayoutOrder = order
	f.Parent = parent
	corner(f)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 10)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = f
	list(f, 6)
	text(f, title, FONT_TITLE, 20, GOLD, { Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, TextXAlignment = Enum.TextXAlignment.Left })
	return f
end

local function row(parent: Instance, order: number): Frame
	local r = Instance.new("Frame")
	r.BackgroundTransparency = 1
	r.Size = UDim2.new(1, 0, 0, 34)
	r.LayoutOrder = order
	r.Parent = parent
	list(r, 6, true)
	return r
end

local function buildPanel(sg: ScreenGui)
	local p = Instance.new("Frame")
	p.Name = "LaunchPanel"
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.new(0.5, 0, 0.5, 0)
	p.Size = UDim2.new(0, 520, 0.8, 0)
	p.BackgroundColor3 = PANEL
	p.Visible = false
	p.Parent = sg
	corner(p, 8)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 720)
	limit.Parent = p
	text(p, "APOIAR  /  SOBRE", FONT_TITLE, 26, INK, { Size = UDim2.new(1, -60, 0, 40), Position = UDim2.new(0, 14, 0, 6), TextXAlignment = Enum.TextXAlignment.Left })
	local close = button(p, "X", PANEL2, UDim2.new(0, 34, 0, 34), function()
		p.Visible = false
	end)
	close.Position = UDim2.new(1, -42, 0, 8)

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.Position = UDim2.new(0, 8, 0, 52)
	scroll.Size = UDim2.new(1, -16, 1, -60)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 5
	scroll.BorderSizePixel = 0
	scroll.Parent = p
	list(scroll, 8)

	-- Testar Stand
	local kit = section(scroll, "TESTAR STAND", 1)
	text(kit, "Só nesta sessão, com todas as teclas liberadas. Teste nos bonecos de treino do Coliseu.", FONT_BODY, 13, SUB,
		{ Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
	local kr = row(kit, 2)
	for _, id in LaunchConfig.TestKits do
		local def = CharacterDefs.Get(id)
		local name = if def then (def :: any).DisplayName or id else id
		button(kr, name, PANEL, UDim2.new(0, 88, 1, 0), function()
			requestLaunch:FireServer("kit", id)
		end).TextSize = 14
	end

	-- Doar
	local don = section(scroll, "APOIAR O DESENVOLVIMENTO", 2)
	text(don, "Cada Robux vai para o desenvolvimento do jogo. Quem apoia ganha a tag de Apoiador (só visual, sem vantagem).",
		FONT_BODY, 13, SUB, { Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
	local dr = row(don, 2)
	for _, d in LaunchConfig.Donations do
		button(dr, ("%d R$"):format(d.amount), GOLD, UDim2.new(0, 86, 1, 0), function()
			requestLaunch:FireServer("donate", d.key)
		end)
	end
	donatedLabel = text(don, "", FONT_BODY, 13, GOLD, { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left })

	-- Placar
	local top = section(scroll, "MAIORES APOIADORES", 3)
	local bl = Instance.new("Frame")
	bl.BackgroundTransparency = 1
	bl.AutomaticSize = Enum.AutomaticSize.Y
	bl.Size = UDim2.new(1, 0, 0, 0)
	bl.LayoutOrder = 1
	bl.Parent = top
	list(bl, 2)
	boardList = bl
	renderBoard()

	-- O que vem aí
	local feat = section(scroll, "O QUE VEM AÍ", 4)
	for i, f in LaunchConfig.Features do
		text(feat, "•  " .. f, FONT_BODY, 14, INK, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = i, TextXAlignment = Enum.TextXAlignment.Left })
	end

	-- Transparência + intro
	local about = section(scroll, "SOBRE O PROJETO", 5)
	for i, n in LaunchConfig.Notice do
		text(about, n, FONT_BODY, 13, SUB, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = i, TextXAlignment = Enum.TextXAlignment.Left })
	end
	local ir = row(about, 9)
	button(ir, "▶  VER A INTRO DE NOVO", PANEL, UDim2.new(0, 220, 1, 0), function()
		p.Visible = false
		task.spawn(playIntro)
	end)
	panel = p
end

local function buildGui(): ScreenGui
	local sg = Instance.new("ScreenGui")
	sg.Name = "LaunchGui"
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 40
	sg.Parent = playerGui

	-- Tela de título
	local tf = Instance.new("Frame")
	tf.Name = "Title"
	tf.Size = UDim2.new(1, 0, 1, 0)
	tf.BackgroundColor3 = Color3.new(0, 0, 0)
	tf.BackgroundTransparency = 0.35
	tf.Parent = sg
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 0) })
	grad.Parent = tf
	text(tf, LaunchConfig.Title, FONT_TITLE, 64, INK, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.36, 0), Size = UDim2.new(0.9, 0, 0, 80), TextStrokeTransparency = 0.6 })
	text(tf, LaunchConfig.Tagline, FONT_BOLD, 16, GOLD, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.36, 52), Size = UDim2.new(0.9, 0, 0, 24) })
	local play = button(tf, "▶   PLAY INTRO", GOLD, UDim2.new(0, 280, 0, 54), function()
		task.spawn(playIntro)
	end)
	play.AnchorPoint = Vector2.new(0.5, 0.5)
	play.Position = UDim2.new(0.5, 0, 0.56, 0)
	play.TextSize = 22
	local skip = button(tf, "IR PARA O LOBBY", PANEL2, UDim2.new(0, 280, 0, 42), function()
		showLobby()
	end)
	skip.AnchorPoint = Vector2.new(0.5, 0.5)
	skip.Position = UDim2.new(0.5, 0, 0.56, 58)
	if player:GetAttribute("IsDeveloper") == true then
		local world = button(tf, "JOGAR NO MUNDO", PANEL2, UDim2.new(0, 280, 0, 42), function()
			developerTitlePending = false
			if player:GetAttribute("PreLaunchLocked") == true then
				requestLaunch:FireServer("view", false)
			else
				refreshLock()
			end
		end)
		world.AnchorPoint = Vector2.new(0.5, 0.5)
		world.Position = UDim2.new(0.5, 0, 0.56, 108)
	end
	text(tf, table.concat(LaunchConfig.Notice, "\n"), FONT_BODY, 14, SUB, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0.9, 0, 0, 48) })
	titleFrame = tf
	task.defer(hideOthersForTitle) -- depois que o HUD dos outros controllers já existe

	-- Faixa do lobby
	local bar = Instance.new("Frame")
	bar.Name = "LobbyBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 10)
	bar.Size = UDim2.new(0, 560, 0, 44)
	bar.BackgroundColor3 = PANEL
	bar.BackgroundTransparency = 0.15
	bar.Visible = false
	bar.Parent = sg
	corner(bar)
	text(bar, "LOBBY DE TESTES  ·  o jogo completo chega em breve", FONT_BOLD, 14, INK,
		{ Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -170, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local open = button(bar, "★  APOIAR / SOBRE", GOLD, UDim2.new(0, 150, 0, 32), function()
		local pp = panel
		if pp then
			pp.Visible = not pp.Visible
		end
	end)
	open.Position = UDim2.new(1, -156, 0, 6)
	open.TextSize = 14
	if player:GetAttribute("IsDeveloper") == true then
		local world = button(bar, "VOLTAR AO MUNDO", PANEL2, UDim2.new(0, 180, 0, 32), function()
			developerTitlePending = false
			requestLaunch:FireServer("view", false)
		end)
		world.Position = UDim2.new(0.5, -90, 1, 6)
	end
	lobbyBar = bar

	buildPanel(sg)
	return sg
end

showLobby = function()
	developerTitlePending = false
	if player:GetAttribute("IsDeveloper") == true and player:GetAttribute("PreLaunchLocked") ~= true then
		requestLaunch:FireServer("view", true)
	end
	stopOrbit()
	restoreAfterTitle()
	applyBackpack() -- a intro (TrailerController) religa toda a CoreGui no fim
	if titleFrame then
		titleFrame.Visible = false
	end
	if lobbyBar then
		lobbyBar.Visible = true
	end
end

-- ---------------------------------------------------------------------------
-- Esconder a história enquanto preso ao lobby
-- ---------------------------------------------------------------------------

local function locked(): boolean
	return player:GetAttribute("PreLaunchLocked") == true
end

local function guard(g: Instance)
	if not g:IsA("ScreenGui") or not STORY_GUIS[g.Name] then
		return
	end
	local sg = g :: ScreenGui
	local function apply()
		if locked() and sg.Enabled then
			sg.Enabled = false
		end
	end
	apply()
	sg:GetPropertyChangedSignal("Enabled"):Connect(apply)
end

refreshLock = function()
	local developer = player:GetAttribute("IsDeveloper") == true
	if developer and not developerShortcut then
		local shortcut = Instance.new("ScreenGui")
		shortcut.Name = "LaunchAccessGui"
		shortcut.ResetOnSpawn = false
		shortcut.DisplayOrder = 41
		shortcut.Parent = playerGui
		local access = button(shortcut, "PRÉ-LANÇAMENTO", GOLD, UDim2.new(0, 170, 0, 36), function()
			requestLaunch:FireServer("view", true)
		end)
		access.AnchorPoint = Vector2.new(1, 1)
		access.Position = UDim2.new(1, -16, 1, -100)
		developerShortcut = shortcut
	end
	if developerShortcut then
		developerShortcut.Enabled = developer and not locked() and not developerTitlePending
	end
	applyBackpack()
	if locked() or (developer and developerTitlePending) then
		if not gui then
			gui = buildGui()
			startOrbit()
		end
		for _, g in playerGui:GetChildren() do
			if g:IsA("ScreenGui") and STORY_GUIS[g.Name] then
				g.Enabled = false
			end
		end
	elseif gui then
		playingIntro = false
		stopOrbit()
		restoreAfterTitle()
		gui:Destroy()
		gui, titleFrame, lobbyBar, panel, boardList, donatedLabel = nil, nil, nil, nil, nil, nil
		for _, g in playerGui:GetChildren() do
			if g:IsA("ScreenGui") and STORY_GUIS[g.Name] then
				g.Enabled = true
			end
		end
	end
end

local function updateDonated()
	local l = donatedLabel
	if l then
		local total = tonumber(player:GetAttribute("Donated")) or 0
		l.Text = if total > 0 then ("Você já apoiou com %d R$ — obrigado!"):format(total) else ""
	end
end

function IntroController.Init()
	requestLaunch = Remotes.GetEvent(Remotes.Events.RequestLaunch)
end

function IntroController.Start()
	if not LaunchConfig.PreLaunch then
		return
	end
	for _, g in playerGui:GetChildren() do
		guard(g)
	end
	playerGui.ChildAdded:Connect(guard)
	Remotes.GetEvent(Remotes.Events.NotifyLaunch).OnClientEvent:Connect(function(event: string, data: any)
		data = if typeof(data) == "table" then data else {}
		if event == "board" and typeof(data.board) == "table" then
			boardData = data.board
			renderBoard()
		elseif event == "thanks" then
			HUDController.ShowToast(("Obrigado pelos %d R$!"):format(tonumber(data.amount) or 0), "Você agora é Apoiador.", GOLD)
			updateDonated()
		elseif event == "info" then
			HUDController.ShowToast(tostring(data.text or ""), nil, GOLD)
		end
	end)
	player:GetAttributeChangedSignal("PreLaunchLocked"):Connect(refreshLock)
	player:GetAttributeChangedSignal("IsDeveloper"):Connect(refreshLock)
	player:GetAttributeChangedSignal("Donated"):Connect(updateDonated)
	-- Só no Studio: o teste automático (MCP) abre lobby/painel sem clique — atributo IntroDebug = "lobby" | "panel"
	if RunService:IsStudio() then
		player:GetAttributeChangedSignal("IntroDebug"):Connect(function()
			local mode = player:GetAttribute("IntroDebug")
			if gui and (mode == "lobby" or mode == "panel") then
				showLobby()
				if panel then
					panel.Visible = mode == "panel"
				end
			end
		end)
	end
	refreshLock()
	task.spawn(function()
		local ok, res = pcall(function()
			return Remotes.GetFunction(Remotes.Functions.FetchLaunch):InvokeServer()
		end)
		if ok and typeof(res) == "table" and typeof(res.board) == "table" then
			boardData = res.board
			renderBoard()
		end
		updateDonated()
	end)
	Log.debug("[IntroController] pronto")
end

return IntroController
