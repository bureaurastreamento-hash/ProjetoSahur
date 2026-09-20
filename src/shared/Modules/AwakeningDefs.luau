--!strict
--[[
	AwakeningDefs
	Identidade da cutscene do DESPERTAR (G) por personagem: nome grande da ult na tela, tema do "mundo
	reagindo" (o que sobe/gira/racha em volta durante a carga e o que estoura), poses e sons próprios.
	Lido só pelo cliente (CutsceneController); nada aqui muda regra de jogo.

	Temas (implementados em CutsceneController.THEMES):
	  rock      pedras levitando + chão rachando; estouro = pedras voam           (Jotaro)
	  lightning pós-imagens do corpo + raios do chão; estouro = raios em volta    (Swift)
	  arcane    anel de runas no chão + esferas orbitando; estouro = convergem     (Kira)
	  stone     pilares de pedra sobem em círculo; estouro = desmoronam            (Dio)
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
	Stand: boolean?, -- tem Stand: silhueta de luz atrás (StandSilhouette) na cutscene e nas rajadas ORA/MUDA
}

local AwakeningDefs = {}

local characters: { [string]: Def } = {
	Swift = { UltName = "DOMÍNIO DO TEMPO", Subtitle = "Bruno Gollini", Theme = "lightning" }, -- Swift = Bruno Gollini (dono, 2026-09-20)
	Sahur = { UltName = "RITMO FINAL", Subtitle = "o ritmo que esmaga", Theme = "drums" },
	Overlord = { UltName = "CATACLISMO", Subtitle = "só admin", Theme = "void" },
	BigChop = { UltName = "FRENESI", Subtitle = "não morre, só cresce", Theme = "flesh" },
	-- roster decidido (2026-09-20): a forma da ult é o nome da direita
	Rick = { UltName = "RICK PRIME", Subtitle = "o Rick mais inteligente do multiverso", Theme = "void", Color = Color3.fromRGB(120, 255, 180) },
	-- (2026-09-21: os antigos Brawler/Mystic/Guardian viraram Jotaro/Kira/Dio — kits mantidos até os movesets próprios)
	Jotaro = { UltName = "STAR PLATINUM: THE WORLD", Subtitle = "o tempo é meu", Theme = "rock", Stand = true },
	Dio = { UltName = "THE WORLD", Subtitle = "ZA WARUDO", Theme = "stone", Stand = true },
	Kira = { UltName = "KILLER QUEEN", Subtitle = "já tocou", Theme = "arcane", Stand = true },
}

local default: Def = { UltName = "DESPERTAR", Theme = "rock" }
AwakeningDefs.Characters = characters
AwakeningDefs.Default = default

function AwakeningDefs.Get(characterId: string): Def
	return characters[characterId] or default
end

return AwakeningDefs
