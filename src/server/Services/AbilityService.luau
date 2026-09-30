--!strict
--[[
	AbilityService (servidor)
	Autoridade sobre personagem escolhido, carga da ult, cooldowns e efeito de cada habilidade.
	Slots (RequestAbility(slot, direção)): 1..4 = ataques (CharacterDef.Abilities; enquanto DESPERTO, os
	AwakenedAbilities no lugar), 5 = R (CharacterDef.Passive, suporte). O dash universal (Q) é do MovementService.

	Ultimate (G = RequestAwaken, redesign B 2026-09-24): com a carga cheia, zera a carga, roda a cutscene de
	transformação (CombatConfig.Awakening.Cutscene) e liga a forma desperta por CharacterDef.Ultimate.Duration s
	(+dano/+velocidade por personagem; o kit desperto entra PRONTO — cooldown por Id). Ultimate.Effect, se
	houver, dispara sozinho no fim da cutscene (Bruno: cúpula do tempo). Ao acabar, os 4 normais voltam com o
	cooldown que tinham. Qualquer Effect pode ter `Then` (segundo efeito encadeado após ThenDelay).

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
local StandConfig = require(Modules:WaitForChild("StandConfig"))
local ProgressionConfig = require(Modules:WaitForChild("ProgressionConfig"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local Hitbox = require(Modules:WaitForChild("Hitbox"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))
local Combatant = require(Modules:WaitForChild("Combatant"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))
local AdminService = require(script.Parent:WaitForChild("AdminService"))
local MovementService = require(script.Parent:WaitForChild("MovementService"))

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
	speedMultiplier: number, -- Buff.Speed
	speedMultiplierUntil: number,
	awakenedUntil: number, -- os.clock()
	onceUsed: { [string]: number }, -- abilityId -> awakenedUntil em que a habilidade OncePerAwakening já saiu
	lastAbilityId: string?, -- D2: última habilidade usada (para Variants.Chain)
	lastAbilityAt: number,
}

type Fighter = Combatant.Fighter
local states: { [Instance]: PlayerState } = {} -- por lutador (Player ou Model de bot)

--- AntiExploit só existe para Player (bot é do servidor).
local function grace(fighter: Fighter, seconds: number)
	local asPlayer = Combatant.PlayerOf(fighter)
	if asPlayer then
		AntiExploitService.Grace(asPlayer, seconds)
	end
end

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
		speedMultiplier = 1,
		speedMultiplierUntil = 0,
		awakenedUntil = 0,
		onceUsed = {},
		lastAbilityAt = -math.huge,
	}
end

local function getState(player: Fighter): PlayerState
	local existing = states[player]
	if existing then
		return existing
	end
	-- bot: o BotService escolhe o personagem pelo atributo antes de lutar
	local preset = if player:IsA("Model") then player:GetAttribute("CharacterId") else nil
	local s = newState(if typeof(preset) == "string" then preset else nil)
	states[player] = s
	player:SetAttribute("CharacterId", s.characterId)
	player:SetAttribute("Energy", s.energy)
	return s
end

-- Flags do menu de desenvolvedor (atributos no Player, definidos por AdminService)
local ATTR_INFINITE_ENERGY = "DevInfiniteEnergy"
local ATTR_NO_COOLDOWN = "DevNoCooldown"

local function setEnergy(player: Fighter, value: number)
	local state = getState(player)
	if player:GetAttribute(ATTR_INFINITE_ENERGY) == true then
		value = CharacterDefs.Energy.Max
	end
	state.energy = math.clamp(value, 0, CharacterDefs.Energy.Max)
	player:SetAttribute("Energy", state.energy)
end

local detonateMark: (victimModel: Model, byAttacker: Fighter?) -> () -- Mark (Kira): definido junto do handler

--- Chamado por CombatService quando um acerto causou dano. `victimModel`/`isM1` servem para o Mark (Kira).
function AbilityService.OnHitDealt(attacker: Fighter, victim: Fighter?, victimModel: Model?, isM1: boolean?)
	setEnergy(attacker, getState(attacker).energy + CharacterDefs.Energy.GainOnHitDealt)
	if victim then
		setEnergy(victim, getState(victim).energy + CharacterDefs.Energy.GainOnHitTaken)
	end
	if isM1 and victimModel then
		detonateMark(victimModel, attacker)
	end
end

--- Energia por golpe recebido de um NPC (boss); o atacante não é Player.
function AbilityService.OnHitTaken(victim: Fighter)
	setEnergy(victim, getState(victim).energy + CharacterDefs.Energy.GainOnHitTaken)
end

--- Carga extra por parry.
function AbilityService.OnParry(player: Fighter)
	setEnergy(player, getState(player).energy + CombatConfig.Awakening.ChargeOnParry)
end

function AbilityService.IsAwakened(player: Fighter): boolean
	local state = states[player]
	return state ~= nil and os.clock() < state.awakenedUntil
end

function AbilityService.GetDamageMultiplier(player: Fighter): number
	local state = states[player]
	if not state then
		return 1
	end
	local mult = if os.clock() > state.damageMultiplierUntil then 1 else state.damageMultiplier
	if os.clock() < state.awakenedUntil then
		local def = CharacterDefs.Get(state.characterId)
		local ultMult = def and def.Ultimate and def.Ultimate.DamageMultiplier
		mult *= if typeof(ultMult) == "number" then ultMult else CombatConfig.Awakening.DamageMultiplier
	end
	return mult
end

--- Multiplicador de WalkSpeed (forma desperta por personagem × Buff.Speed). CombatService.RestoreWalkSpeed aplica.
function AbilityService.GetSpeedMultiplier(player: Fighter): number
	local state = states[player]
	if not state then
		return 1
	end
	local mult = if os.clock() > state.speedMultiplierUntil then 1 else state.speedMultiplier
	if os.clock() < state.awakenedUntil then
		local def = CharacterDefs.Get(state.characterId)
		local ultMult = def and def.Ultimate and def.Ultimate.SpeedMultiplier
		mult *= if typeof(ultMult) == "number" then ultMult else CombatConfig.Awakening.SpeedMultiplier
	end
	return mult
end

--- Multiplicador de dano RECEBIDO (escudo). 1 = normal.
function AbilityService.GetIncomingMultiplier(player: Fighter): number
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

local function areaHit(player: Fighter, character: Model, effect: CharacterDefs.Effect, damage: number, center: Vector3?)
	local victims: { Model }
	if center then
		victims = Hitbox.AroundPoint(character, center, effect.Radius, MAX_AREA_TARGETS)
	else
		victims = Hitbox.Around(character, effect.Radius, MAX_AREA_TARGETS)
	end
	for _, victim in victims do
		local kind = CombatService.ResolveHit(player, character, victim, damage, false, effect.Knockback)
		local stunSeconds = effect.StunSeconds
		if typeof(stunSeconds) == "number" and kind ~= "immune" then
			local victimPlayer = Combatant.Of(victim) -- Player ou bot; nil = NPC
			if victimPlayer then
				CombatService.Stun(victimPlayer, stunSeconds, "stunned")
			end
		end
	end
end

local function stillValid(player: Fighter, character: Model): boolean
	return Combatant.IsPresent(player) and Combatant.CharacterOf(player) == character and HealthService.IsAlive(character)
end

-- direction = horizontal unitária pedida pelo cliente (WASD), já validada; frente do HRP se não veio
local effects: { [string]: (Fighter, Model, CharacterDefs.AbilityDef, Vector3) -> () } = {}
local runEffect: (player: Fighter, character: Model, ability: CharacterDefs.AbilityDef, direction: Vector3) -> ()

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
	grace(player, maxDuration + 1.0)
	notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "start", {
		Speed = e.Speed,
		Duration = e.Duration,
		Direction = direction,
	})
	if Combatant.IsBot(player) then
		MovementService.ServerDash(character, direction, direction, e.Speed, maxDuration) -- bot: o servidor move
	end
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
					local kind = CombatService.ResolveHit(player, character, victim, e.Damage, false, e.Knockback, { KnockbackDirection = dir })
					local victimPlayer = Combatant.Of(victim) -- Player ou bot; nil = NPC
					if victimPlayer and typeof(e.StunSeconds) == "number" and kind ~= "immune" then
						CombatService.Stun(victimPlayer, e.StunSeconds, "stunned")
					end
					-- Devorar (boss): cada alvo atingido cura o lançador
					local healed = 0
					if typeof(e.HealPerHit) == "number" and e.HealPerHit > 0 then
						healed = HealthService.Heal(character, e.HealPerHit)
					end
					notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "hit", { Healed = healed })
				end
			end
			task.wait(DASH_SAMPLE_INTERVAL)
		end
	end)
