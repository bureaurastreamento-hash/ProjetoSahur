--!strict
--[[
	StoryConfig — campanha F/X orientada por dados.
	Cânone: LORE_FX_CANONE.md. Capítulo 1 = BIBLIA_CAMPANHA_CAP1_v0.1.md (missões numeradas em `Mission`).
	Estrutura (ESTRUTURA_JOGO.md): estes atos são a *Story Questline*; o mundo (farm, sidequests, PvP, eventos)
	existe entre eles e nunca é bloqueado pela história, só as rotas entre ilhas.

	O perfil guarda o ato pelo ÍNDICE (`profile.story.act`). Mudou a ordem/quantidade? Aumente `StoryConfig.Revision`
	e escreva a migração em StoryService.migrate.

	Campos do ato:
	  Objectives  — contadores (`Kind`) que o StoryService soma; todos completos = próximo ato.
	  Arrive      — região cuja chegada conclui o ato (sem objetivos).
	  UnlockFlag  — flag gravada ao concluir o ato (portais checam em WorldPortalService).
	  Guide       — fala do Humanoider_20 quando o player conversa com ele durante este ato.
	  Trace       — Rastro de Carlos ligado ao ato (texto em StoryConfig.Traces).
]]

local StoryConfig = {}

StoryConfig.Revision = 2

export type Chapter = {
	Id: string,
	Order: number,
	Elder: string,
	World: string,
	Inspiration: string,
	Title: string,
	Acts: { Act },
}
export type Objective = { Kind: string, Goal: number, Text: string }
export type Act = {
	Id: string,
	Title: string,
	Mission: string?,
	Region: string?,
	Objectives: { Objective },
	Arrive: string?,
	UnlockFlag: string?,
	Guide: string?,
	Trace: string?,
	Hint: string?,
}

-- Rastros de Carlos: o que o player vê ao investigar. Nunca revelar mais do que a bíblia permite no ponto.
StoryConfig.Traces = {
	carlos_era01 = {
		Title = "O objeto impossível",
		Text = "Uma peça metálica com um símbolo desconhecido. Humanoider_20: \"Isso não deveria estar aqui.\"",
	},
	carlos_eclipse01 = {
		Title = "O homem que não existe",
		Text = "Um registro anterior à F/X traz o mesmo símbolo da peça do Porto da Névoa. Como alguém esteve aqui antes de tudo quebrar?",
	},
} :: { [string]: { Title: string, Text: string } }

