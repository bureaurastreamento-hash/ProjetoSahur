--!strict
--[[
	CharacterDefs
	Definição de cada personagem e do seu KIT. Lido pelo servidor (autoridade: cooldown, carga, efeito) e
	pelo cliente (só teclas, nomes e feedback).

	ESQUEMA (redesign B, dono 2026-09-23/24 — PESQUISA_KITS.md):
	  Abilities          4 ataques normais (teclas 1–4). Sem custo de energia: só cooldown.
	  Passive            1 habilidade de SUPORTE (tecla R): cura/escudo/velocidade/fuga, com cooldown próprio.
	                     Não muda ao despertar.
	  Ultimate           G com a barra cheia = DESPERTAR (cutscene, CombatConfig.Awakening.Cutscene) e, por
	                     Duration s, o kit desperto no lugar dos 4 normais; Effect (opcional) dispara sozinho
	                     no fim da cutscene (ex.: Bruno abre a cúpula do tempo). Nome/tema da cutscene ficam
	                     em AwakeningDefs.
	  AwakenedAbilities  4 golpes da forma desperta (teclas 1–4 enquanto Ultimate durar). Entram PRONTOS
	                     (cooldown próprio, por Id); ao acabar, os 4 normais voltam com o cooldown que tinham.
	  DashOverride       substitui o dash universal (Q) — só o Bruno (Piscar). Único lugar onde ainda existe
	                     AwakenedEffect (pisca mais longe desperto).
	  Variants           D2 (lido pelo AbilityService.pickVariant): variações por CONTEXTO, o servidor escolhe
	                     { OnDowned?, Chain?, Falling?, Air?, Sprint? } = Effect alternativo (nessa prioridade).
	                     Chain = Effect (depois de qualquer habilidade) ou { [IdAnterior] = Effect, ["*"] = Effect }.
	                     Mesmo Id/cooldown; o cliente mostra etiqueta e VFX "<Id>_<Variante>" se existir.

	A barra "Energy" é a CARGA DA ULT (0..Max): enche dando/recebendo dano e parryando.

	Assets esperados (por nome, ver Assets.luau):
	  Animations.<CharacterId>.<AbilityId>   VFX.<CharacterId>.<AbilityId>   (também para os despertos e o R)

	Tipos de efeito (implementados em AbilityService):
	  Dash        { Speed, Duration, Damage, Range, Width, Height, HealPerHit?, StunSeconds?, Knockback? }
	                                                                 -> investida COM dano (movimento no cliente, hitbox no servidor);
	                                                                    HealPerHit = cura o lançador por alvo atingido
	  Grab        { Speed, Duration, Range, Width, Height, Carry, Damage, Knockback?, StunSeconds?, Finish? }
	                                                                 -> investida; ao encostar SEGURA o alvo por Carry s e solta com o golpe.
	                                                                    Finish: "Slam" (padrão) | "Throw" (arremessa; Knockback.Up)
	                                                                    | "Chokeslam" (Lift; esmaga + área SlamRadius/SlamDamage/SlamKnockback?)
	                                                                    | "Spin" (gira Spin voltas/s; SpinRadius/SpinDamage/SpinInterval/SpinKnockback?)
	  Teleport    { Distance }                                       -> move o HRP Distance studs para frente atravessando obstáculos
	  AreaDamage  { Radius, Damage, Delay, StunSeconds?, Knockback?, Offset? }
	                                                                 -> dano em esfera após Delay; Offset = studs à frente do lançador
	  MultiHitArea{ Radius, Damage, Hits, Interval, Offset?, StunSeconds?, Knockback? } -> vários ticks de AreaDamage (Offset = cone à frente)
	  Projectile  { Speed, Range, Radius, Damage, Knockback?, Count?, Spread?, Interval?, AreaRadius?, AreaDamage? }
	                                                                 -> esfera simulada no servidor; Count > 1 = várias (Spread graus em leque
	                                                                    ou Interval s em sequência); AreaRadius = explode em área ao acertar
	  Heal        { Amount, Cleanse? }                               -> cura o lançador; Cleanse = tira stun/ragdoll
	  Shield      { Multiplier, Duration }                           -> multiplica dano RECEBIDO (0.5 = metade)
	  Buff        { Damage?, Speed?, Duration, DashCooldownMult? }   -> ×dano causado / ×velocidade por Duration s (DamageBuff = alias)
	  Mark        { Radius, Offset?, Damage, Delay?, ExplodeRadius, ExplodeDamage, ExplodeKnockback?, AutoDelay? }
	                                                                 -> toca quem está na área e MARCA: o próximo M1 do lançador no marcado
	                                                                    (ou AutoDelay s depois) explode ExplodeRadius em volta dele
	  Homing      { Count?, Duration, Speed, Radius, Damage, Knockback?, StunSeconds?, SeekRadius? }
	                                                                 -> "Sheer Heart Attack": bomba no chão persegue o inimigo mais perto
	                                                                    por Duration s e explode ao encostar (Radius)
	  Rewind      { Delay, Radius?, Damage?, Knockback? }            -> guarda vida/posição; Delay s depois volta para lá (e explode
	                                                                    Radius/Damage em volta, se houver) — Bites the Dust
	  FlyGrab     { FlySpeed, Duration, Range, Width, Height, RiseTime, RiseHeight, DiveSpeed, Damage, Knockback?,
	                SlamRadius?, SlamDamage?, SlamKnockback? }       -> voa na direção da câmera; pegou alguém, sobe e mergulha esmagando
	  TimeDome    { Radius, Duration, SlowMultiplier, SelfMultiplier, BreakMultiplier, NoBreak?, Cinematic? }
	                                                                 -> cúpula fixa no ponto do cast; quem está dentro fica a SlowMultiplier
	                                                                    (0.02 = "tempo parado"), o lançador a SelfMultiplier; sair quebra a
	                                                                    cúpula (salvo NoBreak) e ele fica a BreakMultiplier até o fim
	  Qualquer efeito aceita `Then = { <outro Effect> }` + `ThenDelay?` (s): encadeia um segundo efeito
	  (ex.: Teleport e depois AreaDamage; Heal e depois Shield).
]]