end

-- Agarrão: investida curta (como Dash) e, ao encostar no 1º alvo, SEGURA ele por Carry s (a vítima
-- fica em stun duro e segue o atacante no cliente dela; o atacante ganha super armor: não pode ser
-- interrompido). Sem alvo = só a investida. O final depende de Effect.Finish:
--   Slam (padrão): golpe colado (Damage + Knockback)
--   Throw:         arremessa na direção em que o atacante olha (Knockback forte, com Up; wall splat conta)
--   Chokeslam:     segura erguido (Lift studs) e esmaga à frente; área SlamRadius/SlamDamage onde cai
--   Spin:          a vítima gira ao redor (Spin voltas/s) batendo em quem chega perto (SpinRadius/
--                  SpinDamage a cada SpinInterval) e é solta na tangente
local GRAB_OFFSET = 3 -- studs à frente do atacante onde a vítima fica presa
local GRAB_COLLISION_GROUP = "Grabbed" -- vítima carregada: não colide com nada (ver attachVictim)
do
	local PhysicsService = game:GetService("PhysicsService")
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GRAB_COLLISION_GROUP)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(GRAB_COLLISION_GROUP, "Default", false)
		PhysicsService:CollisionGroupSetCollidable(GRAB_COLLISION_GROUP, GRAB_COLLISION_GROUP, false)
	end)
end
local SPIN_DEFAULT = 1.25 -- voltas por segundo
-- posição relativa da vítima no giro (mesma fórmula do cliente: AbilityController.startGrabbed)
local function spinAngle(e: any, elapsed: number): number
	return elapsed * (tonumber(e.Spin) or SPIN_DEFAULT) * math.pi * 2
end
--- Solda a vítima na frente do atacante (Weld HRP→HRP no servidor: todo mundo vê a mesma posição, sem
--- atraso). A física da vítima passa para o cliente do atacante durante o Carry. Retorna a função que solta.
local function attachVictim(attacker: Fighter, attackerRoot: BasePart, victim: Model, offset: number, lift: number?, spin: number?, e: any): () -> ()
	local vRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
	local vHum = victim:FindFirstChildOfClass("Humanoid")
	if not vRoot then
		return function() end
	end
	local victimPlayer = Combatant.Of(victim) -- Player ou bot; nil = NPC
	local weld = Instance.new("Weld")
	weld.Name = "GrabWeld"
	weld.Part0 = attackerRoot
	weld.Part1 = vRoot
	local function c0(angle: number): CFrame
		return CFrame.Angles(0, angle, 0) * CFrame.new(0, lift or 0, -offset) * CFrame.Angles(0, math.pi, 0)
	end
	weld.C0 = c0(0)
	weld.C1 = CFrame.new()
	if vHum then
		vHum.PlatformStand = true
	end
	-- dono (2026-09-23): preso no agarrão NINGUÉM age — bot, traidor, boss, boneco (as IAs e o NpcPunch leem isto)
	victim:SetAttribute("Grabbed", true)
	-- Soldada, a vítima NÃO pode colidir: as partes dela sobrepostas ao atacante/chão numa solda rígida
	-- viram impulso enorme e os dois voam (bug do "vai pro void", dono 2026-09-19). Grupo de colisão em vez
	-- de CanCollide porque o Humanoid religa o CanCollide do Torso sozinho. Sem massa para o atacante
	-- andar normal. Devolvido no release.
	local collisions: { [BasePart]: { Group: string, Massless: boolean } } = {}
	for _, part in victim:GetDescendants() do
		if part:IsA("BasePart") then
			collisions[part] = { Group = part.CollisionGroup, Massless = part.Massless }
			part.CollisionGroup = GRAB_COLLISION_GROUP
			part.Massless = true
		end
	end
	vRoot.AssemblyLinearVelocity = Vector3.zero
	vRoot.AssemblyAngularVelocity = Vector3.zero
	weld.Parent = vRoot
	pcall(function()
		vRoot:SetNetworkOwner(Combatant.PlayerOf(attacker)) -- bot agarrando: o servidor
	end)
	local released = false
	if spin then
		local t0 = os.clock()
		task.spawn(function()
			while not released and weld.Parent do
				weld.C0 = c0(spinAngle(e, os.clock() - t0))
				task.wait(1 / 30)
			end
		end)
	end
	return function()
		if released then
			return
		end
		released = true
		weld:Destroy()
		victim:SetAttribute("Grabbed", false)
		if vHum and not (victimPlayer and victimPlayer:GetAttribute("Ragdolled") == true) then
			vHum.PlatformStand = false
		end
		pcall(function()
			local asPlayer = Combatant.PlayerOf(victimPlayer)
			if asPlayer then
				vRoot:SetNetworkOwner(asPlayer)
			elseif Combatant.IsBot(victimPlayer) then
				vRoot:SetNetworkOwner(nil)
			else
				vRoot:SetNetworkOwnershipAuto()
			end
		end)
		-- na hora: sem colisão a vítima cairia pelo chão; a 3 studs de distância não há sobreposição
		for part, saved in collisions do
			if part.Parent then
				part.Massless = saved.Massless
				part.CollisionGroup = saved.Group
			end
		end
	end
end

