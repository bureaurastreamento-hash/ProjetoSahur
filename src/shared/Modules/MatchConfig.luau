--!strict
--[[
	MatchConfig
	Regras de partida. Mode define o núcleo do jogo.
	  FFA   : todos contra todos, cada jogador é seu próprio time.
	  Duel  : 1v1.
	  Teams : NvN (TeamSize).
	Vitória em qualquer modo: só um time com jogadores vivos. No tempo limite
	vence o time com mais kills (empate = "Draw").
]]

export type ModeDef = {
	MinPlayers: number,
	MaxPlayers: number,
	TeamSize: number, -- 0 = cada um por si
}

local MatchConfig = {}

-- Núcleo atual: MAPA LIVRE (todos lutam o tempo todo no mesmo mapa, sem rounds).
-- Com FreeRoam = false, volta o loop de rounds (fila → seleção → round) usando Mode.
MatchConfig.FreeRoam = true
MatchConfig.Mode = "FFA"

MatchConfig.Modes = {
	FFA = { MinPlayers = 2, MaxPlayers = 8, TeamSize = 0 } :: ModeDef,
	Duel = { MinPlayers = 2, MaxPlayers = 2, TeamSize = 1 } :: ModeDef,
	Teams = { MinPlayers = 4, MaxPlayers = 4, TeamSize = 2 } :: ModeDef,
}

MatchConfig.SelectTime = 15 -- segundos para escolher personagem antes do round
MatchConfig.RoundTime = 180 -- duração máxima do round
MatchConfig.EndTime = 6 -- tela de resultado
MatchConfig.AllowLobbyCombat = true -- DEBUG: permite socos/habilidades no lobby. TODO(launch): false

-- Atributos no Player usados como "contrato" entre serviços (sem acoplamento direto):
--   CanFight (boolean) : CombatService/AbilityService/HealthService só agem se ~= false
--   InMatch  (boolean) : está participando do round atual
--   InQueue  (boolean) : está na fila do lobby
--   TeamId   (number)  : time no round atual

function MatchConfig.GetMode(): ModeDef
	return MatchConfig.Modes[MatchConfig.Mode] or MatchConfig.Modes.FFA
end

return MatchConfig
