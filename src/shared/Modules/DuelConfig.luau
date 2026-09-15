--!strict
--[[
	DuelConfig
	Duelos opt-in dentro do mapa livre: 1v1 por desafio direto e 2v2 por salas (TeamSize).
	Fluxo: A desafia B (RequestDuel "challenge") -> B aceita -> os dois vão para uma cópia
	da arena no céu, longe do mapa -> MELHOR DE 3 (morte/tempo/queda decide cada round; quem morre
	renasce no mapa e volta para a arena no round seguinte) -> recompensa via
	DataService.RecordMatchResult (DataConfig.Rewards) -> volta ao mapa livre.
]]

local DuelConfig = {}

DuelConfig.MapName = "Arena_Gerada" -- Model em ServerStorage.Maps (com pasta Spawns)
DuelConfig.InviteTimeout = 20 -- s até o convite expirar
DuelConfig.Countdown = 3 -- s de "preparar" antes de liberar o combate
DuelConfig.RoundTime = 120 -- s máximos de cada round (empate se ninguém cair)
-- Melhor de 3: quem vencer RoundsToWin rounds leva; MaxRounds fecha a série (mais rounds vencidos ganha).
DuelConfig.RoundsToWin = 2
DuelConfig.MaxRounds = 3
DuelConfig.BetweenRounds = 3 -- s mostrando o placar antes do próximo round
DuelConfig.EndTime = 4 -- s mostrando o resultado antes de voltar
DuelConfig.MaxConcurrent = 8 -- arenas simultâneas
DuelConfig.TeamSize = 2 -- jogadores por time nas salas de equipe (2 = 2v2)

-- Onde as cópias da arena ficam: longe e alto para nunca encostar no mapa da equipe.
DuelConfig.ArenaOrigin = Vector3.new(4000, 1500, 4000)
DuelConfig.ArenaSpacing = 800 -- studs entre arenas (Arena_Gerada tem 320x320)
DuelConfig.FallDepth = 60

-- Ranking (Elo) de duelos 1v1: profile.rating (começa em 1000); K = variação máxima por duelo.
DuelConfig.RatingStart = 1000
DuelConfig.RatingK = 24 -- abaixo do chão da arena = eliminado (caiu)

return DuelConfig
