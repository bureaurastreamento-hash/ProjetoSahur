--!strict
local Config = {}
Config.Map, Config.Region = "FXFortalezaMare", "fortaleza_mare"
Config.Interactions = {
	MarePrisao = { Kind = "fx_mare_prisao", Text = "A prisão reúne pessoas com habilidades surgidas após a F/X. Há gente perigosa e gente detida injustamente." },
	MareLoop1 = { Kind = "fx_mare_loop", Text = "Um movimento se repete como se o acontecimento tivesse voltado ao início." },
	MareLoop2 = { Kind = "fx_mare_loop", Text = "Um objeto retorna à posição anterior. A estabilidade do universo está despencando." },
	MareRastro = { Kind = "fx_mare_rastro", Text = "Equipamento antigo do Universo de Origem, assinado por Carlos, numa sala ausente das plantas. Registro: ‘Se alguém encontrar isto…’ [ruído] ‘…as linhas não começaram a falhar sozinhas.’ [ruído] ‘Não confiem no padrão.’ Humanoider fica em silêncio. Você: Carlos sabia? Humanoider: Acho que Carlos sabia de muita coisa." },
	MareFragmento1 = { Kind = "fx_mare_fragmento", Text = "Um fragmento de outra ilha apareceu dentro da fortaleza." },
	MareFragmento2 = { Kind = "fx_mare_fragmento", Text = "Fragmentos de outra era se juntam à crise. As anomalias atingem as regiões ao mesmo tempo." },
	MareComunicador = { Kind = "fx_mare_comunicacao", Text = "Humanoider pede ajuda. Approx mantém uma ruptura estabilizada. Lry percebe distorções espirituais. Fred elimina uma ameaça. Ravy aparece pela comunicação." },
	MareToduro = { Kind = "fx_mare_toduro", Text = "Toduro: Isso é o escolhido? Humanoider: Ele sobreviveu. Toduro: Sobreviver não significa estar pronto." },
	MareAdryan = { Kind = "fx_mare_adryan", Text = "Adryan chega depois. Então você é quem está dando trabalho pra todo mundo." },
	MareFratura = { Kind = "fx_mare_fratura", Text = "Uma ruptura gigantesca revela castelos, montanhas, criaturas e magia. A próxima realidade está instável demais para manter a conexão." },
	MareAncora1 = { Kind = "fx_mare_ancora", Text = "Primeira âncora ativada durante o combate." },
	MareAncora2 = { Kind = "fx_mare_ancora", Text = "Segunda âncora ativada durante o combate." },
	MareAncora3 = { Kind = "fx_mare_ancora", Text = "Terceira âncora ativada durante o combate." },
	MareSeguro1 = { Kind = "fx_mare_seguro", Text = "Primeiro mecanismo do método seguro ajustado." },
	MareSeguro2 = { Kind = "fx_mare_seguro", Text = "Segundo mecanismo do método seguro ajustado. O processo mais lento pode deixar pessoas do outro lado presas." },
	MareInterno1 = { Kind = "fx_mare_interno", Text = "Primeiro ponto interno da anomalia ajustado." },
	MareInterno2 = { Kind = "fx_mare_interno", Text = "Segundo ponto interno da anomalia ajustado." },
	MareInterno3 = { Kind = "fx_mare_interno", Text = "Terceiro ponto interno ajustado. Toduro: Ainda lento." },
	MareAtivarDispositivo = { Kind = "fx_mare_dispositivo", Text = "O dispositivo estabiliza a rede com eficiência, registrando a assinatura do protagonista na F/X." },
	MareEstabilizar = { Kind = "fx_mare_estabilizar", Text = "A passagem foi estabilizada. Todos os métodos mantêm a conexão para a próxima realidade." },
	MareEncerramento = { Kind = "fx_mare_encerramento", Text = "Outra crise exige a presença de Humanoider. Adryan: Eu posso levar ele. Toduro: Ele não está pronto. Adryan: Então alguém precisa ajudá-lo a ficar. Toduro olha para você e sai. Adryan: Não leva pro pessoal. Ele é assim com todo mundo. [Estende a mão.] Vamos?" },
	MareTerminal = { Kind = "fx_mare_terminal", Text = "[Última cena] Humanoider fica para trás e aproxima o primeiro objeto de Carlos de um terminal. O terminal acende sozinho: C-8 // RASTRO RECUPERADO. Outra linha: 1 DE ?. Capítulo 1 concluído." },
} :: { [string]: { Kind: string, Text: string } }
Config.SpecialMarkers = { "MareCheckpoint", "MareToCosta", "MareHumanoider", "MareAlaCivil", "MareAlaRisco", "MarePrepararDispositivo", "MareColapsoPad1", "MareColapsoPad2" }
function Config.Wings(flags: { [string]: boolean }): string
	if flags.eco_m27_civil then return "A ala civil recebeu energia primeiro. A ala de alto risco sofreu a demora."
	elseif flags.eco_m27_risco then return "A ala de alto risco recebeu energia primeiro. A ala civil sofreu a demora." end
	return ""
end
return Config
