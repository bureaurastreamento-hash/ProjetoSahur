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
			rig.original[d.Name] = d.C0
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
-- Despertar
-- ---------------------------------------------------------------------------

local activeByCharacter: { [Model]: { cancel: () -> () } } = {}

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
	local color = (def and def.Color) or GOLD
	local isMe = character == localPlayer.Character
	local rig = captureRig(character)
	local camera = Workspace.CurrentCamera
	local alive = true
	local steps: { thread } = {}
	local stopCharge: (() -> ())? = nil

	local function at(t: number, fn: () -> ())
		table.insert(steps, task.delay(t, function()
			if alive then
				fn()
			end
		end))
	end

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
		if isMe then
			humanoid.AutoRotate = savedAutoRotate
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			if camera and cameraBusy then
				releaseCamera()
				camera.CameraType = savedCameraType
				camera.FieldOfView = savedFov
			end
		end
	end
	activeByCharacter[character] = { cancel = finish }

	-- Morreu/trocou de personagem no meio: desfaz tudo
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

	-- t = 0: começa a carga
	if isMe then
		humanoid.AutoRotate = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		if camera then
			camera.CameraType = Enum.CameraType.Scriptable
			-- plano aberto de lado/trás; órbita lenta até a frente durante a carga (segue o root a cada frame)
			takeCamera(root, { offset = Vector3.new(4, 0.5, 8), look = Vector3.new(0, 1.5, 0), fov = 70 })
			cameraShot({ offset = Vector3.new(-4.5, 1.8, -6.5), look = Vector3.new(0, 0.8, 0), fov = 60 }, burstAt * 0.68, Enum.EasingStyle.Sine)
		end
	end
	-- Sons: início em t=0, carga (loop, se a equipe colar o id em Sounds.Shared.Awakening_Charge) até o
	-- estouro, estouro em BurstAt, fim quando o modo acaba (AbilityController).
	if not FX.PlaySoundAt(character, characterId, "Awakening") then
		FX.PlaySoundAt(character, SHARED, "Awakening")
	end
	stopCharge = FX.PlaySoundAtStoppable(character, characterId, "Awakening_Charge")
		or FX.PlaySoundAtStoppable(character, SHARED, "Awakening_Charge")
	FX.SetOutline(character, color)
	FX.SetAura(character, color, "AwakenCharge")
	FX.SpawnVFX(character, SHARED, "Awakening_Charge", true)
	if rig then
		applyPose(rig, POSE_CHARGE_1, 0.35)
	end

	-- carga crescendo (tempos proporcionais ao BurstAt: com 5 s → 1,6 s / 3,4 s)
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
			-- close no rosto, acelerando até o estouro
			cameraShot({ offset = Vector3.new(-1.2, 1.2, -3.6), look = Vector3.new(0, 1.2, 0), fov = 50 }, burstAt * 0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end)

	-- ESTOURO
	at(burstAt, function()
		if rig then
			applyPose(rig, POSE_BURST, 0.12, Enum.EasingStyle.Back)
		end
		if stopCharge then
			stopCharge()
			stopCharge = nil
		end
		FX.SetAura(character, nil, "AwakenCharge")
		FX.Flash(character, Color3.new(1, 1, 1), 0.35)
		FX.SpawnVFX(character, SHARED, "Awakening_Burst", true)
		FX.SpawnVFX(character, characterId, "Awakening", false) -- aura do modo (segue o personagem)
		if not FX.PlaySoundAt(character, characterId, "Awakening_Burst") then
			FX.PlaySoundAt(character, SHARED, "Awakening_Burst")
		end
		FX.SetOutline(character, GOLD)
		if isMe then
			FX.Shake(1.2, 0.5)
			if camera then
				-- corte para a frente, baixo, e recua com o impacto
				cameraShot({ offset = Vector3.new(0, 2.5, -9), look = Vector3.new(0, 1, 0), fov = 78 }, 0)
				cameraShot({ offset = Vector3.new(1.5, 3, -13), look = Vector3.new(0, 1, 0), fov = 64 }, 0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
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
			-- órbita lenta em volta da pose despertada
			cameraShot({ offset = Vector3.new(-3.5, 2.5, -11), look = Vector3.new(0, 1.2, 0), fov = 62 }, math.max(total - burstAt - 1.5, 0.3), Enum.EasingStyle.Sine)
		end
	end)
	at(math.max(total - 0.45, burstAt + 0.6), function()
		if isMe and camera then
			-- volta suave para trás do personagem (a câmera padrão assume no fim)
			cameraShot({ offset = Vector3.new(0, 4, 11), look = Vector3.new(0, 1.5, 0), fov = savedFov }, 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
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
