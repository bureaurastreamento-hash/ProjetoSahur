--!strict
--[[
	AbilityService (servidor)
	Autoridade sobre personagem escolhido, carga da ult, cooldowns e efeito de cada
	habilidade (slots 1..4 = teclas 1/2/3/4; G = ultimate). O dash universal (Q) é do MovementService.
	O cliente só envia RequestAbility(slot, direção) e RequestSelectCharacter(id).

	Ultimate (G, CombatConfig.Awakening): com a carga cheia, RequestAwaken zera a carga, liga o modo
	Awakening por Duration s (+dano, +velocidade, aura por NotifyAbility "Awakening") e dispara na hora a
	ultimate do personagem (a Ability com EnergyCost = Max, sempre a última da lista). Slots 1..4 = só
	habilidades normais.

	Replicação de estado (para HUD): atributos no Player
	  "CharacterId" (string), "Energy" (number), "AwakenedUntil" (number, GetServerTimeNow; 0 = fora)
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
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local Hitbox = require(Modules:WaitForChild("Hitbox"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))
local AdminService = require(script.Parent:WaitForChild("AdminService"))

local AbilityService = {}

type PlayerState = {
	characterId: string,
	energy: number,
	cooldownReadyAt: { [string]: number }, -- abilityId -> os.clock()
	busyUntil: number,
	damageMultiplier: number,
	damageMultiplierUntil: number,
	incomingMultiplier: number,
	incomingMultiplierUntil: number,
	awakenedUntil: number, -- os.clock()
}

local states: { [Player]: PlayerState } = {}

local notifyAbility: RemoteEvent
local notifyAbilityCooldown: RemoteEvent
local notifyAbilityDenied: RemoteEvent

local MAX_AREA_TARGETS = 8
local abilityLimiter = RateLimiter.new(8, 1)
local selectLimiter = RateLimiter.new(2, 1)
local awakenLimiter = RateLimiter.new(3, 1)
local ATTR_AWAKENED_UNTIL = "AwakenedUntil"

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
		incomingMultiplier = 1,
		incomingMultiplierUntil = 0,
		awakenedUntil = 0,
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

-- Flags do menu de desenvolvedor (atributos no Player, definidos por AdminService)
local ATTR_INFINITE_ENERGY = "DevInfiniteEnergy"
local ATTR_NO_COOLDOWN = "DevNoCooldown"

local function setEnergy(player: Player, value: number)
	local state = getState(player)
	if player:GetAttribute(ATTR_INFINITE_ENERGY) == true then
		value = CharacterDefs.Energy.Max
	end
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

--- Energia por golpe recebido de um NPC (boss); o atacante não é Player.
function AbilityService.OnHitTaken(victim: Player)
	setEnergy(victim, getState(victim).energy + CharacterDefs.Energy.GainOnHitTaken)
end

--- Carga extra por parry.
function AbilityService.OnParry(player: Player)
	setEnergy(player, getState(player).energy + CombatConfig.Awakening.ChargeOnParry)
end

function AbilityService.IsAwakened(player: Player): boolean
	local state = states[player]
	return state ~= nil and os.clock() < state.awakenedUntil
end

function AbilityService.GetDamageMultiplier(player: Player): number
	local state = states[player]
	if not state then
		return 1
	end
	local mult = if os.clock() > state.damageMultiplierUntil then 1 else state.damageMultiplier
	if os.clock() < state.awakenedUntil then
		mult *= CombatConfig.Awakening.DamageMultiplier
	end
	return mult
end

--- Multiplicador de WalkSpeed (Awakening). CombatService.RestoreWalkSpeed aplica.
function AbilityService.GetSpeedMultiplier(player: Player): number
	return if AbilityService.IsAwakened(player) then CombatConfig.Awakening.SpeedMultiplier else 1
end

--- Multiplicador de dano RECEBIDO (escudo). 1 = normal.
function AbilityService.GetIncomingMultiplier(player: Player): number
	local state = states[player]
	if not state or os.clock() > state.incomingMultiplierUntil then
		return 1
	end
	return state.incomingMultiplier
end

-- ---------------------------------------------------------------------------
-- Efeitos
-- ---------------------------------------------------------------------------

--- Ponto central de um efeito de área: o lançador, ou `Offset` studs à frente dele.
local function areaCenter(character: Model, effect: CharacterDefs.Effect): Vector3?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local offset = effect.Offset
	if typeof(offset) == "number" and offset > 0 then
		local look = root.CFrame.LookVector
		return root.Position + Vector3.new(look.X, 0, look.Z).Unit * offset
	end
	return root.Position
end

local function areaHit(player: Player, character: Model, effect: CharacterDefs.Effect, damage: number, center: Vector3?)
	local victims: { Model }
	if center then
		victims = Hitbox.AroundPoint(character, center, effect.Radius, MAX_AREA_TARGETS)
	else
		victims = Hitbox.Around(character, effect.Radius, MAX_AREA_TARGETS)
	end
	for _, victim in victims do
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

-- direction = horizontal unitária pedida pelo cliente (WASD), já validada; frente do HRP se não veio
local effects: { [string]: (Player, Model, CharacterDefs.AbilityDef, Vector3) -> () } = {}

local function facing(character: Model): Vector3
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			return flat.Unit
		end
	end
	return Vector3.new(0, 0, -1)
end

local function sanitizeDirection(character: Model, raw: any): Vector3
	if typeof(raw) == "Vector3" then
		local flat = Vector3.new(raw.X, 0, raw.Z)
		if flat.Magnitude > 0.5 and flat.Magnitude < 1.5 and flat.X == flat.X and flat.Z == flat.Z then
			return flat.Unit
		end
	end
	return facing(character)
end

-- Movimento é feito no cliente (dono da física); dano checado aqui, amostrando a
-- hitbox várias vezes durante o dash (cada alvo é atingido no máximo uma vez).
local DASH_SAMPLE_INTERVAL = 0.05
effects.Dash = function(player, character, ability, direction)
	local e = ability.Effect
	local maxDuration = e.Duration * CharacterDefs.DashTuning.ForwardScale
	AntiExploitService.Grace(player, maxDuration + 1.0)
	notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "start", {
		Speed = e.Speed,
		Duration = e.Duration,
		Direction = direction,
	})
	task.spawn(function()
		local hitAlready: { [Model]: boolean } = {}
		local endsAt = os.clock() + maxDuration + DASH_SAMPLE_INTERVAL
		while os.clock() < endsAt do
			if not stillValid(player, character) or CombatService.IsStunned(player) then
				return
			end
			-- o dash é dirigível no cliente: a caixa segue a velocidade real, não a frente do boneco
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local vel = if root then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z) else Vector3.zero
			local dir = if vel.Magnitude > 5 then vel.Unit else direction
			for _, victim in Hitbox.InDirection(character, dir, e.Range, e.Width, e.Height, MAX_AREA_TARGETS) do
				if not hitAlready[victim] then
					hitAlready[victim] = true
					CombatService.ResolveHit(player, character, victim, e.Damage, false)
					local victimPlayer = Players:GetPlayerFromCharacter(victim)
					if victimPlayer and typeof(e.StunSeconds) == "number" then
						CombatService.Stun(victimPlayer, e.StunSeconds, "stunned")
					end
					notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "hit")
				end
			end
			task.wait(DASH_SAMPLE_INTERVAL)
		end
	end)
