--!strict
--[[
	CombatConfig
	Números do combate. Lido pelo servidor (autoridade) e pelo cliente (só feedback/timing).
	Rig alvo: R6.
]]

local CombatConfig = {}

--- Empurrão: Speed/Duration horizontais; Ragdoll = segundos caído; Up = velocidade vertical (uppercut).
export type Knockback = { Speed: number, Duration: number, Ragdoll: number?, Up: number? }

CombatConfig.MaxHealth = 100
CombatConfig.RespawnTime = 3
CombatConfig.WalkSpeed = 16

-- Regeneração fora de combate (substitui o script Health padrão do Roblox)
CombatConfig.Regen = {
	Delay = 6, -- segundos sem tomar dano para começar a regenerar
	PerSecond = 3,
}

-- Ataques disponíveis. Chave = attackId enviado pelo cliente em RequestAttack.
-- Ar: velocidade vertical do HRP > AirRisingSpeed = subindo (uppercut); no ar e não subindo = caindo (downslam).
-- Dano em % da vida (100 HP): combo de 4 = 15% (ref. TSB); o resto vem das habilidades.
CombatConfig.AirRisingSpeed = 5
CombatConfig.Attacks = {
	M1 = {
		ComboDamage = { 3, 3, 4, 5 }, -- dano de cada golpe do combo (índice = golpe)
		ComboLength = 4,
		Cooldown = 0.3, -- entre golpes do combo
		ComboEndCooldown = 1.2, -- depois do finisher ("downtime")
		ComboResetTime = 1.2, -- sem golpear por esse tempo, combo volta pro 1
		HitDelay = 0.15, -- tempo entre o pedido e a checagem da hitbox (wind-up)
		BlockedEndlagMultiplier = 2, -- M1 bloqueado = o dobro de espera até o próximo (punição)
		PullStuds = 1.0, -- acerto puxa o atacante em direção à vítima (cliente)
		-- Hitbox (studs) à frente do HumanoidRootPart do atacante
		Range = 7,
		Width = 5,
		Height = 6,
		MaxTargets = 3,
		FinisherKnockback = { Speed = 45, Duration = 0.2, Ragdoll = 1.2 } :: Knockback, -- empurrão + ragdoll no 4º golpe
	},
	-- Soco CAINDO (no ar, já descendo): ignora block, esmaga no chão (ragdoll). Não repete no mesmo ragdoll.
	Downslam = {
		Damage = 5,
		RequiresFalling = true,
		BreaksBlock = true,
		Cooldown = 1.2, -- espera depois (e zera o combo)
		HitDelay = 0.12,
		Range = 7,
		Width = 6,
		Height = 8,
		MaxTargets = 3,
		Knockback = { Speed = 10, Duration = 0.15, Ragdoll = 1.2 } :: Knockback,
		RagdollOnce = true,
	},
	-- Soco SUBINDO (logo depois de pular): levanta o alvo e o atacante junto (segue no ar -> downslam).
	Uppercut = {
		Damage = 4,
		RequiresRising = true,
		Cooldown = 0.9,
		HitDelay = 0.12,
		Range = 6,
		Width = 5,
		Height = 7,
		MaxTargets = 3,
		Knockback = { Speed = 8, Duration = 0.3, Up = 42 } :: Knockback,
		AttackerUp = 42, -- o atacante também sobe (cliente)
	},
}

-- Dash UNIVERSAL (Q, todo personagem; MovementService/MovementController). Sem dano.
-- Direção = WASD (frente do boneco se parado). Frente = fechar distância (cooldown maior);
-- lados/trás = esquiva (cooldown curto). Pode usar durante hitstun (é a saída defensiva), não
-- durante stun "duro" (parry/guard break). Q enquanto ragdollado = ragdoll cancel (abaixo).
CombatConfig.Dash = {
	Speed = 70,
	Duration = 0.22, -- base; CharacterDefs.DashTuning escala frente/lado
	ForwardCooldown = 4.5,
	SideCooldown = 2.0, -- lados e trás
	ForwardDot = 0.5, -- direção·frente do boneco acima disso = dash frontal
}

