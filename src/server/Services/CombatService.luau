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
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))

local CombatService = {}

-- AbilityService depende deste módulo; é carregado tardiamente em Start() para evitar ciclo.
local AbilityService: any = nil

type PlayerState = {
	wantBlock: boolean, -- jogador está segurando o botão de block
	blocking: boolean,
	blockStart: number,
	blockReleased: number,
	nextAttackAt: number, -- os.clock() a partir do qual pode atacar
	stunnedUntil: number,
	hardStunUntil: number, -- parry/guard break/habilidade: nem o dash (Q) sai
	combo: number, -- índice do PRÓXIMO golpe (1..ComboLength)
	lastAttackAt: number,
	guard: number, -- guarda restante (CombatConfig.Block.GuardMax)
	guardHitAt: number, -- último golpe bloqueado (regen começa GuardRegenDelay depois)
	hitStunUntil: number,
	critUntil: number, -- parryou: próximo M1 até aqui é crítico
	critArmedUntil: number, -- 1º crítico saiu: parry+crítico até aqui = Black Flash
	lastRagdollHitAt: number, -- (vítima) último downslam que derrubou (RagdollOnce)
	superArmorUntil: number, -- agarrão/ult: não toma hitstun nem cai (dano entra normal)
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
		hardStunUntil = 0,
		combo = 1,
		lastAttackAt = -math.huge,
		guard = CombatConfig.Block.GuardMax,
		guardHitAt = -math.huge,
		hitStunUntil = 0,
		critUntil = 0,
		critArmedUntil = 0,
		lastRagdollHitAt = -math.huge,
		superArmorUntil = 0,
	}
end

--- WalkSpeed "certa" para o estado atual (block > hitstun > corrida > normal) × buff de velocidade
--- (Awakening). DevSpeed manda. Público: MovementService (corrida) e AbilityService (awakening) chamam.
local function restoreWalkSpeed(player: Player)
	local state = states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not state or not humanoid or player:GetAttribute("DevSpeed") ~= nil then
		return
	end
	local mult = if AbilityService then AbilityService.GetSpeedMultiplier(player) else 1
	if state.blocking then
		humanoid.WalkSpeed = CombatConfig.Block.WalkSpeed
	elseif os.clock() < state.hitStunUntil then
		humanoid.WalkSpeed = CombatConfig.HitStun.WalkSpeed
	else
		local base = if player:GetAttribute("Sprinting") == true then CombatConfig.Sprint.Speed else CombatConfig.WalkSpeed
		humanoid.WalkSpeed = base * mult
	end
end
CombatService.RestoreWalkSpeed = restoreWalkSpeed

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
		local readyAt = math.max(state.blockReleased + CombatConfig.Block.Cooldown, state.stunnedUntil, state.lastAttackAt + CombatConfig.Block.LockoutAfterAttack)
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
	state.hardStunUntil = math.max(state.hardStunUntil, until_)
	state.nextAttackAt = math.max(state.nextAttackAt, until_)
	if state.blocking then
		setBlocking(player, false)
	end
	notifyCooldown:FireClient(player, reason, seconds)
end

--- Solta o block (e a intenção) — usado ao cair em ragdoll.
function CombatService.CancelBlock(player: Player)
	local state = getState(player)
	state.wantBlock = false
	if state.blocking then
		setBlocking(player, false)
	end
end

--- Super armor: por `seconds` o jogador não entra em hitstun nem cai em ragdoll (agarrão em curso).
function CombatService.SetSuperArmor(player: Player, seconds: number)
	local state = getState(player)
	state.superArmorUntil = math.max(state.superArmorUntil, os.clock() + seconds)
end

function CombatService.HasSuperArmor(player: Player): boolean
	return os.clock() < getState(player).superArmorUntil
end

--- Hitstun: interrompe o combo/ações da vítima por HitStun.Duration e freia o andar.
function CombatService.HitStun(player: Player)
	local state = getState(player)
	local cfg = CombatConfig.HitStun
	local now = os.clock()
	if now < state.superArmorUntil then
		return
	end
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

