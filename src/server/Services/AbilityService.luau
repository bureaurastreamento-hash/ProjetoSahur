--!strict
--[[
	AbilityService (servidor)
	Autoridade sobre personagem escolhido, energia, cooldowns e efeito de cada
	habilidade. O cliente só envia RequestAbility(slot) e RequestSelectCharacter(id).

	Replicação de estado (para HUD): atributos no Player
	  "CharacterId" (string), "Energy" (number)
	Cooldowns vão por NotifyAbilityCooldown(slot, abilityId, readyAtServerTime),
	usando workspace:GetServerTimeNow() para o cliente contar sozinho.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local Hitbox = require(Modules:WaitForChild("Hitbox"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))

local AbilityService = {}

type PlayerState = {
	characterId: string,
	energy: number,
	cooldownReadyAt: { [string]: number }, -- abilityId -> os.clock()
	busyUntil: number,
	damageMultiplier: number,
	damageMultiplierUntil: number,
}

local states: { [Player]: PlayerState } = {}

local notifyAbility: RemoteEvent
local notifyAbilityCooldown: RemoteEvent
local notifyAbilityDenied: RemoteEvent

local MAX_AREA_TARGETS = 8
local abilityLimiter = RateLimiter.new(8, 1)
local selectLimiter = RateLimiter.new(2, 1)

-- ---------------------------------------------------------------------------
-- Estado
-- ---------------------------------------------------------------------------

local function newState(characterId: string?): PlayerState
	return {
		characterId = characterId or CharacterDefs.DefaultCharacter,
		energy = 0,
		cooldownReadyAt = {},
		busyUntil = 0,
		damageMultiplier = 1,
		damageMultiplierUntil = 0,
	}
end

local function getState(player: Player): PlayerState
	local existing = states[player]
	if existing then
		return existing
	end
	local s = newState()
	states[player] = s
	player:SetAttribute("CharacterId", s.characterId)
	player:SetAttribute("Energy", s.energy)
	return s
end

local function setEnergy(player: Player, value: number)
	local state = getState(player)
	state.energy = math.clamp(value, 0, CharacterDefs.Energy.Max)
	player:SetAttribute("Energy", state.energy)
end

--- Chamado por CombatService quando um acerto causou dano.
function AbilityService.OnHitDealt(attacker: Player, victim: Player?)
	setEnergy(attacker, getState(attacker).energy + CharacterDefs.Energy.GainOnHitDealt)
	if victim then
		setEnergy(victim, getState(victim).energy + CharacterDefs.Energy.GainOnHitTaken)
	end
end

function AbilityService.GetDamageMultiplier(player: Player): number
	local state = states[player]
	if not state or os.clock() > state.damageMultiplierUntil then
		return 1
	end
	return state.damageMultiplier
end

-- ---------------------------------------------------------------------------
-- Efeitos
-- ---------------------------------------------------------------------------

local function areaHit(player: Player, character: Model, effect: CharacterDefs.Effect, damage: number)
	for _, victim in Hitbox.Around(character, effect.Radius, MAX_AREA_TARGETS) do
		CombatService.ResolveHit(player, character, victim, damage, false, effect.Knockback)
		local stunSeconds = effect.StunSeconds
		if typeof(stunSeconds) == "number" then
			local victimPlayer = Players:GetPlayerFromCharacter(victim)
			if victimPlayer then
				CombatService.Stun(victimPlayer, stunSeconds, "stunned")
			end
		end
	end
end

local function stillValid(player: Player, character: Model): boolean
	return player.Parent == Players and player.Character == character and HealthService.IsAlive(character)
end

local effects: { [string]: (Player, Model, CharacterDefs.AbilityDef) -> () } = {}

-- Movimento é feito no cliente (dono da física); dano checado aqui, amostrando a
-- hitbox várias vezes durante o dash (cada alvo é atingido no máximo uma vez).
local DASH_SAMPLE_INTERVAL = 0.05
effects.Dash = function(player, character, ability)
	local e = ability.Effect
	AntiExploitService.Grace(player, e.Duration + 0.5)
	notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "start", {
		Speed = e.Speed,
		Duration = e.Duration,
	})
	task.spawn(function()
		local hitAlready: { [Model]: boolean } = {}
		local endsAt = os.clock() + e.Duration + DASH_SAMPLE_INTERVAL
		while os.clock() < endsAt do
			if not stillValid(player, character) or CombatService.IsStunned(player) then
				return
			end
			for _, victim in Hitbox.InFront(character, e.Range, e.Width, e.Height, MAX_AREA_TARGETS) do
				if not hitAlready[victim] then
					hitAlready[victim] = true
					CombatService.ResolveHit(player, character, victim, e.Damage, false)
					notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "hit")
				end
			end
			task.wait(DASH_SAMPLE_INTERVAL)
		end
	end)
end

effects.Teleport = function(player, character, ability)
	local e = ability.Effect
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	AntiExploitService.Grace(player, 1)
	local direction = root.CFrame.LookVector * e.Distance
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(root.Position, direction, params)
	local distance = if hit then math.max(0, hit.Distance - 2) else e.Distance
	root.CFrame = root.CFrame + root.CFrame.LookVector * distance
	notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "start")
