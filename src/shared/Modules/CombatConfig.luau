--!strict
--[[
	CombatConfig
	Números do combate. Lido pelo servidor (autoridade) e pelo cliente (só feedback/timing).
	Rig alvo: R6.
]]

local CombatConfig = {}

CombatConfig.MaxHealth = 100
CombatConfig.RespawnTime = 3
CombatConfig.WalkSpeed = 16

-- Regeneração fora de combate (substitui o script Health padrão do Roblox)
CombatConfig.Regen = {
	Delay = 6, -- segundos sem tomar dano para começar a regenerar
	PerSecond = 3,
}

-- Ataques disponíveis. Chave = attackId enviado pelo cliente em RequestAttack.
CombatConfig.Attacks = {
	M1 = {
		Damage = 8, -- dano dos golpes normais do combo
		FinisherDamage = 15, -- dano do último golpe do combo
		ComboLength = 4,
		Cooldown = 0.35, -- entre golpes do combo
		ComboEndCooldown = 0.9, -- depois do finisher
		ComboResetTime = 1.2, -- sem golpear por esse tempo, combo volta pro 1
		HitDelay = 0.15, -- tempo entre o pedido e a checagem da hitbox (wind-up)
		-- Hitbox (studs) à frente do HumanoidRootPart do atacante
		Range = 7,
		Width = 5,
		Height = 6,
		MaxTargets = 3,
		FinisherKnockback = { Speed = 45, Duration = 0.2, Ragdoll = 1.6 }, -- empurrão + ragdoll no último golpe do combo
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
	DamageMultiplier = 0.3, -- dano que passa enquanto bloqueia
	WalkSpeed = 8,
	ParryWindow = 0.2, -- segundos após iniciar o block em que um golpe recebido vira parry
	ParryStun = 1.0, -- tempo que o atacante fica sem poder agir após ser parryado
	Cooldown = 0.4, -- tempo mínimo entre soltar e voltar a bloquear (evita spam de parry)
	-- Guarda: cada golpe bloqueado gasta o dano BRUTO dele; zerou = guard break
	GuardMax = 60,
	GuardRegenPerSecond = 20, -- volta sozinha quando não está bloqueando há RegenDelay
	GuardRegenDelay = 1.0,
	GuardBreakStun = 1.6, -- atordoado, sem block, dano cheio no golpe que quebrou
}

-- Levar golpe: interrompe o combo da vítima e freia por um instante (hitstun).
-- Só socos/habilidades "hit" (não bloqueados). Não se acumula além de Duration.
CombatConfig.HitStun = {
	Duration = 0.35,
	WalkSpeed = 6,
}

-- Finisher (4º golpe) em alvo com vida <= LowHealth (fração) ou que morre no golpe:
-- empurrão forte + ragdoll + efeito/câmera pesados no cliente (kind = "finisher").
CombatConfig.Finisher = {
	LowHealth = 0.3,
	Knockback = { Speed = 75, Duration = 0.35, Ragdoll = 2.2 },
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
-- (ver Assets.luau): M1_1, M1_2, M1_3, M1_4, Block, Parry, Hit, Idle, Walk, Run, Dash, DashBack

return CombatConfig
