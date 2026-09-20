--!strict
--[[
	QuestConfig — a HISTÓRIA em capítulos (dono, 2026-09-22): uma linha só; cada capítulo = falar com o NPC
	(um desenvolvedor do grupo, TeamConfig) → cumprir objetivos de battlegrounds → voltar no NPC → recompensa.
	Capítulo final (dono, 2026-09-23): o TRAIDOR é o adryan_keep — aceita-se com ele na cachoeira, ele vira um
	NPC hostil no santuário (TraitorService) e a entrega é com o Humanoider_20 na Taberna (`DeliverNpcUserId`).
	Contadores (`Kind`) vêm do AchievementService (kills, parries, duel_wins, boss_kills, bricks, playtime...) e
	do próprio QuestService (visit_<spot>, streak = maior kill streak). `Max = true` = vale o maior valor.
	Textos/recompensas são PROVISÓRIOS — o dono ajusta depois.
]]


local QuestConfig = {}

export type Objective = { Kind: string, Goal: number, Desc: string, Max: boolean? }
export type Reward = { EventPoints: number?, Coins: number?, XP: number?, Cosmetic: string?, Emote: string?, Title: string? }
export type Spot = { Pos: Vector3, Yaw: number, Label: string }
export type Chapter = {
	Id: string,
	Title: string,
	NpcUserId: number?, -- membro da equipe (TeamConfig) que dá o capítulo; nil = sem NPC
	DeliverNpcUserId: number?, -- quem recebe a entrega quando NÃO é o mesmo NPC (final: o traidor não entrega)
	Spot: string, -- QuestConfig.Spots
	Intro: string, -- ao aceitar
	Progress: string, -- voltou sem terminar
	Done: string, -- ao entregar
	Objectives: { Objective },
	Reward: Reward,
	Locked: boolean?, -- ainda não jogável ("em breve")
}

-- Onde cada NPC fica (o QuestService acha o chão por raycast; Yaw = para onde olha, graus)
QuestConfig.Spots = {
	Taberna = { Pos = Vector3.new(352, -1, 62), Yaw = 180, Label = "Taberna" },
	Praca = { Pos = Vector3.new(124, 0, 96), Yaw = -135, Label = "Praça dos spawns" },
	Lojinha = { Pos = Vector3.new(0, 0, 0), Yaw = 0, Label = "Lojinha" }, -- Pos preenchida pelo ShopNpcService (VendedorSpot + 8 studs)
	Cachoeira = { Pos = Vector3.new(112, -0.87, 322), Yaw = 200, Label = "Cachoeira" },
	ZigurateSE = { Pos = Vector3.new(110, 15.4, 232), Yaw = 180, Label = "Topo do zigurate (sudeste)" },
	MercadoNW = { Pos = Vector3.new(-110, -0.87, -190), Yaw = 0, Label = "Mercado coberto (noroeste)" },
	Santuario = { Pos = Vector3.new(98, 0.5, 396), Yaw = 180, Label = "Santuário do boss" },
} :: { [string]: Spot }

