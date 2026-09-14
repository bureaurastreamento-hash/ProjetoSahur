--!strict
--[[
	DataConfig
	Formato do perfil salvo por jogador e regras de recompensa.
	Mudou o formato? Suba SchemaVersion e trate a migração em DataService.migrate().
]]

local DataConfig = {}

DataConfig.StoreName = "PlayerData"
DataConfig.SchemaVersion = 1

DataConfig.AutosaveInterval = 90 -- segundos
DataConfig.LoadRetries = 3
DataConfig.SaveRetries = 3
DataConfig.RetryBaseDelay = 1 -- segundos; dobra a cada tentativa

-- DEBUG: força falha em todas as chamadas ao DataStore para testar o fallback.
-- TODO(launch): manter false
DataConfig.SimulateFailure = false

DataConfig.Rewards = {
	Win = 50,
	Loss = 10,
	Kill = 5,
}

export type Stats = { wins: number, losses: number, kills: number, deaths: number, matches: number }
export type Profile = {
	schemaVersion: number,
	coins: number,
	unlockedCharacters: { string },
	stats: Stats,
}

function DataConfig.DefaultProfile(): Profile
	return {
		schemaVersion = DataConfig.SchemaVersion,
		coins = 0,
		unlockedCharacters = { "Brawler" },
		stats = { wins = 0, losses = 0, kills = 0, deaths = 0, matches = 0 },
	}
end

return DataConfig
