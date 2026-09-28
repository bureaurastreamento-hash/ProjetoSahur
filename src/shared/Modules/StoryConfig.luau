--!strict
--[[ StoryConfig — esqueleto canônico da campanha F/X. Ver BIBLIA_HISTORIA_FX_v1.0.md. ]]

local StoryConfig = {}

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
export type Act = { Id: string, Title: string, Objectives: { Objective }, Trace: string?, Hint: string? }

StoryConfig.Chapters = {
	{ Id = "cap1", Order = 1, Elder = "Humanoider_20", World = "Mundo das Eras", Inspiration = "JoJo", Title = "A Primeira Fratura", Acts = {
		{ Id = "chegada", Title = "Um mundo fora do lugar", Objectives = {}, Hint = "Fale com Humanoider_20 na vila." },
		{ Id = "primeiros_golpes", Title = "Aprenda a sobreviver", Objectives = {
			{ Kind = "kills", Goal = 3, Text = "Derrote 3 inimigos" },
			{ Kind = "parries", Goal = 1, Text = "Execute 1 parry" },
		} },
		{ Id = "rastro_carlos_01", Title = "O homem que não está aqui", Objectives = {
			{ Kind = "trace_carlos_era01", Goal = 1, Text = "Investigue o rastro desconhecido" },
		}, Trace = "carlos_era01" },
		{ Id = "guardiao_da_era", Title = "Guardião da primeira era", Objectives = {
			{ Kind = "fx_cap1_boss", Goal = 1, Text = "Derrote o guardião da região" },
		} },
		{ Id = "rota_sol_partido", Title = "Rumo ao Sol Partido", Objectives = {}, Hint = "Use o portal no lado oeste da Ilha do Alvorecer." },
		{ Id = "prova_do_oasis", Title = "A prova do oásis", Objectives = {
			{ Kind = "fx_sol_enemy", Goal = 5, Text = "Derrote 5 Saqueadores Solares" },
			{ Kind = "parries", Goal = 2, Text = "Execute 2 parries" },
		} },
		{ Id = "subida_do_templo", Title = "Suba o templo partido", Objectives = {
			{ Kind = "fx_sol_temple", Goal = 1, Text = "Alcance o altar solar" },
		} },
		{ Id = "sentinela_solar", Title = "A Sentinela Solar", Objectives = {
			{ Kind = "fx_sol_boss", Goal = 1, Text = "Derrote a Sentinela Solar" },
		} },
		{ Id = "rota_mar_cinzas", Title = "Uma rota pelo Mar de Cinzas", Objectives = {}, Hint = "A próxima rota ainda está sendo estabilizada." },
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