--- Stun "duro" (parry, guard break, habilidade). Hitstun de soco NÃO conta: o dash sai dele.
function CombatService.IsHardStunned(player: Player): boolean
	return os.clock() < getState(player).hardStunUntil
end

-- ---------------------------------------------------------------------------
-- Ataque
-- ---------------------------------------------------------------------------

--- Resolve um acerto contra `victim` considerando block/parry e buffs.
--- Usado pelos socos e pelas habilidades (AbilityService).
--- Empurra a vítima para longe do atacante (aplicado no cliente dono da física). Com
--- `ragdollSeconds` a vítima também cai em ragdoll de combate (RagdollService) e perde o block.
export type Knockback = CombatConfig.Knockback
function CombatService.Knockback(attackerChar: Model, victim: Model, speed: number, duration: number, ragdollSeconds: number?, up: number?)
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	local aRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local vRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not victimPlayer or not aRoot or not vRoot then
		return
	end
	local flat = vRoot.Position - aRoot.Position
	flat = Vector3.new(flat.X, 0, flat.Z)
	local direction = if flat.Magnitude > 0.1 then flat.Unit else aRoot.CFrame.LookVector
	if CombatService.HasSuperArmor(victimPlayer) then
		return -- agarrando alguém: nem empurrão nem queda
	end
	if ragdollSeconds and ragdollSeconds > 0 then
		CombatService.CancelBlock(victimPlayer)
		RagdollService.Ragdoll(victimPlayer, ragdollSeconds)
		duration = math.max(duration, 0.3) -- corpo solto voa um pouco mais
	end
	if AntiExploitService then
		-- folga generosa: o corpo continua deslizando/voando depois do empurrão
		AntiExploitService.Grace(victimPlayer, duration + (ragdollSeconds or 0) + 2.0)
	end
	notifyKnockback:FireClient(victimPlayer, direction, speed, duration, up)
end

--- Block só cobre a frente: golpe vindo de trás (dot < FrontDot) entra como se não bloqueasse.
local function blockCovers(victim: Model, attackerChar: Model): boolean
	local vRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
	local aRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not vRoot or not aRoot then
		return true
	end
	local toAttacker = aRoot.Position - vRoot.Position
	toAttacker = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	if toAttacker.Magnitude < 0.1 then
		return true
	end
	local look = vRoot.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z).Unit:Dot(toAttacker.Unit) >= CombatConfig.Block.FrontDot
end

export type HitOptions = {
	IsM1: boolean?, -- soco: consome o crítico do parry
	BreaksBlock: boolean?, -- ignora o block (quem bloqueia toma guard break)
	RagdollOnce: boolean?, -- não derruba de novo quem já está caído (downslam)
}

