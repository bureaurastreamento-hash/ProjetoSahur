--!strict
--[[
	BossConfig
	Boss NPC invocado no altar (Workspace.Sahur.ArenaExtras: BossAltar / BossSpawn / BossArena).
	Todos os números de balanceamento ficam aqui. Servidor autoritativo (BossService).
]]

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

local BossConfig = {}

BossConfig.Name = "Notorious B.I.G."
BossConfig.SummonCost = 0 -- moedas cobradas de quem invoca (0 = grátis por enquanto)
BossConfig.Cooldown = 45 -- s entre uma luta e a próxima invocação
BossConfig.AutoSpawnMinutes = 0 -- além do altar: o Santuário invoca sozinho a cada N min (0 = desligado; agora é ritual)
BossConfig.AutoSpawnWarning = 30 -- s de aviso antes do spawn automático
BossConfig.MaxHealth = 1500
-- Modelo: rig por PEÇAS do Roblox (BossRigs, sem mesh externo) — ver BossConfig.Form.RigId.
BossConfig.ArenaRadius = 55 -- studs a partir de BossArena; fora disso o boss ignora/volta
BossConfig.AbandonSeconds = 30 -- sem jogador vivo na arena por esse tempo = boss some (sem recompensa)
BossConfig.WalkSpeed = 14
BossConfig.PhaseTwoAt = 0.5 -- fração de vida que liga a fase 2 (mais rápido, investida)
BossConfig.PhaseTwoSpeed = 20

-- Ritual da FLECHA (dono, 2026-09-16, noite): uma flecha perdida aparece, de tempos em tempos, num ponto
-- escondido do mapa. Quem encosta carrega a flecha (visível nas costas); morreu = a flecha cai ali por
-- DropLifetime s e some.
-- À NOITE, o portador segura E no altar e VIRA o Notorious B.I.G. (BossConfig.Form) — controlável.
BossConfig.Ritual = {
	Enabled = true,
	NightOnly = true,
	CollectRadius = 7, -- studs do personagem até a flecha para pegar
	RespawnDelay = 30, -- s depois de a forma acabar até a flecha entrar na fila de reaparecer
	-- Dono (2026-09-16, noite): a flecha é RARA e ESCONDIDA. Não fica sempre no mapa: aparece em tempos
	-- aleatórios (SpawnDelayMin..Max s depois de sumir; FirstSpawnMin..Max no boot), num ponto SORTEADO do
	-- mapa (raycast do céu; ArrowSpot* só como reserva), sem feixe/lanterna. Quem morre com ela a deixa no
	-- chão por DropLifetime s; ninguém pegou = some e volta para a fila aleatória.
	SpawnDelayMin = 120,
	SpawnDelayMax = 300,
	FirstSpawnMin = 45,
	FirstSpawnMax = 150,
	DropLifetime = 10,
	HiddenSpawn = true, -- true = ponto aleatório do mapa; false = só nos ArrowSpot*
	SpawnRadius = 225, -- alcance (x/z) do sorteio a partir do centro do mapa
	MinDistanceFromPlayers = 35, -- não nasce colado em alguém
	MinDistanceFromAltar = 45,
	ArrowModelName = "StandArrow", -- Model/BasePart em ServerStorage ou ReplicatedStorage.Assets (senão: flecha por código)
}

-- Forma de boss: o jogador vira o rig (BossRigs) com o kit CharacterDefs.Characters[CharacterId].
-- Acaba quando morre ou em Duration s. Quem bateu divide RewardPool (como o boss NPC); o boss ganha
-- FormKillPoints por kill (via HealthService.Died → ProgressionService normal) + FormSurviveCoins se sobreviver.
BossConfig.Form = {
	RigId = "NotoriousBIG",
	CharacterId = "NotoriousBIG",
	MaxHealth = 1500,
	WalkSpeed = 15,
	Duration = 240,
	HitboxScale = 2.2,
	DamageMultiplier = 2.2, -- socos (M1) da forma
	SurviveCoins = 150, -- se aguentar até o fim
	TransformSeconds = 2.5, -- tempo parado/invencível no altar antes de virar (cutscene curta)
}

-- Recompensa: bolo dividido pela fração de dano causado + mínimo para quem participou
BossConfig.RewardPool = 300
BossConfig.RewardMin = 20
BossConfig.RewardTopBonus = 50 -- quem mais causou dano
BossConfig.TopDropChance = 0.35 -- chance de o top de dano ganhar um giro grátis da roleta (drop raro)

export type Attack = {
	Damage: number,
	Windup: number, -- s de aviso (anel vermelho) antes do dano
	Range: number, -- alcance para escolher o golpe
	MinRange: number?, -- só usa se o alvo estiver a pelo menos isso (Charge/Leap)
	Radius: number, -- área do dano (esfera no boss ou ponto)
	Cooldown: number,
	Knockback: CombatConfig.Knockback?, -- Ragdoll = segundos caído (ragdoll de combate)
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

-- Enrage reativo (ref. HB): levou Hits golpes em Window s -> ruge (empurra/atordoa quem está colado),
-- cura HealFraction do dano dessa janela, contorno vermelho e +dano/+velocidade por Duration s.
BossConfig.Enrage = {
	Hits = 6,
	Window = 3,
	Duration = 8,
	Cooldown = 25, -- s entre um enrage e o próximo
	HealFraction = 0.5,
	DamageScale = 1.3,
	SpeedScale = 1.3,
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
