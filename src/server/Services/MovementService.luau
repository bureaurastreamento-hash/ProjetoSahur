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
local Workspace = game:GetService("Workspace")
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
local notifyAbility: RemoteEvent -- DashOverride (Blink) avisa como habilidade para o FX de teleporte

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

--- Teleporte de verdade (decisão do dono 2026-09-16): anda `distance` studs em `direction` ATRAVESSANDO o
--- que estiver na frente (sem raycast travando na parede) e encaixa no chão do destino, mantendo a
--- altura que o boneco tinha em relação ao chão de onde saiu. Sem chão no destino, mantém o Y.
function MovementService.Teleport(player: Player, character: Model, direction: Vector3, distance: number): boolean
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then
		flat = root.CFrame.LookVector
	end
	flat = flat.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local here = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	local heightAboveGround = if here then root.Position.Y - here.Position.Y else 3
	local target = root.Position + flat * distance
	local ground = Workspace:Raycast(target + Vector3.new(0, 15, 0), Vector3.new(0, -45, 0), params)
	if ground then
		target = Vector3.new(target.X, ground.Position.Y + heightAboveGround, target.Z)
	end
	AntiExploitService.Grace(player, 1)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(target) * (root.CFrame - root.CFrame.Position)
	return true
end

--- Q de um personagem com DashOverride (Swift = Piscar): teleporta em vez de dar dash; um cooldown só
--- (mostrado nos dois "kinds" do HUD). Usa a mesma trava DashingUntil por CastTime.
local function doDashOverride(player: Player, character: Model, ability: any, direction: Vector3, state: DashState, noCooldown: boolean)
	local now = os.clock()
	if now < state.forwardReadyAt and not noCooldown then
		return
	end
	local effect = ability.Effect
	-- Despertado (AwakenedUntil vem do AbilityService, que já depende deste módulo): versão desperta
	local awakenedUntil = player:GetAttribute("AwakenedUntil")
	if ability.AwakenedEffect and typeof(awakenedUntil) == "number" and Workspace:GetServerTimeNow() < awakenedUntil then
		effect = ability.AwakenedEffect
	end
	if not (effect and effect.Type == "Teleport") then
		warn(("[MovementService] DashOverride %s: só Effect Teleport é suportado"):format(tostring(ability.Id)))
		return
	end
	if not MovementService.Teleport(player, character, direction, effect.Distance) then
		return
	end
	if not noCooldown then
		local serverNow = Workspace:GetServerTimeNow()
		state.forwardReadyAt = now + ability.Cooldown
		state.sideReadyAt = state.forwardReadyAt
		notifyDashCooldown:FireClient(player, "forward", serverNow + ability.Cooldown, ability.Cooldown)
		notifyDashCooldown:FireClient(player, "side", serverNow + ability.Cooldown, ability.Cooldown)
	end
	player:SetAttribute(ATTR_DASHING_UNTIL, now + (ability.CastTime or 0))
	local characterId = player:GetAttribute("CharacterId")
	notifyAbility:FireAllClients(character, if typeof(characterId) == "string" then characterId else "", ability.Id, "start", { Teleported = true })
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
	-- Personagem sem dash (Swift): o Q vira a habilidade DashOverride
	local characterId = player:GetAttribute("CharacterId")
	local override = if typeof(characterId) == "string" then CharacterDefs.GetDashOverride(characterId) else nil
	if override then
		doDashOverride(player, character, override, direction, state, noCooldown)
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
	notifyAbility = Remotes.GetEvent(Remotes.Events.NotifyAbility)
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
