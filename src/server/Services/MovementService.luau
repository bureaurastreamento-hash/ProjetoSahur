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
	Lutador = Combatant.Fighter (Player ou bot). Bot: o SERVIDOR move o dash (LinearVelocity, mesma receita
	do cliente) — MovementService.Dash(bot, direction) / Sprint(bot, on) são a API que o BotService usa.
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
local Hitbox = require(Modules:WaitForChild("Hitbox"))
local Combatant = require(Modules:WaitForChild("Combatant"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))

local MovementService = {}

type Fighter = Combatant.Fighter

local sprintLimiter = RateLimiter.new(10, 1)
local dashLimiter = RateLimiter.new(6, 1)

local ATTR_NO_COOLDOWN = "DevNoCooldown"

type DashState = { forwardReadyAt: number, sideReadyAt: number, cancelReadyAt: number }
local ATTR_DASHING_UNTIL = "DashingUntil" -- os.clock(); CombatService/AbilityService recusam ações até aqui
local ATTR_DASH_KIND = "DashKind" -- "side" | "forward": o soco no fim do dash LATERAL é permitido (CombatService)
local dashStates: { [Instance]: DashState } = {}
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local DASH_GROUP = "Dashing" -- durante o dash o corpo não colide com jogadores (CombatConfig.Dash.NoPlayerCollision)
local PLAYERS_GROUP = "Players" -- CharacterService põe todo personagem aqui

local notifyDash: RemoteEvent
local notifyDashCooldown: RemoteEvent
local notifyAbility: RemoteEvent -- DashOverride (Blink) avisa como habilidade para o FX de teleporte

local function dashState(player: Fighter): DashState
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

--- Teleporte (Piscar do Bruno, Warp do Overlord, Effect Teleport): anda até `distance` studs em `direction`
--- ATRAVESSANDO só PERSONAGENS (jogadores/NPCs). Dono (2026-09-21): parede não se atravessa e nunca cai no
--- void — o raio para antes do primeiro obstáculo do cenário e o destino precisa ter chão; sem chão, recua
--- pelo caminho até achar (senão não teleporta). Mantém a altura que o boneco tinha em relação ao chão.
local function characterFilter(exclude: Model): { Instance }
	local list: { Instance } = { exclude }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, m in CollectionService:GetTagged("Combatant") do
		table.insert(list, m)
	end
	local arrow = Workspace:FindFirstChild("RitualArrow")
	if arrow then
		table.insert(list, arrow)
	end
	return list
end

function MovementService.Teleport(player: Fighter, character: Model, direction: Vector3, distance: number): boolean
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
	params.FilterDescendantsInstances = characterFilter(character)
	params.RespectCanCollide = true
	local here = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	local heightAboveGround = if here then math.clamp(root.Position.Y - here.Position.Y, 2.5, 8) else 3
	-- obstáculo do cenário no caminho (na altura do peito e dos pés): para 2 studs antes
	local travel = distance
	for _, dy in { 0, -2 } do
		local hit = Workspace:Raycast(root.Position + Vector3.new(0, dy, 0), flat * distance, params)
		if hit then
			travel = math.min(travel, math.max(0, (hit.Position - root.Position).Magnitude - 2.5))
		end
	end
	if travel < 2 then
		return false
	end
	-- destino precisa ter chão: recua pelo caminho até achar
	local target: Vector3? = nil
	for _, frac in { 1, 0.85, 0.7, 0.55, 0.4 } do
		local candidate = root.Position + flat * (travel * frac)
		local ground = Workspace:Raycast(candidate + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), params)
		if ground then
			target = Vector3.new(candidate.X, ground.Position.Y + heightAboveGround, candidate.Z)
			break
		end
	end
	if not target then
		return false
	end
	local asPlayer = Combatant.PlayerOf(player)
	if asPlayer then
		AntiExploitService.Grace(asPlayer, 1)
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(target) * (root.CFrame - root.CFrame.Position)
	return true
end

--- Grupo de colisão do dash: liga/desliga em todas as peças do personagem.
local function setDashCollision(character: Model, dashing: boolean)
	if not CombatConfig.Dash.NoPlayerCollision then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and (d.CollisionGroup == PLAYERS_GROUP or d.CollisionGroup == DASH_GROUP or d.CollisionGroup == "Default") then
			d.CollisionGroup = if dashing then DASH_GROUP else PLAYERS_GROUP
		end
	end
end

