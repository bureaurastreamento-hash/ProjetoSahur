--!strict
--[[ WorldService — região, checkpoint e descoberta persistentes de F/X. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local WorldService = {}

local function validDestination(regionId: string, checkpointId: string): boolean
	local region = WorldConfig.GetRegion(regionId)
	return region ~= nil and region.Available and WorldConfig.GetCheckpoint(regionId, checkpointId) ~= nil
end

local function apply(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local savedRegion = WorldConfig.GetRegion(profile.world.region)
	local waitingForMap = savedRegion ~= nil and not savedRegion.Available
	if not waitingForMap and not validDestination(profile.world.region, profile.world.checkpoint) then
		profile.world.region = WorldConfig.DefaultRegion
		profile.world.checkpoint = WorldConfig.DefaultCheckpoint
		profile.world.discovered[WorldConfig.DefaultRegion] = true
		DataService.MarkDirty(player)
	end
	-- Destino conhecido ainda indisponível: fallback só na sessão, sem apagar o checkpoint salvo.
	local regionId = if waitingForMap then WorldConfig.DefaultRegion else profile.world.region
	local checkpointId = if waitingForMap then WorldConfig.DefaultCheckpoint else profile.world.checkpoint
	player:SetAttribute("WorldRegion", regionId)
	player:SetAttribute("WorldCheckpoint", checkpointId)
	local cf = WorldConfig.CFrameOf(regionId, checkpointId)
	if cf then
		player:SetAttribute("WorldSpawnX", cf.X)
		player:SetAttribute("WorldSpawnY", cf.Y)
		player:SetAttribute("WorldSpawnZ", cf.Z)
		local _, yaw = cf:ToOrientation()
		player:SetAttribute("WorldSpawnYaw", math.deg(yaw))
	end
end

function WorldService.Refresh(player: Player)
	apply(player)
end

function WorldService.SetCheckpoint(player: Player, regionId: string, checkpointId: string): boolean
	local profile = DataService.GetProfile(player)
	if not profile or not validDestination(regionId, checkpointId) then return false end
	profile.world.region = regionId
	profile.world.checkpoint = checkpointId
	profile.world.discovered[regionId] = true
	DataService.MarkDirty(player)
	apply(player)
	return true
end

--- Marca a região como descoberta sem mexer no spawn salvo (portal/viagem).
function WorldService.Discover(player: Player, regionId: string)
	local profile = DataService.GetProfile(player)
	if not profile or not WorldConfig.GetRegion(regionId) or profile.world.discovered[regionId] then return end
	profile.world.discovered[regionId] = true
	DataService.MarkDirty(player)
end

function WorldService.SpawnCFrame(player: Player): CFrame?
	local profile = DataService.GetProfile(player)
	if not profile then return nil end
	if not validDestination(profile.world.region, profile.world.checkpoint) then
		return WorldConfig.CFrameOf(WorldConfig.DefaultRegion, WorldConfig.DefaultCheckpoint)
	end
	return WorldConfig.CFrameOf(profile.world.region, profile.world.checkpoint)
end

function WorldService.Start()
	DataService.ProfileLoaded.Event:Connect(function(player: Player)
		apply(player)
	end)
	for _, player in Players:GetPlayers() do apply(player) end
end

return WorldService
