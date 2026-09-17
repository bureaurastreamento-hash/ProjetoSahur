--!strict
--[[
	AwakeningDefs
	Identidade da cutscene do DESPERTAR (G) por personagem: nome grande da ult na tela, tema do "mundo
	reagindo" (o que sobe/gira/racha em volta durante a carga e o que estoura), poses e sons próprios.
	Lido só pelo cliente (CutsceneController); nada aqui muda regra de jogo.

	Temas (implementados em CutsceneController.THEMES):
	  rock      pedras levitando + chão rachando; estouro = pedras voam           (Brawler)
	  lightning pós-imagens do corpo + raios do chão; estouro = raios em volta    (Swift)
	  arcane    anel de runas no chão + esferas orbitando; estouro = convergem     (Mystic)
	  stone     pilares de pedra sobem em círculo; estouro = desmoronam            (Guardian)
	  drums     pulsos de luz/anéis no ritmo (acelerando); estouro = anel gigante  (Sahur)
	  void      esfera escura crescendo + mundo dessaturado; estouro = colapsa     (Overlord)
	  flesh     bolhas de carne borbulhando; estouro = estouram                    (BigChop)

	Sons: Sounds.<Char>.Awakening_Voice (grito no estouro) > Sounds.Shared.Awakening_Voice.
	Poses: opcional; sem entrada usa as poses padrão do CutsceneController.
]]

export type Def = {
	UltName: string, -- texto grande no estouro
	Subtitle: string?, -- linha pequena abaixo
	Theme: string,
	Color: Color3?, -- sobrescreve CharacterDefs.Color na cena
	VoiceAt: number?, -- segundos DEPOIS do estouro para o grito (padrão 0.05)
}

local AwakeningDefs = {}

local characters: { [string]: Def } = {
	Brawler = { UltName = "FÚRIA", Subtitle = "força bruta", Theme = "rock" },
	Swift = { UltName = "TEMPESTADE", Subtitle = "velocidade absoluta", Theme = "lightning" },
	Mystic = { UltName = "METEORO", Subtitle = "o céu cai", Theme = "arcane" },
	Guardian = { UltName = "TERREMOTO", Subtitle = "muralha viva", Theme = "stone" },
	Sahur = { UltName = "RITMO FINAL", Subtitle = "o ritmo que esmaga", Theme = "drums" },
	Overlord = { UltName = "CATACLISMO", Subtitle = "só admin", Theme = "void" },
	BigChop = { UltName = "FRENESI", Subtitle = "não morre, só cresce", Theme = "flesh" },
}

local default: Def = { UltName = "DESPERTAR", Theme = "rock" }
AwakeningDefs.Characters = characters
AwakeningDefs.Default = default

function AwakeningDefs.Get(characterId: string): Def
	return characters[characterId] or default
end

return AwakeningDefs