effects.Grab = function(player, character, ability, direction)
	local e = ability.Effect
	local characterId = getState(player).characterId
	local finish = if typeof(e.Finish) == "string" then e.Finish else "Slam"
	local maxDuration = e.Duration * CharacterDefs.DashTuning.ForwardScale
	grace(player, maxDuration + e.Carry + 1.0)
	CombatService.SetSuperArmor(player, maxDuration + e.Carry + 0.2)
	-- Prioridade (dono, 2026-09-16): executando um agarrão não se leva golpe, do início ao release.
	-- Se a investida não pegar ninguém, a invencibilidade acaba junto com ela.
	RagdollService.GrantIFrames(character, maxDuration + 0.1)
	notifyAbility:FireAllClients(character, characterId, ability.Id, "start", {
		Speed = e.Speed,
		Duration = e.Duration,
		Direction = direction,
	})
	if Combatant.IsBot(player) then
		MovementService.ServerDash(character, direction, direction, e.Speed, maxDuration) -- bot: o servidor move
	end
	task.spawn(function()
		local endsAt = os.clock() + maxDuration + DASH_SAMPLE_INTERVAL
		local caught: Model? = nil
		local blockedOnce: { [Model]: boolean } = {}
		while os.clock() < endsAt and not caught do
			if not stillValid(player, character) then
				return
			end
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local vel = if root then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z) else Vector3.zero
			local dir = if vel.Magnitude > 5 then vel.Unit else direction
			for _, candidate in Hitbox.InDirection(character, dir, e.Range, e.Width, e.Height, 2) do
				-- não agarra quem está invencível (cutscene, i-frames, preso em outro agarrão)
				if HealthService.IsInvulnerable(candidate, player) then
					continue
				end
				-- dono (2026-09-21): quem está BLOQUEANDO de frente não é agarrado — o block absorve (gasta guarda)
				if CombatService.IsBlockingAgainst(candidate, character) then
					if not blockedOnce[candidate] then
						blockedOnce[candidate] = true
						CombatService.ResolveHit(player, character, candidate, e.Damage, false)
					end
					continue
				end
				caught = candidate
				break
			end
			if not caught then
				task.wait(DASH_SAMPLE_INTERVAL)
			end
		end
		if not caught then
			RagdollService.ClearIFrames(character)
			return
		end
		local victim = caught :: Model
		local victimPlayer = Combatant.Of(victim) -- Player ou bot; nil = NPC
		RagdollService.GrantIFrames(character, e.Carry + 0.3)
		HealthService.LockTo(victim, player, e.Carry + 0.5) -- terceiro não tira a vítima do agarrão
		if victimPlayer then
			CombatService.CancelBlock(victimPlayer)
			CombatService.Stun(victimPlayer, e.Carry + 0.3, "grabbed")
			grace(victimPlayer, e.Carry + 1.5)
		end
		notifyAbility:FireAllClients(character, characterId, ability.Id, "grab", {
			Victim = victim,
			Carry = e.Carry,
			Offset = GRAB_OFFSET,
			Lift = if finish == "Chokeslam" then (tonumber(e.Lift) or 5) else nil,
			Spin = if finish == "Spin" then (tonumber(e.Spin) or SPIN_DEFAULT) else nil,
		})
		local grabbedAt = os.clock()
		local aRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart
		-- cena do agarrão: o atacante fica parado (dono, 2026-09-20: "consigo me mover durante"); o Spin gira no lugar
		CombatService.HoldStill(player, e.Carry + 0.15, "grab")
		local release = attachVictim(player, aRoot, victim, GRAB_OFFSET,
			if finish == "Chokeslam" then (tonumber(e.Lift) or 5) else nil,
			if finish == "Spin" then (tonumber(e.Spin) or SPIN_DEFAULT) else nil, e)
		if finish == "Spin" then
			-- enquanto gira, a vítima é a "arma": quem estiver no raio toma ticks
			local interval = tonumber(e.SpinInterval) or 0.3
			task.spawn(function()
				while os.clock() - grabbedAt < e.Carry do
					task.wait(interval)
					if not stillValid(player, character) or not HealthService.IsAlive(victim) then
						return
					end
					for _, other in Hitbox.Around(character, tonumber(e.SpinRadius) or 8, MAX_AREA_TARGETS) do
						if other ~= victim then
							CombatService.ResolveHit(player, character, other, tonumber(e.SpinDamage) or 6, false, e.SpinKnockback)
						end
					end
				end
			end)
		end
		task.wait(e.Carry)
		release() -- solta ANTES do golpe: a física volta para a vítima e o empurrão entra no cliente dela
		-- dono (2026-09-23): intocável até o golpe final sair (nada de dano/hitstun/ragdoll no meio do agarrão)
		RagdollService.GrantIFrames(character, 0.5)
		if not stillValid(player, character) or not HealthService.IsAlive(victim) then
			HealthService.LockTo(victim, nil)
			notifyAbility:FireAllClients(character, characterId, ability.Id, "release", { Victim = victim })
			return
		end
		-- golpe final: a vítima está colada; ResolveHit sem parry (está presa)
		local vRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hitData: { [string]: any } = { Victim = victim }
		if finish == "Spin" then
			-- tangente da órbita no instante em que solta (θ = ângulo acumulado; posição = frente girada)
			local theta = spinAngle(e, os.clock() - grabbedAt)
			local front = facing(character)
			local right = Vector3.new(-front.Z, 0, front.X)
			-- cliente: aRoot.CFrame * Angles(0, θ, 0) * (0, 0, -offset) → r(θ) = front·cosθ − right·sinθ
			-- r'(θ) = −front·sinθ − right·cosθ
			local tangent = (-front * math.sin(theta) - right * math.cos(theta)).Unit
			CombatService.ResolveHit(player, character, victim, e.Damage, false, e.Knockback, { BreaksBlock = true, KnockbackDirection = tangent })
		elseif finish == "Chokeslam" then
			CombatService.ResolveHit(player, character, victim, e.Damage, false, e.Knockback, { BreaksBlock = true })
			local at = if vRoot then vRoot.Position else nil
			if at then
				hitData.Position = at
				for _, other in Hitbox.AroundPoint(character, at, tonumber(e.SlamRadius) or 8, MAX_AREA_TARGETS) do
					if other ~= victim then
						CombatService.ResolveHit(player, character, other, tonumber(e.SlamDamage) or 10, false, e.SlamKnockback)
					end
				end
			end
		else
			CombatService.ResolveHit(player, character, victim, e.Damage, false, e.Knockback, { BreaksBlock = true })
		end
		HealthService.LockTo(victim, nil)
		if victimPlayer and typeof(e.StunSeconds) == "number" then
			CombatService.Stun(victimPlayer, e.StunSeconds, "stunned")
		end
		notifyAbility:FireAllClients(character, characterId, ability.Id, "hit", hitData)
	end)
end

-- ULT DO RICK (dono, 2026-09-20): voo livre na direção da câmera (o cliente dono da física dirige;
-- MovementController.Fly) por Duration s procurando alguém à frente; pegou = agarra, SOBE (RiseTime/
-- RiseHeight) e MERGULHA (DiveSpeed) esmagando no chão. Subida/mergulho são do servidor (root ancorado,
-- CFrame interpolado) para todo mundo ver igual; a vítima vai soldada (attachVictim).
effects.FlyGrab = function(player, character, ability, direction)
	local e = ability.Effect
	local characterId = getState(player).characterId
	local flyTime = tonumber(e.Duration) or 7
	local riseTime = tonumber(e.RiseTime) or 1.4
	local riseHeight = tonumber(e.RiseHeight) or 20
	local diveSpeed = tonumber(e.DiveSpeed) or 100
	grace(player, flyTime + riseTime + 4)
	CombatService.SetSuperArmor(player, flyTime + riseTime + 2)
	RagdollService.GrantIFrames(character, flyTime + 0.1)
	notifyAbility:FireAllClients(character, characterId, ability.Id, "start", { Fly = true, Speed = e.FlySpeed, Duration = flyTime })
	-- bot: o servidor voa reto na direção pedida (o jogador dirige pela câmera no cliente)
	local botFly: LinearVelocity? = nil
	if Combatant.IsBot(player) then
		local root0 = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root0 then
			local att = Instance.new("Attachment")
			att.Name = "BotFly"
			att.Parent = root0
			local lv = Instance.new("LinearVelocity")
			lv.Attachment0 = att
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
			lv.MaxForce = math.huge
			lv.VectorVelocity = (direction + Vector3.new(0, 0.15, 0)).Unit * (tonumber(e.FlySpeed) or 60)
			lv.Parent = att
			botFly = lv
			task.delay(flyTime, function()
				att:Destroy()
			end)
		end
	end
	task.spawn(function()
		local endsAt = os.clock() + flyTime
		local caught: Model? = nil
		while os.clock() < endsAt and not caught do
			if not stillValid(player, character) then
				return
			end
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local vel = if root then root.AssemblyLinearVelocity else Vector3.zero
			local dir = if vel.Magnitude > 5 then vel.Unit else (if root then root.CFrame.LookVector else direction)
			for _, candidate in Hitbox.InDirection(character, dir, e.Range, e.Width, e.Height, 2) do
				-- (ult) pega até quem bloqueia: block só segura agarrão comum
				if not HealthService.IsInvulnerable(candidate, player) then
					caught = candidate
					break
				end
			end
			if not caught then
				task.wait(DASH_SAMPLE_INTERVAL)
			end
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if botFly then
			local att = botFly.Parent
			if att then
				att:Destroy()
			end
		end
		if not caught or not root then
			RagdollService.ClearIFrames(character)
			notifyAbility:FireAllClients(character, characterId, ability.Id, "end", {})
			return
		end
		local victim = caught :: Model
		local victimPlayer = Combatant.Of(victim) -- Player ou bot; nil = NPC
		-- tempo total da cena: subida + mergulho (estimado pela altura + margem)
		local carry = riseTime + (riseHeight + 30) / diveSpeed + 0.4
		RagdollService.GrantIFrames(character, carry + 0.3)
		HealthService.LockTo(victim, player, carry + 0.5)
		if victimPlayer then
			CombatService.CancelBlock(victimPlayer)
			CombatService.Stun(victimPlayer, carry + 0.3, "grabbed")
			grace(victimPlayer, carry + 1.5)
		end
		CombatService.HoldStill(player, carry, "grab")
		notifyAbility:FireAllClients(character, characterId, ability.Id, "grab", { Victim = victim, Carry = carry, Offset = GRAB_OFFSET, Lift = 1 })
		local release = attachVictim(player, root, victim, GRAB_OFFSET, 1, nil, e)
		-- servidor assume o corpo: ancora e interpola (o cliente parou de voar no "grab")
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
		local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		local look = if flat.Magnitude > 0.05 then flat.Unit else facing(character)
		local startPos = root.Position
		local topPos = startPos + Vector3.new(0, riseHeight, 0) + look * 4
		local function alive(): boolean
			return stillValid(player, character) and root.Parent ~= nil and HealthService.IsAlive(victim)
		end
		local function moveTo(from: Vector3, to: Vector3, seconds: number, pitch: number): boolean
			local t0 = os.clock()
			while true do
				local a = math.clamp((os.clock() - t0) / seconds, 0, 1)
				if not alive() then
					return false
				end
				local pos = from:Lerp(to, a)
				root.CFrame = CFrame.lookAt(pos, pos + look) * CFrame.Angles(pitch, 0, 0)
				if a >= 1 then
					return true
				end
				task.wait()
			end
		end
		-- SOBE olhando para cima (a animação fica com a cabeça pra cima)
		local ok = moveTo(startPos, topPos, riseTime, math.rad(35))
		local groundPos = startPos
		if ok then
			-- MERGULHO: vira para o chão e desce até onde o raio acha piso à frente
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character, victim }
			local hit = Workspace:Raycast(topPos + look * 6, Vector3.new(0, -(riseHeight + 80), 0), params)
			groundPos = if hit then hit.Position + Vector3.new(0, 3, 0) else Vector3.new(topPos.X, startPos.Y, topPos.Z) + look * 6
			local dist = (groundPos - topPos).Magnitude
			ok = moveTo(topPos, groundPos, math.max(0.15, dist / diveSpeed), math.rad(-60))
		end
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
		root.Anchored = false
		release()
		RagdollService.GrantIFrames(character, 0.5) -- intocável até o impacto sair
		if not ok or not stillValid(player, character) or not HealthService.IsAlive(victim) then
			HealthService.LockTo(victim, nil)
			notifyAbility:FireAllClients(character, characterId, ability.Id, "release", { Victim = victim })
			return
		end
		-- IMPACTO: a vítima toma o golpe no chão + área em volta
		CombatService.ResolveHit(player, character, victim, e.Damage, false, e.Knockback, { BreaksBlock = true })
		local at = groundPos + look * GRAB_OFFSET
		for _, other in Hitbox.AroundPoint(character, at, tonumber(e.SlamRadius) or 10, MAX_AREA_TARGETS) do
			if other ~= victim then
				CombatService.ResolveHit(player, character, other, tonumber(e.SlamDamage) or 15, false, e.SlamKnockback)
			end
		end
		HealthService.LockTo(victim, nil)
		notifyAbility:FireAllClients(character, characterId, ability.Id, "hit", { Victim = victim, Position = at })
	end)
