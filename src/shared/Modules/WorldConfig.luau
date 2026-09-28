--!strict
--[[
	WorldConfig — catálogo autoritativo dos mundos e regiões de F/X.
	A arena atual é preservada como região PvP. Regiões futuras entram aqui apenas quando
	tiverem mapa e checkpoint reais; config não deve teleportar jogador para cenário vazio.
]]

local WorldConfig = {}

export type Checkpoint = { Position: Vector3, Yaw: number }
export type Region = {
	Id: string,
	Name: string,
	Universe: string,
	Chapter: string?,
	Pvp: boolean,
	Available: boolean,
	Checkpoints: { [string]: Checkpoint },
}

WorldConfig.DefaultRegion = "ilha_tutorial"
WorldConfig.DefaultCheckpoint = "porto"

WorldConfig.Regions = {
	fx_origem = {
		Id = "fx_origem",
		Name = "Encruzilhada F/X",
		Universe = "origem",
		Chapter = "cap1",
		Pvp = true,
		Available = true,
		-- Usa a área já sincronizada enquanto o porto do Capítulo 1 não é produzido.
		Checkpoints = { chegada = { Position = Vector3.new(0, 5, 0), Yaw = 0 } },
	},
	ilha_tutorial = {
		Id = "ilha_tutorial", Name = "Ilha do Alvorecer", Universe = "mundo_das_eras", Chapter = "cap1",
		Pvp = true, Available = true,
		Checkpoints = { porto = { Position = Vector3.new(850, 5, 130), Yaw = 180 } },
	},
	arena_pvp = {
		Id = "arena_pvp", Name = "Ilha da Convergência", Universe = "origem", Chapter = nil,
		Pvp = true, Available = true,
		Checkpoints = { praca = { Position = Vector3.new(0, 5, 0), Yaw = 90 } },
	},
	ilha_sol_partido = {
		Id = "ilha_sol_partido", Name = "Ilha do Sol Partido", Universe = "mundo_das_eras", Chapter = "cap1",
		Pvp = true, Available = true,
		Checkpoints = { oasis = { Position = Vector3.new(1360, 10, 70), Yaw = 90 } },
	},
} :: { [string]: Region }

function WorldConfig.GetRegion(id: string): Region?
	return WorldConfig.Regions[id]
end

function WorldConfig.GetCheckpoint(regionId: string, checkpointId: string): Checkpoint?
	local region = WorldConfig.GetRegion(regionId)
	return if region then region.Checkpoints[checkpointId] else nil
end

function WorldConfig.CFrameOf(regionId: string, checkpointId: string): CFrame?
	local checkpoint = WorldConfig.GetCheckpoint(regionId, checkpointId)
	if not checkpoint then
		return nil
	end
	return CFrame.new(checkpoint.Position) * CFrame.Angles(0, math.rad(checkpoint.Yaw), 0)
end

return WorldConfig