export type Effect = {
	Type: string,
	[string]: any,
}

export type AbilityDef = {
	Id: string,
	DisplayName: string,
	Cooldown: number,
	CastTime: number, -- tempo em que o jogador fica "ocupado" (não pode usar outra habilidade)
	Effect: Effect,
	OncePerAwakening: boolean?, -- só nos despertos: sai UMA vez por despertar (Parada do Tempo)
	Variants: { [string]: any }?, -- D2: OnDowned | Chain | Falling | Air | Sprint = Effect (ver cabeçalho)
	AwakenedEffect: Effect?, -- SÓ DashOverride: versão desperta do Piscar
	SideCooldown: number?, -- SÓ DashOverride: cooldown do teleporte LATERAL (frente/trás usa Cooldown)
}

export type UltimateDef = {
	Duration: number, -- s de forma desperta (depois da cutscene)
	DamageMultiplier: number?, -- padrão CombatConfig.Awakening.DamageMultiplier
	SpeedMultiplier: number?, -- padrão CombatConfig.Awakening.SpeedMultiplier
	Effect: Effect?, -- dispara sozinho no fim da cutscene (Bruno: cúpula do tempo)
}

export type CharacterDef = {
	Id: string,
	DisplayName: string,
	UnlockCost: number, -- moedas; 0 = todos começam com ele (só vale com Access = "coins"/nil)
	Access: string?, -- "stand" = só pela Flecha/Disco (StandConfig; o jogador tem UM Stand ativo) | nil/"coins" = pontos | "vip" = passe VIP (ShopConfig) | "early" = acesso antecipado (bloqueado; só devs) | "admin" = só devs, escondido dos outros | "drop" = só cai do boss (BossConfig.Loot)
	Model: string?, -- nome do rig em ServerStorage.CharacterModels (arte) para "Ser o personagem escolhido"; nil = o Id
	Tagline: string?, -- subtítulo no cartão da seleção
	Color: Color3?, -- cor do personagem (cartão, rastro do dash)
	Image: string?, -- rbxassetid:// do retrato no cartão (vazio = placeholder com a inicial)
	Abilities: { AbilityDef }, -- 4 ataques (teclas 1..4)
	Passive: AbilityDef?, -- suporte (tecla R)
	Ultimate: UltimateDef, -- G: despertar + kit desperto
	AwakenedAbilities: { AbilityDef }, -- 4 golpes despertos (teclas 1..4 enquanto desperto)
	DashOverride: AbilityDef?, -- substitui o dash universal (Q) por esta habilidade (Bruno: Piscar)
}

local CharacterDefs = {}

CharacterDefs.Energy = {
	Max = 100,
	-- dono (2026-09-20): ult carrega mais devagar (era 6/4); 2026-09-21: "ult muito rápida de pegar" → 2/1
	GainOnHitDealt = 2,
	GainOnHitTaken = 1,
}

CharacterDefs.DefaultCharacter = "Humano" -- todo mundo nasce humano (StandConfig); Stand vem da Flecha

--- Afinação global de dash (dash universal do Q e Effect.Type = "Dash"). Duration × escala conforme a
--- direção. O cliente move; o servidor amostra a hitbox por Duration × ForwardScale (o maior).
CharacterDefs.DashTuning = {
	ForwardScale = 1.4, -- frente/trás
	SideScale = 1.0, -- lados
	SteerRate = 14, -- rad/s de correção pelo WASD durante o dash (liberdade de curvar)
	MinDistanceHold = true, -- bateu em parede/jogador: a duração continua contando (sem "dash grátis")
}

--- Trocar de personagem faz respawn; só é permitido depois deste tempo sem levar dano.
CharacterDefs.SwapOutOfCombatSeconds = 10

