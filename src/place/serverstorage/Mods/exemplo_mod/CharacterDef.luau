--[[
	CharacterDef — personagem novo (mesmo formato de CharacterDefs do jogo).
	Abilities: índice = tecla (1..3); a última com EnergyCost = 100 é a ULT (G). Tipos de Effect aceitos:
	  Dash { Speed, Duration, Damage, Range, Width, Height, StunSeconds?, Knockback? }
	  Grab { Speed, Duration, Range, Width, Height, Carry, Damage, Finish = "Slam"|"Throw"|"Chokeslam"|"Spin", Knockback? }
	  Teleport { Distance }
	  AreaDamage { Radius, Damage, Delay, StunSeconds?, Knockback?, Offset? }
	  MultiHitArea { Radius, Damage, Hits, Interval }
	  DamageBuff { Multiplier, Duration }      Projectile { Speed, Range, Radius, Damage, Knockback? }
	  Heal { Amount }                          Shield { Multiplier, Duration }
	Knockback = { Speed, Duration, Ragdoll?, Up? }. Tetos do kit: Damage ≤ 120, Multiplier ≤ 3.
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
		{
			Id = "Investida",
			DisplayName = "Investida",
			Cooldown = 7,
			EnergyCost = 0,
			CastTime = 0.3,
			Effect = { Type = "Dash", Speed = 70, Duration = 0.3, Damage = 12, Range = 6, Width = 6, Height = 6, Knockback = { Speed = 40, Duration = 0.2 } },
		},
		{
			Id = "Onda",
			DisplayName = "Onda de Choque",
			Cooldown = 10,
			EnergyCost = 0,
			CastTime = 0.5,
			Effect = { Type = "AreaDamage", Radius = 10, Damage = 18, Delay = 0.35, Knockback = { Speed = 35, Duration = 0.25, Ragdoll = 1.2 } },
		},
		{
			Id = "Explosao",
			DisplayName = "Explosão",
			Cooldown = 30,
			EnergyCost = 100, -- ULT (G)
			CastTime = 0.6,
			Effect = { Type = "AreaDamage", Radius = 14, Damage = 35, Delay = 0.5, Knockback = { Speed = 55, Duration = 0.3, Ragdoll = 2 } },
		},
	},
}