end

effects.Teleport = function(player, character, ability, direction)
	local e = ability.Effect
	-- teleporte real (atravessa obstáculos, encaixa no chão) — mesmo do Q do Swift; Backward = fuga
	local dir = if e.Backward == true then -facing(character) else direction
	if not MovementService.Teleport(player, character, dir, e.Distance) then
		return
	end
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
	-- Os golpes do meio só seguram o alvo (hitstun, sem empurrão); o empurrão/ragdoll fica para o ÚLTIMO,
	-- senão o 1º tick já joga o alvo para fora do alcance e a rajada acerta 2 de 12 (teste 2026-09-25).
	local holdEffect = table.clone(e)
	holdEffect.Knockback = nil
	task.spawn(function()
		for i = 1, e.Hits do
			task.wait(e.Interval)
			if not stillValid(player, character) or CombatService.IsStunned(player) then
				return
			end
			-- Com Offset a rajada é à frente do rig (ORA/MUDA): o centro segue a frente atual a cada golpe
			local center = if typeof(e.Offset) == "number" then areaCenter(character, e) else nil
			areaHit(player, character, if i < e.Hits then holdEffect else e, e.Damage, center)
			notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "hit", { Index = i })
		end
		notifyAbility:FireAllClients(character, getState(player).characterId, ability.Id, "end")
	end)
end

effects.Heal = function(player, character, ability)
	local e = ability.Effect
	local healed = HealthService.Heal(character, e.Amount)
	if e.Cleanse == true then
		CombatService.ClearStun(player)
		if RagdollService.IsRagdolled(player) then
			RagdollService.Recover(player, 0.3)
		end
	end
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

local function fireProjectile(player: Fighter, character: Model, ability: CharacterDefs.AbilityDef, direction: Vector3)
	local e = ability.Effect
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local characterId = getState(player).characterId
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
			-- AreaRadius: explode em área ao acertar (Moeda Bomba): o alvo direto já tomou Damage, os outros AreaDamage
			local areaRadius = tonumber(e.AreaRadius)
			if areaRadius and areaRadius > 0 and stillValid(player, character) then
				for _, other in Hitbox.AroundPoint(character, hitPosition, areaRadius, MAX_AREA_TARGETS) do
					if other ~= victim then
						CombatService.ResolveHit(player, character, other, tonumber(e.AreaDamage) or e.Damage, false, e.Knockback)
					end
				end
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

--- Projectile: Count > 1 = leque (Spread graus totais) ou rajada (Interval s entre cada)
effects.Projectile = function(player, character, ability)
	local e = ability.Effect
	local count = math.clamp(math.floor(tonumber(e.Count) or 1), 1, 8)
	local base = facing(character)
	if count == 1 then
		fireProjectile(player, character, ability, base)
		return
	end
	local spread = tonumber(e.Spread) or 0
	local interval = tonumber(e.Interval) or 0
	task.spawn(function()
		for i = 1, count do
			if not stillValid(player, character) then
				return
			end
			local angle = if spread > 0 then math.rad(-spread / 2 + spread * (i - 1) / (count - 1)) else 0
			local dir = (CFrame.fromAxisAngle(Vector3.yAxis, angle) * base)
			fireProjectile(player, character, ability, dir)
			if interval > 0 then
				task.wait(interval)
			end
		end
	end)
end

effects.Shield = function(player, character, ability)
	local e = ability.Effect
	local state = getState(player)
	state.incomingMultiplier = e.Multiplier
	state.incomingMultiplierUntil = os.clock() + e.Duration
	notifyAbility:FireAllClients(character, state.characterId, ability.Id, "start", { Duration = e.Duration })
end

