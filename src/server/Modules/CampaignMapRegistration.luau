--!strict
-- Registro aditivo de região: validação extraída da Cidade Âmbar para ilhas futuras.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local WorldConfig = require(Modules.WorldConfig)
local PvpConfig = require(Modules.PvpConfig)
local WorldService = require(script.Parent.Parent.Services.WorldService)
local Registration = {}
export type Settings = { Region: string, Center: string, Spawn: string, Boss: string, Markers: { string }, FloorMarkers: { string }? }
function Registration.Bind(map: Model, settings: Settings, onRemoved: () -> ()): { [string]: BasePart }?
	local rx, rz = map:GetAttribute("FXRadiusX"), map:GetAttribute("FXRadiusZ")
	if typeof(rx) ~= "number" or typeof(rz) ~= "number" or rx ~= rx or rz ~= rz or rx <= 0 or rz <= 0 or rx >= math.huge or rz >= math.huge then return nil end
	local markers: { [string]: BasePart } = {}
	local names = { settings.Spawn, settings.Center, settings.Boss }
	for _, name in settings.Markers do table.insert(names, name) end
	for _, name in names do
		local found = map:FindFirstChild(name, true)
		if not found or not found:IsA("BasePart") or not found.Anchored then return nil end
		markers[name] = found
	end
	local center = markers[settings.Center].Position
	-- Rejeita área sobreposta às ilhas anteriores, para RegionOf continuar inequívoco.
	for _, island in WorldConfig.Islands do
		if math.abs(center.X - island.Center.X) <= rx + island.RadiusX
			and math.abs(center.Z - island.Center.Z) <= rz + island.RadiusZ then return nil end
	end
	for _, marker in markers do
		local dx, dz = (marker.Position.X - center.X) / rx, (marker.Position.Z - center.Z) / rz
		if dx * dx + dz * dz > 1 then return nil end
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, marker in markers do table.insert(exclude, marker) end
	ray.FilterDescendantsInstances, ray.RespectCanCollide = exclude, true
	local floorMarkers = { settings.Spawn, settings.Boss }
	local extraFloorMarkers: { string } = settings.FloorMarkers or {}
	for _, name in extraFloorMarkers do table.insert(floorMarkers, name) end
	for _, name in floorMarkers do
		local floor = Workspace:Raycast(markers[name].Position + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), ray)
		if not floor or floor.Normal.Y < 0.7 or (floor.Instance ~= Workspace.Terrain and not floor.Instance:IsDescendantOf(map)) then return nil end
	end
	local region = WorldConfig.Regions[settings.Region]
	if not region or region.Available then return nil end
	region.Checkpoints.chegada = { Position = markers[settings.Spawn].Position, Yaw = markers[settings.Spawn].Orientation.Y }
	local island = { Id = settings.Region, Region = settings.Region, Center = center, RadiusX = rx, RadiusZ = rz }
	local safe = { Name = region.Name .. " · chegada", Center = markers[settings.Spawn].Position, Radius = 25 }
	table.insert(WorldConfig.Islands, island)
	table.insert(PvpConfig.SafeZones, safe)
	region.Available = true
	for _, player in Players:GetPlayers() do WorldService.Refresh(player) end
	local removal: RBXScriptConnection?
	removal = map.AncestryChanged:Connect(function()
		if map:IsDescendantOf(Workspace) then return end
		if removal then removal:Disconnect() end
		region.Available, region.Checkpoints = false, {}
		for _, player in Players:GetPlayers() do WorldService.Refresh(player) end
		local i = table.find(WorldConfig.Islands, island); if i then table.remove(WorldConfig.Islands, i) end
		local j = table.find(PvpConfig.SafeZones, safe); if j then table.remove(PvpConfig.SafeZones, j) end
		onRemoved()
	end)
	return markers
end
return Registration
