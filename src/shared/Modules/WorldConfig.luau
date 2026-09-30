--!strict
--[[
	WorldConfig — catálogo autoritativo dos mundos e regiões de F/X.
	Arquipélago do Capítulo 1 (2026-09-28, MAPA_CAPITULO_1.md "Layout do mundo"): a arena fechada foi
	desmontada; o chão das ilhas é Terrain (tools/studio/MontarMundo.luau, mesmos centros/raios de Islands abaixo).
	Regiões futuras ficam indisponíveis e sem checkpoint até terem mapa validado.
	Ids persistidos NÃO mudam: "arena_pvp" (antiga Ilha da Convergência) agora aponta para o Coliseu.
	Nomes = BIBLIA_CAMPANHA_CAP1_v0.1.md (2026-09-29): ilha_tutorial = Porto da Névoa (Parte 1), ilha_pilares =
	Deserto do Sol (Parte 2), ilha_sol_partido = Rota do Eclipse (Parte 3). Ids antigos ficam por causa dos saves.
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
	-- Pescador (FisherService): NPC perto da chegada; conversar SALVA o spawn neste checkpoint da ilha.
	Fisher: { Position: Vector3, Checkpoint: string }?,
}

WorldConfig.DefaultRegion = "ilha_tutorial"
WorldConfig.DefaultCheckpoint = "porto"

WorldConfig.Regions = {
	fortaleza_mare = {
		Id = "fortaleza_mare", Name = "Fortaleza Maré", Universe = "mundo_das_eras", Chapter = "cap1",
		Pvp = true, Available = false, Checkpoints = {},
	},
	costa_dourada = {
		Id = "costa_dourada", Name = "Costa Dourada", Universe = "mundo_das_eras", Chapter = "cap1",
		Pvp = true, Available = false, Checkpoints = {},
	},
	cidade_ambar = {
		Id = "cidade_ambar", Name = "Cidade Âmbar", Universe = "mundo_das_eras", Chapter = "cap1",
		Pvp = true, Available = false, Checkpoints = {}, -- ativado somente pelo mapa validado
	},
	fx_origem = {
		Id = "fx_origem",
		Name = "Encruzilhada F/X",
		Universe = "origem",
		Chapter = "cap1",
		Pvp = true,
		Available = true,
		-- legado: centro do Porto da Névoa
		Checkpoints = { chegada = { Position = Vector3.new(40, 2, 150), Yaw = 0 } },
	},
	ilha_tutorial = {
		Id = "ilha_tutorial", Name = "Porto da Névoa", Universe = "mundo_das_eras", Chapter = "cap1",
		Pvp = true, Available = true,
		Checkpoints = { porto = { Position = Vector3.new(40, 2, 185), Yaw = 0 } },
		Fisher = { Position = Vector3.new(52, 0, 178), Checkpoint = "porto" },
	},
	arena_pvp = {
		Id = "arena_pvp", Name = "Coliseu do Deserto", Universe = "mundo_das_eras", Chapter = "cap1",
		Pvp = true, Available = true,
		Checkpoints = { praca = { Position = Vector3.new(900, 2, -340), Yaw = 0 } },
	},
	ilha_pilares = {
		Id = "ilha_pilares", Name = "Deserto do Sol", Universe = "mundo_das_eras", Chapter = "cap1",
		Pvp = true, Available = true,
		Checkpoints = { praia = { Position = Vector3.new(690, 2, -420), Yaw = -90 } },
		Fisher = { Position = Vector3.new(702, 0.5, -410), Checkpoint = "praia" },
	},
	ilha_sol_partido = {
		Id = "ilha_sol_partido", Name = "Rota do Eclipse", Universe = "mundo_das_eras", Chapter = "cap1",
		Pvp = true, Available = true,
		Checkpoints = { oasis = { Position = Vector3.new(1710, 2, -130), Yaw = -90 } },
		Fisher = { Position = Vector3.new(1722, 0, -122), Checkpoint = "oasis" },
	},
} :: { [string]: Region }

-- Ilhas: centro XZ + raios da elipse. O chão de peças (tools/gerar_chao_ilhas.py, cópia lá) usa os mesmos números; e serve para
-- saber em que ilha um ponto está (RegionAt).
export type Island = { Id: string, Region: string?, Center: Vector3, RadiusX: number, RadiusZ: number }
WorldConfig.Islands = {
	{ Id = "alvorecer", Region = "ilha_tutorial", Center = Vector3.new(150, 0, -40), RadiusX = 330, RadiusZ = 290 },
	-- Campos da Névoa (ilhota de farm da Ilha 1, ponte a oeste; tools/gerar_expansao_ilha1.py)
	{ Id = "campos_nevoa", Region = "ilha_tutorial", Center = Vector3.new(-470, 0, -60), RadiusX = 190, RadiusZ = 230 },
	{ Id = "pilares", Region = "ilha_pilares", Center = Vector3.new(910, 0, -500), RadiusX = 320, RadiusZ = 305 },
	{ Id = "sol_partido", Region = "ilha_sol_partido", Center = Vector3.new(1700, 0, -130), RadiusX = 340, RadiusZ = 290 },
	{ Id = "kame", Region = nil, Center = Vector3.new(-450, 0, 560), RadiusX = 300, RadiusZ = 140 }, -- easter egg do dono
} :: { Island }

--- Ilha em que o ponto (x, z) está (nil = mar).
function WorldConfig.IslandAt(position: Vector3): Island?
	for _, island in WorldConfig.Islands do
		local dx = (position.X - island.Center.X) / island.RadiusX
		local dz = (position.Z - island.Center.Z) / island.RadiusZ
		if dx * dx + dz * dz <= 1 then
			return island
		end
	end
	return nil
end

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
