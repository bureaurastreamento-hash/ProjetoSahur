--!strict
-- Eventos da Ilha 5, conforme a bíblia; implementação inicial por marcadores reais.
local Config = {}
Config.Map, Config.Region = "FXCostaDourada", "costa_dourada"
Config.Interactions = {
	CostaLote1 = { Kind = "fx_costa_mercado", Text = "Armas e fragmentos de outras realidades. Alguns objetos lembram as ilhas anteriores." },
	CostaLote2 = { Kind = "fx_costa_mercado", Text = "Outro lote contém objetos de lugares que você nunca viu. Existe comércio entre realidades." },
	CostaOrganizacao = { Kind = "fx_costa_organizacao", Text = "Uma facção domina o tráfico interdimensional. Explora a F/X, mas não a criou." },
	CostaPassagem1 = { Kind = "fx_costa_furtivo", Text = "Você atravessou a passagem lateral. Siga para a passagem interna." },
	CostaPassagem2 = { Kind = "fx_costa_furtivo", Text = "Você atravessou a passagem interna sem exigir combate. Siga pelo acesso furtivo." },
	CostaRegistro1 = { Kind = "fx_costa_registro", Text = "O registro de entregas mostra rupturas em horários específicos." },
	CostaRegistro2 = { Kind = "fx_costa_registro", Text = "Comparar o segundo registro confirma um padrão de horários. Algumas rupturas podem estar sendo coordenadas." },
	CostaC8 = { Kind = "fx_costa_c8", Text = "O carregamento traz a identificação C-8. Mostre o registro ao Humanoider." },
} :: { [string]: { Kind: string, Text: string } }
Config.SpecialMarkers = { "CostaHumanoider", "CostaCheckpoint", "CostaToAmbar", "CostaContato", "CostaFavor",
	"CostaAcessoForca", "CostaAcessoFurtivo", "CostaAcessoSocial", "CostaGuardPad1", "CostaGuardPad2", "CostaGuardPad3" }
Config.C8Report = "C-8... Carlos usava esse antigo sistema de identificação. Objetos pessoais e de pesquisa dele estão circulando no mercado negro. Como chegaram aqui?"
function Config.Style(flags: { [string]: boolean }): string
	if flags.costa_infiltracao_forca then return "Os moradores reconhecem que você abriu caminho pela força."
	elseif flags.costa_infiltracao_furtividade then return "Os moradores reconhecem seu caminho pelas passagens discretas."
	elseif flags.costa_infiltracao_social then return "O contato reconhece que você obteve acesso ajudando alguém." end
	return ""
end
function Config.Market(flags: { [string]: boolean }): string
	if flags.eco_ilha5_destruiu then return "O mercado negro foi encerrado."
	elseif flags.eco_ilha5_faccao then return "Uma facção menos agressiva controla o mercado."
	elseif flags.eco_ilha5_monitorou then return "O mercado permanece sob monitoramento do Humanoider." end
	return ""
end
return Config
