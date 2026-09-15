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
		incomingMultiplier = 1,
		incomingMultiplierUntil = 0,
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

function AbilityService.GetDamageMultiplier(player: Player): number
	local state = states[player]
	if not state or os.clock() > state.damageMultiplierUntil then
		return 1
	end
	return state.damageMultiplier
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
	local noCooldown = player:GetAttribute(ATTR_NO_COOLDOWN) == true
	if now < state.busyUntil and not noCooldown then
		return deny(player, slot, "busy")
	end
	local readyAt = state.cooldownReadyAt[ability.Id] or 0
	if now < readyAt and not noCooldown then
		return deny(player, slot, "cooldown")
	end
	if state.energy < ability.EnergyCost and player:GetAttribute(ATTR_INFINITE_ENERGY) ~= true then
		return deny(player, slot, "energy")
	end
	local handler = effects[ability.Effect.Type]
	if not handler then
		warn(("[AbilityService] efeito '%s' sem handler (habilidade %s)"):format(ability.Effect.Type, ability.Id))
		return deny(player, slot, "no_handler")
	end

	-- Tudo validado: cobra antes de executar
	setEnergy(player, state.energy - ability.EnergyCost)
	if not noCooldown then
		state.cooldownReadyAt[ability.Id] = now + ability.Cooldown
		state.busyUntil = now + ability.CastTime
		notifyAbilityCooldown:FireClient(player, slot, ability.Id, Workspace:GetServerTimeNow() + ability.Cooldown)
	end

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
	player:LoadCharacter()
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
	Remotes.GetEvent(Remotes.Events.RequestAbility).OnServerEvent:Connect(onRequestAbility)
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
