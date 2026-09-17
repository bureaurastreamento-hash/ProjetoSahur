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
-- Detecção de golpe: o CLIENTE do atacante checa a hitbox (posições exatas, sem atraso de rede) e manda
-- as vítimas; o servidor só ACEITA quem estiver dentro de uma caixa maior (tolerância de lag) à frente
-- dele. Quem estiver fora da caixa tolerante é descartado (anti-cheat), cooldown/dano continuam do servidor.
CombatConfig.HitValidation = {
	RangeScale = 1.7, -- caixa do servidor = Range × isto (ping de 100–200 ms move ~3–5 studs)
	WidthScale = 1.7,
	HeightScale = 1.4,
	ExtraTargets = 1, -- o servidor aceita até MaxTargets + isto candidatos na caixa tolerante
}

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
	-- Golpes especiais só saem como 4º GOLPE do combo (no lugar do finisher com empurrão); o downslam
	-- também sai como continuação do uppercut (FollowUpWindow).
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
		FollowUpWindow = 1.6, -- s após o uppercut em que o downslam sai sem precisar de combo novo
	},
}

-- Dash UNIVERSAL (Q, todo personagem; MovementService/MovementController). Sem dano.
-- Direção = WASD relativo à CÂMERA (A/D = lateral puro, S = para trás, W/nada = frente); o boneco
-- mantém a frente virada para a câmera durante o dash (strafe), sem girar para o lado.
-- Dois cooldowns independentes: frente/trás e lateral. Não sai em stun nenhum (hitstun incluído:
-- preso no combo só se sai quando o atacante para) nem caído; Q caído = ragdoll cancel (abaixo).
-- Durante o dash (DashingUntil no Player) não dá para socar nem usar habilidade.
CombatConfig.Dash = {
	Speed = 74,
	Duration = 0.24, -- base; CharacterDefs.DashTuning escala frente/lado
	ForwardBackCooldown = 4.0,
	SideCooldown = 2.0,
	SideDot = 0.5, -- |direção·frente da câmera| abaixo disso = lateral
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
	IFrames = 0.6, -- invencível na ativação (somado à cutscene)
	ChargeOnParry = 10, -- carga extra ao parryar
	-- Cutscene de transformação (decisão do dono 2026-09-16): G = o personagem para, carrega, ESTOURA e
	-- volta despertado. O jogador fica invencível e sem agir durante Duration; no BurstAt quem estiver a
	-- BurstRadius leva BurstDamage + empurrão. O buff/kit despertado só começa DEPOIS da cutscene.
	-- Tempos (dono, 2026-09-16): ~7 s para os sons terem construção: início → carga longa crescendo →
	-- estouro → pose. O servidor prende o personagem no lugar (âncora, vale no ar) durante Duration.
	Cutscene = {
		Duration = 7.0,
		BurstAt = 5.0,
		BurstRadius = 12,
		BurstDamage = 5,
		BurstKnockback = { Speed = 45, Duration = 0.25, Ragdoll = 1.0 } :: Knockback,
		-- "O tempo para": no estouro TODOS os outros jogadores congelam (WalkSpeed 0 + sem agir) por
		-- FreezeSeconds (dono, 2026-09-16: aceito). FreezeRadius = 0 → o servidor inteiro; > 0 → só quem está perto.
		FreezeSeconds = 1.3,
		FreezeRadius = 0,
	},
}

-- Wall splat: golpe que derruba (4º M1, finisher, agarrão) com parede a até Distance studs na direção
-- do empurrão = dano extra + ragdoll mais longo + efeito pesado (kind "wallsplat").
CombatConfig.WallSplat = {
	Distance = 12,
	Damage = 6,
	ExtraRagdoll = 0.8,
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
