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
	if not validDestination(profile.world.region, profile.world.checkpoint) then
		profile.world.region = WorldConfig.DefaultRegion
		profile.world.checkpoint = WorldConfig.DefaultCheckpoint
		profile.world.discovered[WorldConfig.DefaultRegion] = true
		DataService.MarkDirty(player)
	end
	player:SetAttribute("WorldRegion", profile.world.region)
	player:SetAttribute("WorldCheckpoint", profile.world.checkpoint)
	local cf = WorldConfig.CFrameOf(profile.world.region, profile.world.checkpoint)
	if cf then
		player:SetAttribute("WorldSpawnX", cf.X)
		player:SetAttribute("WorldSpawnY", cf.Y)
		player:SetAttribute("WorldSpawnZ", cf.Z)
		local _, yaw = cf:ToOrientation()
		player:SetAttribute("WorldSpawnYaw", math.deg(yaw))
	end
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
	return if profile then WorldConfig.CFrameOf(profile.world.region, profile.world.checkpoint) else nil
end

function WorldService.Start()
	DataService.ProfileLoaded.Event:Connect(function(player: Player)
		apply(player)
	end)
	for _, player in Players:GetPlayers() do apply(player) end
end

return WorldService
