--!strict
--[[
	HealthService (servidor)
	Autoridade sobre vida: vida máxima, dano, cura, morte, respawn.
	Usa o Humanoid como armazenamento (replica de graça pro cliente), mas
	TODA alteração passa por aqui. Nenhum outro script deve mexer em Humanoid.Health.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))

local respawnLimiter = RateLimiter.new(1, 1)
local timeLimiter = RateLimiter.new(2, 1)

local HealthService = {}

local ATTR_LAST_ATTACKER = "LastAttackerUserId"
local ATTR_LAST_ATTACK_TIME = "LastAttackTime"
local KILL_CREDIT_WINDOW = 8
local VOID_Y = -80 -- abaixo disso = caiu do mapa
local warnedRig = false -- segundos que o último atacante recebe crédito do kill

local notifyHealth: RemoteEvent
local notifyKill: RemoteEvent

--- Disparado no servidor quando um jogador morre: (victim: Player, killer: Player?)
HealthService.Died = Instance.new("BindableEvent")
--- Disparado a cada dano aplicado (victim: Model, amount: number, attacker: Player?). BossService usa para crédito.
HealthService.Damaged = Instance.new("BindableEvent")

--- Segundos desde a última vez que o jogador levou dano (math.huge se nunca / sem personagem).
function HealthService.SecondsSinceDamaged(player: Player): number
	local character = player.Character
	local lastHit = character and character:GetAttribute(ATTR_LAST_ATTACK_TIME)
	if typeof(lastHit) ~= "number" then
		return math.huge
	end
	return os.clock() - lastHit
end

--- Jogadores com atributo CanFight == false não dão nem recebem dano (ex.: lobby).
function HealthService.CanFight(player: Player?): boolean
	return player == nil or player:GetAttribute("CanFight") ~= false
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function getHumanoid(character: Model?): Humanoid?
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function HealthService.IsAlive(character: Model?): boolean
	local humanoid = getHumanoid(character)
	return humanoid ~= nil and humanoid.Health > 0
end

local function setupCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		warn(("[HealthService] %s spawnou sem Humanoid"):format(player.Name))
		return
	end

	if humanoid.RigType ~= Enum.HumanoidRigType.R6 and not warnedRig then
		warnedRig = true
		local StarterPlayer = game:GetService("StarterPlayer")
		local starterChar = StarterPlayer:FindFirstChild("StarterCharacter")
		local starterHum = StarterPlayer:FindFirstChild("StarterHumanoid")
		local causa = if starterChar
			then "existe um StarterPlayer.StarterCharacter (rig R15 do pack) — apague-o"
			elseif starterHum then "existe um StarterPlayer.StarterHumanoid com RigType R15 — apague-o"
			else "o CharacterService não montou o rig (ver warns acima) ou algum script do place recarregou o personagem"
		warn(("[HealthService] rig do jogador é %s; o projeto foi feito para R6 (CharacterService força R6). As animações da equipe (R6) NÃO vão tocar. Causa provável: %s."):format(humanoid.RigType.Name, causa))
	end
	humanoid.MaxHealth = CombatConfig.MaxHealth
	humanoid.Health = CombatConfig.MaxHealth
	humanoid.WalkSpeed = CombatConfig.WalkSpeed
	humanoid.BreakJointsOnDeath = false

	character:SetAttribute(ATTR_LAST_ATTACKER, nil)
	character:SetAttribute(ATTR_LAST_ATTACK_TIME, nil)

	humanoid.Died:Once(function()
		local killer: Player? = nil
		local lastId = character:GetAttribute(ATTR_LAST_ATTACKER)
		local lastTime = character:GetAttribute(ATTR_LAST_ATTACK_TIME)
		if typeof(lastId) == "number" and typeof(lastTime) == "number" and (os.clock() - lastTime) <= KILL_CREDIT_WINDOW then
			killer = Players:GetPlayerByUserId(lastId)
		end
		Log.debug(("[HealthService] %s morreu (killer: %s)"):format(player.Name, killer and killer.Name or "nenhum"))
		notifyKill:FireAllClients(killer, player)
		HealthService.Died:Fire(player, killer)
	end)

	notifyHealth:FireClient(player, humanoid.Health, humanoid.MaxHealth)
	Log.debug(("[HealthService] %s pronto: %d HP"):format(player.Name, CombatConfig.MaxHealth))