-- Capítulo final: o traidor vira um NPC hostil (rig R6 com o avatar dele) no santuário do boss. Números de
-- balanceamento aqui; a IA é a do BotService (TraitorService só monta o bot e cuida do crédito). Outros jogadores podem ajudar; crédito = deu dano E está
-- no capítulo final ativo.
QuestConfig.Traitor = {
	UserId = 7521923542, -- adryan_keep
	Title = "TRAIDOR",
	-- v2 (dono, 2026-09-23): o traidor é um BOT ESPECIAL (BotService) com o combate real do personagem abaixo —
	-- combo de M1, dash, block/parry, habilidades 1–3, despertar + ULT — e números de chefe. Mais OP que o Big C.H.O.P.
	CharacterId = "Dio", -- kit que ele usa (após o redesign B: kit próprio)
	HealthMult = 4, -- × CombatConfig.MaxHealth
	DamageMult = 1.5, -- × dano de soco e habilidade (atributo DamageMult no Model)
	WalkSpeed = 26, -- base (acima do sprint do jogador, 24)
	ChaseSpeed = 30, -- fase 2 (metade da vida)
	PhaseTwoAt = 0.5,
	PhaseTwoDamageMult = 1.8, -- fase 2: bate ainda mais forte
	UltEvery = 40, -- s: recarrega a ult (entra com ela cheia)
	ArenaRadius = 45, -- (legado) raio do santuário onde nasce
	ChaseRadius = 300, -- à solta: enxerga/persegue lutadores até aqui a partir de onde ESTÁ (mapa inteiro)
	SpawnPartName = "BossSpawn", -- Workspace.Sahur.ArenaExtras (Props)
	ArenaPartName = "BossArena",
	AbandonSeconds = 120, -- sem ninguém vivo por perto por esse tempo = some (fala de novo com o NPC para voltar)
	-- IA (override de BotService.Config): mais habilidade, mais dash, guarda melhor, ult de mais longe
	Tuning = { AbilityChancePerTick = 0.3, DashChancePerTick = 0.4, BlockChancePerTick = 0.35, UltRange = 16, CancelChancePerTick = 0.6 },
}

QuestConfig.TalkDistance = 14 -- studs (E no NPC)
QuestConfig.VisitRadius = 18 -- studs para contar "visitou o lugar"

