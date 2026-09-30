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

-- Arco battlegrounds preservado como legado. A campanha ativa é StoryConfig (cânone F/X).
-- Não expor a revelação antiga de Adryan nem alterar conquistas/recompensas já salvas.
QuestConfig.Enabled = false

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
	Praca = { Pos = Vector3.new(18, 0.5, 128), Yaw = -50, Label = "Praça da vila" },
	Lojinha = { Pos = Vector3.new(0, 0, 0), Yaw = 0, Label = "Lojinha" }, -- Pos preenchida pelo ShopNpcService (VendedorSpot + 8 studs)
	Cachoeira = { Pos = Vector3.new(914, -0.87, -681), Yaw = 200, Label = "Cachoeira (Deserto do Sol)" },
	ZigurateSE = { Pos = Vector3.new(1580, 15.4, -56), Yaw = 180, Label = "Topo do zigurate (Rota do Eclipse)" },
	MercadoNW = { Pos = Vector3.new(1110, -0.87, -432), Yaw = 0, Label = "Mercado coberto (Deserto do Sol)" },
	Santuario = { Pos = Vector3.new(900, 0.5, -607), Yaw = 180, Label = "Santuário do boss (Deserto do Sol)" },
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
	Tuning = { AbilityChancePerTick = 0.3, DashChancePerTick = 0.4, BlockChancePerTick = 0.35, CancelChancePerTick = 0.6 },
}

QuestConfig.TalkDistance = 14 -- studs (E no NPC)
QuestConfig.VisitRadius = 18 -- studs para contar "visitou o lugar"