end

-- ---------------------------------------------------------------------------
-- API pública (usada por outros services)
-- ---------------------------------------------------------------------------

--- Aplica dano. Retorna o dano efetivamente aplicado (0 se alvo inválido/morto).
function HealthService.ApplyDamage(victim: Model, amount: number, attacker: Player?): number
	local humanoid = getHumanoid(victim)
	if not humanoid or humanoid.Health <= 0 or amount <= 0 then
		return 0
	end
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	if not HealthService.CanFight(attacker) or not HealthService.CanFight(victimPlayer) then
		return 0
	end
	if victimPlayer and victimPlayer:GetAttribute("Invulnerable") == true then
		return 0 -- modo deus (AdminService)
	end
	if attacker and victimPlayer and attacker ~= victimPlayer then
		-- mesmo time (Teams/duelo 2v2): sem fogo amigo
		local teamA, teamB = attacker:GetAttribute("TeamId"), victimPlayer:GetAttribute("TeamId")
		if teamA ~= nil and teamA == teamB then
			return 0
		end
	end

	local before = humanoid.Health
	humanoid.Health = math.max(0, before - amount)
	local dealt = before - humanoid.Health

	if attacker then
		victim:SetAttribute(ATTR_LAST_ATTACKER, attacker.UserId)
		victim:SetAttribute(ATTR_LAST_ATTACK_TIME, os.clock())
	end

	if victimPlayer then
		notifyHealth:FireClient(victimPlayer, humanoid.Health, humanoid.MaxHealth)
	end
	if dealt > 0 then
		HealthService.Damaged:Fire(victim, dealt, attacker)
	end

	return dealt
end

--- Cura. Retorna quanto curou de fato.
function HealthService.Heal(target: Model, amount: number): number
	local humanoid = getHumanoid(target)
	if not humanoid or humanoid.Health <= 0 or amount <= 0 then
		return 0
	end
	local before = humanoid.Health
	humanoid.Health = math.min(humanoid.MaxHealth, before + amount)
	local healed = humanoid.Health - before

	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if targetPlayer then
		notifyHealth:FireClient(targetPlayer, humanoid.Health, humanoid.MaxHealth)
	end
	return healed
end

--- Mata imediatamente (sem crédito de kill).
function HealthService.Kill(target: Model)
	local humanoid = getHumanoid(target)
	if humanoid then
		humanoid.Health = 0
	end
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function HealthService.Init()
	notifyHealth = Remotes.GetEvent(Remotes.Events.NotifyHealth)
	notifyKill = Remotes.GetEvent(Remotes.Events.NotifyKill)
	Players.RespawnTime = CombatConfig.RespawnTime
end

function HealthService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			setupCharacter(player, character)
		end)
		if player.Character then
			setupCharacter(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	-- Regeneração controlada: só depois de Regen.Delay segundos sem tomar dano
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				-- Caiu do mapa: mata (respawn normal) em vez de cair para sempre
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and humanoid and humanoid.Health > 0 and root.Position.Y < VOID_Y then
					HealthService.Kill(character :: Model)
					continue
				end
				if character and humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
					local lastHit = character:GetAttribute(ATTR_LAST_ATTACK_TIME)
					if typeof(lastHit) ~= "number" or now - lastHit >= CombatConfig.Regen.Delay then
						HealthService.Heal(character, CombatConfig.Regen.PerSecond)
					end
				end
			end
		end
	end)

	local requestRespawn = Remotes.GetEvent(Remotes.Events.RequestRespawn)
	requestRespawn.OnServerEvent:Connect(function(player)
		if not respawnLimiter:Allow(player) then
			return
		end
		-- Só permite respawn manual se estiver morto (evita "reset" como fuga de combate)
		if not HealthService.IsAlive(player.Character) then
			CharacterService.Load(player)
		end
	end)

	Remotes.GetFunction(Remotes.Functions.FetchServerTime).OnServerInvoke = function(player)
		if not timeLimiter:Allow(player) then
			return nil
		end
		return workspace:GetServerTimeNow()
	end
end

return HealthService
