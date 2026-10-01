--!strict
--[[
	ProgressionConfig
	Regras de progressão fora do combate: XP/nível, recompensa diária e missões diárias.
	Tudo é decidido no servidor (ProgressionService); o cliente só exibe.
]]

local ProgressionConfig = {}

-- XP ------------------------------------------------------------------------
ProgressionConfig.MaxLevel = 50
ProgressionConfig.XP = {
	Kill = 20,
	DuelWin = 60,
	DuelLoss = 20,
	BossPool = 300, -- dividido por dano entre quem bateu no boss
	BossMin = 30,
	BossTopBonus = 60,
}

-- PvE da campanha. Só estes identificadores pagam: bonecos de treino e bots DEV não geram farm.
-- Drops = materiais (MaterialConfig) com chance POR participante; Min/Max = quantidade quando cai.
export type Drop = { Item: string, Chance: number, Min: number, Max: number }
export type NpcReward = { XP: number, Coins: number, Boss: boolean?, ArrowChance: number?, Drops: { Drop }? }
ProgressionConfig.Npcs = {
	fx_tutorial_enemy = { XP = 12, Coins = 1, Drops = { { Item = "mat:nevoa", Chance = 0.35, Min = 1, Max = 1 } } },
	fx_campos_enemy = { XP = 18, Coins = 1, Drops = { { Item = "mat:nevoa", Chance = 0.5, Min = 1, Max = 2 } } }, -- Campos da Névoa
	fx_campos_forte = { XP = 30, Coins = 2, Drops = { { Item = "mat:nevoa", Chance = 0.7, Min = 1, Max = 3 }, { Item = "mat:couro_capataz", Chance = 0.08, Min = 1, Max = 1 }, { Item = "mat:fibra_antiga", Chance = 0.035, Min = 1, Max = 1 } } },
	fx_capataz = { XP = 120, Coins = 8, Boss = true, ArrowChance = 0.02, -- miniboss dos Campos (renasce)
		Drops = { { Item = "mat:couro_capataz", Chance = 0.6, Min = 1, Max = 2 }, { Item = "mat:nevoa", Chance = 1, Min = 3, Max = 5 } } },
	fx_pedra_enemy = { XP = 24, Coins = 2, Drops = { { Item = "mat:areia_negra", Chance = 0.3, Min = 1, Max = 1 } } },
	fx_sol_enemy = { XP = 32, Coins = 2 },
	fx_canion_espectro = { XP = 60, Coins = 4, Drops = { { Item = "mat:areia_negra", Chance = 0.6, Min = 1, Max = 2 } } }, -- Cânion Fantasma (WorldEventsService)
	fx_mascara_boss = { XP = 90, Coins = 5, Boss = true, ArrowChance = 0.03, Drops = { { Item = "mat:lasca_mascara", Chance = 0.35, Min = 1, Max = 1 } } },
	fx_cap1_boss = { XP = 160, Coins = 8, Boss = true, ArrowChance = 0.05, Drops = { { Item = "mat:lasca_mascara", Chance = 0.5, Min = 1, Max = 2 } } },
	fx_solnegro_boss = { XP = 100, Coins = 6, Boss = true, ArrowChance = 0.05 },
	fx_mare_colapso_boss = { XP = 100, Coins = 6, Boss = true, ArrowChance = 0.05 },
	fx_mare_avatar = { XP = 200, Coins = 12, Boss = true, ArrowChance = 0.05 },
	fx_costa_guard = { XP = 22, Coins = 2 },
	fx_costa_boss = { XP = 160, Coins = 10, Boss = true, ArrowChance = 0.05 },
	fx_ambar_boss = { XP = 140, Coins = 9, Boss = true, ArrowChance = 0.05 },
	fx_sol_boss = { XP = 120, Coins = 8, Boss = true, ArrowChance = 0.05 },
} :: { [string]: NpcReward }
ProgressionConfig.PveCredit = { MinDamageFraction = 0.05, Seconds = 30, Radius = 150 }

--- XP necessário para sair do nível `level` e chegar em `level + 1`.
function ProgressionConfig.XPForLevel(level: number): number
	return 100 + (level - 1) * 40
end

--- Moedas ganhas ao chegar em `level`.
function ProgressionConfig.LevelUpCoins(level: number): number
	return 6 + level * 2
end

-- Recompensa diária: removida (2026-09-15). Só o campo `daily` do perfil sobrevive, sem uso.

-- Missões diárias -----------------------------------------------------------
export type MissionDef = {
	id: string,
	kind: "kills" | "duels" | "duel_wins" | "boss_damage" | "playtime" | "boss_kills",
	goal: number,
	coins: number,
	xp: number,
	text: string, -- %d = goal
}

-- Maestria por personagem/Stand: usar = ganha. Nos Stands ela LIBERA as teclas (StandConfig.SlotUnlock).
ProgressionConfig.Mastery = {
	Kill = 25,
	NpcKill = 12, -- mob da campanha/bot (29/09)
	NpcBoss = 80, -- chefe da campanha (StoryKillKind com "boss")
	DuelWin = 30,
	Boss = 40,
	PerLevel = 150, -- XP de maestria por nível
	MaxLevel = 10,
}
function ProgressionConfig.MasteryLevel(xp: number): number
	return math.min(ProgressionConfig.Mastery.MaxLevel, math.floor(xp / ProgressionConfig.Mastery.PerLevel) + 1)
end

-- Títulos (tag antes do nome; VIP tem prioridade): por nível ou maestria máxima em algum personagem.
ProgressionConfig.Titles = {
	{ Level = 40, Title = "Lenda" },
	{ Level = 25, Title = "Elite" },
	{ Level = 10, Title = "Veterano" },
}
ProgressionConfig.MasterTitle = "Mestre" -- maestria no máximo em algum personagem: "Mestre"

ProgressionConfig.MissionsPerDay = 3
local MissionPool: { MissionDef } = {
	{ id = "kills10", kind = "kills", goal = 10, coins = 80, xp = 100, text = "Elimine %d jogadores" },
	{ id = "kills25", kind = "kills", goal = 25, coins = 150, xp = 200, text = "Elimine %d jogadores" },
	{ id = "duels2", kind = "duels", goal = 2, coins = 60, xp = 80, text = "Jogue %d duelos" },
	{ id = "duelwin1", kind = "duel_wins", goal = 1, coins = 100, xp = 120, text = "Vença %d duelo" },
	{ id = "bossdmg600", kind = "boss_damage", goal = 600, coins = 100, xp = 120, text = "Cause %d de dano ao boss" },
	{ id = "bosskill1", kind = "boss_kills", goal = 1, coins = 150, xp = 200, text = "Participe de %d vitória contra o boss" },
	{ id = "play15", kind = "playtime", goal = 15, coins = 50, xp = 60, text = "Jogue por %d minutos" },
}
ProgressionConfig.MissionPool = MissionPool

--- Dia atual em UTC (inteiro) — muda à meia-noite UTC.
function ProgressionConfig.DayIndex(now: number?): number
	return (now or os.time()) // 86400
end

return ProgressionConfig
