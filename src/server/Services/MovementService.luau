--!strict
--[[
	MovementService (servidor)
	Corrida (Shift segurado) e dash genérico (Ctrl esquerdo / botão no mobile), para todos os
	personagens. Servidor decide velocidade e cooldown; o impulso do dash é aplicado pelo dono
	da física (cliente) depois de autorizado, como nos Dash de habilidade.
	  RequestSprint(active) -> WalkSpeed = CombatConfig.Sprint.Speed (não enquanto bloqueia)
	  RequestDash()         -> cooldown CombatConfig.Dash.Cooldown -> NotifyDash(character, speed, duration)
	Atributo Sprinting no Player (CombatService usa ao soltar o block; MovementController anima).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))

local MovementService = {}

local sprintLimiter = RateLimiter.new(10, 1)
local dashLimiter = RateLimiter.new(6, 1)
local dashReadyAt: { [Player]: number } = {}
local notifyDash: RemoteEvent
local notifyCooldown: RemoteEvent

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setSprint(player: Player, active: boolean)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	if active and (not HealthService.IsAlive(player.Character) or CombatService.IsBlocking(player)) then
		active = false
	end
	if player:GetAttribute("DevSpeed") ~= nil then
		player:SetAttribute("Sprinting", active) -- só anima; velocidade é do menu dev
		return
	end
	player:SetAttribute("Sprinting", active)
	if CombatService.IsBlocking(player) then
		return -- block manda na velocidade; ao soltar, CombatService lê o atributo
	end
	humanoid.WalkSpeed = if active then CombatConfig.Sprint.Speed else CombatConfig.WalkSpeed
end

local function onRequestSprint(player: Player, active: any)
	if not sprintLimiter:Allow(player) or typeof(active) ~= "boolean" then
		return
	end
	setSprint(player, active)
end

local function onRequestDash(player: Player)
	if not dashLimiter:Allow(player) then
		return
	end
	local character = player.Character
	if not character or not HealthService.IsAlive(character) or not HealthService.CanFight(player) then
		return
	end
	local now = os.clock()
	if CombatService.IsStunned(player) or CombatService.IsBlocking(player) then
		return
	end
	local readyAt = dashReadyAt[player] or 0
	if now < readyAt and player:GetAttribute("DevNoCooldown") ~= true then
		notifyCooldown:FireClient(player, "dash", readyAt - now)
		return
	end
	local cfg = CombatConfig.Dash
	dashReadyAt[player] = now + cfg.Cooldown
	AntiExploitService.Grace(player, cfg.Duration + 0.5)
	notifyDash:FireAllClients(character, cfg.Speed, cfg.Duration)
end

function MovementService.Init()
	notifyDash = Remotes.GetEvent(Remotes.Events.NotifyDash)
	notifyCooldown = Remotes.GetEvent(Remotes.Events.NotifyCooldown)
end

function MovementService.Start()
	Remotes.GetEvent(Remotes.Events.RequestSprint).OnServerEvent:Connect(onRequestSprint)
	Remotes.GetEvent(Remotes.Events.RequestDash).OnServerEvent:Connect(onRequestDash)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Sprinting", false)
			dashReadyAt[player] = 0
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		dashReadyAt[player] = nil
	end)
	Log.debug("[MovementService] pronto (Shift corre, Ctrl dá dash)")
end

return MovementService
