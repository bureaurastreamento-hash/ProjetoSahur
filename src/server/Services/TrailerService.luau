--!strict
--[[
	TrailerService (servidor) — v3 (dono, 2026-10-01): TRAILER ÉPICO/SÉRIO de Bizarre Showdown F/X, textos em
	inglês, sem música (o dono põe na edição), duas versões:
	  "h" = 16:9 para YouTube (~115 s)      "v" = 9:16 para TikTok/Shorts (~60 s)
	Os atores são BOTS com o combate REAL (Combat/Movement/Ability/Ragdoll/Boss); a coreografia decide QUEM faz O
	QUÊ e QUANDO, e o TrailerController desenha câmera, cor, cartelas e efeitos de cena (Parada do Tempo, portal,
	Flecha, roleta, "ゴゴゴ", logo, To Be Continued).
	Sincronia: cada cena tem duração FIXA e cada evento é marcado em tempo ABSOLUTO desde o fim da contagem (T0),
	então nada escorrega. O log do servidor imprime a FOLHA DE TEMPOS ("[Trailer] 00:12.0 ...") para casar a música
	na edição.
	Fluxo: begin (tela preta) → elenco nasce escondido nos sets → contagem 3-2-1 (canto da tela) → trailer → preto
	→ fim. Ambiente controlado: inimigos/bots do mapa ficam parados e invisíveis na tela, nomes/HUD somem, bonecos
	de treino desligam, jogadores ficam estacionados no alto.
	Sets: posições em MARKS; o dono pode ajustar sem código pondo uma Part em Workspace.TrailerMarks.<Nome>.
	DEV: "TrailerScene <cena> [v]" roda uma cena só; "Trailer" (h) / "TrailerV" (v) o trailer inteiro.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local BossConfig = require(Modules:WaitForChild("BossConfig"))
local EnvironmentService = require(script.Parent:WaitForChild("EnvironmentService"))
local DummyService = require(script.Parent:WaitForChild("DummyService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local MovementService = require(script.Parent:WaitForChild("MovementService"))
local AbilityService = require(script.Parent:WaitForChild("AbilityService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local BossService = require(script.Parent:WaitForChild("BossService"))

local TrailerService = {}

local V = Vector3.new

-- ---------------------------------------------------------------------------
-- Sets (chão achado por raycast; Workspace.TrailerMarks.<Nome> sobrepõe)
-- ---------------------------------------------------------------------------
local MARKS: { [string]: Vector3 } = {
	Porto = V(30, 0, 228), -- cais do Porto da Névoa (mar ao norte, +Z)
	Praia = V(72, 0, 213), -- destroços da Missão 0
	Estrutura = V(96, 0, 206), -- a estrutura enterrada
	Vila = V(-77, 0, 60), -- praça do mercado da Vila Nova
	Coliseu = V(901, 0, -339), -- arena do Coliseu do Deserto (areia, raio ~97)
	Templo = V(1800, 41, -305), -- topo do templo da Rota do Eclipse
	Campos = V(-470, 8, -60), -- Campos da Névoa
	Boss = V(900, 1.5, -581), -- santuário do boss (BossArena)
	Portal = V(36, 0, 150), -- praça do Porto (spawn), portal virado para o sul
}

require(Modules.IslandLayout).TranslateTable(MARKS)

-- ---------------------------------------------------------------------------
-- Estado
-- ---------------------------------------------------------------------------
local notifyTrailer: RemoteEvent
local running = false
local token = 0
local format = "h"
local T0 = 0
local parkedPlayers: { [Player]: CFrame } = {}
local cast: { [string]: Model } = {}
local mutedBots: { [Model]: string } = {}
local summonedBoss = false

local function send(event: string, data: { [string]: any }?)
	notifyTrailer:FireAllClients(event, data or {})
end

local function stamp(t: number): string
	return ("%02d:%04.1f"):format(math.floor(t / 60), t % 60)
end

local function cue(label: string)
	Log.info(("[Trailer] %s  %s"):format(stamp(os.clock() - T0), label))
end

--- Espera até T0 + t (tempo absoluto do trailer); false = interrompido.
local function waitUntil(t: number, myToken: number): boolean
	local d = T0 + t - os.clock()
	if d > 0 then
		task.wait(d)
	end
	return running and token == myToken
end

-- ---------------------------------------------------------------------------
-- Chão / sets
-- ---------------------------------------------------------------------------
local RAY = RaycastParams.new()
RAY.FilterType = Enum.RaycastFilterType.Exclude
RAY.RespectCanCollide = true

local function groundAt(x: number, z: number, fromY: number): Vector3
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, m in BotService.List() do
		table.insert(exclude, m)
	end
	local props = Workspace:FindFirstChild("TrailerProps")
	if props then
		table.insert(exclude, props)
	end
	RAY.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(V(x, fromY + 60, z), V(0, -200, 0), RAY)
	return if hit then hit.Position else V(x, fromY, z)
end

local markCache: { [string]: Vector3 } = {}
local function mark(name: string): Vector3
	local cached = markCache[name]
	if cached then
		return cached
	end
	local folder = Workspace:FindFirstChild("TrailerMarks")
	local part = folder and folder:FindFirstChild(name)
	local base = if part and part:IsA("BasePart") then part.Position else MARKS[name] or Vector3.zero
	local g = groundAt(base.X, base.Z, base.Y)
	markCache[name] = g
	return g
end

-- ---------------------------------------------------------------------------
-- Comandos para o cliente
-- ---------------------------------------------------------------------------
type ShotOpts = { fov0: number?, fov1: number?, ease: string?, roll0: number?, roll1: number?, hand: number?, look: any?, wide: boolean?, dof: any?, lookUp: number?, frame: { any }? }

local function path(pts: { CFrame | Vector3 }, t: number, o: ShotOpts?)
	local list: { CFrame } = {}
	for _, p in pts do
		table.insert(list, if typeof(p) == "Vector3" then CFrame.new(p) else p :: CFrame)
	end
	local data: { [string]: any } = { kind = "path", pts = list, t = t }
	for k, v in (o or {}) :: any do
		data[k] = v
	end
	send("shot", data)
end

local function orbit(center: any, radius: number, height: number, a0: number, a1: number, t: number, o: ShotOpts?)
	local data: { [string]: any } = { kind = "orbit", center = center, radius = radius, height = height, a0 = a0, a1 = a1, t = t }
	for k, v in (o or {}) :: any do
		data[k] = v
	end
	send("shot", data)
end

local function title(style: string, text: string, seconds: number, sub: string?, color: Color3?)
	send("title", { style = style, text = text, seconds = seconds, sub = sub, color = color })
	cue(("TEXT %s \"%s\"%s"):format(style, text, if sub then " / " .. sub else ""))
end

local function grade(preset: string, seconds: number?)
	send("grade", { preset = preset, seconds = seconds or 0 })
end

local function clock(hour: number)
	EnvironmentService.SetClockOverride(hour)
end

local function sfx(key: string, model: Model?)
	send("sound", { key = key, model = if model then model.Name else nil })
end

local function vfx(model: Model?, key: string, at: Vector3?)
	if model then
		send("vfx", { model = model.Name, key = key, at = at })
	end
end

local function anim(model: Model?, key: string, stop: boolean?)
	if model then
		send("anim", { model = model.Name, key = key, stop = stop })
	end
end

local function punch(fov: number, shake: number, seconds: number?)
	send("punch", { fov = fov, shake = shake, seconds = seconds or 0.4 })
end

local function impact(seconds: number?)
	send("impact", { seconds = seconds or 0.14 })
end

local function flash(seconds: number?, color: Color3?)
	send("flash", { seconds = seconds or 0.5, color = color })
end

local function fade(to: number, seconds: number)
	send("fade", { to = to, seconds = seconds })
end

-- ---------------------------------------------------------------------------
-- Elenco (bots com o combate real)
-- ---------------------------------------------------------------------------
type CastDef = { char: string, mark: string, offset: Vector3 }
local CAST: { [string]: CastDef } = {
	drifter = { char = "Humano", mark = "Praia", offset = V(0, 0, -3) },
	f1 = { char = "Jotaro", mark = "Coliseu", offset = V(-6, 0, 40) },
	f2 = { char = "Dio", mark = "Coliseu", offset = V(-2, 0, 40) },
	f3 = { char = "Kira", mark = "Coliseu", offset = V(2, 0, 40) },
	f4 = { char = "Swift", mark = "Coliseu", offset = V(6, 0, 40) },
	bag1 = { char = "Humano", mark = "Coliseu", offset = V(-10, 0, 46) },
	bag2 = { char = "Humano", mark = "Coliseu", offset = V(0, 0, 46) },
	bag3 = { char = "Humano", mark = "Coliseu", offset = V(10, 0, 46) },
	visitor = { char = "Rick", mark = "Portal", offset = V(0, 0, 30) },
}

-- golpes que derrubam jogam os atores bem mais perto (no jogo eles voam para fora do quadro)
local KNOCKBACK_SCALE = 0.35

local function rootOf(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(model: Model?): Humanoid?
	return model and model:FindFirstChildOfClass("Humanoid")
end

--- Põe o ator em pé em `at` (chão) olhando para `lookAt`.
local function put(model: Model?, at: Vector3, lookAt: Vector3)
	local r = rootOf(model)
	if not model or not r then
		return
	end
	r.Anchored = false
	r.AssemblyLinearVelocity = Vector3.zero
	r.AssemblyAngularVelocity = Vector3.zero
	local g = groundAt(at.X, at.Z, at.Y)
	r.CFrame = CFrame.lookAt(g + V(0, 3.05, 0), V(lookAt.X, g.Y + 3.05, lookAt.Z))
	local h = humanoidOf(model)
	if h then
		h:MoveTo(r.Position)
	end
end

local function face(a: Model?, b: Model?)
	local ra, rb = rootOf(a), rootOf(b)
	if ra and rb then
		ra.CFrame = CFrame.lookAt(ra.Position, V(rb.Position.X, ra.Position.Y, rb.Position.Z))
	end
end

local function setVisible(model: Model?, visible: boolean)
	if model then
		model:SetAttribute("TrailerHidden", if visible then nil else true)
	end
end

--- Levanta, cura, tira atordoamento: o ator volta "novo" para a próxima tomada.
local function refresh(model: Model?)
	if not model or not model.Parent then
		return
	end
	RagdollService.Recover(model)
	CombatService.ClearStun(model)
	local h = humanoidOf(model)
	if h then
		HealthService.Heal(model, h.MaxHealth)
	end
	local r = rootOf(model)
	if r then
		r.Anchored = false
	end
	BotService.SetBehavior(model, "idle")
end

local function spawnCast(key: string): Model?
	local def = CAST[key]
	if not def then
		return nil
	end
	local existing = cast[key]
	if existing and existing.Parent then
		return existing
	end
	local base = mark(def.mark) + def.offset
	local g = groundAt(base.X, base.Z, base.Y)
	local model = BotService.Spawn({
		Name = "TR_" .. key,
		CharacterId = def.char,
		CFrame = CFrame.new(g),
		Behavior = "idle",
		Respawn = false,
		Team = "trailer_" .. key, -- cada ator no próprio time: todos se acertam
		Attributes = { MaxHealth = 100000, TrailerCast = true, TrailerHidden = true, KnockbackScale = KNOCKBACK_SCALE },
	})
	if model then
		cast[key] = model
	end
	return model
end

local function c(key: string): Model?
	local m = cast[key]
	return if m and m.Parent then m else nil
end

-- ---------------------------------------------------------------------------
-- Preparação / limpeza
-- ---------------------------------------------------------------------------
local function prepare(castKeys: { string })
	DummyService.SetEnabled(false)
	-- figurantes: bots do mapa (inimigos, ecos) param e somem da tela
	for _, m in BotService.List() do
		if m:GetAttribute("TrailerCast") ~= true and mutedBots[m] == nil then
			mutedBots[m] = tostring(m:GetAttribute("Behavior") or "passive")
			BotService.SetBehavior(m, "idle")
			m:SetAttribute("TrailerHidden", true)
		end
	end
	-- jogadores: estacionados no alto, invisíveis
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character and root then
			parkedPlayers[player] = root.CFrame
			AntiExploitService.Grace(player, 900)
			root.CFrame = CFrame.new(0, 320, -600)
			root.Anchored = true
			character:SetAttribute("TrailerHidden", true)
		end
	end
	-- elenco em paralelo (CreateHumanoidModelFromDescription demora): só segue com todos prontos (≤ 25 s)
	local pending = #castKeys
	for _, key in castKeys do
		task.spawn(function()
			local ok, err = pcall(spawnCast, key)
			if not ok then
				warn("[TrailerService] ator " .. key .. ": " .. tostring(err))
			end
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	if pending > 0 then
		warn(("[TrailerService] %d ator(es) não ficaram prontos a tempo"):format(pending))
	end
	task.wait(1) -- avatares/acessórios terminam de carregar
end

local function cleanup()
	for key, m in cast do
		if m.Parent then
			BotService.Remove(m)
			if m.Parent then
				m:Destroy()
			end
		end
		cast[key] = nil
	end
	if summonedBoss and BossService.GetState() == "Fighting" then
		BossService.Despawn()
	end
	summonedBoss = false
	for m, behavior in mutedBots do
		if m.Parent then
			m:SetAttribute("TrailerHidden", nil)
			BotService.SetBehavior(m, behavior)
		end
	end
	table.clear(mutedBots)
	EnvironmentService.SetClockOverride(nil)
	DummyService.SetEnabled(true)
	for player, cf in parkedPlayers do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character and root then
			AntiExploitService.Grace(player, 3)
			root.Anchored = false
			root.CFrame = cf
			character:SetAttribute("TrailerHidden", nil)
		end
	end
	table.clear(parkedPlayers)
	table.clear(markCache)
	send("end")
	running = false
end

function TrailerService.IsRunning(): boolean
	return running
end

function TrailerService.Stop()
	if running then
		token += 1
		cleanup()
	end
end

-- ---------------------------------------------------------------------------
-- CENAS: duração fixa (h / v); ctx.at(t) espera até t segundos DESDE O COMEÇO DA CENA
-- ---------------------------------------------------------------------------
type Ctx = { v: boolean, at: (t: number) -> boolean }
type Scene = { dur: number, durV: number?, cast: { string }, fn: (ctx: Ctx) -> boolean }
local S: { [string]: Scene } = {}

local EAST = V(1, 0, 0)

-- 1. Abertura: frase no preto → o Porto da Névoa nasce da névoa, vindo do mar
S.open = { dur = 8, durV = 5, cast = {}, fn = function(ctx)
	local P = mark("Porto")
	clock(6.3)
	grade("mist")
	path({ P + V(-70, 5, 240), P + V(-40, 10, 160), P + V(-12, 18, 95) }, if ctx.v then 5 else 8, { look = P + V(0, 8, -10), fov0 = 50, fov1 = 46, ease = "Sine", wide = true, hand = 0.15 })
	sfx("Shared/Awakening_Riser")
	if not ctx.at(0.3) then
		return false
	end
	title("card", "EVERY ERA BROKE AT ONCE.", if ctx.v then 1.9 else 2.9)
	if not ctx.at(if ctx.v then 2.4 else 3.6) then
		return false
	end
	fade(0, if ctx.v then 0.8 else 1.6)
	if not ctx.at(if ctx.v then 2.9 else 4.6) then
		return false
	end
	title("place", "PORT OF MIST", if ctx.v then 1.8 else 2.8, "CHAPTER 1  ·  THE FIRST FRACTURE")
	return true
end }

-- 2. A praia: o sobrevivente anda pelos destroços até a estrutura enterrada e a toca (clarão)
S.beach = { dur = 7, cast = { "drifter" }, fn = function(ctx)
	local D = mark("Praia")
	local E = mark("Estrutura")
	local drifter = c("drifter")
	if not drifter then
		return false
	end
	clock(6.6)
	grade("mist")
	refresh(drifter)
	local dir = (V(E.X, 0, E.Z) - V(D.X, 0, D.Z)).Unit
	local right = dir:Cross(V(0, 1, 0))
	local touchAt = E - dir * 3.2
	local startAt = touchAt - dir * 12
	local glow = E + V(0, 3, 0)
	put(drifter, startAt, E)
	setVisible(drifter, true)
	local h = humanoidOf(drifter)
	if h then
		h:MoveTo(touchAt)
	end
	-- plano aberto de lado: ele e a estrutura no quadro, caminhando até ela
	path({ startAt + right * 14 + dir * 2 + V(0, 3, 0), startAt + right * 12 + dir * 7 + V(0, 3.4, 0) }, 4.4,
		{ look = glow, fov0 = 46, fov1 = 42, hand = 0.2, frame = { drifter.Name :: any, glow } })
	if not ctx.at(0.6) then
		return false
	end
	title("card", "YOU SHOULDN'T BE IN ONE PIECE.", 2.4)
	if not ctx.at(4.4) then
		return false
	end
	-- por cima do ombro: a mão e o ponto que ele toca no centro
	put(drifter, touchAt, E)
	path({ touchAt - dir * 4.5 + right * 2.2 + V(0, 2.2, 0), touchAt - dir * 3.6 + right * 1.6 + V(0, 2.4, 0) }, 2.6,
		{ look = glow, fov0 = 44, fov1 = 38, hand = 0.15, dof = glow, frame = { drifter.Name :: any, glow } })
	if not ctx.at(4.8) then
		return false
	end
	anim(drifter, "Trailer/Reach")
	if not ctx.at(5.6) then
		return false
	end
	flash(0.7)
	sfx("Shared/Awakening_Pulse")
	vfx(drifter, "Shared/Awakening_Burst", glow)
	punch(-6, 0.5, 0.5)
	if not ctx.at(6.8) then
		return false
	end
	setVisible(drifter, false)
	return true
end }

-- 3. O mundo: montagem de 4 lugares, 3 s cada, com o nome embaixo
S.world = { dur = 12, cast = {}, fn = function(ctx)
	local vila = mark("Vila")
	clock(10)
	grade("normal")
	orbit(vila + V(0, 4, 0), 46, 24, 200, 238, 3.1, { fov0 = 55, fov1 = 52, wide = true })
	title("place", "NEW VILLAGE", 2.4, "PORT OF MIST")
	if not ctx.at(3) then
		return false
	end
	local col = mark("Coliseu")
	clock(13.5)
	grade("desert")
	path({ col + V(-215, 5, -60), col + V(-170, 45, -30) }, 3.1, { look = col + V(0, 18, 0), fov0 = 50, fov1 = 48, wide = true, ease = "Quad" })
	title("place", "DESERT OF THE SUN", 2.4, "THE COLOSSEUM AWAITS")
	if not ctx.at(6) then
		return false
	end
	local temple = mark("Templo")
	clock(17.4)
	grade("eclipse")
	orbit(temple + V(0, -10, 0), 120, 55, 120, 150, 3.1, { fov0 = 50, lookUp = 10, wide = true })
	title("place", "ECLIPSE ROUTE", 2.4, "WHERE THE SUN BROKE")
	if not ctx.at(9) then
		return false
	end
	local fields = mark("Campos")
	clock(18.7)
	grade("dusk")
	orbit(fields + V(0, 6, 0), 140, 45, 300, 328, 3.1, { fov0 = 52, lookUp = 0, wide = true })
	title("place", "MISTFIELDS", 2.4, "NOTHING HERE IS FROM THIS ERA")
	return true
end }

-- 4. A Flecha: escolhe, atravessa, o Stand surge e a raridade gira até o ANÔMALO
S.arrow = { dur = 11, durV = 9, cast = { "f1" }, fn = function(ctx)
	local T = mark("Templo")
	local hero = c("f1")
	if not hero then
		return false
	end
	local fwd = V(0, 0, -1)
	local side = V(1, 0, 0)
	clock(17.2)
	grade("eclipse")
	refresh(hero)
	put(hero, T, T + fwd * 10)
	setVisible(hero, true)
	local A = T + fwd * 7 + V(0, 4.2, 0)
	send("arrow", { phase = "show", at = A })
	path({ A + V(3, 0.6, 2.2), A + V(1.6, 0.25, 3.4) }, if ctx.v then 2.6 else 3.2, { look = A, fov0 = 30, fov1 = 25, hand = 0.15, dof = A })
	if not ctx.at(0.3) then
		return false
	end
	title("card", "THE ARROW CHOOSES.", if ctx.v then 1.8 else 2.4)
	local flyAt = if ctx.v then 2.6 else 3.2
	if not ctx.at(flyAt) then
		return false
	end
	path({ T + side * 13 + fwd * 3.5 + V(0, 3, 0), T + side * 11 + fwd * 3 + V(0, 3.2, 0) }, 1.4, { look = T + fwd * 3 + V(0, 3.5, 0), fov0 = 44, fov1 = 40, frame = { hero.Name :: any, A } })
	if not ctx.at(flyAt + 0.2) then
		return false
	end
	send("arrow", { phase = "fly", target = hero.Name, seconds = 0.4 })
	cue("ARROW HIT")
	if not ctx.at(flyAt + 0.62) then
		return false
	end
	anim(hero, "Trailer/Pierced")
	flash(0.5)
	sfx("Shared/Awakening_Impact")
	vfx(hero, "Shared/Awakening_Burst")
	punch(-10, 0.9, 0.5)
	impact(0.12)
	if not ctx.at(flyAt + 1.4) then
		return false
	end
	local rollFor = if ctx.v then 5 else 5.6
	orbit(hero.Name, 9, 2.4, 250, 300, rollFor + 0.6, { fov0 = 52, fov1 = 46, lookUp = 2.5, frame = { hero.Name } })
	send("stand", { model = hero.Name, seconds = rollFor + 0.6, scale = 1.15 })
	sfx("Shared/Awakening_Pulse")
	if not ctx.at(flyAt + 1.6) then
		return false
	end
	send("roulette", { seconds = rollFor })
	cue("ROULETTE (final ~" .. stamp(os.clock() - T0 + rollFor - 1.2) .. ")")
	return true
end }

local function colosseum(): Vector3
	return mark("Coliseu")
end

-- 5. Combo de 4 socos com finalizador
S.combo = { dur = 4.5, durV = 4, cast = { "f1", "f4" }, fn = function(ctx)
	local C = colosseum()
	local a, b = c("f1"), c("f4")
	if not a or not b then
		return false
	end
	clock(15.2)
	grade("desert")
	refresh(a)
	refresh(b)
	put(a, C + V(-2.6, 0, 0), C + V(3, 0, 0))
	put(b, C + V(2.6, 0, 0), C + V(-3, 0, 0))
	setVisible(a, true)
	setVisible(b, true)
	path({ C + V(-2, 1.7, -9), C + V(1.5, 1.9, -8.4) }, 2.3, { look = C + V(0, 2.4, 0), fov0 = 46, fov1 = 42, hand = 0.25, frame = { a.Name, b.Name } })
	if not ctx.at(0.3) then
		return false
	end
	title("move", "4-HIT COMBO", 2.2, nil, Color3.fromRGB(120, 90, 255))
	for i = 1, 4 do
		if not ctx.at(0.4 + (i - 1) * 0.5) then
			return false
		end
		face(a, b)
		CombatService.Attack(a, "M1")
	end
	if not ctx.at(2.05) then
		return false
	end
	punch(-10, 0.9, 0.45)
	impact(0.12)
	if not ctx.at(2.3) then
		return false
	end
	path({ C + V(4, 2, -8), C + V(14, 3, -10) }, 2.2, { look = b.Name, fov0 = 50, fov1 = 54, frame = { a.Name, b.Name } })
	return true
end }

-- 6. Parry → crítico → parry de novo → BLACK FLASH (coreografado com as funções reais)
S.parry = { dur = 6.5, cast = { "f1", "f2" }, fn = function(ctx)
	local P = colosseum() + V(0, 0, 8)
	local a, b = c("f2"), c("f1")
	if not a or not b then
		return false
	end
	setVisible(c("f4"), false)
	refresh(a)
	refresh(b)
	put(a, P + V(-3, 0, 0), P + V(3, 0, 0))
	put(b, P + V(3, 0, 0), P + V(-3, 0, 0))
	setVisible(a, true)
	setVisible(b, true)
	path({ P + V(0, 3, -11), P + V(2.5, 3.5, -12) }, 3.0, { look = P + V(0, 2.4, 0), fov0 = 42, fov1 = 38, hand = 0.2, frame = { a.Name, b.Name } })
	local function exchange(start: number, label: string, color: Color3, big: boolean): boolean
		if not ctx.at(start) then
			return false
		end
		face(a, b)
		face(b, a)
		CombatService.Block(b, true)
		if not ctx.at(start + 0.12) then
			return false
		end
		CombatService.Attack(a, "M1")
		if not ctx.at(start + 0.47) then
			return false
		end
		CombatService.Block(b, false)
		if not ctx.at(start + 0.72) then
			return false
		end
		CombatService.Attack(b, "M1") -- crítico (×3) — ou Black Flash (×6) se for o 2º seguido
		if not ctx.at(start + 0.87) then
			return false
		end
		title("move", label, if big then 1.8 else 1.2, nil, color)
		if big then
			impact(0.22)
			punch(-14, 1.3, 0.6)
		else
			punch(-6, 0.5, 0.35)
		end
		return true
	end
	if not ctx.at(0.4) then
		return false
	end
	title("move", "PERFECT PARRY", 1.0, nil, Color3.fromRGB(255, 230, 140))
	if not exchange(0.6, "CRITICAL", Color3.fromRGB(255, 120, 80), false) then
		return false
	end
	if not ctx.at(3.0) then
		return false
	end
	put(a, P + V(-3, 0, 0), P + V(3, 0, 0))
	put(b, P + V(3, 0, 0), P + V(-3, 0, 0))
	path({ P + V(5, 2.4, -9), P + V(7, 3, -11) }, 3.5, { look = P + V(0, 2.4, 0), fov0 = 40, fov1 = 36, hand = 0.2, frame = { a.Name, b.Name } })
	return exchange(3.2, "BLACK FLASH", Color3.fromRGB(200, 20, 40), true)
end }

-- 7. Dash de longe com hit de chegada
S.dash = { dur = 4, cast = { "f2", "f3" }, fn = function(ctx)
	local P = colosseum() + V(0, 0, -10)
	local reach = CombatConfig.Dash.Speed * CombatConfig.Dash.Duration * CharacterDefs.DashTuning.ForwardScale
	local a, b = c("f3"), c("f2")
	if not a or not b then
		return false
	end
	setVisible(c("f1"), false)
	refresh(a)
	refresh(b)
	put(a, P + V(-(reach + 2), 0, 0), P)
	put(b, P, P - EAST * reach)
	setVisible(a, true)
	setVisible(b, true)
	path({ P + V(-reach - 2, 1.2, -6), P + V(-3, 1.4, -7) }, 1.2, { look = a.Name, fov0 = 52, fov1 = 44, ease = "Quad", frame = { a.Name } })
	if not ctx.at(0.4) then
		return false
	end
	MovementService.Dash(a, EAST, EAST)
	title("move", "DASH STRIKE", 1.8, nil, Color3.fromRGB(170, 110, 255))
	if not ctx.at(0.75) then
		return false
	end
	punch(-10, 0.9, 0.4)
	impact(0.1)
	if not ctx.at(1.2) then
		return false
	end
	path({ P + V(2, 2, -7), P + V(12, 3, -9) }, 2.8, { look = b.Name, fov0 = 52, fov1 = 56, frame = { a.Name, b.Name } })
	return true
end }

-- 8. Golpes de Stand: três batidas de 2,5 s (no 9:16 só duas)
S.rush = { dur = 7.5, durV = 5, cast = { "f1", "f3", "f4", "bag1", "bag2", "bag3" }, fn = function(ctx)
	local C = colosseum()
	for _, k in { "f2", "f3", "f4" } do
		setVisible(c(k), false)
	end
	local beats = {
		{ who = "f1", bag = "bag1", spot = C + V(0, 0, 14), gap = 5, slot = 1, label = "STAND RUSH", color = Color3.fromRGB(120, 90, 255),
			cam = { V(7, 2.8, -5), V(6, 3, -6.2) }, look = V(1.5, 2.6, 0), fov = 46 },
		{ who = "f4", bag = "bag2", spot = C + V(0, 0, -18), gap = 14, slot = 2, label = "WIND BLADE", color = Color3.fromRGB(110, 230, 255),
			cam = { V(-5, 3, -4), V(-3, 3.2, -5) }, look = V(6, 2, 0), fov = 50 },
		{ who = "f3", bag = "bag3", spot = C + V(0, 0, 26), gap = 8, slot = 2, label = "COIN BOMB", color = Color3.fromRGB(170, 110, 255),
			cam = { V(3.5, 1, -9), V(5, 2, -10) }, look = V(4, 2, 0), fov = 48 },
	}
	local order: { number } = if ctx.v then { 1, 3 } else { 1, 2, 3 }
	for n, i in order do
		local beat = beats[i]
		local start = (n - 1) * 2.5
		if not ctx.at(start) then
			return false
		end
		if n > 1 then
			local prev = beats[order[n - 1]]
			setVisible(c(prev.who), false)
			setVisible(c(prev.bag), false)
		end
		local a, b = c(beat.who), c(beat.bag)
		if not a or not b then
			return false
		end
		refresh(a)
		refresh(b)
		put(a, beat.spot, beat.spot + EAST * beat.gap)
		put(b, beat.spot + EAST * beat.gap, beat.spot)
		setVisible(a, true)
		setVisible(b, true)
		path({ beat.spot + beat.cam[1], beat.spot + beat.cam[2] }, 2.5, { look = beat.spot + beat.look, fov0 = beat.fov, fov1 = beat.fov - 4, hand = 0.25, frame = { a.Name, b.Name } })
		if not ctx.at(start + 0.2) then
			return false
		end
		AbilityService.Use(a, beat.slot, EAST)
		title("move", beat.label, 1.8, nil, beat.color)
	end
	return true
end }

-- 9. PARADA DO TEMPO: o rival pula; o tempo para no ar (imagem congela, P&B); o Stand descarrega; o tempo volta
S.timestop = { dur = 11, durV = 10, cast = { "f1", "f2" }, fn = function(ctx)
	local W = colosseum() + V(0, 0, -22)
	local a, b = c("f1"), c("f2")
	if not a or not b then
		return false
	end
	for _, k in { "f3", "f4", "bag1", "bag2", "bag3" } do
		setVisible(c(k), false)
	end
	clock(17)
	grade("dusk")
	refresh(a)
	refresh(b)
	put(a, W + V(-6, 0, 0), W + V(10, 0, 0))
	put(b, W + V(10, 0, 0), W + V(-6, 0, 0))
	setVisible(a, true)
	setVisible(b, true)
	path({ W + V(-13, 3, -7), W + V(-11, 3.4, -8) }, 0.6, { look = W + V(4, 2, 0), fov0 = 50, hand = 0.3, frame = { a.Name, b.Name } })
	local hb = humanoidOf(b)
	if hb then
		hb:MoveTo(W + V(-5, 0, 0))
	end
	if not ctx.at(0.28) then
		return false
	end
	if hb then
		hb.Jump = true
	end
	anim(a, "Trailer/TimeStop")
	if not ctx.at(0.52) then
		return false
	end
	-- O TEMPO PARA
	local rb = rootOf(b)
	if rb then
		rb.Anchored = true
	end
	CombatService.HoldStill(b, 6, "trailer_timestop")
	local ra = rootOf(a)
	send("timestop", { phase = "stop", at = if ra then ra.Position else W })
	send("freeze", { models = { b.Name }, on = true })
	send("menacing", { seconds = 5.2, count = 8 })
	cue("TIME STOP")
	orbit(b.Name, 11, 1.5, 200, 330, 5.4, { fov0 = 48, fov1 = 44, lookUp = 0, frame = { a.Name, b.Name } })
	if not ctx.at(1.3) then
		return false
	end
	title("card", "TIME STOPS.", 2.2)
	if not ctx.at(1.7) then
		return false
	end
	anim(a, "Trailer/TimeStop", true)
	local frozenAt = if rb then rb.Position else W
	local ha = humanoidOf(a)
	if ha and ra then
		local dir = (V(frozenAt.X, ra.Position.Y, frozenAt.Z) - ra.Position).Unit
		ha:MoveTo(V(frozenAt.X, ra.Position.Y, frozenAt.Z) - dir * 3.5)
	end
	if not ctx.at(3.3) then
		return false
	end
	face(a, b)
	send("stand", { model = a.Name, seconds = 2.3, punch = true, rate = 0.07 })
	for i = 0, 15 do
		if not ctx.at(3.4 + i * 0.13) then
			return false
		end
		local jitter = V((math.random() - 0.5) * 1.6, (math.random() - 0.5) * 1.6, (math.random() - 0.5) * 1.6)
		vfx(a, "Shared/Hit", frozenAt + jitter)
		if i % 2 == 0 then
			sfx("Shared/Punch_Hit")
		end
	end
	if not ctx.at(6.0) then
		return false
	end
	-- O TEMPO VOLTA
	send("timestop", { phase = "resume", at = if ra then ra.Position else W })
	send("freeze", { models = { b.Name }, on = false })
	cue("TIME RESUMES")
	if rb then
		rb.Anchored = false
	end
	CombatService.ClearStun(b)
	CombatService.Knockback(a, b, 120, 0.45, 2.5, 30, EAST)
	vfx(b, "Shared/BlackFlash")
	sfx("Shared/BlackFlash")
	sfx("Shared/Finisher_Hit")
	impact(0.2)
	punch(-16, 1.4, 0.6)
	path({ W + V(-2, 3, -8), W + V(12, 6, -15) }, if ctx.v then 4 else 5, { look = b.Name, fov0 = 52, fov1 = 58, frame = { a.Name, b.Name } })
	return true
end }

-- 10. Despertar (cutscene real) + ult
S.ult = { dur = 10.5, cast = { "f2", "f4" }, fn = function(ctx)
	local X = colosseum() + V(-18, 0, 4)
	local a, b = c("f2"), c("f4")
	if not a or not b then
		return false
	end
	setVisible(c("f1"), false)
	clock(16.5)
	grade("desert")
	refresh(a)
	refresh(b)
	put(a, X, X + EAST * 9)
	put(b, X + EAST * 9, X)
	setVisible(a, true)
	setVisible(b, true)
	local cut = CombatConfig.Awakening.Cutscene
	orbit(a.Name, 11, 3.5, 20, 110, cut.BurstAt + 0.3, { fov0 = 52, fov1 = 46, lookUp = 2.5, frame = { a.Name } })
	BotService.Fill(a)
	if not ctx.at(0.3) then
		return false
	end
	AbilityService.Awaken(a)
	cue("AWAKEN")
	if not ctx.at(0.6) then
		return false
	end
	title("move", "AWAKENING", 2.2, nil, Color3.fromRGB(255, 205, 80))
	if not ctx.at(0.3 + cut.BurstAt) then
		return false
	end
	path({ X + V(6, 1.2, -5), X + V(9, 2.5, -10) }, 2.1, { look = X + V(0, 2.5, 0), fov0 = 62, fov1 = 56, frame = { a.Name } })
	impact(0.12)
	punch(-12, 1.2, 0.6)
	if not ctx.at(7.4) then
		return false
	end
	face(a, b)
	AbilityService.Use(a, 4, EAST)
	path({ X + V(-6, 14, -16), X + V(-2, 10, -20) }, 3.1, { look = X + V(6, 0, 0), fov0 = 55, fov1 = 52, frame = { a.Name, b.Name } })
	if not ctx.at(7.6) then
		return false
	end
	title("move", "ROAD ROLLER", 2.2, nil, Color3.fromRGB(255, 205, 80))
	return true
end }

-- 11. Boss do mundo à noite contra três caçadores
S.boss = { dur = 9, cast = { "f1", "f3", "f4" }, fn = function(ctx)
	local B = mark("Boss")
	local admin = Players:GetPlayers()[1]
	setVisible(c("f2"), false)
	clock(21.6)
	grade("night")
	if BossService.GetState() ~= "Fighting" and admin then
		local ok, why = BossService.Summon(admin)
		summonedBoss = ok
		if not ok then
			warn("[TrailerService] boss não invocou: " .. tostring(why))
		end
	end
	local bossModel = Workspace:FindFirstChild(BossConfig.Name)
	if bossModel then
		bossModel:SetAttribute("TrailerCast", true)
	end
	local hunters = { "f1", "f3", "f4" }
	for i, k in hunters do
		local m = c(k)
		if m then
			refresh(m)
			local ang = math.rad(235 + i * 25)
			put(m, B + V(math.cos(ang) * 18, 0, math.sin(ang) * 18), B)
			setVisible(m, true)
			if bossModel then
				BotService.SetBehavior(m, "aggressive")
				BotService.Provoke(m, bossModel)
			end
		end
	end
	local bossRef: any = if bossModel then bossModel.Name else B + V(0, 6, 0)
	path({ B + V(4, 1.2, -26), B + V(2, 1.8, -20) }, 3.6, { look = bossRef, fov0 = 50, fov1 = 44, hand = 0.4, frame = if bossModel then { bossModel.Name } else nil })
	if not ctx.at(0.5) then
		return false
	end
	title("card", "HUNT THE ECHOES.", 2.6, "WORLD BOSSES  ·  LOOT BY DAMAGE RANK")
	if not ctx.at(3.6) then
		return false
	end
	local group: { any } = { "TR_f1", "TR_f3", "TR_f4" }
	if bossModel then
		table.insert(group, bossModel.Name)
	end
	orbit(group, 26, 8, 160, 230, 5.4, { fov0 = 58, lookUp = 4, frame = group })
	if not ctx.at(8.8) then
		return false
	end
	for _, k in hunters do
		refresh(c(k))
		setVisible(c(k), false)
	end
	if summonedBoss and BossService.GetState() == "Fighting" then
		BossService.Despawn()
	end
	summonedBoss = false
	return true
end }

-- 12. O portal: alguém de outro mundo atravessa, acena para a câmera e volta; o portal fecha
S.portal = { dur = 9.5, durV = 8.5, cast = { "visitor" }, fn = function(ctx)
	local G = mark("Portal")
	local front = V(0, 0, -1) -- a frente do portal aponta para a câmera (sul)
	local visitor = c("visitor")
	if not visitor then
		return false
	end
	clock(18.3)
	grade("dusk")
	local center = G + V(0, 4.6, 0)
	put(visitor, G - front * 4, G + front * 10)
	setVisible(visitor, false)
	path({ G + front * 20 + V(-3, 3.5, 0), G + front * 16.5 + V(-1, 3.2, 0) }, if ctx.v then 8.5 else 9.5, { look = center - V(0, 1, 0), fov0 = 45, fov1 = 40, hand = 0.15, frame = { visitor.Name :: any, center + V(5.5, 5.5, 0), center - V(5.5, 5.5, 0) } })
	if not ctx.at(0.6) then
		return false
	end
	send("portal", { id = "visitor", phase = "open", cf = CFrame.lookAt(center, center + front), size = 11 })
	cue("PORTAL OPEN")
	if not ctx.at(1.8) then
		return false
	end
	setVisible(visitor, true) -- atrás do disco: o portal tampa até ele atravessar
	sfx("Swift/Blink")
	local h = humanoidOf(visitor)
	if not ctx.at(2.0) then
		return false
	end
	if h then
		h:MoveTo(G + front * 4)
	end
	if not ctx.at(3.0) then
		return false
	end
	put(visitor, G + front * 4, G + front * 20)
	anim(visitor, "Emotes/wave")
	cue("WAVE")
	if not ctx.at(5.3) then
		return false
	end
	put(visitor, G + front * 4, G - front * 10)
	if h then
		h:MoveTo(G - front * 4)
	end
	if not ctx.at(6.3) then
		return false
	end
	setVisible(visitor, false)
	if not ctx.at(6.6) then
		return false
	end
	send("portal", { id = "visitor", phase = "close" })
	cue("PORTAL CLOSE")
	if not ctx.at(7.2) then
		return false
	end
	title("card", "OTHER WORLDS ARE WATCHING.", if ctx.v then 1.1 else 2.0)
	return true
end }

-- 13. JoJo poses: os quatro lado a lado, Stands atrás, "ゴゴゴ", câmera baixa com ângulo holandês
S.poses = { dur = 6.5, durV = 5.5, cast = { "f1", "f2", "f3", "f4" }, fn = function(ctx)
	local C = colosseum() + V(0, 0, 4)
	local look = C + V(0, 0, -20)
	clock(17.6)
	grade("eclipse")
	local spots = if ctx.v
		then { f1 = V(-2.6, 0, 0), f2 = V(-0.9, 0, 2), f3 = V(0.9, 0, 2), f4 = V(2.6, 0, 0) }
		else { f1 = V(-6, 0, 0), f2 = V(-2, 0, 1.5), f3 = V(2, 0, 1.5), f4 = V(6, 0, 0) }
	local poses = { f1 = "Trailer/Pose_Point", f2 = "Trailer/Pose_Lean", f3 = "Trailer/Pose_Hand", f4 = "Trailer/Pose_Twist" }
	for _, k in { "f1", "f2", "f3", "f4" } do
		local m = c(k)
		refresh(m)
		put(m, C + spots[k], look + spots[k])
		setVisible(m, true)
	end
	path({ C + V(-3, 0.8, -18), C + V(-1, 1.4, -12) }, if ctx.v then 5.5 else 6.5, { look = C + V(0, 3.2, 0), fov0 = 44, fov1 = 38, roll0 = -8, roll1 = -4, frame = { "TR_f1", "TR_f2", "TR_f3", "TR_f4" } })
	for i, k in { "f2", "f1", "f3", "f4" } do
		if not ctx.at(0.2 + (i - 1) * 0.15) then
			return false
		end
		anim(c(k), poses[k])
	end
	sfx("Shared/Awakening_Pulse")
	if not ctx.at(0.5) then
		return false
	end
	send("stand", { model = "TR_f1", seconds = 6 })
	send("stand", { model = "TR_f2", seconds = 6 })
	send("menacing", { seconds = if ctx.v then 4.8 else 5.8, count = 9 })
	return true
end }

-- 14. To Be Continued: congela as poses em sépia
S.tbc = { dur = 3, durV = 2.5, cast = {}, fn = function(ctx)
	send("hold", {})
	send("freeze", { models = { "TR_f1", "TR_f2", "TR_f3", "TR_f4" }, on = true })
	send("tbc", { seconds = if ctx.v then 2.5 else 3 })
	cue("TO BE CONTINUED")
	return true
end }

-- 15. Logo no preto
S.logo = { dur = 5, durV = 4, cast = {}, fn = function(ctx)
	fade(1, 0.3)
	if not ctx.at(0.3) then
		return false
	end
	send("logo", { seconds = if ctx.v then 3.2 else 4.2 })
	sfx("Shared/Awakening_Impact")
	cue("LOGO")
	return true
end }

local ORDER_H = { "open", "beach", "world", "arrow", "combo", "parry", "dash", "rush", "timestop", "ult", "boss", "portal", "poses", "tbc", "logo" }
local ORDER_V = { "open", "arrow", "combo", "parry", "rush", "timestop", "portal", "poses", "tbc", "logo" }

TrailerService.Scenes = { "all", "open", "beach", "world", "arrow", "combo", "parry", "dash", "rush", "timestop", "ult", "boss", "portal", "poses", "tbc", "logo" }

--- Duração total de uma lista (para o log e o painel).
local function total(list: { string }, v: boolean): number
	local t = 0
	for _, name in list do
		local sc = S[name]
		t += if v and sc.durV then sc.durV else sc.dur
	end
	return t
end

local function runList(list: { string }, v: boolean, myToken: number): boolean
	local t = 0
	for _, name in list do
		local sc = S[name]
		local dur = if v and sc.durV then sc.durV else sc.dur
		local base = t
		Log.info(("[Trailer] %s  ===== %s (%.1f s)"):format(stamp(base), name:upper(), dur))
		local ctx: Ctx = {
			v = v,
			at = function(rel: number): boolean
				return waitUntil(base + rel, myToken)
			end,
		}
		local ok, result = pcall(sc.fn, ctx)
		if not ok then
			warn(("[TrailerService] cena %s: %s"):format(name, tostring(result)))
		elseif result == false and not (running and token == myToken) then
			return false
		end
		t += dur
		if not waitUntil(t, myToken) then
			return false
		end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

--- `arg` = "<cena|all> [v|h]" (ex.: "all v", "timestop", "portal v").
function TrailerService.Run(arg: string?): (boolean, string)
	if running then
		return false, "trailer já está rodando (TrailerStop para parar)"
	end
	local words = {}
	for w in (arg or "all"):gmatch("%S+") do
		table.insert(words, w:lower())
	end
	local sceneName = words[1] or "all"
	local v = false
	for i = 2, #words do
		if words[i] == "v" or words[i] == "vertical" then
			v = true
		end
	end
	local list: { string }
	if sceneName == "all" then
		list = if v then ORDER_V else ORDER_H
	elseif S[sceneName] then
		list = { sceneName }
	else
		return false, ("cena desconhecida '%s' (%s)"):format(sceneName, table.concat(TrailerService.Scenes, ", "))
	end
	local castKeys: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, name in list do
		for _, k in S[name].cast do
			if not seen[k] then
				seen[k] = true
				table.insert(castKeys, k)
			end
		end
	end
	-- poses/tbc sozinhas precisam dos quatro
	if sceneName == "tbc" then
		for _, k in { "f1", "f2", "f3", "f4" } do
			if not seen[k] then
				table.insert(castKeys, k)
			end
		end
	end
	running = true
	token += 1
	format = if v then "v" else "h"
	local myToken = token
	local length = total(list, v)
	task.spawn(function()
		local ok: boolean, err: any = pcall(function(): ()
			send("begin", { format = format })
			prepare(castKeys)
			if not (running and token == myToken) then
				return
			end
			-- contagem para o dono começar a gravar (tela preta; número pequeno no canto)
			for n = 3, 1, -1 do
				send("countdown", { n = n })
				task.wait(1)
				if not (running and token == myToken) then
					return
				end
			end
			send("countdown", { n = 0 })
			T0 = os.clock()
			Log.info(("[Trailer] ===== INÍCIO (%s, %s, %.1f s) — folha de tempos abaixo ====="):format(sceneName, if v then "9:16" else "16:9", length))
			if runList(list, v, myToken) then
				fade(1, 0.6)
				Log.info(("[Trailer] %s  ===== FIM"):format(stamp(os.clock() - T0)))
				task.wait(1.2)
			end
		end)
		if not ok then
			warn("[TrailerService] erro: " .. tostring(err))
		end
		if running and token == myToken then
			cleanup()
		end
	end)
	return true, ("trailer %s (%s, ~%d s) preparando o elenco; contagem 3-2-1 na tela. TrailerStop interrompe."):format(
		sceneName, if v then "9:16" else "16:9", math.floor(length + 0.5))
end

function TrailerService.Init()
	notifyTrailer = Remotes.GetEvent(Remotes.Events.NotifyTrailer)
end

return TrailerService