-- Ragdoll de combate: cai por `seconds` (juntas soltas, sem agir), permite follow-ups.
-- Fontes: 4º M1 (FinisherKnockback.Ragdoll), finisher, habilidades com Knockback.Ragdoll.
-- Ragdoll cancel: Q ragdollado -> levanta na hora, i-frames curtos, cooldown longo.
CombatConfig.CombatRagdoll = {
	MaxSeconds = 3, -- teto por segurança
	CancelCooldown = 20,
	CancelIFrames = 0.5,
	GetUpIFrames = 0.2, -- ao levantar sozinho (evita o "loop" de ragdoll no chão)
}

CombatConfig.Block = {
	DamageMultiplier = 0.1, -- dano que passa enquanto bloqueia
	WalkSpeed = 8,
	FrontDot = 0, -- só cobre a frente: (atacante − vítima)·frente da vítima abaixo disso = golpe por trás, entra cheio
	ParryWindow = 0.2, -- segundos após iniciar o block em que um golpe recebido vira parry
	ParryStun = 0.4, -- tempo curto que o atacante fica sem agir após ser parryado (a recompensa real é o crítico)
	Cooldown = 0.4, -- tempo mínimo entre soltar e voltar a bloquear (evita spam de parry)
	LockoutAfterAttack = 0.2, -- depois de um M1 não dá para bloquear por este tempo
	-- Guarda: cada golpe bloqueado gasta o dano BRUTO dele; zerou = guard break
	GuardMax = 30,
	GuardRegenPerSecond = 12, -- volta sozinha quando não está bloqueando há RegenDelay
	GuardRegenDelay = 1.0,
	GuardBreakStun = 1.6, -- atordoado, sem block, dano cheio no golpe que quebrou
}

-- Parry = o PRÓXIMO M1 de quem parryou vira CRÍTICO (×3) se sair dentro de Window.
-- Dois críticos seguidos (sem outro M1 acertando no meio, dentro de ChainWindow) = BLACK FLASH (×6).
CombatConfig.Critical = {
	Window = 4, -- s após o parry para usar o crítico
	Multiplier = 3,
	ChainWindow = 4, -- s entre o 1º crítico e o próximo parry+crítico para virar Black Flash
	BlackFlashMultiplier = 6,
}

-- Levar golpe: interrompe o combo da vítima e freia por um instante (hitstun).
-- Só socos/habilidades "hit" (não bloqueados). Não se acumula além de Duration.
CombatConfig.HitStun = {
	Duration = 0.7, -- > Cooldown do M1: dentro do combo a vítima só sai com dash (Q) ou parry antes
	WalkSpeed = 6,
}

-- Finisher (4º golpe) em alvo com vida <= LowHealth (fração) ou que morre no golpe:
-- empurrão forte + ragdoll + efeito/câmera pesados no cliente (kind = "finisher").
CombatConfig.Finisher = {
	LowHealth = 0.3,
	Knockback = { Speed = 75, Duration = 0.35, Ragdoll = 2.0 } :: Knockback,
}

-- Awakening (G com a carga da ult cheia; AbilityService): modo por Duration s com buff de dano e
-- velocidade, aura VFX (Assets.VFX.<Char>.Awakening ou Shared.Awakening) e o slot T (ultimate,
-- EnergyCost = Max) liberado. Fora do modo o T fica trancado.
CombatConfig.Awakening = {
	Duration = 20,
	DamageMultiplier = 1.3,
	SpeedMultiplier = 1.1,
	IFrames = 0.6, -- invencível na ativação
	ChargeOnParry = 10, -- carga extra ao parryar
}

-- Morte: personagem vira ragdoll (juntas soltas) até o respawn; empurrado na direção do golpe.
CombatConfig.Ragdoll = {
	Enabled = true,
	PushSpeed = 40,
}

-- Movimento (MovementService/MovementController). Dash universal em CombatConfig.Dash.
CombatConfig.Sprint = {
	Speed = 24, -- WalkSpeed correndo (Shift segurado); AntiExploit tolera WalkSpeed * 1.6
}

-- Animações são buscadas por NOME em ReplicatedStorage.Assets.Animations.Shared
-- (ver Assets.luau): M1_1, M1_2, M1_3, M1_4, Downslam, Uppercut, Block, Parry, Hit, Idle, Walk, Run, Dash, DashBack

return CombatConfig
