--!strict
-- Usa o crédito autoritativo de HealthService; não há Request de bounty do cliente.
local Players = game:GetService("Players")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local Config = require(Modules.BountyConfig)
local Remotes = require(Modules.RemoteEvents)
local DataService = require(script.Parent.DataService)
local HealthService = require(script.Parent.HealthService)
local BountyService = {}
local function reflect(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	player:SetAttribute("Bounty", profile.bounty.points)
	player:SetAttribute("BountyTitle", Config.Title(profile.bounty.points))
end
function BountyService.OnDeath(victim: Player, killer: Player?, eligible: boolean?, openWorld: boolean?): boolean
	if eligible ~= true or openWorld ~= true or not killer or killer == victim then return false end
	if killer.Parent ~= Players or victim.Parent ~= Players then return false end
	local profile, target = DataService.GetProfile(killer), DataService.GetProfile(victim)
	if not profile or not target or math.abs(profile.level - target.level) > Config.MaxLevelGap then return false end
	local now = os.time()
	local state = Config.Normalize(profile.bounty, now)
	local key = tostring(victim.UserId)
	if state.recentVictims[key] then return false end
	local count = 0
	for _ in state.recentVictims do count += 1 end
	-- Não expulsar entradas ainda válidas: isso permitiria repetir alvos ao encher a lista.
	if count >= Config.MaxRecentVictims then return false end
	state.recentVictims[key] = now
	local gain = math.min(Config.KillGain, Config.MaxPoints - state.points)
	state.points += gain
	profile.bounty = state
	local bonus = Config.DefeatBonus(target.bounty.points)
	reflect(killer)
	-- A moeda e a bounty ficam no mesmo perfil/snapshot; nenhuma escrita no perfil do derrotado.
	if bonus > 0 then bonus = DataService.RewardCoins(killer, bonus) else DataService.MarkDirty(killer) end
	Remotes.GetEvent(Remotes.Events.NotifyProgression):FireClient(killer, "bounty", {
		gain = gain, points = state.points, title = Config.Title(state.points), coins = bonus,
	})
	return true
end
function BountyService.Start()
	DataService.ProfileLoaded.Event:Connect(reflect)
	for _, player in Players:GetPlayers() do reflect(player) end
	HealthService.Died.Event:Connect(BountyService.OnDeath)
end
return BountyService