-- ARCO (dono, C0 2026-09-23/25): o adryan aparece CEDO e "ajuda" (favor generoso demais no cap2b), depois cada dev
-- deixa uma pista (LRY: ele nunca pagou ninguém; Toduro: pegadas na cachoeira; Ravy: pediu para ninguém subir à
-- noite; approx_verde: viu ele no altar) até o RIP_ACE juntar tudo no cap7 e o final revelar. Um NPC por membro:
-- todos os capítulos do adryan usam o Spot "Cachoeira" (o NPC fica no spot do primeiro capítulo dele).
-- Progresso salvo por Id (`done`), então inserir capítulo no meio não quebra perfil antigo (QuestService migra).
QuestConfig.Chapters = {
	{
		Id = "cap1", Title = "Primeiros socos", NpcUserId = 3792294725, Spot = "Taberna",
		Intro = "Chegou agora? Aqui a conversa é na porrada. A equipe inteira tá espalhada pelo mapa — cada um vai te pedir uma coisa. Começa comigo: derruba uns e me prova que consegue PARRYAR (F bem antes do golpe).",
		Progress = "Ainda não. Volta quando tiver derrubado gente e aparado uns golpes.",
		Done = "Isso! Parry no tempo certo vira crítico — lembra disso. Toma, pelo esforço. Ah, e se cruzar com o adryan lá na cachoeira, manda ele aparecer mais na Taberna. Anda sumido.",
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
		Done = "Agora sim a praça tem dono. Boa. O adryan tava te procurando, por sinal — disse que tem um trabalho pra você. Ele paga bem. Bem até demais.",
		Objectives = {
			{ Kind = "kills", Goal = 15, Desc = "Elimine %d jogadores" },
			{ Kind = "streak", Goal = 3, Desc = "Faça um kill streak de %d", Max = true },
		},
		Reward = { EventPoints = 150, Coins = 200, XP = 200 },
	},
	{
		Id = "cap2b", Title = "Um favor para o adryan", NpcUserId = 7521923542, Spot = "Cachoeira",
		Intro = "Ah, você. Ouvi falar. Preciso de um favor — e pago bem. Quero o mapa MOVIMENTADO longe daqui: passa no mercado do noroeste, sobe no zigurate, arruma briga. Quanto mais gente olhando pra lá, melhor. Não pergunta por quê.",
		Progress = "Mercado, zigurate, briga. Longe da cachoeira. É simples.",
		Done = "Perfeito. Ninguém passou por aqui enquanto você estava fora, né? ...Esquece. Toma o que prometi — e mais um pouco. Você não me viu hoje.",
		Objectives = {
			{ Kind = "visit_MercadoNW", Goal = 1, Desc = "Passe pelo mercado coberto (noroeste)" },
			{ Kind = "visit_ZigurateSE", Goal = 1, Desc = "Suba no zigurate (sudeste)" },
			{ Kind = "kills", Goal = 10, Desc = "Elimine %d jogadores" },
		},
		Reward = { EventPoints = 300, Coins = 350, XP = 200 },
	},
	{
		Id = "cap3", Title = "Demolição", NpcUserId = 1955537372, Spot = "Lojinha",
		Intro = "Vê aqueles bairros de tijolo? Quero ver eles no chão. Soco, habilidade, tanto faz — o 4º golpe e a ult derrubam o dobro.",
		Progress = "Tijolo ainda em pé é tijolo mal socado.",
		Done = "Uma nuvem de poeira daquelas... é disso que eu gosto. ...O adryan te pagou bem, não foi? Engraçado. Em anos de equipe ele nunca pagou NINGUÉM. De onde tá saindo esse dinheiro?",
		Objectives = {
			{ Kind = "bricks", Goal = 150, Desc = "Derrube %d tijolos das construções" },
			{ Kind = "kills", Goal = 10, Desc = "Elimine %d jogadores" },
		},
		Reward = { EventPoints = 200, Coins = 250, XP = 250 },
	},
	{
		Id = "cap4", Title = "O segredo da cachoeira", NpcUserId = 7521923542, Spot = "Cachoeira",
		Intro = "Você de novo. Já que é de confiança... dizem que atrás dessa água tem um lugar que ninguém deveria ver. Atravessa o véu, acha o santuário e volta inteiro. Quero saber se dá pra entrar.",
		Progress = "Você ainda não entrou lá. É só atravessar a cachoeira.",
		Done = "Então dá pra entrar. E você viu o altar... Guarda esse segredo. Se alguém perguntar — principalmente o Humanoider — você não viu nada. A flecha aparece à noite.",
		Objectives = {
			{ Kind = "visit_Santuario", Goal = 1, Desc = "Entre no santuário atrás da cachoeira" },
			{ Kind = "kills", Goal = 10, Desc = "Elimine %d jogadores" },
		},
		Reward = { EventPoints = 200, Coins = 200, XP = 300 },
	},
	{
		Id = "cap4b", Title = "Pegadas na lama", NpcUserId = 435519507, Spot = "Praca",
		Intro = "Psiu. Alguém anda fuçando a cachoeira de madrugada — tem pegadas frescas na lama e o boss apareceu DUAS vezes essa semana, sem ninguém invocar. Vai lá, bate no que aparecer e volta. Quero saber o que tá acontecendo.",
		Progress = "Cachoeira, parries, e continua derrubando gente. Fica de olho em quem anda por lá.",
		Done = "Pegadas de bota de dev. Do tamanho do pé do adryan... Não. Deve ser coincidência. Ele é da equipe desde o começo.",
		Objectives = {
			{ Kind = "visit_Cachoeira", Goal = 1, Desc = "Vá até a cachoeira" },
			{ Kind = "parries", Goal = 5, Desc = "Faça %d parries" },
			{ Kind = "kills", Goal = 15, Desc = "Elimine %d jogadores" },
		},
		Reward = { EventPoints = 250, Coins = 250, XP = 300 },
	},
	{
		Id = "cap5", Title = "Rei do zigurate", NpcUserId = 3751306055, Spot = "ZigurateSE",
		Intro = "Subiu até aqui? Então serve. Quero ver você vencendo DUELOS (J em alguém) — 1v1, sem desculpa. E fica: o adryan me pediu pra não deixar NINGUÉM subir aqui à noite. Daqui dá pra ver a cachoeira inteira. Esquisito, né?",
		Progress = "Duelo se aceita com J. Vence uns e volta.",
		Done = "Três duelos. Tá virando gente grande. ...Ontem à noite, daqui de cima, vi uma luz atrás da cachoeira. Não era o boss.",
		Objectives = {
			{ Kind = "duel_wins", Goal = 3, Desc = "Vença %d duelos" },
			{ Kind = "kills", Goal = 20, Desc = "Elimine %d jogadores" },
		},
		Reward = { EventPoints = 250, Coins = 300, XP = 350 },
	},
	{
		Id = "cap6", Title = "Caçada", NpcUserId = 1712538599, Spot = "MercadoNW",
		Intro = "O Big C.H.O.P. aparece de tempos em tempos — e à noite alguém pode invocar ele no altar. Participa de uma vitória contra o boss. Quero ver de perto quem está soltando esse bicho.",
		Progress = "O boss ainda tá de pé por aí? Vai lá.",
		Done = "Derrubou o monstro. O loot é por ranking de dano, sabia? ...Agora o que importa: vi quem estava no altar quando ele nasceu. Era o adryan. Com a flecha na mão. Fala com o RIP_ACE no santuário — ele tá juntando as peças.",
		Objectives = {
			{ Kind = "boss_kills", Goal = 1, Desc = "Participe de %d vitória contra o boss" },
			{ Kind = "kills", Goal = 25, Desc = "Elimine %d jogadores" },
		},
		Reward = { EventPoints = 300, Coins = 400, XP = 400 },
	},
	{
		Id = "cap7", Title = "O ritual", NpcUserId = 3352486957, Spot = "Santuario",
		Intro = "Você chegou longe. Eu também: o dinheiro do adryan, as pegadas, a luz atrás da cachoeira, a flecha... tudo aponta pra ele. Mas ele é forte — mais forte que o boss. Antes de enfrentar, prova que domina o combate: streak de 5, muitos parries, muitos corpos.",
		Progress = "Ainda falta. O final não espera qualquer um.",
		Done = "Você está pronto. Foi ele: a flecha, o altar, o monstro — e o favor que te pediu era pra ninguém ver o que ele carregava pela cachoeira. Vai lá. E toma cuidado: ele sabe que você sabe.",
		Objectives = {
			{ Kind = "streak", Goal = 5, Desc = "Faça um kill streak de %d", Max = true },
			{ Kind = "parries", Goal = 10, Desc = "Faça %d parries" },
			{ Kind = "kills", Goal = 30, Desc = "Elimine %d jogadores" },
		},
		Reward = { EventPoints = 400, Coins = 500, XP = 600, Emote = "flex" },
	},
	{
		Id = "final", Title = "O traidor", NpcUserId = 7521923542, DeliverNpcUserId = 3792294725, Spot = "Cachoeira",
		Intro = "...Então você chegou até aqui. Sim, fui eu: a flecha, o altar, o monstro — tudo. E aquele favor? Era pra ninguém ver o que eu carregava pela cachoeira. Você foi útil. Me encontra atrás da água, no santuário. Vamos ver se é tão bom quanto dizem.",
		Progress = "Ainda de pé? Estou te esperando no santuário. Atravessa a água.",
		Done = "...O adryan? Desde o começo? Nunca imaginei. Você salvou a equipe — e o Sahur. Obrigado, de verdade. Você zerou a história.",
		Objectives = { { Kind = "traitor_kill", Goal = 1, Desc = "Derrote o traidor no santuário" } },
		Reward = { EventPoints = 1000, Coins = 1000, XP = 1500 },
	},
} :: { Chapter }

function QuestConfig.Get(index: number): Chapter?
	return QuestConfig.Chapters[index]
end

return QuestConfig
