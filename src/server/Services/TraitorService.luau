--!strict
--[[
	TraitorService (servidor)
	Capítulo FINAL da história (dono, 2026-09-23): o desenvolvedor TRAIDOR (QuestConfig.Traitor.UserId =
	adryan_keep) vira um NPC hostil no santuário do boss. Quem aceita o capítulo `final` (ou volta a falar com
	ele sem ter vencido) invoca o traidor — um só por servidor; todo mundo pode bater, e o crédito
	(contador `traitor_kill`) vai para quem deu dano E está no capítulo final ativo (QuestService.IsActiveOn).
	Rig: R6 com o avatar real do membro (GetHumanoidDescriptionFromUserId → CreateHumanoidModelFromDescription),
	física de verdade (leva knockback/ragdoll como o boneco de treino), tag "Combatant", atributo Npc, direto
	no Workspace (o ProcAnimController anima Idle/Walk/Run de quem está ali).
	IA (loop 0,1 s): alvo = jogador vivo mais perto dentro de ArenaRadius de BossArena; anda (MoveTo); combo
	de 4 socos no ritmo do M1 (CombatService.NpcPunch → ResolveNpcHit respeita block); longe = DASH em arco
	até o alvo; a cada Burst.Cooldown uma RAJADA com aviso no chão (anel vermelho) + knockback/ragdoll.
	Fase 2 (metade da vida): mais rápido. Sem ninguém vivo na arena por AbandonSeconds = some sem crédito.
	Servidor autoritativo; nada vem do cliente.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local QuestConfig = require(Modules:WaitForChild("QuestConfig"))
local TeamConfig = require(Modules:WaitForChild("TeamConfig"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local Hitbox = require(Modules:WaitForChild("Hitbox"))
local Combatant = require(Modules:WaitForChild("Combatant"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))

local TraitorService = {}

local CFG = QuestConfig.Traitor
local FINAL_ID = "final"

type Fight = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	damageBy: { [Player]: number },
	phase: number,
	finished: boolean,
	lastSeenPlayer: number,
	lastHitAt: number,
	nextDashAt: number,
	nextBurstAt: number,
	busyUntil: number, -- os.clock() até o fim do golpe atual (não anda nem inicia outro)
	combo: number,
}

local fight: Fight? = nil
local spawnPart: BasePart? = nil
local arenaPart: BasePart? = nil
local notifyQuest: RemoteEvent
local descriptionCache: HumanoidDescription? = nil

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

local function traitorName(): string
	local m = TeamConfig.ByUserId(CFG.UserId)
	return if m then m.DisplayName else "?"
end

local function findExtras()
	local sahur = Workspace:FindFirstChild("Sahur")
	local extras = sahur and sahur:FindFirstChild("ArenaExtras")
	if not extras then
		return
	end
	spawnPart = extras:FindFirstChild(CFG.SpawnPartName, true) :: BasePart?
	arenaPart = extras:FindFirstChild(CFG.ArenaPartName, true) :: BasePart?
end

local function toast(player: Player, title: string, text: string)
	notifyQuest:FireClient(player, "toast", { title = title, text = text })
end

local function toastAll(title: string, text: string)
	for _, p in Players:GetPlayers() do
		toast(p, title, text)
	end
end

local function playersNear(from: Vector3, radius: number): { { player: Combatant.Fighter, root: BasePart, dist: number } }
	local list = {}
	for _, player in Combatant.All() do -- jogadores e bots
		local character = Combatant.CharacterOf(player)
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and HealthService.IsAlive(character) then
			local dist = (root.Position - from).Magnitude
			if dist <= radius then
				table.insert(list, { player = player, root = root, dist = dist })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.dist < b.dist
	end)
	return list
end

local function telegraph(position: Vector3, radius: number, seconds: number)
	local ring = Instance.new("Part")
	ring.Name = "TraitorTelegraph"
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

-- ---------------------------------------------------------------------------
-- Rig
-- ---------------------------------------------------------------------------

local function describe(): HumanoidDescription
	if descriptionCache then
		return descriptionCache:Clone()
	end
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(CFG.UserId)
	end)
	if ok and desc then
		descriptionCache = desc
		return desc:Clone()
	end
	warn(("[TraitorService] avatar de %s não carregou (%s); rig padrão"):format(traitorName(), tostring(desc)))
	return Instance.new("HumanoidDescription")
end

local function buildRig(): (Model?, Humanoid?, BasePart?)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(describe(), Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn("[TraitorService] não consegui criar o rig: " .. tostring(model))
		return nil, nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		model:Destroy()
		return nil, nil, nil
	end
	local maxHealth = math.floor(CombatConfig.MaxHealth * CFG.HealthMult + 0.5)
	model.Name = "Traidor_" .. traitorName()
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	humanoid.DisplayName = ("%s — %s"):format(traitorName(), CFG.Title)
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.NameDisplayDistance = 120
	humanoid.HealthDisplayDistance = 120
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = CFG.WalkSpeed
	humanoid.JumpPower = 0
	humanoid.AutoRotate = true
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = d.Name ~= "HumanoidRootPart"
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	-- aura de traidor: contorno vermelho + luz (o cliente não precisa saber de nada)
	local hl = Instance.new("Highlight")
	hl.Name = "TraitorAura"
	hl.FillColor = Color3.fromRGB(200, 30, 30)
	hl.FillTransparency = 0.7
	hl.OutlineColor = Color3.fromRGB(255, 80, 60)
	hl.OutlineTransparency = 0
	hl.Parent = model
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 40)
	light.Brightness = 2
	light.Range = 14
	light.Parent = root
	model:SetAttribute("Npc", true)
	model:SetAttribute("Traitor", true)
	CollectionService:AddTag(model, "Combatant")
	return model, humanoid, root
end

-- ---------------------------------------------------------------------------
-- Golpes
-- ---------------------------------------------------------------------------

local function face(f: Fight, target: BasePart)
	local to = target.Position - f.root.Position
	to = Vector3.new(to.X, 0, to.Z)
	if to.Magnitude > 0.1 then
		f.root.CFrame = CFrame.lookAt(f.root.Position, f.root.Position + to.Unit)
	end
end

local function punch(f: Fight, target: BasePart)
	local m1 = CombatConfig.Attacks.M1
	face(f, target)
	f.humanoid:MoveTo(f.root.Position)
	local isFinisher = f.combo >= m1.ComboLength
	CombatService.NpcPunch(f.model, f.combo, CFG.Punch.Damage)
	f.combo = if isFinisher then 1 else f.combo + 1
	f.busyUntil = os.clock() + (if isFinisher then m1.ComboEndCooldown else m1.Cooldown)
end

--- Pulo em arco até perto do alvo (servidor é dono do rig).
local function dash(f: Fight, target: BasePart)
	f.nextDashAt = os.clock() + CFG.Dash.Cooldown
	f.busyUntil = os.clock() + CFG.Dash.Seconds + 0.2
	local from = f.root.Position
	local flat = Vector3.new(target.Position.X - from.X, 0, target.Position.Z - from.Z)
	local goal = target.Position - (if flat.Magnitude > 0.1 then flat.Unit * 4 else Vector3.zero)
	goal = Vector3.new(goal.X, from.Y, goal.Z)
	local t0 = os.clock()
	while not f.finished and f.model.Parent do
		local a = math.clamp((os.clock() - t0) / CFG.Dash.Seconds, 0, 1)
		local pos = from:Lerp(goal, a) + Vector3.new(0, math.sin(a * math.pi) * 6, 0)
		f.root.AssemblyLinearVelocity = Vector3.zero
		f.root.CFrame = if flat.Magnitude > 0.1 then CFrame.lookAt(pos, pos + flat.Unit) else CFrame.new(pos)
		if a >= 1 then
			break
		end
		task.wait()
	end
	f.combo = 1
end

--- Rajada: aviso no chão, depois dano em área com knockback/ragdoll (respeita block).
local function burst(f: Fight)
	local b = CFG.Burst
	f.nextBurstAt = os.clock() + b.Cooldown
	f.busyUntil = os.clock() + b.Windup + 0.4
	f.humanoid:MoveTo(f.root.Position)
	telegraph(f.root.Position, b.Radius, b.Windup + 0.15)
	task.wait(b.Windup)
	if f.finished or not f.model.Parent then
		return
	end
	local center = f.root.Position
	for _, victim in Hitbox.AroundPoint(f.model, center, b.Radius, 12) do
		if Combatant.Of(victim) then -- jogador ou bot
			CombatService.ResolveNpcHit(f.model, victim, b.Damage, b.Knockback)
		end
	end
	-- onda visual simples (peça neon que cresce e some)
	local wave = Instance.new("Part")
	wave.Shape = Enum.PartType.Ball
	wave.Size = Vector3.new(2, 2, 2)
	wave.CFrame = CFrame.new(center)
	wave.Anchored = true
	wave.CanCollide = false
	wave.CanQuery = false
	wave.CanTouch = false
	wave.Material = Enum.Material.Neon
	wave.Color = Color3.fromRGB(255, 70, 50)
	wave.Transparency = 0.3
	wave.Parent = Workspace
	TweenService:Create(wave, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(b.Radius * 2, b.Radius * 2, b.Radius * 2), Transparency = 1 }):Play()
	task.delay(0.5, function()
		wave:Destroy()
	end)