-- DOMÍNIO DO TEMPO (Swift): cúpula fixa no ponto do cast. A cada tick, quem está dentro (jogadores) recebe
-- Player.TimeSlow = SlowMultiplier (WalkSpeed, socos, dashes e habilidades ficam proporcionalmente lentos;
-- o cliente desacelera as animações e tinge a tela). O lançador recebe SelfMultiplier enquanto está dentro;
-- se SAIR, a cúpula quebra (todos liberados) e ele fica a BreakMultiplier até Duration acabar.
local ATTR_TIME_SLOW = "TimeSlow"
local activeDomes: { [Instance]: boolean } = {}
effects.TimeDome = function(player, character, ability)
	local e = ability.Effect
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	if activeDomes[player] then
		return
	end
	activeDomes[player] = true
	local center = root.Position
	local radius = tonumber(e.Radius) or 22
	local duration = tonumber(e.Duration) or 8
	local slowMult = tonumber(e.SlowMultiplier) or 0.25
	local selfMult = tonumber(e.SelfMultiplier) or 1.25
	local breakMult = tonumber(e.BreakMultiplier) or 2.2
	local noBreak = e.NoBreak == true -- Parada do Tempo: o lançador pode sair sem quebrar a cúpula
	local characterId = getState(player).characterId
	local endsAt = os.clock() + duration
	local slowed: { [Instance]: boolean } = {}
	local broken = false
	local function setSlow(target: Fighter, value: number?)
		if target:GetAttribute(ATTR_TIME_SLOW) ~= value then
			target:SetAttribute(ATTR_TIME_SLOW, value)
			CombatService.RestoreWalkSpeed(target)
		end
	end
	notifyAbility:FireAllClients(character, characterId, ability.Id, "start", { Position = center, Radius = radius, Duration = duration })
	grace(player, duration + 1)
	task.spawn(function()
		while os.clock() < endsAt do
			if not stillValid(player, character) then
				break
			end
			local myRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local inside = myRoot ~= nil and (myRoot.Position - center).Magnitude <= radius
			if not broken then
				if inside or noBreak then
					setSlow(player, if selfMult ~= 1 then selfMult else nil)
				else
					-- saiu: a cúpula quebra, todo mundo é liberado, o Swift fica MUITO rápido até o fim
					broken = true
					for other in slowed do
						setSlow(other, nil)
					end
					table.clear(slowed)
					setSlow(player, breakMult)
					notifyAbility:FireAllClients(character, characterId, ability.Id, "break", { Position = center, Radius = radius })
					Log.debug(("[AbilityService] %s saiu do Domínio do Tempo: cúpula quebrada"):format(player.Name))
				end
				if not broken then
					for _, other in Combatant.All() do
						if other == player then
							continue
						end
						local oc = Combatant.CharacterOf(other)
						local oroot = oc and oc:FindFirstChild("HumanoidRootPart") :: BasePart?
						local oin = oroot ~= nil and HealthService.IsAlive(oc :: Model) and (oroot.Position - center).Magnitude <= radius
						if oin then
							if not slowed[other] then
								slowed[other] = true
								setSlow(other, slowMult)
							end
						elseif slowed[other] then
							slowed[other] = nil
							setSlow(other, nil)
						end
					end
				end
			end
			task.wait(0.1)
		end
		for other in slowed do
			setSlow(other, nil)
		end
		table.clear(slowed)
		setSlow(player, nil)
		activeDomes[player] = nil
		notifyAbility:FireAllClients(character, characterId, ability.Id, "end", { Position = center, Radius = radius, Broken = broken })
	end)
end

--- Buff { Damage?, Speed?, Duration, DashCooldownMult? } (DamageBuff { Multiplier, Duration } = alias antigo)
effects.Buff = function(player, character, ability)
	local e = ability.Effect
	local state = getState(player)
	local duration = tonumber(e.Duration) or 5
	local dmg = tonumber(e.Damage) or tonumber(e.Multiplier)
	if dmg then
		state.damageMultiplier = dmg
		state.damageMultiplierUntil = os.clock() + duration
	end
	local spd = tonumber(e.Speed)
	if spd then
		state.speedMultiplier = spd
		state.speedMultiplierUntil = os.clock() + duration
		CombatService.RestoreWalkSpeed(player)
		task.delay(duration + 0.05, function()
			if states[player] == state then
				CombatService.RestoreWalkSpeed(player)
			end
		end)
	end
	local dashMult = tonumber(e.DashCooldownMult)
	if dashMult then
		player:SetAttribute("DashCooldownMult", dashMult) -- MovementService lê ao cobrar o cooldown do Q
		task.delay(duration, function()
			if states[player] == state and player:GetAttribute("DashCooldownMult") == dashMult then
				player:SetAttribute("DashCooldownMult", nil)
			end
		end)
	end
	notifyAbility:FireAllClients(character, state.characterId, ability.Id, "start", { Duration = duration })
end
effects.DamageBuff = effects.Buff

-- MARK (Kira): toca quem está na área e marca; o próximo M1 do lançador no marcado (ou AutoDelay s) explode
-- ExplodeRadius em volta da vítima. Uma marca por vítima (a mais nova vence).
type Mark = { by: Fighter, character: Model, effect: CharacterDefs.Effect, abilityId: string, expiresAt: number }
local marks: { [Model]: Mark } = {}
local function explodeMark(victim: Model, mark: Mark)
	marks[victim] = nil
	victim:SetAttribute("Marked", nil)
	if not stillValid(mark.by, mark.character) then
		return
	end
	local root = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
	local center = if root then root.Position else nil
	local e = mark.effect
	local knock = e.ExplodeKnockback
	-- a vítima marcada leva o dano cheio; quem está em volta também
	CombatService.ResolveHit(mark.by, mark.character, victim, e.ExplodeDamage, false, knock)
	if center then
		for _, other in Hitbox.AroundPoint(mark.character, center, e.ExplodeRadius, MAX_AREA_TARGETS) do
			if other ~= victim then
				CombatService.ResolveHit(mark.by, mark.character, other, e.ExplodeDamage, false, knock)
			end
		end
	end
	notifyAbility:FireAllClients(mark.character, getState(mark.by).characterId, mark.abilityId, "hit", { Position = center, Victim = victim })
end
detonateMark = function(victim: Model, by: Fighter?)
	local mark = marks[victim]
	if mark and (by == nil or by == mark.by) and os.clock() < mark.expiresAt then
		explodeMark(victim, mark)
	end
end
effects.Mark = function(player, character, ability)
	local e = ability.Effect
	local characterId = getState(player).characterId
	local center = if typeof(e.Offset) == "number" then areaCenter(character, e) else nil
	notifyAbility:FireAllClients(character, characterId, ability.Id, "start", { Position = center })
	local victims: { Model }
	if center then
		victims = Hitbox.AroundPoint(character, center, e.Radius, MAX_AREA_TARGETS)
	else
		victims = Hitbox.Around(character, e.Radius, MAX_AREA_TARGETS)
	end
	local autoDelay = tonumber(e.AutoDelay) or 4
	for _, victim in victims do
		local kind = CombatService.ResolveHit(player, character, victim, tonumber(e.Damage) or 0, false)
		if kind == "immune" or kind == "parry" then
			continue
		end
		local mark: Mark = { by = player, character = character, effect = e, abilityId = ability.Id, expiresAt = os.clock() + autoDelay }
		marks[victim] = mark
		victim:SetAttribute("Marked", true) -- o cliente mostra a marca (VFX <Char>/<Ability>_Mark)
		notifyAbility:FireAllClients(character, characterId, ability.Id, "mark", { Victim = victim, Duration = autoDelay })
		task.delay(autoDelay, function()
			if marks[victim] == mark then
				explodeMark(victim, mark)
			end
		end)
	end
end

