--!strict
--[[
	BossService (servidor)
	Altar no mapa (Workspace.Sahur.ArenaExtras.BossAltar) com ProximityPrompt: invoca um boss NPC
	(rig R6 escalado, tag "Combatant" para a Hitbox/HealthService tratarem como alvo normal).
	IA simples em loop: alvo = jogador vivo mais perto dentro de BossConfig.ArenaRadius de BossArena;
	anda com Humanoid:MoveTo; golpes por alcance (Swipe/Slam; Charge na fase 2) com telegraph
	(anel vermelho no chão) antes do dano. Dano nos jogadores via CombatService.ResolveNpcHit
	(respeita block). Dano recebido é creditado por HealthService.Damaged -> recompensa
	proporcional (BossConfig.Reward*) via DataService.AddCoins.

	Estados: Ready -> Fighting -> Cooldown -> Ready. BillboardGui no altar mostra o estado.
	NotifyBoss(event, data) para a HUD (BossController).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local BossConfig = require(Modules:WaitForChild("BossConfig"))
local Hitbox = require(Modules:WaitForChild("Hitbox"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))

local BossService = {}

type Fight = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	summoner: Player,
	damageBy: { [Player]: number },
	phase: number,
	cooldowns: { [string]: number }, -- os.clock() em que o golpe libera
	lastSeenPlayer: number,
	finished: boolean,
	target: Player?,
	targetChosenAt: number,
	recentHits: { { t: number, amount: number } }, -- golpes recebidos (janela do enrage)
	enragedUntil: number,
	enrageReadyAt: number,
}

local state = "Ready" -- Ready | Fighting | Cooldown | Missing
local fight: Fight? = nil
local cooldownUntil = 0
local altar: BasePart? = nil
local spawnPart: BasePart? = nil
local arenaPart: BasePart? = nil
local prompt: ProximityPrompt? = nil
local statusLabel: TextLabel? = nil
local notifyBoss: RemoteEvent

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

local function broadcast(event: string, data: { [string]: any })
	data.event = event
	notifyBoss:FireAllClients(event, data)
end

local function arenaCenter(): Vector3
	return if arenaPart then arenaPart.Position elseif spawnPart then spawnPart.Position else Vector3.zero
end

local function setStatus(text: string)
	if statusLabel then
		statusLabel.Text = text
	end
end

local function findExtras()
	local sahur = Workspace:FindFirstChild("Sahur")
	if not sahur then
		return
	end
	for _, d in sahur:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "BossAltar" then
				altar = d
			elseif d.Name == "BossSpawn" then
				spawnPart = d
			elseif d.Name == "BossArena" then
				arenaPart = d
			end
		end
	end
end

--- Jogadores vivos e aptos dentro da arena, do mais perto ao mais longe do ponto.
local function playersNear(from: Vector3, radius: number): { { player: Player, root: BasePart, dist: number } }
	local out = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and HealthService.IsAlive(character) and HealthService.CanFight(player) and player:GetAttribute("InMatch") ~= true then
			local dist = (root.Position - from).Magnitude
			if dist <= radius then
				table.insert(out, { player = player, root = root, dist = dist })
			end
		end
	end
	table.sort(out, function(a, b)
		return a.dist < b.dist
	end)
	return out
end

-- ---------------------------------------------------------------------------
-- Rig
-- ---------------------------------------------------------------------------

local function buildBoss(): (Model?, Humanoid?, BasePart?)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn("[BossService] não consegui criar o rig: " .. tostring(model))
		return nil, nil, nil
	end
	model.Name = BossConfig.Name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		model:Destroy()
		return nil, nil, nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Color = Color3.fromRGB(70, 30, 35)
			d.Material = Enum.Material.Slate
		end
	end
	-- Animator criado no servidor para as animações do cliente replicarem (FX.PlayAnimation)
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	humanoid.DisplayName = BossConfig.Name
	humanoid.MaxHealth = BossConfig.MaxHealth
	humanoid.Health = BossConfig.MaxHealth
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.NameDisplayDistance = 120
	humanoid.HealthDisplayDistance = 120
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = BossConfig.WalkSpeed
	humanoid.JumpPower = 0
	humanoid.AutoRotate = true
	pcall(function()
		model:ScaleTo(BossConfig.Scale)
	end)
	-- olhos: neon para ler a direção
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		head.Color = Color3.fromRGB(120, 20, 25)
	end
	CollectionService:AddTag(model, "Combatant")
	return model, humanoid, root
end

-- ---------------------------------------------------------------------------
-- Telegraph + golpes
-- ---------------------------------------------------------------------------

local function telegraph(position: Vector3, radius: number, seconds: number)
	local ring = Instance.new("Part")
	ring.Name = "BossTelegraph"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(230, 50, 50)
	ring.Transparency = 0.55
	ring.Parent = Workspace
	task.delay(seconds, function()
		ring:Destroy()
	end)
end

local function isEnraged(f: Fight): boolean
	return os.clock() < f.enragedUntil
end

local function hitAround(f: Fight, center: Vector3, attack: BossConfig.Attack)
	local damage = attack.Damage * (if f.phase >= 2 then BossConfig.AI.Phase2DamageScale else 1)
	if isEnraged(f) then
		damage *= BossConfig.Enrage.DamageScale
	end
	for _, victim in Hitbox.AroundPoint(f.model, center, attack.Radius, 12) do
		local victimPlayer = Players:GetPlayerFromCharacter(victim)
		if victimPlayer then
			local dealt = CombatService.ResolveNpcHit(f.model, victim, damage, attack.Knockback)
			if dealt > 0 and typeof(attack.StunSeconds) == "number" then
				CombatService.Stun(victimPlayer, attack.StunSeconds, "stunned")
			end
		end
	end
end

--- WalkSpeed conforme fase e enrage.
local function baseWalkSpeed(f: Fight): number
	local speed = if f.phase >= 2 then BossConfig.PhaseTwoSpeed else BossConfig.WalkSpeed
	return if isEnraged(f) then speed * BossConfig.Enrage.SpeedScale else speed
end

--- Move o boss até `goal` em `seconds` com um arco (pulo). Servidor é dono do rig.
local function leapTo(f: Fight, goal: Vector3, seconds: number)
	local from = f.root.Position
	local t0 = os.clock()
	local height = 14
	while not f.finished and f.model.Parent do
		local a = math.clamp((os.clock() - t0) / seconds, 0, 1)
		local pos = from:Lerp(goal, a) + Vector3.new(0, math.sin(a * math.pi) * height, 0)
		local flat = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
		f.root.CFrame = if flat.Magnitude > 0.1 then CFrame.lookAt(pos, pos + flat.Unit) else CFrame.new(pos)
		if a >= 1 then
			break
		end
		task.wait()
	end
end

local function doAttack(f: Fight, name: string, target: BasePart)
	local attack = BossConfig.Attacks[name]
	f.cooldowns[name] = os.clock() + attack.Cooldown * (if f.phase >= 2 then BossConfig.AI.Phase2CooldownScale else 1)
	f.humanoid:MoveTo(f.root.Position) -- para durante o golpe
	broadcast("attack", { model = f.model, name = name, phase = "windup", windup = attack.Windup })
	if name == "Leap" then
		local goal = target.Position
		telegraph(goal, attack.Radius, attack.Windup + 0.6)
		task.wait(attack.Windup)
		if f.finished then
			return
		end
		leapTo(f, Vector3.new(goal.X, f.root.Position.Y, goal.Z), 0.55)
		if not f.finished then
			broadcast("attack", { model = f.model, name = name, phase = "hit", position = f.root.Position, radius = attack.Radius })
			hitAround(f, f.root.Position, attack)
		end
		return
	end
	if name == "Charge" then
		telegraph(target.Position, attack.Radius, attack.Windup + 0.6)
		task.wait(attack.Windup)
		if f.finished then
			return
		end
		local goal = target.Position
		f.humanoid.WalkSpeed = baseWalkSpeed(f) * 3
		f.humanoid:MoveTo(goal)
		local t0 = os.clock()
		while not f.finished and os.clock() - t0 < 1.2 and (f.root.Position - goal).Magnitude > 4 do
			task.wait(0.05)
		end
		f.humanoid.WalkSpeed = baseWalkSpeed(f)
		if not f.finished then
			broadcast("attack", { model = f.model, name = name, phase = "hit", position = f.root.Position, radius = attack.Radius })
			hitAround(f, f.root.Position, attack)
		end
		return
	end
	local centered = name == "Slam" or name == "Shockwave" or name == "Roar"
	local center = if centered then f.root.Position else f.root.Position + f.root.CFrame.LookVector * (attack.Radius * 0.6)
	telegraph(center, attack.Radius, attack.Windup + 0.15)
	task.wait(attack.Windup)
	if f.finished then
		return
	end
	local hitCenter = if centered then f.root.Position else f.root.Position + f.root.CFrame.LookVector * (attack.Radius * 0.6)
	broadcast("attack", { model = f.model, name = name, phase = "hit", position = hitCenter, radius = attack.Radius })
	hitAround(f, hitCenter, attack)
end

--- Sorteia entre os golpes prontos e no alcance, ponderado por Weight (fase 2 libera Charge/Roar).
local function chooseAttack(f: Fight, dist: number): string?
	local now = os.clock()
	local candidates: { { name: string, weight: number } } = {}
	local total = 0
	for name, attack in BossConfig.Attacks :: { [string]: BossConfig.Attack } do
		if attack.Phase and f.phase < attack.Phase then
			continue
		end
		if (f.cooldowns[name] or 0) > now or dist > attack.Range then
			continue
		end
		if attack.MinRange and dist < attack.MinRange then
			continue
		end
		local weight = attack.Weight or 1
		table.insert(candidates, { name = name, weight = weight })
		total += weight
	end
	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	for _, c in candidates do
		roll -= c.weight
		if roll <= 0 then
			return c.name
		end
	end
	return candidates[#candidates].name
end

--- Prioridade: quem mais bateu no boss, perto e sem bloquear. Reavalia a cada RetargetSeconds
--- ou quando o alvo some/morre/sai da arena.
local function pickTarget(f: Fight, near: { { player: Player, root: BasePart, dist: number } }, center: Vector3): { player: Player, root: BasePart, dist: number }?
	local best, bestScore = nil, -math.huge
	for _, entry in near do
		if (entry.root.Position - center).Magnitude > BossConfig.ArenaRadius then
			continue
		end
		local score = (f.damageBy[entry.player] or 0) * BossConfig.AI.AggroDamageWeight - entry.dist * 0.05
		if CombatService.IsBlocking(entry.player) then
			score -= BossConfig.AI.AggroBlockPenalty
		end
		if entry.player == f.target then
			score += 0.5 -- um pouco de inércia para não ficar trocando
		end
		if score > bestScore then
			best, bestScore = entry, score
		end
	end
	return best
end

-- ---------------------------------------------------------------------------
-- Luta
-- ---------------------------------------------------------------------------

local function rewardAndFinish(f: Fight)
	local total = 0
	local top: Player? = nil
	local topDamage = 0
	for player, dmg in f.damageBy do
		total += dmg
		if dmg > topDamage then
			top, topDamage = player, dmg
		end
	end
	local rewards = {}
	for player, dmg in f.damageBy do
		if player.Parent == Players and total > 0 then
			local coins = math.max(BossConfig.RewardMin, math.floor(BossConfig.RewardPool * dmg / total))
			if player == top then
				coins += BossConfig.RewardTopBonus
			end
			coins = DataService.RewardCoins(player, coins)
			ProgressionService.OnBossDefeated(player, dmg, dmg / total, player == top)
			table.insert(rewards, { name = player.Name, coins = coins, damage = math.floor(dmg) })
		end
	end
	table.sort(rewards, function(a, b)
		return a.damage > b.damage
	end)
	Log.debug(("[BossService] boss derrotado; %d participante(s), dano total %d"):format(#rewards, math.floor(total)))
	broadcast("defeated", { rewards = rewards, top = if top then top.Name else nil })
end

local function endFight(f: Fight, defeated: boolean)
	if f.finished then
		return
	end
	f.finished = true
	fight = nil
	if defeated then
		rewardAndFinish(f)
	else
		broadcast("despawned", {})
	end
	task.delay(if defeated then 4 else 0.5, function()
		f.model:Destroy()
	end)
	state = "Cooldown"
	cooldownUntil = os.clock() + BossConfig.Cooldown
	task.spawn(function()
		while state == "Cooldown" and os.clock() < cooldownUntil do
			setStatus(("Altar recarregando: %ds"):format(math.ceil(cooldownUntil - os.clock())))
			task.wait(1)
		end
		if state == "Cooldown" then
			state = "Ready"
			setStatus("Altar pronto: segure E para invocar")
			if prompt then
				prompt.Enabled = true
			end
		end
	end)
end

local function aiLoop(f: Fight)
	local center = arenaCenter()
	local lastState = 0
	while not f.finished and f.humanoid.Health > 0 and f.model.Parent do
		local near = playersNear(f.root.Position, BossConfig.ArenaRadius * 1.3)
		-- alvo atual continua válido? senão (ou passou RetargetSeconds) escolhe de novo
		local target = nil
		for _, entry in near do
			if entry.player == f.target and (entry.root.Position - center).Magnitude <= BossConfig.ArenaRadius then
				target = entry
			end
		end
		if not target or os.clock() - f.targetChosenAt > BossConfig.AI.RetargetSeconds then
			local picked = pickTarget(f, near, center)
			if picked then
				target = picked
				f.target = picked.player
				f.targetChosenAt = os.clock()
			end
		end
		if target then
			f.lastSeenPlayer = os.clock()
			local attackName = chooseAttack(f, target.dist)
			if attackName then
				doAttack(f, attackName, target.root)
				-- fase 2: emenda um Swipe se o alvo ficou colado (combo)
				if not f.finished and f.phase >= 2 and math.random() < BossConfig.AI.ComboChance then
					local again = playersNear(f.root.Position, BossConfig.Attacks.Swipe.Range)
					if #again > 0 then
						f.cooldowns.Swipe = 0
						doAttack(f, "Swipe", again[1].root)
					end
				end
			else
				f.humanoid:MoveTo(target.root.Position)
			end
		else
			-- ninguém na arena: volta para o spawn e espera
			if (f.root.Position - center).Magnitude > 6 then
				f.humanoid:MoveTo(center)
			end
			if os.clock() - f.lastSeenPlayer > BossConfig.AbandonSeconds then
				Log.debug("[BossService] boss abandonado; removendo")
				endFight(f, false)
				return
			end
		end
		-- fase 2
		if f.phase == 1 and f.humanoid.Health <= f.humanoid.MaxHealth * BossConfig.PhaseTwoAt then
			f.phase = 2
			f.humanoid.WalkSpeed = baseWalkSpeed(f)
			broadcast("phase", { phase = 2, model = f.model })
			-- virada de fase: rugido na hora (atordoa quem estiver colado)
			f.cooldowns.Roar = 0
			doAttack(f, "Roar", f.root)
		end
		-- enrage: levou golpes demais em pouco tempo (combo estendido) -> ruge, cura parte, fica mais forte
		local now = os.clock()
		local e = BossConfig.Enrage
		if not isEnraged(f) and now >= f.enrageReadyAt then
			local count, taken = 0, 0
			for i = #f.recentHits, 1, -1 do
				local h = f.recentHits[i]
				if now - h.t <= e.Window then
					count += 1
					taken += h.amount
				else
					table.remove(f.recentHits, i)
				end
			end
			if count >= e.Hits then
				f.enragedUntil = now + e.Duration
				f.enrageReadyAt = now + e.Cooldown
				table.clear(f.recentHits)
				HealthService.Heal(f.model, taken * e.HealFraction)
				f.humanoid.WalkSpeed = baseWalkSpeed(f)
				broadcast("enrage", { model = f.model, duration = e.Duration, active = true })
				f.cooldowns.Roar = 0
				doAttack(f, "Roar", f.root)
				task.delay(e.Duration, function()
					if not f.finished and f.model.Parent then
						f.humanoid.WalkSpeed = baseWalkSpeed(f)
						broadcast("enrage", { model = f.model, active = false })
					end
				end)
			end
		end
		if os.clock() - lastState > 0.5 then
			lastState = os.clock()
			broadcast("state", { health = f.humanoid.Health, maxHealth = f.humanoid.MaxHealth, phase = f.phase })
			setStatus(("%s: %d%%"):format(BossConfig.Name, math.floor(100 * f.humanoid.Health / f.humanoid.MaxHealth)))
		end
		task.wait(0.2)
	end
end

local function summon(player: Player)
	if state ~= "Ready" or fight then
		return
	end
	if BossConfig.SummonCost > 0 then
		local profile = DataService.GetProfile(player)
		if not profile or profile.coins < BossConfig.SummonCost then
			notifyBoss:FireClient(player, "denied", { event = "denied", reason = ("Precisa de %d moedas para invocar."):format(BossConfig.SummonCost) })
			return
		end
		DataService.AddCoins(player, -BossConfig.SummonCost)
	end
	local model, humanoid, root = buildBoss()
	if not model or not humanoid or not root then
		return
	end
	state = "Fighting"
	if prompt then
		prompt.Enabled = false
	end
	local spawnCf = if spawnPart then spawnPart.CFrame else CFrame.new(arenaCenter())
	model:PivotTo(CFrame.new(spawnCf.Position + Vector3.new(0, 3 * BossConfig.Scale + 1, 0)))
	model.Parent = Workspace
	pcall(function()
		root:SetNetworkOwner(nil) -- servidor simula
	end)

	local f: Fight = {
		model = model,
		humanoid = humanoid,
		root = root,
		summoner = player,
		damageBy = {},
		phase = 1,
		recentHits = {},
		enragedUntil = 0,
		enrageReadyAt = 0,
		cooldowns = {},
		lastSeenPlayer = os.clock(),
		finished = false,
		target = nil,
		targetChosenAt = 0,
	}
	fight = f
	humanoid.Died:Once(function()
		endFight(f, true)
	end)
	Log.debug(("[BossService] %s invocou o boss"):format(player.Name))
	broadcast("summoned", { by = player.Name, name = BossConfig.Name, health = humanoid.Health, maxHealth = humanoid.MaxHealth })
	setStatus(BossConfig.Name .. ": 100%")
	task.spawn(aiLoop, f)
end

--- [Admin] Remove o boss atual (sem recompensa) e libera o altar.
function BossService.Despawn(): boolean
	local f = fight
	if not f then
		return false
	end
	endFight(f, false)
	cooldownUntil = 0
	return true
end

--- [Admin] Invoca direto.
function BossService.Summon(player: Player): (boolean, string)
	if state == "Cooldown" then
		state = "Ready"
	end
	if state ~= "Ready" then
		return false, "boss já está ativo"
	end
	summon(player)
	return true, "boss invocado"
end

function BossService.GetState(): string
	return state
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function BossService.Init()
	notifyBoss = Remotes.GetEvent(Remotes.Events.NotifyBoss)
end

function BossService.Start()
	findExtras()
	if not altar then
		state = "Missing"
		warn("[BossService] Workspace.Sahur sem BossAltar (ArenaExtras); altar desativado")
		return
	end
	local a = altar :: BasePart

	local p = Instance.new("ProximityPrompt")
	p.Name = "SummonPrompt"
	p.ActionText = "Invocar o boss"
	p.ObjectText = BossConfig.Name
	p.HoldDuration = 1
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = a
	p.Triggered:Connect(summon)
	prompt = p

	local gui = Instance.new("BillboardGui")
	gui.Name = "BossAltarGui"
	gui.Size = UDim2.fromOffset(260, 40)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.Parent = a
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(255, 220, 200)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = false
	label.Parent = gui
	statusLabel = label
	setStatus("Altar pronto: segure E para invocar")

	HealthService.Damaged.Event:Connect(function(victim: Model, amount: number, attacker: Player?)
		local f = fight
		if f and attacker and victim == f.model then
			f.damageBy[attacker] = (f.damageBy[attacker] or 0) + amount
			table.insert(f.recentHits, { t = os.clock(), amount = amount })
		end
	end)

	-- quem entra no meio recebe o estado
	Players.PlayerAdded:Connect(function(player)
		task.wait(1)
		local f = fight
		if f then
			notifyBoss:FireClient(player, "summoned", { event = "summoned", by = f.summoner.Name, name = BossConfig.Name, health = f.humanoid.Health, maxHealth = f.humanoid.MaxHealth })
		end
	end)

	Log.debug(("[BossService] altar pronto em %s"):format(a:GetFullName()))
end

return BossService