CharacterDefs.Characters = {
	-- =====================================================================================================
	-- HUMANO — sem Stand (todo mundo nasce assim): só M1, dash e block. Sem ult.
	-- =====================================================================================================
	Humano = {
		Id = "Humano",
		DisplayName = "Humano",
		UnlockCost = 0,
		Access = "human",
		Tagline = "Sem Stand · a Flecha decide o resto",
		Color = Color3.fromRGB(220, 200, 170),
		Image = "",
		Abilities = {},
		Ultimate = { Duration = 0 },
		AwakenedAbilities = {},
	} :: CharacterDef,

	-- =====================================================================================================
	-- JOTARO — Star Platinum (Stand incomum): soco, agarrão e pressão de perto
	-- =====================================================================================================
	Jotaro = {
		Id = "Jotaro",
		DisplayName = "Jotaro",
		UnlockCost = 0,
		Access = "stand",
		Tagline = "Star Platinum · punhos e pressão",
		Color = Color3.fromRGB(120, 90, 255),
		Image = "",
		Abilities = {
			{ Id = "OraRush", DisplayName = "Rajada ORA", Cooldown = 7, CastTime = 0.3,
				-- cone à frente: 6 socos rápidos do Stand, empurrão só no último
				Effect = { Type = "MultiHitArea", Radius = 6, Offset = 4, Damage = 4, Hits = 6, Interval = 0.12, Knockback = { Speed = 30, Duration = 0.2 } } },
			{ Id = "ShoulderBash", DisplayName = "Arremesso", Cooldown = 8, CastTime = 0.4,
				-- agarra, carrega 0,8 s e arremessa
				Effect = { Type = "Grab", Finish = "Throw", Speed = 70, Duration = 0.25, Range = 6, Width = 6, Height = 6, Carry = 0.8, Damage = 16, Knockback = { Speed = 70, Duration = 0.35, Ragdoll = 1.8, Up = 25 } } },
			{ Id = "StarFinger", DisplayName = "Soco Estrela", Cooldown = 9, CastTime = 0.3,
				Effect = { Type = "Dash", Speed = 70, Duration = 0.3, Damage = 18, Range = 7, Width = 6, Height = 6, Knockback = { Speed = 45, Duration = 0.25, Ragdoll = 1.2 } },
				-- D2: correndo = soco mais longo e forte; emendado depois do Arremesso = persegue quem voou
				Variants = {
					Sprint = { Type = "Dash", Speed = 95, Duration = 0.35, Damage = 24, Range = 9, Width = 6, Height = 6, Knockback = { Speed = 60, Duration = 0.3, Ragdoll = 1.6 } },
					Chain = { ShoulderBash = { Type = "Dash", Speed = 110, Duration = 0.4, Damage = 22, Range = 8, Width = 7, Height = 7, Knockback = { Speed = 55, Duration = 0.3, Ragdoll = 1.5 } } },
				} },
			{ Id = "GroundSlam", DisplayName = "Pancada no Chão", Cooldown = 10, CastTime = 0.6,
				Effect = { Type = "AreaDamage", Radius = 12, Damage = 20, Delay = 0.4, Knockback = { Speed = 40, Duration = 0.25, Ragdoll = 1.5 } },
				-- D2: caindo de altura = meteoro (área maior, impacto na chegada); alvo no chão = esmaga sem empurrar longe
				Variants = {
					Falling = { Type = "AreaDamage", Radius = 15, Damage = 28, Delay = 0.15, Knockback = { Speed = 55, Duration = 0.3, Ragdoll = 2 } },
					OnDowned = { Type = "AreaDamage", Radius = 8, Offset = 4, Damage = 30, Delay = 0.3, Knockback = { Speed = 15, Duration = 0.15, Ragdoll = 1.2 } },
				} },
		},
		Passive = { Id = "StandGuard", DisplayName = "Postura do Stand", Cooldown = 20, CastTime = 0.3,
			-- aguenta e avança: metade do dano recebido por 4 s + um pouco mais rápido
			Effect = { Type = "Shield", Multiplier = 0.5, Duration = 4, Then = { Type = "Buff", Speed = 1.15, Duration = 4 } } },
		Ultimate = { Duration = 20 }, -- STAR PLATINUM: THE WORLD (AwakeningDefs)
		AwakenedAbilities = {
			{ Id = "OraOraOra", DisplayName = "ORA ORA ORA", Cooldown = 9, CastTime = 0.3,
				Effect = { Type = "MultiHitArea", Radius = 7, Offset = 4, Damage = 4, Hits = 12, Interval = 0.08, Knockback = { Speed = 50, Duration = 0.3, Ragdoll = 1.5 } } },
			{ Id = "TimeStopShort", DisplayName = "Parada do Tempo", Cooldown = 15, CastTime = 0.5, OncePerAwakening = true,
				-- 2,5 s: todo mundo perto congela; o Jotaro segue normal (sem cinemática, sem quebrar ao sair)
				Effect = { Type = "TimeDome", Radius = 18, Duration = 2.5, SlowMultiplier = 0.02, SelfMultiplier = 1, BreakMultiplier = 1, NoBreak = true } },
			{ Id = "StarFingerMax", DisplayName = "Soco Estrela Máximo", Cooldown = 9, CastTime = 0.3,
				Effect = { Type = "Dash", Speed = 85, Duration = 0.35, Damage = 28, Range = 8, Width = 7, Height = 7, Knockback = { Speed = 60, Duration = 0.3, Ragdoll = 2 } } },
			{ Id = "StarImpact", DisplayName = "Impacto Estelar", Cooldown = 14, CastTime = 0.6,
				Effect = { Type = "AreaDamage", Radius = 16, Damage = 34, Delay = 0.5, Knockback = { Speed = 55, Duration = 0.3, Ragdoll = 2 } } },
		},
	} :: CharacterDef,

	-- =====================================================================================================
	-- BRUNO GOLLINI (id "Swift") — velocidade, tempo, pisca. Q = Piscar (DashOverride)
	-- =====================================================================================================
	Swift = {
		Id = "Swift", -- id interno continua "Swift" (perfis salvos, pastas de animação/som/VFX); na tela é o Bruno
		DisplayName = "Bruno Gollini",
		UnlockCost = 0,
		Access = "stand",
		Tagline = "Velocidade e domínio do tempo",
		Color = Color3.fromRGB(110, 230, 255),
		Image = "",
		DashOverride = {
			Id = "Blink",
			DisplayName = "Piscar",
			Cooldown = 5, -- frente/trás
			SideCooldown = 2.5, -- lateral
			CastTime = 0.15,
			Effect = { Type = "Teleport", Distance = 18 },
			AwakenedEffect = { Type = "Teleport", Distance = 28 },
		},
		Abilities = {
			{ Id = "SweepKick", DisplayName = "Rasteira", Cooldown = 8, CastTime = 0.4,
				Effect = { Type = "AreaDamage", Radius = 8, Damage = 12, Delay = 0.2, StunSeconds = 0.8 },
				-- D2: correndo = rasteira deslizante (avança e derruba)
				Variants = { Sprint = { Type = "Dash", Speed = 75, Duration = 0.3, Damage = 14, Range = 8, Width = 6, Height = 4, Knockback = { Speed = 30, Duration = 0.2, Ragdoll = 1.2 } } } },
			{ Id = "WindBlade", DisplayName = "Lâmina de Vento", Cooldown = 6, CastTime = 0.25,
				Effect = { Type = "Projectile", Speed = 120, Range = 60, Radius = 2.5, Damage = 14, Knockback = { Speed = 25, Duration = 0.15 } },
				-- D2: no ar = duas lâminas cruzadas
				Variants = { Air = { Type = "Projectile", Count = 2, Spread = 10, Speed = 120, Range = 60, Radius = 2.5, Damage = 12, Knockback = { Speed = 25, Duration = 0.15 } } } },
			{ Id = "CrossCut", DisplayName = "Corte Cruzado", Cooldown = 10, CastTime = 0.4,
				-- pisca 10 studs à frente (atravessa o alvo) e corta em volta
				Effect = { Type = "Teleport", Distance = 10, Then = { Type = "AreaDamage", Radius = 6, Damage = 16, Delay = 0.15, Knockback = { Speed = 30, Duration = 0.2 } }, ThenDelay = 0.05 } },
			{ Id = "Tempest", DisplayName = "Tempestade", Cooldown = 14, CastTime = 0.5,
				Effect = { Type = "MultiHitArea", Radius = 9, Damage = 5, Hits = 4, Interval = 0.2, Knockback = { Speed = 25, Duration = 0.15 } } },
		},
		Passive = { Id = "Haste", DisplayName = "Aceleração", Cooldown = 18, CastTime = 0.2,
			Effect = { Type = "Buff", Speed = 1.3, Duration = 5, DashCooldownMult = 0.5 } },
		-- DOMÍNIO DO TEMPO: a cúpula abre sozinha no fim da cutscene e dura o mesmo que a forma (14 s)
		Ultimate = { Duration = 14, Effect = { Type = "TimeDome", Radius = 30, Duration = 14, SlowMultiplier = 0.08, SelfMultiplier = 1.25, BreakMultiplier = 3.0 } },
		AwakenedAbilities = {
			{ Id = "ThousandCuts", DisplayName = "Mil Cortes", Cooldown = 8, CastTime = 0.3,
				Effect = { Type = "MultiHitArea", Radius = 8, Damage = 4, Hits = 8, Interval = 0.1, Knockback = { Speed = 30, Duration = 0.2 } } },
			{ Id = "TwinBlades", DisplayName = "Lâminas Gêmeas", Cooldown = 6, CastTime = 0.25,
				Effect = { Type = "Projectile", Count = 2, Spread = 10, Speed = 120, Range = 60, Radius = 2.5, Damage = 14, Knockback = { Speed = 30, Duration = 0.15 } } },
			{ Id = "PhantomCut", DisplayName = "Corte Fantasma", Cooldown = 9, CastTime = 0.4,
				Effect = { Type = "Teleport", Distance = 12, Then = { Type = "AreaDamage", Radius = 8, Damage = 24, Delay = 0.15, StunSeconds = 1, Knockback = { Speed = 35, Duration = 0.2 } }, ThenDelay = 0.05 } },
			{ Id = "TimeBreak", DisplayName = "Quebra do Tempo", Cooldown = 14, CastTime = 0.6,
				Effect = { Type = "AreaDamage", Radius = 14, Damage = 34, Delay = 0.6, Knockback = { Speed = 55, Duration = 0.3, Ragdoll = 2 } } },
		},
	} :: CharacterDef,

	-- =====================================================================================================
	-- DIO — The World (Stand lendário): tempo parado, facas, rolo compressor, vampiro
	-- =====================================================================================================
	Dio = {
		Id = "Dio",
		DisplayName = "Dio",
		UnlockCost = 0,
		Access = "stand",
		Tagline = "The World · o tempo é dele",
		Color = Color3.fromRGB(255, 205, 80),
		Image = "",
		Abilities = {
			{ Id = "MudaRush", DisplayName = "Rajada MUDA", Cooldown = 7, CastTime = 0.3,
				Effect = { Type = "MultiHitArea", Radius = 6, Offset = 4, Damage = 4, Hits = 6, Interval = 0.12, Knockback = { Speed = 30, Duration = 0.2 } } },
			{ Id = "Knives", DisplayName = "Facas", Cooldown = 7, CastTime = 0.3,
				Effect = { Type = "Projectile", Count = 3, Spread = 12, Speed = 110, Range = 55, Radius = 2, Damage = 8, Knockback = { Speed = 15, Duration = 0.1 } },
				-- D2: no ar = leque de 5 facas; emendado depois da rajada MUDA = facas mais fortes em quem ficou preso
				Variants = {
					Air = { Type = "Projectile", Count = 5, Spread = 22, Speed = 110, Range = 55, Radius = 2, Damage = 8, Knockback = { Speed = 15, Duration = 0.1 } },
					Chain = { MudaRush = { Type = "Projectile", Count = 3, Spread = 6, Speed = 130, Range = 40, Radius = 2.5, Damage = 12, Knockback = { Speed = 30, Duration = 0.2 } } },
				} },
			{ Id = "VampiricStrike", DisplayName = "Golpe Vampírico", Cooldown = 10, CastTime = 0.3,
				Effect = { Type = "Dash", Speed = 65, Duration = 0.3, Damage = 16, Range = 7, Width = 6, Height = 6, HealPerHit = 12, Knockback = { Speed = 35, Duration = 0.2 } },
				-- D2: alvo caído = bebe mais sangue (cura dobrada)
				Variants = { OnDowned = { Type = "Dash", Speed = 65, Duration = 0.3, Damage = 20, Range = 8, Width = 6, Height = 6, HealPerHit = 24, Knockback = { Speed = 20, Duration = 0.15 } } } },
			{ Id = "RoyalKnee", DisplayName = "Joelhada Real", Cooldown = 9, CastTime = 0.4,
				-- ergue 0,8 s e esmaga; quem está perto do impacto toma área
				Effect = { Type = "Grab", Finish = "Chokeslam", Lift = 5, Speed = 55, Duration = 0.22, Range = 6, Width = 7, Height = 6, Carry = 0.8, Damage = 14, Knockback = { Speed = 10, Duration = 0.15, Ragdoll = 1.5 }, SlamRadius = 8, SlamDamage = 10, SlamKnockback = { Speed = 35, Duration = 0.2 } } },
		},
		Passive = { Id = "ColdBlood", DisplayName = "Sangue Frio", Cooldown = 22, CastTime = 0.3,
			Effect = { Type = "Heal", Amount = 20, Then = { Type = "Shield", Multiplier = 0.6, Duration = 3 } } },
		Ultimate = { Duration = 20 }, -- THE WORLD
		AwakenedAbilities = {
			{ Id = "MudaMudaMuda", DisplayName = "MUDA MUDA MUDA", Cooldown = 9, CastTime = 0.3,
				Effect = { Type = "MultiHitArea", Radius = 7, Offset = 4, Damage = 4, Hits = 12, Interval = 0.08, Knockback = { Speed = 50, Duration = 0.3, Ragdoll = 1.5 } } },
			{ Id = "TimeStop", DisplayName = "Parada do Tempo", Cooldown = 15, CastTime = 0.6, OncePerAwakening = true,
				-- 5 s: "ZA WARUDO" — todo mundo perto congela; o Dio segue normal
				Effect = { Type = "TimeDome", Radius = 22, Duration = 5, SlowMultiplier = 0.02, SelfMultiplier = 1, BreakMultiplier = 1, NoBreak = true } },
			{ Id = "KnifeRain", DisplayName = "Chuva de Facas", Cooldown = 8, CastTime = 0.3,
				Effect = { Type = "Projectile", Count = 6, Spread = 24, Speed = 110, Range = 55, Radius = 2, Damage = 8, Knockback = { Speed = 20, Duration = 0.1 } } },
			{ Id = "RoadRoller", DisplayName = "ROLO COMPRESSOR", Cooldown = 16, CastTime = 0.8,
				Effect = { Type = "AreaDamage", Radius = 12, Offset = 10, Damage = 40, Delay = 0.9, Knockback = { Speed = 60, Duration = 0.3, Ragdoll = 2.5 } } },
		},
	} :: CharacterDef,

	-- =====================================================================================================
	-- YOSHIKAGE KIRA — Killer Queen: bombas, marcar e detonar, Sheer Heart Attack, Bites the Dust
	-- =====================================================================================================
	Kira = {
		Id = "Kira",
		DisplayName = "Yoshikage Kira",
		UnlockCost = 0,
		Access = "stand",
		Tagline = "Killer Queen · tudo que ele toca vira bomba",
		Color = Color3.fromRGB(170, 110, 255),
		Image = "",
		Abilities = {
			{ Id = "BombTouch", DisplayName = "Toque da Bomba", Cooldown = 8, CastTime = 0.3,
				-- toque curto à frente marca; o próximo M1 no marcado explode (ou sozinho em 4 s)
				Effect = { Type = "Mark", Radius = 4, Offset = 3, Damage = 8, ExplodeRadius = 6, ExplodeDamage = 16, AutoDelay = 4, ExplodeKnockback = { Speed = 40, Duration = 0.25, Ragdoll = 1.2 } } },
			{ Id = "CoinBomb", DisplayName = "Moeda Bomba", Cooldown = 9, CastTime = 0.3,
				Effect = { Type = "Projectile", Speed = 60, Range = 45, Radius = 2, Damage = 18, AreaRadius = 6, AreaDamage = 12, Knockback = { Speed = 35, Duration = 0.2 } },
				-- D2: no ar = 3 moedas em leque
				Variants = { Air = { Type = "Projectile", Count = 3, Spread = 18, Speed = 60, Range = 45, Radius = 2, Damage = 14, AreaRadius = 5, AreaDamage = 10, Knockback = { Speed = 30, Duration = 0.2 } } } },
			{ Id = "SheerHeartAttack", DisplayName = "Sheer Heart Attack", Cooldown = 16, CastTime = 0.5,
				Effect = { Type = "Homing", Duration = 6, Speed = 22, Radius = 7, Damage = 22, SeekRadius = 40, Knockback = { Speed = 45, Duration = 0.25, Ragdoll = 1.5 } } },
			{ Id = "ChainDetonation", DisplayName = "Detonação em Cadeia", Cooldown = 12, CastTime = 0.5,
				Effect = { Type = "AreaDamage", Radius = 12, Damage = 20, Delay = 0.5, Knockback = { Speed = 40, Duration = 0.25 } },
				-- D2: emendada logo depois do Toque da Bomba = explosão maior e que derruba
				Variants = { Chain = { BombTouch = { Type = "AreaDamage", Radius = 14, Damage = 26, Delay = 0.35, Knockback = { Speed = 50, Duration = 0.3, Ragdoll = 1.5 } } } } },
		},
		Passive = { Id = "CleanHands", DisplayName = "Mãos Limpas", Cooldown = 18, CastTime = 0.2,
			-- fuga: pisca 12 para TRÁS (direção negativa) e cura um pouco
			Effect = { Type = "Teleport", Distance = 12, Backward = true, Then = { Type = "Heal", Amount = 10 } } },
		Ultimate = { Duration = 20 }, -- KILLER QUEEN
		AwakenedAbilities = {
			{ Id = "FirstBomb", DisplayName = "Primeira Bomba", Cooldown = 9, CastTime = 0.3,
				-- marca todo mundo em volta; detona sozinha em 1,5 s
				Effect = { Type = "Mark", Radius = 8, Damage = 6, ExplodeRadius = 7, ExplodeDamage = 26, AutoDelay = 1.5, ExplodeKnockback = { Speed = 50, Duration = 0.3, Ragdoll = 1.5 } } },
			{ Id = "CoinRain", DisplayName = "Chuva de Moedas", Cooldown = 9, CastTime = 0.3,
				Effect = { Type = "Projectile", Count = 4, Spread = 20, Speed = 60, Range = 45, Radius = 2, Damage = 12, AreaRadius = 5, AreaDamage = 8, Knockback = { Speed = 35, Duration = 0.2 } } },
			{ Id = "SheerHeartAttackX2", DisplayName = "Sheer Heart Attack ×2", Cooldown = 16, CastTime = 0.5,
				Effect = { Type = "Homing", Count = 2, Duration = 8, Speed = 24, Radius = 7, Damage = 22, SeekRadius = 45, Knockback = { Speed = 45, Duration = 0.25, Ragdoll = 1.5 } } },
			{ Id = "BitesTheDust", DisplayName = "BITES THE DUST", Cooldown = 20, CastTime = 0.4, OncePerAwakening = true,
				-- marca o instante; 4 s depois volta com a vida/posição de antes e explode em volta
				Effect = { Type = "Rewind", Delay = 4, Radius = 14, Damage = 38, Knockback = { Speed = 60, Duration = 0.3, Ragdoll = 2 } } },
		},
	} :: CharacterDef,

	-- =====================================================================================================
	-- RICK → RICK PRIME: exclusivo do boss (Access "drop")
	-- =====================================================================================================
	Rick = {
		Id = "Rick",
		DisplayName = "Rick",
		UnlockCost = 0,
		Access = "drop",
		Tagline = "Exclusivo do boss · desperta como Rick Prime",
		Color = Color3.fromRGB(120, 220, 160),
		Image = "",
		Abilities = {
			{ Id = "LaserPistol", DisplayName = "Pistola Laser", Cooldown = 4, CastTime = 0.2,
				Effect = { Type = "Projectile", Speed = 140, Range = 70, Radius = 2, Damage = 12, Knockback = { Speed = 20, Duration = 0.1 } } },
			{ Id = "Portal", DisplayName = "Portal", Cooldown = 8, CastTime = 0.2,
				Effect = { Type = "Teleport", Distance = 22 } },
			{ Id = "SentryDrone", DisplayName = "Drone Sentinela", Cooldown = 12, CastTime = 0.4,
				Effect = { Type = "Homing", Duration = 5, Speed = 26, Radius = 5, Damage = 16, StunSeconds = 0.8, SeekRadius = 40, Knockback = { Speed = 20, Duration = 0.15 } } },
			{ Id = "NeutrinoBomb", DisplayName = "Bomba de Neutrinos", Cooldown = 12, CastTime = 0.5,
				Effect = { Type = "AreaDamage", Radius = 10, Offset = 12, Damage = 24, Delay = 0.8, Knockback = { Speed = 45, Duration = 0.25, Ragdoll = 1.2 } },
				-- D2: caindo = solta a bomba embaixo de si (impacto rápido); correndo = joga mais longe
				Variants = {
					Falling = { Type = "AreaDamage", Radius = 12, Damage = 26, Delay = 0.3, Knockback = { Speed = 50, Duration = 0.3, Ragdoll = 1.5 } },
					Sprint = { Type = "AreaDamage", Radius = 10, Offset = 20, Damage = 24, Delay = 0.8, Knockback = { Speed = 45, Duration = 0.25, Ragdoll = 1.2 } },
				} },
		},
		Passive = { Id = "MedKit", DisplayName = "Kit Médico", Cooldown = 22, CastTime = 0.3,
			Effect = { Type = "Heal", Amount = 25, Cleanse = true } },
		Ultimate = { Duration = 18 }, -- RICK PRIME
		AwakenedAbilities = {
			{ Id = "PrimeLaser", DisplayName = "Laser Prime", Cooldown = 5, CastTime = 0.2,
				Effect = { Type = "Projectile", Count = 3, Interval = 0.12, Speed = 140, Range = 70, Radius = 2, Damage = 12, Knockback = { Speed = 25, Duration = 0.1 } } },
			{ Id = "DoublePortal", DisplayName = "Portal Duplo", Cooldown = 8, CastTime = 0.2,
				Effect = { Type = "Teleport", Distance = 30, Then = { Type = "AreaDamage", Radius = 6, Damage = 14, Delay = 0.1, Knockback = { Speed = 30, Duration = 0.2 } }, ThenDelay = 0.05 } },
			-- voa 7 s com a mão esticada (anim 71127142596119); pegou alguém, sobe e mergulha (PrimeDive_Carry)
			{ Id = "PrimeDive", DisplayName = "Mergulho Prime", Cooldown = 25, CastTime = 0.4, OncePerAwakening = true,
				Effect = { Type = "FlyGrab", FlySpeed = 55, Duration = 7, Range = 6, Width = 7, Height = 7, RiseTime = 1.4, RiseHeight = 22, DiveSpeed = 110, Damage = 45,
					Knockback = { Speed = 30, Duration = 0.25, Ragdoll = 2.5 }, SlamRadius = 12, SlamDamage = 18, SlamKnockback = { Speed = 55, Duration = 0.25, Ragdoll = 1.2, Up = 20 } } },
			{ Id = "OmegaDevice", DisplayName = "Omega Device", Cooldown = 18, CastTime = 0.7,
				Effect = { Type = "AreaDamage", Radius = 20, Damage = 44, Delay = 1.2, Knockback = { Speed = 65, Duration = 0.35, Ragdoll = 3 } } },
		},
	} :: CharacterDef,

	-- =====================================================================================================
	-- SAHUR (acesso antecipado, fora da seleção — dono 2026-09-24): kit de ritmo, baixa prioridade
	-- =====================================================================================================
	Sahur = {
		Id = "Sahur",
		DisplayName = "Sahur",
		UnlockCost = 0,
		Access = "early",
		Tagline = "O ritmo que esmaga",
		Color = Color3.fromRGB(120, 255, 160),
		Image = "",
		Abilities = {
			{ Id = "Bombo", DisplayName = "Bombo", Cooldown = 9, CastTime = 0.5,
				Effect = { Type = "AreaDamage", Radius = 10, Damage = 18, Delay = 0.35, Knockback = { Speed = 45, Duration = 0.25, Ragdoll = 1.5 } } },
			{ Id = "Compasso", DisplayName = "Compasso", Cooldown = 8, CastTime = 0.3,
				Effect = { Type = "Dash", Speed = 65, Duration = 0.3, Damage = 14, Range = 7, Width = 6, Height = 6, Knockback = { Speed = 35, Duration = 0.2 } } },
			{ Id = "Baqueta", DisplayName = "Baqueta", Cooldown = 6, CastTime = 0.25,
				Effect = { Type = "Projectile", Speed = 100, Range = 50, Radius = 2.5, Damage = 12, Knockback = { Speed = 20, Duration = 0.1 } } },
			{ Id = "Ritmo", DisplayName = "Ritmo", Cooldown = 14, CastTime = 0.5,
				Effect = { Type = "MultiHitArea", Radius = 10, Damage = 6, Hits = 4, Interval = 0.25, Knockback = { Speed = 25, Duration = 0.15 } } },
		},
		Passive = { Id = "Toque", DisplayName = "Toque de Guerra", Cooldown = 18, CastTime = 0.6,
			Effect = { Type = "Buff", Damage = 1.5, Duration = 6 } },
		Ultimate = { Duration = 20 }, -- RITMO FINAL
		AwakenedAbilities = {
			{ Id = "BomboFinal", DisplayName = "Bombo Final", Cooldown = 9, CastTime = 0.5,
				Effect = { Type = "AreaDamage", Radius = 15, Damage = 24, Delay = 0.25, Knockback = { Speed = 60, Duration = 0.3, Ragdoll = 2 } } },
			{ Id = "CompassoFinal", DisplayName = "Compasso Final", Cooldown = 8, CastTime = 0.3,
				Effect = { Type = "Dash", Speed = 80, Duration = 0.35, Damage = 22, Range = 8, Width = 7, Height = 7, Knockback = { Speed = 50, Duration = 0.25, Ragdoll = 1.5 } } },
			{ Id = "BaquetaFinal", DisplayName = "Baquetas", Cooldown = 6, CastTime = 0.25,
				Effect = { Type = "Projectile", Count = 3, Spread = 15, Speed = 100, Range = 50, Radius = 2.5, Damage = 12, Knockback = { Speed = 25, Duration = 0.1 } } },
			{ Id = "RitmoFinal", DisplayName = "Ritmo Final", Cooldown = 16, CastTime = 1.5,
				Effect = { Type = "MultiHitArea", Radius = 12, Damage = 9, Hits = 6, Interval = 0.25, Knockback = { Speed = 30, Duration = 0.15 } } },
		},
	} :: CharacterDef,

	-- Personagem de ADMIN (Access = "admin"): só devs veem/usam; números absurdos para testar sistemas.
	Overlord = {
		Id = "Overlord",
		DisplayName = "Overlord",
		UnlockCost = 0,
		Access = "admin",
		Tagline = "Só admin: teste de sistemas",
		Color = Color3.fromRGB(255, 80, 200),
		Image = "",
		Abilities = {
			{ Id = "Smite", DisplayName = "Golpe Divino", Cooldown = 1, CastTime = 0.1,
				Effect = { Type = "AreaDamage", Radius = 20, Damage = 60, Delay = 0.1, Knockback = { Speed = 60, Duration = 0.3, Ragdoll = 2 } } },
			{ Id = "Warp", DisplayName = "Teleporte Longo", Cooldown = 1, CastTime = 0.1,
				Effect = { Type = "Teleport", Distance = 60 } },
			{ Id = "Clutch", DisplayName = "Giro Devastador", Cooldown = 2, CastTime = 0.2,
				Effect = { Type = "Grab", Finish = "Spin", Spin = 1.25, Speed = 90, Duration = 0.4, Range = 10, Width = 10, Height = 8, Carry = 1.6, Damage = 30, Knockback = { Speed = 80, Duration = 0.35, Ragdoll = 2.5, Up = 15 }, SpinRadius = 9, SpinDamage = 6, SpinInterval = 0.3, SpinKnockback = { Speed = 30, Duration = 0.15 } } },
			{ Id = "Cataclysm", DisplayName = "Cataclismo", Cooldown = 5, CastTime = 0.5,
				Effect = { Type = "MultiHitArea", Radius = 30, Damage = 25, Hits = 4, Interval = 0.3, Knockback = { Speed = 70, Duration = 0.3, Ragdoll = 2 } } },
		},
		Passive = { Id = "FullHeal", DisplayName = "Cura Total", Cooldown = 2, CastTime = 0.1,
			Effect = { Type = "Heal", Amount = 1000, Cleanse = true } },
		Ultimate = { Duration = 30, DamageMultiplier = 2 },
		AwakenedAbilities = {
			{ Id = "SmiteMax", DisplayName = "Golpe Divino ×2", Cooldown = 1, CastTime = 0.1,
				Effect = { Type = "AreaDamage", Radius = 30, Damage = 120, Delay = 0.1, Knockback = { Speed = 80, Duration = 0.3, Ragdoll = 2 } } },
			{ Id = "WarpMax", DisplayName = "Teleporte Máximo", Cooldown = 1, CastTime = 0.1,
				Effect = { Type = "Teleport", Distance = 120 } },
			{ Id = "ClutchMax", DisplayName = "Giro Devastador ×2", Cooldown = 2, CastTime = 0.2,
				Effect = { Type = "Grab", Finish = "Spin", Spin = 1.5, Speed = 90, Duration = 0.4, Range = 12, Width = 12, Height = 8, Carry = 2, Damage = 60, Knockback = { Speed = 100, Duration = 0.35, Ragdoll = 3, Up = 20 }, SpinRadius = 12, SpinDamage = 12, SpinInterval = 0.25, SpinKnockback = { Speed = 40, Duration = 0.15 } } },
			{ Id = "CataclysmMax", DisplayName = "Cataclismo ×2", Cooldown = 5, CastTime = 0.5,
				Effect = { Type = "MultiHitArea", Radius = 40, Damage = 50, Hits = 4, Interval = 0.3, Knockback = { Speed = 90, Duration = 0.3, Ragdoll = 2 } } },
		},
	} :: CharacterDef,

	-- FORMA DE BOSS (ritual da flecha, BossFormService): não aparece na seleção (fora de Order, Access "form").
	-- O jogador vira o Big C.H.O.P. (rig por peças, BossRigs) com muita vida; todo mundo caça ele.
	BigChop = {
		Id = "BigChop",
		DisplayName = "Big C.H.O.P.",
		UnlockCost = 0,
		Access = "form",
		Tagline = "Stand de carne — não morre, só cresce",
		Color = Color3.fromRGB(196, 66, 108),
		Image = "",
		Abilities = {
			-- investida pesada: cada alvo devorado CURA o boss ("não morre, só cresce")
			{ Id = "Devour", DisplayName = "Devorar", Cooldown = 6, CastTime = 0.5,
				Effect = { Type = "Dash", Speed = 62, Duration = 0.45, Damage = 24, Range = 10, Width = 12, Height = 10, HealPerHit = 60, Knockback = { Speed = 55, Duration = 0.3, Ragdoll = 1.6 } } },
			-- empina e desaba: quem sobreviver fica tonto para o Devorar emendar
			{ Id = "Crush", DisplayName = "Esmagar", Cooldown = 9, CastTime = 0.7,
				Effect = { Type = "AreaDamage", Radius = 16, Damage = 30, Delay = 0.55, StunSeconds = 0.6, Knockback = { Speed = 60, Duration = 0.3, Ragdoll = 1.8 } } },
			-- anel de choque: expulsa quem fica colado (dano baixo, empurrão enorme)
			{ Id = "FleshWave", DisplayName = "Onda de Carne", Cooldown = 12, CastTime = 0.8,
				Effect = { Type = "AreaDamage", Radius = 22, Damage = 22, Delay = 0.7, Knockback = { Speed = 75, Duration = 0.35, Ragdoll = 2 } } },
			-- mordidas em sequência em volta (8 × 8 = 64 num alvo parado)
			{ Id = "Frenzy", DisplayName = "Frenesi", Cooldown = 20, CastTime = 0.6,
				Effect = { Type = "MultiHitArea", Radius = 14, Damage = 8, Hits = 8, Interval = 0.22, Knockback = { Speed = 12, Duration = 0.1 } } },
		},
		Passive = { Id = "Regrow", DisplayName = "Regenerar", Cooldown = 25, CastTime = 0.5,
			Effect = { Type = "Heal", Amount = 150 } },
		Ultimate = { Duration = 20 }, -- FRENESI
		AwakenedAbilities = {
			{ Id = "DevourMax", DisplayName = "Devorar Tudo", Cooldown = 6, CastTime = 0.5,
				Effect = { Type = "Dash", Speed = 75, Duration = 0.55, Damage = 32, Range = 12, Width = 14, Height = 11, HealPerHit = 90, Knockback = { Speed = 70, Duration = 0.35, Ragdoll = 2 } } },
			{ Id = "CrushMax", DisplayName = "Esmagar Tudo", Cooldown = 9, CastTime = 0.7,
				Effect = { Type = "AreaDamage", Radius = 22, Damage = 40, Delay = 0.45, StunSeconds = 0.8, Knockback = { Speed = 75, Duration = 0.35, Ragdoll = 2.2 } } },
			{ Id = "FleshWaveMax", DisplayName = "Maré de Carne", Cooldown = 12, CastTime = 0.8,
				Effect = { Type = "AreaDamage", Radius = 30, Damage = 30, Delay = 0.6, Knockback = { Speed = 95, Duration = 0.4, Ragdoll = 2.5 } } },
			{ Id = "FrenzyMax", DisplayName = "Frenesi Total", Cooldown = 20, CastTime = 0.6,
				Effect = { Type = "MultiHitArea", Radius = 18, Damage = 10, Hits = 10, Interval = 0.2, Knockback = { Speed = 15, Duration = 0.1 } } },
		},
	} :: CharacterDef,
}