-- HOMING (Sheer Heart Attack / drone): bomba no chão que persegue o lutador mais perto por Duration s e explode
-- (Radius) ao encostar. Servidor simula a peça (anchored, Heartbeat). Count > 1 = várias, com um atraso entre elas.
local function launchHoming(player: Fighter, character: Model, ability: CharacterDefs.AbilityDef, index: number)
	local e = ability.Effect
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local characterId = getState(player).characterId
	local speed = tonumber(e.Speed) or 22
	local radius = tonumber(e.Radius) or 6
	local seek = tonumber(e.SeekRadius) or 40
	local duration = tonumber(e.Duration) or 6
	local side = if index % 2 == 0 then 2 else -2
	local position = root.Position + root.CFrame.LookVector * 3 + root.CFrame.RightVector * side * (math.ceil(index / 2) - (if index == 1 then 1 else 0)) - Vector3.new(0, 2, 0)
	local part = Instance.new("Part")
	part.Name = ability.Id
	part.Size = Vector3.new(2, 1.5, 2.5)
	part.Material = Enum.Material.Metal
	part.Color = Color3.fromRGB(60, 60, 70)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = CFrame.new(position, position + root.CFrame.LookVector)
	local folder = projectileFolder()
	part.Parent = folder
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character, folder }
	notifyAbility:FireAllClients(character, characterId, ability.Id, "start", { Position = position, Part = part })
	task.spawn(function()
		local endsAt = os.clock() + duration
		local target: Model? = nil
		local heading = root.CFrame.LookVector
		while os.clock() < endsAt do
			local dt = task.wait()
			if not stillValid(player, character) or not part.Parent then
				break
			end
			-- alvo: o lutador vivo mais perto (jogador, bot, boneco ou boss) até SeekRadius
			if not target or not target.Parent or not HealthService.IsAlive(target) then
				target = nil
				local best = seek
				for _, m in Hitbox.AroundPoint(character, position, seek, 12) do
					local r = m:FindFirstChild("HumanoidRootPart") :: BasePart?
					local d = if r then (r.Position - position).Magnitude else math.huge
					if d < best then
						best, target = d, m
					end
				end
			end
			local tRoot = target and target:FindFirstChild("HumanoidRootPart") :: BasePart?
			if tRoot then
				local to = tRoot.Position - position
				local flat = Vector3.new(to.X, 0, to.Z)
				if flat.Magnitude > 0.1 then
					heading = heading:Lerp(flat.Unit, math.min(1, dt * 6)).Unit
				end
				if to.Magnitude <= radius * 0.6 then
					break -- encostou: explode
				end
			end
			position += heading * speed * dt
			-- cola no chão
			local ground = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), rayParams)
			if ground then
				position = Vector3.new(position.X, ground.Position.Y + 0.9, position.Z)
			end
			part.CFrame = CFrame.new(position, position + heading)
		end
		part:Destroy()
		if stillValid(player, character) then
			for _, victim in Hitbox.AroundPoint(character, position, radius, MAX_AREA_TARGETS) do
				local kind = CombatService.ResolveHit(player, character, victim, e.Damage, false, e.Knockback)
				local stun = tonumber(e.StunSeconds)
				local vf = Combatant.Of(victim)
				if stun and vf and kind ~= "immune" then
					CombatService.Stun(vf, stun, "stunned")
				end
			end
		end
		notifyAbility:FireAllClients(character, characterId, ability.Id, "hit", { Position = position })
	end)
end
effects.Homing = function(player, character, ability)
	local count = math.clamp(math.floor(tonumber(ability.Effect.Count) or 1), 1, 4)
	task.spawn(function()
		for i = 1, count do
			launchHoming(player, character, ability, i)
			if i < count then
				task.wait(0.35)
			end
		end
	end)
end

-- REWIND (Bites the Dust): guarda vida e posição; Delay s depois volta para lá (vida nunca desce) e, se houver
-- Radius/Damage, explode em volta ao voltar.
effects.Rewind = function(player, character, ability)
	local e = ability.Effect
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local characterId = getState(player).characterId
	local savedHealth = humanoid.Health
	local savedCFrame = root.CFrame
	local delay = tonumber(e.Delay) or 4
	notifyAbility:FireAllClients(character, characterId, ability.Id, "start", { Position = root.Position, Duration = delay })
	task.delay(delay, function()
		if not stillValid(player, character) then
			return
		end
		local r = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local h = character:FindFirstChildOfClass("Humanoid")
		if not r or not h then
			return
		end
		grace(player, 2)
		if RagdollService.IsRagdolled(player) then
			RagdollService.Recover(player, 0.3)
		end
		CombatService.ClearStun(player)
		r.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(savedCFrame)
		if h.Health < savedHealth then
			HealthService.Heal(character, savedHealth - h.Health)
		end
		RagdollService.GrantIFrames(character, 0.5)
		local radius = tonumber(e.Radius)
		if radius and radius > 0 then
			for _, victim in Hitbox.AroundPoint(character, savedCFrame.Position, radius, MAX_AREA_TARGETS) do
				CombatService.ResolveHit(player, character, victim, tonumber(e.Damage) or 0, false, e.Knockback)
			end
		end
		notifyAbility:FireAllClients(character, characterId, ability.Id, "hit", { Position = savedCFrame.Position, Teleported = true })
	end)
end

-- ---------------------------------------------------------------------------
-- Requests
-- ---------------------------------------------------------------------------

--- Executa o efeito da habilidade e, se houver, o `Then` encadeado (Id <abilityId>_Then para animação/VFX próprios).
function runEffect(player: Fighter, character: Model, ability: CharacterDefs.AbilityDef, direction: Vector3)
	local handler = effects[ability.Effect.Type]
	if not handler then
		warn(("[AbilityService] efeito '%s' sem handler (habilidade %s)"):format(tostring(ability.Effect.Type), ability.Id))
		return
	end
	local ok, err = pcall(handler :: any, player, character, ability, direction)
	if not ok then
		warn(("[AbilityService] erro em %s: %s"):format(ability.Id, tostring(err)))
	end
	local nextEffect = ability.Effect.Then
	if typeof(nextEffect) == "table" and typeof(nextEffect.Type) == "string" then
		local chained: CharacterDefs.AbilityDef = table.clone(ability)
		chained.Id = ability.Id .. "_Then"
		chained.Effect = nextEffect
		local delay = tonumber(ability.Effect.ThenDelay) or 0
		task.delay(delay, function()
			if stillValid(player, character) then
				runEffect(player, character, chained, direction)
			end
		end)
	end
end

-- ---------------------------------------------------------------------------
-- D2 (dono, 2026-09-23): VARIAÇÕES DE GOLPE por contexto (estilo Jujutsu Shenanigans). A habilidade declara
-- `Variants = { Air | Falling | Sprint | OnDowned | Chain = Effect }` e o SERVIDOR escolhe pelo estado no momento:
--   OnDowned  alvo ragdollado/caído na frente (até CHAIN_DOWNED_RANGE studs)
--   Chain     emendada logo depois de outra habilidade (Variants.Chain[<IdAnterior>] ou Chain["*"], ≤ CHAIN_WINDOW s)
--   Falling   no ar caindo   ·   Air   no ar subindo/pulando   ·   Sprint   correndo (atributo Sprinting)
-- Prioridade nessa ordem. O Id continua o mesmo (cooldown/animação/VFX base); o cliente recebe a fase "variant"
-- e, se existir VFX "<Id>_<Variante>", toca por cima.
-- ---------------------------------------------------------------------------
local CHAIN_WINDOW = 2.0
local CHAIN_DOWNED_RANGE = 9

local function pickVariant(player: Fighter, character: Model, ability: CharacterDefs.AbilityDef, state: PlayerState): (CharacterDefs.AbilityDef, string?)
	local variants = ability.Variants
	if typeof(variants) ~= "table" then
		return ability, nil
	end
	local chosen: any, name: string? = nil, nil
	if variants.OnDowned then
		for _, victim in Hitbox.InFront(character, CHAIN_DOWNED_RANGE, 8, 6, 3) do
			if RagdollService.IsModelRagdolled(victim) or victim:GetAttribute("Downed") == true then
				chosen, name = variants.OnDowned, "OnDowned"
				break
			end
		end
	end
	if not chosen and typeof(variants.Chain) == "table" and state.lastAbilityId and os.clock() - state.lastAbilityAt <= CHAIN_WINDOW then
		local chain: any = variants.Chain
		local byId = chain[state.lastAbilityId] or chain["*"]
		if typeof(byId) == "table" and typeof(byId.Type) == "string" then
			chosen, name = byId, "Chain"
		elseif typeof(chain.Type) == "string" then
			chosen, name = chain, "Chain" -- Chain = Effect direto: vale depois de qualquer habilidade
		end
	end
	if not chosen then
		local air = CombatService.AirState(character)
		if air == "falling" and variants.Falling then
			chosen, name = variants.Falling, "Falling"
		elseif air ~= "ground" and variants.Air then
			chosen, name = variants.Air, "Air"
		elseif air == "ground" and variants.Sprint and player:GetAttribute("Sprinting") == true then
			chosen, name = variants.Sprint, "Sprint"
		end
	end
	if not chosen or typeof(chosen.Type) ~= "string" or not effects[chosen.Type] then
		return ability, nil
	end
	local variant: CharacterDefs.AbilityDef = table.clone(ability)
	variant.Effect = chosen
	return variant, name