QuestConfig.Chapters = {
	{
		Id = "cap1", Title = "Primeiros socos", NpcUserId = 3792294725, Spot = "Taberna",
		Intro = "Chegou agora? Aqui a conversa é na porrada. Mostra que sabe brigar: derruba uns e me prova que consegue PARRYAR (F bem antes do golpe).",
		Progress = "Ainda não. Volta quando tiver derrubado gente e aparado uns golpes.",
		Done = "Isso! Parry no tempo certo vira crítico — lembra disso. Toma, pelo esforço.",
		Objectives = {
			{ Kind = "kills", Goal = 5, Desc = "Elimine %d jogadores" },
			{ Kind = "parries", Goal = 3, Desc = "Faça %d parries" },
		},
		Reward = { EventPoints = 100, Coins = 150, XP = 100 },
	},
	{
		Id = "cap2", Title = "A praça é minha", NpcUserId = 435519507, Spot = "Praca",
		Intro = "Essa praça vive lotada de gente querendo aparecer. Limpa ela pra mim — e emenda as kills, quero ver STREAK.",
		Progress = "Streak é sem morrer no meio, hein. Continua.",
		Done = "Agora sim a praça tem dono. Boa.",
		Objectives = {
			{ Kind = "kills", Goal = 15, Desc = "Elimine %d jogadores" },
			{ Kind = "streak", Goal = 3, Desc = "Faça um kill streak de %d", Max = true },
		},
		Reward = { EventPoints = 150, Coins = 200, XP = 200 },
	},
	{
		Id = "cap3", Title = "Demolição", NpcUserId = 1955537372, Spot = "Lojinha",
		Intro = "Vê aqueles bairros de tijolo? Quero ver eles no chão. Soco, habilidade, tanto faz — o 4º golpe e a ult derrubam o dobro.",
		Progress = "Tijolo ainda em pé é tijolo mal socado.",
		Done = "Uma nuvem de poeira daquelas... é disso que eu gosto.",
		Objectives = {
			{ Kind = "bricks", Goal = 150, Desc = "Derrube %d tijolos das construções" },
			{ Kind = "kills", Goal = 10, Desc = "Elimine %d jogadores" },
		},
		Reward = { EventPoints = 200, Coins = 250, XP = 250 },
	},
	{
		Id = "cap4", Title = "O segredo da cachoeira", NpcUserId = 7521923542, Spot = "Cachoeira",
		Intro = "Dizem que atrás dessa água tem um lugar que ninguém deveria ver. Atravessa o véu, acha o santuário e volta inteiro.",
		Progress = "Você ainda não entrou lá. É só atravessar a cachoeira.",
		Done = "Então você viu o altar... Guarda esse segredo. A flecha aparece à noite.",
		Objectives = {
			{ Kind = "visit_Santuario", Goal = 1, Desc = "Entre no santuário atrás da cachoeira" },
			{ Kind = "kills", Goal = 10, Desc = "Elimine %d jogadores" },
		},
		Reward = { EventPoints = 200, Coins = 200, XP = 300 },
	},
	{
		Id = "cap5", Title = "Rei do zigurate", NpcUserId = 3751306055, Spot = "ZigurateSE",
		Intro = "Subiu até aqui? Então serve. Quero ver você vencendo DUELOS (J em alguém) — 1v1, sem desculpa.",
		Progress = "Duelo se aceita com J. Vence uns e volta.",
		Done = "Três duelos. Tá virando gente grande.",
		Objectives = {
			{ Kind = "duel_wins", Goal = 3, Desc = "Vença %d duelos" },
			{ Kind = "kills", Goal = 20, Desc = "Elimine %d jogadores" },
		},
		Reward = { EventPoints = 250, Coins = 300, XP = 350 },
	},
	{
		Id = "cap6", Title = "Caçada", NpcUserId = 1712538599, Spot = "MercadoNW",
		Intro = "O Big C.H.O.P. aparece de tempos em tempos — e à noite alguém pode invocar ele no altar. Participa de uma vitória contra o boss.",
		Progress = "O boss ainda tá de pé por aí? Vai lá.",
		Done = "Derrubou o monstro. O loot é por ranking de dano, sabia?",
		Objectives = {
			{ Kind = "boss_kills", Goal = 1, Desc = "Participe de %d vitória contra o boss" },
			{ Kind = "kills", Goal = 25, Desc = "Elimine %d jogadores" },
		},
		Reward = { EventPoints = 300, Coins = 400, XP = 400 },
	},
	{
		Id = "cap7", Title = "O ritual", NpcUserId = 3352486957, Spot = "Santuario",
		Intro = "Você chegou longe. Antes do final, prova que domina o combate: streak de 5, muitos parries, muitos corpos.",
		Progress = "Ainda falta. O final não espera qualquer um.",
		Done = "...Tem algo errado com a equipe. Alguém está traindo a gente. O adryan anda sumindo perto da cachoeira. Vai lá — e toma cuidado.",
		Objectives = {
			{ Kind = "streak", Goal = 5, Desc = "Faça um kill streak de %d", Max = true },
			{ Kind = "parries", Goal = 10, Desc = "Faça %d parries" },
			{ Kind = "kills", Goal = 30, Desc = "Elimine %d jogadores" },
		},
		Reward = { EventPoints = 400, Coins = 500, XP = 600, Emote = "flex" },
	},
	{
		Id = "final", Title = "O traidor", NpcUserId = 7521923542, DeliverNpcUserId = 3792294725, Spot = "Cachoeira",
		Intro = "...Então você chegou até aqui. Sim, fui eu: a flecha, o altar, o monstro — tudo. Ninguém ia descobrir. Me encontra atrás da cachoeira, no santuário. Vamos ver se você é tão bom quanto dizem.",
		Progress = "Ainda de pé? Estou te esperando no santuário. Atravessa a água.",
		Done = "...O adryan? Nunca imaginei. Você salvou a equipe — e o Sahur. Obrigado, de verdade. Você zerou a história.",
		Objectives = { { Kind = "traitor_kill", Goal = 1, Desc = "Derrote o traidor no santuário" } },
		Reward = { EventPoints = 1000, Coins = 1000, XP = 1500 },
	},
} :: { Chapter }

function QuestConfig.Get(index: number): Chapter?
	return QuestConfig.Chapters[index]
end

return QuestConfig
