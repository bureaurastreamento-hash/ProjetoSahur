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
local Log = require(Modules:WaitForChild("Log"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local Hitbox = require(Modules:WaitForChild("Hitbox"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))

-- AbilityService depende deste módulo; é carregado tardiamente em Start() para evitar ciclo.
local AbilityService: any = nil

local CombatService = {}

type PlayerState = {
	wantBlock: boolean, -- jogador está segurando o botão de block
	blocking: boolean,
	blockStart: number,
	blockReleased: number,
	nextAttackAt: number, -- os.clock() a partir do qual pode atacar
	stunnedUntil: number,
	combo: number, -- índice do PRÓXIMO golpe (1..ComboLength)
	lastAttackAt: number,
	guard: number, -- guarda restante (CombatConfig.Block.GuardMax)
	guardHitAt: number, -- último golpe bloqueado (regen começa GuardRegenDelay depois)
	hitStunUntil: number,
}

local states: { [Player]: PlayerState } = {}

local notifyAttack: RemoteEvent
local notifyDamage: RemoteEvent
local notifyCooldown: RemoteEvent
local notifyBlock: RemoteEvent
local notifyKnockback: RemoteEvent

-- AntiExploit é opcional aqui (carregado tardiamente para evitar ciclo)
local AntiExploitService: any = nil

local attackLimiter = RateLimiter.new(10, 1)
local blockLimiter = RateLimiter.new(10, 1)

-- ---------------------------------------------------------------------------
-- Estado
-- ---------------------------------------------------------------------------

local function newState(): PlayerState
	return {
		wantBlock = false,
		blocking = false,
		blockStart = -math.huge,
		blockReleased = -math.huge,
		nextAttackAt = 0,
		stunnedUntil = 0,
		combo = 1,
		lastAttackAt = -math.huge,
		guard = CombatConfig.Block.GuardMax,
		guardHitAt = -math.huge,
		hitStunUntil = 0,
	}
end

--- WalkSpeed "certa" para o estado atual (block > hitstun > corrida > normal). DevSpeed manda.
local function restoreWalkSpeed(player: Player)
	local state = states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not state or not humanoid or player:GetAttribute("DevSpeed") ~= nil then
		return
	end
	if state.blocking then
		humanoid.WalkSpeed = CombatConfig.Block.WalkSpeed
	elseif os.clock() < state.hitStunUntil then
		humanoid.WalkSpeed = CombatConfig.HitStun.WalkSpeed
	else
		humanoid.WalkSpeed = if player:GetAttribute("Sprinting") == true then CombatConfig.Sprint.Speed else CombatConfig.WalkSpeed
	end
end

--- Guarda atual com a regeneração aplicada preguiçosamente.
local function currentGuard(state: PlayerState): number
	local cfg = CombatConfig.Block
	local since = os.clock() - state.guardHitAt - cfg.GuardRegenDelay
	if since > 0 then
		state.guard = math.min(cfg.GuardMax, state.guard + since * cfg.GuardRegenPerSecond)
		state.guardHitAt = os.clock() - cfg.GuardRegenDelay -- evita somar o mesmo intervalo de novo
	end
	return state.guard
end

local function getState(player: Player): PlayerState
	local s = states[player]
	if not s then
		s = newState()
		states[player] = s
	end
	return s
end

-- ---------------------------------------------------------------------------
-- Block
-- ---------------------------------------------------------------------------

local tryActivateBlock: (Player) -> ()

local function setBlocking(player: Player, active: boolean)
	local state = getState(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if state.blocking == active then
		return
	end

	local now = os.clock()
	if active then
		local readyAt = math.max(state.blockReleased + CombatConfig.Block.Cooldown, state.stunnedUntil)
		if now < readyAt then
			-- Ainda em cooldown/stun: ativa sozinho quando liberar, se o botão continuar pressionado
			task.delay(readyAt - now + 0.01, tryActivateBlock, player)
			return
		end
		state.blocking = true
		state.blockStart = now
		if humanoid then
			humanoid.WalkSpeed = CombatConfig.Block.WalkSpeed
		end
	else
		state.blocking = false
		state.blockReleased = now
		restoreWalkSpeed(player)
	end

	if character then
		notifyBlock:FireAllClients(character, active)
	end
end

tryActivateBlock = function(player: Player)
	local state = states[player]
	if state and state.wantBlock and not state.blocking and HealthService.IsAlive(player.Character) then
		setBlocking(player, true)
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

--- Hitstun: interrompe o combo/ações da vítima por HitStun.Duration e freia o andar.
function CombatService.HitStun(player: Player)
	local state = getState(player)
	local cfg = CombatConfig.HitStun
	local now = os.clock()
	local until_ = now + cfg.Duration
	if until_ <= state.hitStunUntil then
		return -- já está em hitstun maior
	end
	state.hitStunUntil = until_
	state.stunnedUntil = math.max(state.stunnedUntil, until_)
	state.nextAttackAt = math.max(state.nextAttackAt, until_)
	state.combo = 1
	restoreWalkSpeed(player)
	task.delay(cfg.Duration + 0.01, function()
		if states[player] == state and os.clock() >= state.hitStunUntil then
			restoreWalkSpeed(player)
		end
	end)
	notifyCooldown:FireClient(player, "hit", cfg.Duration)
end

function CombatService.IsBlocking(player: Player): boolean
	return getState(player).blocking
end

function CombatService.IsStunned(player: Player): boolean
	return os.clock() < getState(player).stunnedUntil
end

-- ---------------------------------------------------------------------------
-- Ataque
-- ---------------------------------------------------------------------------

--- Resolve um acerto contra `victim` considerando block/parry e buffs.
--- Usado pelos socos e pelas habilidades (AbilityService).
--- Empurra a vítima na direção do atacante (aplicado no cliente dono da física; sem efeito de gameplay além do deslocamento).
function CombatService.Knockback(attackerChar: Model, victim: Model, speed: number, duration: number)
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	local aRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local vRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not victimPlayer or not aRoot or not vRoot then
		return
	end
	local flat = vRoot.Position - aRoot.Position
	flat = Vector3.new(flat.X, 0, flat.Z)
	local direction = if flat.Magnitude > 0.1 then flat.Unit else aRoot.CFrame.LookVector
	if AntiExploitService then
		AntiExploitService.Grace(victimPlayer, duration + 0.5)
	end
	notifyKnockback:FireClient(victimPlayer, direction, speed, duration)
end

function CombatService.ResolveHit(attacker: Player, attackerChar: Model, victim: Model, damage: number, allowParry: boolean?, knockback: { Speed: number, Duration: number }?)
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	local victimState = victimPlayer and states[victimPlayer]
	local kind = "hit"
	if AbilityService then
		damage *= AbilityService.GetDamageMultiplier(attacker)
		if victimPlayer then
			damage *= AbilityService.GetIncomingMultiplier(victimPlayer)
		end
	end
	local devMult = attacker:GetAttribute("DevDamageMult")
	if typeof(devMult) == "number" then
		damage *= devMult -- menu de desenvolvedor
	end
	local finalDamage = damage

	if victimState and victimState.blocking and victimPlayer then
		local blockAge = os.clock() - victimState.blockStart
		if allowParry ~= false and blockAge <= CombatConfig.Block.ParryWindow then
			kind = "parry"
			finalDamage = 0
			CombatService.Stun(attacker, CombatConfig.Block.ParryStun, "parried")
		else
			local guard = currentGuard(victimState) - damage
			victimState.guardHitAt = os.clock()
			if guard <= 0 then
				-- Guard break: o golpe entra cheio, block cai e a vítima fica atordoada
				kind = "guardbreak"
				finalDamage = damage
				victimState.guard = CombatConfig.Block.GuardMax
				victimState.wantBlock = false
				CombatService.Stun(victimPlayer, CombatConfig.Block.GuardBreakStun, "guardbreak")
			else
				kind = "blocked"
				victimState.guard = guard
				finalDamage = damage * CombatConfig.Block.DamageMultiplier
			end
		end
	end

	local dealt = 0
	if finalDamage > 0 then
		dealt = HealthService.ApplyDamage(victim, finalDamage, attacker)
		if dealt > 0 and AbilityService then
			AbilityService.OnHitDealt(attacker, victimPlayer)
		end
	end

	-- Finisher: 4º golpe (tem knockback) em alvo com pouca vida ou que morreu no golpe
	local kb = knockback
	if kind == "hit" and knockback and dealt > 0 then
		local humanoid = victim:FindFirstChildOfClass("Humanoid")
		local ratio = if humanoid and humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
		if ratio <= CombatConfig.Finisher.LowHealth then
			kind = "finisher"
			kb = CombatConfig.Finisher.Knockback
		end
	end
	if kind == "hit" and dealt > 0 and victimPlayer and HealthService.IsAlive(victim) then
		CombatService.HitStun(victimPlayer)
	end

	Log.debug(("[CombatService] %s -> %s: %s, dano %.1f"):format(attacker.Name, victim.Name, kind, dealt))
	notifyDamage:FireAllClients(attackerChar, victim, dealt, kind)
	if kb and (kind == "hit" or kind == "finisher") and HealthService.IsAlive(victim) then
		CombatService.Knockback(attackerChar, victim, kb.Speed, kb.Duration)
	end
end

--- Acerto de um NPC (boss) em um jogador: respeita block (sem parry), avisa os clientes e empurra.
function CombatService.ResolveNpcHit(attackerChar: Model, victim: Model, damage: number, knockback: { Speed: number, Duration: number }?): number
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	local victimState = victimPlayer and states[victimPlayer]
	local kind = "hit"
	if victimPlayer and AbilityService then
		damage *= AbilityService.GetIncomingMultiplier(victimPlayer)
	end
	if victimState and victimState.blocking then
		kind = "blocked"
		damage *= CombatConfig.Block.DamageMultiplier
	end
	local dealt = if damage > 0 then HealthService.ApplyDamage(victim, damage, nil) else 0
	if dealt > 0 and victimPlayer and AbilityService then
		AbilityService.OnHitTaken(victimPlayer)
	end
	if kind == "hit" and dealt > 0 and victimPlayer and HealthService.IsAlive(victim) then
		CombatService.HitStun(victimPlayer)
	end
	notifyDamage:FireAllClients(attackerChar, victim, dealt, kind)
	if knockback and kind == "hit" and HealthService.IsAlive(victim) then
		CombatService.Knockback(attackerChar, victim, knockback.Speed, knockback.Duration)
	end
	return dealt
end

local function onRequestAttack(player: Player, attackId: any)
	if not attackLimiter:Allow(player) then
		return
	end
	local state = getState(player)

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

	-- Atacar cancela o block (e a intenção; o jogador precisa apertar F de novo)
	state.wantBlock = false
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
			CombatService.ResolveHit(player, character, victim, damage, nil, if isFinisher then attackCfg.FinisherKnockback else nil)
		end
	end)
end

local function onRequestBlock(player: Player, active: any)
	if not blockLimiter:Allow(player) then
		return
	end
	local state = getState(player)
	if typeof(active) ~= "boolean" then
		return
	end
	if not HealthService.IsAlive(player.Character) or not HealthService.CanFight(player) then
		return
	end
	state.wantBlock = active
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
	notifyKnockback = Remotes.GetEvent(Remotes.Events.NotifyKnockback)
end

function CombatService.Start()
	local ok, result = pcall(require, script.Parent:WaitForChild("AbilityService"))
	if ok then
		AbilityService = result
	else
		warn("[CombatService] AbilityService indisponível; buffs/energia desligados: " .. tostring(result))
	end
	local ok2, anti = pcall(require, script.Parent:WaitForChild("AntiExploitService"))
	if ok2 then
		AntiExploitService = anti
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