end

-- Agarrão: investida curta (como Dash) e, ao encostar no 1º alvo, SEGURA ele por Carry s (a vítima
-- fica em stun duro e segue o atacante no cliente dela; o atacante ganha super armor: não pode ser
-- interrompido) e solta com o golpe final (Damage + Knockback/ragdoll). Sem alvo = só a investida.
local GRAB_OFFSET = 3 -- studs à frente do atacante onde a vítima fica presa
effects.Grab = function(player, character, ability, direction)
	local e = ability.Effect
	local characterId = getState(player).characterId
	local maxDuration = e.Duration * CharacterDefs.DashTuning.ForwardScale
	AntiExploitService.Grace(player, maxDuration + e.Carry + 1.0)
	CombatService.SetSuperArmor(player, maxDuration + e.Carry + 0.2)
	notifyAbility:FireAllClients(character, characterId, ability.Id, "start", {
		Speed = e.Speed,
		Duration = e.Duration,
		Direction = direction,
	})
	task.spawn(function()
		local endsAt = os.clock() + maxDuration + DASH_SAMPLE_INTERVAL
		local caught: Model? = nil
		while os.clock() < endsAt and not caught do
			if not stillValid(player, character) then
				return
			end
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local vel = if root then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z) else Vector3.zero
			local dir = if vel.Magnitude > 5 then vel.Unit else direction
			caught = Hitbox.InDirection(character, dir, e.Range, e.Width, e.Height, 1)[1]
			if not caught then
				task.wait(DASH_SAMPLE_INTERVAL)
			end
		end
		if not caught then
			return
		end
		local victim = caught :: Model
		local victimPlayer = Players:GetPlayerFromCharacter(victim)
		if victimPlayer then
			CombatService.CancelBlock(victimPlayer)
			CombatService.Stun(victimPlayer, e.Carry + 0.3, "grabbed")
			AntiExploitService.Grace(victimPlayer, e.Carry + 1.5)
		end
		notifyAbility:FireAllClients(character, characterId, ability.Id, "grab", { Victim = victim, Carry = e.Carry, Offset = GRAB_OFFSET })
		task.wait(e.Carry)
		if not stillValid(player, character) or not HealthService.IsAlive(victim) then
			notifyAbility:FireAllClients(character, characterId, ability.Id, "release", { Victim = victim })
			return
		end
		-- golpe final: a vítima está colada; ResolveHit sem parry (está presa)
		CombatService.ResolveHit(player, character, victim, e.Damage, false, e.Knockback, { BreaksBlock = true })
		if victimPlayer and typeof(e.StunSeconds) == "number" then
			CombatService.Stun(victimPlayer, e.StunSeconds, "stunned")
		end
		notifyAbility:FireAllClients(character, characterId, ability.Id, "hit", { Victim = victim })
	end)