--- Hit de chegada do dash para a frente / Piscar (CombatConfig.Dash.ArrivalHit): dano fixo sem combo;
--- vítima bem de frente = empurrão longe em vez do hit.
local function arrivalHit(player: Fighter, character: Model, direction: Vector3)
	local cfg = CombatConfig.Dash.ArrivalHit
	if not cfg or not HealthService.IsAlive(character) or Combatant.CharacterOf(player) ~= character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local dir = Vector3.new(direction.X, 0, direction.Z)
	dir = if dir.Magnitude > 0.1 then dir.Unit else root.CFrame.LookVector
	for _, victim in Hitbox.InDirection(character, dir, cfg.Range, cfg.Width, cfg.Height, cfg.MaxTargets) do
		local vRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
		local toVictim = if vRoot then Vector3.new(vRoot.Position.X - root.Position.X, 0, vRoot.Position.Z - root.Position.Z) else Vector3.zero
		local front = toVictim.Magnitude > 0.1 and dir:Dot(toVictim.Unit) >= cfg.FrontDot
		if front then
			CombatService.ResolveHit(player, character, victim, cfg.Damage, false, cfg.Knockback, { KnockbackDirection = dir })
		else
			CombatService.ResolveHit(player, character, victim, cfg.Damage, false)
		end
	end
end

--- Q de um personagem com DashOverride (Swift = Piscar): teleporta em vez de dar dash; um cooldown só
--- (mostrado nos dois "kinds" do HUD). Usa a mesma trava DashingUntil por CastTime.
local function doDashOverride(player: Fighter, character: Model, ability: any, direction: Vector3, state: DashState, noCooldown: boolean, sideways: boolean)
	local now = os.clock()
	local kind = if sideways then "side" else "forward"
	if now < (if sideways then state.sideReadyAt else state.forwardReadyAt) and not noCooldown then
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
		-- dois cooldowns como o dash universal (dono, 2026-09-21): lateral = SideCooldown (ou Cooldown)
		local serverNow = Workspace:GetServerTimeNow()
		local cd = if sideways then (tonumber(ability.SideCooldown) or ability.Cooldown) else ability.Cooldown
		local dashMult = player:GetAttribute("DashCooldownMult")
		if typeof(dashMult) == "number" and dashMult > 0 then
			cd *= dashMult
		end
		if sideways then
			state.sideReadyAt = now + cd
		else
			state.forwardReadyAt = now + cd
		end
		Combatant.Notify(player, notifyDashCooldown, kind, serverNow + cd, cd)
	end
	player:SetAttribute(ATTR_DASH_KIND, kind)
	player:SetAttribute(ATTR_DASHING_UNTIL, now + (ability.CastTime or 0))
	local characterId = player:GetAttribute("CharacterId")
	notifyAbility:FireAllClients(character, if typeof(characterId) == "string" then characterId else "", ability.Id, "start", { Teleported = true })
	-- chegou: hit de chegada (só quando o Piscar foi para a FRENTE da câmera)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local look = if root then root.CFrame.LookVector else direction
	if direction:Dot(Vector3.new(look.X, 0, look.Z)) >= 0 then
		task.delay(0.05, function()
			arrivalHit(player, character, direction)
		end)
	end
end

--- Bot: o servidor é dono da física — LinearVelocity no plano por `duration` s (o cliente faz igual para
--- o próprio jogador em MovementController.SteerableDash). Sem componente vertical (gravidade normal).
function MovementService.ServerDash(character: Model, direction: Vector3, facing: Vector3, speed: number, duration: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root then
		return
	end
	local old = root:FindFirstChild("BotDash")
	if old then
		old:Destroy()
	end
	if humanoid and facing.Magnitude > 0.01 then
		humanoid.AutoRotate = false
		root.CFrame = CFrame.lookAt(root.Position, root.Position + facing)
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "BotDash"
	attachment.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.MaxForce = math.huge
	lv.PlaneVelocity = Vector2.new(direction.X, direction.Z) * speed
	lv.Parent = attachment
	task.delay(duration, function()
		attachment:Destroy()
		if humanoid then
			humanoid.AutoRotate = true
		end
		if root.Parent then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, math.min(v.Y, 0), 0)
		end
	end)
end