end

--- Stand: a tecla só libera com maestria suficiente (StandConfig). Bots e modo DEV "sem cooldown" ignoram.
local function masteryMissing(player: Fighter, characterId: string, slot: number): number?
	local required = StandConfig.RequiredMastery(characterId, slot)
	local owner = Combatant.PlayerOf(player)
	if not required or not owner or player:GetAttribute("DevNoCooldown") == true then
		return nil
	end
	local profile = DataService.GetProfile(owner)
	local level = ProgressionConfig.MasteryLevel(if profile then profile.mastery[characterId] or 0 else 0)
	return if level < required then required else nil
end

local function deny(player: Fighter, slot: number, reason: string)
	Log.debug(("[AbilityService] %s slot %d negado: %s"):format(player.Name, slot, reason))
	Combatant.Notify(player, notifyAbilityDenied, slot, reason)
end

local function onRequestAbility(player: Fighter, slot: any, rawDirection: any)
	if not abilityLimiter:Allow(player) then
		return
	end
	if player:GetAttribute("NoAbilities") == true then
		return -- mod "só na mão" (ModService): sem habilidades
	end
	local state = getState(player)
	local now = os.clock()

	if typeof(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > CharacterDefs.PASSIVE_SLOT then
		return
	end

	-- 1..4 = ataques (despertos enquanto a forma durar); 5 = R (suporte)
	local ability = CharacterDefs.GetAbility(state.characterId, slot, AbilityService.IsAwakened(player))
	if not ability then
		return deny(player, slot, "no_ability")
	end
	local needMastery = masteryMissing(player, state.characterId, slot)
	if needMastery then
		return deny(player, slot, "mastery:" .. needMastery)
	end
	local character = Combatant.CharacterOf(player)
	if not character or not HealthService.IsAlive(character) then
		return deny(player, slot, "dead")
	end
	if not HealthService.CanFight(player) then
		return deny(player, slot, "cant_fight")
	end
	if CombatService.IsStunned(player) or CombatService.IsGrabbed(character) then
		return deny(player, slot, "stunned")
	end
	if RagdollService.IsRagdolled(player) then
		return deny(player, slot, "ragdoll")
	end
	local dashingUntil = player:GetAttribute("DashingUntil")
	if typeof(dashingUntil) == "number" and now < dashingUntil then
		return deny(player, slot, "dashing")
	end
	if CombatService.IsAttacking(player) then
		return deny(player, slot, "attacking") -- ação individual (dono, 2026-09-21): soco em curso
	end
	if CombatService.IsTimeSlowed(player) then
		return deny(player, slot, "timeslow") -- dentro do Domínio do Tempo não se age
	end
	local noCooldown = player:GetAttribute(ATTR_NO_COOLDOWN) == true
	if now < state.busyUntil and not noCooldown then
		return deny(player, slot, "busy")
	end
	local readyAt = state.cooldownReadyAt[ability.Id] or 0
	if now < readyAt and not noCooldown then
		return deny(player, slot, "cooldown")
	end
	if ability.OncePerAwakening and state.onceUsed[ability.Id] == state.awakenedUntil then
		return deny(player, slot, "once") -- Parada do Tempo / Bites the Dust: uma vez por despertar
	end
	if not effects[ability.Effect.Type] then
		warn(("[AbilityService] efeito '%s' sem handler (habilidade %s)"):format(ability.Effect.Type, ability.Id))
		return deny(player, slot, "no_handler")
	end

	-- Tudo validado: cobra o cooldown antes de executar (a ultimate não gasta carga: o Awakening já gastou)
	if not noCooldown then
		local timeSlow = player:GetAttribute("TimeSlow")
		local slowDiv = if typeof(timeSlow) == "number" and timeSlow > 0 and timeSlow < 1 then timeSlow else 1
		state.cooldownReadyAt[ability.Id] = now + ability.Cooldown / slowDiv
		state.busyUntil = now + ability.CastTime / slowDiv
		Combatant.Notify(player, notifyAbilityCooldown, slot, ability.Id, Workspace:GetServerTimeNow() + ability.Cooldown)
	end

	if ability.OncePerAwakening then
		state.onceUsed[ability.Id] = state.awakenedUntil
	end
	CombatService.NotifyAction(player) -- habilidade cancela emote em loop
	local chosen, variantName = pickVariant(player, character, ability, state)
	state.lastAbilityId = ability.Id
	state.lastAbilityAt = now
	if variantName then
		notifyAbility:FireAllClients(character, state.characterId, ability.Id, "variant", { Variant = variantName })
	end
	Log.debug(("[AbilityService] %s usou %s.%s%s (carga %d)"):format(player.Name, state.characterId, ability.Id, if variantName then " [" .. variantName .. "]" else "", state.energy))
	runEffect(player, character, chosen, sanitizeDirection(character, rawDirection))
end

local function onRequestAwaken(player: Fighter)
	if not awakenLimiter:Allow(player) then
		return
	end
	if player:GetAttribute("NoAbilities") == true then
		return -- mod "só na mão": sem ult
	end
	local state = getState(player)
	local character = Combatant.CharacterOf(player)
	if not character or not HealthService.IsAlive(character) or not HealthService.CanFight(player) then
		return
	end
	if CombatService.IsHardStunned(player) or RagdollService.IsRagdolled(player) then
		return
	end
	if AbilityService.IsAwakened(player) then
		return
	end
	local kit = CharacterDefs.Get(state.characterId)
	if not kit or #kit.AwakenedAbilities == 0 then
		return deny(player, 0, "no_awaken") -- Humano: sem Stand não desperta
	end
	local needMastery = masteryMissing(player, state.characterId, 0)
	if needMastery then
		return deny(player, 0, "mastery:" .. needMastery)
	end
	if state.energy < CharacterDefs.Energy.Max and player:GetAttribute(ATTR_INFINITE_ENERGY) ~= true then
		return deny(player, 0, "energy")
	end
	local cfg = CombatConfig.Awakening
	local cut = cfg.Cutscene
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local def = CharacterDefs.Get(state.characterId)
	local ultDuration = CharacterDefs.UltimateDuration(state.characterId, cfg.Duration)
	setEnergy(player, 0)
	-- Cutscene: parado (CutsceneUntil → WalkSpeed 0), sem agir (Stun), invencível; o modo só começa depois
	state.awakenedUntil = now + cut.Duration + ultDuration
	state.busyUntil = now + cut.Duration
	player:SetAttribute("CutsceneUntil", serverNow + cut.Duration)
	player:SetAttribute(ATTR_AWAKENED_UNTIL, serverNow + cut.Duration + ultDuration)
	player:SetAttribute("AwakenedDuration", ultDuration) -- HUD: contagem regressiva proporcional
	RagdollService.GrantIFrames(character, cut.Duration + cfg.IFrames)
	CombatService.Stun(player, cut.Duration, "awakening")
	CombatService.RestoreWalkSpeed(player)
	grace(player, cut.Duration + 1)
	-- Preso no lugar (vale no ar: ativou pulando fica flutuando até o fim da cutscene). Âncora no servidor
	-- replica e trava a física do cliente; a câmera da cutscene segue o root de qualquer jeito.
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local function release()
		if root and root.Anchored then
			root.Anchored = false
		end
	end
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Died:Once(release)
		end
		character.AncestryChanged:Once(release)
	end
	notifyAbility:FireAllClients(character, state.characterId, "Awakening", "start", { Duration = ultDuration, Cutscene = cut.Duration, BurstAt = cut.BurstAt })
	Log.debug(("[AbilityService] %s DESPERTOU (cutscene %.1fs + %ds)"):format(player.Name, cut.Duration, ultDuration))
	-- Estouro: quem estiver perto leva dano + empurrão (o único "ataque" da transformação)
	task.delay(cut.BurstAt, function()
		if states[player] ~= state or Combatant.CharacterOf(player) ~= character or not HealthService.IsAlive(character) then
			return
		end
		for _, victim in Hitbox.Around(character, cut.BurstRadius, 8) do
			CombatService.ResolveHit(player, character, victim, cut.BurstDamage, false, cut.BurstKnockback, { BreaksBlock = true })
		end
		-- "o tempo para": os outros congelam por FreezeSeconds (o cliente deles congela animação/tela)
		local freezeCfg = cut.FreezeByCharacter and cut.FreezeByCharacter[state.characterId]
		local freeze = if freezeCfg then tonumber(freezeCfg.Seconds) or 0 else 0
		if freeze > 0 then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local radius = tonumber(freezeCfg.Radius) or 0
			local untilT = Workspace:GetServerTimeNow() + freeze
			for _, other in Combatant.All() do
				local oc = Combatant.CharacterOf(other)
				local oroot = oc and oc:FindFirstChild("HumanoidRootPart") :: BasePart?
				if other == player or not oc or not oroot or not HealthService.IsAlive(oc) then
					continue
				end
				if radius > 0 and root and (oroot.Position - root.Position).Magnitude > radius then
					continue
				end
				local current = other:GetAttribute("CutsceneUntil")
				if typeof(current) ~= "number" or current < untilT then
					other:SetAttribute("CutsceneUntil", untilT)
				end
				CombatService.Stun(other, freeze, "frozen")
				CombatService.RestoreWalkSpeed(other)
				task.delay(freeze + 0.05, function()
					if Combatant.IsPresent(other) and Combatant.CharacterOf(other) == oc then
						CombatService.RestoreWalkSpeed(other)
					end
				end)
			end
		end
	end)
	task.delay(cut.Duration, function()
		release()
		if states[player] == state and Combatant.CharacterOf(player) == character then
			player:SetAttribute("CutsceneUntil", 0)
			CombatService.RestoreWalkSpeed(player) -- agora com o SpeedMultiplier do modo
			-- kit desperto entra pronto: avisa a HUD que os 4 slots estão livres
			for slot = 1, 4 do
				local a = CharacterDefs.GetAbility(state.characterId, slot, true)
				if a then
					state.cooldownReadyAt[a.Id] = nil
					Combatant.Notify(player, notifyAbilityCooldown, slot, a.Id, Workspace:GetServerTimeNow())
				end
			end
			-- Ultimate.Effect: dispara sozinho no fim da cutscene (Bruno: cúpula do tempo)
			local ultEffect = def and def.Ultimate and def.Ultimate.Effect
			if ultEffect and HealthService.IsAlive(character) then
				local synthetic = CharacterDefs.UltimateAbility(state.characterId)
				if synthetic then
					runEffect(player, character, synthetic, facing(character))
				end
			end
		end
	end)
	task.delay(cut.Duration + ultDuration, function()
		if states[player] == state and Combatant.CharacterOf(player) == character and os.clock() >= state.awakenedUntil then
			player:SetAttribute(ATTR_AWAKENED_UNTIL, 0)
			CombatService.RestoreWalkSpeed(player)
			notifyAbility:FireAllClients(character, state.characterId, "Awakening", "end")
			-- os 4 normais voltam com o cooldown que tinham
			for slot = 1, 4 do
				local a = CharacterDefs.GetAbility(state.characterId, slot, false)
				if a then
					local readyIn = math.max(0, (state.cooldownReadyAt[a.Id] or 0) - os.clock())
					Combatant.Notify(player, notifyAbilityCooldown, slot, a.Id, Workspace:GetServerTimeNow() + readyIn)
				end
			end
		end
	end)
end

--- Forma temporária (BossFormService): troca o personagem SEM respawn (o Model já foi trocado por quem
--- chamou). `characterId` nil = volta ao personagem escolhido antes. Zera cooldowns/carga.
local formPrevious: { [Instance]: string } = {}
--- [Admin/testes/bots] usa a habilidade do slot como se o jogador tivesse pedido.
function AbilityService.Use(player: Fighter, slot: number, direction: Vector3?)
	onRequestAbility(player, slot, direction)
end

--- [Bots/DEV] G: despertar (precisa de carga cheia, como o jogador).
function AbilityService.Awaken(player: Fighter)
	onRequestAwaken(player)
end

--- [Bots/DEV] define a carga da ult.
function AbilityService.SetEnergy(player: Fighter, value: number)
	setEnergy(player, value)
end

--- Está no CastTime de uma habilidade (busy)?
function AbilityService.IsBusy(player: Fighter): boolean
	local state = states[player]
	return state ~= nil and os.clock() < state.busyUntil
end

--- Carga atual da ult (0..Max).
function AbilityService.GetEnergy(player: Fighter): number
	local state = states[player]
	return if state then state.energy else 0
end

function AbilityService.SetForm(player: Fighter, characterId: string?)
	local state = getState(player)
	if characterId then
		if not formPrevious[player] then
			formPrevious[player] = state.characterId
		end
		state.characterId = characterId
	else
		state.characterId = formPrevious[player] or state.characterId
		formPrevious[player] = nil
	end
	state.cooldownReadyAt = {}
	state.awakenedUntil = 0
	state.damageMultiplierUntil = 0
	state.incomingMultiplierUntil = 0
	setEnergy(player, 0)
	player:SetAttribute(ATTR_AWAKENED_UNTIL, 0)
	player:SetAttribute("CharacterId", state.characterId)
end

--- [Mods/DEV] Troca o personagem na marra (sem checar posse/combate) e respawna. Fora da forma de boss.
function AbilityService.ForceCharacter(player: Player, characterId: string)
	if not CharacterDefs.Get(characterId) or formPrevious[player] then
		return
	end
	local state = getState(player)
	if state.characterId == characterId then
		return
	end
	state.characterId = characterId
	state.cooldownReadyAt = {}
	state.damageMultiplierUntil = 0
	state.incomingMultiplierUntil = 0
	player:SetAttribute("CharacterId", characterId)
	grace(player, 3)
	CharacterService.Load(player)
end

function AbilityService.IsInForm(player: Fighter): boolean
	return formPrevious[player] ~= nil
end

--- Regra comum da seleção e da mochila. Conferir ANTES de consumir qualquer item.
function AbilityService.CanChangeCharacter(player: Player): (boolean, string)
	if player:GetAttribute("InMatch") == true or player:GetAttribute("Tournament") == true or formPrevious[player] then
		return false, "Você não pode trocar de poder durante uma partida ou transformação."
	end
	local character = player.Character
	if not character or not HealthService.IsAlive(character) or player:GetAttribute("ChangingPower") == true then
		return false, "Espere seu personagem estar pronto para trocar de poder."
	end
	if CombatService.IsStunned(player) or CombatService.IsGrabbed(character) or RagdollService.IsRagdolled(player)
		or AbilityService.IsBusy(player) then
		return false, "Você não pode trocar de poder durante uma ação de combate."
	end
	local since = HealthService.SecondsSinceDamaged(player)
	if since < CharacterDefs.SwapOutOfCombatSeconds then
		return false, ("Espere %d s fora de combate para trocar de poder."):format(math.ceil(CharacterDefs.SwapOutOfCombatSeconds - since))
	end
	return true, ""
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
	if not AbilityService.CanChangeCharacter(player) then
		return
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
	grace(player, 3)
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
local function forceCharacter(player: Fighter, characterId: string)
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
local function resetCooldowns(player: Fighter)
	local state = getState(player)
	state.cooldownReadyAt = {}
	state.busyUntil = 0
	for slot = 1, CharacterDefs.PASSIVE_SLOT do
		local ability = CharacterDefs.GetAbility(state.characterId, slot, AbilityService.IsAwakened(player))
		if ability then
			Combatant.Notify(player, notifyAbilityCooldown, slot, ability.Id, Workspace:GetServerTimeNow())
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
	-- bots: estado por Model (respawn = Model novo)
	game:GetService("CollectionService"):GetInstanceRemovedSignal(Combatant.BotTag):Connect(function(model)
		states[model] = nil
		activeDomes[model] = nil
	end)
end

return AbilityService
