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
					CombatService.ResolveHit(player, character, victim, e.Damage, false, e.Knockback, { KnockbackDirection = dir })
					local victimPlayer = Players:GetPlayerFromCharacter(victim)
					if victimPlayer and typeof(e.StunSeconds) == "number" then
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
local SPIN_DEFAULT = 1.25 -- voltas por segundo
-- posição relativa da vítima no giro (mesma fórmula do cliente: AbilityController.startGrabbed)
local function spinAngle(e: any, elapsed: number): number
	return elapsed * (tonumber(e.Spin) or SPIN_DEFAULT) * math.pi * 2
end
--- Solda a vítima na frente do atacante (Weld HRP→HRP no servidor: todo mundo vê a mesma posição, sem
--- atraso). A física da vítima passa para o cliente do atacante durante o Carry. Retorna a função que solta.
local function attachVictim(attacker: Player, attackerRoot: BasePart, victim: Model, offset: number, lift: number?, spin: number?, e: any): () -> ()
	local vRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
	local vHum = victim:FindFirstChildOfClass("Humanoid")
	if not vRoot then
		return function() end
	end
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
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
	vRoot.AssemblyLinearVelocity = Vector3.zero
	weld.Parent = vRoot
	pcall(function()
		vRoot:SetNetworkOwner(attacker)
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
		if vHum and not (victimPlayer and victimPlayer:GetAttribute("Ragdolled") == true) then
			vHum.PlatformStand = false
		end
		pcall(function()
			if victimPlayer then
				vRoot:SetNetworkOwner(victimPlayer)
			else
				vRoot:SetNetworkOwnershipAuto()
			end
		end)
	end
end

effects.Grab = function(player, character, ability, direction)
	local e = ability.Effect
	local characterId = getState(player).characterId
	local finish = if typeof(e.Finish) == "string" then e.Finish else "Slam"
	local maxDuration = e.Duration * CharacterDefs.DashTuning.ForwardScale
	AntiExploitService.Grace(player, maxDuration + e.Carry + 1.0)
	CombatService.SetSuperArmor(player, maxDuration + e.Carry + 0.2)
	-- Prioridade (dono, 2026-09-16): executando um agarrão não se leva golpe, do início ao release.
	-- Se a investida não pegar ninguém, a invencibilidade acaba junto com ela.
	RagdollService.GrantIFrames(character, maxDuration + 0.1)
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
			for _, candidate in Hitbox.InDirection(character, dir, e.Range, e.Width, e.Height, 2) do
				-- não agarra quem está invencível (cutscene, i-frames, preso em outro agarrão)
				if not HealthService.IsInvulnerable(candidate, player) then
					caught = candidate
					break
				end
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
		local victimPlayer = Players:GetPlayerFromCharacter(victim)
		RagdollService.GrantIFrames(character, e.Carry + 0.3)
		HealthService.LockTo(victim, player, e.Carry + 0.5) -- terceiro não tira a vítima do agarrão
		if victimPlayer then
			CombatService.CancelBlock(victimPlayer)
			CombatService.Stun(victimPlayer, e.Carry + 0.3, "grabbed")
			AntiExploitService.Grace(victimPlayer, e.Carry + 1.5)
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
		RagdollService.ClearIFrames(character)
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

effects.Teleport = function(player, character, ability, direction)
	local e = ability.Effect
	-- teleporte real (atravessa obstáculos, encaixa no chão) — mesmo do Q do Swift
	if not MovementService.Teleport(player, character, direction, e.Distance) then
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
	if ability.EnergyCost >= CharacterDefs.Energy.Max and not AbilityService.IsAwakened(player) then
		return deny(player, slot, "use_g") -- ultimate: só no modo despertado (G = cutscene de transformação)
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
	local cut = cfg.Cutscene
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	setEnergy(player, 0)
	-- Cutscene: parado (CutsceneUntil → WalkSpeed 0), sem agir (Stun), invencível; o modo só começa depois
	state.awakenedUntil = now + cut.Duration + cfg.Duration
	state.busyUntil = now + cut.Duration
	player:SetAttribute("CutsceneUntil", serverNow + cut.Duration)
	player:SetAttribute(ATTR_AWAKENED_UNTIL, serverNow + cut.Duration + cfg.Duration)
	RagdollService.GrantIFrames(character, cut.Duration + cfg.IFrames)
	CombatService.Stun(player, cut.Duration, "awakening")
	CombatService.RestoreWalkSpeed(player)
	AntiExploitService.Grace(player, cut.Duration + 1)
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
	notifyAbility:FireAllClients(character, state.characterId, "Awakening", "start", { Duration = cfg.Duration, Cutscene = cut.Duration, BurstAt = cut.BurstAt })
	Log.debug(("[AbilityService] %s DESPERTOU (cutscene %.1fs + %ds)"):format(player.Name, cut.Duration, cfg.Duration))
	-- Estouro: quem estiver perto leva dano + empurrão (o único "ataque" da transformação)
	task.delay(cut.BurstAt, function()
		if states[player] ~= state or player.Character ~= character or not HealthService.IsAlive(character) then
			return
		end
		for _, victim in Hitbox.Around(character, cut.BurstRadius, 8) do
			CombatService.ResolveHit(player, character, victim, cut.BurstDamage, false, cut.BurstKnockback, { BreaksBlock = true })
		end
		-- "o tempo para": os outros congelam por FreezeSeconds (o cliente deles congela animação/tela)
		local freeze = tonumber(cut.FreezeSeconds) or 0
		if freeze > 0 then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local radius = tonumber(cut.FreezeRadius) or 0
			local untilT = Workspace:GetServerTimeNow() + freeze
			for _, other in Players:GetPlayers() do
				local oc = other.Character
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
					if other.Parent == Players and other.Character == oc then
						CombatService.RestoreWalkSpeed(other)
					end
				end)
			end
		end
	end)
	task.delay(cut.Duration, function()
		release()
		if states[player] == state and player.Character == character then
			player:SetAttribute("CutsceneUntil", 0)
			CombatService.RestoreWalkSpeed(player) -- agora com o SpeedMultiplier do modo
		end
	end)
	task.delay(cut.Duration + cfg.Duration, function()
		if states[player] == state and player.Character == character and os.clock() >= state.awakenedUntil then
			player:SetAttribute(ATTR_AWAKENED_UNTIL, 0)
			CombatService.RestoreWalkSpeed(player)
			notifyAbility:FireAllClients(character, state.characterId, "Awakening", "end")
		end
	end)
end

--- Forma temporária (BossFormService): troca o personagem SEM respawn (o Model já foi trocado por quem
--- chamou). `characterId` nil = volta ao personagem escolhido antes. Zera cooldowns/carga.
local formPrevious: { [Player]: string } = {}
--- [Admin/testes] usa a habilidade do slot como se o jogador tivesse pedido.
function AbilityService.Use(player: Player, slot: number, direction: Vector3?)
	onRequestAbility(player, slot, direction)
end

function AbilityService.SetForm(player: Player, characterId: string?)
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

function AbilityService.IsInForm(player: Player): boolean
	return formPrevious[player] ~= nil
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
	if player:GetAttribute("InMatch") == true or formPrevious[player] then
		return -- troca só fora do round / fora da forma de boss
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
