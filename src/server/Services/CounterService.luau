--!strict
--[[
	CounterService (servidor) — ANTI 2v1 "Revide" (D1, dono 2026-09-23).
	Quando MinAttackers+ lutadores DISTINTOS (jogadores ou bots) acertam o mesmo alvo dentro de Window s,
	o alvo está "em desvantagem": todo dano que ele leva nesse estado carrega a barra Revide
	(CombatConfig.Counter). Cheia, o cliente pede RequestCounter (tecla E / L3 / botão de toque) e o servidor,
	depois de validar, dispara o CONTRA-ATAQUE: i-frames + tira o hitstun, anima em todos
	(NotifyAbility "Shared"/"Counter") e Delay s depois acerta TODO MUNDO em volta (360°), quebrando block
	(é a punição do 2v1), com dano + knockback/ragdoll curto.
	Servidor autoritativo: a barra vive aqui e é replicada pelos atributos do lutador
	  CounterCharge  (0..Threshold; HUD mostra só quando > 0)
	  CounterReadyAt (GetServerTimeNow em que o cooldown acaba)
	Lutador = Combatant.Fighter (Player ou bot): bots também revidam (BotService chama IsReady/Use).
	Agressor NPC (boss/traidor sem Fighter) NÃO conta: o 2v1 é entre lutadores.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local Combatant = require(Modules:WaitForChild("Combatant"))
local Hitbox = require(Modules:WaitForChild("Hitbox"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))

local CounterService = {}

type Fighter = Combatant.Fighter

local ATTR_CHARGE = "CounterCharge"
local ATTR_READY_AT = "CounterReadyAt"

type State = {
	attackers: { [number]: number }, -- userId do agressor -> os.clock() do último acerto
	charge: number,
	disadvantagedAt: number, -- último instante em desvantagem (-inf = nunca)
	readyAt: number, -- os.clock() em que o cooldown acaba
	usingUntil: number, -- contra-ataque em curso
}

local states: { [Instance]: State } = {}
local notifyAbility: RemoteEvent
local limiter = RateLimiter.new(6, 1)

local function newState(): State
	return { attackers = {}, charge = 0, disadvantagedAt = -math.huge, readyAt = 0, usingUntil = 0 }
end

local function getState(fighter: Fighter): State
	local s = states[fighter]
	if not s then
		s = newState()
		states[fighter] = s
	end
	return s
end

--- Publica a barra no atributo (só quando o inteiro muda: não spamma replicação).
local function publish(fighter: Fighter, s: State)
	local value = math.floor(s.charge + 0.5)
	if fighter:GetAttribute(ATTR_CHARGE) ~= value then
		fighter:SetAttribute(ATTR_CHARGE, value)
	end
end

local function reset(fighter: Fighter)
	local s = states[fighter]
	if not s then
		return
	end
	table.clear(s.attackers)
	s.charge = 0
	s.disadvantagedAt = -math.huge
	publish(fighter, s)
end

--- Agressores distintos que acertaram há menos de Window s (limpa os velhos).
local function distinctAttackers(s: State, now: number): number
	local cfg = CombatConfig.Counter
	local count = 0
	for userId, at in s.attackers do
		if now - at > cfg.Window then
			s.attackers[userId] = nil
		else
			count += 1
		end
	end
	return count
end

local function onDamaged(victim: Model, amount: number, attacker: Fighter?)
	if not attacker or amount <= 0 then
		return
	end
	local victimFighter = Combatant.Of(victim)
	if not victimFighter or victimFighter == attacker then
		return
	end
	if not (Combatant.IsPlayer(attacker) or Combatant.IsBot(attacker)) then
		return -- boss/traidor/boneco: não é 2v1
	end
	local cfg = CombatConfig.Counter
	local s = getState(victimFighter)
	local now = os.clock()
	s.attackers[Combatant.UserId(attacker)] = now
	if distinctAttackers(s, now) < cfg.MinAttackers then
		return
	end
	s.disadvantagedAt = now
	if now < s.readyAt then
		return -- em cooldown: não carrega (evita E encadeado)
	end
	local before = s.charge
	s.charge = math.min(cfg.Threshold, s.charge + amount * cfg.ChargePerDamage)
	if s.charge >= cfg.Threshold and before < cfg.Threshold then
		Log.debug(("[CounterService] %s: Revide PRONTO (%d agressores)"):format(victimFighter.Name, distinctAttackers(s, now)))
	end
	publish(victimFighter, s)
end

--- Barra cheia e pode usar agora? (BotService pergunta antes de chamar Use)
function CounterService.IsReady(fighter: Fighter): boolean
	local s = states[fighter]
	if not s or s.charge < CombatConfig.Counter.Threshold then
		return false
	end
	local now = os.clock()
	return now >= s.readyAt and now >= s.usingUntil
end

--- Motivo pelo qual NÃO pode revidar agora (nil = pode). Hitstun de soco e RAGDOLL não impedem: o Revide é a
--- fuga do 2v1 e num 2v1 você vive no chão (teste 25/09: 2 bots = ragdoll atrás de ragdoll) — ele levanta na hora,
--- como o ragdoll cancel do Q. Stun duro (parry/guard break/habilidade), agarrão, cutscene e Domínio do Tempo impedem.
local function blockedReason(fighter: Fighter, character: Model): string?
	if not HealthService.IsAlive(character) or not HealthService.CanFight(fighter) then
		return "dead"
	end
	if CombatService.IsHardStunned(fighter) then
		return "stunned"
	end
	if CombatService.IsGrabbed(character) then
		return "grabbed"
	end
	local cutscene = fighter:GetAttribute("CutsceneUntil")
	if typeof(cutscene) == "number" and Workspace:GetServerTimeNow() < cutscene then
		return "cutscene"
	end
	if CombatService.IsTimeSlowed(fighter) then
		return "timeslow"
	end
	return nil
end

--- Dispara o contra-ataque (já validado). Retorna true se saiu.
function CounterService.Use(fighter: Fighter): boolean
	local cfg = CombatConfig.Counter
	local s = getState(fighter)
	local character = Combatant.CharacterOf(fighter)
	if not character or not CounterService.IsReady(fighter) then
		return false
	end
	local reason = blockedReason(fighter, character)
	if reason then
		Log.debug(("[CounterService] %s: Revide negado (%s)"):format(fighter.Name, reason))
		return false
	end
	local now = os.clock()
	s.charge = 0
	table.clear(s.attackers)
	s.disadvantagedAt = -math.huge
	s.readyAt = now + cfg.Cooldown
	s.usingUntil = now + cfg.Delay + 0.35
	publish(fighter, s)
	fighter:SetAttribute(ATTR_READY_AT, Workspace:GetServerTimeNow() + cfg.Cooldown)

	-- fuga: levanta do ragdoll, sai do hitstun, fica intocável durante o giro e não cai
	RagdollService.Recover(fighter)
	CombatService.ClearStun(fighter)
	CombatService.CancelBlock(fighter)
	CombatService.SetSuperArmor(fighter, cfg.Invuln)
	RagdollService.GrantIFrames(character, cfg.Invuln)
	CombatService.NotifyAction(fighter)
	notifyAbility:FireAllClients(character, "Shared", "Counter", "start", { Radius = cfg.Radius })
	Log.debug(("[CounterService] %s revidou"):format(fighter.Name))

	task.delay(cfg.Delay, function()
		if not Combatant.IsPresent(fighter) or Combatant.CharacterOf(fighter) ~= character or not HealthService.IsAlive(character) then
			return
		end
		local hits = 0
		local around = Hitbox.Around(character, cfg.Radius, cfg.MaxTargets)
		local kinds = {}
		for _, victim in around do
			local kind = CombatService.ResolveHit(fighter, character, victim, cfg.Damage, false, cfg.Knockback, { BreaksBlock = true })
			kinds[#kinds + 1] = victim.Name .. "=" .. tostring(kind)
			if kind ~= "immune" then
				hits += 1
			end
		end
		Log.debug(("[CounterService] %s: giro acertou %d de %d (%s)"):format(fighter.Name, hits, #around, table.concat(kinds, ", ")))
		notifyAbility:FireAllClients(character, "Shared", "Counter", "hit", { Hits = hits })
	end)
	return true
end

local function onRequestCounter(player: Player)
	if not limiter:Allow(player) then
		return
	end
	if not CounterService.IsReady(player) then
		return -- cliente atrasado/cheat: ignora em silêncio
	end
	CounterService.Use(player)
end

--- Tick lento: a barra zera Window s depois de a desvantagem acabar (e limpa agressores velhos).
local function tick()
	local cfg = CombatConfig.Counter
	local now = os.clock()
	for fighter, s in states do
		if not Combatant.IsPresent(fighter) then
			states[fighter] = nil
		elseif s.charge > 0 and distinctAttackers(s, now) < cfg.MinAttackers and now - s.disadvantagedAt > cfg.Window then
			s.charge = 0
			publish(fighter, s)
		end
	end
end

function CounterService.Init()
	notifyAbility = Remotes.GetEvent(Remotes.Events.NotifyAbility)
end

function CounterService.Start()
	Remotes.GetEvent(Remotes.Events.RequestCounter).OnServerEvent:Connect(onRequestCounter)
	HealthService.Damaged.Event:Connect(onDamaged)
	HealthService.FighterDied.Event:Connect(function(victim: Instance)
		reset(victim)
	end)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			reset(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			tick()
		end
	end)
	Log.debug("[CounterService] pronto (anti-2v1: E)")
end

return CounterService
