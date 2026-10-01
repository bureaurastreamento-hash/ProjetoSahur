--!strict
--[[
	HealthService (servidor)
	Autoridade sobre vida: vida máxima, dano, cura, morte, respawn.
	Usa o Humanoid como armazenamento (replica de graça pro cliente), mas
	TODA alteração passa por aqui. Nenhum outro script deve mexer em Humanoid.Health.
	Lutadores = Players e BOTS (Combatant.Fighter): bots entram por HealthService.SetupBot(model) — mesma
	vida/regen/morte, sem HUD, sem crédito de kill/pontos (Died só dispara para vítima Player; killer bot = nil).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local NpcCombatRules = require(Modules.NpcCombatRules)
local NpcLifecycle = require(Modules.NpcLifecycleConfig)
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local ProgressionConfig = require(Modules.ProgressionConfig)
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local RagdollRig = require(Modules:WaitForChild("RagdollRig"))
local Combatant = require(Modules:WaitForChild("Combatant"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local PvpService = require(script.Parent.PvpService)

local respawnLimiter = RateLimiter.new(1, 1)
local timeLimiter = RateLimiter.new(2, 1)

local HealthService = {}

type Fighter = Combatant.Fighter

local ATTR_LAST_ATTACKER = "LastAttackerUserId"
local ATTR_LAST_ATTACK_TIME = "LastAttackTime"
local ATTR_IFRAMES = "IFramesUntil" -- os.clock; RagdollService concede (ragdoll cancel/levantar)
-- Preso num agarrão: só quem agarrou acerta a vítima até LockedUntil (terceiro não interrompe o agarrão)
local ATTR_LOCKED_TO = "LockedToUserId"
local ATTR_LOCKED_UNTIL = "LockedUntil"
local KILL_CREDIT_WINDOW = 8
local VOID_Y = -80 -- abaixo disso = caiu do mapa
local warnedRig = false -- segundos que o último atacante recebe crédito do kill

local notifyHealth: RemoteEvent
local notifyKill: RemoteEvent
local notifyKnockback: RemoteEvent

--- Disparado no servidor quando um JOGADOR morre: (victim: Player, killer: Player?) — killer bot = nil.
HealthService.Died = Instance.new("BindableEvent")
--- Disparado quando QUALQUER lutador (jogador ou bot) morre: (victim: Fighter, killer: Fighter?). BotService usa.
HealthService.FighterDied = Instance.new("BindableEvent")
--- Disparado a cada dano aplicado (victim: Model, amount: number, attacker: Fighter?). BossService usa para crédito.
HealthService.Damaged = Instance.new("BindableEvent")

local bots: { [Model]: boolean } = {} -- bots registrados (regen/queda no vazio)
local contributions: { [Model]: { [Player]: { damage: number, at: number } } } = setmetatable({}, { __mode = "k" }) :: any

function HealthService.ClearPveCredit(model: Model)
	contributions[model] = nil
end

--- Participação real e recente em chefe, com proximidade no momento da morte.
function HealthService.PveParticipants(model: Model): { Player }
	local result = {}
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return result end
	local config = ProgressionConfig.PveCredit
	local credits = contributions[model]
	if not credits then return result end
	for player, credit in credits do
		local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if player.Parent == Players and playerRoot and playerRoot:IsA("BasePart")
			and credit.damage >= humanoid.MaxHealth * config.MinDamageFraction
			and os.clock() - credit.at <= config.Seconds
			and (playerRoot.Position - root.Position).Magnitude <= config.Radius then
			table.insert(result, player)
		end
	end
	return result
end

local ATTR_LAST_COMBAT_TIME = "LastCombatTime" -- deu OU levou dano (troca de personagem espera isto)

--- Marca que o jogador está em combate (deu dano). CombatService chama; a troca de personagem espera.
function HealthService.MarkInCombat(player: Fighter)
	local character = Combatant.CharacterOf(player)
	if character then
		character:SetAttribute(ATTR_LAST_COMBAT_TIME, os.clock())
	end
end

--- Segundos desde a última vez que o jogador LEVOU ou DEU dano (math.huge se nunca / sem personagem).
--- Dono (2026-09-21): quem ataca também não pode trocar de personagem.
function HealthService.SecondsSinceDamaged(player: Fighter): number
	local character = Combatant.CharacterOf(player)
	if not character then
		return math.huge
	end
	local lastHit = character:GetAttribute(ATTR_LAST_ATTACK_TIME)
	local lastCombat = character:GetAttribute(ATTR_LAST_COMBAT_TIME)
	local last = math.max(if typeof(lastHit) == "number" then lastHit else -math.huge, if typeof(lastCombat) == "number" then lastCombat else -math.huge)
	if last == -math.huge then
		return math.huge
	end
	return os.clock() - last
end

--- Jogadores com atributo CanFight == false não dão nem recebem dano (ex.: lobby).
function HealthService.CanFight(player: Fighter?): boolean
	return player == nil or (player:GetAttribute("CanFight") ~= false and player:GetAttribute("DataTransaction") ~= true)
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

--- Morte com peso: solta as juntas (RagdollRig, permanente até o respawn) e empurra o corpo para
--- longe do último atacante. O empurrão vai pelo NotifyKnockback (o cliente é dono da física).
local function ragdoll(player: Fighter, character: Model, attacker: Fighter?)
	if character:GetAttribute("BossRig") ~= nil then
		-- forma de boss (rig por peças): morto NÃO ragdolla (dono, 2026-09-21: o corpo batia no cenário e
		-- saía voando). Congela no lugar.
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.AssemblyLinearVelocity = Vector3.zero
				d.Anchored = true
				d.CanCollide = false
			end
		end
		return
	end
	RagdollRig.Apply(character) -- no-op se já estava em ragdoll de combate
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attackerChar = Combatant.CharacterOf(attacker)
	local attackerRoot = attackerChar and attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local away = if attackerRoot then root.Position - attackerRoot.Position else -root.CFrame.LookVector
		away = Vector3.new(away.X, 0, away.Z)
		local direction = if away.Magnitude > 0.1 then away.Unit else -root.CFrame.LookVector
		if Combatant.IsPlayer(player) then
			notifyKnockback:FireClient(player :: Player, direction, CombatConfig.Ragdoll.PushSpeed, 0.25)
		else
			-- bot: o servidor é dono da física
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") and not part.Anchored then
					part.AssemblyLinearVelocity = direction * CombatConfig.Ragdoll.PushSpeed + Vector3.new(0, 8, 0)
				end
			end
		end
	end
end

local function setupCharacter(player: Fighter, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		warn(("[HealthService] %s spawnou sem Humanoid"):format(player.Name))
		return
	end
	local isPlayer = Combatant.IsPlayer(player)

	if isPlayer and humanoid.RigType ~= Enum.HumanoidRigType.R6 and not warnedRig then
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
	-- forma de boss (BossFormService) traz a própria vida/velocidade no Model
	local maxOverride = character:GetAttribute("MaxHealth")
	local speedOverride = character:GetAttribute("WalkSpeed")
	humanoid.MaxHealth = if typeof(maxOverride) == "number" then maxOverride else CombatConfig.MaxHealth
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = if typeof(speedOverride) == "number" then speedOverride else CombatConfig.WalkSpeed
	humanoid.BreakJointsOnDeath = false

	character:SetAttribute(ATTR_LAST_ATTACKER, nil)
	character:SetAttribute(ATTR_LAST_ATTACK_TIME, nil)

	humanoid.Died:Once(function()
		local killer: Fighter? = nil
		local lastId = character:GetAttribute(ATTR_LAST_ATTACKER)
		local lastTime = character:GetAttribute(ATTR_LAST_ATTACK_TIME)
		if typeof(lastId) == "number" and typeof(lastTime) == "number" and (os.clock() - lastTime) <= KILL_CREDIT_WINDOW then
			killer = Combatant.ByUserId(lastId)
		end
		if CombatConfig.Ragdoll.Enabled then
			ragdoll(player, character, if typeof(lastId) == "number" then Combatant.ByUserId(lastId) else nil)
		end
		Log.debug(("[HealthService] %s morreu (killer: %s)"):format(player.Name, Combatant.Name(killer)))
		local creditedPlayer = Combatant.PlayerOf(killer)
		local openWorld = isPlayer and PvpService.OpenWorldKill(player :: Player, creditedPlayer)
		HealthService.FighterDied:Fire(player, killer)
		if isPlayer then
			-- crédito/kill feed/progressão só entre jogadores: bot que mata não pontua, bot que morre não conta
			local killerPlayer = Combatant.PlayerOf(killer)
			notifyKill:FireAllClients(killerPlayer, player)
			HealthService.Died:Fire(player, killerPlayer, PvpService.OnDeath(player :: Player, killerPlayer), openWorld)
		end
	end)

	Combatant.Notify(player, notifyHealth, humanoid.Health, humanoid.MaxHealth)
	Log.debug(("[HealthService] %s pronto: %d HP"):format(player.Name, humanoid.MaxHealth))
end

--- Registra um BOT (BotService): vida/regen/morte iguais às do jogador; sem HUD nem crédito.
function HealthService.SetupBot(model: Model)
	bots[model] = true
	setupCharacter(model, model)
	model.AncestryChanged:Connect(function()
		if not model.Parent then
			bots[model] = nil
		end
	end)
end

-- ---------------------------------------------------------------------------
-- API pública (usada por outros services)
-- ---------------------------------------------------------------------------

--- Prioridade: quem NÃO pode levar golpe de `attacker` agora. Vale i-frames (ragdoll cancel, levantar,
--- cutscene do despertar, agarrão em curso), modo deus e a trava do agarrão (só o agarrador acerta a
--- vítima presa). Habilidades que "pegam" alguém (agarrão) devem checar antes de agarrar.
function HealthService.IsInvulnerable(victim: Model, attacker: Fighter?): boolean
	local victimFighter = Combatant.Of(victim)
	local victimPlayer, attackerPlayer = Combatant.PlayerOf(victimFighter), Combatant.PlayerOf(attacker)
	if not NpcCombatRules.CanDamage(attacker, victimFighter or victim) then return true end
	if (victimPlayer and victimPlayer:GetAttribute("FactionPending") == true)
		or (attackerPlayer and attackerPlayer:GetAttribute("FactionPending") == true) then return true end
	if victimPlayer and attackerPlayer and not PvpService.CanDamage(attackerPlayer, victimPlayer) then return true end
	if victimFighter and victimFighter:GetAttribute("Invulnerable") == true then
		return true -- modo deus (AdminService)
	end
	if attacker and victimFighter and attacker ~= victimFighter then
		-- torneio "Último de pé" em duplas/clãs (D3): companheiro de time não machuca companheiro
		local team = victimFighter:GetAttribute("TournamentTeam")
		if team ~= nil and attacker:GetAttribute("TournamentTeam") == team then
			return true
		end
	end
	local iframes = victim:GetAttribute(ATTR_IFRAMES)
	if typeof(iframes) == "number" and os.clock() < iframes then
		return true -- i-frames (ragdoll cancel / levantar / cutscene / agarrando)
	end
	local lockedUntil = victim:GetAttribute(ATTR_LOCKED_UNTIL)
	if typeof(lockedUntil) == "number" and os.clock() < lockedUntil then
		local owner = victim:GetAttribute(ATTR_LOCKED_TO)
		if not attacker or Combatant.UserId(attacker) ~= owner then
			return true -- preso num agarrão: só o agarrador acerta
		end
	end
	return false
end

--- Trava a vítima a um atacante por `seconds` (agarrão): só ele consegue acertá-la. `attacker` nil = solta.
function HealthService.LockTo(victim: Model, attacker: Fighter?, seconds: number?)
	if attacker and seconds and seconds > 0 then
		victim:SetAttribute(ATTR_LOCKED_TO, Combatant.UserId(attacker))
		victim:SetAttribute(ATTR_LOCKED_UNTIL, os.clock() + seconds)
	else
		victim:SetAttribute(ATTR_LOCKED_TO, nil)
		victim:SetAttribute(ATTR_LOCKED_UNTIL, 0)
	end
end

--- Aplica dano. Retorna o dano efetivamente aplicado (0 se alvo inválido/morto).
function HealthService.ApplyDamage(victim: Model, amount: number, attacker: Fighter?): number
	local humanoid = getHumanoid(victim)
	if not humanoid or humanoid.Health <= 0 or amount <= 0 then
		return 0
	end
	local victimFighter = Combatant.Of(victim)
	local victimPlayer = Combatant.PlayerOf(victimFighter)
	if not HealthService.CanFight(attacker) or not HealthService.CanFight(victimFighter) then
		return 0
	end
	if HealthService.IsInvulnerable(victim, attacker) then
		return 0
	end
	if attacker and victimFighter and attacker ~= victimFighter then
		-- mesmo time (Teams/duelo 2v2): sem fogo amigo
		local teamA, teamB = attacker:GetAttribute("TeamId"), victimFighter:GetAttribute("TeamId")
		if teamA ~= nil and teamA == teamB then
			return 0
		end
	end

	if attacker then
		victim:SetAttribute(ATTR_LAST_ATTACKER, Combatant.UserId(attacker))
		victim:SetAttribute(ATTR_LAST_ATTACK_TIME, os.clock())
		victim:SetAttribute(ATTR_LAST_COMBAT_TIME, os.clock())
	end
	local attackerPlayer = Combatant.PlayerOf(attacker)
	if attackerPlayer and victimPlayer then PvpService.RecordHit(attackerPlayer, victimPlayer) end
	local before = humanoid.Health
	if attackerPlayer and victim:GetAttribute("FXEnemy") == true then
		local ledger = contributions[victim] or {}
		local previous = ledger[attackerPlayer]
		ledger[attackerPlayer] = { damage = (if previous then previous.damage else 0) + math.min(before, amount), at = os.clock() }
		contributions[victim] = ledger
	end
	humanoid.Health = math.max(0, before - amount)
	local dealt = before - humanoid.Health
	if dealt > 0 then victim:SetAttribute("LastDamageReceived", os.clock()) end

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
	notifyKnockback = Remotes.GetEvent(Remotes.Events.NotifyKnockback)
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
			for _, fighter in Combatant.All() do
				local character = Combatant.CharacterOf(fighter)
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				-- Caiu do mapa: mata (respawn normal) em vez de cair para sempre
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and humanoid and humanoid.Health > 0 and root.Position.Y < VOID_Y then
					HealthService.Kill(character :: Model)
					continue
				end
				if character and humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
					local npc = character:GetAttribute("FXEnemy") == true
					local regen = if NpcLifecycle.IsBoss(character:GetAttribute("StoryKillKind")) then NpcLifecycle.BossRegen else NpcLifecycle.MobRegen
					local lastHit = character:GetAttribute("LastDamageReceived") or character:GetAttribute(ATTR_LAST_ATTACK_TIME)
					local delay = if npc then regen.Delay else CombatConfig.Regen.Delay
					if typeof(lastHit) ~= "number" or now - lastHit >= delay then
						HealthService.Heal(character, if npc then humanoid.MaxHealth * regen.Fraction else CombatConfig.Regen.PerSecond)
						if npc and humanoid.Health >= humanoid.MaxHealth then HealthService.ClearPveCredit(character) end
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