end

effects.Teleport = function(player, character, ability, direction)
	local e = ability.Effect
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	AntiExploitService.Grace(player, 1)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(root.Position, direction * e.Distance, params)
	local distance = if hit then math.max(0, hit.Distance - 2) else e.Distance
	root.CFrame = root.CFrame + direction * distance
	notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "start", { Teleported = true })
end

effects.AreaDamage = function(player, character, ability)
	local e = ability.Effect
	-- Com Offset o ponto é travado no momento do cast (o alvo vê onde vai cair e pode sair)
	local center = if typeof(e.Offset) == "number" then areaCenter(character, e) else nil
	notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "start", { Position = center })
	task.delay(e.Delay, function()
		if not stillValid(player, character) or CombatService.IsStunned(player) then
			return
		end
		areaHit(player, character, e, e.Damage, center)
		notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "hit", { Position = center })
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

effects.Heal = function(player, character, ability)
	local e = ability.Effect
	local healed = HealthService.Heal(character, e.Amount)
	notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "start", { Healed = healed })
end

-- Projétil simulado no servidor: esfera anchored avança por Heartbeat e acerta o
-- primeiro personagem (ou parede) no caminho. A parte é o visual mínimo; o VFX
-- de impacto vai pelo NotifyAbility "hit" com a posição.
local PROJECTILE_FOLDER_NAME = "Projectiles"
local function projectileFolder(): Folder
	local existing = Workspace:FindFirstChild(PROJECTILE_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = PROJECTILE_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

effects.Projectile = function(player, character, ability)
	local e = ability.Effect
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local characterId = getState(player).characterId
	local direction = root.CFrame.LookVector
	local origin = root.Position + direction * 3 + Vector3.new(0, 0.5, 0)

	local bolt = Instance.new("Part")
	bolt.Name = ability.Id
	bolt.Shape = Enum.PartType.Ball
	bolt.Size = Vector3.new(1.6, 1.6, 1.6)
	bolt.Material = Enum.Material.Neon
	bolt.Color = Color3.fromRGB(120, 200, 255)
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanQuery = false
	bolt.CanTouch = false
	bolt.CastShadow = false
	bolt.CFrame = CFrame.new(origin, origin + direction)
	local glow = Instance.new("PointLight")
	glow.Color = bolt.Color
	glow.Range = 10
	glow.Brightness = 1.5
	glow.Parent = bolt
	local folder = projectileFolder()
	bolt.Parent = folder

	notifyAbility:FireAllClients(character, characterId, ability.Id, "start")

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character, folder }

	task.spawn(function()
		local travelled = 0
		local position = origin
		local function finish(hitPosition: Vector3, victim: Model?)
			bolt:Destroy()
			if victim and stillValid(player, character) then
				CombatService.ResolveHit(player, character, victim, e.Damage, false, e.Knockback)
			end
			notifyAbility:FireAllClients(character, characterId, ability.Id, "hit", { Position = hitPosition })
		end
		while travelled < e.Range do
			local dt = task.wait()
			if not player.Parent or not bolt.Parent then
				bolt:Destroy()
				return
			end
			local step = math.min(e.Speed * dt, e.Range - travelled)
			-- Raycast do passo evita atravessar paredes finas em frames longos
			local ray = Workspace:Raycast(position, direction * (step + e.Radius), rayParams)
			local nextPosition = position + direction * step
			if ray then
				local victims = Hitbox.AroundPoint(character, ray.Position, e.Radius, 1)
				finish(ray.Position, victims[1])
				return
			end
			local victims = Hitbox.AroundPoint(character, nextPosition, e.Radius, 1)
			if #victims > 0 then
				finish(nextPosition, victims[1])
				return
			end
			position = nextPosition
			travelled += step
			bolt.CFrame = CFrame.new(position, position + direction)
		end
		finish(position, nil)
	end)
