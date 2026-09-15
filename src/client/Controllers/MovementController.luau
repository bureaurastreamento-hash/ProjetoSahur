--!strict
--[[
	MovementController (cliente)
	  - Correr: segurar Shift esquerdo (gamepad L3; mobile botão CORRER) -> RequestSprint.
	  - Shift lock na tecla Ctrl esquerdo, implementado aqui (mouse travado no centro, personagem
	    vira com a câmera, ombro deslocado). O nativo está desligado no project.json
	    (StarterPlayer.EnableMouseLockOption = false) para o Shift ficar livre para correr.
	  - Animações de movimento da equipe (Assets.Animations.Shared.Idle/Walk/Run) tocadas por
	    nós mesmos com prioridade Movement, por cima do script "Animate" padrão (que fica só
	    com pulo/queda). Assim funciona mesmo se o place trocar/remover o Animate.
	    Diagnóstico: se a track carrega com Length 0, avisa no Output (id não é da conta dona
	    do jogo ou foi feita para outro rig).
	API: MovementController.SetSprint(active) (mobile).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local Assets = require(Modules:WaitForChild("Assets"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))

local MovementController = {}

local localPlayer = Players.LocalPlayer
local SPRINT_KEY = Enum.KeyCode.LeftShift
local SPRINT_GAMEPAD = Enum.KeyCode.ButtonL3
local SHIFTLOCK_KEY = Enum.KeyCode.LeftControl
local SHARED = "Shared"
local MOVE_THRESHOLD = 0.5 -- studs/s a partir do qual conta como andando

local requestSprint: RemoteEvent
local sprintHeld = false

-- ---------------------------------------------------------------------------
-- Animações de movimento
-- ---------------------------------------------------------------------------

type MoveAnims = {
	humanoid: Humanoid,
	tracks: { [string]: AnimationTrack },
	current: string?, -- "Idle" | "Walk" | "Run"
	grounded: boolean,
	moving: boolean,
	connections: { RBXScriptConnection },
}

local anims: MoveAnims? = nil

local function loadTrack(animator: Animator, name: string): AnimationTrack?
	local anim = Assets.GetAnimation(SHARED, name)
	if not anim then
		return nil
	end
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok then
		warn(("[MovementController] não carregou Animations.Shared.%s (%s): %s"):format(name, anim.AnimationId, tostring(track)))
		return nil
	end
	track.Priority = Enum.AnimationPriority.Movement
	track.Looped = true
	return track
end

local function play(name: string)
	local a = anims
	if not a or a.current == name then
		return
	end
	for other, track in a.tracks do
		if other ~= name and track.IsPlaying then
			track:Stop(0.15)
		end
	end
	a.current = name
	local track = a.tracks[name] or (name == "Run" and a.tracks.Walk) or nil
	if track then
		track:Play(0.15)
	end
end

local function stopAll()
	local a = anims
	if not a then
		return
	end
	for _, track in a.tracks do
		if track.IsPlaying then
			track:Stop(0.1)
		end
	end
	a.current = nil
end

local function update()
	local a = anims
	if not a then
		return
	end
	if not a.grounded then
		stopAll() -- pulo/queda: deixa o Animate padrão mostrar
		return
	end
	if a.moving then
		play(if localPlayer:GetAttribute("Sprinting") == true then "Run" else "Walk")
	else
		play("Idle")
	end
end

local function teardown()
	local a = anims
	if not a then
		return
	end
	for _, c in a.connections do
		c:Disconnect()
	end
	stopAll()
	anims = nil
end

local function setup(character: Model)
	teardown()
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5) :: Animator?
	if not animator then
		return
	end
	local a: MoveAnims = {
		humanoid = humanoid,
		tracks = {},
		current = nil,
		grounded = humanoid.FloorMaterial ~= Enum.Material.Air,
		moving = false,
		connections = {},
	}
	for _, name in { "Idle", "Walk", "Run" } do
		local track = loadTrack(animator, name)
		if track then
			a.tracks[name] = track
		end
	end
	anims = a
	if next(a.tracks) == nil then
		Log.debug("[MovementController] sem animações de movimento (ids vazios); Animate padrão segue")
		return
	end

	table.insert(a.connections, humanoid.Running:Connect(function(speed: number)
		a.moving = speed > MOVE_THRESHOLD
		update()
	end))
	table.insert(a.connections, humanoid.StateChanged:Connect(function(_, new: Enum.HumanoidStateType)
		a.grounded = new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.RunningNoPhysics or new == Enum.HumanoidStateType.Landed
		update()
	end))
	update()

	-- Diagnóstico: track que carrega com Length 0 = asset não autorizado ou rig diferente
	task.delay(3, function()
		if anims ~= a then
			return
		end
		for name, track in a.tracks do
			if track.Length <= 0 then
				warn(("[MovementController] Animations.Shared.%s (%s) carregou com duração 0: a animação não é da conta/grupo dono do jogo ou foi feita para outro rig (jogo é %s)"):format(
					name, track.Animation and track.Animation.AnimationId or "?", humanoid.RigType.Name))
			end
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Shift lock próprio no Ctrl (o nativo está desligado: StarterPlayer.EnableMouseLockOption=false)
-- ---------------------------------------------------------------------------

local shiftLock = false
local shiftLockConn: RBXScriptConnection? = nil
local SHIFTLOCK_OFFSET = Vector3.new(1.75, 0, 0)

local function applyShiftLock(active: boolean)
	shiftLock = active
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if shiftLockConn then
		shiftLockConn:Disconnect()
		shiftLockConn = nil
	end
	if not active then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		if humanoid then
			humanoid.AutoRotate = true
			humanoid.CameraOffset = Vector3.zero
		end
		return
	end
	shiftLockConn = RunService.RenderStepped:Connect(function()
		local char = localPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hum or not root or hum.Health <= 0 then
			return
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		hum.AutoRotate = false
		hum.CameraOffset = SHIFTLOCK_OFFSET
		local look = Workspace.CurrentCamera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
		end
	end)
end

local function toggleShiftLock()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return
	end
	applyShiftLock(not shiftLock)
end

-- ---------------------------------------------------------------------------
-- Correr
-- ---------------------------------------------------------------------------

function MovementController.SetSprint(active: boolean)
	if sprintHeld == active then
		return
	end
	sprintHeld = active
	requestSprint:FireServer(active)
end

local function onInputBegan(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == SPRINT_KEY or input.KeyCode == SPRINT_GAMEPAD then
		MovementController.SetSprint(true)
	elseif input.KeyCode == SHIFTLOCK_KEY then
		toggleShiftLock()
	end
end

local function onInputEnded(input: InputObject)
	if input.KeyCode == SPRINT_KEY or input.KeyCode == SPRINT_GAMEPAD then
		MovementController.SetSprint(false)
	end
end

function MovementController.Start()
	requestSprint = Remotes.GetEvent(Remotes.Events.RequestSprint)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	localPlayer:GetAttributeChangedSignal("Sprinting"):Connect(function()
		local a = anims
		if a then
			a.current = nil -- força trocar Walk <-> Run
			update()
		end
	end)
	localPlayer.CharacterAdded:Connect(function(character)
		sprintHeld = false
		setup(character)
		if shiftLock then
			applyShiftLock(true) -- reaplica no personagem novo
		end
		if UserInputService:IsKeyDown(SPRINT_KEY) then
			MovementController.SetSprint(true)
		end
	end)
	if localPlayer.Character then
		task.spawn(setup, localPlayer.Character)
	end
	Log.debug(("[MovementController] pronto (Shift corre a %d, Ctrl = shift lock)"):format(CombatConfig.Sprint.Speed))
end

return MovementController
