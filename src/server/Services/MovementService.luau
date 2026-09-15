--!strict
--[[
	MovementService (servidor)
	Corrida automática ao andar para a frente (cliente decide a direção; botão CORRER no mobile força).
	  RequestSprint(active) -> WalkSpeed = CombatConfig.Sprint.Speed (não enquanto bloqueia)
	Atributo Sprinting no Player: CombatService lê ao soltar o block; MovementController anima.
	Dash/teleporte são habilidades de personagem no Q (AbilityService), não existe dash genérico.
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

local MovementService = {}

local sprintLimiter = RateLimiter.new(10, 1)

local function setSprint(player: Player, active: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if active and (not HealthService.IsAlive(character) or CombatService.IsBlocking(player)) then
		active = false
	end
	player:SetAttribute("Sprinting", active)
	if player:GetAttribute("DevSpeed") ~= nil then
		return -- só anima; a velocidade é do menu dev
	end
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

function MovementService.Start()
	Remotes.GetEvent(Remotes.Events.RequestSprint).OnServerEvent:Connect(onRequestSprint)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Sprinting", false)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Log.debug("[MovementService] pronto (corrida automática para a frente)")
end

return MovementService