end

effects.Shield = function(player, character, ability)
	local e = ability.Effect
	local state = getState(player)
	state.incomingMultiplier = e.Multiplier
	state.incomingMultiplierUntil = os.clock() + e.Duration
	notifyAbility:FireAllClients(character, state.characterId, ability.Id, "start", { Duration = e.Duration })
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

local function onRequestAbility(player: Player, slot: any, rawDirection: any)
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
	if RagdollService.IsRagdolled(player) then
		return deny(player, slot, "ragdoll")
	end
	local dashingUntil = player:GetAttribute("DashingUntil")
	if typeof(dashingUntil) == "number" and now < dashingUntil then
		return deny(player, slot, "dashing")
	end
	local noCooldown = player:GetAttribute(ATTR_NO_COOLDOWN) == true
	if now < state.busyUntil and not noCooldown then
		return deny(player, slot, "busy")
	end
	local readyAt = state.cooldownReadyAt[ability.Id] or 0
	if now < readyAt and not noCooldown then
		return deny(player, slot, "cooldown")
	end
	if ability.EnergyCost >= CharacterDefs.Energy.Max then
		return deny(player, slot, "use_g") -- a ultimate sai pelo G (RequestAwaken), não pelo slot
	end
	local handler = effects[ability.Effect.Type]
	if not handler then
		warn(("[AbilityService] efeito '%s' sem handler (habilidade %s)"):format(ability.Effect.Type, ability.Id))
		return deny(player, slot, "no_handler")
	end

	-- Tudo validado: cobra o cooldown antes de executar (a ultimate não gasta carga: o Awakening já gastou)
	if not noCooldown then
		state.cooldownReadyAt[ability.Id] = now + ability.Cooldown
		state.busyUntil = now + ability.CastTime
		notifyAbilityCooldown:FireClient(player, slot, ability.Id, Workspace:GetServerTimeNow() + ability.Cooldown)
	end

	Log.debug(("[AbilityService] %s usou %s.%s (carga %d)"):format(player.Name, state.characterId, ability.Id, state.energy))

	-- Despertou: usa a versão desperta da habilidade se existir (mesmo Id: animação/VFX iguais)
	local used = ability
	if ability.AwakenedEffect and AbilityService.IsAwakened(player) then
		used = table.clone(ability)
		used.Effect = ability.AwakenedEffect :: CharacterDefs.Effect
		local awakenedHandler = effects[used.Effect.Type]
		if awakenedHandler then
			handler = awakenedHandler
		end
	end
	local ok, err = pcall(handler :: any, player, character, used, sanitizeDirection(character, rawDirection))
	if not ok then
		warn(("[AbilityService] erro em %s: %s"):format(ability.Id, tostring(err)))
	end
end

