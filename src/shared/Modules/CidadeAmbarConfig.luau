--!strict
-- A bíblia define os eventos; tarefas/pistas abaixo são interações iniciais, sem nova subtrama.
local Config = {}
Config.Region = "cidade_ambar"
Config.Map = "FXCidadeAmbar"
Config.Interactions = {
	AmbarMorador1 = { Kind = "fx_ambar_morador", Title = "Morador", Text = "A conversa transcorre normalmente. A cidade parece estável." },
	AmbarMorador2 = { Kind = "fx_ambar_morador", Title = "Morador", Text = "Outro morador apresenta a vida cotidiana da cidade." },
	AmbarTarefa = { Kind = "fx_ambar_tarefa", Title = "Tarefa simples", Text = "Você terminou a pequena tarefa e ajudou um morador." },
	AmbarDesaparecimento1 = { Kind = "fx_ambar_desaparecimento", Title = "Desaparecimento", Text = "Há sinais de alguém que desapareceu. As pessoas agem como se nunca tivesse existido." },
	AmbarDesaparecimento2 = { Kind = "fx_ambar_desaparecimento", Title = "Desaparecimento", Text = "Outro local mostra a mesma contradição entre os sinais e a memória dos moradores." },
	AmbarFotografia = { Kind = "fx_ambar_foto", Title = "Fotografia antiga", Text = "O símbolo se parece com o dos Rastros. O rosto está danificado; não é possível identificar a pessoa. Leve a fotografia ao Humanoider." },
	AmbarCena1 = { Kind = "fx_ambar_cena", Title = "Cena", Text = "A cena contém sinais de uma anomalia usada para ocultar o crime." },
	AmbarCena2 = { Kind = "fx_ambar_cena", Title = "Cena", Text = "Os sinais se repetem nesta outra cena." },
	AmbarTestemunha = { Kind = "fx_ambar_depoimento", Title = "Testemunha", Text = "O depoimento permite comparar quem teve vínculo com os locais investigados." },
	AmbarPadrao = { Kind = "fx_ambar_padrao", Title = "Conectar pistas", Text = "As duas cenas e o depoimento apontam para alguém ligado aos locais, não para uma pessoa sem vínculo." },
	AmbarContrapista = { Kind = "fx_ambar_contrapista", Title = "Reinvestigar", Text = "Reexaminar a pista descarta a acusação sem vínculo. O padrão das cenas permanece." },
	AmbarCasa = { Kind = "fx_ambar_casa", Title = "Casa vazia", Text = "Uma pequena ruptura controlada. Pela primeira vez, parece artificial." },
} :: { [string]: { Kind: string, Title: string, Text: string } }
Config.Revelation = "(Humanoider pega a fotografia. Você o confronta.) Carlos. Ele era um de nós. Você: Um Ancião? Humanoider: Éramos oito. Agora somos sete."
return Config
