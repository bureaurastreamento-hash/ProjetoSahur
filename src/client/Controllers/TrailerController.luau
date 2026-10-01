--!strict
--[[
	TrailerController (cliente) — v3 (dono, 2026-10-01): trailer épico/sério, 16:9 (YouTube) e 9:16 (TikTok).
	O TrailerService manda TUDO por NotifyTrailer (event, data) na hora certa; aqui só se desenha:
	  begin    { format = "h"|"v", countdown }   esconde HUD/nomes, monta barras (h = cinema 2.39:1; v = coluna 9:16
	                                             no meio, o resto preto: grave a tela inteira e recorte a coluna),
	                                             tela preta + "PREPARING" até o countdown "3 2 1"
	  countdown{ n }                             número pequeno no canto (corte na edição)
	  shot     { kind = "path"|"orbit"|"follow", t, ease?, fov0, fov1?, roll0?, roll1?, hand?, dof? ... }
	             path:   pts = { CFrame... } (Catmull-Rom na posição), look = Vector3|nome de Model (opcional)
	             orbit:  center = Vector3|nome|{nomes}, radius, height, a0, a1 (graus), lookUp?
	             follow: target = nome, offset = Vector3 (no espaço do alvo, só yaw), lookOffset?, smooth?
	           no 9:16 a câmera se afasta do assunto (VK) para caber na coluna
	  title    { style = "card"|"place"|"move"|"small", text, sub?, seconds, color? }
	  fade     { to = 0|1, seconds }      flash { color?, seconds? }      impact { seconds? } (quadro de impacto P&B)
	  punch    { fov?, shake?, seconds? }  chute de câmera
	  grade    { preset, seconds? }        correção de cor (mist/desert/eclipse/night/dusk/normal/timestop/sepia)
	  anim     { model, key, stop? }       pose/animação procedural (FX.PlayAnimation "Pasta/Nome")
	  vfx      { model, key, at? }         composição do jogo (VFXLibrary/Assets)    sound { key, model? } (2D se sem model)
	  stand    { model, seconds, punch?, rate? }  silhueta do Stand
	  freeze   { models = {Model}, on }    congela a IMAGEM (clone ancorado no lugar; o original some)
	  timestop { at, phase = "stop"|"resume" }    portal { id, cf, size, phase = "open"|"close" }
	  arrow    { phase = "show"|"fly", at?, target? }   roulette { seconds, final }   menacing { seconds, count? }
	  logo     { seconds }   tbc { seconds }   hold (câmera para onde está)   end
	Modelos marcados pelo servidor com o atributo TrailerHidden somem só na tela (mobs, outros jogadores, atores fora
	de cena). Grave com OBS; textos em inglês.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local FX = require(Modules:WaitForChild("FX"))
local VFXLibrary = require(Modules:WaitForChild("VFXLibrary"))
local StandSilhouette = require(Modules:WaitForChild("StandSilhouette"))
local AwakeningDefs = require(Modules:WaitForChild("AwakeningDefs"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))

local TrailerController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local VK = 1.6 -- 9:16: quanto a câmera se afasta do assunto (a coluna tem ~1/3 da largura do 16:9)
local LETTERBOX = 0.12 -- 16:9 → ~2.39:1

local active = false
local format = "h"
local gui: ScreenGui? = nil
local stage: Frame? = nil -- área visível (entre as barras / dentro da coluna 9:16); todos os textos vivem aqui
local fadeFrame: Frame? = nil
local flashFrame: Frame? = nil
local countLabel: TextLabel? = nil
local hiddenGuis: { ScreenGui } = {}
local savedCameraType = Enum.CameraType.Custom
local savedMouseIcon = true
local savedFov = 70
local shotConn: RBXScriptConnection? = nil
local conns: { RBXScriptConnection } = {}
local props: Folder? = nil -- peças locais (portal, flecha, esfera, clones)
local cc: ColorCorrectionEffect? = nil
local bloom: BloomEffect? = nil
local dof: DepthOfFieldEffect? = nil
local hiddenModels: { [Model]: boolean } = {}
local hideHumanoids = false -- modo LOCAL (intro do pré-lançamento): todo personagem/NPC some só nesta tela
local savedNameDisplay: { [Humanoid]: Enum.HumanoidDisplayDistanceType } = {}
local savedBillboards: { [BillboardGui]: boolean } = {}
local frozen: { [Model]: Model } = {}
local portals: { [string]: { parts: { BasePart }, scale: NumberValue, conn: RBXScriptConnection, base: CFrame, size: number } } = {}

-- chute de câmera / tremor (somam por cima do plano)
local kickFov = 0
local kickUntil = 0
local kickStart = 0
local shake = 0
local shakeUntil = 0
local shakeStart = 0

local EASE: { [string]: Enum.EasingStyle } = {
	Sine = Enum.EasingStyle.Sine,
	Quad = Enum.EasingStyle.Quad,
	Linear = Enum.EasingStyle.Linear,
	Quart = Enum.EasingStyle.Quart,
	Cubic = Enum.EasingStyle.Cubic,
	Expo = Enum.EasingStyle.Exponential,
}

local FONT_TITLE = Enum.Font.Oswald
local FONT_SUB = Enum.Font.Michroma
local INK = Color3.fromRGB(245, 238, 225)
local GOLD = Color3.fromRGB(235, 195, 95)

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

local function findModel(ref: any): Model?
	if typeof(ref) == "Instance" and ref:IsA("Model") then
		return ref
	end
	if typeof(ref) ~= "string" then
		return nil
	end
	local m = Workspace:FindFirstChild(ref)
	return if m and m:IsA("Model") then m else nil
end

local function modelPos(m: Model?): Vector3?
	if not m or not m.Parent then
		return nil
	end
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else m:GetPivot().Position
end

local function refPos(ref: any): Vector3?
	if typeof(ref) == "Vector3" then
		return ref
	end
	if typeof(ref) == "table" then
		local sum, n = Vector3.zero, 0
		for _, r in ref do
			local p = modelPos(findModel(r))
			if p then
				sum += p
				n += 1
			end
		end
		return if n > 0 then sum / n else nil
	end
	local frozenClone = findModel(ref)
	if frozenClone and frozen[frozenClone] then
		return modelPos(frozen[frozenClone])
	end
	return modelPos(frozenClone)
end

local function tween(obj: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(obj, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function label(parent: Instance, text: string, font: Enum.Font, color: Color3, size: UDim2, pos: UDim2, anchor: Vector2?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.Size = size
	l.Position = pos
	l.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	l.TextStrokeTransparency = 1
	l.TextTransparency = 1
	l.ZIndex = 3
	l.Parent = parent
	return l
end

local function propsFolder(): Folder
	local f = props
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "TrailerProps"
	nf.Parent = Workspace
	props = nf
	return nf
end

local function newPart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Transparency = transparency or 0
	p.Parent = propsFolder()
	return p
end

local function emitter(parent: Instance, textureId: number, color: ColorSequence, props_: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxassetid://" .. textureId
	e.Color = color
	e.LightEmission = 1
	e.LightInfluence = 0
	for k, v in props_ do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function playSound(key: string, model: Model?)
	local folder, name = key:match("^(.-)/(.+)$")
	if not folder or not name then
		return
	end
	if model then
		FX.PlaySoundAt(model, folder, name)
	else
		FX.PlaySoundUI(folder, name)
	end
end

-- ---------------------------------------------------------------------------
-- Tela: barras / coluna 9:16 / textos
-- ---------------------------------------------------------------------------

local function layout()
	local sg = gui
	local st = stage
	if not sg or not st then
		return
	end
	local abs = sg.AbsoluteSize
	if format == "v" then
		local w = math.floor(abs.Y * 9 / 16)
		local side = math.max(0, (abs.X - w) / 2)
		local l = sg:FindFirstChild("PillarL") :: Frame?
		local r = sg:FindFirstChild("PillarR") :: Frame?
		if l and r then
			l.Size = UDim2.new(0, side + 1, 1, 0)
			r.Size = UDim2.new(0, side + 1, 1, 0)
		end
		st.Size = UDim2.new(0, w, 1, 0)
		st.Position = UDim2.new(0.5, 0, 0, 0)
		st.AnchorPoint = Vector2.new(0.5, 0)
	else
		st.Size = UDim2.new(1, 0, 1 - LETTERBOX * 2, 0)
		st.Position = UDim2.new(0, 0, LETTERBOX, 0)
		st.AnchorPoint = Vector2.zero
	end
end

local function buildGui(): ScreenGui
	local sg = Instance.new("ScreenGui")
	sg.Name = "TrailerGui"
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 100
	sg.ResetOnSpawn = false
	sg.ScreenInsets = Enum.ScreenInsets.None

	local st = Instance.new("Frame")
	st.Name = "Stage"
	st.BackgroundTransparency = 1
	st.ClipsDescendants = true
	st.ZIndex = 2
	st.Parent = sg
	stage = st

	local function black(name: string, size: UDim2, pos: UDim2, anchor: Vector2?): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Size = size
		f.Position = pos
		f.AnchorPoint = anchor or Vector2.zero
		f.ZIndex = 10
		f.Parent = sg
		return f
	end
	if format == "v" then
		black("PillarL", UDim2.new(0, 0, 1, 0), UDim2.new(0, 0, 0, 0))
		black("PillarR", UDim2.new(0, 0, 1, 0), UDim2.new(1, 0, 0, 0), Vector2.new(1, 0))
	else
		black("BarTop", UDim2.new(1, 0, LETTERBOX, 1), UDim2.new(0, 0, 0, 0))
		black("BarBottom", UDim2.new(1, 0, LETTERBOX, 1), UDim2.new(0, 0, 1, 0), Vector2.new(0, 1))
	end

	-- preto do começo/fim (dentro do palco, abaixo dos textos de cartela) e flash por cima de tudo
	local fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BorderSizePixel = 0
	fade.Size = UDim2.new(1, 0, 1, 0)
	fade.BackgroundTransparency = 0
	fade.ZIndex = 2
	fade.Parent = st
	fadeFrame = fade
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BorderSizePixel = 0
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 8
	flash.Parent = st
	flashFrame = flash

	local count = Instance.new("TextLabel")
	count.Name = "Countdown"
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.GothamMedium
	count.TextSize = 16
	count.TextColor3 = Color3.fromRGB(90, 90, 90)
	count.Text = "PREPARING"
	count.AnchorPoint = Vector2.new(1, 1)
	count.Position = UDim2.new(1, -14, 1, -10)
	count.Size = UDim2.new(0, 160, 0, 20)
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.ZIndex = 12
	count.Parent = sg
	countLabel = count

	sg:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	return sg
end

local titleToken = 0
local function clearTitles(onlyMoves: boolean?)
	local st = stage
	if not st then
		return
	end
	for _, c in st:GetChildren() do
		if c:GetAttribute("TrailerTitle") and (onlyMoves ~= true or c:GetAttribute("TrailerTitle") == "move") then
			c:Destroy()
		end
	end
end

--- Cartelas. card = centro, grande (frase); place = canto inferior (lugar); move = nome do golpe na lateral;
--- small = linha discreta embaixo.
local function onTitle(data: any)
	local st = stage
	if not st then
		return
	end
	titleToken += 1
	local seconds = tonumber(data.seconds) or 3
	local style = tostring(data.style or "card")
	local text = tostring(data.text or "")
	local sub = if data.sub then tostring(data.sub) else nil
	local color: Color3 = if typeof(data.color) == "Color3" then data.color else INK
	local vertical = format == "v"
	clearTitles(style == "move")

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 1, 0)
	holder.ZIndex = 3
	holder:SetAttribute("TrailerText", true)
	holder:SetAttribute("TrailerTitle", style)
	holder.Parent = st
	local labels: { TextLabel } = {}
	local others: { GuiObject } = {}

	if style == "card" then
		local main = label(holder, text, FONT_TITLE, color, UDim2.new(if vertical then 0.9 else 0.8, 0, if vertical then 0.075 else 0.11, 0), UDim2.new(0.5, 0, 0.5, 0))
		main.TextStrokeColor3 = Color3.new(0, 0, 0)
		table.insert(labels, main)
		local scale = Instance.new("UIScale")
		scale.Scale = 1.08
		scale.Parent = main
		tween(scale, seconds, { Scale = 1 }, Enum.EasingStyle.Sine)
		if sub then
			local s = label(holder, sub, FONT_SUB, Color3.fromRGB(200, 190, 175), UDim2.new(0.8, 0, if vertical then 0.022 else 0.035, 0), UDim2.new(0.5, 0, if vertical then 0.56 else 0.6, 0))
			table.insert(labels, s)
		end
	elseif style == "place" then
		local x = if vertical then 0.5 else 0.06
		local anchorX = if vertical then 0.5 else 0
		local main = label(holder, text, FONT_TITLE, color, UDim2.new(0.6, 0, if vertical then 0.04 else 0.07, 0), UDim2.new(x, 0, if vertical then 0.8 else 0.82, 0), Vector2.new(anchorX, 1))
		main.TextXAlignment = if vertical then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
		table.insert(labels, main)
		local line = Instance.new("Frame")
		line.BackgroundColor3 = GOLD
		line.BorderSizePixel = 0
		line.AnchorPoint = Vector2.new(anchorX, 0)
		line.Position = UDim2.new(x, 0, if vertical then 0.81 else 0.835, 0)
		line.Size = UDim2.new(0, 0, 0, 2)
		line.ZIndex = 3
		line.Parent = holder
		tween(line, 0.8, { Size = UDim2.new(if vertical then 0.3 else 0.18, 0, 0, 2) }, Enum.EasingStyle.Quart)
		table.insert(others, line)
		if sub then
			local s = label(holder, sub, FONT_SUB, Color3.fromRGB(210, 200, 185), UDim2.new(0.6, 0, if vertical then 0.018 else 0.03, 0), UDim2.new(x, 0, if vertical then 0.825 else 0.855, 0), Vector2.new(anchorX, 0))
			s.TextXAlignment = main.TextXAlignment
			table.insert(labels, s)
		end
	elseif style == "move" then
		local x = if vertical then 0.5 else 0.94
		local anchorX = if vertical then 0.5 else 1
		local y = if vertical then 0.2 else 0.2
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = color
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(anchorX, 0.5)
		bar.Position = UDim2.new(x, 0, y + (if vertical then 0.03 else 0.05), 0)
		bar.Size = UDim2.new(0, 0, 0, 3)
		bar.ZIndex = 3
		bar.Parent = holder
		tween(bar, 0.4, { Size = UDim2.new(if vertical then 0.5 else 0.22, 0, 0, 3) }, Enum.EasingStyle.Quart)
		table.insert(others, bar)
		local main = label(holder, text, FONT_TITLE, INK, UDim2.new(0.5, 0, if vertical then 0.045 else 0.075, 0), UDim2.new(x, 0, y, 0), Vector2.new(anchorX, 0.5))
		main.TextXAlignment = if vertical then Enum.TextXAlignment.Center else Enum.TextXAlignment.Right
		main.Position = UDim2.new(x + (if vertical then 0 else 0.04), 0, y, 0)
		tween(main, 0.35, { Position = UDim2.new(x, 0, y, 0) }, Enum.EasingStyle.Quart)
		table.insert(labels, main)
	else -- small
		local main = label(holder, text, FONT_SUB, color, UDim2.new(0.8, 0, if vertical then 0.02 else 0.035, 0), UDim2.new(0.5, 0, 0.9, 0))
		table.insert(labels, main)
	end

	for _, l in labels do
		tween(l, 0.45, { TextTransparency = 0 })
	end
	task.delay(seconds, function()
		if not holder.Parent then
			return
		end
		for _, l in labels do
			tween(l, 0.5, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		for _, o in others do
			tween(o, 0.5, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.delay(0.55, function()
			holder:Destroy()
		end)
	end)
end

-- ---------------------------------------------------------------------------
-- Câmera
-- ---------------------------------------------------------------------------

local function stopShot()
	if shotConn then
		shotConn:Disconnect()
		shotConn = nil
	end
end

--- Catmull-Rom (uniforme) por uma lista de pontos; t em 0..1.
local function spline(points: { Vector3 }, t: number): Vector3
	local n = #points
	if n == 1 then
		return points[1]
	end
	local seg = math.clamp(t, 0, 1) * (n - 1)
	local i = math.min(math.floor(seg) + 1, n - 1)
	local u = seg - (i - 1)
	local p0 = points[math.max(i - 1, 1)]
	local p1 = points[i]
	local p2 = points[i + 1]
	local p3 = points[math.min(i + 2, n)]
	local u2, u3 = u * u, u * u * u
	return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3)
end

local function rotAlong(cfs: { CFrame }, t: number): CFrame
	local n = #cfs
	if n == 1 then
		return cfs[1].Rotation
	end
	local seg = math.clamp(t, 0, 1) * (n - 1)
	local i = math.min(math.floor(seg) + 1, n - 1)
	local u = seg - (i - 1)
	return cfs[i].Rotation:Lerp(cfs[i + 1].Rotation, u)
end


-- Enquadramento: `frame` = lista de atores (nome) e/ou pontos (Vector3) que TÊM que caber inteiros na área
-- visível (entre as barras no 16:9 / na coluna no 9:16). A câmera mantém o ângulo do plano e só se AFASTA
-- (nunca chega mais perto que o roteiro) e recentra no meio do grupo — cabeça e pés sempre no quadro.
local FRAME_MARGIN = 0.8 -- fração da tela que o grupo pode ocupar
local FRAME_MAX = 70 -- teto de afastamento (corpo voando longe não leva a câmera para o espaço)
local R6_PARTS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local function addCorners(out: { Vector3 }, cf: CFrame, size: Vector3)
	local h = size / 2
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(out, (cf * CFrame.new(h.X * sx, h.Y * sy, h.Z * sz)).Position)
			end
		end
	end
end

local function framePoints(refs: { any }): { Vector3 }
	local out: { Vector3 } = {}
	for _, ref in refs do
		if typeof(ref) == "Vector3" then
			table.insert(out, ref)
			continue
		end
		local m = findModel(ref)
		if m and frozen[m] then
			m = frozen[m]
		end
		if not m or not m.Parent then
			continue
		end
		local any = false
		for _, n in R6_PARTS do
			local part = m:FindFirstChild(n)
			if part and part:IsA("BasePart") then
				addCorners(out, part.CFrame, part.Size)
				any = true
			end
		end
		if not any then -- boss por peças / modelo sem R6
			local cf, size = m:GetBoundingBox()
			addCorners(out, cf, size)
		end
	end
	return out
end

--- Centro (no plano da câmera) e distância mínima para os pontos caberem com `fov` e a direção `dir`.
local function fitFrame(points: { Vector3 }, dir: Vector3, fov: number): (Vector3?, number)
	local st = stage
	local camera = Workspace.CurrentCamera
	if #points == 0 or not st or not camera then
		return nil, 0
	end
	local vp = camera.ViewportSize
	local t = math.tan(math.rad(fov) / 2)
	local tanV = t * (st.AbsoluteSize.Y / math.max(vp.Y, 1)) * FRAME_MARGIN
	local tanH = t * (st.AbsoluteSize.X / math.max(vp.Y, 1)) * FRAME_MARGIN
	if tanV <= 0 or tanH <= 0 then
		return nil, 0
	end
	local rot = CFrame.lookAt(Vector3.zero, dir)
	local origin = Vector3.zero
	for _, p in points do
		origin += p
	end
	origin /= #points
	local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
	local loc: { Vector3 } = table.create(#points)
	for i, p in points do
		local q = rot:VectorToObjectSpace(p - origin)
		loc[i] = q
		minX, maxX = math.min(minX, q.X), math.max(maxX, q.X)
		minY, maxY = math.min(minY, q.Y), math.max(maxY, q.Y)
	end
	local midX, midY = (minX + maxX) / 2, (minY + maxY) / 2
	local need = 0
	for _, q in loc do
		local ahead = -q.Z -- quanto o ponto está ATRÁS do centro (mais longe da câmera)
		need = math.max(need, math.abs(q.X - midX) / tanH - ahead, math.abs(q.Y - midY) / tanV - ahead)
	end
	return origin + rot.RightVector * midX + rot.UpVector * midY, math.clamp(need, 0, FRAME_MAX)
end

local function onShot(data: any)
	local camera = Workspace.CurrentCamera
	if not camera or not active then
		return
	end
	stopShot()
	local t0 = os.clock()
	local dur = math.max(0.05, tonumber(data.t) or 4)
	local style = EASE[data.ease or "Sine"] or Enum.EasingStyle.Sine
	local fov0 = tonumber(data.fov0) or 55
	local fov1 = tonumber(data.fov1) or fov0
	local roll0 = tonumber(data.roll0) or 0
	local roll1 = tonumber(data.roll1) or roll0
	local hand = tonumber(data.hand) or 0
	local vertical = format == "v"
	local kind = tostring(data.kind or "path")
	local frameRefs: { any }? = if typeof(data.frame) == "table" then data.frame else nil
	-- com `frame` o enquadramento decide o afastamento (vale para 16:9 e 9:16); sem ele, o 9:16 afasta VK×
	local vk = if vertical and not frameRefs then VK else 1
	camera.CameraType = Enum.CameraType.Scriptable

	-- path: posições (Catmull-Rom) + rotação dos CFrames ou olhar fixo
	local pathCFs: { CFrame } = {}
	local pathPos: { Vector3 } = {}
	if kind == "path" and typeof(data.pts) == "table" then
		for _, cf in data.pts do
			if typeof(cf) == "CFrame" then
				table.insert(pathCFs, cf)
				table.insert(pathPos, cf.Position)
			end
		end
	end
	local smoothCenter: Vector3? = nil
	local followCF: CFrame? = nil
	local fitCenter: Vector3? = nil
	local fitDist = 0
	local seed = math.random() * 100

	shotConn = RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		local alpha = math.clamp((now - t0) / dur, 0, 1)
		local a = TweenService:GetValue(alpha, style, Enum.EasingDirection.InOut)
		local cf: CFrame
		local lookAt: Vector3? = nil

		if kind == "orbit" then
			local c = refPos(data.center)
			if c then
				smoothCenter = if smoothCenter then smoothCenter:Lerp(c, math.min(1, dt * 4)) else c
			end
			local center = smoothCenter or Vector3.zero
			local r = (tonumber(data.radius) or 12) * vk
			local h = (tonumber(data.height) or 3) * (if vk > 1 then 1.25 else 1)
			local ang = math.rad((tonumber(data.a0) or 0) + ((tonumber(data.a1) or 90) - (tonumber(data.a0) or 0)) * a)
			local pos = center + Vector3.new(math.cos(ang) * r, h, math.sin(ang) * r)
			local target = center + Vector3.new(0, tonumber(data.lookUp) or 2, 0)
			lookAt = target
			cf = CFrame.lookAt(pos, target)
		elseif kind == "follow" then
			local m = findModel(data.target)
			local root = m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
			local offset: Vector3 = if typeof(data.offset) == "Vector3" then data.offset else Vector3.new(0, 3, 10)
			offset *= vk
			local lookOffset: Vector3 = if typeof(data.lookOffset) == "Vector3" then data.lookOffset else Vector3.new(0, 1.5, 0)
			if root then
				local yaw = CFrame.new(root.Position) * CFrame.fromOrientation(0, select(2, root.CFrame:ToOrientation()), 0)
				local want = CFrame.lookAt((yaw * CFrame.new(offset)).Position, root.Position + lookOffset)
				local k = math.min(1, dt * (tonumber(data.smooth) or 6))
				followCF = if followCF then followCF:Lerp(want, k) else want
			end
			cf = followCF or camera.CFrame
		else
			if #pathPos == 0 then
				return
			end
			local pos = spline(pathPos, a)
			local look = data.look
			local lp: Vector3? = if look ~= nil then refPos(look) else nil
			if lp then
				if vk > 1 and data.wide ~= true then
					pos = lp + (pos - lp) * vk
				end
				lookAt = lp
				cf = CFrame.lookAt(pos, lp)
			else
				cf = CFrame.new(pos) * rotAlong(pathCFs, a)
			end
		end

		local baseFov = fov0 + (fov1 - fov0) * a
		if frameRefs then
			local center, need = fitFrame(framePoints(frameRefs), cf.LookVector, baseFov)
			if center then
				local scripted = if lookAt then (cf.Position - lookAt).Magnitude else need
				local want = math.max(scripted, need)
				local k = math.min(1, dt * 5)
				fitCenter = if fitCenter then fitCenter:Lerp(center, k) else center
				fitDist = if fitDist > 0 then fitDist + (want - fitDist) * k else want
				local fc = fitCenter :: Vector3
				cf = CFrame.lookAt(fc - cf.LookVector * fitDist, fc)
				lookAt = fc
			end
		end

		-- rolagem (dutch angle), câmera na mão e tremor de impacto
		local roll = roll0 + (roll1 - roll0) * a
		if roll ~= 0 then
			cf *= CFrame.Angles(0, 0, math.rad(roll))
		end
		if hand > 0 then
			local tt = now * 0.9
			cf *= CFrame.Angles(math.rad(math.noise(tt, seed) * hand), math.rad(math.noise(seed, tt) * hand), 0)
		end
		if now < shakeUntil then
			local k = 1 - (now - shakeStart) / math.max(0.01, shakeUntil - shakeStart)
			local s = shake * k
			cf *= CFrame.new(math.noise(now * 30, 1) * s, math.noise(now * 30, 2) * s, 0) * CFrame.Angles(0, 0, math.rad(math.noise(now * 25, 3) * s * 4))
		end
		camera.CFrame = cf
		local fov = baseFov
		if now < kickUntil then
			local k = 1 - (now - kickStart) / math.max(0.01, kickUntil - kickStart)
			fov += kickFov * k * k
		end
		camera.FieldOfView = math.clamp(fov, 8, 110)
		-- foco: assunto do plano (ou o `dof` explícito)
		local d = dof
		if d then
			local focusRef = data.dof or lookAt
			local fp = if focusRef ~= nil then refPos(focusRef) else nil
			if fp then
				d.FocusDistance = (fp - cf.Position).Magnitude
			end
		end
	end)
end

local function onPunch(data: any)
	local now = os.clock()
	local seconds = tonumber(data.seconds) or 0.35
	kickFov = tonumber(data.fov) or -8
	kickStart, kickUntil = now, now + seconds
	shake = tonumber(data.shake) or 0.6
	shakeStart, shakeUntil = now, now + seconds * 1.4
end

-- ---------------------------------------------------------------------------
-- Cor / flash / quadro de impacto
-- ---------------------------------------------------------------------------

type Grade = { b: number, c: number, s: number, tint: Color3, bloom: number, far: number, near: number }
local GRADES: { [string]: Grade } = {
	normal = { b = 0, c = 0.08, s = 0.05, tint = Color3.new(1, 1, 1), bloom = 0.4, far = 0.15, near = 0 },
	mist = { b = 0.02, c = 0.06, s = -0.3, tint = Color3.fromRGB(212, 226, 238), bloom = 0.5, far = 0.35, near = 0 },
	desert = { b = 0.03, c = 0.14, s = 0.1, tint = Color3.fromRGB(255, 236, 208), bloom = 0.45, far = 0.25, near = 0 },
	eclipse = { b = -0.02, c = 0.2, s = 0.05, tint = Color3.fromRGB(255, 205, 178), bloom = 0.6, far = 0.3, near = 0 },
	dusk = { b = -0.01, c = 0.16, s = 0, tint = Color3.fromRGB(255, 214, 196), bloom = 0.55, far = 0.3, near = 0 },
	night = { b = -0.03, c = 0.18, s = -0.15, tint = Color3.fromRGB(192, 202, 255), bloom = 0.7, far = 0.3, near = 0 },
	timestop = { b = -0.06, c = 0.45, s = -1, tint = Color3.fromRGB(205, 190, 255), bloom = 0.9, far = 0.2, near = 0 },
	sepia = { b = 0.03, c = 0.12, s = -1, tint = Color3.fromRGB(255, 218, 165), bloom = 0.2, far = 0, near = 0 },
	close = { b = 0, c = 0.12, s = 0.05, tint = Color3.new(1, 1, 1), bloom = 0.45, far = 0.55, near = 0.25 },
}
local currentGrade = "normal"

local function onGrade(data: any)
	local g = GRADES[tostring(data.preset or "normal")] or GRADES.normal
	currentGrade = tostring(data.preset or "normal")
	local seconds = tonumber(data.seconds) or 0.6
	if cc then
		tween(cc, seconds, { Brightness = g.b, Contrast = g.c, Saturation = g.s, TintColor = g.tint }, Enum.EasingStyle.Sine)
	end
	if bloom then
		tween(bloom, seconds, { Intensity = g.bloom }, Enum.EasingStyle.Sine)
	end
	if dof then
		tween(dof, seconds, { FarIntensity = g.far, NearIntensity = g.near }, Enum.EasingStyle.Sine)
	end
end

local function onFlash(data: any)
	local f = flashFrame
	if not f then
		return
	end
	f.BackgroundColor3 = if typeof(data.color) == "Color3" then data.color else Color3.new(1, 1, 1)
	f.BackgroundTransparency = tonumber(data.from) or 0
	tween(f, tonumber(data.seconds) or 0.5, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
end

--- Quadro de impacto (mangá): 1 quadro branco + preto-e-branco de alto contraste, e volta ao grade atual.
local function onImpact(data: any)
	local seconds = tonumber(data.seconds) or 0.14
	onFlash({ seconds = 0.08 })
	local c = cc
	if not c then
		return
	end
	local back = GRADES[currentGrade] or GRADES.normal
	c.Saturation, c.Contrast, c.Brightness = -1, 2.2, 0.08
	task.delay(seconds, function()
		if c.Parent then
			tween(c, 0.12, { Brightness = back.b, Contrast = back.c, Saturation = back.s })
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Esconder figurantes / nomes
-- ---------------------------------------------------------------------------

local function setModelVisible(m: Model, visible: boolean)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if visible then 0 else 1
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = if visible then 0 else 1
		elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
			if not visible then
				if savedBillboards[d :: any] == nil then
					savedBillboards[d :: any] = (d :: any).Enabled
				end
				(d :: any).Enabled = false
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			if not visible then
				if d:GetAttribute("TrailerWasOn") == nil then
					d:SetAttribute("TrailerWasOn", (d :: any).Enabled)
				end
				(d :: any).Enabled = false
			elseif d:GetAttribute("TrailerWasOn") ~= nil then
				(d :: any).Enabled = d:GetAttribute("TrailerWasOn") == true
				d:SetAttribute("TrailerWasOn", nil)
			end
		end
	end
end

local function quietModel(m: Model)
	-- sem nomes/barras de vida/plaquinhas em ninguém durante o trailer
	local h = m:FindFirstChildOfClass("Humanoid")
	if h and savedNameDisplay[h] == nil then
		savedNameDisplay[h] = h.DisplayDistanceType
		h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BillboardGui") and savedBillboards[d] == nil then
			savedBillboards[d] = d.Enabled
			d.Enabled = false
		end
	end
end

local function refreshHidden(m: Instance)
	if not m:IsA("Model") or not active then
		return
	end
	if m:FindFirstChildOfClass("Humanoid") then
		quietModel(m)
	end
	local hide = (m:GetAttribute("TrailerHidden") == true or (hideHumanoids and m:FindFirstChildOfClass("Humanoid") ~= nil)) and not frozen[m]
	if hide and not hiddenModels[m] then
		hiddenModels[m] = true
		setModelVisible(m, false)
	elseif not hide and hiddenModels[m] then
		hiddenModels[m] = nil
		if not frozen[m] then
			setModelVisible(m, true)
		end
	end
end

local function watchModel(m: Instance)
	if not m:IsA("Model") then
		return
	end
	refreshHidden(m)
	table.insert(conns, m:GetAttributeChangedSignal("TrailerHidden"):Connect(function()
		refreshHidden(m)
	end))
	-- peças que chegam depois (acessórios do avatar carregando) também somem
	table.insert(conns, m.DescendantAdded:Connect(function(d)
		if hiddenModels[m] or frozen[m] then
			if d:IsA("BasePart") or d:IsA("Decal") then
				(d :: any).LocalTransparencyModifier = 1
			end
		end
		if d:IsA("BillboardGui") and savedBillboards[d] == nil then
			savedBillboards[d] = d.Enabled
			d.Enabled = false
		end
	end))
end

-- ---------------------------------------------------------------------------
-- Congelar imagem / parada do tempo
-- ---------------------------------------------------------------------------

local function freezeModel(m: Model)
	if frozen[m] or not m.Parent then
		return
	end
	local was = m.Archivable
	m.Archivable = true
	local ok, clone = pcall(function()
		return m:Clone()
	end)
	m.Archivable = was
	if not ok or not clone then
		return
	end
	local c = clone :: Model
	c.Name = m.Name .. "_Frozen"
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("ParticleEmitter") then
			d.TimeScale = 0
		elseif d:IsA("BillboardGui") then
			d.Enabled = false
		end
	end
	local h = c:FindFirstChildOfClass("Humanoid")
	if h then
		h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		h.PlatformStand = true
	end
	c.Parent = propsFolder()
	frozen[m] = c
	setModelVisible(m, false)
end

local function unfreezeModel(m: Model)
	local c = frozen[m]
	if not c then
		return
	end
	frozen[m] = nil
	c:Destroy()
	if not hiddenModels[m] then
		setModelVisible(m, true)
	end
end

local function onFreeze(data: any)
	local list = if typeof(data.models) == "table" then data.models else {}
	for _, ref in list do
		local m = findModel(ref)
		if m then
			if data.on then
				freezeModel(m)
			else
				unfreezeModel(m)
			end
		end
	end
	-- partículas no ar (VFX do jogo) congelam/voltam junto
	for _, d in Workspace:GetDescendants() do
		if d:IsA("ParticleEmitter") and not d:IsDescendantOf(propsFolder()) then
			local pe = d :: ParticleEmitter
			if data.on and data.particles ~= false then
				if pe:GetAttribute("TrailerTS") == nil then
					pe:SetAttribute("TrailerTS", pe.TimeScale)
				end
				pe.TimeScale = 0
			elseif not data.on and pe:GetAttribute("TrailerTS") ~= nil then
				pe.TimeScale = tonumber(pe:GetAttribute("TrailerTS")) or 1
				pe:SetAttribute("TrailerTS", nil)
			end
		end
	end
end

local function onTimeStop(data: any)
	local at: Vector3 = if typeof(data.at) == "Vector3" then data.at else Vector3.zero
	local stop = data.phase ~= "resume"
	local ball = newPart("TimeSphere", Vector3.one, CFrame.new(at), Color3.fromRGB(150, 120, 255), Enum.Material.ForceField, 0)
	ball.Shape = Enum.PartType.Ball
	local shell = newPart("TimeShell", Vector3.one, CFrame.new(at), Color3.fromRGB(240, 235, 255), Enum.Material.Neon, 0.75)
	shell.Shape = Enum.PartType.Ball
	if stop then
		ball.Size = Vector3.one * 2
		shell.Size = Vector3.one * 2
		tween(ball, 0.75, { Size = Vector3.one * 150 }, Enum.EasingStyle.Quart)
		tween(shell, 0.5, { Size = Vector3.one * 60, Transparency = 1 }, Enum.EasingStyle.Quart)
		task.delay(0.35, function()
			onGrade({ preset = "timestop", seconds = 0.35 })
		end)
		task.delay(0.8, function()
			tween(ball, 0.5, { Transparency = 1 })
		end)
		playSound("Shared/Awakening_Freeze")
	else
		ball.Size = Vector3.one * 150
		ball.Transparency = 0.3
		tween(ball, 0.45, { Size = Vector3.one * 1 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		shell.Size = Vector3.one * 2
		tween(shell, 0.4, { Size = Vector3.one * 40, Transparency = 1 }, Enum.EasingStyle.Quart)
		task.delay(0.45, function()
			onFlash({ seconds = 0.5 })
		end)
		playSound("Swift/TimeDome_Break")
	end
	task.delay(1.6, function()
		ball:Destroy()
		shell:Destroy()
	end)
end

-- ---------------------------------------------------------------------------
-- Portal
-- ---------------------------------------------------------------------------

local function onPortal(data: any)
	local id = tostring(data.id or "p")
	local size = tonumber(data.size) or 10
	if data.phase == "close" then
		local p = portals[id]
		if not p then
			return
		end
		portals[id] = nil
		tween(p.scale, 0.35, { Value = 0.02 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		playSound("Shared/Transform_Burst")
		task.delay(0.33, function()
			local center = p.base.Position
			local burst = newPart("PortalBurst", Vector3.one * 2, CFrame.new(center), Color3.fromRGB(190, 150, 255), Enum.Material.Neon, 0.2)
			burst.Shape = Enum.PartType.Ball
			tween(burst, 0.35, { Size = Vector3.one * size * 1.4, Transparency = 1 }, Enum.EasingStyle.Quart)
			p.conn:Disconnect()
			for _, part in p.parts do
				part:Destroy()
			end
			task.delay(0.5, function()
				burst:Destroy()
			end)
		end)
		return
	end
	local base: CFrame = if typeof(data.cf) == "CFrame" then data.cf else CFrame.new()
	-- disco virado para LookVector: o eixo X do cilindro vai para a frente
	local disc = base * CFrame.Angles(0, math.rad(90), 0)
	local rim = newPart("PortalRim", Vector3.new(0.2, size, size), disc, Color3.fromRGB(150, 90, 255), Enum.Material.Neon, 0)
	rim.Shape = Enum.PartType.Cylinder
	local glow = newPart("PortalGlow", Vector3.new(0.15, size * 1.08, size * 1.08), disc, Color3.fromRGB(110, 220, 255), Enum.Material.Neon, 0.55)
	glow.Shape = Enum.PartType.Cylinder
	local core = newPart("PortalCore", Vector3.new(0.4, size * 0.86, size * 0.86), disc, Color3.fromRGB(14, 6, 28), Enum.Material.Glass, 0.05)
	core.Shape = Enum.PartType.Cylinder
	local swirl = newPart("PortalSwirl", Vector3.new(size, 0.2, size), base * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(190, 140, 255), Enum.Material.Neon, 0.35)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	local ring = VFXLibrary.Meshes.RingPurple
	mesh.MeshId = "rbxassetid://" .. ring.id
	mesh.Parent = swirl
	local sucker = newPart("PortalPull", Vector3.new(size * 0.8, size * 0.8, 0.5), base, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, 1)
	emitter(sucker, VFXLibrary.Textures.Flare, ColorSequence.new(Color3.fromRGB(200, 160, 255), Color3.fromRGB(110, 220, 255)), {
		Rate = 60,
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(4, 7),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.2, 1),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		RotSpeed = NumberRange.new(-180, 180),
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 120, 255)
	light.Brightness = 5
	light.Range = size * 2.2
	light.Parent = core
	local parts: { BasePart } = { rim, glow, core, swirl, sucker }
	local scale = Instance.new("NumberValue")
	scale.Value = 0.02
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local s = math.max(0.02, scale.Value)
		local wobble = 1 + math.sin((os.clock() - t0) * 7) * 0.02
		rim.Size = Vector3.new(0.2, size * s * wobble, size * s * wobble)
		glow.Size = Vector3.new(0.15, size * 1.08 * s, size * 1.08 * s)
		core.Size = Vector3.new(0.4, size * 0.86 * s, size * 0.86 * s)
		local spin = (os.clock() - t0) * 3
		swirl.CFrame = base * CFrame.Angles(math.rad(90), spin, 0)
		mesh.Scale = Vector3.new(size / ring.size.X, 1, size / ring.size.Z) * s
		sucker.Size = Vector3.new(size * 0.8 * s, size * 0.8 * s, 0.5)
	end)
	portals[id] = { parts = parts, scale = scale, conn = conn, base = base, size = size }
	tween(scale, 0.8, { Value = 1 }, Enum.EasingStyle.Back)
	playSound("Shared/Awakening_Riser")
end

-- ---------------------------------------------------------------------------
-- Flecha / roleta
-- ---------------------------------------------------------------------------

local arrowModel: Model? = nil
local arrowConn: RBXScriptConnection? = nil
local arrowHum: (() -> ())? = nil -- zumbido da Flecha (som em LOOP): sempre parar

local function stopArrowHum()
	local stop = arrowHum
	arrowHum = nil
	if stop then
		stop()
	end
end

local function buildArrow(at: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "TrailerArrow"
	local gold = Color3.fromRGB(230, 185, 80)
	local shaft = newPart("Shaft", Vector3.new(0.16, 0.16, 3.4), CFrame.new(at), Color3.fromRGB(150, 110, 60), Enum.Material.Wood)
	local head = newPart("Head", Vector3.new(0.08, 0.7, 0.9), CFrame.new(at + Vector3.new(0, 0, -2.05)) * CFrame.Angles(0, 0, math.rad(45)), gold, Enum.Material.Neon)
	local head2 = newPart("Head2", Vector3.new(0.08, 0.7, 0.9), CFrame.new(at + Vector3.new(0, 0, -2.05)) * CFrame.Angles(0, 0, math.rad(-45)), gold, Enum.Material.Neon)
	local beetle = newPart("Beetle", Vector3.new(0.42, 0.42, 0.42), CFrame.new(at + Vector3.new(0, 0, -1.45)), gold, Enum.Material.Metal)
	beetle.Shape = Enum.PartType.Ball
	local fl = newPart("Fletch", Vector3.new(0.05, 0.6, 0.7), CFrame.new(at + Vector3.new(0, 0, 1.5)), Color3.fromRGB(240, 235, 220), Enum.Material.SmoothPlastic)
	local fl2 = newPart("Fletch2", Vector3.new(0.6, 0.05, 0.7), CFrame.new(at + Vector3.new(0, 0, 1.5)), Color3.fromRGB(240, 235, 220), Enum.Material.SmoothPlastic)
	for _, p in { shaft, head, head2, beetle, fl, fl2 } do
		p.Parent = m
	end
	m.PrimaryPart = shaft
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Brightness = 3
	light.Range = 10
	light.Parent = beetle
	emitter(head, VFXLibrary.Textures.Shine, ColorSequence.new(gold), {
		Rate = 10,
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(0.5, 1.5),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		SpreadAngle = Vector2.new(180, 180),
	})
	m.Parent = propsFolder()
	return m
end

local function onArrow(data: any)
	if data.phase == "show" then
		if arrowModel then
			arrowModel:Destroy()
		end
		local at: Vector3 = if typeof(data.at) == "Vector3" then data.at else Vector3.zero
		local m = buildArrow(at)
		arrowModel = m
		local t0 = os.clock()
		if arrowConn then
			arrowConn:Disconnect()
		end
		arrowConn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			m:PivotTo(CFrame.new(at + Vector3.new(0, math.sin(t * 1.6) * 0.25, 0)) * CFrame.Angles(math.rad(-12), t * 0.6, 0))
		end)
		stopArrowHum()
		arrowHum = FX.PlaySoundUIStoppable("Shared", "Awakening_Charge")
	elseif data.phase == "fly" then
		stopArrowHum()
		local m = arrowModel
		local target = findModel(data.target)
		local root = target and target:FindFirstChild("Torso") or (target and target:FindFirstChild("HumanoidRootPart"))
		if not m or not root or not root:IsA("BasePart") then
			return
		end
		if arrowConn then
			arrowConn:Disconnect()
			arrowConn = nil
		end
		local from = m:GetPivot()
		local seconds = tonumber(data.seconds) or 0.45
		local t0 = os.clock()
		playSound("Shared/Finisher_Whoosh")
		arrowConn = RunService.RenderStepped:Connect(function()
			local a = math.clamp((os.clock() - t0) / seconds, 0, 1)
			local e = a * a
			local to = (root :: BasePart).Position
			local pos = from.Position:Lerp(to, e)
			m:PivotTo(CFrame.lookAt(pos, to + (to - from.Position).Unit))
			if a >= 1 then
				if arrowConn then
					arrowConn:Disconnect()
					arrowConn = nil
				end
				m:Destroy()
				arrowModel = nil
			end
		end)
	else
		stopArrowHum()
		if arrowModel then
			arrowModel:Destroy()
			arrowModel = nil
		end
	end
end

local RARITIES: { { any } } = {
	{ "COMMON", Color3.fromRGB(190, 190, 190) },
	{ "UNCOMMON", Color3.fromRGB(110, 200, 110) },
	{ "RARE", Color3.fromRGB(80, 150, 255) },
	{ "EPIC", Color3.fromRGB(170, 90, 240) },
	{ "LEGENDARY", Color3.fromRGB(255, 180, 40) },
	{ "RELIC", Color3.fromRGB(255, 90, 90) },
	{ "ANOMALOUS", Color3.fromRGB(60, 240, 230) },
}

local function onRoulette(data: any)
	local st = stage
	if not st then
		return
	end
	local seconds = tonumber(data.seconds) or 4
	local vertical = format == "v"
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 1, 0)
	holder.ZIndex = 4
	holder:SetAttribute("TrailerText", true)
	holder.Parent = st
	local header = label(holder, "STAND RARITY", FONT_SUB, Color3.fromRGB(215, 205, 190), UDim2.new(0.6, 0, if vertical then 0.02 else 0.032, 0), UDim2.new(0.5, 0, if vertical then 0.66 else 0.68, 0))
	header.TextTransparency = 0.1
	local name = label(holder, "COMMON", FONT_TITLE, Color3.new(1, 1, 1), UDim2.new(0.8, 0, if vertical then 0.07 else 0.1, 0), UDim2.new(0.5, 0, if vertical then 0.72 else 0.77, 0))
	name.TextTransparency = 0
	name.TextStrokeTransparency = 0.4
	local nameScale = Instance.new("UIScale")
	nameScale.Parent = name
	local odds = label(holder, "", FONT_SUB, Color3.fromRGB(215, 205, 190), UDim2.new(0.6, 0, if vertical then 0.018 else 0.03, 0), UDim2.new(0.5, 0, if vertical then 0.77 else 0.85, 0))
	task.spawn(function()
		local t0 = os.clock()
		local spinFor = seconds - 1.2
		local i = 1
		local interval = 0.05
		while os.clock() - t0 < spinFor and holder.Parent do
			i = i % 6 + 1 -- gira entre os 6 primeiros; o Anômalo só aparece no fim
			name.Text = RARITIES[i][1]
			name.TextColor3 = RARITIES[i][2]
			nameScale.Scale = 1.06
			tween(nameScale, interval * 0.9, { Scale = 1 })
			FX.PlaySoundUI("Shared", "Block")
			task.wait(interval)
			interval = math.min(0.32, interval * 1.16)
		end
		if not holder.Parent then
			return
		end
		local final = RARITIES[7]
		name.Text = final[1]
		name.TextColor3 = final[2]
		nameScale.Scale = 1.5
		tween(nameScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		onFlash({ color = final[2], seconds = 0.7, from = 0.2 })
		onPunch({ fov = -10, shake = 0.8, seconds = 0.5 })
		playSound("Shared/Awakening_Burst")
		odds.Text = "0.05%  ·  NO PITY. ONLY FATE."
		tween(odds, 0.4, { TextTransparency = 0 })
		task.wait(1.1)
		for _, l in { header, name, odds } do
			tween(l, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
		task.wait(0.45)
		holder:Destroy()
	end)
end

-- ---------------------------------------------------------------------------
-- "ゴゴゴ", logo, To Be Continued
-- ---------------------------------------------------------------------------

local function onMenacing(data: any)
	local st = stage
	if not st then
		return
	end
	local seconds = tonumber(data.seconds) or 3
	local count = tonumber(data.count) or 7
	local vertical = format == "v"
	for i = 1, count do
		task.delay((i - 1) * 0.16, function()
			if not st.Parent then
				return
			end
			local side = if i % 2 == 0 then 1 else 0
			local x = if vertical then (0.12 + math.random() * 0.76) else (if side == 1 then 0.7 + math.random() * 0.24 else 0.04 + math.random() * 0.22)
			local y = 0.15 + math.random() * 0.6
			local g = label(st, "ゴ", Enum.Font.GothamBlack, Color3.fromRGB(170, 70, 220), UDim2.new(0, 0, if vertical then 0.07 else 0.12, 0), UDim2.new(x, 0, y, 0))
			g.Size = UDim2.new(if vertical then 0.14 else 0.08, 0, if vertical then 0.07 else 0.12, 0)
			g.TextStrokeColor3 = Color3.fromRGB(20, 0, 30)
			g.Rotation = math.random(-14, 14)
			g:SetAttribute("TrailerText", true)
			local s = Instance.new("UIScale")
			s.Scale = 0.4
			s.Parent = g
			tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			tween(g, 0.2, { TextTransparency = 0.05, TextStrokeTransparency = 0.2 })
			local life = seconds - (i - 1) * 0.16
			tween(g, life, { Position = UDim2.new(x + (math.random() - 0.5) * 0.03, 0, y - 0.05, 0), Rotation = g.Rotation + math.random(-6, 6) }, Enum.EasingStyle.Sine)
			-- tremidinha
			task.spawn(function()
				local t0 = os.clock()
				while g.Parent and os.clock() - t0 < life - 0.3 do
					s.Scale = 1 + (math.random() - 0.5) * 0.06
					task.wait(0.05)
				end
			end)
			task.delay(math.max(0.3, life - 0.3), function()
				tween(g, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
				task.delay(0.35, function()
					g:Destroy()
				end)
			end)
		end)
	end
end

local function onLogo(data: any)
	local st = stage
	if not st then
		return
	end
	clearTitles()
	local seconds = tonumber(data.seconds) or 5
	local vertical = format == "v"
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 1, 0)
	holder.ZIndex = 5
	holder:SetAttribute("TrailerText", true)
	holder.Parent = st
	local function word(text: string, y: number, h: number, font: Enum.Font, grad: boolean): TextLabel
		local l = label(holder, text, font, Color3.new(1, 1, 1), UDim2.new(if vertical then 0.92 else 0.7, 0, h, 0), UDim2.new(0.5, 0, y, 0))
		l.ZIndex = 6
		l.TextStrokeColor3 = Color3.fromRGB(25, 10, 35)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = if vertical then 2 else 3
		stroke.Color = Color3.fromRGB(25, 10, 35)
		stroke.Transparency = 1
		stroke.Parent = l
		if grad then
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 225, 130)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(235, 160, 70)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 80, 220)),
			})
			g.Rotation = 90
			g.Parent = l
		end
		return l
	end
	local top = word("BIZARRE", if vertical then 0.4 else 0.36, if vertical then 0.09 else 0.17, Enum.Font.Bangers, true)
	local bottom = word("SHOWDOWN", if vertical then 0.49 else 0.53, if vertical then 0.09 else 0.17, Enum.Font.Bangers, true)
	local fx = word("F / X", if vertical then 0.565 else 0.665, if vertical then 0.035 else 0.06, FONT_TITLE, false)
	fx.TextColor3 = Color3.fromRGB(110, 230, 255)
	local cta = word("PLAY NOW ON ROBLOX", if vertical then 0.63 else 0.76, if vertical then 0.022 else 0.035, FONT_SUB, false)
	cta.TextColor3 = INK
	local all = { top, bottom, fx, cta }
	for i, l in all do
		local s = Instance.new("UIScale")
		s.Scale = 1.35
		s.Parent = l
		task.delay((i - 1) * 0.12 + (if i == 4 then 0.5 else 0), function()
			tween(s, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
			tween(l, 0.25, { TextTransparency = 0 })
			local stroke = l:FindFirstChildOfClass("UIStroke")
			if stroke then
				tween(stroke, 0.25, { Transparency = 0 })
			end
		end)
	end
	task.delay(0.2, function()
		onPunch({ fov = -6, shake = 0.5, seconds = 0.4 })
	end)
	task.delay(seconds, function()
		for _, l in all do
			tween(l, 0.5, { TextTransparency = 1 })
			local stroke = l:FindFirstChildOfClass("UIStroke")
			if stroke then
				tween(stroke, 0.5, { Transparency = 1 })
			end
		end
		task.delay(0.6, function()
			holder:Destroy()
		end)
	end)
end

local function onTbc(data: any)
	local st = stage
	if not st then
		return
	end
	local seconds = tonumber(data.seconds) or 3
	local vertical = format == "v"
	onGrade({ preset = "sepia", seconds = 0.15 })
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 1, 0)
	holder.ZIndex = 6
	holder:SetAttribute("TrailerText", true)
	holder.Parent = st
	local box = Instance.new("Frame")
	box.BackgroundColor3 = Color3.fromRGB(60, 42, 22)
	box.BorderSizePixel = 0
	box.AnchorPoint = Vector2.new(0, 1)
	local w = if vertical then 0.8 else 0.34
	box.Size = UDim2.new(w, 0, if vertical then 0.06 else 0.1, 0)
	box.Position = UDim2.new(-w, 0, if vertical then 0.9 else 0.92, 0)
	box.ZIndex = 7
	box.Parent = holder
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(235, 200, 120)
	stroke.Thickness = 3
	stroke.Parent = box
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(0.92, 0, 0.7, 0)
	t.Position = UDim2.new(0.5, 0, 0.5, 0)
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Font = Enum.Font.Bangers
	t.TextScaled = true
	t.Text = "TO BE CONTINUED  ⇒"
	t.TextColor3 = Color3.fromRGB(245, 220, 150)
	t.ZIndex = 8
	t.Parent = box
	tween(box, 0.35, { Position = UDim2.new(if vertical then 0.1 else 0.04, 0, box.Position.Y.Scale, 0) }, Enum.EasingStyle.Quart)
	task.delay(seconds, function()
		holder:Destroy()
	end)
end

-- ---------------------------------------------------------------------------
-- Ciclo
-- ---------------------------------------------------------------------------

local function begin(data: any)
	if active then
		return
	end
	active = true
	format = if data.format == "v" then "v" else "h"
	hideHumanoids = data.hideHumanoids == true
	local camera = Workspace.CurrentCamera
	if camera then
		savedCameraType = camera.CameraType
		savedFov = camera.FieldOfView
		camera.CameraType = Enum.CameraType.Scriptable
	end
	table.clear(hiddenGuis)
	-- HUD do jogo some (e continua sumido: tela que abrir/religar durante o trailer, ex. barra do boss, é desligada)
	local function silence(g: Instance)
		if not g:IsA("ScreenGui") or g.Name == "TrailerGui" then
			return
		end
		if g.Enabled then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
		table.insert(conns, g:GetPropertyChangedSignal("Enabled"):Connect(function()
			if active and g.Enabled then
				g.Enabled = false
				if not table.find(hiddenGuis, g) then
					table.insert(hiddenGuis, g)
				end
			end
		end))
	end
	for _, g in playerGui:GetChildren() do
		silence(g)
	end
	table.insert(conns, playerGui.ChildAdded:Connect(silence))
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	savedMouseIcon = UserInputService.MouseIconEnabled
	-- o CursorController religa o mouse do sistema a cada quadro: este passo roda depois dele
	RunService:BindToRenderStep("TrailerCursor", Enum.RenderPriority.Last.Value + 1, function()
		UserInputService.MouseIconEnabled = false
	end)
	local sg = buildGui()
	sg.Parent = playerGui
	gui = sg
	layout()
	-- pós-processo próprio (some no fim)
	local c = Instance.new("ColorCorrectionEffect")
	c.Name = "TrailerGrade"
	c.Parent = Lighting
	cc = c
	local b = Instance.new("BloomEffect")
	b.Name = "TrailerBloom"
	b.Intensity = 0.4
	b.Size = 28
	b.Threshold = 1.6
	b.Parent = Lighting
	bloom = b
	local d = Instance.new("DepthOfFieldEffect")
	d.Name = "TrailerDOF"
	d.FarIntensity = 0.15
	d.NearIntensity = 0
	d.InFocusRadius = 14
	d.FocusDistance = 30
	d.Parent = Lighting
	dof = d
	onGrade({ preset = "normal", seconds = 0 })
	-- figurantes/nomes
	for _, child in Workspace:GetChildren() do
		watchModel(child)
	end
	table.insert(conns, Workspace.ChildAdded:Connect(function(child)
		task.defer(watchModel, child)
	end))
end

local function finish()
	if not active then
		return
	end
	active = false
	hideHumanoids = false
	stopShot()
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	for m in frozen do
		unfreezeModel(m)
	end
	for m in hiddenModels do
		if m.Parent then
			setModelVisible(m, true)
		end
	end
	table.clear(hiddenModels)
	for h, v in savedNameDisplay do
		if h.Parent then
			h.DisplayDistanceType = v
		end
	end
	table.clear(savedNameDisplay)
	for bb, v in savedBillboards do
		if bb.Parent then
			bb.Enabled = v
		end
	end
	table.clear(savedBillboards)
	for id, p in portals do
		p.conn:Disconnect()
		for _, part in p.parts do
			part:Destroy()
		end
		portals[id] = nil
	end
	if arrowConn then
		arrowConn:Disconnect()
		arrowConn = nil
	end
	arrowModel = nil
	stopArrowHum()
	for _, d in Workspace:GetDescendants() do
		if d:IsA("ParticleEmitter") and d:GetAttribute("TrailerTS") ~= nil then
			d.TimeScale = tonumber(d:GetAttribute("TrailerTS")) or 1
			d:SetAttribute("TrailerTS", nil)
		end
	end
	if props then
		props:Destroy()
		props = nil
	end
	for _, e: Instance? in { cc :: Instance?, bloom :: Instance?, dof :: Instance? } do
		if e then
			e:Destroy()
		end
	end
	cc, bloom, dof = nil, nil, nil
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = savedCameraType
		camera.FieldOfView = savedFov
	end
	for _, g in hiddenGuis do
		if g.Parent then
			g.Enabled = true
		end
	end
	table.clear(hiddenGuis)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	pcall(function()
		RunService:UnbindFromRenderStep("TrailerCursor")
	end)
	UserInputService.MouseIconEnabled = savedMouseIcon
	if gui then
		gui:Destroy()
		gui = nil
	end
	stage, fadeFrame, flashFrame, countLabel = nil, nil, nil, nil
end

local handlers: { [string]: (data: any) -> () } = {
	shot = onShot,
	title = onTitle,
	grade = onGrade,
	flash = onFlash,
	impact = onImpact,
	punch = onPunch,
	freeze = onFreeze,
	timestop = onTimeStop,
	portal = onPortal,
	arrow = onArrow,
	roulette = onRoulette,
	menacing = onMenacing,
	logo = onLogo,
	tbc = onTbc,
	hold = function()
		stopShot()
	end,
	countdown = function(data)
		local l = countLabel
		if l then
			l.Text = if data.n and tonumber(data.n) and tonumber(data.n) > 0 then tostring(data.n) else ""
		end
	end,
	fade = function(data)
		local f = fadeFrame
		if f then
			tween(f, tonumber(data.seconds) or 1, { BackgroundTransparency = if tonumber(data.to) == 1 then 0 else 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		end
	end,
	anim = function(data)
		local m = findModel(data.model)
		local key = tostring(data.key or "")
		local folder, name = key:match("^(.-)/(.+)$")
		if not m or not folder or not name then
			return
		end
		if data.stop then
			FX.StopAnimation(m, folder, name)
		else
			FX.PlayAnimation(m, folder, name)
		end
	end,
	vfx = function(data)
		local m = findModel(data.model)
		local key = tostring(data.key or "")
		local folder, name = key:match("^(.-)/(.+)$")
		if not m or not folder or not name then
			return
		end
		FX.SpawnVFX(m, folder, name, true, if typeof(data.at) == "Vector3" then data.at else nil)
	end,
	sound = function(data)
		playSound(tostring(data.key or ""), findModel(data.model))
	end,
	stand = function(data)
		local m = findModel(data.model)
		if not m then
			return
		end
		local id = m:GetAttribute("CharacterId")
		local charId = if typeof(id) == "string" then id else "Jotaro"
		local aw = AwakeningDefs.Get(charId)
		local def = CharacterDefs.Get(charId)
		local color = aw.Color or (def and def.Color) or Color3.fromRGB(200, 200, 255)
		StandSilhouette.Show(m, color, tonumber(data.seconds) or 3, { punch = data.punch == true, rate = tonumber(data.rate) or 0.1, style = aw.Stand, scale = tonumber(data.scale) })
	end,
}

--- Roda um evento do trailer SÓ neste cliente (mesmo formato do NotifyTrailer): intro do pré-lançamento
--- (IntroController). "begin" com hideHumanoids = true esconde todos os personagens/NPCs só nesta tela.
function TrailerController.Dispatch(event: string, data: any?)
	local d = if typeof(data) == "table" then data else {}
	if event == "begin" then
		begin(d)
		return
	elseif event == "end" then
		finish()
		return
	end
	local h = handlers[event]
	if active and h then
		local ok, err = pcall(function()
			h(d)
		end)
		if not ok then
			warn(("[TrailerController] %s: %s"):format(event, tostring(err)))
		end
	end
end

function TrailerController.IsActive(): boolean
	return active
end

function TrailerController.Start()
	Remotes.GetEvent(Remotes.Events.NotifyTrailer).OnClientEvent:Connect(function(event: string, data: any)
		data = if typeof(data) == "table" then data else {}
		if event == "begin" then
			begin(data)
			localPlayer:SetAttribute("TrailerWatching", true) -- CutsceneController: efeitos de "quem assiste" mesmo longe
			return
		elseif event == "end" then
			finish()
			localPlayer:SetAttribute("TrailerWatching", nil)
			return
		end
		if not active then
			return
		end
		local h = handlers[event]
		if h then
			local ok, err = pcall(function()
				h(data)
			end)
			if not ok then
				warn(("[TrailerController] %s: %s"):format(event, tostring(err)))
			end
		end
	end)
	Log.debug("[TrailerController] pronto")
end

return TrailerController