local function onRequestDash(player: Fighter, rawDirection: any, rawLook: any)
	if not dashLimiter:Allow(player) then
		return
	end
	local isBot = Combatant.IsBot(player)
	local asPlayer = Combatant.PlayerOf(player)
	local character = Combatant.CharacterOf(player)
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	CombatService.NotifyAction(player) -- dash cancela emote em loop
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
			Combatant.Notify(player, notifyDashCooldown, "cancel", serverNow + rc.CancelCooldown, rc.CancelCooldown)
		end
		if asPlayer then
			AntiExploitService.Grace(asPlayer, cfg.Duration * 2 + 1)
		end
		player:SetAttribute(ATTR_DASHING_UNTIL, now + cfg.Duration * 1.4)
		notifyDash:FireAllClients(character, { Direction = direction, Facing = facing, Speed = cfg.Speed, Duration = cfg.Duration, Kind = kind, Cancel = true })
		if isBot then
			MovementService.ServerDash(character, direction, facing, cfg.Speed, cfg.Duration * CharacterDefs.DashTuning.ForwardScale)
		end
		Log.debug(("[MovementService] %s ragdoll cancel"):format(player.Name))
		return
	end

	-- Preso no combo/stun/agarrão: não sai (a brecha é quando o atacante para de bater)
	if CombatService.IsStunned(player) or CombatService.IsGrabbed(character) then
		return
	end
	-- Dono (2026-09-21): ação individual — no meio do soco não sai dash; dentro do Domínio do Tempo nada sai
	if CombatService.IsAttacking(player) or CombatService.IsTimeSlowed(player) then
		return
	end
	-- Personagem sem dash (Swift): o Q vira a habilidade DashOverride
	local characterId = player:GetAttribute("CharacterId")
	local override = if typeof(characterId) == "string" then CharacterDefs.GetDashOverride(characterId) else nil
	if override then
		doDashOverride(player, character, override, direction, state, noCooldown, sideways)
		return
	end
	local readyAt = if sideways then state.sideReadyAt else state.forwardReadyAt
	if now < readyAt and not noCooldown then
		return
	end
	local cooldown = if sideways then cfg.SideCooldown else cfg.ForwardBackCooldown
	local timeSlow = player:GetAttribute("TimeSlow")
	if typeof(timeSlow) == "number" and timeSlow > 0 and timeSlow < 1 then
		cooldown /= timeSlow -- Domínio do Tempo
	end
	local dashMult = player:GetAttribute("DashCooldownMult") -- Buff.DashCooldownMult (Aceleração do Bruno)
	if typeof(dashMult) == "number" and dashMult > 0 then
		cooldown *= dashMult
	end
	if not noCooldown then
		if sideways then
			state.sideReadyAt = now + cooldown
		else
			state.forwardReadyAt = now + cooldown
		end
		Combatant.Notify(player, notifyDashCooldown, kind, serverNow + cooldown, cooldown)
	end
	if asPlayer then
		AntiExploitService.Grace(asPlayer, cfg.Duration * 2 + 1)
	end
	-- durante o dash não dá para socar/usar habilidade (lateral é mais curto: SideScale)
	local scale = if sideways then CharacterDefs.DashTuning.SideScale else CharacterDefs.DashTuning.ForwardScale
	local dashUntil = now + cfg.Duration * scale
	player:SetAttribute(ATTR_DASH_KIND, kind)
	player:SetAttribute(ATTR_DASHING_UNTIL, dashUntil)
	-- corpo não empurra ninguém durante o dash
	setDashCollision(character, true)
	task.delay(cfg.Duration * scale + 0.05, function()
		if Combatant.CharacterOf(player) == character then
			setDashCollision(character, false)
		end
	end)
	notifyDash:FireAllClients(character, { Direction = direction, Facing = facing, Speed = cfg.Speed, Duration = cfg.Duration, Kind = kind })
	if isBot then
		MovementService.ServerDash(character, direction, if sideways then facing else Vector3.zero, cfg.Speed, cfg.Duration * scale)
	end
	-- dash para a FRENTE (não lateral, não para trás): hit de chegada no fim do deslocamento
	if not sideways and direction:Dot(facing) > 0 then
		task.delay(cfg.Duration * scale, function()
			arrivalHit(player, character, direction)
		end)
	end
end

--- Bot/DEV: mesmo caminho do Q do jogador (validações, cooldowns, hit de chegada). `look` = frente
--- (decide lateral × frente/trás); sem ela, a direção pedida.
function MovementService.Dash(fighter: Fighter, direction: Vector3, look: Vector3?)
	onRequestDash(fighter, direction, look or direction)
end

--- Está no meio de um dash (Q)?
function MovementService.IsDashing(player: Fighter): boolean
	local untilT = player:GetAttribute(ATTR_DASHING_UNTIL)
	return typeof(untilT) == "number" and os.clock() < untilT
end

local function setSprint(player: Fighter, active: boolean)
	local character = Combatant.CharacterOf(player)
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

--- Bot/DEV: liga/desliga a corrida.
function MovementService.Sprint(fighter: Fighter, active: boolean)
	setSprint(fighter, active)
end

function MovementService.Init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(PLAYERS_GROUP)
		PhysicsService:RegisterCollisionGroup(DASH_GROUP)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(DASH_GROUP, PLAYERS_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(DASH_GROUP, DASH_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(DASH_GROUP, "Grabbed", false)
		PhysicsService:CollisionGroupSetCollidable("Grabbed", PLAYERS_GROUP, false) -- vítima carregada não bate em jogador
	end)
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
