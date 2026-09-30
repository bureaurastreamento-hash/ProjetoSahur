--!strict
-- Zonas por posição real; não usa WorldRegion (que representa o checkpoint salvo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Config = require(Modules.PvpConfig)
local DataService = require(script.Parent.DataService)

local PvpService = {}
local combat: { [Player]: number } = {}
local protection: { [Player]: number } = {}
local rewarded: { [string]: number } = {}

function PvpService.SafeZone(player: Player): string?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return nil end
	for _, zone in Config.SafeZones do
		if (root.Position - zone.Center).Magnitude <= zone.Radius then return zone.Name end
	end
	local shop = workspace:FindFirstChild("Lojinha")
	if shop and shop:IsA("Model") then
		local spot = shop:FindFirstChild("VendedorSpot", true)
		local position = if spot and spot:IsA("BasePart") then spot.Position else shop:GetPivot().Position
		if (root.Position - position).Magnitude <= 25 then return "Loja" end
	end
	return nil
end

-- Capturar antes de FighterDied: duelos/guerras podem limpar seus atributos nesse evento.
function PvpService.OpenWorldKill(victim: Player, killer: Player?): boolean
	if not killer or killer == victim then return false end
	for _, player in { victim, killer } do
		if player:GetAttribute("InMatch") == true or player:GetAttribute("Tournament") == true
			or player:GetAttribute("DuelId") ~= nil or player:GetAttribute("WarId") ~= nil
			or PvpService.SafeZone(player) then return false end
	end
	return true
end

function PvpService.CanDamage(attacker: Player, victim: Player): boolean
	if attacker == victim then return true end
	for _, attribute in { "DuelId", "WarId" } do
		local match = attacker:GetAttribute(attribute)
		if match ~= nil and victim:GetAttribute(attribute) == match then return true end
	end
	if PvpService.SafeZone(attacker) or PvpService.SafeZone(victim) then return false end
	local now = os.clock()
	return (protection[attacker] or 0) <= now and (protection[victim] or 0) <= now
end

function PvpService.RecordHit(attacker: Player, victim: Player)
	if attacker == victim then return end
	local untilTime = os.clock() + Config.CombatSeconds
	for _, player in { attacker, victim } do
		combat[player] = untilTime
		player:SetAttribute("PvpCombatUntil", workspace:GetServerTimeNow() + Config.CombatSeconds)
	end
end

-- Chamada uma vez por morte; o resultado é compartilhado por XP, moedas e streak.
function PvpService.OnDeath(victim: Player, killer: Player?): boolean
	combat[victim] = nil
	victim:SetAttribute("PvpCombatUntil", nil)
	if killer and killer ~= victim then protection[victim] = os.clock() + Config.RespawnProtection end
	if not killer or killer == victim then return false end
	local killerLevel, victimLevel = killer:GetAttribute("Level"), victim:GetAttribute("Level")
	if typeof(killerLevel) ~= "number" or typeof(victimLevel) ~= "number" then return false end
	if not Config.LevelsRewardable(killerLevel, victimLevel) then return false end
	local key = tostring(killer.UserId) .. ":" .. tostring(victim.UserId)
	if (rewarded[key] or 0) > os.clock() then return false end
	rewarded[key] = os.clock() + Config.RepeatRewardSeconds
	return true
end

function PvpService.Init()
	DataService.BeforeLeave = function(player: Player, profile)
		if (combat[player] or 0) <= os.clock() then return end
		local penalty = math.min(Config.LogoutCoinCap, math.floor(profile.coins * Config.LogoutCoinFraction))
		profile.coins -= penalty
		combat[player] = nil
	end
end

function PvpService.Start()
	local function onPlayer(player: Player)
		if player.Character then protection[player] = os.clock() + Config.RespawnProtection end
		player.CharacterAdded:Connect(function()
			-- Proteção após spawn não dá direito de atacar outro player até expirar.
			protection[player] = os.clock() + Config.RespawnProtection
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do onPlayer(player) end
	Players.PlayerRemoving:Connect(function(player)
		-- O marcador de combate é limpo pelo BeforeLeave, antes do save, sem depender da ordem dos eventos.
		protection[player] = nil
		task.delay(Config.CombatSeconds + 1, function() combat[player] = nil end)
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				player:SetAttribute("SafeZone", PvpService.SafeZone(player))
				player:SetAttribute("PvpProtected", (protection[player] or 0) > os.clock())
			end
			for key, expires in rewarded do if expires <= os.clock() then rewarded[key] = nil end end
		end
	end)
end

return PvpService
