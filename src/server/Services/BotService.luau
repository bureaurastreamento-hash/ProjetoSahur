--!strict
--[[
	BotService (servidor)
	BOTS com o combate REAL (dono, 2026-09-23: trailer/testes com ataques e ults de verdade, sem depender de
	segundo jogador). Um bot é um Model R6 (avatar de um membro da equipe ou rig liso) com atributo `Bot`
	(Combatant.Fighter): ele passa pelos MESMOS caminhos do jogador — CombatService.Attack/Block,
	MovementService.Dash/Sprint, AbilityService.Use/Awaken — com estado, cooldowns, carga de ult, hitstun,
	ragdoll, parry e cutscene do despertar iguais. Só não tem cliente (HUD/DataStore/crédito).
	Comportamento (atributo Behavior):
	  passive    (padrão, dono) — parado até APANHAR; aí revida contra quem bateu por AggroSeconds e volta a ficar quieto
	  aggressive — caça o lutador mais perto dentro de SeekRadius
	  idle       — nunca ataca (só serve de alvo; leva hitstun/ragdoll normalmente)
	IA (tick 0,1 s): perto = combo de M1; meio = habilidade 1–3 pronta (chance por tick); longe = dash/andar até
	o alvo; carga cheia = despertar (G) e depois a ULT quando estiver perto; bloqueia por instantes quando o
	alvo está atacando; caído = ragdoll cancel às vezes. Morreu = renasce no ponto de origem após RespawnTime.
	API: Spawn(opts), Clear(), SetBehavior(model?, behavior), Fill(model?) (carga da ult cheia), List().
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Log = require(Modules:WaitForChild("Log"))
local Combatant = require(Modules:WaitForChild("Combatant"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local TeamConfig = require(Modules:WaitForChild("TeamConfig"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))
local MovementService = require(script.Parent:WaitForChild("MovementService"))
local AbilityService = require(script.Parent:WaitForChild("AbilityService"))

local BotService = {}

BotService.Config = {
	Tick = 0.1,
	SeekRadius = 70, -- aggressive: enxerga lutadores até aqui
	AggroSeconds = 12, -- passive: revida por esse tempo depois do último golpe trocado
	PunchRange = 6.5, -- <= aqui: soca
	AbilityChancePerTick = 0.12, -- chance por tick de usar uma habilidade pronta quando está no alcance dela
	AbilityRange = 18, -- habilidades de investida/agarrão: usa quando o alvo está até aqui
	DashRange = { 12, 40 }, -- longe assim: dash na direção do alvo (se pronto)
	DashChancePerTick = 0.25,
	BlockChancePerTick = 0.2, -- alvo atacando a menos de 9 studs: chance de levantar a guarda por BlockSeconds
	BlockSeconds = 0.5,
	CancelChancePerTick = 0.35, -- caído: chance por tick de ragdoll cancel
	UltRange = 12, -- despertado: usa a ult quando o alvo está até aqui
	RespawnTime = CombatConfig.RespawnTime,
}

export type SpawnOptions = {
	CharacterId: string?, -- padrão: próximo da lista
	Name: string?,
	UserId: number?, -- avatar (padrão: roda os membros da equipe)
	CFrame: CFrame?, -- padrão: perto do primeiro jogador
	Behavior: string?, -- passive | aggressive | idle
	Respawn: boolean?, -- padrão true
	Team: string?, -- TeamId (bots do mesmo time não se batem)
}

type Bot = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	opts: SpawnOptions,
	home: CFrame,
	index: number,
	target: Instance?, -- Fighter (Player/bot) ou NPC de chefe (boss/traidor: Model com BossRig/Traitor)
	aggroUntil: number,
	blockUntil: number,
	holdUntil: number, -- usou habilidade: não emenda soco/dash até aqui (CastTime + folga)
	nextUltTryAt: number, -- não fica pedindo a ult a cada tick (OncePerAwakening nega)
	alive: boolean,
}

local bots: { [Model]: Bot } = {}
local nextIndex = 0
local castIndex = 0
local avatarIndex = 0
local descriptionCache: { [number]: HumanoidDescription } = {}

-- ---------------------------------------------------------------------------
-- Rig
-- ---------------------------------------------------------------------------

local function nextCharacterId(): string
	local ids = {}
	for _, id in CharacterDefs.Order do
		local def = CharacterDefs.Get(id)
		local access = def and CharacterDefs.AccessOf(def)
		if def and access ~= "form" and access ~= "admin" and access ~= "early" then
			table.insert(ids, id)
		end
	end
	if #ids == 0 then
		return CharacterDefs.DefaultCharacter
	end
	castIndex += 1
	return ids[((castIndex - 1) % #ids) + 1]
end

local function nextAvatarUserId(): number?
	local members = TeamConfig.Members
	if #members == 0 then
		return nil
	end
	avatarIndex += 1
	return members[((avatarIndex - 1) % #members) + 1].UserId
end

local function describe(userId: number?): HumanoidDescription
	if userId and descriptionCache[userId] then
		return descriptionCache[userId]:Clone()
	end
	if userId then
		local ok, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(userId)
		end)
		if ok and desc then
			descriptionCache[userId] = desc
			return desc:Clone()
		end
	end
	return Instance.new("HumanoidDescription")
end

local function buildRig(opts: SpawnOptions, index: number): (Model?, Humanoid?, BasePart?)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(describe(opts.UserId), Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn("[BotService] não consegui criar o rig: " .. tostring(model))
		return nil, nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		model:Destroy()
		return nil, nil, nil
	end
	local name = opts.Name or ("Bot %d"):format(index)
	model.Name = name
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	local def = CharacterDefs.Get(opts.CharacterId or "")
	humanoid.DisplayName = ("%s · %s"):format(name, if def then def.DisplayName else "?")
	humanoid.NameDisplayDistance = 80
	humanoid.HealthDisplayDistance = 80
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.BreakJointsOnDeath = false
	humanoid.AutoRotate = true
	-- Nunca cai "duro" (estado FallingDown/Ragdoll do Humanoid ao levar empurrão forte: o boneco deita rígido e
	-- fica preso — dono, 2026-09-23); o ragdoll de combate é o RagdollRig, não este estado
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = d.Name ~= "HumanoidRootPart"
			if d.CollisionGroup == "Default" then
				d.CollisionGroup = "Players" -- mesmo grupo dos jogadores (dash não empurra, entulho não empurra)
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	-- identidade de lutador (Combatant): atributos no Model
	model:SetAttribute(Combatant.ATTR_BOT, true)
	model:SetAttribute(Combatant.ATTR_BOT_USERID, -1000 - index)
	model:SetAttribute("Npc", true)
	model:SetAttribute("CharacterId", opts.CharacterId)
	model:SetAttribute("Behavior", opts.Behavior or "passive")
	model:SetAttribute("Energy", 0)
	model:SetAttribute("Ragdolled", false)
	if opts.Team then
		model:SetAttribute("TeamId", opts.Team)
	end
	CollectionService:AddTag(model, Combatant.BotTag)
	CollectionService:AddTag(model, "Combatant")
	return model, humanoid, root
end

-- ---------------------------------------------------------------------------
-- IA
-- ---------------------------------------------------------------------------

local function rootOf(fighter: Instance?): BasePart?
	local character = Combatant.CharacterOf(fighter)
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

--- Chefe NPC que o bot pode caçar (boss por peças, traidor) — não é lutador, mas leva golpe.
local function isBossNpc(inst: Instance?): boolean
	return inst ~= nil and inst:IsA("Model") and (inst:GetAttribute("BossRig") ~= nil or inst:GetAttribute("Traitor") == true)
end

local function validTarget(b: Bot, fighter: Instance?): boolean
	if not fighter or fighter == b.model then
		return false
	end
	if isBossNpc(fighter) then
		return fighter.Parent ~= nil and HealthService.IsAlive(fighter :: Model)
	end
	if not Combatant.IsPresent(fighter) then
		return false
	end
	local character = Combatant.CharacterOf(fighter)
	if not character or not HealthService.IsAlive(character) or not HealthService.CanFight(fighter) then
		return false
	end
	local team = b.model:GetAttribute("TeamId")
	if team ~= nil and fighter:GetAttribute("TeamId") == team then
		return false
	end
	return true
end

--- Lutadores + chefes NPC (boss/traidor) para a caça do agressivo.
local function candidates(): { Instance }
	local list: { Instance } = {}
	for _, f in Combatant.All() do
		table.insert(list, f)
	end
	for _, m in CollectionService:GetTagged("Combatant") do
		if isBossNpc(m) then
			table.insert(list, m)
		end
	end
	return list
end

local function nearestFighter(b: Bot, radius: number): Instance?
	local best, bestDist = nil, radius
	for _, fighter in candidates() do
		if validTarget(b, fighter) then
			local r = rootOf(fighter)
			local d = if r then (r.Position - b.root.Position).Magnitude else math.huge
			if d < bestDist then
				best, bestDist = fighter, d
			end
		end
	end
	return best
end

local function abilityRangeOk(effect: any, dist: number): boolean
	local t = effect.Type
	local C = BotService.Config
	if t == "Dash" or t == "Grab" or t == "Projectile" or t == "FlyGrab" then
		return dist >= 5 and dist <= C.AbilityRange
	elseif t == "AreaDamage" or t == "MultiHitArea" or t == "TimeDome" then
		local radius = tonumber(effect.Radius) or 10
		return dist <= radius + (tonumber(effect.Offset) or 0) - 1
	elseif t == "Teleport" then
		return dist >= 8
	end
	return dist <= 12 -- buffs/cura/escudo: perto do alvo
end

local function think(b: Bot)
	local C = BotService.Config
	local now = os.clock()
	local behavior = b.model:GetAttribute("Behavior")
	if behavior == "idle" then
		return
	end
	-- alvo
	if not validTarget(b, b.target) then
		b.target = nil
	end
	if behavior == "aggressive" then
		if not b.target then
			b.target = nearestFighter(b, C.SeekRadius)
		end
	elseif now >= b.aggroUntil then
		b.target = nil -- passive: esfriou
	end
	local target = b.target
	if not target then
		return
	end
	local tRoot = rootOf(target)
	if not tRoot then
		return
	end
	local toTarget = tRoot.Position - b.root.Position
	local dist = toTarget.Magnitude
	local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
	local dir = if flat.Magnitude > 0.1 then flat.Unit else b.root.CFrame.LookVector

	-- caído: ragdoll cancel às vezes
	if RagdollService.IsRagdolled(b.model) then
		if math.random() < C.CancelChancePerTick then
			MovementService.Dash(b.model, -dir, dir)
		end
		return
	end
	if CombatService.IsStunned(b.model) or CombatService.IsTimeSlowed(b.model) or CombatService.IsGrabbed(b.model) then
		return
	end
	local cutscene = b.model:GetAttribute("CutsceneUntil")
	if typeof(cutscene) == "number" and Workspace:GetServerTimeNow() < cutscene then
		return
	end
	-- guarda: alvo atacando perto → bloqueia por um instante
	if now < b.blockUntil or now < b.holdUntil then
		return -- segurando o block / terminando uma habilidade
	end
	if CombatService.IsBlocking(b.model) then
		CombatService.Block(b.model, false)
	end
	if dist <= 9 and not isBossNpc(target) and CombatService.IsAttacking(target) and math.random() < C.BlockChancePerTick then
		b.root.CFrame = CFrame.lookAt(b.root.Position, b.root.Position + dir)
		CombatService.Block(b.model, true)
		b.blockUntil = now + C.BlockSeconds
		task.delay(C.BlockSeconds, function()
			if b.alive and CombatService.IsBlocking(b.model) then
				CombatService.Block(b.model, false)
			end
		end)
		return
	end
	-- despertar / ult
	local energy = AbilityService.GetEnergy(b.model)
	local awakened = AbilityService.IsAwakened(b.model)
	if energy >= CharacterDefs.Energy.Max and not awakened and dist <= 24 then
		AbilityService.Awaken(b.model)
		return
	end
	local characterId = b.model:GetAttribute("CharacterId")
	local def = if typeof(characterId) == "string" then CharacterDefs.Get(characterId) else nil
	if def and awakened and dist <= C.UltRange and now >= b.nextUltTryAt then
		for slot, ability in def.Abilities do
			if ability.EnergyCost >= CharacterDefs.Energy.Max then
				b.root.CFrame = CFrame.lookAt(b.root.Position, b.root.Position + dir)
				b.humanoid:MoveTo(b.root.Position)
				AbilityService.Use(b.model, slot, dir)
				b.nextUltTryAt = now + 4
				if AbilityService.IsBusy(b.model) then
					b.holdUntil = now + ability.CastTime + 0.6
					return
				end
				break
			end
		end
	end
	-- habilidade comum pronta e no alcance
	if def and not MovementService.IsDashing(b.model) and not CombatService.IsAttacking(b.model) and math.random() < C.AbilityChancePerTick then
		local candidates = {}
		for slot, ability in def.Abilities do
			if ability.EnergyCost < CharacterDefs.Energy.Max and abilityRangeOk(ability.Effect, dist) then
				table.insert(candidates, slot)
			end
		end
		if #candidates > 0 then
			local slot = candidates[math.random(#candidates)]
			b.root.CFrame = CFrame.lookAt(b.root.Position, b.root.Position + dir)
			b.humanoid:MoveTo(b.root.Position)
			AbilityService.Use(b.model, slot, dir)
			-- se estava em cooldown o servidor nega em silêncio e o tick segue; se saiu, espera o cast
			local ability = def.Abilities[slot]
			if ability and CombatService.IsAttacking(b.model) == false and AbilityService.IsBusy(b.model) then
				b.holdUntil = now + ability.CastTime + 0.4
				return
			end
		end
	end
	-- perto: soca (o CombatService segura o ritmo do combo/cooldown)
	if dist <= C.PunchRange then
		b.humanoid:MoveTo(b.root.Position)
		b.root.CFrame = CFrame.lookAt(b.root.Position, b.root.Position + dir)
		CombatService.Attack(b.model, "M1")
		return
	end
	-- longe: dash na direção do alvo, senão anda
	if dist >= C.DashRange[1] and dist <= C.DashRange[2] and math.random() < C.DashChancePerTick and not MovementService.IsDashing(b.model) then
		MovementService.Dash(b.model, dir, dir)
		return
	end
	if not MovementService.IsDashing(b.model) then
		MovementService.Sprint(b.model, dist > 14)
		b.humanoid:MoveTo(tRoot.Position - dir * 4)
	end
end

local function aiLoop(b: Bot)
	while b.alive and b.model.Parent do
		local ok, err = pcall(function()
			think(b)
		end)
		if not ok then
			warn("[BotService] IA: " .. tostring(err))
		end
		task.wait(BotService.Config.Tick)
	end
end

-- ---------------------------------------------------------------------------
-- Spawn / morte
-- ---------------------------------------------------------------------------

local function defaultCFrame(): CFrame
	local any = Players:GetPlayers()[1]
	local root = any and any.Character and any.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local look = root.CFrame.LookVector
		local pos = root.Position + Vector3.new(look.X, 0, look.Z).Unit * 12
		return CFrame.lookAt(pos, Vector3.new(root.Position.X, pos.Y, root.Position.Z))
	end
	return CFrame.new(0, 5, 0)
end

local spawnAt: (opts: SpawnOptions, home: CFrame, index: number) -> Model?

local function onBotDied(b: Bot)
	b.alive = false
	bots[b.model] = nil
	task.delay(BotService.Config.RespawnTime, function()
		local model = b.model
		if model.Parent then
			model:Destroy()
		end
		if b.opts.Respawn ~= false and BotService.Enabled then
			spawnAt(b.opts, b.home, b.index)
		end
	end)
end

spawnAt = function(opts: SpawnOptions, home: CFrame, index: number): Model?
	local model, humanoid, root = buildRig(opts, index)
	if not model or not humanoid or not root then
		return nil
	end
	local m: Model, h: Humanoid, r: BasePart = model, humanoid, root
	m:PivotTo(home * CFrame.new(0, 3.05, 0))
	m.Parent = Workspace -- direto no Workspace: o ProcAnimController anima quem está aqui
	pcall(function()
		r:SetNetworkOwner(nil) -- o servidor simula (dash/knockback/ragdoll)
	end)
	HealthService.SetupBot(m)
	local b: Bot = {
		model = m,
		humanoid = h,
		root = r,
		opts = opts,
		home = home,
		index = index,
		target = nil,
		aggroUntil = 0,
		blockUntil = 0,
		holdUntil = 0,
		nextUltTryAt = 0,
		alive = true,
	}
	bots[m] = b
	h.Died:Once(function()
		onBotDied(b)
	end)
	task.spawn(aiLoop, b)
	return m
end

BotService.Enabled = true

--- Cria um bot. Devolve o Model.
function BotService.Spawn(options: SpawnOptions?): Model?
	local opts: SpawnOptions = if options then table.clone(options) else {}
	opts.CharacterId = opts.CharacterId or nextCharacterId()
	if not CharacterDefs.Get(opts.CharacterId :: string) then
		warn(("[BotService] personagem '%s' não existe"):format(tostring(opts.CharacterId)))
		return nil
	end
	if opts.UserId == nil then
		opts.UserId = nextAvatarUserId()
	end
	nextIndex += 1
	local home = opts.CFrame or defaultCFrame()
	local model = spawnAt(opts, home, nextIndex)
	if model then
		Log.debug(("[BotService] bot %d: %s (%s, %s)"):format(nextIndex, model.Name, tostring(opts.CharacterId), tostring(opts.Behavior or "passive")))
	end
	return model
end

--- Remove todos os bots (sem respawn).
function BotService.Clear(): number
	local n = 0
	for model, b in bots do
		b.alive = false
		b.opts.Respawn = false
		model:Destroy()
		n += 1
	end
	table.clear(bots)
	return n
end

--- Troca o comportamento de um bot (nil = todos): passive | aggressive | idle.
function BotService.SetBehavior(model: Model?, behavior: string)
	for m, b in bots do
		if model == nil or m == model then
			m:SetAttribute("Behavior", behavior)
			b.opts.Behavior = behavior
			if behavior ~= "aggressive" then
				b.target = nil
			end
		end
	end
end

--- Faz o bot revidar contra `fighter` agora (passive ganha aggro). Aceita boss/traidor também.
function BotService.Provoke(model: Model, fighter: Instance)
	local b = bots[model]
	if b then
		b.target = fighter
		b.aggroUntil = os.clock() + BotService.Config.AggroSeconds
	end
end

--- Carga da ult cheia (nil = todos): o bot desperta e usa a ult na próxima chance.
function BotService.Fill(model: Model?)
	for m in bots do
		if model == nil or m == model then
			AbilityService.SetEnergy(m, CharacterDefs.Energy.Max)
		end
	end
end

function BotService.List(): { Model }
	local list = {}
	for m in bots do
		table.insert(list, m)
	end
	return list
end

--- Comportamento predominante dos bots ("" sem bots).
function BotService.Behavior(): string
	local count: { [string]: number } = {}
	local best, bestN = "", 0
	for m in bots do
		local b = tostring(m:GetAttribute("Behavior") or "passive")
		count[b] = (count[b] or 0) + 1
		if count[b] > bestN then
			best, bestN = b, count[b]
		end
	end
	return best
end

function BotService.Count(): number
	return #BotService.List()
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function BotService.Init() end

function BotService.Start()
	-- passive: apanhou → revida contra quem bateu; bater também renova o aggro
	HealthService.Damaged.Event:Connect(function(victim: Model, _amount: number, attacker: Combatant.Fighter?)
		local b = bots[victim]
		if b and attacker and attacker ~= b.model and validTarget(b, attacker) then
			if not b.target or b.model:GetAttribute("Behavior") ~= "aggressive" then
				b.target = attacker
			end
			b.aggroUntil = os.clock() + BotService.Config.AggroSeconds
		end
		local attackerModel = Combatant.CharacterOf(attacker)
		local mine = attackerModel and bots[attackerModel :: Model]
		if mine then
			mine.aggroUntil = os.clock() + BotService.Config.AggroSeconds
		end
	end)
	-- boss/traidor/boneco bateu num bot: o passivo revida contra o NPC
	CombatService.NpcHitHook = function(attackerChar: Model, victim: Model, _dealt: number)
		local b = bots[victim]
		if b and isBossNpc(attackerChar) then
			if not b.target or b.model:GetAttribute("Behavior") ~= "aggressive" then
				b.target = attackerChar
			end
			b.aggroUntil = os.clock() + BotService.Config.AggroSeconds
		end
	end
	Log.debug("[BotService] pronto (bots com o combate real; padrão: só revidam quando apanham)")
end

return BotService