-- Roster na seleção (dono, 2026-09-24): Sahur sai da lista (fica só como acesso antecipado no código);
-- Overlord continua só admin.
CharacterDefs.Order = { "Humano", "Jotaro", "Swift", "Dio", "Kira", "Rick", "Overlord" }

--- "human" | "stand" | "coins" | "vip" | "early" | "admin" | "drop" | "form" (só via ritual, nunca selecionável)
function CharacterDefs.AccessOf(def: CharacterDef): string
	return def.Access or "coins"
end

function CharacterDefs.Get(characterId: string): CharacterDef?
	return CharacterDefs.Characters[characterId]
end

--- Habilidade que substitui o dash universal (Q) deste personagem, se houver.
function CharacterDefs.GetDashOverride(characterId: string): AbilityDef?
	local def = CharacterDefs.Get(characterId)
	return def and def.DashOverride
end

CharacterDefs.PASSIVE_SLOT = 5 -- tecla R (RequestAbility com slot 5)

--- Habilidade do slot: 1..4 = ataques (despertos se `awakened`), 5 = passiva (R).
function CharacterDefs.GetAbility(characterId: string, slot: number, awakened: boolean?): AbilityDef?
	local def = CharacterDefs.Characters[characterId]
	if not def then
		return nil
	end
	if slot == CharacterDefs.PASSIVE_SLOT then
		return def.Passive
	end
	if awakened then
		return def.AwakenedAbilities[slot] or def.Abilities[slot]
	end
	return def.Abilities[slot]