--- Resolve um acerto contra `victim` considerando block (só frontal)/parry/crítico e buffs.
--- Retorna o `kind` ("hit"|"blocked"|"parry"|"guardbreak"|"finisher"|"crit"|"blackflash").
--- Usado pelos socos e pelas habilidades (AbilityService).
function CombatService.ResolveHit(attacker: Player, attackerChar: Model, victim: Model, damage: number, allowParry: boolean?, knockback: Knockback?, options: HitOptions?): string
	local opts: HitOptions = options or {}
	local attackerState = getState(attacker)
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	local victimState = victimPlayer and states[victimPlayer]
	local kind = "hit"
	local now = os.clock()
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

	-- Crítico do parry (só M1): ×3, ou Black Flash ×6 se for o 2º crítico seguido
	local critKind: string? = nil
	if opts.IsM1 and now < attackerState.critUntil then
		local cfg = CombatConfig.Critical
		if now < attackerState.critArmedUntil then
			critKind = "blackflash"
			damage *= cfg.BlackFlashMultiplier
			attackerState.critArmedUntil = 0
		else
			critKind = "crit"
			damage *= cfg.Multiplier
			attackerState.critArmedUntil = now + cfg.ChainWindow
		end
		attackerState.critUntil = 0
	elseif opts.IsM1 then
		attackerState.critArmedUntil = 0 -- soco normal no meio quebra a corrente do Black Flash
	end
	local finalDamage = damage

	-- NPC bloqueando (boneco de treino com atributo Blocking): só reduz, sem parry/guarda
	if not victimPlayer and victim:GetAttribute("Blocking") == true and not opts.BreaksBlock and blockCovers(victim, attackerChar) then
		kind = "blocked"
		finalDamage = damage * CombatConfig.Block.DamageMultiplier
	end

	if victimState and victimState.blocking and victimPlayer and blockCovers(victim, attackerChar) then
		local blockAge = now - victimState.blockStart
		if opts.BreaksBlock then
			-- Block breaker (downslam, habilidades marcadas): quem bloqueia toma guard break
			kind = "guardbreak"
			victimState.guard = CombatConfig.Block.GuardMax
			victimState.wantBlock = false
			CombatService.Stun(victimPlayer, CombatConfig.Block.GuardBreakStun, "guardbreak")
		elseif allowParry ~= false and blockAge <= CombatConfig.Block.ParryWindow then
			kind = "parry"
			finalDamage = 0
			CombatService.Stun(attacker, CombatConfig.Block.ParryStun, "parried")
			victimState.critUntil = now + CombatConfig.Critical.Window
			if AbilityService then
				AbilityService.OnParry(victimPlayer)
			end
			notifyCooldown:FireClient(victimPlayer, "crit_ready", CombatConfig.Critical.Window)
		else
			local guard = currentGuard(victimState) - damage
			victimState.guardHitAt = now
			if guard <= 0 then
				-- Guard break: o golpe entra cheio, block cai e a vítima fica atordoada
				kind = "guardbreak"
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
	if kind == "hit" and critKind and dealt > 0 then
		kind = critKind
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
	local landed = kind == "hit" or kind == "finisher" or kind == "crit" or kind == "blackflash"
	if landed and dealt > 0 and victimPlayer and HealthService.IsAlive(victim) then
		CombatService.HitStun(victimPlayer)
	end

	Log.debug(("[CombatService] %s -> %s: %s, dano %.1f"):format(attacker.Name, victim.Name, kind, dealt))
	notifyDamage:FireAllClients(attackerChar, victim, dealt, kind)
	if kb and (landed or kind == "guardbreak") and HealthService.IsAlive(victim) then
		local ragdoll = kb.Ragdoll
		if ragdoll and opts.RagdollOnce and victimPlayer and RagdollService.IsRagdolled(victimPlayer) then
			ragdoll = nil -- downslam em quem já está no chão: só o dano
		end
		CombatService.Knockback(attackerChar, victim, kb.Speed, kb.Duration, ragdoll, kb.Up)
	end
	return kind
end

--- Soco de NPC (boneco atacante): anima em todos (NotifyAttack) e, após o wind-up, acerta jogadores à
--- frente com ResolveNpcHit. `comboIndex` só para a animação/knockback do 4º.
function CombatService.NpcPunch(attackerChar: Model, comboIndex: number, damage: number)
	local cfg = CombatConfig.Attacks.M1
	notifyAttack:FireAllClients(attackerChar, "M1", comboIndex)
	task.delay(cfg.HitDelay, function()
		if not attackerChar.Parent or not HealthService.IsAlive(attackerChar) then
			return
		end
		local kb = if comboIndex >= cfg.ComboLength then cfg.FinisherKnockback else nil
		for _, victim in Hitbox.InFront(attackerChar, cfg.Range, cfg.Width, cfg.Height, cfg.MaxTargets) do
			CombatService.ResolveNpcHit(attackerChar, victim, damage, kb)
		end
	end)
end

--- Aviso de block de NPC para os clientes (contorno/animação).
function CombatService.NotifyNpcBlock(character: Model, active: boolean, player: Player?)
	if player then
		notifyBlock:FireClient(player, character, active)
	else
		notifyBlock:FireAllClients(character, active)
	end
end

--- Acerto de um NPC (boss) em um jogador: respeita block (sem parry), avisa os clientes e empurra.
function CombatService.ResolveNpcHit(attackerChar: Model, victim: Model, damage: number, knockback: Knockback?): number
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	local victimState = victimPlayer and states[victimPlayer]
	local kind = "hit"
	if victimPlayer and AbilityService then
		damage *= AbilityService.GetIncomingMultiplier(victimPlayer)
	end
	if victimState and victimState.blocking and blockCovers(victim, attackerChar) then
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
		CombatService.Knockback(attackerChar, victim, knockback.Speed, knockback.Duration, knockback.Ragdoll, knockback.Up)
	end
	return dealt
