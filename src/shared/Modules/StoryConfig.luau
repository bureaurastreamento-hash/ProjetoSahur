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
	  Reward      — itens entregues ao CONCLUIR o ato ({ [itemId] = n }, StandService.Give; ex.: a Flecha).
	  MinLevel    — nível mínimo para o objetivo contar (abaixo: dica de onde treinar; o ato destrava ao subir).
	  XP/Coins    — pagos ao concluir o ato (toda missão dá algo na hora).
	  Key         — o Ancião aparece (diálogo com foto) só nos atos-chave; o resto chega como aviso discreto.
	  Intro/IntroNpc — fala automática ao ENTRAR no ato (padrão: Guide do Humanoider). IntroNpc "???" = sem foto.
	  GuideNpc    — quem fala o Guide (padrão Humanoider_20).
	  Choice      — ECO (BIBLIA_CAMPANHA_CAP1 "Ecos"): escolha na tela ao entrar no ato; escolher conclui o ato e grava
	                as flags da opção. Opção com RequiresFlag só aparece liberada se o jogador explorou antes.
	Objetivo "reach_<lugar>": chegar perto de StoryConfig.Places[<lugar>] (StoryService confere a posição).
]]

local StoryConfig = {}

StoryConfig.Revision = 7 -- Fortaleza Maré adicionada após os 39 atos existentes

export type Chapter = {
	Id: string,
	Order: number,
	Elder: string,
	World: string,
	Inspiration: string,
	Title: string,
	Acts: { Act },
}
export type Objective = { Kind: string, Goal: number, Text: string, WhenFlag: string? }
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
	Reward: { [string]: number }?,
	MinLevel: number?, -- nível mínimo para o ato contar (antes disso: dica de treino; dono 30/09 "prender")
	XP: number?, -- XP ao concluir o ato
	Coins: number?, -- moedas ao concluir o ato
	Key: boolean?, -- momento-chave: o Ancião fala em diálogo; nos outros atos a missão chega como aviso discreto
	Intro: string?,
	IntroNpc: string?,
	GuideNpc: string?,
	Choice: Choice?,
}
export type ChoiceOption = { Id: string, Label: string, Desc: string, Flags: { string }, Say: string, RequiresFlag: string?, RetryObjective: string? }
export type Choice = { Id: string, Title: string, Text: string, Options: { ChoiceOption } }