end

-- ---------------------------------------------------------------------------
-- Fim da luta
-- ---------------------------------------------------------------------------

local function endFight(f: Fight, defeated: boolean)
	if f.finished then
		return
	end
	f.finished = true
	fight = nil
	if defeated then
		-- crédito: deu dano E está no capítulo final ativo
		local credited = {}
		for player, amount in f.damageBy do
			if amount > 0 and player.Parent and QuestService.IsActiveOn(player, FINAL_ID) then
				QuestService.Progress(player, "traitor_kill", 1)
				table.insert(credited, player.Name)
			end
		end
		Log.debug(("[TraitorService] traidor derrotado; crédito: %s"):format(if #credited > 0 then table.concat(credited, ", ") else "ninguém"))
		toastAll("O traidor caiu", ("%s foi derrotado no santuário."):format(traitorName()))
		-- corpo: ragdoll por um instante e some
		RagdollService.RagdollModel(f.model, 3)
		task.delay(2.5, function()
			for _, d in f.model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					TweenService:Create(d, TweenInfo.new(1.4), { Transparency = 1 }):Play()
				end
			end
		end)
		task.delay(4, function()
			f.model:Destroy()
		end)
	else
		toastAll("O traidor sumiu", "Ninguém ficou no santuário. Fale com ele de novo para chamá-lo.")
		f.model:Destroy()
	end
end

-- ---------------------------------------------------------------------------
-- IA
-- ---------------------------------------------------------------------------

local function aiLoop(f: Fight)
	f.lastSeenPlayer = os.clock()
	while not f.finished and f.model.Parent and f.humanoid.Health > 0 do
		task.wait(0.1)
		if f.finished then
			break
		end
		local now = os.clock()
		-- fase 2
		if f.phase == 1 and f.humanoid.Health <= f.humanoid.MaxHealth * CFG.PhaseTwoAt then
			f.phase = 2
			f.humanoid.WalkSpeed = CFG.ChaseSpeed
			toastAll("O traidor está furioso", "Metade da vida: ele ficou mais rápido.")
		end
		-- regen fora de combate
		if now - f.lastHitAt >= CFG.Regen.Delay and f.humanoid.Health < f.humanoid.MaxHealth then
			f.humanoid.Health = math.min(f.humanoid.MaxHealth, f.humanoid.Health + CFG.Regen.PerSecond * 0.1)
		end
		-- caído/atordoado/AGARRADO: espera
		if RagdollService.IsModelRagdolled(f.model) or now < f.busyUntil or f.model:GetAttribute("Grabbed") == true then
			continue
		end
		-- À SOLTA (dono, 2026-09-23): o traidor persegue pelo mapa inteiro a partir de onde ESTÁ (ChaseRadius);
		-- sem ninguém por perto ele fica parado onde parou (não volta ao santuário) e some após AbandonSeconds.
		local near = playersNear(f.root.Position, CFG.ChaseRadius)
		local target = near[1]
		if not target then
			f.humanoid:MoveTo(f.root.Position)
			f.combo = 1
			if now - f.lastSeenPlayer > CFG.AbandonSeconds then
				endFight(f, false)
				return
			end
			continue
		end
		f.lastSeenPlayer = now
		local dist = (target.root.Position - f.root.Position).Magnitude
		if now >= f.nextBurstAt and dist <= CFG.Burst.Radius * 0.8 then
			task.spawn(burst, f)
		elseif dist <= CFG.Punch.Range then
			punch(f, target.root)
		elseif now >= f.nextDashAt and dist >= CFG.Dash.MinDist and dist <= CFG.Dash.MaxDist then
			task.spawn(dash, f, target.root)
		else
			f.humanoid:MoveTo(target.root.Position)
			if dist > CFG.Punch.Range + 3 then
				f.combo = 1
			end
		end
	end
	if not f.finished then
		endFight(f, true)
	end
end

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

--- Invoca o traidor no santuário (um só por servidor). (ok, mensagem)
function TraitorService.Summon(by: Player?): (boolean, string)
	if fight then
		return true, "o traidor já está no santuário"
	end
	if not spawnPart then
		findExtras()
	end
	local model, humanoid, root = buildRig()
	if not model or not humanoid or not root then
		return false, "não consegui criar o traidor"
	end
	local pos = if spawnPart then spawnPart.Position + Vector3.new(0, spawnPart.Size.Y / 2 + 3.05, 0) else QuestConfig.Spots.Santuario.Pos + Vector3.new(0, 3.5, 0)
	model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(180), 0))
	model.Parent = Workspace
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local f: Fight = {
		model = model,
		humanoid = humanoid,
		root = root,
		damageBy = {},
		phase = 1,
		finished = false,
		lastSeenPlayer = os.clock(),
		lastHitAt = os.clock(),
		nextDashAt = os.clock() + 2,
		nextBurstAt = os.clock() + 6,
		busyUntil = os.clock() + 1.5, -- entrada: fica parado um instante
		combo = 1,
	}
	fight = f
	humanoid.Died:Once(function()
		endFight(f, true)
	end)
	task.spawn(aiLoop, f)
	toastAll("TRAIDOR", ("%s apareceu no santuário atrás da cachoeira%s."):format(traitorName(), if by then " — chamado por " .. by.Name else ""))
	Log.debug(("[TraitorService] traidor invocado por %s (vida %d)"):format(if by then by.Name else "servidor", humanoid.MaxHealth))
	return true, "traidor invocado"
