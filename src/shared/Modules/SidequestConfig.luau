--!strict
-- Investigações opcionais derivadas dos Ecos (bíblia Cap.1 e ESTRUTURA_JOGO).
-- Não introduzem revelações ou personagens novos; flags usam o save existente da campanha.
local SidequestConfig = {}
export type Quest = { Id: string, Title: string, RequiresFlag: string, Region: string, Island: string, Marker: string, XP: number, Coins: number, Report: string }
SidequestConfig.List = {
	{ Id = "arquivos_capela", Title = "Revisar os arquivos preservados", RequiresFlag = "eco_ilha1_arquivos", Region = "ilha_tutorial", Island = "FXTutorialIsland", Marker = "RachaduraCapela", XP = 25, Coins = 3,
		Report = "Os arquivos preservados ajudam a estudar os experimentos e a F/X. Ainda há muita coisa incompleta." },
	{ Id = "anomalia_deserto", Title = "Examinar a anomalia remanescente", RequiresFlag = "eco_ilha2_transferiu", Region = "ilha_pilares", Island = "FXPilaresIsland", Marker = "CamaraMarker", XP = 35, Coins = 4,
		Report = "A transferência impediu o despertar, mas deixou uma anomalia menor permanente. A observação confirma esse resultado." },
} :: { Quest }

function SidequestConfig.Get(id: string): Quest?
	for _, quest in SidequestConfig.List do if quest.Id == id then return quest end end
	return nil
end

function SidequestConfig.Key(id: string, phase: string): string
	return "side_" .. id .. "_" .. phase
end

function SidequestConfig.State(flags: { [string]: boolean }): { { id: string, title: string, ready: boolean } }
	local result = {}
	for _, quest in SidequestConfig.List do
		if flags[quest.RequiresFlag] and not flags[SidequestConfig.Key(quest.Id, "done")] then
			table.insert(result, { id = quest.Id, title = quest.Title, ready = flags[SidequestConfig.Key(quest.Id, "inspected")] == true })
		end
	end
	if flags.costa_dourada_unlocked and not flags.costa_acesso_social then
		table.insert(result, { id = "costa_contato", title = if flags.costa_favor_recolhido then "Volte ao contato da Costa Dourada" elseif flags.costa_contato_conhecido then "Busque a entrega do contato da Costa Dourada" else "Converse com o contato da Costa para obter acesso social", ready = false })
	end
	return result
end

function SidequestConfig.EchoSummary(flags: { [string]: boolean }): string
	local lines = {}
	if flags.eco_m3_deixou then table.insert(lines, "Só quem conseguia andar saiu da fenda.")
	elseif flags.eco_m3_carregou or flags.eco_m3_saida then table.insert(lines, "Os dois sobreviventes saíram da fenda.") end
	if flags.eco_ilha1_prisioneiros and flags.eco_ilha1_arquivos then table.insert(lines, "Os prisioneiros saíram e parte dos arquivos foi recuperada.")
	elseif flags.eco_ilha1_arquivos then table.insert(lines, "Os arquivos foram recuperados; nem todos os prisioneiros saíram.")
	elseif flags.eco_ilha1_prisioneiros then table.insert(lines, "Mais prisioneiros saíram; parte dos dados se perdeu.") end
	return table.concat(lines, " ")
end

return SidequestConfig
