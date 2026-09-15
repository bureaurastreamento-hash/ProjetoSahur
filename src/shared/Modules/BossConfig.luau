--!strict
--[[
	BossConfig
	Boss NPC invocado no altar (Workspace.Sahur.ArenaExtras: BossAltar / BossSpawn / BossArena).
	Todos os números de balanceamento ficam aqui. Servidor autoritativo (BossService).
]]

local BossConfig = {}

BossConfig.Name = "Sahur Colossal"
BossConfig.SummonCost = 0 -- moedas cobradas de quem invoca (0 = grátis por enquanto)
BossConfig.Cooldown = 45 -- s entre uma luta e a próxima invocação
BossConfig.MaxHealth = 1500
BossConfig.Scale = 1.9 -- Model:ScaleTo no rig R6
BossConfig.ArenaRadius = 55 -- studs a partir de BossArena; fora disso o boss ignora/volta
BossConfig.AbandonSeconds = 30 -- sem jogador vivo na arena por esse tempo = boss some (sem recompensa)
BossConfig.WalkSpeed = 14
BossConfig.PhaseTwoAt = 0.5 -- fração de vida que liga a fase 2 (mais rápido, investida)
BossConfig.PhaseTwoSpeed = 20

-- Recompensa: bolo dividido pela fração de dano causado + mínimo para quem participou
BossConfig.RewardPool = 300
BossConfig.RewardMin = 20
BossConfig.RewardTopBonus = 50 -- quem mais causou dano

export type Attack = {
	Damage: number,
	Windup: number, -- s de aviso (anel vermelho) antes do dano
	Range: number, -- alcance para escolher o golpe
	MinRange: number?, -- só usa se o alvo estiver a pelo menos isso (Charge/Leap)
	Radius: number, -- área do dano (esfera no boss ou ponto)
	Cooldown: number,
	Knockback: { Speed: number, Duration: number, Ragdoll: number? }?, -- Ragdoll = segundos caído (ragdoll de combate)
	StunSeconds: number?, -- Roar: atordoa quem for atingido
	Phase: number?, -- só a partir desta fase (nil = sempre)
	Weight: number?, -- peso na escolha aleatória entre os golpes prontos (nil = 1)
}

BossConfig.Attacks = {
	Swipe = { Damage = 18, Windup = 0.45, Range = 9, Radius = 8, Cooldown = 1.4, Weight = 3, Knockback = { Speed = 30, Duration = 0.15 } } :: Attack,
	Slam = { Damage = 30, Windup = 0.9, Range = 14, Radius = 14, Cooldown = 5, Weight = 2, Knockback = { Speed = 55, Duration = 0.25, Ragdoll = 1.5 } } :: Attack,
	-- anel de choque: pune quem fica colado batendo; empurra forte
	Shockwave = { Damage = 22, Windup = 1.0, Range = 12, Radius = 18, Cooldown = 9, Weight = 2, Knockback = { Speed = 70, Duration = 0.3, Ragdoll = 2 } } :: Attack,
	-- pulo até o alvo (some 0,5 s) e cai em área — para quem fica de longe
	Leap = { Damage = 28, Windup = 0.7, Range = 45, MinRange = 14, Radius = 12, Cooldown = 10, Weight = 2, Knockback = { Speed = 50, Duration = 0.25 } } :: Attack,
	-- rugido: atordoa todo mundo perto (fase 2; também sai na virada de fase)
	Roar = { Damage = 5, Windup = 0.8, Range = 16, Radius = 20, Cooldown = 18, Weight = 1, Phase = 2, StunSeconds = 1.2, Knockback = { Speed = 25, Duration = 0.2 } } :: Attack,
	-- fase 2: investida até o alvo, dano ao chegar
	Charge = { Damage = 25, Windup = 0.6, Range = 40, MinRange = 12, Radius = 7, Cooldown = 7, Weight = 2, Phase = 2, Knockback = { Speed = 60, Duration = 0.3, Ragdoll = 1.8 } } :: Attack,
}

-- IA
BossConfig.AI = {
	RetargetSeconds = 5, -- reavalia o alvo (quem mais bateu ganha prioridade)
	AggroDamageWeight = 0.04, -- +1 ponto de prioridade a cada 25 de dano causado
	AggroBlockPenalty = 2, -- alvo bloqueando perde prioridade (o boss vai atrás de quem está aberto)
	Phase2CooldownScale = 0.7, -- fase 2: golpes saem mais rápido
	Phase2DamageScale = 1.2,
	ComboChance = 0.5, -- fase 2: chance de emendar um Swipe logo após um golpe
}

return BossConfig
