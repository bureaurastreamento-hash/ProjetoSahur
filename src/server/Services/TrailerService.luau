--!strict
--[[
	TrailerService (servidor)
	Amostragem/trailer do jogo por script (comando DEV "Trailer"): ambiente controlado — bonecos apagados,
	jogador afastado, atores NPC (R6) no mapa, hora/noite controladas — e uma LINHA DO TEMPO que dispara os
	mesmos eventos que o jogo usa (NotifyAttack/Damage/Ability/Boss), então tudo que os clientes veem é o
	efeito real (animações, VFX, cutscene do despertar, transformação no boss), sem mexer em nenhum sistema.
	A câmera é do TrailerController (cliente): o servidor manda "shots" (CFrames no mundo, alvo para olhar,
	duração, FOV) e cartelas de texto. Ao acabar (ou "TrailerStop"), tudo é desfeito: atores, cópia da
	Arena_Antiga, hora automática, bonecos, HUD.

	Grave com OBS/Studio (View > Video Record) enquanto roda. Duração ~85 s.
	FUNDO (dono, 2026-09-17): dupla brigando o tempo todo num canto, dançarino, provocador que toma o Terremoto
	e voa, corredor que atravessa a praça, curioso reverenciando o altar que foge do boss, dupla na arena, aceno final.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local BossConfig = require(Modules:WaitForChild("BossConfig"))
local BossRigs = require(Modules:WaitForChild("BossRigs"))
local EnvironmentService = require(script.Parent:WaitForChild("EnvironmentService"))
local DummyService = require(script.Parent:WaitForChild("DummyService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))

local TrailerService = {}

local notifyTrailer: RemoteEvent
local notifyAttack: RemoteEvent
local notifyDamage: RemoteEvent
local notifyAbility: RemoteEvent
local notifyBoss: RemoteEvent
local notifyEmote: RemoteEvent
local notifyDash: RemoteEvent

local running = false
local token = 0
local actors: { [string]: Model? } = {}
local extras: { Instance } = {}
local parkedPlayers: { [Player]: CFrame } = {}

-- pontos do mundo (mapa importado + santuário do gerador)
local PLAZA = Vector3.new(0, 0.6, 0)
local ALTAR = Vector3.new(97.75, 4.9, 261.6)
local ARENA_ANTIGA_AT = Vector3.new(2500, 900, 2500)

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

local function send(event: string, data: { [string]: any })
	notifyTrailer:FireAllClients(event, data)
end

local function shot(data: { [string]: any })
	send("shot", data)
end

local function title(text: string, seconds: number, sub: string?)
	send("title", { text = text, seconds = seconds, sub = sub })
end

local function wait_(t: number, myToken: number): boolean
	task.wait(t)
	return running and token == myToken
end

--- Ator R6 (sem avatar: cinza) com Humanoid/Animator, colorido pelo personagem (só o torso).
local function makeActor(name: string, characterId: string, cf: CFrame, color: Color3?): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if not ok or typeof(model) ~= "Instance" then
		return nil
	end
	local m = model :: Model
	m.Name = "TrailerActor_" .. name
	for _, d in m:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Color = Color3.fromRGB(215, 205, 190)
		end
	end
	local torso = m:FindFirstChild("Torso") :: BasePart?
	if torso and color then
		torso.Color = color
	end
	local head = m:FindFirstChild("Head") :: BasePart?
	if head then
		head.Color = Color3.fromRGB(235, 200, 170)
	end
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayName = name
	hum.NameDisplayDistance = 0
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.MaxHealth = 1000
	hum.Health = 1000
	hum.BreakJointsOnDeath = false
	if not hum:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = hum
	end
	m:SetAttribute("CharacterId", characterId)
	CollectionService:AddTag(m, "Combatant")
	m:PivotTo(cf * CFrame.new(0, 3.05, 0))
	m.Parent = Workspace
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	actors[name] = m
	return m
end

local function actorRoot(name: string): BasePart?
	local m = actors[name]
	return m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function face(a: string, b: string)
	local ra, rb = actorRoot(a), actorRoot(b)
	if ra and rb then
		local p = ra.Position
		local target = Vector3.new(rb.Position.X, p.Y, rb.Position.Z)
		ra.CFrame = CFrame.lookAt(p, target)
	end
end

--- Soco do ator `a` em `b` (animação + VFX de swing + hit em todos os clientes), com empurrão no 4º.
local function punch(a: string, b: string, comboIndex: number, kind: string?)
	local ma, mb = actors[a], actors[b]
	if not ma or not mb then
		return
	end
	local mA: Model, mB: Model = ma, mb
	face(a, b)
	notifyAttack:FireAllClients(mA, "M1", comboIndex)
	task.delay(CombatConfig.Attacks.M1.HitDelay, function()
		if not running then
			return
		end
		local dmg = CombatConfig.Attacks.M1.ComboDamage[comboIndex] or 3
		notifyDamage:FireAllClients(mA, mB, dmg, kind or (if comboIndex >= 4 then "finisher" else "hit"))
		local rb, ra = actorRoot(b), actorRoot(a)
		if rb and ra and comboIndex >= 4 then
			local dir = (rb.Position - ra.Position) * Vector3.new(1, 0, 1)
			rb.AssemblyLinearVelocity = dir.Unit * 40 + Vector3.new(0, 18, 0)
		end
	end)
end

local function ability(a: string, characterId: string, abilityId: string, phase: string, data: { [string]: any }?)
	local m = actors[a]
	if m then
		notifyAbility:FireAllClients(m, characterId, abilityId, phase, data or {})
	end
end

local function cleanup()
	for _, m in actors do
		if m then
			m:Destroy()
		end
	end
	table.clear(actors)
	for _, inst in extras do
		inst:Destroy()
	end
	table.clear(extras)
	EnvironmentService.SetClockOverride(nil)
	DummyService.SetEnabled(true)
	for player, cf in parkedPlayers do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			AntiExploitService.Grace(player, 3)
			root.Anchored = false
			root.CFrame = cf
		end
	end
	table.clear(parkedPlayers)
	send("end", {})
	running = false
end

function TrailerService.Stop()
	if running then
		token += 1
		cleanup()
	end
end

-- ---------------------------------------------------------------------------
-- "Coisas de fundo" (dono, 2026-09-17): ações que ninguém precisa notar, mas quem reparar acha
-- engraçado/legal. Todas são atores extras com loops próprios, cancelados pelo token.
-- ---------------------------------------------------------------------------

local function emote(a: string, emoteId: string)
	local m = actors[a]
	if m then
		notifyEmote:FireAllClients(m, emoteId, true)
	end
end

--- Dois atores trocando socos sem parar (um combo cada, alternando), até o trailer acabar.
local function sparLoop(a: string, b: string, myToken: number)
	task.spawn(function()
		local attacker, victim = a, b
		while running and token == myToken and actors[a] and actors[b] do
			for i = 1, 4 do
				if not (running and token == myToken and actors[attacker] and actors[victim]) then
					return
				end
				-- só o 4º empurra; aqui nem isso (é fundo): dano visual sem knockback
				local ma, mb = actors[attacker], actors[victim]
				face(attacker, victim)
				notifyAttack:FireAllClients(ma, "M1", i)
				task.delay(CombatConfig.Attacks.M1.HitDelay, function()
					if running and token == myToken and ma and mb then
						notifyDamage:FireAllClients(ma, mb, 3, "hit")
					end
				end)
				task.wait(0.45)
			end
			task.wait(0.8)
			attacker, victim = victim, attacker
		end
	end)
end

--- Ator repetindo um emote em loop (com pausa) até o fim.
local function emoteLoop(a: string, emoteId: string, period: number, myToken: number)
	task.spawn(function()
		while running and token == myToken and actors[a] do
			emote(a, emoteId)
			task.wait(period)
		end
	end)
end

--- Ator "corre" de um ponto a outro (dash visual + deslocamento por tween no servidor).
local function dashAcross(a: string, from: Vector3, to: Vector3, seconds: number)
	local root = actorRoot(a)
	if not root then
		return
	end
	local dir = (to - from) * Vector3.new(1, 0, 1)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.zAxis
	root.CFrame = CFrame.lookAt(from, from + dir)
	notifyDash:FireAllClients(actors[a], { Direction = dir, Facing = dir, Speed = (to - from).Magnitude / seconds, Duration = seconds, Kind = "forward" })
	local tween = TweenService:Create(root, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + dir) })
	tween:Play()
end

--- Empurra um ator para longe (velocidade), com número de dano.
local function launch(fromModel: Model?, a: string, speed: number, up: number, damage: number, kind: string)
	local r = actorRoot(a)
	if not r then
		return
	end
	local origin = if fromModel then (fromModel:FindFirstChild("HumanoidRootPart") :: BasePart?) else nil
	local dir = if origin then (r.Position - origin.Position) * Vector3.new(1, 0, 1) else r.CFrame.LookVector * -1
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.xAxis
	if fromModel then
		notifyDamage:FireAllClients(fromModel, actors[a], damage, kind)
	end
	r.AssemblyLinearVelocity = dir * speed + Vector3.new(0, up, 0)
end

-- ---------------------------------------------------------------------------
-- Roteiro (~80 s)
-- ---------------------------------------------------------------------------

local function run(myToken: number)
	-- preparação: bonecos fora, jogadores estacionados longe (fora de quadro), fim de tarde
	DummyService.SetEnabled(false)
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			parkedPlayers[player] = root.CFrame
			AntiExploitService.Grace(player, 120)
			root.CFrame = CFrame.new(0, 300, -600)
			root.Anchored = true
		end
	end
	EnvironmentService.SetClockOverride(16.8)
	send("begin", {})

	local ORANGE = Color3.fromRGB(255, 150, 60)
	local BLUE = Color3.fromRGB(110, 230, 255)
	local PURPLE = Color3.fromRGB(170, 110, 255)
	local GOLD = Color3.fromRGB(255, 205, 80)
	local GREEN = Color3.fromRGB(120, 255, 160)
	local GREY = Color3.fromRGB(120, 120, 130)
	-- atores principais na praça
	makeActor("A", "Brawler", CFrame.new(PLAZA + Vector3.new(-3, 0, 0)) * CFrame.Angles(0, -math.pi / 2, 0), ORANGE)
	makeActor("B", "Swift", CFrame.new(PLAZA + Vector3.new(3, 0, 0)) * CFrame.Angles(0, math.pi / 2, 0), BLUE)
	makeActor("C", "Mystic", CFrame.new(PLAZA + Vector3.new(14, 0, 12)) * CFrame.Angles(0, math.rad(200), 0), PURPLE)
	makeActor("D", "Guardian", CFrame.new(PLAZA + Vector3.new(-12, 0, 14)) * CFrame.Angles(0, math.rad(150), 0), GOLD)
	-- FUNDO: X e Y trocando socos o trailer inteiro num canto; Z dançando sem parar; W provocando; S "sahur"
	makeActor("X", "Sahur", CFrame.new(PLAZA + Vector3.new(24, 0, -20)), GREEN)
	makeActor("Y", "Brawler", CFrame.new(PLAZA + Vector3.new(28, 0, -20)), GREY)
	makeActor("Z", "Swift", CFrame.new(PLAZA + Vector3.new(-26, 0, -12)) * CFrame.Angles(0, math.rad(40), 0), GREY)
	makeActor("W", "Mystic", CFrame.new(PLAZA + Vector3.new(-4, 0, 24)) * CFrame.Angles(0, math.rad(180), 0), GREY)
	makeActor("R", "Swift", CFrame.new(PLAZA + Vector3.new(-40, 0, -30)), GREY)
	sparLoop("X", "Y", myToken)
	emoteLoop("Z", "dance", 5.2, myToken)
	emoteLoop("W", "taunt", 3.0, myToken)
	if not wait_(0.5, myToken) then
		return
	end

	-- 1) abertura: voo sobre o mapa até a praça (8 s) — no fundo, a briga do canto e o dançarino já rolam
	shot({ from = CFrame.lookAt(Vector3.new(-260, 140, -420), Vector3.new(0, 10, 0)), to = CFrame.lookAt(Vector3.new(-40, 26, -70), Vector3.new(0, 4, 0)), t = 8, fov = 62, ease = "Sine" })
	title("SAHUR", 4.5, "battlegrounds")
	if not wait_(8, myToken) then
		return
	end

	-- 2) combo de socos com finisher (7 s): câmera baixa orbitando os dois; R atravessa o fundo correndo
	shot({ orbit = "TrailerActor_A", radius = 13, height = 3.5, from = 200, to = 290, t = 7, fov = 58 })
	task.delay(1.2, function()
		if running and token == myToken then
			dashAcross("R", PLAZA + Vector3.new(-40, 3.05, -30), PLAZA + Vector3.new(40, 3.05, -26), 2.2)
		end
	end)
	for i = 1, 4 do
		punch("A", "B", i)
		if not wait_(0.45, myToken) then
			return
		end
	end
	if not wait_(1.0, myToken) then
		return
	end
	-- B levanta e devolve: parry → crítico → BLACK FLASH (corte seco para perto no black flash)
	local rb = actorRoot("B")
	if rb then
		rb.CFrame = CFrame.lookAt(PLAZA + Vector3.new(6, 3.05, 0), PLAZA + Vector3.new(0, 3.05, 0))
	end
	face("A", "B")
	notifyAttack:FireAllClients(actors.A, "M1", 1)
	if not wait_(0.15, myToken) then
		return
	end
	notifyDamage:FireAllClients(actors.A, actors.B, 0, "parry")
	if not wait_(0.5, myToken) then
		return
	end
	punch("B", "A", 1, "crit")
	if not wait_(0.5, myToken) then
		return
	end
	shot({ from = CFrame.lookAt(PLAZA + Vector3.new(6, 2.4, -11), PLAZA + Vector3.new(0, 2.5, 0)), to = CFrame.lookAt(PLAZA + Vector3.new(8, 3, -14), PLAZA + Vector3.new(0, 2.5, 0)), t = 2.2, fov = 42, ease = "Sine" })
	punch("B", "A", 2, "blackflash")
	if not wait_(2.0, myToken) then
		return
	end

	-- 3) DASH + PISCAR com hit de chegada (4 s): B pisca para trás de A e A é jogado longe
	shot({ from = CFrame.lookAt(PLAZA + Vector3.new(-14, 6, 10), PLAZA + Vector3.new(0, 3, 0)), to = CFrame.lookAt(PLAZA + Vector3.new(-10, 5, 14), PLAZA + Vector3.new(0, 3, 0)), t = 4, fov = 60, ease = "Sine" })
	title("DASH = HIT", 2.5, "de frente, joga longe")
	local ra0 = actorRoot("A")
	if ra0 and rb then
		ra0.CFrame = CFrame.lookAt(PLAZA + Vector3.new(-4, 3.05, 0), PLAZA + Vector3.new(6, 3.05, 0))
		rb.CFrame = CFrame.lookAt(PLAZA + Vector3.new(10, 3.05, 0), PLAZA + Vector3.new(-4, 3.05, 0))
	end
	if not wait_(0.6, myToken) then
		return
	end
	ability("B", "Swift", "Blink", "start", { Teleported = true })
	if rb then
		rb.CFrame = CFrame.lookAt(PLAZA + Vector3.new(-1, 3.05, 0), PLAZA + Vector3.new(-6, 3.05, 0))
	end
	if not wait_(0.1, myToken) then
		return
	end
	launch(actors.B, "A", 70, 22, 4, "hit")
	if not wait_(1.6, myToken) then
		return
	end
	-- A volta e dá um UPPERCUT (pulo normal socando) em B
	if ra0 and rb then
		ra0.CFrame = CFrame.lookAt(PLAZA + Vector3.new(-5, 3.05, 0), PLAZA + Vector3.new(0, 3.05, 0))
		rb.CFrame = CFrame.lookAt(PLAZA + Vector3.new(0, 3.05, 0), PLAZA + Vector3.new(-5, 3.05, 0))
		ra0.AssemblyLinearVelocity = Vector3.new(0, 40, 0)
	end
	if not wait_(0.2, myToken) then
		return
	end
	notifyAttack:FireAllClients(actors.A, "Uppercut", 4)
	task.delay(0.12, function()
		if running and token == myToken and rb then
			notifyDamage:FireAllClients(actors.A, actors.B, 4, "hit")
			rb.AssemblyLinearVelocity = Vector3.new(0, 46, 0)
		end
	end)
	if not wait_(1.5, myToken) then
		return
	end

	-- 4) habilidades (10 s): plano aberto na praça; W (provocando) toma o Terremoto e voa — piada de fundo
	shot({ from = CFrame.lookAt(Vector3.new(28, 12, 34), PLAZA + Vector3.new(0, 3, 4)), to = CFrame.lookAt(Vector3.new(20, 9, 26), PLAZA + Vector3.new(0, 3, 4)), t = 10, fov = 64, ease = "Sine" })
	title("HABILIDADES", 3)
	local rw = actorRoot("W")
	if rw then
		rw.CFrame = CFrame.lookAt(PLAZA + Vector3.new(-8, 3.05, 18), PLAZA + Vector3.new(-12, 3.05, 14))
	end
	ability("D", "Guardian", "Quake", "start")
	task.delay(0.5, function()
		ability("D", "Guardian", "Quake", "hit")
		launch(actors.D, "W", 38, 24, 12, "finisher")
	end)
	if not wait_(1.6, myToken) then
		return
	end
	-- DOMÍNIO DO TEMPO de verdade: cúpula no ponto do B (o C dentro fica lento: só visual aqui)
	local rbNow = actorRoot("B")
	ability("B", "Swift", "TimeDome", "start", { Position = if rbNow then rbNow.Position else PLAZA, Radius = 30, Duration = 5 })
	if not wait_(1.8, myToken) then
		return
	end
	local meteorAt = PLAZA + Vector3.new(0, 0.6, 4)
	ability("C", "Mystic", "Meteor", "start", { Position = meteorAt })
	if not wait_(1.5, myToken) then
		return
	end
	ability("C", "Mystic", "Meteor", "hit", { Position = meteorAt })
	notifyDamage:FireAllClients(actors.C, actors.A, 30, "finisher")
	if not wait_(1.2, myToken) then
		return
	end
	ability("A", "Brawler", "Rampage", "start")
	task.delay(0.5, function()
		ability("A", "Brawler", "Rampage", "hit")
	end)
	if not wait_(2.4, myToken) then
		return
	end
	ability("B", "Swift", "TimeDome", "break", { Position = if rbNow then rbNow.Position else PLAZA, Radius = 30 })
	if not wait_(1.0, myToken) then
		return
	end

	-- 5) DESPERTAR (cutscene real vista de fora: pedras levitando, nome da ult) — corte para dentro no estouro
	local cut = CombatConfig.Awakening.Cutscene
	shot({ orbit = "TrailerActor_A", radius = 12, height = 4, from = 30, to = 120, t = cut.BurstAt, fov = 55 })
	title("DESPERTAR", 3)
	ability("A", "Brawler", "Awakening", "start", { Duration = CombatConfig.Awakening.Duration, Cutscene = cut.Duration, BurstAt = cut.BurstAt })
	if not wait_(cut.BurstAt - 0.05, myToken) then
		return
	end
	shot({ from = CFrame.lookAt(PLAZA + Vector3.new(0, 2.5, -9), PLAZA + Vector3.new(0, 1.5, 0)), to = CFrame.lookAt(PLAZA + Vector3.new(2, 4, -14), PLAZA + Vector3.new(0, 1.5, 0)), t = cut.Duration - cut.BurstAt + 0.8, fov = 66, ease = "Quart" })
	if not wait_(cut.Duration - cut.BurstAt + 0.8, myToken) then
		return
	end

	-- 6) anoitece → santuário (6 s): voo da praça até o altar; no fundo, um ator "reverencia" o altar
	EnvironmentService.SetClockOverride(21.5)
	shot({ from = CFrame.lookAt(Vector3.new(60, 40, 120), ALTAR + Vector3.new(0, 4, -10)), to = CFrame.lookAt(ALTAR + Vector3.new(-16, 8, -26), ALTAR + Vector3.new(0, 4, 0)), t = 6, fov = 60, ease = "Sine" })
	title("À NOITE, A FLECHA", 3.5, "quem a encontra vira o boss")
	local e = makeActor("E", "Overlord", CFrame.lookAt(ALTAR + Vector3.new(0, -4.3, -9), ALTAR), Color3.fromRGB(255, 80, 200))
	if e then
		local torso = e:FindFirstChild("Torso") :: BasePart?
		local RitualService = (require :: any)(script.Parent:WaitForChild("RitualService"))
		local arrow = RitualService.BuildArrow() :: Model
		if torso then
			local primary = arrow.PrimaryPart :: BasePart
			primary.Anchored = false
			arrow:PivotTo(torso.CFrame * CFrame.new(0.4, 0.3, 0.75) * CFrame.Angles(0, 0, math.rad(-30)))
			local w = Instance.new("WeldConstraint")
			w.Part0 = torso
			w.Part1 = primary
			w.Parent = primary
			arrow.Parent = e
		end
	end
	makeActor("F", "Guardian", CFrame.lookAt(ALTAR + Vector3.new(11, -4.3, -14), ALTAR), GREY) -- curioso reverenciando
	emoteLoop("F", "bow", 2.6, myToken)
	if not wait_(6, myToken) then
		return
	end

	-- 7) TRANSFORMAÇÃO vista de fora (câmera passando pelo ator) — 2,5 s de carga + boss aparece
	local eRoot = actorRoot("E")
	local ePos = if eRoot then eRoot.Position else ALTAR + Vector3.new(0, -1, -9)
	shot({ from = CFrame.lookAt(ePos + Vector3.new(-9, 1.5, -6), ePos + Vector3.new(0, 1, 0)), to = CFrame.lookAt(ePos + Vector3.new(9, 2.5, -8), ePos + Vector3.new(0, 2, 0)), t = 3.2, fov = 50, ease = "Sine", look = "TrailerActor_E" })
	notifyBoss:FireAllClients("transforming", { event = "transforming", by = "?", name = BossConfig.Name, seconds = 2.5, character = actors.E })
	if not wait_(2.6, myToken) then
		return
	end
	local rig = BossRigs.Build(BossConfig.Form.RigId)
	rig.Name = "TrailerActor_BOSS"
	local rigHum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	rigHum.WalkSpeed = 14
	rigHum.DisplayName = BossConfig.Name
	rigHum.NameDisplayDistance = 0
	rig:PivotTo(CFrame.lookAt(Vector3.new(ePos.X, ePos.Y + 1.5, ePos.Z), Vector3.new(ePos.X, ePos.Y + 1.5, ePos.Z - 20)))
	rig.Parent = Workspace
	local rigRoot = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		rigRoot:SetNetworkOwner(nil)
	end)
	actors.BOSS = rig
	if actors.E then
		actors.E:Destroy()
		actors.E = nil
	end
	ability("BOSS", "BigChop", "FleshWave", "start")
	notifyBoss:FireAllClients("summoned", { event = "summoned", by = "?", name = BossConfig.Name, model = rig, health = 1500, maxHealth = 1500, form = true, endsAt = Workspace:GetServerTimeNow() + 240 })
	-- o curioso F leva um susto e sai correndo
	task.delay(0.4, function()
		if running and token == myToken then
			local rf = actorRoot("F")
			if rf then
				dashAcross("F", rf.Position, rf.Position + Vector3.new(30, 0, -30), 1.8)
			end
		end
	end)
	if not wait_(1.4, myToken) then
		return
	end

	-- 8) o boss em ação (10 s): câmera baixa orbitando, ele avança, DEVORA (cura) e esmaga
	shot({ orbit = "TrailerActor_BOSS", radius = 30, height = 6, from = 160, to = 260, t = 10, fov = 60 })
	title("BIG C.H.O.P.", 3.5, "controlado por um jogador · devora para curar")
	local bossPos = rigRoot.Position
	local ra, rd = actorRoot("A"), actorRoot("D")
	if ra then
		ra.CFrame = CFrame.lookAt(bossPos + Vector3.new(-8, 0, -18), bossPos)
	end
	if rd then
		rd.CFrame = CFrame.lookAt(bossPos + Vector3.new(9, 0, -20), bossPos)
	end
	rigHum:MoveTo(bossPos + Vector3.new(0, 0, -12))
	if not wait_(1.4, myToken) then
		return
	end
	ability("BOSS", "BigChop", "Devour", "start", { Speed = 62, Duration = 0.45, Direction = -Vector3.zAxis })
	task.delay(0.35, function()
		ability("BOSS", "BigChop", "Devour", "hit", { Healed = 60 })
		launch(rig, "A", 55, 20, 24, "hit")
	end)
	if not wait_(1.2, myToken) then
		return
	end
	ability("BOSS", "BigChop", "Crush", "start")
	task.delay(0.6, function()
		ability("BOSS", "BigChop", "Crush", "hit")
		launch(rig, "D", 60, 26, 30, "finisher")
	end)
	if not wait_(2.4, myToken) then
		return
	end
	ability("BOSS", "BigChop", "Frenzy", "start")
	if not wait_(3.0, myToken) then
		return
	end
	notifyBoss:FireAllClients("despawned", { event = "despawned" })

	-- 9) arena da guerra de clã (7 s): cópia no céu, voo por cima; no fundo dois atores no ponto B
	local template = ServerStorage:FindFirstChild("Maps") and ServerStorage.Maps:FindFirstChild("Arena_Antiga")
	if template and template:IsA("Model") then
		local clone = template:Clone()
		clone.Name = "TrailerArena"
		clone:PivotTo(CFrame.new(ARENA_ANTIGA_AT))
		clone.Parent = Workspace
		table.insert(extras, clone)
		local floorY = ARENA_ANTIGA_AT.Y - 56
		local center = Vector3.new(ARENA_ANTIGA_AT.X, floorY + 4, ARENA_ANTIGA_AT.Z + 42)
		makeActor("G", "Brawler", CFrame.new(center + Vector3.new(-3, 4, 0)) * CFrame.Angles(0, -math.pi / 2, 0), Color3.fromRGB(110, 170, 255))
		makeActor("H", "Guardian", CFrame.new(center + Vector3.new(3, 4, 0)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(255, 140, 110))
		sparLoop("G", "H", myToken)
		EnvironmentService.SetClockOverride(17.5)
		shot({ from = CFrame.lookAt(ARENA_ANTIGA_AT + Vector3.new(-260, 110, 40), center), to = CFrame.lookAt(ARENA_ANTIGA_AT + Vector3.new(-60, 40, 42), center), t = 7, fov = 60, ease = "Sine" })
		title("GUERRA DE CLÃS", 3.5, "dominação em arenas")
		if not wait_(7, myToken) then
			return
		end
	end

	-- 10) fechamento: praça ao entardecer; W (que voou) volta e acena para a câmera; cartela final
	EnvironmentService.SetClockOverride(17.2)
	local rw2 = actorRoot("W")
	if rw2 then
		rw2.CFrame = CFrame.lookAt(PLAZA + Vector3.new(24, 3.05, 24), Vector3.new(90, 3, 90))
	end
	emoteLoop("W", "wave", 2.4, myToken)
	shot({ from = CFrame.lookAt(Vector3.new(90, 30, 90), PLAZA + Vector3.new(0, 4, 0)), to = CFrame.lookAt(Vector3.new(120, 60, 120), PLAZA + Vector3.new(0, 4, 0)), t = 6, fov = 58, ease = "Sine" })
	title("SAHUR", 5, "em breve")
	send("fade", { seconds = 5 })
	if not wait_(5.5, myToken) then
		return
	end
	cleanup()
	Log.debug("[TrailerService] trailer concluído")
end

--- Roda o trailer (comando DEV). Retorna (ok, mensagem).
function TrailerService.Run(): (boolean, string)
	if running then
		return false, "trailer já está rodando (TrailerStop para parar)"
	end
	running = true
	token += 1
	local myToken = token
	task.spawn(function()
		local ok, err = pcall(function()
			run(myToken)
		end)
		if not ok then
			warn("[TrailerService] erro: " .. tostring(err))
			cleanup()
		end
	end)
	return true, "trailer rodando (~85 s). Grave a tela; TrailerStop interrompe."
end

function TrailerService.Init()
	notifyTrailer = Remotes.GetEvent(Remotes.Events.NotifyTrailer)
	notifyAttack = Remotes.GetEvent(Remotes.Events.NotifyAttack)
	notifyDamage = Remotes.GetEvent(Remotes.Events.NotifyDamage)
	notifyAbility = Remotes.GetEvent(Remotes.Events.NotifyAbility)
	notifyBoss = Remotes.GetEvent(Remotes.Events.NotifyBoss)
	notifyEmote = Remotes.GetEvent(Remotes.Events.NotifyEmote)
	notifyDash = Remotes.GetEvent(Remotes.Events.NotifyDash)
end

return TrailerService
