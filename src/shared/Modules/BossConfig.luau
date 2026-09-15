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
	Radius: number, -- área do dano (esfera no boss ou ponto)
	Cooldown: number,
	Knockback: { Speed: number, Duration: number }?,
}

BossConfig.Attacks = {
	Swipe = { Damage = 18, Windup = 0.45, Range = 9, Radius = 8, Cooldown = 1.4, Knockback = { Speed = 30, Duration = 0.15 } } :: Attack,
	Slam = { Damage = 30, Windup = 0.9, Range = 14, Radius = 14, Cooldown = 4, Knockback = { Speed = 55, Duration = 0.25 } } :: Attack,
	-- fase 2: investida até o alvo, dano ao chegar
	Charge = { Damage = 25, Windup = 0.6, Range = 40, Radius = 7, Cooldown = 7, Knockback = { Speed = 60, Duration = 0.3 } } :: Attack,
}

return BossConfig