local function onRequestAwaken(player: Player)
	if not awakenLimiter:Allow(player) then
		return
	end
	local state = getState(player)
	local character = player.Character
	if not character or not HealthService.IsAlive(character) or not HealthService.CanFight(player) then
		return
	end
	if CombatService.IsHardStunned(player) or RagdollService.IsRagdolled(player) then
		return
	end
	if AbilityService.IsAwakened(player) then
		return
	end
	if state.energy < CharacterDefs.Energy.Max and player:GetAttribute(ATTR_INFINITE_ENERGY) ~= true then
		return deny(player, 0, "energy")
	end
	local cfg = CombatConfig.Awakening
	local now = os.clock()
	setEnergy(player, 0)
	state.awakenedUntil = now + cfg.Duration
	player:SetAttribute(ATTR_AWAKENED_UNTIL, Workspace:GetServerTimeNow() + cfg.Duration)
	RagdollService.GrantIFrames(character, cfg.IFrames)
	CombatService.RestoreWalkSpeed(player)
	notifyAbility:FireAllClients(character, state.characterId, "Awakening", "start", { Duration = cfg.Duration })
	Log.debug(("[AbilityService] %s DESPERTOU por %ds"):format(player.Name, cfg.Duration))
	-- A ultimate do personagem (Abilities com EnergyCost = Max) sai junto com o despertar
	local def = CharacterDefs.Get(state.characterId)
	local ult: CharacterDefs.AbilityDef? = nil
	if def then
		for _, ability in def.Abilities do
			if ability.EnergyCost >= CharacterDefs.Energy.Max then
				ult = ability
			end
		end
	end
	if ult then
		local handler = effects[ult.Effect.Type]
		if handler then
			state.busyUntil = now + ult.CastTime
			local ok, err = pcall(handler :: any, player, character, ult, facing(character))
			if not ok then
				warn(("[AbilityService] erro na ultimate %s: %s"):format(ult.Id, tostring(err)))
			end
		end
	end
	task.delay(cfg.Duration, function()
		if states[player] == state and player.Character == character and os.clock() >= state.awakenedUntil then
			player:SetAttribute(ATTR_AWAKENED_UNTIL, 0)
			CombatService.RestoreWalkSpeed(player)
			notifyAbility:FireAllClients(character, state.characterId, "Awakening", "end")
		end
	end)
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
	-- Trocar = respawn com o personagem novo; em combate (levou dano há pouco) espera
	local since = HealthService.SecondsSinceDamaged(player)
	if since < CharacterDefs.SwapOutOfCombatSeconds then
		local remaining = math.ceil(CharacterDefs.SwapOutOfCombatSeconds - since)
		Remotes.GetEvent(Remotes.Events.NotifyUnlockDenied):FireClient(player, characterId, ("in_combat:%d"):format(remaining))
		return
	end
	state.characterId = characterId
	state.cooldownReadyAt = {}
	state.damageMultiplierUntil = 0
	state.incomingMultiplierUntil = 0
	player:SetAttribute("CharacterId", characterId)
	Log.debug(("[AbilityService] %s agora é %s (respawn)"):format(player.Name, characterId))
	AntiExploitService.Grace(player, 3)
	CharacterService.Load(player)
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function AbilityService.Init()
	notifyAbility = Remotes.GetEvent(Remotes.Events.NotifyAbility)
	notifyAbilityCooldown = Remotes.GetEvent(Remotes.Events.NotifyAbilityCooldown)
	notifyAbilityDenied = Remotes.GetEvent(Remotes.Events.NotifyAbilityDenied)
end

--- [Admin] Troca o personagem sem checar desbloqueio/round.
local function forceCharacter(player: Player, characterId: string)
	if not CharacterDefs.Get(characterId) then
		return
	end
	local state = getState(player)
	state.characterId = characterId
	state.cooldownReadyAt = {}
	state.damageMultiplierUntil = 0
	player:SetAttribute("CharacterId", characterId)
end

--- [Admin] Zera cooldowns/busy.
local function resetCooldowns(player: Player)
	local state = getState(player)
	state.cooldownReadyAt = {}
	state.busyUntil = 0
	for slot = 1, 3 do
		local ability = CharacterDefs.GetAbility(state.characterId, slot)
		if ability then
			notifyAbilityCooldown:FireClient(player, slot, ability.Id, Workspace:GetServerTimeNow())
		end
	end
end

function AbilityService.Start()
	AdminService.ForceCharacter = forceCharacter
	AdminService.SetEnergy = setEnergy
	AdminService.ResetCooldowns = resetCooldowns
	AdminService.Awaken = onRequestAwaken
	Remotes.GetEvent(Remotes.Events.RequestAbility).OnServerEvent:Connect(onRequestAbility)
	Remotes.GetEvent(Remotes.Events.RequestAwaken).OnServerEvent:Connect(onRequestAwaken)
	Remotes.GetEvent(Remotes.Events.RequestSelectCharacter).OnServerEvent:Connect(onRequestSelectCharacter)

	local function onPlayer(player: Player)
		getState(player)
		player:GetAttributeChangedSignal(ATTR_INFINITE_ENERGY):Connect(function()
			setEnergy(player, getState(player).energy)
		end)
		player.CharacterAdded:Connect(function()
			-- Respawn mantém o personagem escolhido, zera energia/cooldowns/buffs
			local prev = getState(player)
			states[player] = newState(prev.characterId)
			player:SetAttribute("Energy", 0)
			player:SetAttribute(ATTR_AWAKENED_UNTIL, 0)
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
