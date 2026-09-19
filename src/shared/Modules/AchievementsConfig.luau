--!strict
--[[
	AchievementsConfig
	CONQUISTAS (substituem as missões diárias — decisão do dono, 2026-09-17). Cada conquista é um
	contador que só sobe (`Kind`) até a meta (`Goal`) e paga uma vez: pontos, XP, cosmético, emote ou
	até um personagem. O servidor (AchievementService) é quem conta e paga; o cliente só mostra.

	Dois grupos:
	  - PERMANENTES (`Season = nil`): ficam para sempre. Completar todas = "zerar o jogo"
	    (a conquista `zerou`, que conta as outras permanentes concluídas).
	  - DE PASSE/TEMPORADA (`Season = "<id>"`): só existem enquanto a temporada está no ar. As
	    recompensas delas são LIMITADAS (CosmeticsConfig com `Season`/`Limited`): acabou a temporada,
	    ninguém mais ganha nem pela roleta — só um DEV pode dar. Passe novo = temporada nova aqui,
	    com conquistas e itens novos.

	Contadores (`Kind`) alimentados pelo AchievementService:
	  kills · deaths · duels · duel_wins · boss_damage · boss_kills · playtime (minutos) · level
	  mastery_max (maior nível de maestria) · cosmetics (itens/emotes que possui) · achievements
	  (quantas conquistas PERMANENTES já concluiu) · season_achievements (da temporada ativa)
]]

local AchievementsConfig = {}

export type Reward = {
	Coins: number?,
	XP: number?,
	Cosmetic: string?, -- id em CosmeticsConfig.Items
	Emote: string?, -- id em CosmeticsConfig.Emotes
	Character: string?, -- id em CharacterDefs (desbloqueia)
}

export type Achievement = {
	Id: string,
	Name: string,
	Desc: string, -- %d = meta
	Kind: string,
	Goal: number,
	Reward: Reward,
	Season: string?, -- nil = permanente
}

export type Season = {
	Id: string,
	Name: string,
	Start: { year: number, month: number, day: number }, -- 00:00 UTC deste dia
	Days: number, -- quanto o passe dura
}

-- ---------------------------------------------------------------------------
-- Temporadas / passes. Para abrir a próxima: adicione aqui, crie as conquistas com
-- `Season = "<id>"` e os itens limitados em CosmeticsConfig (Season = "<id>", Limited = true).
-- ---------------------------------------------------------------------------
AchievementsConfig.Seasons = {
	{ Id = "s1", Name = "Passe 1 — Despertar", Start = { year = 2026, month = 9, day = 17 }, Days = 60 },
} :: { Season }

