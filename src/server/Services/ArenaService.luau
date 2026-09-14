--!strict
--[[
	ArenaService (servidor)
	Rotação de mapas e pontos de spawn.
	Mapas: Models em ServerStorage.Maps (pasta gerenciada pelo Rojo a partir de
	src/maps/, com ignoreUnknownInstances para a equipe de arte adicionar mapas
	direto no Studio). Cada mapa deve ter uma Folder "Spawns" com BaseParts.
	O mapa ativo é clonado em Workspace.CurrentMap.
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ArenaService = {}

local CURRENT_MAP_NAME = "CurrentMap"
local SPAWNS_FOLDER = "Spawns"
local SPAWN_HEIGHT_OFFSET = Vector3.new(0, 3, 0)

local mapsFolder: Folder
local rotation: { Model } = {}
local rotationIndex = 0
local current: Model? = nil

local function refreshRotation()
	rotation = {}
	for _, child in mapsFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(rotation, child)
		end
	end
	table.sort(rotation, function(a, b)
		return a.Name < b.Name
	end)
end

--- Nomes dos mapas disponíveis.
function ArenaService.GetMapNames(): { string }
	refreshRotation()
	local names = {}
	for _, m in rotation do
		table.insert(names, m.Name)
	end
	return names
end

--- Descarrega o mapa atual (se houver).
function ArenaService.Unload()
	if current then
		current:Destroy()
		current = nil
	end
	local stray = Workspace:FindFirstChild(CURRENT_MAP_NAME)
	if stray then
		stray:Destroy()
	end
end

--- Carrega o próximo mapa da rotação (ou um específico por nome). Retorna o Model ou nil.
function ArenaService.LoadNextMap(mapName: string?): Model?
	ArenaService.Unload()
	refreshRotation()
	if #rotation == 0 then
		warn("[ArenaService] nenhum mapa em ServerStorage.Maps")
		return nil
	end

	local template: Model? = nil
	if mapName then
		template = mapsFolder:FindFirstChild(mapName) :: Model?
	end
	if not template then
		rotationIndex = (rotationIndex % #rotation) + 1
		template = rotation[rotationIndex]
	end
	assert(template, "template nil")

	local map = template:Clone()
	map.Name = CURRENT_MAP_NAME
	map:SetAttribute("MapName", template.Name)
	map.Parent = Workspace
	current = map

	-- TODO(launch): reduzir log
	print(("[ArenaService] mapa carregado: %s (%d spawns)"):format(template.Name, #ArenaService.GetSpawnCFrames()))
	return map
end

function ArenaService.GetCurrentMap(): Model?
	return current
end

function ArenaService.GetCurrentMapName(): string?
	return if current then current:GetAttribute("MapName") :: string? else nil
end

--- CFrames de spawn do mapa atual, ordenados por nome. Fallback: pivot do mapa.
function ArenaService.GetSpawnCFrames(): { CFrame }
	local result: { CFrame } = {}
	if not current then
		return result
	end
	local folder = current:FindFirstChild(SPAWNS_FOLDER)
	if folder then
		local parts: { BasePart } = {}
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
		table.sort(parts, function(a, b)
			return a.Name < b.Name
		end)
		for _, part in parts do
			table.insert(result, CFrame.new(part.Position + SPAWN_HEIGHT_OFFSET))
		end
	end
	if #result == 0 then
		warn("[ArenaService] mapa sem pasta Spawns; usando o pivot do mapa")
		table.insert(result, current:GetPivot() + SPAWN_HEIGHT_OFFSET)
	end
	return result
end

--- Distribui spawns para N jogadores: embaralha e cicla se faltar spawn.
function ArenaService.AllocateSpawns(count: number): { CFrame }
	local spawns = ArenaService.GetSpawnCFrames()
	local out: { CFrame } = {}
	if #spawns == 0 then
		return out
	end
	local order = table.clone(spawns)
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for i = 1, count do
		table.insert(out, order[((i - 1) % #order) + 1])
	end
	return out
end

function ArenaService.Init()
	mapsFolder = ServerStorage:WaitForChild("Maps") :: Folder
	ArenaService.Unload()
	refreshRotation()
	-- TODO(launch): reduzir log
	print(("[ArenaService] %d mapa(s): %s"):format(#rotation, table.concat(ArenaService.GetMapNames(), ", ")))
end

return ArenaService