end

effects.AreaDamage = function(player, character, ability)
	local e = ability.Effect
	notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "start")
	task.delay(e.Delay, function()
		if not stillValid(player, character) or CombatService.IsStunned(player) then
			return
		end
		areaHit(player, character, e, e.Damage)
		notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "hit")
	end)
end

effects.MultiHitArea = function(player, character, ability)
	local e = ability.Effect
	notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "start")
	task.spawn(function()
		for i = 1, e.Hits do
			task.wait(e.Interval)
			if not stillValid(player, character) or CombatService.IsStunned(player) then
				return
			end
			areaHit(player, character, e, e.Damage)
			notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "hit", { Index = i })
		end
		notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "end")
	end)
end

effects.DamageBuff = function(player, character, ability)
	local e = ability.Effect
	local state = getState(player)
	state.damageMultiplier = e.Multiplier
	state.damageMultiplierUntil = os.clock() + e.Duration
	notifyAbility:FireAllClients(character, state.characterId, ability.Id, "start", { Duration = e.Duration })
end

-- ---------------------------------------------------------------------------
-- Requests
-- ---------------------------------------------------------------------------

local function deny(player: Player, slot: number, reason: string)
	Log.debug(("[AbilityService] %s slot %d negado: %s"):format(player.Name, slot, reason))
	notifyAbilityDenied:FireClient(player, slot, reason)
end

local function onRequestAbility(player: Player, slot: any)
	if not abilityLimiter:Allow(player) then
		return
	end
	local state = getState(player)
	local now = os.clock()

	if typeof(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > 8 then
		return
	end

	local ability = CharacterDefs.GetAbility(state.characterId, slot)
	if not ability then
		return deny(player, slot, "no_ability")
	end
	local character = player.Character
	if not character or not HealthService.IsAlive(character) then
		return deny(player, slot, "dead")
	end
	if not HealthService.CanFight(player) then
		return deny(player, slot, "cant_fight")
	end
	if CombatService.IsStunned(player) then
		return deny(player, slot, "stunned")
	end
	if now < state.busyUntil then
		return deny(player, slot, "busy")
	end
	local readyAt = state.cooldownReadyAt[ability.Id] or 0
	if now < readyAt then
		return deny(player, slot, "cooldown")
	end
	if state.energy < ability.EnergyCost then
		return deny(player, slot, "energy")
	end
	local handler = effects[ability.Effect.Type]
	if not handler then
		warn(("[AbilityService] efeito '%s' sem handler (habilidade %s)"):format(ability.Effect.Type, ability.Id))
		return deny(player, slot, "no_handler")
	end

	-- Tudo validado: cobra antes de executar
	setEnergy(player, state.energy - ability.EnergyCost)
	state.cooldownReadyAt[ability.Id] = now + ability.Cooldown
	state.busyUntil = now + ability.CastTime
	notifyAbilityCooldown:FireClient(player, slot, ability.Id, Workspace:GetServerTimeNow() + ability.Cooldown)

	Log.debug(("[AbilityService] %s usou %s.%s (energia restante %d)"):format(player.Name, state.characterId, ability.Id, state.energy))

	local ok, err = pcall(handler :: any, player, character, ability)
	if not ok then
		warn(("[AbilityService] erro em %s: %s"):format(ability.Id, tostring(err)))
	end
end

local function onRequestSelectCharacter(player: Player, characterId: any)
	if not selectLimiter:Allow(player) then
		return
	end
	if typeof(characterId) ~= "string" or not CharacterDefs.Get(characterId) then
		return
	end
	local state = getState(player)
	if state.characterId == characterId then
		return
	end
	if player:GetAttribute("InMatch") == true then
		return -- troca só fora do round
	end
	if not DataService.HasCharacter(player, characterId) then
		Remotes.GetEvent(Remotes.Events.NotifyUnlockDenied):FireClient(player, characterId, "locked")
		return
	end
	state.characterId = characterId
	state.cooldownReadyAt = {}
	state.damageMultiplierUntil = 0
	player:SetAttribute("CharacterId", characterId)
	Log.debug(("[AbilityService] %s agora é %s"):format(player.Name, characterId))
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function AbilityService.Init()
	notifyAbility = Remotes.GetEvent(Remotes.Events.NotifyAbility)
	notifyAbilityCooldown = Remotes.GetEvent(Remotes.Events.NotifyAbilityCooldown)
	notifyAbilityDenied = Remotes.GetEvent(Remotes.Events.NotifyAbilityDenied)
end

function AbilityService.Start()
	Remotes.GetEvent(Remotes.Events.RequestAbility).OnServerEvent:Connect(onRequestAbility)
	Remotes.GetEvent(Remotes.Events.RequestSelectCharacter).OnServerEvent:Connect(onRequestSelectCharacter)

	local function onPlayer(player: Player)
		getState(player)
		player.CharacterAdded:Connect(function()
			-- Respawn mantém o personagem escolhido, zera energia/cooldowns/buffs
			local prev = getState(player)
			states[player] = newState(prev.characterId)
			player:SetAttribute("Energy", 0)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return AbilityService
