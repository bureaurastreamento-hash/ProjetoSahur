--!strict
--[[
	DataConfig
	Formato do perfil salvo por jogador e regras de recompensa.
	Mudou o formato? Suba SchemaVersion e trate a migração em DataService.migrate().
]]

local StoryConfig = require(script.Parent.StoryConfig)
local DataConfig = {}

DataConfig.StoreName = "PlayerData"
DataConfig.SchemaVersion = 5 -- 3 = eventPoints (2026-09-20); 4 = lastUpdateSeen (2026-09-25); 5 = Stands/raças/inventário (2026-09-29)
-- O DataStore é "<StoreName>_v<SchemaVersion>": subir a versão COMEÇA DO ZERO (o v4 fica intacto). A 5 foi o WIPE
-- pedido pelo dono para a leva de Stands (todo mundo renasce humano).

DataConfig.AutosaveInterval = 90 -- segundos
DataConfig.LoadRetries = 3
DataConfig.SaveRetries = 3
DataConfig.RetryBaseDelay = 1 -- segundos; dobra a cada tentativa
DataConfig.SessionLeaseSeconds = 180 -- renova a cada autosave; sessão anterior não pode sobrescrever a nova

-- DEBUG: força falha em todas as chamadas ao DataStore para testar o fallback.
-- TODO(launch): manter false
DataConfig.SimulateFailure = false

-- Pontos são para ser DIFÍCEIS de juntar (dono, 2026-09-20: "deixar mais difícil conseguir pontos").
DataConfig.Rewards = {
	Win = 20,
	Loss = 3,
	Kill = 2,
}

export type Stats = { wins: number, losses: number, kills: number, deaths: number, matches: number, tournamentWins: number }
export type Mission = { id: string, progress: number, done: boolean } -- legado (missões diárias, saíram em 2026-09-17)
-- Conquistas (AchievementsConfig): contadores que só sobem + o que já foi pago.
export type Achievements = {
	counters: { [string]: number }, -- kills, duels, duel_wins, boss_damage, boss_kills, playtime…
	done: { [string]: boolean }, -- id da conquista -> já pagou
	season: { id: string, counters: { [string]: number } }, -- contadores DO PASSE atual (zeram no passe novo)
}
export type Quests = {
	chapter: number, -- capítulo atual (1 = primeiro; > #QuestConfig.Chapters = zerou a história)
	active: boolean, -- já falou com o NPC do capítulo (objetivos contando)
	counters: { [string]: number }, -- progresso dos objetivos do capítulo ATUAL (zera ao avançar)
	done: { [string]: boolean }, -- capítulos concluídos (Id)
}
export type WorldProgress = {
	region: string,
	checkpoint: string,
	discovered: { [string]: boolean },
}
export type StoryProgress = {
	rev: number, -- StoryConfig.Revision em que os índices de ato foram gravados (StoryService.migrate)
	chapter: string,
	act: number,
	counters: { [string]: number },
	flags: { [string]: boolean },
	traces: { [string]: boolean },
	completed: { [string]: boolean },
}

export type Profile = {
	schemaVersion: number,
	coins: number,
	faction: string, -- vazio = escolha inicial pendente; não altera campanha/build
	honor: { points: number, recentVictims: { [string]: number } },
	bounty: { points: number, recentVictims: { [string]: number } },
	eventPoints: number, -- pontos ESPECIAIS de evento (mini eventos do Canion); só o vendedor aceita
	unlockedCharacters: { string },
	stats: Stats,
	-- progressão (ProgressionService)
	xp: number, -- XP dentro do nível atual
	level: number,
	daily: { lastDay: number, streak: number }, -- lastDay = ProgressionConfig.DayIndex
	missions: { day: number, list: { Mission } }, -- legado: fica no save, ninguém mais usa
	achievements: Achievements,
	quests: Quests, -- história em capítulos (QuestService, 2026-09-22)
	world: WorldProgress, -- F/X: região/checkpoint/descobertas (WorldService)
	story: StoryProgress, -- F/X: capítulo, ato, flags e Rastros de Carlos (StoryService)
	-- cosméticos (CosmeticsService): ids de CosmeticsConfig
	cosmetics: { owned: { string }, equipped: { [string]: string } }, -- equipped[categoria] = id
	emotes: { string }, -- ids comprados (os de custo 0 são de todos)
	mastery: { [string]: number }, -- characterId -> XP de maestria (ProgressionConfig.Mastery)
	rating: number, -- Elo de duelo 1v1 (DuelConfig.RatingStart)
	clanTag: string?, -- clã atual (ClanService; a verdade é o registro do clã, isto é cache)
	settings: { [string]: any }, -- acessibilidade/controles (Controls.Settings; SettingsService valida)
	lastUpdateSeen: string, -- última versão do log de atualização que o jogador viu ("" = nenhuma; UpdateLogService)
	-- Stands e raças (StandService/StandConfig, schema 5)
	power: string, -- Stand ATIVO (CharacterDefs id com Access "stand"); "" = humano sem Stand
	race: string, -- StandConfig.Races id ("Humano" por padrão)
	inventory: { [string]: number }, -- itemId -> quantidade ("flecha", "stand:<id>", "raca:<id>")
	build: { route: string, weapon: string, style: string, techniqueTier: number },
	born: boolean, -- já passou pelo sorteio de nascimento ("abençoado")
	receipts: { [string]: boolean }, -- PurchaseId já entregue (mesmo save da recompensa)
}

function DataConfig.DefaultProfile(): Profile
	return {
		schemaVersion = DataConfig.SchemaVersion,
		coins = 0,
		faction = "",
		honor = { points = 0, recentVictims = {} },
		bounty = { points = 0, recentVictims = {} },
		eventPoints = 0,
		unlockedCharacters = { "Humano" },
		stats = { wins = 0, losses = 0, kills = 0, deaths = 0, matches = 0, tournamentWins = 0 }, -- tournamentWins: "Último de pé" (D3); perfil antigo começa em 0 (a carga copia só chaves conhecidas)
		xp = 0,
		level = 1,
		daily = { lastDay = 0, streak = 0 },
		missions = { day = 0, list = {} },
		achievements = { counters = {}, done = {}, season = { id = "", counters = {} } },
		quests = { chapter = 1, active = false, counters = {}, done = {} }, -- QuestService (história em capítulos)
		world = { region = "ilha_tutorial", checkpoint = "porto", discovered = { ilha_tutorial = true } },
		story = { rev = StoryConfig.Revision, chapter = "cap1", act = 1, counters = {}, flags = {}, traces = {}, completed = {} },
		cosmetics = { owned = {}, equipped = {} },
		emotes = {},
		mastery = {},
		rating = 1000,
		settings = {},
		lastUpdateSeen = "",
		power = "",
		race = "Humano",
		inventory = {},
		build = { route = "", weapon = "", style = "", techniqueTier = 0 },
		born = false,
		receipts = {},
	}
end

return DataConfig