end

--- Kit ativo (4 ataques) conforme o estado.
function CharacterDefs.ActiveAbilities(def: CharacterDef, awakened: boolean?): { AbilityDef }
	return if awakened and #def.AwakenedAbilities > 0 then def.AwakenedAbilities else def.Abilities
end

--- Habilidade pelo Id em qualquer lista do personagem (ataques, despertos, R, Piscar).
function CharacterDefs.FindAbility(def: CharacterDef, abilityId: string): AbilityDef?
	for _, ability in def.Abilities do
		if ability.Id == abilityId then
			return ability
		end
	end
	for _, ability in def.AwakenedAbilities do
		if ability.Id == abilityId then
			return ability
		end
	end
	if def.Passive and def.Passive.Id == abilityId then
		return def.Passive
	end
	if def.DashOverride and def.DashOverride.Id == abilityId then
		return def.DashOverride
	end
	if abilityId == CharacterDefs.ULTIMATE_ABILITY_ID then
		return CharacterDefs.UltimateAbility(def.Id)
	end
	-- efeito encadeado (<Id>_Then): devolve a habilidade-mãe com o Effect do Then
	local baseId = abilityId:match("^(.-)_Then$")
	if baseId then
		local base = CharacterDefs.FindAbility(def, baseId)
		local nextEffect = base and base.Effect.Then
		if base and typeof(nextEffect) == "table" then
			local chained = table.clone(base)
			chained.Id = abilityId
			chained.Effect = nextEffect
			return chained
		end
	end
	return nil
end

CharacterDefs.ULTIMATE_ABILITY_ID = "Ultimate" -- Id do efeito automático da ult (animação/VFX <Char>/Ultimate)

--- Ultimate.Effect embrulhado como AbilityDef (servidor executa; cliente acha por FindAbility).
function CharacterDefs.UltimateAbility(characterId: string): AbilityDef?
	local def = CharacterDefs.Characters[characterId]
	local effect = def and def.Ultimate and def.Ultimate.Effect
	if not effect then
		return nil
	end
	return { Id = CharacterDefs.ULTIMATE_ABILITY_ID, DisplayName = def.DisplayName, Cooldown = 0, CastTime = 0, Effect = effect }
end

--- Duração da forma desperta (Ultimate.Duration, senão CombatConfig.Awakening.Duration — quem chama passa o padrão).
function CharacterDefs.UltimateDuration(characterId: string, default: number): number
	local def = CharacterDefs.Characters[characterId]
	local d = def and def.Ultimate and def.Ultimate.Duration
	return if typeof(d) == "number" and d > 0 then d else default
end

return CharacterDefs