end

--- [DEV] Some com o traidor sem crédito.
function TraitorService.Despawn(): boolean
	local f = fight
	if not f then
		return false
	end
	endFight(f, false)
	return true
end

--- [DEV] Mata o traidor (crédito normal).
function TraitorService.Kill(): boolean
	local f = fight
	if not f then
		return false
	end
	f.humanoid.Health = 0
	return true
end

function TraitorService.IsActive(): boolean
	return fight ~= nil
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function TraitorService.Init()
	notifyQuest = Remotes.GetEvent(Remotes.Events.NotifyQuest)
	-- aceitar o capítulo final (ou voltar a falar com o traidor sem ter vencido) = ele aparece no santuário
	QuestService.OnTalk(function(player: Player, ch: QuestConfig.Chapter, phase: string)
		if ch.Id == FINAL_ID and (phase == "accept" or phase == "progress") then
			TraitorService.Summon(player)
		end
	end)
end

function TraitorService.Start()
	findExtras()
	if not spawnPart then
		warn(("[TraitorService] Workspace.Sahur.ArenaExtras sem %s; o traidor nasce no spot Santuario"):format(CFG.SpawnPartName))
	end
	HealthService.Damaged.Event:Connect(function(victim: Model, amount: number, attacker: Player?)
		local f = fight
		if f and victim == f.model then
			f.lastHitAt = os.clock()
			if attacker then
				f.damageBy[attacker] = (f.damageBy[attacker] or 0) + amount
			end
		end
	end)
	Log.debug(("[TraitorService] traidor = %s (vida ×%d)"):format(traitorName(), CFG.HealthMult))
end

return TraitorService
