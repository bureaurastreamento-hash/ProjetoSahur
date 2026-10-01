--!strict
local Players = game:GetService("Players")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local Config = require(Modules.FactionConfig)
local LaunchConfig = require(Modules.LaunchConfig)
local Remotes = require(Modules.RemoteEvents)
local RateLimiter = require(Modules.RateLimiter)
local DataService = require(script.Parent.DataService)
local limiter = RateLimiter.new(2, 1)
local Service = {}
local function reflect(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	player:SetAttribute("Faction", profile.faction)
	-- pré-lançamento: sem menu de facção no lobby (pendente = sem dano, e o lobby é para testar o combate)
	player:SetAttribute("FactionPending", not LaunchConfig.Locked(player) and not Config.Valid(profile.faction))
end
Service.Refresh = reflect
function Service.Choose(player: Player, id: any): boolean
	local profile = DataService.GetProfile(player)
	if player.Parent ~= Players or not profile or not Config.Valid(id) or Config.Valid(profile.faction) then return false end
	profile.faction = id
	reflect(player)
	DataService.MarkDirty(player)
	Remotes.GetEvent(Remotes.Events.NotifyFaction):FireClient(player, "chosen", { id = id, name = Config.Name(id) })
	return true
end
function Service.Init()
	Remotes.GetEvent(Remotes.Events.RequestFaction).OnServerEvent:Connect(function(player, id)
		if limiter:Allow(player) then Service.Choose(player, id) end
	end)
end
function Service.Start()
	local function waiting(player: Player)
		player:SetAttribute("FactionPending", not LaunchConfig.Locked(player))
		reflect(player)
	end
	Players.PlayerAdded:Connect(waiting)
	DataService.ProfileLoaded.Event:Connect(reflect)
	for _, player in Players:GetPlayers() do waiting(player) end
end
return Service
