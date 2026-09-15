--!strict
--[[
	MovementService (servidor)
	Corrida automática ao andar para a frente (cliente decide a direção; botão CORRER no mobile força).
	  RequestSprint(active) -> WalkSpeed = CombatConfig.Sprint.Speed (não enquanto bloqueia)
	Atributo Sprinting no Player: CombatService lê ao soltar o block; MovementController anima.
	Dash UNIVERSAL (Q, CombatConfig.Dash): RequestDash(direction, cameraLook) -> classifica lateral ×
	frente/trás (dois cooldowns independentes), NotifyDash a todos (o dono move; os outros veem
	rastro/animação). Sem dano. Não sai em stun (hitstun incluído). Durante o dash o atributo
	DashingUntil bloqueia soco/habilidade. Ragdollado = RAGDOLL CANCEL: levanta na hora com i-frames
	curtos e cooldown próprio (CombatConfig.CombatRagdoll).
	Cooldowns vão por NotifyDashCooldown(kind, readyAtServerTime, total).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))

local MovementService = {}

local sprintLimiter = RateLimiter.new(10, 1)
local dashLimiter = RateLimiter.new(6, 1)

local ATTR_NO_COOLDOWN = "DevNoCooldown"

type DashState = { forwardReadyAt: number, sideReadyAt: number, cancelReadyAt: number }
local ATTR_DASHING_UNTIL = "DashingUntil" -- os.clock(); CombatService/AbilityService recusam ações até aqui
local dashStates: { [Player]: DashState } = {}

local notifyDash: RemoteEvent
local notifyDashCooldown: RemoteEvent

local function dashState(player: Player): DashState
	local s = dashStates[player]
	if not s then
		s = { forwardReadyAt = 0, sideReadyAt = 0, cancelReadyAt = 0 }
		dashStates[player] = s
	end
	return s
end

local function facing(root: BasePart): Vector3
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
end

local function sanitizeDirection(root: BasePart, raw: any): Vector3
	if typeof(raw) == "Vector3" then
		local flat = Vector3.new(raw.X, 0, raw.Z)
		if flat.Magnitude > 0.5 and flat.Magnitude < 1.5 and flat.X == flat.X and flat.Z == flat.Z then
			return flat.Unit
		end
	end
	return facing(root)
end

local function onRequestDash(player: Player, rawDirection: any, rawLook: any)
	if not dashLimiter:Allow(player) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root or not HealthService.IsAlive(character) or not HealthService.CanFight(player) then
		return
	end
	local cfg = CombatConfig.Dash
	local state = dashState(player)
	local now = os.clock()
	local noCooldown = player:GetAttribute(ATTR_NO_COOLDOWN) == true
	local direction = sanitizeDirection(root, rawDirection)
	-- frente da câmera do cliente (só decide lateral × frente/trás e a orientação do strafe)
	local facing = sanitizeDirection(root, rawLook)
	local serverNow = workspace:GetServerTimeNow()
	local sideways = math.abs(direction:Dot(facing)) < cfg.SideDot
	local kind = if sideways then "side" else "forward"

	-- Ragdoll cancel: Q caído = levanta agora (i-frames) e sai em dash; cooldown próprio
	if RagdollService.IsRagdolled(player) then
		if now < state.cancelReadyAt and not noCooldown then
			return
		end
		local rc = CombatConfig.CombatRagdoll
		if not RagdollService.Recover(player, rc.CancelIFrames) then
			return
		end
		if not noCooldown then
			state.cancelReadyAt = now + rc.CancelCooldown
			notifyDashCooldown:FireClient(player, "cancel", serverNow + rc.CancelCooldown, rc.CancelCooldown)
		end
		AntiExploitService.Grace(player, cfg.Duration * 2 + 1)
		player:SetAttribute(ATTR_DASHING_UNTIL, now + cfg.Duration * 1.4)
		notifyDash:FireAllClients(character, { Direction = direction, Facing = facing, Speed = cfg.Speed, Duration = cfg.Duration, Kind = kind, Cancel = true })
		Log.debug(("[MovementService] %s ragdoll cancel"):format(player.Name))
		return
	end

	-- Preso no combo/stun: não sai (a brecha é quando o atacante para de bater)
	if CombatService.IsStunned(player) then
		return
	end
	local readyAt = if sideways then state.sideReadyAt else state.forwardReadyAt
	if now < readyAt and not noCooldown then
		return
	end
	local cooldown = if sideways then cfg.SideCooldown else cfg.ForwardBackCooldown
	if not noCooldown then
		if sideways then
			state.sideReadyAt = now + cooldown
		else
			state.forwardReadyAt = now + cooldown
		end
		notifyDashCooldown:FireClient(player, kind, serverNow + cooldown, cooldown)
	end
	AntiExploitService.Grace(player, cfg.Duration * 2 + 1)
	-- durante o dash não dá para socar/usar habilidade (lateral é mais curto: SideScale)
	local scale = if sideways then CharacterDefs.DashTuning.SideScale else CharacterDefs.DashTuning.ForwardScale
	player:SetAttribute(ATTR_DASHING_UNTIL, now + cfg.Duration * scale)
	notifyDash:FireAllClients(character, { Direction = direction, Facing = facing, Speed = cfg.Speed, Duration = cfg.Duration, Kind = kind })
end

--- Está no meio de um dash (Q)?
function MovementService.IsDashing(player: Player): boolean
	local untilT = player:GetAttribute(ATTR_DASHING_UNTIL)
	return typeof(untilT) == "number" and os.clock() < untilT
end

local function setSprint(player: Player, active: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if active and (not HealthService.IsAlive(character) or CombatService.IsBlocking(player)) then
		active = false
	end
	player:SetAttribute("Sprinting", active)
	if player:GetAttribute("DevSpeed") ~= nil then
		return -- só anima; a velocidade é do menu dev
	end
	-- CombatService decide a velocidade final (block > hitstun > corrida) × buff do Awakening
	CombatService.RestoreWalkSpeed(player)
end

local function onRequestSprint(player: Player, active: any)
	if not sprintLimiter:Allow(player) or typeof(active) ~= "boolean" then
		return
	end
	setSprint(player, active)
end

function MovementService.Init()
	notifyDash = Remotes.GetEvent(Remotes.Events.NotifyDash)
	notifyDashCooldown = Remotes.GetEvent(Remotes.Events.NotifyDashCooldown)
end

function MovementService.Start()
	local okAdmin, AdminService = pcall(require, script.Parent:WaitForChild("AdminService"))
	if okAdmin then
		(AdminService :: any).ResetDash = function(player: Player)
			dashStates[player] = nil
			notifyDashCooldown:FireClient(player, "forward", 0, 0)
			notifyDashCooldown:FireClient(player, "side", 0, 0)
			notifyDashCooldown:FireClient(player, "cancel", 0, 0)
		end
	end
	Remotes.GetEvent(Remotes.Events.RequestSprint).OnServerEvent:Connect(onRequestSprint)
	Remotes.GetEvent(Remotes.Events.RequestDash).OnServerEvent:Connect(onRequestDash)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Sprinting", false)
			dashStates[player] = nil -- respawn zera dash e ragdoll cancel
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		dashStates[player] = nil
	end)
	Log.debug("[MovementService] pronto (corrida automática para a frente, dash universal no Q)")
end

return MovementService
