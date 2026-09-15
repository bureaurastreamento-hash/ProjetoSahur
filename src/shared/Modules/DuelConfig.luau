--!strict
--[[
	DuelConfig
	Duelos opt-in dentro do mapa livre: 1v1 por desafio direto e 2v2 por salas (TeamSize).
	Fluxo: A desafia B (RequestDuel "challenge") -> B aceita -> os dois vão para uma cópia
	da arena no céu, longe do mapa -> morte/tempo/queda decide -> recompensa via
	DataService.RecordMatchResult (DataConfig.Rewards) -> volta ao mapa livre.
]]

local DuelConfig = {}

DuelConfig.MapName = "Arena_Gerada" -- Model em ServerStorage.Maps (com pasta Spawns)
DuelConfig.InviteTimeout = 20 -- s até o convite expirar
DuelConfig.Countdown = 3 -- s de "preparar" antes de liberar o combate
DuelConfig.RoundTime = 120 -- s máximos de duelo (empate se ninguém cair)
DuelConfig.EndTime = 4 -- s mostrando o resultado antes de voltar
DuelConfig.MaxConcurrent = 8 -- arenas simultâneas
DuelConfig.TeamSize = 2 -- jogadores por time nas salas de equipe (2 = 2v2)

-- Onde as cópias da arena ficam: longe e alto para nunca encostar no mapa da equipe.
DuelConfig.ArenaOrigin = Vector3.new(4000, 1500, 4000)
DuelConfig.ArenaSpacing = 800 -- studs entre arenas (Arena_Gerada tem 320x320)
DuelConfig.FallDepth = 60 -- abaixo do chão da arena = eliminado (caiu)

return DuelConfig
