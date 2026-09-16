--!strict
--[[
	WarConfig
	Guerra de clã = DOMINAÇÃO: dois clãs, cópia da arena no céu (como os duelos), 3 pontos de captura
	(pasta CapturePoints do mapa: A/B/C). Ficar sozinho num ponto por CaptureSeconds captura; cada ponto
	dominado rende PointsPerSecond ao clã. Vence quem chega a ScoreToWin ou tem mais pontos ao acabar o tempo.
	Fila: líder/oficial põe o clã na fila (RequestWar "queue") com os membros online; com 2 clãs, começa.
]]

local WarConfig = {}

-- Mapas da guerra em ServerStorage.Maps (com Spawns e CapturePoints). Sorteia entre os que existirem;
-- Arena_Antiga = muros do projeto antigo do dono + interior gerado (tools/montar_arena_antiga.luau, roda no Studio).
WarConfig.Maps = { "Arena_Antiga", "Arena_Gerada" }
WarConfig.MapName = "Arena_Gerada" -- reserva se nenhum da lista existir
WarConfig.MinPerSide = 1 -- membros online mínimos para entrar na fila (subir para 2-3 depois dos testes)
WarConfig.MaxPerSide = 6
WarConfig.Countdown = 5
WarConfig.Duration = 300 -- s
WarConfig.ScoreToWin = 300
WarConfig.CaptureRadius = 12
WarConfig.CaptureSeconds = 5 -- sozinho no ponto por esse tempo = captura
WarConfig.PointsPerSecond = 1 -- por ponto dominado
WarConfig.Tick = 0.5
WarConfig.RespawnProtection = 2 -- s sem poder apanhar depois de renascer (CanFight volta depois)
WarConfig.EndTime = 6
WarConfig.MaxConcurrent = 2
-- Longe dos duelos (DuelConfig.ArenaOrigin = 4000,1500,4000)
WarConfig.ArenaOrigin = Vector3.new(-4000, 1500, 4000)
WarConfig.ArenaSpacing = 800
WarConfig.FallDepth = 60

-- Recompensas
WarConfig.Rewards = {
	WinnerCoins = 80, -- por jogador
	LoserCoins = 25,
	WinnerVault = 250, -- para o cofre do clã
	LoserVault = 60,
}

WarConfig.TeamColors = { Color3.fromRGB(70, 140, 255), Color3.fromRGB(255, 80, 80) }
WarConfig.NeutralColor = Color3.fromRGB(180, 180, 190)

return WarConfig
