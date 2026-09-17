--!strict
--[[
	CutsceneController (cliente)
	Cutscenes curtas feitas por código: câmera, poses procedurais nas juntas R6 (Motor6D.C0), VFX, sons,
	tela. Hoje: o DESPERTAR (G) — o personagem para, carrega, ESTOURA e volta transformado.
	Quem despertou vê a câmera cinematográfica; os outros veem só o corpo/efeitos (câmera livre).
	O servidor já travou o jogador (Stun + WalkSpeed 0 + i-frames) pelo tempo da cutscene.

	API: CutsceneController.PlayAwakening(character, characterId, data { Cutscene, BurstAt })
	     CutsceneController.IsPlaying() -> bool (câmera tomada)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local FX = require(Modules:WaitForChild("FX"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local RigPose = require(Modules:WaitForChild("RigPose"))

local CutsceneController = {}

local localPlayer = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 200, 80)
local SHARED = "Shared"

-- ---------------------------------------------------------------------------
-- Poses procedurais (R6). Rotação em radianos no espaço do Torso/HRP em volta do pivô da junta;
-- Offset em studs (só faz sentido no RootJoint = corpo inteiro). Eixos: X direita, Y cima, Z trás.
-- ---------------------------------------------------------------------------

type JointPose = { rot: Vector3?, offset: Vector3? }
type Pose = { [string]: JointPose }

type Rig = {
	joints: { [string]: Motor6D },
	original: { [string]: CFrame },
	tweens: { Tween },
}

local JOINTS = { "RootJoint", "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" }

local function captureRig(character: Model): Rig?
	local rig: Rig = { joints = {}, original = {}, tweens = {} }
	local found = 0
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and table.find(JOINTS, d.Name) then
			rig.joints[d.Name] = d
			rig.original[d.Name] = RigPose.Original(d) -- mesmo "de fábrica" das animações procedurais
			found += 1
		end
	end
	return if found >= 4 then rig else nil
end

local function cancelTweens(rig: Rig)
	for _, t in rig.tweens do
		t:Cancel()
	end
	table.clear(rig.tweens)
end

--- Leva as juntas até a pose em `seconds` (juntas sem entrada voltam ao original).
local function applyPose(rig: Rig, pose: Pose, seconds: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	cancelTweens(rig)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	for name, joint in rig.joints do
		local orig = rig.original[name]
		local jp = pose[name]
		local target = orig
		if jp then
			local pivot = orig.Position
			local rot = jp.rot or Vector3.zero
			local off = jp.offset or Vector3.zero
			target = CFrame.new(off) * CFrame.new(pivot) * CFrame.fromEulerAnglesXYZ(rot.X, rot.Y, rot.Z) * CFrame.new(-pivot) * orig
		end
		local tween = TweenService:Create(joint, info, { C0 = target })
		tween:Play()
		table.insert(rig.tweens, tween)
	end
end

local function restoreRig(rig: Rig, seconds: number)
	applyPose(rig, {}, seconds)
end

local R = math.rad

-- Poses do despertar. Braços: rot.X > 0 = para a frente; rot.Z = abrir para o lado (direito +, esquerdo -).
local POSE_CHARGE_1: Pose = {
	RootJoint = { offset = Vector3.new(0, -0.35, 0), rot = Vector3.new(R(-12), 0, 0) },
	Neck = { rot = Vector3.new(R(-18), 0, 0) },
	["Right Shoulder"] = { rot = Vector3.new(R(-25), 0, R(12)) },
	["Left Shoulder"] = { rot = Vector3.new(R(-25), 0, R(-12)) },
	["Right Hip"] = { rot = Vector3.new(0, 0, R(14)) },
	["Left Hip"] = { rot = Vector3.new(0, 0, R(-14)) },
}
local POSE_CHARGE_2: Pose = {
	RootJoint = { offset = Vector3.new(0, -0.55, 0), rot = Vector3.new(R(-20), 0, 0) },
	Neck = { rot = Vector3.new(R(-28), 0, 0) },
	["Right Shoulder"] = { rot = Vector3.new(R(-40), 0, R(20)) },
	["Left Shoulder"] = { rot = Vector3.new(R(-40), 0, R(-20)) },
	["Right Hip"] = { rot = Vector3.new(0, 0, R(20)) },
	["Left Hip"] = { rot = Vector3.new(0, 0, R(-20)) },
}
local POSE_CHARGE_3: Pose = {
	RootJoint = { offset = Vector3.new(0, -0.3, 0), rot = Vector3.new(R(-8), 0, 0) },
	Neck = { rot = Vector3.new(R(10), 0, 0) },
	["Right Shoulder"] = { rot = Vector3.new(R(-15), 0, R(35)) },
	["Left Shoulder"] = { rot = Vector3.new(R(-15), 0, R(-35)) },
	["Right Hip"] = { rot = Vector3.new(0, 0, R(18)) },
	["Left Hip"] = { rot = Vector3.new(0, 0, R(-18)) },
}
local POSE_BURST: Pose = {
	RootJoint = { offset = Vector3.new(0, 0.45, 0), rot = Vector3.new(R(12), 0, 0) },
	Neck = { rot = Vector3.new(R(25), 0, 0) },
	["Right Shoulder"] = { rot = Vector3.new(R(35), 0, R(80)) },
	["Left Shoulder"] = { rot = Vector3.new(R(35), 0, R(-80)) },
	["Right Hip"] = { rot = Vector3.new(0, 0, R(10)) },
	["Left Hip"] = { rot = Vector3.new(0, 0, R(-10)) },
}
local POSE_STANCE: Pose = {
	RootJoint = { rot = Vector3.new(R(-4), 0, 0) },
	Neck = { rot = Vector3.new(R(4), 0, 0) },
	["Right Shoulder"] = { rot = Vector3.new(R(55), 0, R(15)) },
	["Left Shoulder"] = { rot = Vector3.new(R(70), 0, R(-25)) },
	["Right Hip"] = { rot = Vector3.new(0, 0, R(8)) },
	["Left Hip"] = { rot = Vector3.new(0, 0, R(-8)) },
}

-- ---------------------------------------------------------------------------
-- Câmera (só para quem despertou). Os "planos" são RELATIVOS ao HRP e recalculados a cada frame
-- (RenderStepped), então se o personagem estiver no ar/caindo a câmera vai junto — nunca perde o quadro.
-- ---------------------------------------------------------------------------

local RunService = game:GetService("RunService")

type Shot = { offset: Vector3, look: Vector3, fov: number }

local cameraBusy = false
local cameraConn: RBXScriptConnection? = nil
local shotFrom: Shot? = nil
local shotTo: Shot? = nil
local shotStart = 0
local shotDuration = 0
local shotStyle = Enum.EasingStyle.Quad
local shotDirection = Enum.EasingDirection.InOut
local shotRoot: BasePart? = nil

function CutsceneController.IsPlaying(): boolean
	return cameraBusy
end

--- CFrame de câmera relativo ao HRP (frente = -Z) olhando para um ponto relativo.
local function camAt(root: BasePart, offset: Vector3, lookOffset: Vector3): CFrame
	local pos = root.CFrame:PointToWorldSpace(offset)
	local look = root.CFrame:PointToWorldSpace(lookOffset)
	return CFrame.lookAt(pos, look)
end

local function currentShot(): Shot?
	if not shotTo then
		return nil
	end
	if not shotFrom or shotDuration <= 0 then
		return shotTo
	end
	local alpha = math.clamp((os.clock() - shotStart) / shotDuration, 0, 1)
	alpha = TweenService:GetValue(alpha, shotStyle, shotDirection)
	return {
		offset = shotFrom.offset:Lerp(shotTo.offset, alpha),
		look = shotFrom.look:Lerp(shotTo.look, alpha),
		fov = shotFrom.fov + (shotTo.fov - shotFrom.fov) * alpha,
	}
end

local function renderCamera()
	local camera = Workspace.CurrentCamera
	local root = shotRoot
	local shot = currentShot()
	if not camera or not root or not shot then
		return
	end
	camera.CFrame = camAt(root, shot.offset, shot.look)
	camera.FieldOfView = shot.fov
end

--- Corta (seconds = 0) ou vai suavemente até o plano `to` a partir de onde a câmera está agora.
local function cameraShot(to: Shot, seconds: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	shotFrom = if seconds > 0 then currentShot() else nil
	shotTo = to
	shotStart = os.clock()
	shotDuration = seconds
	shotStyle = style or Enum.EasingStyle.Quad
	shotDirection = direction or Enum.EasingDirection.InOut
	renderCamera()
end

local function takeCamera(root: BasePart, first: Shot)
	shotRoot = root
	shotFrom = nil
	shotTo = nil
	if cameraConn then
		cameraConn:Disconnect()
	end
	cameraConn = RunService.RenderStepped:Connect(renderCamera)
	cameraBusy = true
	cameraShot(first, 0)
end

local function releaseCamera()
	if cameraConn then
		cameraConn:Disconnect()
		cameraConn = nil
	end
	shotRoot = nil
	shotFrom = nil
	shotTo = nil
	cameraBusy = false
end

-- ---------------------------------------------------------------------------
-- Tela (barras de cinema, vinheta, flash, nome da ult) — ScreenGui criado por código
-- ---------------------------------------------------------------------------
local Lighting = game:GetService("Lighting")
local AwakeningDefs = require(Modules:WaitForChild("AwakeningDefs"))

local screenGui: ScreenGui? = nil
local barTop: Frame
local barBottom: Frame
local vignette: { Frame } = {}
local flashFrame: Frame
local ultLabel: TextLabel
local subLabel: TextLabel

local function ensureScreen(): ScreenGui
	if screenGui and screenGui.Parent then
		return screenGui
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CutsceneGui"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	local function bar(name: string, anchorY: number, posY: number): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.new(0, 0, posY, 0)
		f.Size = UDim2.new(1, 0, 0, 0)
		f.ZIndex = 5
		f.Parent = gui
		return f
	end
	barTop = bar("BarTop", 0, 0)
	barBottom = bar("BarBottom", 1, 1)
	-- vinheta: 3 anéis redondos (frames circulares maiores que a tela com UIStroke grosso preto) —
	-- cada anel um pouco menor e mais transparente = escurece os cantos com degradê em degraus
	vignette = {}
	for i = 1, 5 do
		local f = Instance.new("Frame")
		f.Name = "Vignette" .. i
		f.BackgroundTransparency = 1
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		local scale = 1.3 + (i - 1) * 0.16
		f.Size = UDim2.fromScale(scale, scale)
		f.ZIndex = 2
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 1.25
		ratio.Parent = f
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Ring"
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 900
		stroke.Transparency = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = f
		f.Parent = gui
		table.insert(vignette, f)
	end
	flashFrame = Instance.new("Frame")
	flashFrame.Name = "Flash"
	flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	flashFrame.BorderSizePixel = 0
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundTransparency = 1
	flashFrame.ZIndex = 8
	flashFrame.Parent = gui
	ultLabel = Instance.new("TextLabel")
	ultLabel.Name = "UltName"
	ultLabel.BackgroundTransparency = 1
	ultLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	ultLabel.Position = UDim2.fromScale(0.5, 0.78)
	ultLabel.Size = UDim2.fromScale(1, 0.14)
	ultLabel.Font = Enum.Font.GothamBlack
	ultLabel.TextScaled = true
	ultLabel.TextColor3 = Color3.new(1, 1, 1)
	ultLabel.TextStrokeTransparency = 0.2
	ultLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	ultLabel.TextTransparency = 1
	ultLabel.ZIndex = 9
	ultLabel.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Scale = 1
	scale.Parent = ultLabel
	subLabel = Instance.new("TextLabel")
	subLabel.Name = "UltSub"
	subLabel.BackgroundTransparency = 1
	subLabel.AnchorPoint = Vector2.new(0.5, 0)
	subLabel.Position = UDim2.fromScale(0.5, 0.855)
	subLabel.Size = UDim2.fromScale(1, 0.035)
	subLabel.Font = Enum.Font.GothamMedium
	subLabel.TextScaled = true
	subLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
	subLabel.TextStrokeTransparency = 0.5
	subLabel.TextTransparency = 1
	subLabel.ZIndex = 9
	subLabel.Parent = gui
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	screenGui = gui
	return gui
end

local function tween(inst: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function setLetterbox(on: boolean, seconds: number)
	ensureScreen()
	local h = if on then 0.11 else 0
	tween(barTop, seconds, { Size = UDim2.new(1, 0, h, 0) }, Enum.EasingStyle.Quart)
	tween(barBottom, seconds, { Size = UDim2.new(1, 0, h, 0) }, Enum.EasingStyle.Quart)
end

local function setVignette(strength: number, seconds: number)
	ensureScreen()
	for i, f in vignette do
		local ring = f:FindFirstChild("Ring") :: UIStroke
		tween(ring, seconds, { Transparency = 1 - strength * (0.34 - (i - 1) * 0.06) })
	end
end

-- HUD/topbar somem durante a cena de quem despertou (como no trailer); voltam no fim
local StarterGui = game:GetService("StarterGui")
local hiddenGuis: { ScreenGui } = {}
local function hideHud()
	table.clear(hiddenGuis)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	for _, g in localPlayer:WaitForChild("PlayerGui"):GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "CutsceneGui" then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
	end
end
local function showHud()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)
	for _, g in hiddenGuis do
		if g.Parent then
			g.Enabled = true
		end
	end
	table.clear(hiddenGuis)
end

local function screenFlash(color: Color3, peak: number, seconds: number)
	ensureScreen()
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 1 - peak
	tween(flashFrame, seconds, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

--- Nome da ult: entra com "soco" (escala 1,6 → 1) e some depois de `hold` s.
local function showUltName(name: string, subtitle: string?, color: Color3, hold: number, small: boolean?)
	ensureScreen()
	ultLabel.Text = name
	ultLabel.TextColor3 = color
	ultLabel.Size = if small then UDim2.fromScale(1, 0.08) else UDim2.fromScale(1, 0.14)
	subLabel.Text = subtitle or ""
	local scale = ultLabel:FindFirstChild("Scale") :: UIScale
	scale.Scale = 1.7
	ultLabel.TextTransparency = 0
	ultLabel.TextStrokeTransparency = 0.2
	tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	subLabel.TextTransparency = 1
	subLabel.TextStrokeTransparency = 1
	task.delay(0.18, function()
		tween(subLabel, 0.3, { TextTransparency = 0, TextStrokeTransparency = 0.5 })
	end)
	task.delay(hold, function()
		tween(ultLabel, 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
		tween(subLabel, 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
end

-- Pós-processo por cliente (ColorCorrection/Bloom criados por código; removidos no fim)
local ccEffect: ColorCorrectionEffect? = nil
local bloomEffect: BloomEffect? = nil
local postToken = 0
local function post(): (ColorCorrectionEffect, BloomEffect)
	if not (ccEffect and ccEffect.Parent) then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "CutsceneColor"
		cc.Saturation = 0
		cc.Contrast = 0
		cc.Brightness = 0
		cc.TintColor = Color3.new(1, 1, 1)
		cc.Parent = Lighting
		ccEffect = cc
	end
	if not (bloomEffect and bloomEffect.Parent) then
		local b = Instance.new("BloomEffect")
		b.Name = "CutsceneBloom"
		b.Intensity = 0
		b.Size = 24
		b.Threshold = 1.2
		b.Parent = Lighting
		bloomEffect = b
	end
	return ccEffect :: ColorCorrectionEffect, bloomEffect :: BloomEffect
end
local function clearPost(seconds: number)
	postToken += 1
	local token = postToken
	local cc, bloom = ccEffect, bloomEffect
	if cc then
		tween(cc, seconds, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
	end
	if bloom then
		tween(bloom, seconds, { Intensity = 0 })
	end
	task.delay(seconds + 0.1, function()
		if postToken == token then
			if cc then
				cc:Destroy()
			end
			if bloom then
				bloom:Destroy()
			end
			ccEffect = nil
			bloomEffect = nil
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Temas do "mundo reagindo" (peças anchored só no cliente, numa pasta por cena)
-- ---------------------------------------------------------------------------
type ThemeCtx = { character: Model, root: BasePart, color: Color3, folder: Folder, burstAt: number, total: number, alive: () -> boolean, rng: Random }
type Theme = { charge: (ThemeCtx) -> (), burst: (ThemeCtx) -> () }

local function part(folder: Folder, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder
	return p
end

local function groundY(root: BasePart): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent :: Instance }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	return if hit then hit.Position.Y else root.Position.Y - 3
end

--- Peças que sobem e orbitam durante a carga e voam no estouro (base de rock/stone/flesh/arcane).
local function levitate(ctx: ThemeCtx, count: number, make: (i: number) -> Part, radius: number, rise: number)
	local items: { { p: Part, angle: number, r: number, h: number, spin: Vector3, speed: number } } = {}
	local gy = groundY(ctx.root)
	for i = 1, count do
		local p = make(i)
		local angle = (i / count) * math.pi * 2 + ctx.rng:NextNumber(-0.4, 0.4)
		local r = radius * ctx.rng:NextNumber(0.6, 1.2)
		p.CFrame = CFrame.new(ctx.root.Position.X + math.cos(angle) * r, gy - 1, ctx.root.Position.Z + math.sin(angle) * r)
		table.insert(items, { p = p, angle = angle, r = r, h = ctx.rng:NextNumber(0.4, 1), spin = Vector3.new(ctx.rng:NextNumber(-2, 2), ctx.rng:NextNumber(-2, 2), ctx.rng:NextNumber(-2, 2)), speed = ctx.rng:NextNumber(0.6, 1.4) })
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.alive() or not ctx.folder.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		local charge = math.clamp(t / ctx.burstAt, 0, 1)
		local center = ctx.root.Position
		for _, it in items do
			it.angle += dt * (0.5 + charge * 2.5) * it.speed
			local y = gy + 0.5 + rise * it.h * math.min(1, t / (ctx.burstAt * 0.8)) + math.sin(t * 2 + it.angle) * 0.3
			local r = it.r * (1 - charge * 0.35)
			local pos = Vector3.new(center.X + math.cos(it.angle) * r, y, center.Z + math.sin(it.angle) * r)
			it.p.CFrame = CFrame.new(pos) * CFrame.fromEulerAnglesXYZ(t * it.spin.X, t * it.spin.Y, t * it.spin.Z)
		end
	end)
	return function()
		-- estouro: voam para fora e somem
		conn:Disconnect()
		for _, it in items do
			local dir = (it.p.Position - ctx.root.Position) * Vector3.new(1, 0, 1)
			dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.xAxis
			local target = it.p.Position + dir * ctx.rng:NextNumber(18, 34) + Vector3.new(0, ctx.rng:NextNumber(4, 12), 0)
			tween(it.p, 0.55, { CFrame = CFrame.new(target) * CFrame.Angles(ctx.rng:NextNumber(0, 3), ctx.rng:NextNumber(0, 3), 0), Transparency = 1 }, Enum.EasingStyle.Quart)
		end
		task.delay(0.7, function()
			for _, it in items do
				it.p:Destroy()
			end
		end)
	end
end

local THEMES: { [string]: Theme } = {}
local burstCleanup: { [Model]: () -> () } = {}

local STONE = Color3.fromRGB(96, 92, 90)
THEMES.rock = {
	charge = function(ctx)
		burstCleanup[ctx.character] = levitate(ctx, 14, function(i)
			local s = ctx.rng:NextNumber(0.7, 2.2)
			return part(ctx.folder, Vector3.new(s, s * ctx.rng:NextNumber(0.6, 1.2), s * ctx.rng:NextNumber(0.6, 1.2)), CFrame.new(), STONE, Enum.Material.Slate)
		end, 7, 6)
	end,
	burst = function(ctx)
		FX.SpawnVFX(ctx.character, "Brawler", "Rampage", true)
	end,
}
THEMES.stone = {
	charge = function(ctx)
		-- 6 pilares sobem em círculo (do chão), tremendo
		local gy = groundY(ctx.root)
		local pillars: { Part } = {}
		for i = 1, 6 do
			local a = (i / 6) * math.pi * 2
			local h = ctx.rng:NextNumber(7, 11)
			local p = part(ctx.folder, Vector3.new(2.2, h, 2.2), CFrame.new(ctx.root.Position.X + math.cos(a) * 9, gy - h / 2 - 0.5, ctx.root.Position.Z + math.sin(a) * 9) * CFrame.Angles(0, -a, 0), STONE, Enum.Material.Slate)
			table.insert(pillars, p)
			task.delay(0.2 + i * 0.35, function()
				if ctx.alive() and p.Parent then
					tween(p, 1.4, { CFrame = p.CFrame + Vector3.new(0, h - 0.5, 0) }, Enum.EasingStyle.Quart)
					FX.Shake(0.25, 0.3)
				end
			end)
		end
		burstCleanup[ctx.character] = function()
			for _, p in pillars do
				local dir = (p.Position - ctx.root.Position) * Vector3.new(1, 0, 1)
				dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.xAxis
				tween(p, 0.6, { CFrame = CFrame.new(p.Position + dir * 14 + Vector3.new(0, 3, 0)) * CFrame.Angles(ctx.rng:NextNumber(-1.2, 1.2), 0, ctx.rng:NextNumber(-1.2, 1.2)), Transparency = 1 }, Enum.EasingStyle.Quart)
			end
			task.delay(0.7, function()
				for _, p in pillars do
					p:Destroy()
				end
			end)
		end
	end,
	burst = function(ctx)
		FX.SpawnVFX(ctx.character, "Guardian", "Quake", true)
	end,
}
THEMES.flesh = {
	charge = function(ctx)
		burstCleanup[ctx.character] = levitate(ctx, 12, function()
			local s = ctx.rng:NextNumber(1, 3)
			return part(ctx.folder, Vector3.new(s, s, s), CFrame.new(), Color3.fromRGB(210, 80, 120), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end, 6, 5)
	end,
	burst = function(ctx)
		FX.SpawnVFX(ctx.character, "BigChop", "Frenzy", true)
	end,
}
THEMES.arcane = {
	charge = function(ctx)
		-- anel de runas (anel achatado girando) + 5 esferas orbitando que convergem no estouro
		local gy = groundY(ctx.root)
		local ring = part(ctx.folder, Vector3.new(0.3, 14, 14), CFrame.new(ctx.root.Position.X, gy + 0.15, ctx.root.Position.Z) * CFrame.Angles(0, 0, math.rad(90)), ctx.color, Enum.Material.Neon, Enum.PartType.Cylinder)
		ring.Transparency = 0.55
		local inner = part(ctx.folder, Vector3.new(0.3, 9, 9), ring.CFrame, Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Cylinder)
		inner.Transparency = 0.75
		local orbs: { Part } = {}
		for i = 1, 5 do
			local o = part(ctx.folder, Vector3.new(1.2, 1.2, 1.2), CFrame.new(), ctx.color, Enum.Material.Neon, Enum.PartType.Ball)
			local l = Instance.new("PointLight")
			l.Color = ctx.color
			l.Range = 8
			l.Brightness = 1.5
			l.Parent = o
			table.insert(orbs, o)
		end
		local t0 = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.Heartbeat:Connect(function()
			if not ctx.alive() or not ctx.folder.Parent then
				conn:Disconnect()
				return
			end
			local t = os.clock() - t0
			local charge = math.clamp(t / ctx.burstAt, 0, 1)
			local c = ctx.root.Position
			ring.CFrame = CFrame.new(c.X, gy + 0.15, c.Z) * CFrame.Angles(0, t * 0.8, 0) * CFrame.Angles(0, 0, math.rad(90))
			inner.CFrame = CFrame.new(c.X, gy + 0.2, c.Z) * CFrame.Angles(0, -t * 1.4, 0) * CFrame.Angles(0, 0, math.rad(90))
			for i, o in orbs do
				local a = t * (1.2 + charge * 4) + i * (math.pi * 2 / 5)
				local r = 6 - charge * 3.5
				o.Position = Vector3.new(c.X + math.cos(a) * r, c.Y + math.sin(t * 2 + i) * 1.2 + 0.5, c.Z + math.sin(a) * r)
			end
		end)
		burstCleanup[ctx.character] = function()
			conn:Disconnect()
			for _, o in orbs do
				tween(o, 0.12, { Position = ctx.root.Position, Size = Vector3.new(0.2, 0.2, 0.2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
			tween(ring, 0.5, { Size = Vector3.new(0.3, 40, 40), Transparency = 1 }, Enum.EasingStyle.Quart)
			tween(inner, 0.4, { Size = Vector3.new(0.3, 26, 26), Transparency = 1 }, Enum.EasingStyle.Quart)
			task.delay(0.7, function()
				ring:Destroy()
				inner:Destroy()
				for _, o in orbs do
					o:Destroy()
				end
			end)
		end
	end,
	burst = function(ctx)
		FX.SpawnVFX(ctx.character, "Mystic", "Meteor", true)
	end,
}
THEMES.lightning = {
	charge = function(ctx)
		-- pós-imagens (cópia translúcida das partes do corpo, deslocada, sumindo) + raios finos do chão
		local gy = groundY(ctx.root)
		local t0 = os.clock()
		local nextGhost = 0.6
		local nextBolt = 0.3
		local conn: RBXScriptConnection
		conn = RunService.Heartbeat:Connect(function()
			if not ctx.alive() or not ctx.folder.Parent then
				conn:Disconnect()
				return
			end
			local t = os.clock() - t0
			if t >= ctx.burstAt then
				conn:Disconnect()
				return
			end
			local charge = t / ctx.burstAt
			if t >= nextGhost then
				nextGhost = t + math.max(0.12, 0.6 - charge * 0.5)
				local offset = ctx.root.CFrame:VectorToWorldSpace(Vector3.new(ctx.rng:NextNumber(-3, 3), 0, ctx.rng:NextNumber(-3, 3)))
				for _, d in ctx.character:GetChildren() do
					if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
						local g = part(ctx.folder, d.Size, d.CFrame + offset, ctx.color, Enum.Material.Neon)
						g.Transparency = 0.6
						tween(g, 0.35, { Transparency = 1 })
						task.delay(0.4, function()
							g:Destroy()
						end)
					end
				end
			end
			if t >= nextBolt then
				nextBolt = t + math.max(0.05, 0.3 - charge * 0.27)
				local a = ctx.rng:NextNumber(0, math.pi * 2)
				local r = ctx.rng:NextNumber(3, 9)
				local from = Vector3.new(ctx.root.Position.X + math.cos(a) * r, gy, ctx.root.Position.Z + math.sin(a) * r)
				local to = ctx.root.Position + Vector3.new(ctx.rng:NextNumber(-1, 1), ctx.rng:NextNumber(-1, 2), ctx.rng:NextNumber(-1, 1))
				local mid = (from + to) / 2 + Vector3.new(ctx.rng:NextNumber(-2, 2), ctx.rng:NextNumber(-1, 3), ctx.rng:NextNumber(-2, 2))
				for _, seg in { { from, mid }, { mid, to } } do
					local len = (seg[2] - seg[1]).Magnitude
					local b = part(ctx.folder, Vector3.new(0.12, 0.12, len), CFrame.lookAt((seg[1] + seg[2]) / 2, seg[2]), Color3.new(1, 1, 1), Enum.Material.Neon)
					task.delay(0.07, function()
						b:Destroy()
					end)
				end
			end
		end)
		burstCleanup[ctx.character] = function()
			conn:Disconnect()
			-- estouro: 10 raios grandes em volta
			for i = 1, 10 do
				local a = (i / 10) * math.pi * 2
				local from = ctx.root.Position + Vector3.new(0, 1, 0)
				local to = from + Vector3.new(math.cos(a) * 16, ctx.rng:NextNumber(-2, 8), math.sin(a) * 16)
				local b = part(ctx.folder, Vector3.new(0.25, 0.25, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), ctx.color, Enum.Material.Neon)
				tween(b, 0.25, { Transparency = 1 })
				task.delay(0.3, function()
					b:Destroy()
				end)
			end
		end
	end,
	burst = function(ctx)
		FX.SpawnVFX(ctx.character, "Swift", "TimeDome", true)
	end,
}
THEMES.drums = {
	charge = function(ctx)
		-- anéis de luz pulsando no ritmo (acelera até o estouro) + som Awakening_Pulse em cada batida
		local gy = groundY(ctx.root)
		local t0 = os.clock()
		local nextBeat = 0
		local conn: RBXScriptConnection
		conn = RunService.Heartbeat:Connect(function()
			if not ctx.alive() or not ctx.folder.Parent then
				conn:Disconnect()
				return
			end
			local t = os.clock() - t0
			if t >= ctx.burstAt then
				conn:Disconnect()
				return
			end
			if t >= nextBeat then
				local charge = t / ctx.burstAt
				nextBeat = t + math.max(0.16, 0.75 - charge * 0.6)
				local c = ctx.root.Position
				local ring = part(ctx.folder, Vector3.new(0.25, 3, 3), CFrame.new(c.X, gy + 0.2, c.Z) * CFrame.Angles(0, 0, math.rad(90)), ctx.color, Enum.Material.Neon, Enum.PartType.Cylinder)
				ring.Transparency = 0.2
				tween(ring, 0.5, { Size = Vector3.new(0.25, 16 + charge * 10, 16 + charge * 10), Transparency = 1 }, Enum.EasingStyle.Quart)
				task.delay(0.55, function()
					ring:Destroy()
				end)
				FX.PlaySoundAt(ctx.character, SHARED, "Awakening_Pulse")
				FX.Flash(ctx.character, ctx.color, 0.12)
				if ctx.character == localPlayer.Character then
					FX.Shake(0.15 + charge * 0.3, 0.12)
				end
			end
		end)
		burstCleanup[ctx.character] = function()
			conn:Disconnect()
		end
	end,
	burst = function(ctx)
		FX.SpawnVFX(ctx.character, "Sahur", "Ritmo", true)
	end,
}
THEMES.void = {
	charge = function(ctx)
		-- esfera escura crescendo em volta (de dentro para fora), o mundo perde a cor
		local sphere = part(ctx.folder, Vector3.new(1, 1, 1), CFrame.new(ctx.root.Position), Color3.fromRGB(20, 6, 30), Enum.Material.Neon, Enum.PartType.Ball)
		sphere.Transparency = 0.55
		tween(sphere, ctx.burstAt, { Size = Vector3.new(22, 22, 22) }, Enum.EasingStyle.Sine)
		local conn: RBXScriptConnection
		conn = RunService.Heartbeat:Connect(function()
			if not ctx.alive() or not ctx.folder.Parent then
				conn:Disconnect()
				return
			end
			sphere.Position = ctx.root.Position
		end)
		burstCleanup[ctx.character] = function()
			conn:Disconnect()
			tween(sphere, 0.15, { Size = Vector3.new(0.5, 0.5, 0.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.16, function()
				sphere.Transparency = 0
				sphere.Color = Color3.new(1, 1, 1)
				tween(sphere, 0.4, { Size = Vector3.new(50, 50, 50), Transparency = 1 }, Enum.EasingStyle.Quart)
				task.delay(0.45, function()
					sphere:Destroy()
				end)
			end)
		end
	end,
	burst = function(ctx)
		FX.SpawnVFX(ctx.character, "Overlord", "Cataclysm", true)
	end,
}

-- ---------------------------------------------------------------------------
-- Despertar
-- ---------------------------------------------------------------------------

local activeByCharacter: { [Model]: { cancel: () -> () } } = {}
local OBSERVER_RANGE = 110 -- a que distância os OUTROS sentem a cena (tela/congelamento)

--- Congela a animação de todo personagem visível (o servidor já travou o movimento) — "o tempo parou".
local function freezeWorld(except: Model, seconds: number, radius: number)
	local root = except:FindFirstChild("HumanoidRootPart") :: BasePart?
	local function inRange(m: Model): boolean
		if radius <= 0 or not root then
			return true
		end
		local r = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		return r ~= nil and (r.Position - root.Position).Magnitude <= radius
	end
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c and c ~= except and inRange(c) then
			FX.Hitstop(c, seconds)
		end
	end
	for _, d in Workspace:GetChildren() do
		if d:IsA("Model") and d ~= except and d:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(d) and inRange(d) then
			FX.Hitstop(d, seconds)
		end
	end
end

function CutsceneController.PlayAwakening(character: Model, characterId: string, data: any)
	local prev = activeByCharacter[character]
	if prev then
		prev.cancel()
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local cut = CombatConfig.Awakening.Cutscene
	local total = if typeof(data) == "table" and typeof(data.Cutscene) == "number" then data.Cutscene else cut.Duration
	local burstAt = if typeof(data) == "table" and typeof(data.BurstAt) == "number" then data.BurstAt else cut.BurstAt
	local def = CharacterDefs.Get(characterId)
	local awDef = AwakeningDefs.Get(characterId)
	local color = awDef.Color or (def and def.Color) or GOLD
	local isMe = character == localPlayer.Character
	local rig = captureRig(character)
	local camera = Workspace.CurrentCamera
	local alive = true
	local steps: { thread } = {}
	local stopCharge: (() -> ())? = nil
	local stopRiser: (() -> ())? = nil
	local function at(t: number, fn: () -> ())
		table.insert(steps, task.delay(t, function()
			if alive then
				fn()
			end
		end))
	end
	local function near(): boolean
		local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return myRoot ~= nil and (myRoot.Position - root.Position).Magnitude <= OBSERVER_RANGE
	end
	local folder = Instance.new("Folder")
	folder.Name = "AwakenFX_" .. character.Name
	folder.Parent = Workspace
	local ctx: ThemeCtx = { character = character, root = root, color = color, folder = folder, burstAt = burstAt, total = total, alive = function()
		return alive
	end, rng = Random.new() }
	local theme = THEMES[awDef.Theme] or THEMES.rock

	local savedAutoRotate = humanoid.AutoRotate
	local savedCameraType = camera and camera.CameraType or Enum.CameraType.Custom
	local savedFov = camera and camera.FieldOfView or 70
	local function finish()
		if not alive then
			return
		end
		alive = false
		activeByCharacter[character] = nil
		for _, th in steps do
			pcall(task.cancel, th)
		end
		if rig then
			restoreRig(rig, 0.25)
			task.delay(0.3, function()
				cancelTweens(rig)
			end)
		end
		FX.SetAura(character, nil, "AwakenCharge")
		if stopCharge then
			stopCharge()
			stopCharge = nil
		end
		if stopRiser then
			stopRiser()
			stopRiser = nil
		end
		local cleanup = burstCleanup[character]
		if cleanup then
			burstCleanup[character] = nil
			cleanup()
		end
		task.delay(1, function()
			folder:Destroy()
		end)
		if isMe then
			humanoid.AutoRotate = savedAutoRotate
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			if camera and cameraBusy then
				releaseCamera()
				camera.CameraType = savedCameraType
				camera.FieldOfView = savedFov
			end
			setLetterbox(false, 0.35)
			setVignette(0, 0.5)
			clearPost(0.6)
			if screenGui then
				tween(ultLabel, 0.2, { TextTransparency = 1, TextStrokeTransparency = 1 })
				tween(subLabel, 0.2, { TextTransparency = 1, TextStrokeTransparency = 1 })
			end
			showHud()
		end
	end
	activeByCharacter[character] = { cancel = finish }
	local diedConn = humanoid.Died:Once(finish)
	local removedConn = character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			finish()
		end
	end)
	at(total + 0.5, function()
		diedConn:Disconnect()
		removedConn:Disconnect()
	end)

	-- ===== t = 0: começa a carga =====
	if isMe then
		humanoid.AutoRotate = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		if camera then
			camera.CameraType = Enum.CameraType.Scriptable
			takeCamera(root, { offset = Vector3.new(4, 0.5, 8), look = Vector3.new(0, 1.5, 0), fov = 70 })
			cameraShot({ offset = Vector3.new(-4.5, 1.8, -6.5), look = Vector3.new(0, 0.8, 0), fov = 60 }, burstAt * 0.68, Enum.EasingStyle.Sine)
		end
		hideHud()
		setLetterbox(true, 0.5)
		setVignette(0.35, 1.0)
		local cc, bloom = post()
		tween(cc, burstAt * 0.9, { Saturation = -0.55, Contrast = 0.15, Brightness = -0.08, TintColor = color:Lerp(Color3.new(1, 1, 1), 0.7) }, Enum.EasingStyle.Sine)
		tween(bloom, burstAt, { Intensity = 0.6 }, Enum.EasingStyle.Sine)
	end
	-- Sons: base + carga em loop subindo (pitch/volume) + riser que estoura junto com o BurstAt
	if not FX.PlaySoundAt(character, characterId, "Awakening") then
		FX.PlaySoundAt(character, SHARED, "Awakening")
	end
	do
		local stopFn, sound = FX.PlaySoundAtControl(character, characterId, "Awakening_Charge")
		if not stopFn then
			stopFn, sound = FX.PlaySoundAtControl(character, SHARED, "Awakening_Charge")
		end
		stopCharge = stopFn
		if sound then
			sound.PlaybackSpeed = 0.75
			tween(sound, burstAt, { PlaybackSpeed = 1.55 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end
	FX.SetOutline(character, color)
	FX.SetAura(character, color, "AwakenCharge")
	FX.SpawnVFX(character, SHARED, "Awakening_Charge", true)
	FX.SpawnVFX(character, characterId, "Awakening_Charge", true) -- versão própria, se existir
	theme.charge(ctx)
	if rig then
		applyPose(rig, POSE_CHARGE_1, 0.35)
	end
	-- riser (4,9 s) alinhado para acabar no estouro
	at(math.max(0, burstAt - 4.7), function()
		stopRiser = FX.PlaySoundAtStoppable(character, SHARED, "Awakening_Riser")
	end)
	-- batidas de coração acelerando nos últimos 1,8 s (menos no tema drums, que já pulsa)
	if awDef.Theme ~= "drums" then
		for _, dt in { 1.8, 1.25, 0.8, 0.45, 0.2 } do
			at(burstAt - dt, function()
				FX.PlaySoundAt(character, SHARED, "Awakening_Pulse")
				FX.Flash(character, color, 0.1)
				if isMe then
					FX.Shake(0.35, 0.1)
					local cc = post()
					cc.Brightness = 0.06
					tween(cc, 0.15, { Brightness = -0.08 })
				end
			end)
		end
	end
	-- carga crescendo
	at(burstAt * 0.32, function()
		if rig then
			applyPose(rig, POSE_CHARGE_2, burstAt * 0.2, Enum.EasingStyle.Sine)
		end
		if isMe then
			FX.Shake(0.2, burstAt * 0.4)
		end
	end)
	at(burstAt * 0.68, function()
		if rig then
			applyPose(rig, POSE_CHARGE_3, burstAt * 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		end
		if isMe then
			FX.Shake(0.7, burstAt * 0.32)
			-- close no rosto (não tão perto: acessórios grandes de cabeça entravam na câmera)
			cameraShot({ offset = Vector3.new(-1.6, 1.4, -5.6), look = Vector3.new(0, 1.3, 0), fov = 46 }, burstAt * 0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			setVignette(0.6, burstAt * 0.32)
		end
	end)

	-- ===== ESTOURO =====
	at(burstAt, function()
		if rig then
			applyPose(rig, POSE_BURST, 0.12, Enum.EasingStyle.Back)
		end
		if stopCharge then
			stopCharge()
			stopCharge = nil
		end
		stopRiser = nil
		FX.SetAura(character, nil, "AwakenCharge")
		FX.Flash(character, Color3.new(1, 1, 1), 0.35)
		FX.SpawnVFX(character, SHARED, "Awakening_Burst", true)
		FX.SpawnVFX(character, characterId, "Awakening_Burst", true)
		FX.SpawnVFX(character, characterId, "Awakening", false) -- aura do modo (segue o personagem)
		theme.burst(ctx)
		local cleanup = burstCleanup[character]
		if cleanup then
			burstCleanup[character] = nil
			cleanup()
		end
		if not FX.PlaySoundAt(character, characterId, "Awakening_Burst") then
			FX.PlaySoundAt(character, SHARED, "Awakening_Burst")
		end
		FX.PlaySoundAt(character, SHARED, "Awakening_Impact")
		task.delay(awDef.VoiceAt or 0.05, function()
			if not FX.PlaySoundAt(character, characterId, "Awakening_Voice") then
				FX.PlaySoundAt(character, SHARED, "Awakening_Voice")
			end
		end)
		FX.SetOutline(character, GOLD)
		-- "o tempo parou": todo mundo em volta congela a animação; a tela de quem vê responde
		local freezeCfg = cut.FreezeByCharacter and cut.FreezeByCharacter[characterId]
		local freeze = if freezeCfg then tonumber(freezeCfg.Seconds) or 0 else 0
		local freezeRadius = if freezeCfg then tonumber(freezeCfg.Radius) or 0 else 0
		if freeze > 0 then
			freezeWorld(character, freeze, freezeRadius)
		end
		if isMe then
			FX.Shake(1.2, 0.5)
			screenFlash(Color3.new(1, 1, 1), 0.95, 0.5)
			local cc, bloom = post()
			cc.Saturation = 0.35
			cc.Contrast = 0.3
			cc.Brightness = 0.12
			cc.TintColor = Color3.new(1, 1, 1)
			bloom.Intensity = 1.6
			tween(cc, 1.2, { Saturation = 0.1, Contrast = 0.08, Brightness = 0 })
			tween(bloom, 1.2, { Intensity = 0.35 })
			setVignette(0.25, 0.4)
			showUltName(awDef.UltName, awDef.Subtitle, color, math.max(0.8, total - burstAt - 0.9)) -- some antes de a HUD voltar
			if camera then
				cameraShot({ offset = Vector3.new(0, 2.5, -9), look = Vector3.new(0, 1, 0), fov = 78 }, 0)
				cameraShot({ offset = Vector3.new(1.5, 3, -13), look = Vector3.new(0, 1, 0), fov = 64 }, 0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			end
		elseif near() then
			-- quem está perto: flash na cor + nome pequeno da ult; se foi congelado (Guardian, raio pequeno),
			-- também perde a cor e ouve o "tempo parou"
			FX.Shake(0.8, 0.4)
			screenFlash(color, 0.55, 0.45)
			showUltName(awDef.UltName, ("%s despertou"):format(character.Name), color, 1.6, true)
			local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local frozen = freeze > 0 and myRoot ~= nil and (freezeRadius <= 0 or (myRoot.Position - root.Position).Magnitude <= freezeRadius)
			if frozen then
				local cc = post()
				cc.Saturation = -0.7
				tween(cc, math.max(freeze, 0.8), { Saturation = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(math.max(freeze, 0.8) + 0.1, function()
					clearPost(0.3)
				end)
				FX.PlaySoundAt(character, SHARED, "Awakening_Freeze")
			end
		end
	end)
	-- pose de guarda e devolve o controle
	at(burstAt + 0.45, function()
		if rig then
			applyPose(rig, POSE_STANCE, 0.45)
		end
	end)
	at(burstAt + 1.0, function()
		if isMe and camera then
			cameraShot({ offset = Vector3.new(-3.5, 2.5, -11), look = Vector3.new(0, 1.2, 0), fov = 62 }, math.max(total - burstAt - 1.5, 0.3), Enum.EasingStyle.Sine)
		end
	end)
	at(math.max(total - 0.45, burstAt + 0.6), function()
		if isMe and camera then
			cameraShot({ offset = Vector3.new(0, 4, 11), look = Vector3.new(0, 1.5, 0), fov = savedFov }, 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			setLetterbox(false, 0.45)
		end
	end)
	at(total, finish)
end

function CutsceneController.Init()
	Players.LocalPlayer.CharacterRemoving:Connect(function(character)
		local a = activeByCharacter[character]
		if a then
			a.cancel()
		end
	end)
end

return CutsceneController
