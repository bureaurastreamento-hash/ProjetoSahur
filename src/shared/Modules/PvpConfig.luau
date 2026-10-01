--!strict
-- PvP aberto com as proteções de BIZARRE_DIRECAO.md. Números iniciais para teste.
local PvpConfig = {}
PvpConfig.RespawnProtection = 10
PvpConfig.CombatSeconds = 20
PvpConfig.RepeatRewardSeconds = 300
PvpConfig.MaxLevelGap = 10
PvpConfig.LogoutCoinFraction = 0.1
PvpConfig.LogoutCoinCap = 50
PvpConfig.SafeZones = {
	{ Name = "Porto", Center = Vector3.new(40, 2, 185), Radius = 30 },
	{ Name = "Taberna", Center = Vector3.new(352, 0, 62), Radius = 38 },
	{ Name = "Deserto · chegada", Center = Vector3.new(690, 2, -420), Radius = 25 },
	{ Name = "Eclipse · chegada", Center = Vector3.new(1710, 2, -130), Radius = 25 },
}

function PvpConfig.LevelsRewardable(killerLevel: number, victimLevel: number): boolean
	return killerLevel - victimLevel <= PvpConfig.MaxLevelGap
end

require(script.Parent.IslandLayout).TranslateTable(PvpConfig)
return PvpConfig
