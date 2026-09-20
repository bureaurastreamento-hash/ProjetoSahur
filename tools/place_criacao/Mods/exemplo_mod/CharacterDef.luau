--[[
	CharacterDef — personagem novo (mesmo formato de CharacterDefs do jogo, redesign 2026-09-24).
	  Abilities          4 ataques (teclas 1..4), só cooldown
	  Passive            1 suporte (tecla R): Heal / Shield / Buff / Teleport de fuga…
	  Ultimate           { Duration (5–40 s), DamageMultiplier?, SpeedMultiplier?, Effect? } — G com a barra cheia =
	                     despertar (cutscene) e por Duration s os 4 ataques VIRAM os AwakenedAbilities
	  AwakenedAbilities  4 golpes despertos (teclas 1..4 enquanto durar; OncePerAwakening = 1× por despertar)
	Tipos de Effect aceitos:
	  Dash { Speed, Duration, Damage, Range, Width, Height, HealPerHit?, StunSeconds?, Knockback? }
	  Grab { Speed, Duration, Range, Width, Height, Carry, Damage, Finish = "Slam"|"Throw"|"Chokeslam"|"Spin", Knockback? }
	  Teleport { Distance, Backward? }         AreaDamage { Radius, Damage, Delay, StunSeconds?, Knockback?, Offset? }
	  MultiHitArea { Radius, Damage, Hits, Interval, Offset? }
	  Projectile { Speed, Range, Radius, Damage, Knockback?, Count?, Spread?, Interval?, AreaRadius?, AreaDamage? }
	  Heal { Amount, Cleanse? }                Shield { Multiplier, Duration }
	  Buff { Damage?, Speed?, Duration }       Mark { Radius, Damage, ExplodeRadius, ExplodeDamage, AutoDelay? }
	  Homing { Duration, Speed, Radius, Damage, Count? }   Rewind { Delay, Radius?, Damage? }
	  TimeDome { Radius, Duration, SlowMultiplier, SelfMultiplier, BreakMultiplier, NoBreak? }
	  Qualquer Effect aceita Then = { <outro Effect> } (+ ThenDelay) para encadear dois efeitos.
	Knockback = { Speed, Duration, Ragdoll?, Up? }. Tetos do kit: Damage ≤ 120, Multiplier ≤ 3, cura ≤ 400.
	Assets opcionais (pastas do mod): Animations/<Id>/<AbilityId>, Sounds/<Id>/<AbilityId>, VFX/<Id>/<AbilityId>.
	Ao ligar o mod todo mundo da sala recebe o personagem; ao desligar, quem estava com ele volta ao padrão.
]]
return {
	Id = "Exemplo", -- NÃO pode ser um id que já existe (Jotaro, Swift, Dio, Kira, Rick, Sahur, Overlord)
	DisplayName = "Exemplo",
	UnlockCost = 0,
	Tagline = "Personagem de teste do kit",
	Color = Color3.fromRGB(80, 220, 140),
	Image = "",
	Abilities = {
		{ Id = "Investida", DisplayName = "Investida", Cooldown = 7, CastTime = 0.3,
			Effect = { Type = "Dash", Speed = 70, Duration = 0.3, Damage = 12, Range = 6, Width = 6, Height = 6, Knockback = { Speed = 40, Duration = 0.2 } } },
		{ Id = "Onda", DisplayName = "Onda de Choque", Cooldown = 10, CastTime = 0.5,
			Effect = { Type = "AreaDamage", Radius = 10, Damage = 18, Delay = 0.35, Knockback = { Speed = 35, Duration = 0.25, Ragdoll = 1.2 } } },
		{ Id = "Disparo", DisplayName = "Disparo", Cooldown = 5, CastTime = 0.25,
			Effect = { Type = "Projectile", Speed = 100, Range = 50, Radius = 2.5, Damage = 12 } },
		{ Id = "Rajada", DisplayName = "Rajada", Cooldown = 9, CastTime = 0.3,
			Effect = { Type = "MultiHitArea", Radius = 6, Offset = 4, Damage = 4, Hits = 5, Interval = 0.12 } },
	},
	Passive = { Id = "Folego", DisplayName = "Fôlego", Cooldown = 20, CastTime = 0.3,
		Effect = { Type = "Heal", Amount = 20, Then = { Type = "Buff", Speed = 1.2, Duration = 4 } } },
	Ultimate = { Duration = 18 },
	AwakenedAbilities = {
		{ Id = "InvestidaMax", DisplayName = "Investida Máxima", Cooldown = 7, CastTime = 0.3,
			Effect = { Type = "Dash", Speed = 85, Duration = 0.35, Damage = 20, Range = 7, Width = 7, Height = 7, Knockback = { Speed = 55, Duration = 0.25, Ragdoll = 1.5 } } },
		{ Id = "Explosao", DisplayName = "Explosão", Cooldown = 12, CastTime = 0.6,
			Effect = { Type = "AreaDamage", Radius = 14, Damage = 35, Delay = 0.5, Knockback = { Speed = 55, Duration = 0.3, Ragdoll = 2 } } },
		{ Id = "DisparoTriplo", DisplayName = "Disparo Triplo", Cooldown = 5, CastTime = 0.25,
			Effect = { Type = "Projectile", Count = 3, Spread = 15, Speed = 100, Range = 50, Radius = 2.5, Damage = 12 } },
		{ Id = "RajadaMax", DisplayName = "Rajada Máxima", Cooldown = 9, CastTime = 0.3,
			Effect = { Type = "MultiHitArea", Radius = 7, Offset = 4, Damage = 4, Hits = 10, Interval = 0.08, Knockback = { Speed = 45, Duration = 0.3, Ragdoll = 1.2 } } },
	},
}
