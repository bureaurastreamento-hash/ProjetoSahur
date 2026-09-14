--!strict
--[[
	CombatService (servidor)
	Autoridade sobre golpes, cooldowns, combo, block e parry.
	O cliente só envia RequestAttack(attackId) / RequestBlock(active).
	A hitbox é calculada AQUI, a partir da posição do atacante no servidor;
	nada que o cliente envie sobre "quem acertei" é aceito.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local Hitbox = require(Modules:WaitForChild("Hitbox"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))

-- AbilityService depende deste módulo; é carregado tardiamente em Start() para evitar ciclo.
local AbilityService: any = nil

local CombatService = {}

type PlayerState = {
	blocking: boolean,
	blockStart: number,
	blockReleased: number,
	nextAttackAt: number, -- os.clock() a partir do qual pode atacar
	stunnedUntil: number,
	combo: number, -- índice do PRÓXIMO golpe (1..ComboLength)
	lastAttackAt: number,
	lastRequestAt: number, -- rate limit bruto
}

local states: { [Player]: PlayerState } = {}

local notifyAttack: RemoteEvent
local notifyDamage: RemoteEvent
local notifyCooldown: RemoteEvent
local notifyBlock: RemoteEvent

local MIN_REQUEST_INTERVAL = 0.05 -- anti-flood

-- ---------------------------------------------------------------------------
-- Estado
-- ---------------------------------------------------------------------------

local function newState(): PlayerState
	return {
		blocking = false,
		blockStart = -math.huge,
		blockReleased = -math.huge,
		nextAttackAt = 0,
		stunnedUntil = 0,
		combo = 1,
		lastAttackAt = -math.huge,
		lastRequestAt = -math.huge,
	}
end

local function getState(player: Player): PlayerState
	local s = states[player]
	if not s then
		s = newState()
		states[player] = s
	end
	return s
end

local function rateLimited(state: PlayerState): boolean
	local now = os.clock()
	if now - state.lastRequestAt < MIN_REQUEST_INTERVAL then
		return true
	end
	state.lastRequestAt = now
	return false
end

-- ---------------------------------------------------------------------------
-- Block
-- ---------------------------------------------------------------------------

local function setBlocking(player: Player, active: boolean)
	local state = getState(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if state.blocking == active then
		return
	end

	local now = os.clock()
	if active then
		if now - state.blockReleased < CombatConfig.Block.Cooldown then
			return -- spam de block/parry
		end
		state.blocking = true
		state.blockStart = now
		if humanoid then
			humanoid.WalkSpeed = CombatConfig.Block.WalkSpeed
		end
	else
		state.blocking = false
		state.blockReleased = now
		if humanoid then
			humanoid.WalkSpeed = CombatConfig.WalkSpeed
		end
	end

	if character then
		notifyBlock:FireAllClients(character, active)
	end
end

--- Impede o jogador de atacar/bloquear por `seconds`. Usado por parry e habilidades.
function CombatService.Stun(player: Player, seconds: number, reason: string)
	local state = getState(player)
	local until_ = os.clock() + seconds
	state.stunnedUntil = math.max(state.stunnedUntil, until_)
	state.nextAttackAt = math.max(state.nextAttackAt, until_)
	if state.blocking then
		setBlocking(player, false)
	end
	notifyCooldown:FireClient(player, reason, seconds)
end

function CombatService.IsStunned(player: Player): boolean
	return os.clock() < getState(player).stunnedUntil
end

-- ---------------------------------------------------------------------------
-- Ataque
-- ---------------------------------------------------------------------------

--- Resolve um acerto contra `victim` considerando block/parry e buffs.
--- Usado pelos socos e pelas habilidades (AbilityService).
function CombatService.ResolveHit(attacker: Player, attackerChar: Model, victim: Model, damage: number, allowParry: boolean?)
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	local victimState = victimPlayer and states[victimPlayer]
	local kind = "hit"
	if AbilityService then
		damage *= AbilityService.GetDamageMultiplier(attacker)
	end
	local finalDamage = damage

	if victimState and victimState.blocking then
		local blockAge = os.clock() - victimState.blockStart
		if allowParry ~= false and blockAge <= CombatConfig.Block.ParryWindow then
			kind = "parry"
			finalDamage = 0
			CombatService.Stun(attacker, CombatConfig.Block.ParryStun, "parried")
		else
			kind = "blocked"
			finalDamage = damage * CombatConfig.Block.DamageMultiplier
		end
	end

	local dealt = 0
	if finalDamage > 0 then
		dealt = HealthService.ApplyDamage(victim, finalDamage, attacker)
		if dealt > 0 and AbilityService then
			AbilityService.OnHitDealt(attacker, victimPlayer)
		end
	end

	-- TODO(launch): reduzir log
	print(("[CombatService] %s -> %s: %s, dano %.1f"):format(attacker.Name, victim.Name, kind, dealt))
	notifyDamage:FireAllClients(attackerChar, victim, dealt, kind)
end

local function onRequestAttack(player: Player, attackId: any)
	local state = getState(player)
	if rateLimited(state) then
		return
	end

	-- Validação de entrada
	if typeof(attackId) ~= "string" then
		return
	end
	local attackCfg = CombatConfig.Attacks[attackId]
	if not attackCfg then
		warn(("[CombatService] %s pediu ataque desconhecido '%s'"):format(player.Name, attackId))
		return
	end

	local character = player.Character
	if not character or not HealthService.IsAlive(character) or not HealthService.CanFight(player) then
		return
	end

	local now = os.clock()
	if now < state.stunnedUntil or now < state.nextAttackAt then
		return -- em cooldown/stun: ignorado silenciosamente
	end

	-- Atacar cancela o block
	if state.blocking then
		setBlocking(player, false)
	end

	-- Combo
	if now - state.lastAttackAt > attackCfg.ComboResetTime then
		state.combo = 1
	end
	local comboIndex = state.combo
	local isFinisher = comboIndex >= attackCfg.ComboLength
	local damage = if isFinisher then attackCfg.FinisherDamage else attackCfg.Damage

	state.lastAttackAt = now
	state.nextAttackAt = now + (if isFinisher then attackCfg.ComboEndCooldown else attackCfg.Cooldown)
	state.combo = if isFinisher then 1 else comboIndex + 1

	notifyAttack:FireAllClients(character, attackId, comboIndex)

	-- Wind-up: hitbox é checada depois do delay, com a posição de então
	task.delay(attackCfg.HitDelay, function()
		if player.Parent ~= Players or player.Character ~= character or not HealthService.IsAlive(character) then
			return
		end
		if os.clock() < state.stunnedUntil then
			return -- foi parryado/stunado durante o wind-up
		end
		for _, victim in Hitbox.InFront(character, attackCfg.Range, attackCfg.Width, attackCfg.Height, attackCfg.MaxTargets) do
			CombatService.ResolveHit(player, character, victim, damage)
		end
	end)
end

local function onRequestBlock(player: Player, active: any)
	local state = getState(player)
	if rateLimited(state) then
		return
	end
	if typeof(active) ~= "boolean" then
		return
	end
	if not HealthService.IsAlive(player.Character) or not HealthService.CanFight(player) then
		return
	end
	if active and os.clock() < state.stunnedUntil then
		return
	end
	setBlocking(player, active)
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function CombatService.Init()
	notifyAttack = Remotes.GetEvent(Remotes.Events.NotifyAttack)
	notifyDamage = Remotes.GetEvent(Remotes.Events.NotifyDamage)
	notifyCooldown = Remotes.GetEvent(Remotes.Events.NotifyCooldown)
	notifyBlock = Remotes.GetEvent(Remotes.Events.NotifyBlock)
end

function CombatService.Start()
	local ok, result = pcall(require, script.Parent:WaitForChild("AbilityService"))
	if ok then
		AbilityService = result
	else
		warn("[CombatService] AbilityService indisponível; buffs/energia desligados: " .. tostring(result))
	end

	Remotes.GetEvent(Remotes.Events.RequestAttack).OnServerEvent:Connect(onRequestAttack)
	Remotes.GetEvent(Remotes.Events.RequestBlock).OnServerEvent:Connect(onRequestBlock)

	local function onPlayer(player: Player)
		getState(player)
		player.CharacterAdded:Connect(function()
			states[player] = newState() -- respawn zera tudo
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return CombatService
