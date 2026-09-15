--!strict
--[[
	MovementController (cliente)
	  - Correr é AUTOMÁTICO ao andar para a frente (W / analógico para a frente): RequestSprint(true).
	    Para os lados e para trás só anda. Mobile: botão CORRER força a corrida em qualquer direção.
	  - Shift lock no Shift esquerdo, implementado aqui (mouse travado no centro, personagem
	    vira com a câmera, ombro deslocado). O nativo está desligado no project.json
	    (StarterPlayer.EnableMouseLockOption = false) para termos controle total. Ctrl fica livre.
	  - Animações de movimento da equipe (Assets.Animations.Shared.Idle/Walk/Run) tocadas por
	    nós mesmos com prioridade Movement, por cima do script "Animate" padrão (que fica só
	    com pulo/queda). Assim funciona mesmo se o place trocar/remover o Animate.
	    Diagnóstico: se a track carrega com Length 0, avisa no Output (id não é da conta dona
	    do jogo ou foi feita para outro rig).
	  - DASH UNIVERSAL no Q (gamepad X): RequestDash(direção do WASD, frente da câmera). O servidor
	    valida os dois cooldowns (lateral × frente/trás, CombatConfig.Dash) e manda NotifyDash; o
	    movimento (LinearVelocity dirigível) é feito aqui no dono da física. Durante o dash o boneco
	    fica virado para a câmera (A/D = strafe lateral de verdade, S = de costas). Q caído = ragdoll
	    cancel (o servidor decide). Sem dano.
	  - Ragdoll (NotifyRagdoll): para as animações de movimento; ao levantar força GettingUp.
	API: MovementController.SetSprint(active) (mobile) · MovementController.Dash() (mobile)
	     MovementController.SteerableDash(character, speed, duration, dir) (AbilityController: investidas)
	     MovementController.MoveDirection(character) · GetDashCooldowns() · DashCooldownChanged
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
local FX = require(Modules:WaitForChild("FX"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))

local MovementController = {}

local localPlayer = Players.LocalPlayer
local SHIFTLOCK_KEY = Enum.KeyCode.LeftShift
local DASH_KEY = Enum.KeyCode.Q
local DASH_GAMEPAD = Enum.KeyCode.ButtonX
local FORWARD_DOT = 0.6 -- MoveDirection·frente da câmera acima disso = "indo para a frente"
local SPRINT_MIN_INTERVAL = 0.15 -- segundos entre pedidos ao servidor (RateLimiter lá é 10/s)
local SHARED = "Shared"
local MOVE_THRESHOLD = 0.5 -- studs/s a partir do qual conta como andando

local requestSprint: RemoteEvent
local sprintForced = false -- botão CORRER do mobile
local sprintSent = false
local lastSprintRequest = 0

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
	if not a.grounded or localPlayer:GetAttribute("Ragdolled") == true then
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
-- Dash (movimento no cliente; o servidor só autoriza e avisa os outros)
-- ---------------------------------------------------------------------------

local requestDash: RemoteEvent
local shiftLock = false -- (shift lock; seção abaixo) o dash restaura AutoRotate só se não estiver ligado
local dashConn: RBXScriptConnection? = nil
local DASH_STOP_DISTANCE = 3.5 -- studs de folga antes do obstáculo
local DASH_RAY_OFFSETS = { Vector3.new(0, 1.5, 0), Vector3.new(0, 0, 0), Vector3.new(0, -2, 0) } -- cabeça, tronco, pés
local TRAIL_DEFAULT = Color3.fromRGB(255, 255, 255)

-- kind ("dash" | "cancel") -> { readyAt (GetServerTimeNow), total }
local dashCooldowns: { [string]: { readyAt: number, total: number } } = {}
MovementController.DashCooldownChanged = Instance.new("BindableEvent")

function MovementController.GetDashCooldowns()
	return dashCooldowns
end

--- Direção horizontal desejada: WASD/analógico, senão a frente do personagem.
function MovementController.MoveDirection(character: Model): Vector3
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local move = if humanoid then humanoid.MoveDirection else Vector3.zero
	local flat = Vector3.new(move.X, 0, move.Z)
	if flat.Magnitude > 0.1 then
		return flat.Unit
	end
	if root then
		local look = root.CFrame.LookVector
		flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			return flat.Unit
		end
	end
	return Vector3.new(0, 0, -1)
end

--- Dash dirigível: LinearVelocity cujo vetor segue o WASD enquanto durar (mantém a última direção
--- se soltar as teclas). Sem componente vertical: o Humanoid continua cuidando da gravidade/pulo.
--- Usado pelo dash universal (Q) e pelas investidas de personagem (AbilityController).
--- `facing` (opcional): frente a manter durante o dash (strafe); sem ela o boneco gira livre.
function MovementController.SteerableDash(character: Model, speed: number, duration: number, initial: Vector3, facing: Vector3?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root then
		return
	end
	local tuning = CharacterDefs.DashTuning
	-- Lateral vs frente/trás: escala da duração (distância) conforme a direção inicial
	local look = if facing then facing else root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local sideways = flatLook.Magnitude > 0.01 and math.abs(initial:Dot(flatLook.Unit)) < 0.5
	duration *= if sideways then tuning.SideScale else tuning.ForwardScale
	local keepFacing: Vector3? = if facing and flatLook.Magnitude > 0.01 then flatLook.Unit else nil
	if keepFacing and humanoid then
		humanoid.AutoRotate = false
		root.CFrame = CFrame.lookAt(root.Position, root.Position + keepFacing)
	end

	if dashConn then
		dashConn:Disconnect()
		dashConn = nil
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.MaxForce = math.huge
	lv.PlaneVelocity = Vector2.new(initial.X, initial.Z) * speed
	lv.Parent = root
	local direction = initial
	local endsAt = os.clock() + duration
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	rayParams.RespectCanCollide = true
	local function finish()
		if dashConn then
			dashConn:Disconnect()
			dashConn = nil
		end
		lv:Destroy()
		attachment:Destroy()
		if keepFacing and humanoid and not shiftLock then
			humanoid.AutoRotate = true
		end
		if root.Parent then
			-- sem momento residual (era isso que o AntiExploit via como "moveu demais" e o
			-- que devolvia o boneco para o lado contrário na parede)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local walk = if humanoid then humanoid.WalkSpeed else 16
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(direction.X * walk, math.min(v.Y, 0), direction.Z * walk)
		end
	end
	dashConn = RunService.Heartbeat:Connect(function(dt)
		if os.clock() >= endsAt or lv.Parent == nil or root.Parent == nil or localPlayer:GetAttribute("Ragdolled") == true then
			finish()
			return
		end
		-- Correção limitada pelo WASD (SteerRate rad/s): dá para curvar e, se bateu numa parede,
		-- virar e seguir para outro lado — a duração continua contando de qualquer jeito.
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local move = if humanoid then humanoid.MoveDirection else Vector3.zero
		local flat = Vector3.new(move.X, 0, move.Z)
		if flat.Magnitude > 0.1 then
			local want = flat.Unit
			local angle = math.atan2(direction:Cross(want).Y, direction:Dot(want))
			local step = math.clamp(angle, -tuning.SteerRate * dt, tuning.SteerRate * dt)
			direction = (CFrame.Angles(0, step, 0) * direction).Unit
		end
		-- Parede/personagem à frente: zera o empurrão só neste frame (nada de forçar contra o
		-- obstáculo, que travava e derrubava). O tempo do dash não para: sem "dash grátis".
		local ahead = speed * dt + DASH_STOP_DISTANCE
		local blocked = false
		for _, offset in DASH_RAY_OFFSETS do
			if Workspace:Raycast(root.Position + offset, direction * ahead, rayParams) then
				blocked = true
				break
			end
		end
		if blocked then
			lv.PlaneVelocity = Vector2.zero
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, math.min(v.Y, 0), 0)
		else
			lv.PlaneVelocity = Vector2.new(direction.X, direction.Z) * speed
		end
		if keepFacing then
			-- strafe: a frente não gira para o lado do dash (lateral é lateral)
			root.CFrame = CFrame.lookAt(root.Position, root.Position + keepFacing)
		end
	end)
end

--- Frente da câmera no plano (ou a frente do boneco se a câmera olhar reto para baixo).
local function cameraLook(character: Model): Vector3
	local camera = Workspace.CurrentCamera
	local look = if camera then camera.CFrame.LookVector else Vector3.zero
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.05 then
		return flat.Unit
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rl = if root then root.CFrame.LookVector else Vector3.new(0, 0, -1)
	return Vector3.new(rl.X, 0, rl.Z).Unit
end

--- Pede o dash universal (Q / botão de toque). Caído = ragdoll cancel.
function MovementController.Dash()
	local character = localPlayer.Character
	if not character then
		return
	end
	requestDash:FireServer(MovementController.MoveDirection(character), cameraLook(character))
end

local function characterColor(character: Model): Color3
	local player = Players:GetPlayerFromCharacter(character)
	local id = player and player:GetAttribute("CharacterId")
	local def = if typeof(id) == "string" then CharacterDefs.Get(id) else nil
	return if def and def.Color then def.Color else TRAIL_DEFAULT
end

local function onNotifyDash(character: Model?, data: any)
	if not character or typeof(data) ~= "table" or typeof(data.Direction) ~= "Vector3" then
		return
	end
	local direction: Vector3 = data.Direction
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local look = if root then root.CFrame.LookVector else Vector3.zero
	local backwards = Vector3.new(look.X, 0, look.Z):Dot(direction) < -0.5
	FX.Trail(character, characterColor(character), data.Duration + 0.15)
	if data.Cancel then
		FX.Flash(character, Color3.fromRGB(255, 255, 255), 0.3)
		FX.SpawnVFX(character, SHARED, "RagdollCancel", true)
		FX.PlaySoundAt(character, SHARED, "RagdollCancel")
	else
		FX.SpawnVFX(character, SHARED, "Dash", true)
		FX.PlaySoundAt(character, SHARED, "Dash")
	end
	-- DashBack existe (equipe); Dash (frente/lado) entra quando a equipe mandar o id
	if not (backwards and FX.PlayAnimation(character, SHARED, "DashBack")) then
		FX.PlayAnimation(character, SHARED, "Dash")
	end
	if character == localPlayer.Character then
		local facing = if typeof(data.Facing) == "Vector3" then data.Facing else nil
		MovementController.SteerableDash(character, data.Speed, data.Duration, direction, facing)
	end
end

local function onNotifyDashCooldown(kind: string, readyAt: number, total: number)
	dashCooldowns[kind] = { readyAt = readyAt, total = total }
	MovementController.DashCooldownChanged:Fire(kind, readyAt, total)
end

local function onNotifyRagdoll(character: Model?, active: boolean, seconds: number?)
	if not character then
		return
	end
	if active then
		FX.SpawnVFX(character, SHARED, "Ragdoll", true)
	end
	if character ~= localPlayer.Character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if active then
		stopAll()
		if dashConn then
			dashConn:Disconnect()
			dashConn = nil
		end
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end
	else
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		local a = anims
		if a then
			a.current = nil
			update()
		end
	end
end

-- ---------------------------------------------------------------------------
-- Shift lock próprio no Shift (o nativo está desligado: StarterPlayer.EnableMouseLockOption=false)
-- ---------------------------------------------------------------------------

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
		if not hum or not root or hum.Health <= 0 or localPlayer:GetAttribute("Ragdolled") == true then
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
-- Correr (automático para a frente)
-- ---------------------------------------------------------------------------

local function sendSprint(active: boolean)
	if sprintSent == active then
		return
	end
	local now = os.clock()
	if now - lastSprintRequest < SPRINT_MIN_INTERVAL then
		return -- tenta de novo no próximo frame
	end
	lastSprintRequest = now
	sprintSent = active
	requestSprint:FireServer(active)
end

--- Mobile: botão CORRER liga/desliga corrida em qualquer direção.
function MovementController.SetSprint(active: boolean)
	sprintForced = active
end

--- "Para a frente" = direção do movimento alinhada com a frente da câmera (ou do personagem
--- em shift lock, que é a mesma coisa).
local function isMovingForward(humanoid: Humanoid): boolean
	local move = humanoid.MoveDirection
	if move.Magnitude < 0.1 then
		return false
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		return false
	end
	return move.Unit:Dot(flat.Unit) >= FORWARD_DOT
end

local function updateSprint()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local want = moving and (sprintForced or isMovingForward(humanoid))
	sendSprint(want)
end

local function onInputBegan(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == SHIFTLOCK_KEY then
		toggleShiftLock()
	elseif input.KeyCode == DASH_KEY or input.KeyCode == DASH_GAMEPAD then
		MovementController.Dash()
	end
end

function MovementController.Init()
	requestSprint = Remotes.GetEvent(Remotes.Events.RequestSprint)
	requestDash = Remotes.GetEvent(Remotes.Events.RequestDash)
end

function MovementController.Start()
	Remotes.GetEvent(Remotes.Events.NotifyDash).OnClientEvent:Connect(onNotifyDash)
	Remotes.GetEvent(Remotes.Events.NotifyDashCooldown).OnClientEvent:Connect(onNotifyDashCooldown)
	Remotes.GetEvent(Remotes.Events.NotifyRagdoll).OnClientEvent:Connect(onNotifyRagdoll)
	UserInputService.InputBegan:Connect(onInputBegan)
	RunService.Heartbeat:Connect(updateSprint)
	localPlayer:GetAttributeChangedSignal("Sprinting"):Connect(function()
		local a = anims
		if a then
			a.current = nil -- força trocar Walk <-> Run
			update()
		end
	end)
	localPlayer.CharacterAdded:Connect(function(character)
		sprintSent = false
		table.clear(dashCooldowns)
		MovementController.DashCooldownChanged:Fire("forward", 0, 0)
		setup(character)
		if shiftLock then
			applyShiftLock(true) -- reaplica no personagem novo
		end
	end)
	if localPlayer.Character then
		task.spawn(setup, localPlayer.Character)
	end
	Log.debug(("[MovementController] pronto (corre sozinho para a frente a %d, Shift = shift lock, Q = dash)"):format(CombatConfig.Sprint.Speed))
end

return MovementController
