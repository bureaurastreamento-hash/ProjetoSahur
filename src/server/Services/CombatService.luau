--!strict
--[[
	CombatService (servidor)
	Autoridade sobre golpes, cooldowns, combo, block e parry.
	O cliente envia RequestAttack(attackId, vítimas vistas por ele) / RequestBlock(active). A hitbox
	do servidor é só tolerância (CombatConfig.HitValidation): descarta quem não está à frente/perto.
	A hitbox é calculada AQUI, a partir da posição do atacante no servidor;
	nada que o cliente envie sobre "quem acertei" é aceito.
	Lutador = Combatant.Fighter (Player ou BOT do BotService): o estado é por lutador, o que é de cliente
	(NotifyCooldown, AntiExploit, conquistas) só acontece para Player. Bots entram pelos mesmos caminhos
	via CombatService.Attack(bot, "M1") / CombatService.Block(bot, on); knockback/ragdoll deles é simulado
	pelo servidor (ramo NPC: atributo Npc).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local Hitbox = require(Modules:WaitForChild("Hitbox"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local Combatant = require(Modules:WaitForChild("Combatant"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))

local CombatService = {}

type Fighter = Combatant.Fighter

-- AbilityService depende deste módulo; é carregado tardiamente em Start() para evitar ciclo.
local ProgressionService: any = nil -- carregado no Start (evita ciclo Cosmetics→Combat→Progression)
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
	comboArmorUntil: number, -- acabou de acertar um M1: soco simples de TERCEIRO não interrompe o combo
	comboTargetUserId: number, -- em quem o combo está entrando (o alvo em hitstun não bate mesmo)
	attackingUntil: number, -- soco em execução (HitDelay + recuo): sem dash/habilidade até aqui (ação individual)
	endlagUntil: number, -- depois do 4º M1: anda lento (ComboEndSlow)
}

local states: { [Instance]: PlayerState } = {} -- por lutador (Player ou Model de bot)

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
		comboArmorUntil = 0,
		comboTargetUserId = 0,
		attackingUntil = 0,
		endlagUntil = 0,
	}
end

--- WalkSpeed "certa" para o estado atual (block > hitstun > corrida > normal) × buff de velocidade
--- (Awakening). DevSpeed manda. Público: MovementService (corrida) e AbilityService (awakening) chamam.
local function restoreWalkSpeed(player: Fighter)
	local state = states[player]
	local character = Combatant.CharacterOf(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not state or not humanoid or player:GetAttribute("DevSpeed") ~= nil then
		return
	end
	local mult = if AbilityService then AbilityService.GetSpeedMultiplier(player) else 1
	local cutsceneUntil = player:GetAttribute("CutsceneUntil")
	if typeof(cutsceneUntil) == "number" and Workspace:GetServerTimeNow() < cutsceneUntil then
		humanoid.WalkSpeed = 0 -- cutscene (despertar): parado
	elseif state.blocking then
		humanoid.WalkSpeed = CombatConfig.Block.WalkSpeed
	elseif os.clock() < state.hitStunUntil then
		humanoid.WalkSpeed = CombatConfig.HitStun.WalkSpeed
	elseif os.clock() < state.endlagUntil then
		humanoid.WalkSpeed = CombatConfig.Attacks.M1.ComboEndSlow.WalkSpeed
	else
		local formSpeed = character and character:GetAttribute("WalkSpeed")
		local base = if typeof(formSpeed) == "number" then formSpeed
			elseif player:GetAttribute("Sprinting") == true then CombatConfig.Sprint.Speed
			else CombatConfig.WalkSpeed
		local timeSlow = player:GetAttribute("TimeSlow") -- Domínio do Tempo (AbilityService)
		if typeof(timeSlow) == "number" then
			mult *= timeSlow
		end
		local modMult = player:GetAttribute("ModSpeedMult") -- mod de sala (ModService, servidor privado)
		if typeof(modMult) == "number" and modMult > 0 then
			mult *= modMult
		end
		humanoid.WalkSpeed = base * mult
	end
end
CombatService.RestoreWalkSpeed = restoreWalkSpeed

--- Segura o jogador no lugar por `seconds` (cena de emote, carregando um agarrão): WalkSpeed 0 via
--- CutsceneUntil, sem pulo, sem agir (Stun). Não dá i-frames: quem leva porrada durante sai da cena.
--- Dono (2026-09-20): "em cutscenes de emotes/ataques estou conseguindo me mover".
function CombatService.HoldStill(player: Fighter, seconds: number, reason: string)
	local character = Combatant.CharacterOf(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or seconds <= 0 then
		return
	end
	local untilT = Workspace:GetServerTimeNow() + seconds
	local current = player:GetAttribute("CutsceneUntil")
	if typeof(current) ~= "number" or current < untilT then
		player:SetAttribute("CutsceneUntil", untilT)
	end
	CombatService.Stun(player, seconds, reason)
	restoreWalkSpeed(player)
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	task.delay(seconds, function()
		if humanoid.Parent then
			local now = player:GetAttribute("CutsceneUntil")
			if typeof(now) ~= "number" or Workspace:GetServerTimeNow() >= now - 0.05 then
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
				restoreWalkSpeed(player)
			end
		end
	end)
end

--- Gancho "o jogador AGIU" (soco, habilidade, dash, levou/deu golpe): CosmeticsService cancela o emote
--- em loop (sentar etc.). Registrado no Start dele para não criar ciclo de require.
CombatService.ActionHook = nil :: ((Player) -> ())?
function CombatService.NotifyAction(player: Fighter)
	local hook = CombatService.ActionHook
	local asPlayer = Combatant.PlayerOf(player)
	if hook and asPlayer then
		hook(asPlayer)
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

local function getState(player: Fighter): PlayerState
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

local tryActivateBlock: (Fighter) -> ()

local function setBlocking(player: Fighter, active: boolean)
	local state = getState(player)
	local character = Combatant.CharacterOf(player)
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

tryActivateBlock = function(player: Fighter)
	local state = states[player]
	if state and state.wantBlock and not state.blocking and HealthService.IsAlive(Combatant.CharacterOf(player)) then
		setBlocking(player, true)
	end
end

--- Impede o jogador de atacar/bloquear por `seconds`. Usado por parry e habilidades.
function CombatService.Stun(player: Fighter, seconds: number, reason: string)
	local state = getState(player)
	local until_ = os.clock() + seconds
	state.stunnedUntil = math.max(state.stunnedUntil, until_)
	state.hardStunUntil = math.max(state.hardStunUntil, until_)
	state.nextAttackAt = math.max(state.nextAttackAt, until_)
	if state.blocking then
		setBlocking(player, false)
	end
	Combatant.Notify(player, notifyCooldown, reason, seconds)
end

--- Tira o stun/hitstun agora (Heal com Cleanse, Rewind).
function CombatService.ClearStun(player: Fighter)
	local state = getState(player)
	local now = os.clock()
	state.stunnedUntil = math.min(state.stunnedUntil, now)
	state.hardStunUntil = math.min(state.hardStunUntil, now)
	state.hitStunUntil = math.min(state.hitStunUntil, now)
	restoreWalkSpeed(player)
end

--- Solta o block (e a intenção) — usado ao cair em ragdoll.
function CombatService.CancelBlock(player: Fighter)
	local state = getState(player)
	state.wantBlock = false
	if state.blocking then
		setBlocking(player, false)
	end
end

--- Super armor: por `seconds` o jogador não entra em hitstun nem cai em ragdoll (agarrão em curso).
function CombatService.SetSuperArmor(player: Fighter, seconds: number)
	local state = getState(player)
	state.superArmorUntil = math.max(state.superArmorUntil, os.clock() + seconds)
end

function CombatService.HasSuperArmor(player: Fighter): boolean
	return os.clock() < getState(player).superArmorUntil
end

--- Hitstun: interrompe o combo/ações da vítima por HitStun.Duration e freia o andar.
function CombatService.HitStun(player: Fighter)
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
	Combatant.Notify(player, notifyCooldown, "hit", cfg.Duration)
end

function CombatService.IsBlocking(player: Fighter): boolean
	return getState(player).blocking
end

function CombatService.IsStunned(player: Fighter): boolean
	return os.clock() < getState(player).stunnedUntil
end

--- Stun "duro" (parry, guard break, habilidade). Hitstun de soco NÃO conta: o dash sai dele.
function CombatService.IsHardStunned(player: Fighter): boolean
	return os.clock() < getState(player).hardStunUntil
end

--- Soco em execução (do pedido até o fim do recuo): dash/habilidade não saem (ação individual, dono 2026-09-21).
function CombatService.IsAttacking(player: Fighter): boolean
	return os.clock() < getState(player).attackingUntil
end

--- Domínio do Tempo: quem está lento (TimeSlow < 1) não age (CombatConfig.TimeSlowBlocksActions).
function CombatService.IsTimeSlowed(player: Fighter): boolean
	if not CombatConfig.TimeSlowBlocksActions then
		return false
	end
	local t = player:GetAttribute("TimeSlow")
	return typeof(t) == "number" and t > 0 and t < 1
end

-- ---------------------------------------------------------------------------
-- Ataque
-- ---------------------------------------------------------------------------

--- Resolve um acerto contra `victim` considerando block/parry e buffs.
--- Usado pelos socos e pelas habilidades (AbilityService).
--- Empurra a vítima para longe do atacante (aplicado no cliente dono da física). Com
--- `ragdollSeconds` a vítima também cai em ragdoll de combate (RagdollService) e perde o block.
export type Knockback = CombatConfig.Knockback
--- `directionOverride` (horizontal unitária) substitui a direção atacante→vítima (ex.: soltar na tangente).
function CombatService.Knockback(attackerChar: Model, victim: Model, speed: number, duration: number, ragdollSeconds: number?, up: number?, directionOverride: Vector3?)
	local victimFighter = Combatant.Of(victim)
	local victimPlayer = Combatant.PlayerOf(victimFighter)
	local aRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local vRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not aRoot or not vRoot then
		return
	end
	local flat = vRoot.Position - aRoot.Position
	flat = Vector3.new(flat.X, 0, flat.Z)
	local direction = if directionOverride then directionOverride elseif flat.Magnitude > 0.1 then flat.Unit else aRoot.CFrame.LookVector
	if not victimFighter and victim:GetAttribute("Npc") ~= true then
		return -- NPC sem física de combate (boss por peças, NPC de quest)
	end
	if victimFighter and CombatService.HasSuperArmor(victimFighter) then
		return -- agarrando alguém: nem empurrão nem queda
	end
	-- teto de distância (CombatConfig.KnockbackMaxTravelDashMultiple × alcance do dash frontal)
	local dashReach = CombatConfig.Dash.Speed * CombatConfig.Dash.Duration * CharacterDefs.DashTuning.ForwardScale
	local maxTravel = dashReach * CombatConfig.KnockbackMaxTravelDashMultiple
	if speed > 0 and speed * duration > maxTravel then
		duration = maxTravel / speed
	end
	if ragdollSeconds and ragdollSeconds > 0 then
		if victimFighter then
			CombatService.CancelBlock(victimFighter)
			RagdollService.Ragdoll(victimFighter, ragdollSeconds)
		else
			RagdollService.RagdollModel(victim, ragdollSeconds)
		end
		duration = math.max(duration, 0.3) -- corpo solto voa um pouco mais
	end
	if victimPlayer then
		if AntiExploitService then
			-- folga generosa: o corpo continua deslizando/voando depois do empurrão
			AntiExploitService.Grace(victimPlayer, duration + (ragdollSeconds or 0) + 2.0)
		end
		notifyKnockback:FireClient(victimPlayer, direction, speed, duration, up)
		return
	end
	-- bot / NPC (boneco, traidor): o servidor simula — velocidade em todas as partes
	local velocity = direction * speed + Vector3.new(0, up or 8, 0)
	for _, part in victim:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			part.AssemblyLinearVelocity = velocity
		end
	end
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

--- Vítima está BLOQUEANDO de frente para o atacante? (AbilityService: agarrão não pega quem bloqueia)
function CombatService.IsBlockingAgainst(victim: Model, attackerChar: Model): boolean
	local victimFighter = Combatant.Of(victim)
	local st = victimFighter and states[victimFighter]
	if st and st.blocking then
		return blockCovers(victim, attackerChar)
	end
	return victim:GetAttribute("Blocking") == true and blockCovers(victim, attackerChar)
end

export type HitOptions = {
	IsM1: boolean?, -- soco: consome o crítico do parry
	BreaksBlock: boolean?, -- ignora o block (quem bloqueia toma guard break)
	RagdollOnce: boolean?, -- não derruba de novo quem já está caído (downslam)
	KnockbackDirection: Vector3?, -- horizontal unitária; substitui atacante→vítima (agarrão giratório)
	AttackStartedAt: number?, -- os.clock() em que o golpe COMEÇOU (clique do atacante): o parry precisa de block anterior
}

--- Resolve um acerto contra `victim` considerando block (só frontal)/parry/crítico e buffs.
--- Retorna o `kind` ("hit"|"blocked"|"parry"|"guardbreak"|"finisher"|"crit"|"blackflash").
--- Usado pelos socos e pelas habilidades (AbilityService).
function CombatService.ResolveHit(attacker: Fighter, attackerChar: Model, victim: Model, damage: number, allowParry: boolean?, knockback: Knockback?, options: HitOptions?): string
	local opts: HitOptions = options or {}
	local attackerState = getState(attacker)
	local victimFighter = Combatant.Of(victim) -- Player ou bot; nil = NPC (boneco/boss/traidor)
	local victimPlayer = Combatant.PlayerOf(victimFighter)
	local victimState = victimFighter and states[victimFighter]
	if victimFighter then
		CombatService.NotifyAction(victimFighter) -- ser atacado cancela emote em loop
	end
	local kind = "hit"
	local now = os.clock()
	if CombatConfig.NoM1OnRagdolled and opts.IsM1 and victimFighter and RagdollService.IsRagdolled(victimFighter) then
		-- deitado: o soco simples passa por cima (dono, 2026-09-21); downslam/habilidades continuam
		notifyDamage:FireAllClients(attackerChar, victim, 0, "immune")
		return "immune"
	end
	if AbilityService then
		damage *= AbilityService.GetDamageMultiplier(attacker)
		if victimFighter then
			damage *= AbilityService.GetIncomingMultiplier(victimFighter)
		end
	end
	local devMult = attacker:GetAttribute("DevDamageMult")
	if typeof(devMult) == "number" then
		damage *= devMult -- menu de desenvolvedor
	end
	local npcMult = attacker:GetAttribute("DamageMult")
	if typeof(npcMult) == "number" then
		damage *= npcMult -- bot especial (traidor: TraitorService) — vale para soco e habilidade
	end
	local formMult = attacker:GetAttribute("FormDamageMult")
	if typeof(formMult) == "number" and opts.IsM1 then
		damage *= formMult -- forma de boss (BossFormService): socos pesados
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
	if not victimFighter and victim:GetAttribute("Blocking") == true and not opts.BreaksBlock and blockCovers(victim, attackerChar) then
		kind = "blocked"
		finalDamage = damage * CombatConfig.Block.DamageMultiplier
	end

	if victimState and victimState.blocking and victimFighter and blockCovers(victim, attackerChar) then
		local blockAge = now - victimState.blockStart
		if opts.BreaksBlock then
			-- Block breaker (downslam, habilidades marcadas): quem bloqueia toma guard break
			kind = "guardbreak"
			victimState.guard = CombatConfig.Block.GuardMax
			victimState.wantBlock = false
			CombatService.Stun(victimFighter, CombatConfig.Block.GuardBreakStun, "guardbreak")
		elseif allowParry ~= false and (function(): boolean
				-- Parry = block começado ANTES de o golpe sair (até ParryLateTolerance depois) e no máximo
				-- ParryWindow antes dele. Sem AttackStartedAt (habilidade sem wind-up) vale a janela antiga.
				local startedAt = opts.AttackStartedAt
				if typeof(startedAt) ~= "number" then
					return blockAge <= CombatConfig.Block.ParryWindow
				end
				local lead = startedAt - victimState.blockStart -- >0 = bloqueou antes do golpe
				return lead >= -CombatConfig.Block.ParryLateTolerance and lead <= CombatConfig.Block.ParryWindow
			end)() then
			kind = "parry"
			finalDamage = 0
			CombatService.Stun(attacker, CombatConfig.Block.ParryStun, "parried")
			victimState.critUntil = now + CombatConfig.Critical.Window
			if ProgressionService and victimPlayer then
				ProgressionService.Progress(victimPlayer, "parries", 1) -- conquistas/quests
			end
			if AbilityService then
				AbilityService.OnParry(victimFighter)
			end
			Combatant.Notify(victimFighter, notifyCooldown, "crit_ready", CombatConfig.Critical.Window)
		else
			local guard = currentGuard(victimState) - damage
			victimState.guardHitAt = now
			if guard <= 0 then
				-- Guard break: o golpe entra cheio, block cai e a vítima fica atordoada
				kind = "guardbreak"
				victimState.guard = CombatConfig.Block.GuardMax
				victimState.wantBlock = false
				CombatService.Stun(victimFighter, CombatConfig.Block.GuardBreakStun, "guardbreak")
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
		if dealt > 0 then
			HealthService.MarkInCombat(attacker) -- quem ATACA também não troca de personagem (dono, 2026-09-21)
		end
		if dealt > 0 and AbilityService then
			AbilityService.OnHitDealt(attacker, victimFighter, victim, opts.IsM1 == true)
		end
		if dealt == 0 and HealthService.IsInvulnerable(victim, attacker) and HealthService.IsAlive(victim) then
			-- Invencível (cutscene, i-frames, agarrando/preso em agarrão): nem dano, nem hitstun, nem empurrão.
			notifyDamage:FireAllClients(attackerChar, victim, 0, "immune")
			return "immune"
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
	if landed and dealt > 0 and victimFighter and HealthService.IsAlive(victim) then
		-- Prioridade do combo (dono, 2026-09-16): quem está no meio do combo de M1 (acertou há pouco e
		-- ainda tem golpe vindo) não é interrompido pelo soco simples de um terceiro — o dano entra,
		-- o hitstun não. Golpes com empurrão (4º, uppercut, habilidades) interrompem normalmente.
		local plainM1 = opts.IsM1 and knockback == nil
		local comboArmor = plainM1 and victimState ~= nil and now < victimState.comboArmorUntil
			and victimState.comboTargetUserId ~= Combatant.UserId(attacker)
		if not comboArmor then
			CombatService.HitStun(victimFighter)
		end
	end
	if landed and dealt > 0 and opts.IsM1 and knockback == nil and victimFighter then
		local m1 = CombatConfig.Attacks.M1
		attackerState.comboArmorUntil = now + m1.Cooldown + m1.HitDelay + 0.2 -- até o próximo golpe sair
		attackerState.comboTargetUserId = Combatant.UserId(victimFighter)
	end

	Log.debug(("[CombatService] %s -> %s: %s, dano %.1f"):format(attacker.Name, victim.Name, kind, dealt))
	notifyDamage:FireAllClients(attackerChar, victim, dealt, kind)
	if kb and (landed or kind == "guardbreak") and HealthService.IsAlive(victim) then
		local ragdoll = kb.Ragdoll
		if ragdoll and opts.RagdollOnce and victimFighter and RagdollService.IsRagdolled(victimFighter) then
			ragdoll = nil -- downslam em quem já está no chão: só o dano
		end
		-- Wall splat: vai cair contra uma parede próxima na direção do empurrão
		if ragdoll and victimFighter then
			local ws = CombatConfig.WallSplat
			local aRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			local vRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
			if aRoot and vRoot then
				local dir = opts.KnockbackDirection or (vRoot.Position - aRoot.Position)
				dir = Vector3.new(dir.X, 0, dir.Z)
				if dir.Magnitude > 0.1 then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { victim, attackerChar }
					params.RespectCanCollide = true
					local hit = Workspace:Raycast(vRoot.Position, dir.Unit * ws.Distance, params)
					if hit and hit.Instance.Anchored and math.abs(hit.Normal.Y) < 0.5 then
						local extra = HealthService.ApplyDamage(victim, ws.Damage, attacker)
						ragdoll += ws.ExtraRagdoll
						notifyDamage:FireAllClients(attackerChar, victim, extra, "wallsplat")
						Log.debug(("[CombatService] %s: wall splat em %s"):format(attacker.Name, victim.Name))
					end
				end
			end
		end
		CombatService.Knockback(attackerChar, victim, kb.Speed, kb.Duration, ragdoll, kb.Up, opts.KnockbackDirection)
	end
	return kind
end

--- Soco de NPC (boneco atacante): anima em todos (NotifyAttack) e, após o wind-up, acerta jogadores à
--- frente com ResolveNpcHit. `comboIndex` só para a animação/knockback do 4º.
function CombatService.NpcPunch(attackerChar: Model, comboIndex: number, damage: number)
	if CombatService.IsGrabbed(attackerChar) then
		return
	end
	local cfg = CombatConfig.Attacks.M1
	notifyAttack:FireAllClients(attackerChar, "M1", comboIndex)
	task.delay(cfg.HitDelay, function()
		if not attackerChar.Parent or not HealthService.IsAlive(attackerChar) or CombatService.IsGrabbed(attackerChar) then
			return -- morreu ou foi AGARRADO no wind-up: o soco não sai
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

--- Preso num agarrão (AbilityService.attachVictim põe o atributo): não soca, não bloqueia, não usa nada.
function CombatService.IsGrabbed(character: Model?): boolean
	return character ~= nil and character:GetAttribute("Grabbed") == true
end

--- Gancho: um NPC (boss/traidor/boneco) acertou `victim` (BotService: bot passivo revida contra o NPC).
CombatService.NpcHitHook = nil :: ((attackerChar: Model, victim: Model, dealt: number) -> ())?

--- Acerto de um NPC (boss) em um jogador: respeita block (sem parry), avisa os clientes e empurra.
function CombatService.ResolveNpcHit(attackerChar: Model, victim: Model, damage: number, knockback: Knockback?): number
	local victimPlayer = Combatant.Of(victim) -- Player ou bot
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
	if dealt == 0 and damage > 0 and HealthService.IsInvulnerable(victim, nil) then
		notifyDamage:FireAllClients(attackerChar, victim, 0, "immune")
		return 0 -- cutscene/i-frames/agarrão: o NPC também não empurra
	end
	if dealt > 0 and victimPlayer and AbilityService then
		AbilityService.OnHitTaken(victimPlayer)
	end
	local hook = CombatService.NpcHitHook
	if dealt > 0 and hook then
		hook(attackerChar, victim, dealt)
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

--- Vítimas aceitas: as que o cliente do atacante viu (claimed) E que estão na caixa tolerante do servidor.
--- Sem lista do cliente (client antigo/mobile sem hitbox local) cai na hitbox estrita do servidor.
local function resolveVictims(character: Model, attackCfg: any, claimed: any): { Model }
	if typeof(claimed) ~= "table" then
		return Hitbox.InFront(character, attackCfg.Range, attackCfg.Width, attackCfg.Height, attackCfg.MaxTargets)
	end
	local v = CombatConfig.HitValidation
	local allowed: { [Model]: boolean } = {}
	for _, m in Hitbox.InFront(character, attackCfg.Range * v.RangeScale, attackCfg.Width * v.WidthScale, attackCfg.Height * v.HeightScale, attackCfg.MaxTargets + v.ExtraTargets) do
		allowed[m] = true
	end
	local victims: { Model } = {}
	local seen: { [Model]: boolean } = {}
	for i = 1, math.min(#claimed, attackCfg.MaxTargets + v.ExtraTargets) do
		local m = claimed[i]
		if typeof(m) == "Instance" and m:IsA("Model") and allowed[m] and not seen[m] then
			seen[m] = true
			table.insert(victims, m)
			if #victims >= attackCfg.MaxTargets then
				break
			end
		end
	end
	return victims
end

local function onRequestAttack(player: Fighter, attackId: any, claimed: any)
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
	CombatService.NotifyAction(player) -- atacar cancela emote em loop

	local character = Combatant.CharacterOf(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or not HealthService.IsAlive(character) or not HealthService.CanFight(player) then
		return
	end

	local now = os.clock()
	if now < state.stunnedUntil or now < state.nextAttackAt or RagdollService.IsRagdolled(player) or CombatService.IsGrabbed(character) then
		return -- em cooldown/stun/ragdoll/agarrado: ignorado silenciosamente
	end
	if CombatService.IsTimeSlowed(player) then
		return -- dentro do Domínio do Tempo: não soca (dono, 2026-09-21)
	end
	local dashingUntil = player:GetAttribute("DashingUntil")
	if typeof(dashingUntil) == "number" and now < dashingUntil then
		-- no meio do dash (MovementService): só o LATERAL, nos últimos SidePunchWindow s, deixa o soco sair
		local sideEnd = player:GetAttribute("DashKind") == "side" and now >= dashingUntil - CombatConfig.Dash.SidePunchWindow
		if not sideEnd or attackId ~= "M1" then
			return
		end
	end
	-- Uppercut só como 4º GOLPE do combo (no lugar do finisher com empurrão); o Downslam é livre no ar
	-- caindo (dono 2026-09-17: é o par do uppercut), com o cooldown próprio segurando o ritmo.
	local m1 = CombatConfig.Attacks.M1
	if attackId ~= "M1" and attackId ~= "Downslam" then
		local comboAlive = now - state.lastAttackAt <= m1.ComboResetTime
		if not comboAlive or state.combo < m1.ComboLength then
			return
		end
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
	-- ação individual: até o recuo acabar não sai dash nem habilidade
	state.attackingUntil = now + attackCfg.Cooldown
	if isM1 and isFinisher then
		-- endlag do 4º golpe: anda lento (o cooldown longo já segura o soco)
		state.endlagUntil = now + attackCfg.ComboEndSlow.Seconds
		restoreWalkSpeed(player)
		task.delay(attackCfg.ComboEndSlow.Seconds + 0.02, function()
			if states[player] == state then
				restoreWalkSpeed(player)
			end
		end)
	end
	-- 3º golpe levanta um pouco (favorece o combo)
	local lift = attackCfg.ComboLift
	if isM1 and lift and comboIndex == lift.Index then
		knockback = lift.Knockback
	end
	-- 4º golpe é PESADO para o cenário: DestructionService solta o dobro de tijolos (HeavyHitUntil)
	if isM1 and isFinisher then
		character:SetAttribute("HeavyHitUntil", Workspace:GetServerTimeNow() + 0.5)
	end

	-- O cliente já esperou o wind-up (HitDelay) antes de pedir, animando na hora do clique: o cooldown
	-- conta a partir do clique, e a hitbox é resolvida agora (vítimas vistas pelo cliente × caixa tolerante).
	state.nextAttackAt = math.max(now, state.nextAttackAt - attackCfg.HitDelay)
	-- Domínio do Tempo: quem está lento espera proporcionalmente mais entre golpes
	local timeSlow = player:GetAttribute("TimeSlow")
	if typeof(timeSlow) == "number" and timeSlow > 0 and timeSlow < 1 then
		state.nextAttackAt = now + (state.nextAttackAt - now) / timeSlow
	end

	-- 4º arg: golpe CRÍTICO armado (parryou antes) — os clientes tocam a animação de crítico no lugar do M1
	notifyAttack:FireAllClients(character, attackId, comboIndex, attackId == "M1" and now < state.critUntil)

	do
		local blocked = false
		for _, victim in resolveVictims(character, attackCfg, claimed) do
			local kind = CombatService.ResolveHit(player, character, victim, damage, nil, knockback, {
				IsM1 = isM1,
				BreaksBlock = attackCfg.BreaksBlock == true,
				RagdollOnce = attackCfg.RagdollOnce == true,
				AttackStartedAt = now - attackCfg.HitDelay, -- o clique foi HitDelay antes do pedido
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
	end
end

--- Bot/DEV: mesmo caminho do clique do jogador (validação, combo, cooldown, hitbox ESTRITA do servidor).
function CombatService.Attack(fighter: Fighter, attackId: string)
	onRequestAttack(fighter, attackId, nil)
end

local function onRequestBlock(player: Fighter, active: any)
	if not blockLimiter:Allow(player) then
		return
	end
	local state = getState(player)
	if typeof(active) ~= "boolean" then
		return
	end
	if not HealthService.IsAlive(Combatant.CharacterOf(player)) or not HealthService.CanFight(player) then
		return
	end
	if active and (RagdollService.IsRagdolled(player) or CombatService.IsGrabbed(Combatant.CharacterOf(player))) then
		return -- caído/agarrado: sem block (o botão precisa ser apertado de novo ao levantar)
	end
	state.wantBlock = active
	setBlocking(player, active)
end

--- Bot/DEV: mesmo caminho do F do jogador.
function CombatService.Block(fighter: Fighter, active: boolean)
	onRequestBlock(fighter, active)
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
	pcall(function()
		ProgressionService = (require :: any)(script.Parent:FindFirstChild("ProgressionService")) -- FindFirstChild: o analisador não vê ciclo
	end)
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
	-- bots: estado por Model (respawn = Model novo)
	local CollectionService = game:GetService("CollectionService")
	CollectionService:GetInstanceRemovedSignal(Combatant.BotTag):Connect(function(model)
		states[model] = nil
	end)
end

return CombatService
