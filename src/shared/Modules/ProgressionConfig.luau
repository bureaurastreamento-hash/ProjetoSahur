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

--- XP necessário para sair do nível `level` e chegar em `level + 1`.
function ProgressionConfig.XPForLevel(level: number): number
	return 100 + (level - 1) * 40
end

--- Moedas ganhas ao chegar em `level`.
function ProgressionConfig.LevelUpCoins(level: number): number
	return 20 + level * 5
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

-- Maestria por personagem (ref. HB): usar = ganha; nível = título no cartão. Só cosmético/progresso.
ProgressionConfig.Mastery = {
	Kill = 25,
	DuelWin = 30,
	Boss = 40,
	PerLevel = 150, -- XP de maestria por nível
	MaxLevel = 10,
}
function ProgressionConfig.MasteryLevel(xp: number): number
	return math.min(ProgressionConfig.Mastery.MaxLevel, math.floor(xp / ProgressionConfig.Mastery.PerLevel) + 1)
end

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