-- Lugares dos objetivos "reach_<id>" (alturas conferidas no place).
StoryConfig.Places = {
	taberna = { Position = Vector3.new(352, 0, 62), Radius = 34 },
	fenda = { Position = Vector3.new(-115, 0, -20), Radius = 16 },
} :: { [string]: { Position: Vector3, Radius: number } }

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
		{ Id = "acorde", XP = 30, Mission = "0", Region = "ilha_tutorial", Title = "Acorde", Objectives = {
			{ Kind = "fx_m0_destrocos", Goal = 1, Text = "Examine os destroços na praia" },
			{ Kind = "fx_m0_pertence", Goal = 1, Text = "Recupere o que é seu" },
			{ Kind = "fx_m0_estrutura", Goal = 1, Text = "Toque a estrutura enterrada" },
		}, Guide = "(Ele observa você em silêncio. Talvez seja melhor olhar a praia primeiro.)", GuideNpc = "???" },
		{ Id = "chegada", Key = true, Mission = "1", Region = "ilha_tutorial", Title = "Você não deveria estar inteiro", Objectives = {},
			Intro = "Interessante.", IntroNpc = "???",
			Hint = "A voz veio da vila, ao norte do porto. Fale com quem estava olhando.",
			Guide = "Você caiu de uma ruptura ativa... e ainda parece você. (Ele passa um aparelho em você. Falha. Tenta de novo. Falha.) Isso é novo. Me chamo Humanoider. Venha, você precisa ver onde está." },
		{ Id = "porto_da_nevoa", XP = 40, Coins = 10, Key = true, Mission = "2", Region = "ilha_tutorial", Title = "Porto da Névoa", Objectives = {
			{ Kind = "reach_taberna", Goal = 1, Text = "Conheça a Taberna (leste da vila): contratos e gente" },
		}, Choice = { Id = "rota_inicial", Title = "SEU PRIMEIRO CAMINHO", Text = "Escolha como começar. Você poderá aprender outros caminhos depois.", Options = {
			{ Id = "tecnica", Label = "Técnica", Desc = "Combate próximo e resistência. Recebe a Flecha no fim da ilha.", Flags = {}, Say = "Comece pelo corpo. A técnica pode acompanhar qualquer manifestação depois." },
			{ Id = "manifestacao", Label = "Manifestação", Desc = "Recebe uma Flecha agora. Use na mochila (M) para sortear seu Stand.", Flags = {}, Say = "Tome esta Flecha. Ela desperta o que já existe em você; ninguém escolhe o que sai." },
			{ Id = "arma", Label = "Arma", Desc = "Espada de treino na hotbar. Recebe a Flecha no fim da ilha.", Flags = {}, Say = "Uma arma é um começo. Não é o limite do que você pode aprender." },
		} }, Guide = "Isto é o Porto da Névoa. Comerciantes, curandeiro, porto, e a Taberna a leste com o quadro de contratos. Uma coisa chamada F/X está fazendo as realidades se misturarem. É só o que você precisa saber por enquanto." },
		{ Id = "primeiros_golpes", XP = 60, Coins = 10, Mission = "3", Region = "ilha_tutorial", Title = "Prove que consegue sobreviver", Objectives = {
			{ Kind = "fx_tutorial_enemy", Goal = 3, Text = "Derrote 3 Vagantes da Fratura (campo de treino, oeste)" },
			{ Kind = "parries", Goal = 1, Text = "Apare 1 golpe (F na hora certa)" },
		}, Guide = "Você aprende melhor quando existe alguma possibilidade real de morrer. Campo de treino, a oeste da vila." },
		{ Id = "fenda_instavel", XP = 40, Mission = "3", Region = "ilha_tutorial", Title = "A zona instável", Objectives = {
			{ Kind = "reach_fenda", Goal = 1, Text = "Entre na fenda instável a oeste do treino" },
		}, Guide = "Tem uma zona instável a oeste do campo de treino. Os outros precisam de proteção para entrar lá. Quero ver o que acontece com você." },
		{ Id = "eco_sobreviventes", Mission = "3 · Eco", Region = "ilha_tutorial", Title = "A fenda está fechando", Objectives = {},
			Hint = "Escolha o que fazer com os sobreviventes.",
			Choice = { Id = "eco_m3", Title = "A FENDA ESTÁ FECHANDO",
				Text = "Dois sobreviventes lá dentro. Um está muito ferido; o outro ainda consegue andar. Não dá tempo de pensar muito.",
				Options = {
					{ Id = "carregar", Label = "Carregar o ferido", Desc = "Mais lento, mais arriscado. Os dois saem.", Flags = { "eco_m3_carregou" },
						Say = "Você carregou alguém que nem conhecia por uma fenda fechando. Anotado." },
					{ Id = "andar", Label = "Levar só quem anda", Desc = "Seguro. O ferido fica para trás.", Flags = { "eco_m3_deixou" },
						Say = "Um saiu. O outro... a fenda levou. Às vezes é isso." },
					{ Id = "saida", Label = "Usar a passagem estreita", Desc = "Só se você achou outra saída lá dentro.", Flags = { "eco_m3_saida" },
						RequiresFlag = "fenda_saida", Say = "Outra saída? Ninguém tinha visto aquilo. Os dois vivos, sem carregar ninguém." },
				} } },
		{ Id = "a_mascara", MinLevel = 5, XP = 120, Coins = 20, Key = true, Mission = "4", Region = "ilha_tutorial", Title = "A Máscara", Objectives = {
			{ Kind = "fx_mascara_boss", Goal = 1, Text = "Derrote o Portador da Máscara (colinas a leste)" },
		}, Guide = "Gente anda sumindo nas colinas a leste. Um grupo está usando um artefato antigo por lá, e ele reage à F/X de um jeito que não devia." },
		{ Id = "rastro_carlos_01", XP = 60, Coins = 10, Mission = "5", Region = "ilha_tutorial", Title = "O objeto impossível", Objectives = {
			{ Kind = "trace_carlos_era01", Goal = 1, Text = "Investigue o brilho nas ruínas ao norte" },
		}, Trace = "carlos_era01", Guide = "A máscara pertence a esta realidade. Mas aquela energia não. Tem outro brilho nas ruínas ao norte. Vá ver." },
		{ Id = "herdeiro_da_nevoa", MinLevel = 8, XP = 200, Coins = 40, Key = true, Mission = "Final da Ilha 1", Region = "ilha_tutorial", Title = "O Herdeiro da Névoa", Objectives = {
			{ Kind = "fx_cap1_boss", Goal = 1, Text = "Derrote o Herdeiro da Névoa nas ruínas" },
		}, Guide = "Aquela peça... é de alguém que morreu. Esqueça isso por agora. Quem está usando a energia da máscara nas ruínas sabe que existem outros mundos. Pare ele." },
		{ Id = "eco_capela", Mission = "Escolha da Ilha 1", Region = "ilha_tutorial", Title = "A capela está desabando", Objectives = {},
			UnlockFlag = "ilha_pilares_unlocked", -- Flecha condicional por rota em StoryService
			Hint = "Escolha o que salvar na capela.",
			Choice = { Id = "eco_ilha1", Title = "A CAPELA ESTÁ DESABANDO",
				Text = "O Herdeiro caiu, mas a capela vem abaixo. De um lado, prisioneiros acorrentados. Do outro, o arquivo dos experimentos dele. Não dá para garantir os dois.",
				Options = {
					{ Id = "prisioneiros", Label = "Salvar os prisioneiros", Desc = "Mais gente sai viva. Parte dos dados se perde.", Flags = { "eco_ilha1_prisioneiros" },
						Say = "Mais gente viva. Perdemos parte dos papéis. Eu teria escolhido igual... acho." },
					{ Id = "arquivos", Label = "Recuperar os arquivos", Desc = "Mais informação sobre a F/X. Nem todos saem.", Flags = { "eco_ilha1_arquivos" },
						Say = "Com isso eu entendo melhor a F/X. Nem todo mundo saiu. Vou lembrar disso." },
					{ Id = "passagem", Label = "Usar a passagem pela rachadura", Desc = "Só se você achou a passagem antes.", Flags = { "eco_ilha1_prisioneiros", "eco_ilha1_arquivos", "eco_ilha1_passagem" },
						RequiresFlag = "passagem_capela", Say = "Você já conhecia a passagem. Todo mundo saiu, e ainda trouxe parte dos arquivos." },
				} } },
		-- ILHA 2 — DESERTO DO SOL (Parte 2)
		{ Id = "calor", Key = true, Mission = "6", Region = "ilha_pilares", Title = "Calor", Objectives = {}, Arrive = "ilha_pilares",
			Hint = "Atravesse o portal a nordeste do Porto da Névoa até o Deserto do Sol.",
			Guide = "Você sobreviveu. Sua rota não limita o que pode aprender. A mochila (M) guarda suas Flechas. Há uma ruptura ativa num deserto de outra época. Portal a nordeste." },
		{ Id = "homens_de_pedra", MinLevel = 9, XP = 150, Coins = 20, Mission = "7", Region = "ilha_pilares", Title = "Os Homens de Pedra", Objectives = {
			{ Kind = "fx_pedra_enemy", Goal = 4, Text = "Derrote 4 Homens de Pedra na escavação (leste)" },
		}, Guide = "A escavação a leste acordou coisas que deviam dormir por mais alguns séculos. A F/X adiantou o relógio delas." },
		{ Id = "respira", XP = 150, Coins = 20, Mission = "8", Region = "ilha_pilares", Title = "Respira", Objectives = {
			{ Kind = "fx_mestre", Goal = 1, Text = "Fale com o Mestre da Respiração (praça de chegada)" },
			{ Kind = "parries", Goal = 2, Text = "Apare 2 golpes" },
		}, Choice = { Id = "tecnica_m8", Title = "RESPIRA", Text = "Você pode aprender Técnica corporal ou continuar com sua build. Quem começou pela Técnica recebe sua evolução.", Options = {
			{ Id = "aprender", Label = "Aprender Técnica", Desc = "Técnica básica ou evolução da rota Técnica; maestria preservada.", Flags = { "tecnica_m8_aprendeu" }, Say = "Respire com o golpe, não contra ele.", },
			{ Id = "recusar", Label = "Continuar com minha build", Desc = "A campanha continua. Você pode voltar ao mestre para aprender depois.", Flags = { "tecnica_m8_recusou" }, Say = "O corpo lembra o que a cabeça esquece. Volte quando quiser treinar.", },
		} }, Guide = "Tem um mestre perto da praça de chegada. Técnica deste mundo. Aprenda: nenhum sistema de poder é exclusivo de ninguém." },
		{ Id = "a_camara", MinLevel = 12, XP = 200, Coins = 25, Mission = "9", Region = "ilha_pilares", Title = "A Câmara", Objectives = {
			{ Kind = "fx_camara", Goal = 1, Text = "Encontre o símbolo dentro do santuário (atrás da cachoeira)" },
		}, Guide = "O santuário atrás da cachoeira é mais antigo que tudo nesta ilha. Procure o que brilha lá dentro." },
		{ Id = "sol_negro", MinLevel = 14, XP = 320, Coins = 50, Key = true, Mission = "10", Region = "ilha_pilares", Title = "Sol Negro", Objectives = {
			{ Kind = "fx_solnegro_boss", Goal = 1, Text = "Derrote o Sacerdote do Sol Negro na Câmara" },
		},
			Guide = "Esse símbolo parece a peça do Porto... mas não é igual. Alguém estudou isto antes de nós. Agora foco: o Sacerdote quer usar a F/X para acordar o que dorme na Câmara." },
		{ Id = "eco_deserto", Mission = "Escolha da Ilha 2", Region = "ilha_pilares", Title = "A entidade desperta", Objectives = {},
			UnlockFlag = "ilha_sol_partido_unlocked", Hint = "Escolha como impedir o despertar na Câmara.",
			Choice = { Id = "eco_ilha2", Title = "A ENTIDADE DESPERTA", Text = "O Sacerdote caiu, mas a entidade antiga está despertando. A ameaça precisa ser resolvida.", Options = {
				{ Id = "selar", Label = "Selar novamente", Desc = "Impede o despertar e mantém a região relativamente intacta.", Flags = { "eco_ilha2_selou" }, Say = "A entidade foi selada novamente. A Câmara continua de pé." },
				{ Id = "destruir", Label = "Destruir a Câmara", Desc = "Impede o despertar definitivamente. Ruínas importantes se perdem.", Flags = { "eco_ilha2_destruiu" }, Say = "O despertar foi impedido. Parte importante destas ruínas foi perdida." },
				{ Id = "transferir", Label = "Transferir a energia", Desc = "Preserva parte das ruínas, mas deixa uma anomalia menor permanente.", Flags = { "eco_ilha2_transferiu" }, RequiresFlag = "camara_transferencia_preparada", Say = "A energia foi transferida. A entidade não despertará, mas uma anomalia menor permanece." },
			} } },
		-- ILHA 3 — ROTA DO ECLIPSE (Parte 3)
		{ Id = "rota_do_eclipse", Key = true, Mission = "11", Region = "ilha_sol_partido", Title = "Manifestação", Objectives = {}, Arrive = "ilha_sol_partido",
			Hint = "No Deserto do Sol, o portal da praça de chegada leva à Rota do Eclipse.",
			Guide = "A próxima ruptura é uma rota inteira: portos, desertos, cidades. Aqui as manifestações espirituais são comuns. Vá pela praça de chegada." },
		{ Id = "cacados", MinLevel = 15, XP = 220, Coins = 25, Mission = "12", Region = "ilha_sol_partido", Title = "Caçados", Objectives = {
			{ Kind = "fx_sol_enemy", Goal = 5, Text = "Derrote 5 Caçadores de Recompensa" },
			{ Kind = "parries", Goal = 2, Text = "Apare 2 golpes" },
		}, Guide = "Alguém pôs um preço na sua cabeça. E quem contratou sabe que você atravessa rupturas. Isso é específico demais." },
		{ Id = "o_viajante", XP = 220, Coins = 25, Mission = "13", Region = "ilha_sol_partido", Title = "O Viajante", Objectives = {
			{ Kind = "fx_viajante", Goal = 1, Text = "Converse com O Viajante perto da chegada da Rota do Eclipse" },
		}, Guide = "Uma pessoa apareceu perto da chegada. Não veio de barco. Fale com ela.",
			Hint = "O Viajante está perto do portal de chegada." },
		{ Id = "homem_que_nao_existe", MinLevel = 18, XP = 260, Coins = 30, Mission = "14", Region = "ilha_sol_partido", Title = "O homem que não existe", Objectives = {
			{ Kind = "trace_carlos_eclipse01", Goal = 1, Text = "Leia o registro antigo no altar do templo" },
		}, Trace = "carlos_eclipse01", Guide = "O templo ao norte guarda registros antigos. Muito antigos." },
		{ Id = "eclipse", MinLevel = 20, XP = 450, Coins = 60, Key = true, Mission = "15", Region = "ilha_sol_partido", Title = "Eclipse", Objectives = {
			{ Kind = "fx_sol_boss", Goal = 1, Text = "Derrote O Observador no topo do templo" },
		}, UnlockFlag = "cidade_ambar_unlocked",
			Guide = "O Observador não quer poder. Quer saber quem está ligando os mundos. Isso o torna mais perigoso." },
		{ Id = "rumo_cidade_ambar", Key = true, Mission = "16 · chegada", Region = "cidade_ambar", Title = "Rumo à Cidade Âmbar", Objectives = {}, Arrive = "cidade_ambar",
			Hint = "A rota só abre quando a Cidade Âmbar tiver mapa e chegada seguros.",
			Guide = "\"Você acredita que as rachaduras começaram recentemente?\" ... Não gosto de como ele disse isso. Nossa próxima parada é a Cidade Âmbar." },
		-- ILHA 4 — CIDADE ÂMBAR. Marcadores reais ligados por CidadeAmbarService; sem criar/mover arte.
		{ Id = "uma_cidade_normal", Mission = "16", Region = "cidade_ambar", Title = "Uma Cidade Normal", Objectives = {
			{ Kind = "fx_ambar_morador", Goal = 2, Text = "Conheça dois moradores diferentes" },
			{ Kind = "fx_ambar_tarefa", Goal = 1, Text = "Ajude com uma tarefa simples na cidade" },
		}, Guide = "Uma região estável. Por alguns minutos, talvez possamos relaxar. Conheça os moradores e ajude por aqui." },
		{ Id = "desaparecidos", Mission = "17", Region = "cidade_ambar", Title = "Desaparecidos", Objectives = {
			{ Kind = "fx_ambar_desaparecimento", Goal = 2, Text = "Investigue dois locais de desaparecimento" },
		}, Guide = "Pessoas estão desaparecendo. E a cidade continua como se algumas delas nunca tivessem existido. Procure sinais nos locais." },
		{ Id = "fotografia", Mission = "18", Region = "cidade_ambar", Title = "Fotografia", Objectives = {
			{ Kind = "fx_ambar_foto", Goal = 1, Text = "Examine a fotografia antiga" },
			{ Kind = "fx_ambar_confrontar", Goal = 1, Text = "Leve a fotografia ao Humanoider e confronte-o" },
		}, Guide = "Encontrou uma fotografia? Traga para mim.", Hint = "O rosto danificado não permite identificar a pessoa." },
		{ Id = "assassino_invisivel", Mission = "19", Region = "cidade_ambar", Title = "O Assassino Invisível", Objectives = {
			{ Kind = "fx_ambar_cena", Goal = 2, Text = "Analise duas cenas diferentes" },
			{ Kind = "fx_ambar_depoimento", Goal = 1, Text = "Converse com uma testemunha" },
			{ Kind = "fx_ambar_padrao", Goal = 1, Text = "Conecte as pistas e encontre o padrão" },
			{ Kind = "fx_ambar_contrapista", Goal = 1, Text = "Reinvestigue a pista após a acusação incorreta", WhenFlag = "ambar_suspeito_incorreto" },
		}, Guide = "Alguém usa anomalias para esconder crimes. Analise as cenas, converse e conecte as pistas antes de escolher um suspeito.",
			Choice = { Id = "ambar_suspeito", Title = "O PADRÃO", Text = "Quem corresponde às pistas que você reuniu?", Options = {
				{ Id = "sem_vinculo", Label = "Pessoa sem vínculo com as cenas", Desc = "Acusar sem ligação comprovada exige reinvestigar.", Flags = { "ambar_suspeito_incorreto" }, RetryObjective = "fx_ambar_contrapista", Say = "A acusação não se sustenta. Perdemos tempo: volte à pista e confira o vínculo com os locais. A investigação continua." },
				{ Id = "ligado_cenas", Label = "Pessoa ligada às cenas", Desc = "Seguir o vínculo identificado no padrão.", Flags = { "ambar_suspeito_identificado" }, Say = "O padrão aponta para a casa. Vamos conferir antes de acusar." },
			} } },
		{ Id = "casa_vazia", Mission = "20", Region = "cidade_ambar", Title = "Casa Vazia", Objectives = {
			{ Kind = "fx_ambar_casa", Goal = 1, Text = "Investigue a pequena ruptura na casa vazia" },
		}, Guide = "A casa parece vazia. Examine o que restou lá dentro." },
		{ Id = "homem_sem_sombra", MinLevel = 24, XP = 600, Coins = 80, Key = true, Mission = "Boss da Ilha 4", Region = "cidade_ambar", Title = "O Homem Sem Sombra", Objectives = {
			{ Kind = "fx_ambar_boss", Goal = 1, Text = "Derrote O Homem Sem Sombra" },
		}, Guide = "Uma ruptura controlada. Parece artificial... alguém aprendeu a reproduzir os fenômenos da F/X. Ou já sabia antes. Pare quem está usando isso." },
		{ Id = "eco_cidade", Mission = "Escolha da Ilha 4", Region = "cidade_ambar", Title = "Justiça e informação", Objectives = {}, UnlockFlag = "costa_dourada_unlocked",
			Choice = { Id = "eco_ilha4", Title = "JUSTIÇA E INFORMAÇÃO", Text = "O Homem Sem Sombra caiu. Disse ter recebido o método de \"um homem que conhecia as linhas\". Os cidadãos querem justiça imediata. Como obter as informações?", Options = {
				{ Id = "autoridades", Label = "Entregar às autoridades", Desc = "A informação chega ao grupo pelas autoridades locais.", Flags = { "eco_ilha4_autoridades", "ambar_metodo_linhas" }, Say = "As autoridades receberam o criminoso. O relato encaminhado ao grupo confirma: o método veio de um homem que conhecia as linhas. Nenhum nome." },
				{ Id = "humanoider", Label = "Humanoider interroga", Desc = "O Ancião obtém o relato para o grupo.", Flags = { "eco_ilha4_humanoider", "ambar_metodo_linhas" }, Say = "O interrogatório confirma o relato: um homem que conhecia as linhas lhe passou o método. Ele não deu nenhum nome." },
				{ Id = "pessoal", Label = "Interrogar pessoalmente", Desc = "Você obtém o relato e compartilha com o grupo.", Flags = { "eco_ilha4_pessoal", "ambar_metodo_linhas" }, Say = "Você obteve e compartilhou o relato. O método veio de um homem que conhecia as linhas. Nenhum nome foi revelado." },
			} } },
		{ Id = "rumo_costa_dourada", Key = true, Mission = "21 · chegada", Region = "costa_dourada", Title = "Rumo à Costa Dourada", Objectives = {}, Arrive = "costa_dourada",
			Hint = "A rota aguarda mapa e chegada seguros da Costa Dourada.", Guide = "A informação chegou ao grupo. Nossa próxima rota é a Costa Dourada, quando estiver estável." },
		{ Id = "contrabando", Mission = "21", Region = "costa_dourada", Title = "Contrabando", Objectives = {
			{ Kind = "fx_costa_mercado", Goal = 2, Text = "Examine dois lotes de objetos de outras realidades" },
		}, Guide = "Um mercado negro vende armas, fragmentos e objetos impossíveis. Alguns lembram as ilhas anteriores; outros, lugares que nunca vimos." },
		{ Id = "a_organizacao", Mission = "22", Region = "costa_dourada", Title = "A Organização", Objectives = {
			{ Kind = "fx_costa_organizacao", Goal = 1, Text = "Investigue os registros do tráfico interdimensional" },
		}, Guide = "Uma facção domina o tráfico. Não criou a F/X: está explorando o fenômeno. Precisamos descobrir quem fornece os objetos." },
		{ Id = "infiltracao", Mission = "23 · escolha", Region = "costa_dourada", Title = "Infiltração", Objectives = {},
			Choice = { Id = "costa_infiltracao", Title = "INFILTRAÇÃO", Text = "Escolha como obter acesso. Todos os caminhos levam ao fornecedor; moradores reconhecerão seu estilo.", Options = {
				{ Id = "forca", Label = "Força", Desc = "Derrotar três guardas e atravessar o acesso principal.", Flags = { "costa_infiltracao_forca" }, Say = "Você escolheu entrar pela força. Abra caminho e atravesse o acesso principal." },
				{ Id = "furtividade", Label = "Furtividade", Desc = "Usar duas passagens em sequência, sem exigir combate.", Flags = { "costa_infiltracao_furtividade" }, Say = "Use a passagem lateral e depois a passagem interna. O acesso principal será desnecessário." },
				{ Id = "social", Label = "Acesso social", Desc = "Ajudar o contato antes libera esta alternativa.", Flags = { "costa_infiltracao_social" }, RequiresFlag = "costa_acesso_social", Say = "Seu contato abriu o acesso social. Apresente-se na entrada autorizada." },
			} } },
		{ Id = "infiltracao_acesso", Mission = "23", Region = "costa_dourada", Title = "Entrar na organização", Objectives = {
			{ Kind = "fx_costa_guard", Goal = 3, Text = "Derrote três guardas", WhenFlag = "costa_infiltracao_forca" },
			{ Kind = "fx_costa_furtivo", Goal = 2, Text = "Atravesse as duas passagens em sequência", WhenFlag = "costa_infiltracao_furtividade" },
			{ Kind = "fx_costa_acesso", Goal = 1, Text = "Entre pelo acesso correspondente ao seu caminho" },
		}, Guide = "Siga o caminho que escolheu. Há força, passagens laterais e acesso por contato." },
		{ Id = "o_fornecedor", Mission = "24", Region = "costa_dourada", Title = "O Fornecedor", Objectives = {
			{ Kind = "fx_costa_registro", Goal = 2, Text = "Compare dois registros dos horários das rupturas" },
		}, Guide = "Os objetos chegam por rupturas em horários específicos. Compare os registros: parece haver um padrão. Talvez algumas rupturas sejam coordenadas." },
		{ Id = "carregamento_c8", Mission = "25", Region = "costa_dourada", Title = "Carregamento C-8", Objectives = {
			{ Kind = "fx_costa_c8", Goal = 1, Text = "Examine o carregamento marcado C-8" },
			{ Kind = "fx_costa_c8_relato", Goal = 1, Text = "Mostre a identificação ao Humanoider" },
		}, Guide = "Há um carregamento com uma identificação antiga. Traga o registro para mim." },
		{ Id = "regente_dourado", MinLevel = 28, XP = 700, Coins = 90, Key = true, Mission = "Boss da Ilha 5", Region = "costa_dourada", Title = "Regente Dourado", Objectives = {
			{ Kind = "fx_costa_boss", Goal = 1, Text = "Derrote o chefe da organização" },
		}, Guide = "O Regente Dourado reuniu artefatos de outras realidades. Não deixe que continue usando o tráfico para acumular poder." },
		{ Id = "eco_costa", Mission = "Escolha da Ilha 5", Region = "costa_dourada", Title = "O futuro do mercado", Objectives = {}, UnlockFlag = "fortaleza_mare_unlocked",
			Choice = { Id = "eco_ilha5", Title = "O FUTURO DO MERCADO", Text = "O Regente caiu. O que fazer com o mercado negro?", Options = {
				{ Id = "destruir", Label = "Destruir o mercado", Desc = "Encerra a atividade do mercado para sua história.", Flags = { "eco_ilha5_destruiu" }, Say = "O mercado negro foi encerrado. Seguiremos para a fortaleza quando a rota estiver segura." },
				{ Id = "faccao", Label = "Facção menos agressiva", Desc = "Entrega o controle a uma facção menos agressiva.", Flags = { "eco_ilha5_faccao" }, Say = "O controle foi entregue a uma facção menos agressiva. Isso não muda o que descobrimos." },
				{ Id = "monitorar", Label = "Monitoramento de Humanoider", Desc = "Mantém o sistema para observar sua atividade.", Flags = { "eco_ilha5_monitorou" }, Say = "O sistema permanece sob meu monitoramento. Precisamos acompanhar a origem destes objetos." },
			} } },
		{ Id = "rumo_fortaleza_mare", Key = true, Mission = "26 · chegada", Region = "fortaleza_mare", Title = "Rumo à Fortaleza Maré", Objectives = {}, Arrive = "fortaleza_mare",
			Hint = "A rota aguarda mapa e chegada seguros da Fortaleza Maré.", Guide = "A prisão foi construída sobre uma zona extremamente instável. Quando a rota estiver segura, seguimos." },
		{ Id = "prisioneiro", Mission = "26", Region = "fortaleza_mare", Title = "Prisioneiro", Objectives = {
			{ Kind = "fx_mare_prisao", Goal = 1, Text = "Entre na fortaleza e examine a situação dos prisioneiros" },
		}, Guide = "Há gente presa por desenvolver habilidades após a F/X. Algumas são perigosas; outras foram apenas classificadas assim." },
		{ Id = "escolha_quem_sai", Mission = "27 · Eco", Region = "fortaleza_mare", Title = "Escolha quem sai", Objectives = {},
			Choice = { Id = "eco_m27", Title = "ESCOLHA QUEM SAI", Text = "Uma falha de segurança abriu uma oportunidade. Falta energia para as duas alas ao mesmo tempo; qual abrir primeiro?", Options = {
				{ Id = "civil", Label = "Ala civil primeiro", Desc = "Libera primeiro pessoas detidas injustamente. A ala de alto risco fica para depois.", Flags = { "eco_m27_civil" }, Say = "A energia vai primeiro para a ala civil. Ainda poderemos abrir a outra depois, com consequências pela demora." },
				{ Id = "risco", Label = "Ala de alto risco primeiro", Desc = "Há indivíduos perigosos e alguém com informação crítica. A ala civil espera.", Flags = { "eco_m27_risco" }, Say = "A energia vai primeiro para a ala de alto risco. A ala civil ainda poderá ser aberta depois, com consequências pela demora." },
			} } },
		{ Id = "abrir_ala_inicial", Mission = "27", Region = "fortaleza_mare", Title = "Abrir a primeira ala", Objectives = {
			{ Kind = "fx_mare_ala_civil", Goal = 1, Text = "Acione a abertura da ala civil", WhenFlag = "eco_m27_civil" },
			{ Kind = "fx_mare_ala_risco", Goal = 1, Text = "Acione a abertura da ala de alto risco", WhenFlag = "eco_m27_risco" },
		}, Guide = "Acione o mecanismo da ala escolhida. A outra terá de esperar." },
		{ Id = "destino", Mission = "28", Region = "fortaleza_mare", Title = "Destino", Objectives = {
			{ Kind = "fx_mare_loop", Goal = 2, Text = "Examine duas anomalias de repetição diferentes" },
		}, Guide = "Movimentos se repetem. Objetos retornam a posições anteriores. A estabilidade deste universo está despencando." },
		{ Id = "ultimo_rastro", Mission = "29", Region = "fortaleza_mare", Title = "O Último Rastro", Objectives = {
			{ Kind = "fx_mare_rastro", Goal = 1, Text = "Recupere o registro da sala ausente das plantas" },
		}, Guide = "Há uma sala que não aparece nas plantas. O equipamento ali não pertence a esta realidade." },
		{ Id = "colapso", Mission = "30", Region = "fortaleza_mare", Title = "Colapso", Objectives = {
			{ Kind = "fx_mare_fragmento", Goal = 2, Text = "Examine fragmentos de duas outras ilhas" },
			{ Kind = "fx_mare_colapso_boss", Goal = 2, Text = "Derrote duas versões alteradas de chefes" },
			{ Kind = "fx_mare_comunicacao", Goal = 1, Text = "Acompanhe o pedido de ajuda aos Anciões" },
		}, Guide = "As regiões estão apresentando anomalias ao mesmo tempo. Pedaços de outras ilhas apareceram aqui. A F/X ameaça mais de uma realidade. Vou pedir ajuda aos outros Anciões." },
		{ Id = "toduro_avalia", Mission = "30 · Toduro", Region = "fortaleza_mare", Title = "Sobreviver não significa estar pronto", Objectives = {
			{ Kind = "fx_mare_toduro", Goal = 1, Text = "Ouça a avaliação de ToduroDemais" },
		}, Guide = "Toduro chegou para avaliar a situação." },
		{ Id = "adryan_chega", Mission = "30 · Adryan", Region = "fortaleza_mare", Title = "Bom trabalho", Objectives = {
			{ Kind = "fx_mare_adryan", Goal = 1, Text = "Converse com Adryan" },
		}, Choice = { Id = "adryan_resposta", Title = "ADRYAN", Text = "Então você é quem está dando trabalho pra todo mundo. Como responde?", Options = {
			{ Id = "agradecer", Label = "Agradecer", Desc = "Aceitar a recepção cordial.", Flags = { "adryan_resposta_agradeceu" }, Say = "Adryan sorri: Bom trabalho." },
			{ Id = "cautela", Label = "Manter cautela", Desc = "Responder sem baixar a guarda.", Flags = { "adryan_resposta_cautela" }, Say = "Adryan sorri: Bom trabalho." },
			{ Id = "seguir", Label = "Focar na ruptura", Desc = "Continuar lidando com a crise.", Flags = { "adryan_resposta_seguir" }, Say = "Adryan sorri: Bom trabalho." },
		} }, Guide = "Adryan chegou depois de Toduro. Vá falar com ele." },
		{ Id = "fratura_principal", Mission = "31", Region = "fortaleza_mare", Title = "A Fratura Principal", Objectives = {
			{ Kind = "fx_mare_fratura", Goal = 1, Text = "Examine a ruptura para a próxima realidade" },
		}, Guide = "Do outro lado: castelos, montanhas, criaturas e magia. A conexão está instável demais. Precisamos estabilizá-la." },
		{ Id = "avatar_fratura", Mission = "31 · Boss final", Region = "fortaleza_mare", Title = "Avatar da Fratura", Objectives = {
			{ Kind = "fx_mare_avatar", Goal = 1, Text = "Derrote o Avatar da Fratura" },
			{ Kind = "fx_mare_ancora", Goal = 3, Text = "Ative três âncoras diferentes enquanto o Avatar está vivo" },
		}, Guide = "A manifestação reúne energia e fragmentos das eras. Ative as âncoras enquanto enfrenta o Avatar." },
		{ Id = "metodo_final", Mission = "31 · escolha final", Region = "fortaleza_mare", Title = "Estabilizar a passagem", Objectives = {},
			Choice = { Id = "eco_final_cap1", Title = "ESTABILIZAR A PASSAGEM", Text = "O Avatar caiu, mas a conexão continua instável. Escolha o método de estabilização.", Options = {
				{ Id = "humanoider", Label = "Método de Humanoider", Desc = "Seguro e mais lento. Algumas pessoas do outro lado podem ficar presas.", Flags = { "final_cap1_humanoider" }, Say = "Vamos usar o método seguro. Ajuste os dois mecanismos e confirme a estabilização." },
				{ Id = "toduro", Label = "Método de Toduro", Desc = "Entre novamente na anomalia e realize três ações internas; melhor resultado estrutural.", Flags = { "final_cap1_toduro" }, Say = "Toduro exige que você entre na anomalia e ajuste os três pontos internos. Não é um caminho fácil." },
				{ Id = "alternativo", Label = "Dispositivo de Carlos", Desc = "Exige Rastros e dispositivo. Mais eficiente, mas registra sua assinatura na rede F/X.", Flags = { "final_cap1_alternativo" }, RequiresFlag = "mare_dispositivo_preparado", Say = "Use o dispositivo de Carlos. Sua assinatura será registrada na rede F/X." },
			} } },
		{ Id = "estabilizacao_final", Mission = "31 · execução", Region = "fortaleza_mare", Title = "Concluir a estabilização", Objectives = {
			{ Kind = "fx_mare_seguro", Goal = 2, Text = "Ajuste os dois mecanismos seguros", WhenFlag = "final_cap1_humanoider" },
			{ Kind = "fx_mare_interno", Goal = 3, Text = "Ajuste os três pontos internos da anomalia", WhenFlag = "final_cap1_toduro" },
			{ Kind = "fx_mare_dispositivo", Goal = 1, Text = "Ative o dispositivo de Carlos", WhenFlag = "final_cap1_alternativo" },
			{ Kind = "fx_mare_estabilizar", Goal = 1, Text = "Confirme a passagem estabilizada" },
		}, UnlockFlag = "cap1_passagem_estabilizada", Guide = "Conclua o método escolhido e confirme a passagem. O resultado central será o mesmo: a conexão estabilizada." },
		{ Id = "encerramento_cap1", Mission = "31 · encerramento", Region = "fortaleza_mare", Title = "Vamos?", Objectives = {
			{ Kind = "fx_mare_encerramento", Goal = 1, Text = "Ouça a despedida e a oferta de Adryan" },
		}, Guide = "Outra crise exige minha presença. Adryan se ofereceu para continuar com você." },
		{ Id = "terminal_cap1", Mission = "31 · última cena", Region = "fortaleza_mare", Title = "C-8 // RASTRO RECUPERADO", Objectives = {
			{ Kind = "fx_mare_terminal", Goal = 1, Text = "Acompanhe a última cena de Humanoider e o terminal" },
		}, UnlockFlag = "cap1_completed", Guide = "Humanoider fica para trás com o primeiro objeto encontrado no Porto da Névoa." },
		{ Id = "cap2_aguarda", Mission = "Capítulo 1 concluído", Title = "Próximo: O Benfeitor", Objectives = {},
			Hint = "O mundo de Adryan aguarda seu place, mapa e integração. A campanha não troca de place automaticamente.", Guide = "Capítulo 1 concluído. A próxima realidade será acompanhada por Adryan." },
	} },
	{ Id = "cap2", Order = 2, Elder = "Adryan", World = "Mundo do Domínio", Inspiration = "Overlord", Title = "O Benfeitor", Acts = {} },
	{ Id = "cap3", Order = 3, Elder = "ToduroDemais", World = "Mundo da Megacidade", Inspiration = "Cyberpunk: Edgerunners", Title = "Treino de Sobrevivência", Acts = {} },
	{ Id = "cap4", Order = 4, Elder = "Lry", World = "Mundo Espiritual", Inspiration = "Bleach", Title = "Entre Camadas", Acts = {} },
	{ Id = "cap5", Order = 5, Elder = "Approx", World = "Mundo das Muralhas", Inspiration = "Attack on Titan", Title = "Além das Muralhas", Acts = {} },
	{ Id = "cap6", Order = 6, Elder = "Fred", World = "Mundo das Maldições", Inspiration = "Jujutsu Kaisen", Title = "O Falso Culpado", Acts = {} },
	{ Id = "cap7", Order = 7, Elder = "Ravy", World = "Universo de Origem", Inspiration = "F/X", Title = "Ponto Zero", Acts = {} },
} :: { Chapter }

local byId: { [string]: Chapter } = {}
local actsById: { [string]: Act } = {}
for _, chapter in StoryConfig.Chapters do
	byId[chapter.Id] = chapter
	for _, act in chapter.Acts do actsById[act.Id] = act end
end

function StoryConfig.Act(id: string): Act?
	return actsById[id]
end

function StoryConfig.Get(id: string): Chapter?
	return byId[id]
end

function StoryConfig.Next(id: string): Chapter?
	local chapter = byId[id]
	return if chapter then StoryConfig.Chapters[chapter.Order + 1] else nil
end

return StoryConfig
