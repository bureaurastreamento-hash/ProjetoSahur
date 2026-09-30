--!strict
--[[
	TrailerService (servidor) — v2 (dono, 2026-09-23): TRAILER COM COMBATE REAL.
	Os atores são BOTS do BotService (Combatant.Fighter): tudo que aparece — combo, finisher, parry/crítico/
	Black Flash, dash com hit de chegada, habilidades, despertar (cutscene) e ult, boss — passa pelos mesmos
	services do jogo (Combat/Movement/Ability/Health/Ragdoll). Nada é "encenado" com eventos falsos; a
	coreografia só decide QUEM faz O QUÊ e QUANDO (CombatService.Attack/Block, MovementService.Dash,
	AbilityService.Use/Awaken) e a câmera (TrailerController: shots/cartelas por NotifyTrailer).
	Cada CENA roda sozinha (DEV: "TrailerScene <nome>") — serve para demonstrar/testar um golpe:
	  brawl        4 bots agressivos (2 times) brigando na praça (plano aberto)
	  combo        combo de 4 socos + finisher (ragdoll)
	  parry        parry → crítico → segundo parry → BLACK FLASH
	  dash         dash de longe com hit de chegada
	  abilities    cada personagem usa as habilidades 1..3 num alvo (arg: id do personagem; sem = todos)
	  ult          carga cheia → DESPERTAR (cutscene) → ult (arg: id; sem = Jotaro)
	  boss         boss real no santuário contra 3 bots
	  all          o trailer inteiro (~95 s)
	"me" no argumento (ex.: "combo me") = o jogador NÃO é estacionado e pode entrar na cena.
	Grave com OBS/Studio (View > Video Record). TrailerStop interrompe e desfaz tudo.
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
local BotService = require(script.Parent:WaitForChild("BotService"))
local BossService = require(script.Parent:WaitForChild("BossService"))

local TrailerService = {}

TrailerService.Scenes = { "brawl", "combo", "parry", "dash", "abilities", "ult", "boss", "all" }

local notifyTrailer: RemoteEvent
local running = false
local token = 0
local parkedPlayers: { [Player]: CFrame } = {}
local bots: { Model } = {}

-- PALCO = praça central (chão achado por raycast); santuário do boss = BossSpawn/BossArena (ArenaExtras)
local STAGE = Vector3.new(0, 0.6, 0)

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

local function groundAt(x: number, z: number, fallbackY: number): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position else Vector3.new(x, fallbackY, z)
end

local function stage(): Vector3
	return groundAt(STAGE.X, STAGE.Z, STAGE.Y)
end

local function bossArena(): Vector3
	local sahur = Workspace:FindFirstChild("Sahur")
	local extras = sahur and sahur:FindFirstChild("ArenaExtras")
	local part = extras and extras:FindFirstChild("BossArena", true)
	return if part and part:IsA("BasePart") then part.Position else Vector3.new(900, 1.5, -581)
end

--- Bot da cena: nasce virado para `lookAt`. Registrado para a limpeza.
local function actor(name: string, characterId: string, at: Vector3, lookAt: Vector3, behavior: string, team: string?): Model?
	local cf = CFrame.lookAt(at, Vector3.new(lookAt.X, at.Y, lookAt.Z))
	local model = BotService.Spawn({ Name = name, CharacterId = characterId, CFrame = cf, Behavior = behavior, Respawn = false, Team = team })
	if model then
		table.insert(bots, model)
	end
	return model
end

local function rootOf(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function face(a: Model?, b: Model?)
	local ra, rb = rootOf(a), rootOf(b)
	if ra and rb then
		ra.CFrame = CFrame.lookAt(ra.Position, Vector3.new(rb.Position.X, ra.Position.Y, rb.Position.Z))
	end
end

local function put(model: Model?, at: Vector3, lookAt: Vector3)
	local r = rootOf(model)
	if r then
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.lookAt(at + Vector3.new(0, 3.05, 0), Vector3.new(lookAt.X, at.Y + 3.05, lookAt.Z))
	end
end

local function clearBots()
	for _, m in bots do
		if m.Parent then
			m:Destroy()
		end
	end
	table.clear(bots)
end

local function abilityName(characterId: string, slot: number, awakened: boolean?): string
	local ability = CharacterDefs.GetAbility(characterId, slot, awakened)
	return if ability then ability.DisplayName else "?"
end

local function displayName(characterId: string): string
	local def = CharacterDefs.Get(characterId)
	return if def then def.DisplayName else characterId
end

-- ---------------------------------------------------------------------------
-- Preparação / limpeza
-- ---------------------------------------------------------------------------

local function prepare(keepPlayers: boolean)
	DummyService.SetEnabled(false)
	if not keepPlayers then
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				parkedPlayers[player] = root.CFrame
				AntiExploitService.Grace(player, 600)
				root.CFrame = CFrame.new(0, 300, -600)
				root.Anchored = true
			end
		end
	end
	EnvironmentService.SetClockOverride(16.8)
	send("begin", {})
end

local function cleanup()
	clearBots()
	BotService.Clear()
	if BossService.GetState() == "Fighting" then
		BossService.Despawn()
	end
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
-- CENAS (cada uma limpa os próprios bots ao terminar)
-- ---------------------------------------------------------------------------

local scenes: { [string]: (myToken: number, arg: string?) -> boolean } = {}

--- Abertura: voo sobre o mapa até a praça onde 6 bots brigam de verdade (3 × 3 em times, sem ninguém parado).
scenes.brawl = function(myToken)
	local S = stage()
	local ids = { "Jotaro", "Swift", "Dio", "Kira" } -- dono (2026-09-23): 6 era caos; 4 em 2 times
	for i, id in ids do
		local ang = (i - 1) / #ids * math.pi * 2
		local at = S + Vector3.new(math.cos(ang) * 9, 0, math.sin(ang) * 9)
		actor(("Briga %d"):format(i), id, at, S, "aggressive", if i % 2 == 0 then "A" else "B")
	end
	local names = { "Briga 1", "Briga 2", "Briga 3", "Briga 4" }
	shot({ from = CFrame.lookAt(S + Vector3.new(-260, 140, -420), S + Vector3.new(0, 10, 0)), to = CFrame.lookAt(S + Vector3.new(-26, 14, -40), S + Vector3.new(0, 4, 0)), t = 6, fov = 62, ease = "Sine" })
	title("SAHUR", 4.5, "battlegrounds")
	if not wait_(6, myToken) then
		return false
	end
	-- órbita do GRUPO: o raio cresce para caber quem se espalhar
	shot({ orbit = names, radius = 16, height = 6, from = 220, to = 300, t = 6, fov = 60 })
	if not wait_(6, myToken) then
		return false
	end
	clearBots()
	return true
end

--- Combo de 4 socos com finisher: A agressivo em B parado; B revida depois do primeiro combo.
scenes.combo = function(myToken)
	local S = stage()
	actor("A", "Jotaro", S + Vector3.new(-4, 0, 0), S + Vector3.new(4, 0, 0), "aggressive", "A")
	local b = actor("B", "Swift", S + Vector3.new(4, 0, 0), S + Vector3.new(-4, 0, 0), "idle", "B")
	shot({ orbit = { "A", "B" }, radius = 12, height = 3.5, from = 200, to = 290, t = 7, fov = 58 })
	title("COMBO", 2.5, "4 socos · o último derruba")
	if not wait_(3.2, myToken) then
		return false
	end
	if b then
		BotService.SetBehavior(b, "passive") -- B levanta e revida
	end
	if not wait_(3.8, myToken) then
		return false
	end
	clearBots()
	return true
end

--- Parry → crítico → segundo parry → BLACK FLASH. Coreografado com as funções REAIS (block antes do golpe).
scenes.parry = function(myToken)
	local S = stage()
	local a = actor("A", "Dio", S + Vector3.new(-3, 0, 0), S + Vector3.new(3, 0, 0), "idle", "A")
	local b = actor("B", "Jotaro", S + Vector3.new(3, 0, 0), S + Vector3.new(-3, 0, 0), "idle", "B")
	if not a or not b then
		return false
	end
	shot({ from = CFrame.lookAt(S + Vector3.new(0, 3.2, -12), S + Vector3.new(0, 2.5, 0)), to = CFrame.lookAt(S + Vector3.new(3, 4, -13), S + Vector3.new(0, 2.5, 0)), t = 9, fov = 44, ease = "Sine" })
	title("PARRY = CRÍTICO", 3, "dois seguidos = BLACK FLASH")
	if not wait_(0.8, myToken) then
		return false
	end
	local function exchange(): boolean
		-- B levanta a guarda um instante antes do golpe de A → parry; A fica atordoado; B devolve crítico
		face(a, b)
		face(b, a)
		CombatService.Block(b, true)
		if not wait_(0.12, myToken) then
			return false
		end
		CombatService.Attack(a, "M1")
		if not wait_(0.35, myToken) then
			return false
		end
		CombatService.Block(b, false)
		if not wait_(0.25, myToken) then
			return false
		end
		CombatService.Attack(b, "M1") -- crítico (×3) — ou Black Flash (×6) se for o 2º seguido
		return wait_(1.6, myToken)
	end
	if not exchange() then
		return false
	end
	put(a, S + Vector3.new(-3, 0, 0), S + Vector3.new(3, 0, 0))
	put(b, S + Vector3.new(3, 0, 0), S + Vector3.new(-3, 0, 0))
	if not wait_(0.6, myToken) then
		return false
	end
	shot({ from = CFrame.lookAt(S + Vector3.new(5, 2.4, -9), S + Vector3.new(0, 2.5, 0)), to = CFrame.lookAt(S + Vector3.new(7, 3, -11), S + Vector3.new(0, 2.5, 0)), t = 3.5, fov = 40, ease = "Sine" })
	if not exchange() then
		return false
	end
	if not wait_(1.0, myToken) then
		return false
	end
	clearBots()
	return true
end

--- Dash de longe com hit de chegada: A vem de ~27 studs (alcance do dash frontal = Speed × Duration ×
--- ForwardScale ≈ 25) e para com B dentro do alcance do hit de chegada; B voa.
scenes.dash = function(myToken)
	local S = stage()
	local reach = CombatConfig.Dash.Speed * CombatConfig.Dash.Duration * CharacterDefs.DashTuning.ForwardScale
	local a = actor("A", "Kira", S + Vector3.new(-(reach + 2), 0, 0), S, "idle", "A")
	local b = actor("B", "Dio", S + Vector3.new(0, 0, 0), S + Vector3.new(-reach, 0, 0), "idle", "B")
	if not a or not b then
		return false
	end
	shot({ from = CFrame.lookAt(S + Vector3.new(-12, 6, 14), S + Vector3.new(-4, 3, 0)), to = CFrame.lookAt(S + Vector3.new(-2, 5, 16), S + Vector3.new(2, 3, 0)), t = 5, fov = 60, ease = "Sine" })
	title("DASH = HIT", 2.5, "de frente, joga longe")
	if not wait_(0.8, myToken) then
		return false
	end
	local dir = Vector3.new(1, 0, 0)
	MovementService.Dash(a, dir, dir)
	if not wait_(0.5, myToken) then
		return false
	end
	-- vem de novo (cooldown do dash frontal é 4 s: segundo trecho é corrida + soco)
	BotService.SetBehavior(a, "aggressive")
	if not wait_(3.7, myToken) then
		return false
	end
	clearBots()
	return true
end

--- Habilidades: o personagem `arg` (ou todos) usa 1..3 num alvo parado. Cartela com o nome de cada uma.
scenes.abilities = function(myToken, arg)
	local S = stage()
	local list: { string } = {}
	if arg and CharacterDefs.Get(arg) then
		list = { arg }
	else
		for _, id in { "Jotaro", "Swift", "Dio", "Kira", "Rick" } do
			if CharacterDefs.Get(id) then
				table.insert(list, id)
			end
		end
	end
	for _, id in list do
		local a = actor("A", id, S + Vector3.new(-9, 0, 0), S + Vector3.new(5, 0, 0), "idle", "A")
		local b = actor("B", "Jotaro", S + Vector3.new(5, 0, 0), S + Vector3.new(-9, 0, 0), "idle", "B")
		if not a or not b then
			return false
		end
		shot({ orbit = { "A", "B" }, radius = 14, height = 5, from = 210, to = 300, t = 9, fov = 56 })
		-- 1–4 + R (kit normal)
		for slot = 1, CharacterDefs.PASSIVE_SLOT do
			local ability = CharacterDefs.GetAbility(id, slot, false)
			if not ability then
				continue
			end
			if not a.Parent or not HealthService.IsAlive(a) then
				break
			end
			title(displayName(id), 2.4, (if slot == CharacterDefs.PASSIVE_SLOT then "R · " else "") .. abilityName(id, slot, false))
			if b.Parent and HealthService.IsAlive(b) then
				put(b, S + Vector3.new(5, 0, 0), S + Vector3.new(-9, 0, 0))
			end
			put(a, S + Vector3.new(-9, 0, 0), S + Vector3.new(5, 0, 0))
			if not wait_(0.3, myToken) then
				return false
			end
			AbilityService.Use(a, slot, Vector3.new(1, 0, 0))
			if not wait_(2.8, myToken) then
				return false
			end
		end
		clearBots()
		if not wait_(0.3, myToken) then
			return false
		end
	end
	return true
end

--- Despertar (cutscene real) + ult: A com a carga cheia desperta na frente de B; a câmera orbita e corta
--- para dentro no estouro; depois A usa a ult.
scenes.ult = function(myToken, arg)
	local S = stage()
	local id = if arg and CharacterDefs.Get(arg) then arg else "Jotaro"
	local a = actor("A", id, S + Vector3.new(-2, 0, 0), S + Vector3.new(6, 0, 0), "idle", "A")
	local b = actor("B", "Swift", S + Vector3.new(6, 0, 0), S + Vector3.new(-2, 0, 0), "idle", "B")
	if not a or not b then
		return false
	end
	local cut = CombatConfig.Awakening.Cutscene
	shot({ orbit = "A", radius = 12, height = 4, from = 30, to = 120, t = cut.BurstAt, fov = 55 })
	title("DESPERTAR", 3, displayName(id))
	BotService.Fill(a)
	if not wait_(0.3, myToken) then
		return false
	end
	AbilityService.Awaken(a)
	if not wait_(cut.BurstAt - 0.35, myToken) then
		return false
	end
	shot({ from = CFrame.lookAt(S + Vector3.new(0, 2.5, -9), S + Vector3.new(-1, 1.5, 0)), to = CFrame.lookAt(S + Vector3.new(2, 4, -14), S + Vector3.new(-1, 1.5, 0)), t = cut.Duration - cut.BurstAt + 1.0, fov = 66, ease = "Quart" })
	if not wait_(cut.Duration - cut.BurstAt + 0.6, myToken) then
		return false
	end
	-- FORMA DESPERTA: B de volta na frente; A mostra os 4 golpes despertos (kit trocado pela ult)
	shot({ orbit = { "A", "B" }, radius = 13, height = 4.5, from = 220, to = 340, t = 14, fov = 56 })
	for slot = 1, 4 do
		local ability = CharacterDefs.GetAbility(id, slot, true)
		if not ability or not a.Parent or not HealthService.IsAlive(a) then
			break
		end
		title("DESPERTO", 2.4, ability.DisplayName)
		if b.Parent and HealthService.IsAlive(b) then
			put(b, S + Vector3.new(6, 0, 0), S + Vector3.new(-2, 0, 0))
		end
		put(a, S + Vector3.new(-2, 0, 0), S + Vector3.new(6, 0, 0))
		if not wait_(0.4, myToken) then
			return false
		end
		AbilityService.Use(a, slot, Vector3.new(1, 0, 0))
		if not wait_(2.8, myToken) then
			return false
		end
	end
	clearBots()
	return true
end

--- Boss REAL no santuário (BossService.Summon) contra 3 bots agressivos; anoitece; câmera orbita o boss.
scenes.boss = function(myToken)
	local admin = Players:GetPlayers()[1]
	if not admin then
		return false
	end
	EnvironmentService.SetClockOverride(21.5)
	local center = bossArena()
	shot({ from = CFrame.lookAt(center + Vector3.new(-40, 30, -90), center + Vector3.new(0, 6, 0)), to = CFrame.lookAt(center + Vector3.new(-26, 10, -34), center + Vector3.new(0, 5, 0)), t = 5, fov = 60, ease = "Sine" })
	title("À NOITE, O BOSS", 3.5, "Big C.H.O.P. no santuário")
	if BossService.GetState() ~= "Fighting" then
		local ok, why = BossService.Summon(admin)
		if not ok then
			Log.debug("[TrailerService] boss não invocou: " .. tostring(why))
		end
	end
	for i = 1, 3 do
		local ang = math.rad(200 + i * 30)
		actor(("Caçador %d"):format(i), ({ "Jotaro", "Dio", "Kira" })[i], center + Vector3.new(math.cos(ang) * 16, 0, math.sin(ang) * 16), center, "aggressive", "A")
	end
	if not wait_(5, myToken) then
		return false
	end
	local bossModel = Workspace:FindFirstChild(BossConfig.Name)
	shot({ orbit = { if bossModel then bossModel.Name else "Caçador 1", "Caçador 1", "Caçador 2", "Caçador 3" }, radius = 26, height = 7, from = 160, to = 280, t = 11, fov = 60 })
	title("BIG C.H.O.P.", 3.5, "loot por ranking de dano")
	if not wait_(11, myToken) then
		return false
	end
	clearBots()
	if BossService.GetState() == "Fighting" then
		BossService.Despawn()
	end
	EnvironmentService.SetClockOverride(16.8)
	return true
end

--- O trailer inteiro.
scenes.all = function(myToken)
	local order: { { string } } = {
		{ "brawl" }, { "combo" }, { "parry" }, { "dash" }, { "abilities", "Swift" }, { "abilities", "Kira" }, { "ult", "Jotaro" }, { "boss" },
	}
	for _, entry in order do
		local fn = scenes[entry[1]]
		local extra: string? = entry[2]
		if not fn(myToken, extra) then
			return false
		end
		if not wait_(0.4, myToken) then
			return false
		end
	end
	local S = stage()
	shot({ from = CFrame.lookAt(S + Vector3.new(90, 30, 90), S + Vector3.new(0, 4, 0)), to = CFrame.lookAt(S + Vector3.new(120, 60, 120), S + Vector3.new(0, 4, 0)), t = 6, fov = 58, ease = "Sine" })
	title("SAHUR", 5, "em breve")
	send("fade", { seconds = 5 })
	return wait_(6, myToken)
end

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

--- Roda uma cena ("all" = trailer inteiro). `arg` = "<cena> [id] [me]".
function TrailerService.Run(arg: string?): (boolean, string)
	if running then
		return false, "trailer já está rodando (TrailerStop para parar)"
	end
	local words = {}
	for w in (arg or "all"):gmatch("%S+") do
		table.insert(words, w)
	end
	local sceneName = (words[1] or "all"):lower()
	local keepPlayers = false
	local extra: string? = nil
	for i = 2, #words do
		if words[i]:lower() == "me" then
			keepPlayers = true
		else
			extra = words[i]
		end
	end
	local fn = scenes[sceneName]
	if not fn then
		return false, ("cena desconhecida '%s' (%s)"):format(sceneName, table.concat(TrailerService.Scenes, ", "))
	end
	running = true
	token += 1
	local myToken = token
	task.spawn(function()
		local ok, err = pcall(function()
			prepare(keepPlayers)
			if wait_(0.5, myToken) then
				fn(myToken, extra)
			end
		end)
		if not ok then
			warn("[TrailerService] erro: " .. tostring(err))
		end
		if running and token == myToken then
			cleanup()
		end
	end)
	return true, ("cena '%s' rodando%s. Grave a tela; TrailerStop interrompe."):format(sceneName, if extra then " (" .. extra .. ")" else "")
end

function TrailerService.Init()
	notifyTrailer = Remotes.GetEvent(Remotes.Events.NotifyTrailer)
end

return TrailerService