-- ---------------------------------------------------------------------------
-- Conquistas
-- ---------------------------------------------------------------------------
local list: { Achievement } = {
	-- PERMANENTES ------------------------------------------------------------
	{ Id = "kills_10", Name = "Primeiro sangue", Desc = "Elimine %d jogadores", Kind = "kills", Goal = 10, Reward = { Coins = 100, XP = 100 } },
	{ Id = "kills_100", Name = "Encrenqueiro", Desc = "Elimine %d jogadores", Kind = "kills", Goal = 100, Reward = { Coins = 300, XP = 300 } },
	{ Id = "kills_500", Name = "Terror do mapa", Desc = "Elimine %d jogadores", Kind = "kills", Goal = 500, Reward = { Coins = 900, XP = 800, Cosmetic = "cape_black" } },
	{ Id = "duels_10", Name = "Frequentador da arena", Desc = "Jogue %d duelos", Kind = "duels", Goal = 10, Reward = { Coins = 120, XP = 120 } },
	{ Id = "duelwins_5", Name = "Sabe brigar", Desc = "Vença %d duelos", Kind = "duel_wins", Goal = 5, Reward = { Coins = 200, XP = 200 } },
	{ Id = "duelwins_50", Name = "Dono do 1v1", Desc = "Vença %d duelos", Kind = "duel_wins", Goal = 50, Reward = { Coins = 800, XP = 700, Cosmetic = "aura_purple" } },
	{ Id = "boss_1", Name = "Derrubou o monstro", Desc = "Participe de %d vitória contra o boss", Kind = "boss_kills", Goal = 1, Reward = { Coins = 200, XP = 250 } },
	{ Id = "boss_10", Name = "Caçador de bosses", Desc = "Participe de %d vitórias contra o boss", Kind = "boss_kills", Goal = 10, Reward = { Coins = 700, XP = 700, Emote = "flex" } },
	{ Id = "bossdmg_10k", Name = "Bateu até cansar", Desc = "Cause %d de dano ao boss", Kind = "boss_damage", Goal = 10000, Reward = { Coins = 500, XP = 500 } },
	{ Id = "play_60", Name = "Pegou o jeito", Desc = "Jogue %d minutos", Kind = "playtime", Goal = 60, Reward = { Coins = 150, XP = 150 } },
	{ Id = "play_600", Name = "Mora aqui", Desc = "Jogue %d minutos", Kind = "playtime", Goal = 600, Reward = { Coins = 600, XP = 600, Cosmetic = "aura_ember" } },
	{ Id = "level_10", Name = "Veterano", Desc = "Chegue ao nível %d", Kind = "level", Goal = 10, Reward = { Coins = 200, XP = 0 } },
	{ Id = "level_25", Name = "Elite", Desc = "Chegue ao nível %d", Kind = "level", Goal = 25, Reward = { Coins = 500, XP = 0, Emote = "scene_power" } },
	{ Id = "level_50", Name = "Lenda", Desc = "Chegue ao nível %d", Kind = "level", Goal = 50, Reward = { Coins = 1500, XP = 0, Cosmetic = "aura_green" } },
	{ Id = "mastery_max", Name = "Mestre", Desc = "Chegue à maestria %d em algum personagem", Kind = "mastery_max", Goal = 10, Reward = { Coins = 600, XP = 400 } },
	{ Id = "collector_10", Name = "Colecionador", Desc = "Tenha %d cosméticos/emotes", Kind = "cosmetics", Goal = 10, Reward = { Coins = 400, XP = 200 } },
	-- "zerar o jogo": conta as PERMANENTES concluídas (o Goal é preenchido no fim deste arquivo)
	{ Id = "zerou", Name = "ZEROU O SAHUR", Desc = "Conclua as outras %d conquistas permanentes", Kind = "achievements", Goal = 0, Reward = { Coins = 5000, XP = 2000, Cosmetic = "aura_shadow", Emote = "scene_storm" } },

	-- PASSE 1 ----------------------------------------------------------------
	{ Id = "s1_kills_50", Name = "Passe 1: pressão", Desc = "Elimine %d jogadores nesta temporada", Kind = "kills", Goal = 50, Season = "s1", Reward = { Coins = 250, XP = 250 } },
	{ Id = "s1_duelwins_10", Name = "Passe 1: duelista", Desc = "Vença %d duelos nesta temporada", Kind = "duel_wins", Goal = 10, Season = "s1", Reward = { Coins = 300, XP = 300, Emote = "s1_emote_arrow" } },
	{ Id = "s1_boss_3", Name = "Passe 1: ritual", Desc = "Participe de %d vitórias contra o boss", Kind = "boss_kills", Goal = 3, Season = "s1", Reward = { Coins = 400, XP = 400, Cosmetic = "s1_aura_arrow" } },
	{ Id = "s1_play_120", Name = "Passe 1: dedicação", Desc = "Jogue %d minutos nesta temporada", Kind = "playtime", Goal = 120, Season = "s1", Reward = { Coins = 300, XP = 300, Cosmetic = "s1_cape_arrow" } },
	{ Id = "s1_bossdmg_5k", Name = "Passe 1: martelo", Desc = "Cause %d de dano ao boss nesta temporada", Kind = "boss_damage", Goal = 5000, Season = "s1", Reward = { Coins = 350, XP = 350 } },
	{ Id = "s1_complete", Name = "Passe 1 completo", Desc = "Conclua %d conquistas do passe", Kind = "season_achievements", Goal = 5, Season = "s1", Reward = { Coins = 1200, XP = 800, Cosmetic = "s1_aura_arrow_gold" } },
}
AchievementsConfig.List = list

-- Meta da conquista "zerou" = todas as permanentes menos ela mesma
do
	local permanent = 0
	for _, a in list do
		if not a.Season and a.Id ~= "zerou" then
			permanent += 1
		end
	end
	for _, a in list do
		if a.Id == "zerou" then
			a.Goal = permanent
		end
	end
	AchievementsConfig.PermanentCount = permanent
end

local byId: { [string]: Achievement } = {}
for _, a in list do
	byId[a.Id] = a
end

function AchievementsConfig.Get(id: string): Achievement?
	return byId[id]
end

function AchievementsConfig.GetSeason(id: string): Season?
	for _, s in AchievementsConfig.Seasons do
		if s.Id == id then
			return s
		end
	end
	return nil
end

--- Começo e fim (os.time) de uma temporada.
function AchievementsConfig.SeasonWindow(season: Season): (number, number)
	local startAt = os.time({ year = season.Start.year, month = season.Start.month, day = season.Start.day, hour = 0, min = 0, sec = 0 })
	return startAt, startAt + season.Days * 86400
end

--- Temporada no ar agora (nil = nenhuma; acabou o passe e o próximo ainda não abriu).
function AchievementsConfig.ActiveSeason(now: number?): Season?
	local t = now or os.time()
	for _, s in AchievementsConfig.Seasons do
		local startAt, endAt = AchievementsConfig.SeasonWindow(s)
		if t >= startAt and t < endAt then
			return s
		end
	end
	return nil
end

--- Uma conquista vale agora? (permanente sempre; de temporada só enquanto o passe está no ar)
function AchievementsConfig.IsActive(ach: Achievement, now: number?): boolean
	if not ach.Season then
		return true
	end
	local season = AchievementsConfig.ActiveSeason(now)
	return season ~= nil and season.Id == ach.Season
end

--- Conquistas que valem agora (permanentes + as do passe no ar).
function AchievementsConfig.Active(now: number?): { Achievement }
	local out: { Achievement } = {}
	for _, a in list do
		if AchievementsConfig.IsActive(a, now) then
			table.insert(out, a)
		end
	end
	return out
end

--- Quantos dias faltam para o passe acabar (0 = sem passe no ar).
function AchievementsConfig.SeasonDaysLeft(now: number?): number
	local season = AchievementsConfig.ActiveSeason(now)
	if not season then
		return 0
	end
	local _, endAt = AchievementsConfig.SeasonWindow(season)
	return math.max(0, math.ceil((endAt - (now or os.time())) / 86400))
end

return AchievementsConfig
