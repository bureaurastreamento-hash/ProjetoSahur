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
	Stand: StandStyle?, -- tem Stand: silhueta de luz ANIMADA atrás (StandSilhouette) na cutscene e nas rajadas ORA/MUDA
}

--- Proporção da silhueta (B5): multiplicadores em cima do R6 (1 = igual ao jogador). Sem modelo externo (dono).
export type StandStyle = {
	Scale: number?, -- tamanho geral (padrão 1.3)
	Torso: number?, -- largura do tronco
	Arms: number?, -- grossura dos braços
	Legs: number?, -- comprimento das pernas
	Head: number?, -- tamanho da cabeça
	Ears: boolean?, -- orelhas de gato (Killer Queen)
	Anchor: Vector3?, -- posição relativa ao jogador (x = lado, y = altura, z = atrás)
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
	-- Stands (B5): Star Platinum = parrudo; The World = alto e reto; Killer Queen = esguio com orelhas
	Jotaro = { UltName = "STAR PLATINUM: THE WORLD", Subtitle = "o tempo é meu", Theme = "rock", Stand = { Scale = 1.35, Torso = 1.25, Arms = 1.3, Legs = 1, Head = 1 } },
	Dio = { UltName = "THE WORLD", Subtitle = "ZA WARUDO", Theme = "stone", Stand = { Scale = 1.4, Torso = 1.1, Arms = 1.1, Legs = 1.1, Head = 0.95 } },
	Kira = { UltName = "KILLER QUEEN", Subtitle = "já tocou", Theme = "arcane", Stand = { Scale = 1.25, Torso = 0.95, Arms = 0.9, Legs = 1.05, Head = 1, Ears = true } },
}

local default: Def = { UltName = "DESPERTAR", Theme = "rock" }
AwakeningDefs.Characters = characters
AwakeningDefs.Default = default

function AwakeningDefs.Get(characterId: string): Def
	return characters[characterId] or default
end

return AwakeningDefs