end

--- "ground" | "rising" | "falling" (mesma regra do cliente: CombatConfig.AirRisingSpeed)
local function airState(character: Model, humanoid: Humanoid): string
	local st = humanoid:GetState()
	local airborne = st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping or humanoid.FloorMaterial == Enum.Material.Air
	if not airborne then
		return "ground"
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local vy = if root then root.AssemblyLinearVelocity.Y else 0
	return (if vy > CombatConfig.AirRisingSpeed then "rising" else "falling") :: string
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
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or not HealthService.IsAlive(character) or not HealthService.CanFight(player) then
		return
	end

	local now = os.clock()
	if now < state.stunnedUntil or now < state.nextAttackAt or RagdollService.IsRagdolled(player) then
		return -- em cooldown/stun/ragdoll: ignorado silenciosamente
	end
	local dashingUntil = player:GetAttribute("DashingUntil")
	if typeof(dashingUntil) == "number" and now < dashingUntil then
		return -- no meio do dash (MovementService)
	end
	-- Downslam só caindo; uppercut só subindo (o cliente escolhe, o servidor confere)
	local air = airState(character, humanoid)
	local falling, rising = air == "falling", air == "rising"
	if (attackCfg.RequiresFalling and not falling) or (attackCfg.RequiresRising and not rising) then
		return
	end

	-- Atacar cancela o block (e a intenção; o jogador precisa apertar F de novo)
	state.wantBlock = false
	if state.blocking then
		setBlocking(player, false)
	end

	-- Combo (só o M1 tem); downslam/uppercut zeram o combo e têm espera própria
	local comboIndex = 1
	local isM1 = attackId == "M1"
	local damage: number
	local knockback: Knockback? = nil
	local isFinisher = false
	if isM1 then
		if now - state.lastAttackAt > attackCfg.ComboResetTime then
			state.combo = 1
		end
		comboIndex = state.combo
		isFinisher = comboIndex >= attackCfg.ComboLength
		damage = attackCfg.ComboDamage[comboIndex] or attackCfg.ComboDamage[#attackCfg.ComboDamage]
		state.nextAttackAt = now + (if isFinisher then attackCfg.ComboEndCooldown else attackCfg.Cooldown)
		state.combo = if isFinisher then 1 else comboIndex + 1
		if isFinisher then
			knockback = attackCfg.FinisherKnockback
		end
	else
		damage = attackCfg.Damage
		knockback = attackCfg.Knockback
		state.combo = 1
		state.nextAttackAt = now + attackCfg.Cooldown
	end
	state.lastAttackAt = now

	notifyAttack:FireAllClients(character, attackId, comboIndex)

	-- Wind-up: hitbox é checada depois do delay, com a posição de então
	task.delay(attackCfg.HitDelay, function()
		if player.Parent ~= Players or player.Character ~= character or not HealthService.IsAlive(character) then
			return
		end
		if os.clock() < state.stunnedUntil then
			return -- foi parryado/stunado durante o wind-up
		end
		local blocked = false
		for _, victim in Hitbox.InFront(character, attackCfg.Range, attackCfg.Width, attackCfg.Height, attackCfg.MaxTargets) do
			local kind = CombatService.ResolveHit(player, character, victim, damage, nil, knockback, {
				IsM1 = isM1,
				BreaksBlock = attackCfg.BreaksBlock == true,
				RagdollOnce = attackCfg.RagdollOnce == true,
			})
			if kind == "blocked" then
				blocked = true
			end
		end
		-- Bater no block custa: endlag dobrado até o próximo golpe
		if blocked and isM1 then
			local extra = (attackCfg.BlockedEndlagMultiplier - 1) * attackCfg.Cooldown
			state.nextAttackAt = math.max(state.nextAttackAt, os.clock()) + extra
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
	if active and RagdollService.IsRagdolled(player) then
		return -- caído: sem block (o botão precisa ser apertado de novo ao levantar)
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
