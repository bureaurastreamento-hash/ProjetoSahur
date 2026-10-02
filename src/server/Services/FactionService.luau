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
local queued: { [Player]: string } = {}
local chosenThisSession: { [Player]: boolean } = {}
local function reflect(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	player:SetAttribute("FactionReady", true)
	player:SetAttribute("Faction", profile.faction)
	local required = not chosenThisSession[player] or not Config.Valid(profile.faction)
	player:SetAttribute("FactionChoiceRequired", required)
	-- Escolha por sessão; a proteção pendente não bloqueia o combate de teste no lobby.
	player:SetAttribute("FactionPending", not LaunchConfig.Locked(player) and required)
end
Service.Refresh = reflect
function Service.Choose(player: Player, id: any): boolean
	local profile = DataService.GetProfile(player)
	if player.Parent ~= Players or not profile or not Config.Valid(id) then return false end
	chosenThisSession[player] = true
	profile.faction = id
	reflect(player)
	DataService.MarkDirty(player)
	Remotes.GetEvent(Remotes.Events.NotifyFaction):FireClient(player, "chosen", { id = id, name = Config.Name(id) })
	return true
end
function Service.Init()
	Remotes.GetEvent(Remotes.Events.RequestFaction).OnServerEvent:Connect(function(player, id)
		if not limiter:Allow(player) or not Config.Valid(id) then return end
  if not DataService.GetProfile(player) then
   queued[player] = id
   Remotes.GetEvent(Remotes.Events.NotifyFaction):FireClient(player, "waiting", {})
   return
  end
  if not Service.Choose(player, id) then reflect(player) end
	end)
end
function Service.Start()
	local function waiting(player: Player)
		player:SetAttribute("FactionReady", false)
		player:SetAttribute("FactionChoiceRequired", true)
		player:SetAttribute("FactionPending", not LaunchConfig.Locked(player))
		reflect(player)
	end
	Players.PlayerAdded:Connect(waiting)
	DataService.ProfileLoaded.Event:Connect(function(player)
  reflect(player)
  local id = queued[player];queued[player] = nil
  if id then Service.Choose(player,id) end
 end)
 Players.PlayerRemoving:Connect(function(player) queued[player] = nil; chosenThisSession[player] = nil end)
	for _, player in Players:GetPlayers() do waiting(player) end
end
return Service