StoryConfig.Chapters = {
	{ Id = "cap1", Order = 1, Elder = "Humanoider_20", World = "Mundo das Eras", Inspiration = "JoJo", Title = "Primeira Fratura", Acts = {
		-- ILHA 1 — PORTO DA NÉVOA (Parte 1)
		{ Id = "chegada", Mission = "0–1", Region = "ilha_tutorial", Title = "Você não deveria estar inteiro", Objectives = {},
			Hint = "Alguém observa você no porto. Fale com Humanoider_20.",
			Guide = "Você caiu de uma ruptura ativa... e ainda parece você. Isso é novo. Vá ao campo de treino a oeste da vila: sobreviva a três Vagantes e aprenda a aparar um golpe." },
		{ Id = "primeiros_golpes", Mission = "3", Region = "ilha_tutorial", Title = "Prove que consegue sobreviver", Objectives = {
			{ Kind = "kills", Goal = 3, Text = "Derrote 3 Vagantes da Fratura" },
			{ Kind = "parries", Goal = 1, Text = "Apare 1 golpe (F na hora certa)" },
		}, Guide = "Você aprende melhor quando existe alguma possibilidade real de morrer. Campo de treino, a oeste." },
		{ Id = "rastro_carlos_01", Mission = "5", Region = "ilha_tutorial", Title = "O objeto impossível", Objectives = {
			{ Kind = "trace_carlos_era01", Goal = 1, Text = "Investigue o brilho nas ruínas ao norte" },
		}, Trace = "carlos_era01", Guide = "Tem uma energia estranha nas ruínas ao norte. Vá ver o que é. Com cuidado." },
		{ Id = "herdeiro_da_nevoa", Mission = "Final da Ilha 1", Region = "ilha_tutorial", Title = "O Herdeiro da Névoa", Objectives = {
			{ Kind = "fx_cap1_boss", Goal = 1, Text = "Derrote o Herdeiro da Névoa nas ruínas" },
		}, UnlockFlag = "ilha_pilares_unlocked",
			Guide = "Aquela peça... é de alguém que morreu. Esqueça isso por agora. Quem está usando a energia da máscara nas ruínas sabe que existem outros mundos. Pare ele." },
		-- ILHA 2 — DESERTO DO SOL (Parte 2)
		{ Id = "calor", Mission = "6", Region = "ilha_pilares", Title = "Calor", Objectives = {}, Arrive = "ilha_pilares",
			Hint = "Atravesse o portal a nordeste do Porto da Névoa até o Deserto do Sol.",
			Guide = "Acho que descobrimos para onde a nossa história foi parar. Há uma ruptura ativa num deserto de outra época. Portal a nordeste." },
		{ Id = "homens_de_pedra", Mission = "7", Region = "ilha_pilares", Title = "Os Homens de Pedra", Objectives = {
			{ Kind = "fx_pedra_enemy", Goal = 4, Text = "Derrote 4 Homens de Pedra na escavação (leste)" },
		}, Guide = "A escavação a leste acordou coisas que deviam dormir por mais alguns séculos. A F/X adiantou o relógio delas." },
		{ Id = "respira", Mission = "8", Region = "ilha_pilares", Title = "Respira", Objectives = {
			{ Kind = "fx_mestre", Goal = 1, Text = "Fale com o Mestre da Respiração (praça de chegada)" },
			{ Kind = "parries", Goal = 2, Text = "Apare 2 golpes" },
		}, Guide = "Tem um mestre perto da praça de chegada. Técnica deste mundo. Aprenda: nenhum sistema de poder é exclusivo de ninguém." },
		{ Id = "a_camara", Mission = "9", Region = "ilha_pilares", Title = "A Câmara", Objectives = {
			{ Kind = "fx_camara", Goal = 1, Text = "Encontre o símbolo dentro do santuário (atrás da cachoeira)" },
		}, Guide = "O santuário atrás da cachoeira é mais antigo que tudo nesta ilha. Procure o que brilha lá dentro." },
		{ Id = "sol_negro", Mission = "10", Region = "ilha_pilares", Title = "Sol Negro", Objectives = {
			{ Kind = "fx_solnegro_boss", Goal = 1, Text = "Derrote o Sacerdote do Sol Negro na Câmara" },
		}, UnlockFlag = "ilha_sol_partido_unlocked",
			Guide = "Esse símbolo parece a peça do Porto... mas não é igual. Alguém estudou isto antes de nós. Agora foco: o Sacerdote quer usar a F/X para acordar o que dorme na Câmara." },
		-- ILHA 3 — ROTA DO ECLIPSE (Parte 3)
		{ Id = "rota_do_eclipse", Mission = "11", Region = "ilha_sol_partido", Title = "Manifestação", Objectives = {}, Arrive = "ilha_sol_partido",
			Hint = "No Deserto do Sol, o portal da praça de chegada leva à Rota do Eclipse.",
			Guide = "A próxima ruptura é uma rota inteira: portos, desertos, cidades. Aqui as manifestações espirituais são comuns. Vá pela praça de chegada." },
		{ Id = "cacados", Mission = "12", Region = "ilha_sol_partido", Title = "Caçados", Objectives = {
			{ Kind = "fx_sol_enemy", Goal = 5, Text = "Derrote 5 Caçadores de Recompensa" },
			{ Kind = "parries", Goal = 2, Text = "Apare 2 golpes" },
		}, Guide = "Alguém pôs um preço na sua cabeça. E quem contratou sabe que você atravessa rupturas. Isso é específico demais." },
		{ Id = "homem_que_nao_existe", Mission = "14", Region = "ilha_sol_partido", Title = "O homem que não existe", Objectives = {
			{ Kind = "trace_carlos_eclipse01", Goal = 1, Text = "Leia o registro antigo no altar do templo" },
		}, Trace = "carlos_eclipse01", Guide = "O templo ao norte guarda registros antigos. Muito antigos." },
		{ Id = "eclipse", Mission = "15", Region = "ilha_sol_partido", Title = "Eclipse", Objectives = {
			{ Kind = "fx_sol_boss", Goal = 1, Text = "Derrote O Observador no topo do templo" },
		}, UnlockFlag = "cidade_ambar_unlocked",
			Guide = "O Observador não quer poder. Quer saber quem está ligando os mundos. Isso o torna mais perigoso." },
		{ Id = "rumo_cidade_ambar", Mission = "16+", Title = "Rumo à Cidade Âmbar", Objectives = {},
			Hint = "A Cidade Âmbar (Ilha 4) ainda está sendo estabilizada.",
			Guide = "\"Você acredita que as rachaduras começaram recentemente?\" ... Não gosto de como ele disse isso. Descanse. A próxima ilha ainda não está estável." },
	} },
	{ Id = "cap2", Order = 2, Elder = "Adryan", World = "Mundo do Domínio", Inspiration = "Overlord", Title = "O Benfeitor", Acts = {} },
	{ Id = "cap3", Order = 3, Elder = "ToduroDemais", World = "Mundo da Megacidade", Inspiration = "Cyberpunk: Edgerunners", Title = "Treino de Sobrevivência", Acts = {} },
	{ Id = "cap4", Order = 4, Elder = "Lry", World = "Mundo Espiritual", Inspiration = "Bleach", Title = "Entre Camadas", Acts = {} },
	{ Id = "cap5", Order = 5, Elder = "Approx", World = "Mundo das Muralhas", Inspiration = "Attack on Titan", Title = "Além das Muralhas", Acts = {} },
	{ Id = "cap6", Order = 6, Elder = "Fred", World = "Mundo das Maldições", Inspiration = "Jujutsu Kaisen", Title = "O Falso Culpado", Acts = {} },
	{ Id = "cap7", Order = 7, Elder = "Ravy", World = "Universo de Origem", Inspiration = "F/X", Title = "Ponto Zero", Acts = {} },
} :: { Chapter }

local byId: { [string]: Chapter } = {}
for _, chapter in StoryConfig.Chapters do
	byId[chapter.Id] = chapter
end

function StoryConfig.Get(id: string): Chapter?
	return byId[id]
end

function StoryConfig.Next(id: string): Chapter?
	local chapter = byId[id]
	return if chapter then StoryConfig.Chapters[chapter.Order + 1] else nil
end

return StoryConfig
