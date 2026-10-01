--!strict
--[[
	TraitorService (servidor)
	Capítulo FINAL da história (dono, 2026-09-23): o desenvolvedor TRAIDOR (QuestConfig.Traitor.UserId =
	adryan_keep) vira um NPC hostil que nasce no santuário do boss. Quem aceita o capítulo `final` (ou volta a
	falar com ele sem ter vencido) invoca o traidor — um só por servidor; todo mundo pode bater, e o crédito
	(contador `traitor_kill`) vai para quem deu dano E está no capítulo final ativo (QuestService.IsActiveOn).
	v2 (A6, dono: "tem que ser mais OP que o Big C.H.O.P."): o traidor é um BOT ESPECIAL do BotService —
	avatar real do membro, kit COMPLETO do personagem `CharacterId` (combo de M1, dash, block/parry,
	habilidades 1–3, despertar + ULT) com a IA agressiva do bot, vida ×HealthMult, dano ×DamageMult
	(atributo `DamageMult` no Model, CombatService.ResolveHit), velocidade acima do sprint, ult cheia na
	entrada e recarregada a cada UltEvery s, aura/luz vermelha, sem respawn. À solta: persegue pelo mapa
	(Tuning.SeekRadius = ChaseRadius). Fase 2 (metade da vida): mais rápido e mais forte. Sem ninguém vivo
	por perto por AbandonSeconds = some sem crédito. Servidor autoritativo; nada vem do cliente.
]]

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
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local Combatant = require(Modules:WaitForChild("Combatant"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local BotService = require(script.Parent:WaitForChild("BotService"))

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
	nextFillAt: number,
}

local fight: Fight? = nil
local spawnPart: BasePart? = nil
local notifyQuest: RemoteEvent

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
end

local function toast(player: Player, title: string, text: string)
	notifyQuest:FireClient(player, "toast", { title = title, text = text })
end

local function toastAll(title: string, text: string)
	for _, p in Players:GetPlayers() do
		toast(p, title, text)
	end
end

--- Algum jogador vivo a até `radius` do traidor?
local function anyoneNear(f: Fight, radius: number): boolean
	for _, fighter in Players:GetPlayers() do
		local character = Combatant.CharacterOf(fighter)
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character ~= f.model and root and HealthService.IsAlive(character) and (root.Position - f.root.Position).Magnitude <= radius then
			return true
		end
	end
	return false
end

--- Aura de traidor: contorno vermelho + luz (o cliente não precisa saber de nada).
local function decorate(model: Model, root: BasePart, humanoid: Humanoid)
	humanoid.DisplayName = ("%s — %s"):format(traitorName(), CFG.Title)
	humanoid.NameDisplayDistance = 120
	humanoid.HealthDisplayDistance = 120
	humanoid.JumpPower = 0
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
		toastAll("O traidor caiu", ("%s foi derrotado."):format(traitorName()))
		-- corpo: o HealthService já ragdolla ao morrer; fade antes do BotService destruir (RespawnTime)
		task.delay(1.2, function()
			for _, d in f.model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					TweenService:Create(d, TweenInfo.new(1.4), { Transparency = 1 }):Play()
				end
			end
		end)
	else
		toastAll("O traidor sumiu", "Ninguém ficou por perto. Fale com ele de novo para chamá-lo.")
		BotService.Remove(f.model)
	end
end

-- ---------------------------------------------------------------------------
-- Supervisão (a IA de combate é a do BotService)
-- ---------------------------------------------------------------------------

local function watchLoop(f: Fight)
	f.lastSeenPlayer = os.clock()
	while not f.finished and f.model.Parent and f.humanoid.Health > 0 do
		task.wait(0.5)
		if f.finished then
			break
		end
		local now = os.clock()
		-- fase 2: metade da vida = mais rápido e mais forte
		if f.phase == 1 and f.humanoid.Health <= f.humanoid.MaxHealth * CFG.PhaseTwoAt then
			f.phase = 2
			f.model:SetAttribute("WalkSpeed", CFG.ChaseSpeed)
			f.model:SetAttribute("DamageMult", CFG.PhaseTwoDamageMult)
			CombatService.RestoreWalkSpeed(f.model)
			toastAll("O traidor está furioso", "Metade da vida: ele ficou mais rápido e bate mais forte.")
		end
		-- ult recarregada de tempos em tempos (o bot desperta e usa quando está perto)
		if now >= f.nextFillAt then
			f.nextFillAt = now + CFG.UltEvery
			BotService.Fill(f.model)
		end
		-- à solta: some após AbandonSeconds sem ninguém vivo por perto
		if anyoneNear(f, CFG.ChaseRadius) then
			f.lastSeenPlayer = now
		elseif now - f.lastSeenPlayer > CFG.AbandonSeconds then
			endFight(f, false)
			return
		end
	end
end

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

--- Invoca o traidor no santuário (um só por servidor). (ok, mensagem)
function TraitorService.Summon(by: Player?): (boolean, string)
	if fight then
		return true, "o traidor já está à solta"
	end
	if not spawnPart then
		findExtras()
	end
	local characterId = if CharacterDefs.Get(CFG.CharacterId) then CFG.CharacterId else CharacterDefs.DefaultCharacter
	local pos = if spawnPart then spawnPart.Position + Vector3.new(0, spawnPart.Size.Y / 2, 0) else QuestConfig.Spots.Santuario.Pos
	local maxHealth = math.floor(CombatConfig.MaxHealth * CFG.HealthMult + 0.5)
	local tuning: { [string]: number } = table.clone(CFG.Tuning)
	tuning.SeekRadius = CFG.ChaseRadius
	local model = BotService.Spawn({
		CharacterId = characterId,
		Name = "Traidor_" .. traitorName(),
		UserId = CFG.UserId,
		CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(180), 0),
		Behavior = "aggressive",
		Respawn = false,
		Attributes = {
			Traitor = true,
			MaxHealth = maxHealth,
			WalkSpeed = CFG.WalkSpeed,
			DamageMult = CFG.DamageMult,
		},
		Tuning = tuning,
	})
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not model or not humanoid or not root then
		return false, "não consegui criar o traidor"
	end
	decorate(model, root, humanoid)
	BotService.Fill(model) -- entra com a ult cheia
	local f: Fight = {
		model = model,
		humanoid = humanoid,
		root = root,
		damageBy = {},
		phase = 1,
		finished = false,
		lastSeenPlayer = os.clock(),
		nextFillAt = os.clock() + CFG.UltEvery,
	}
	fight = f
	humanoid.Died:Once(function()
		endFight(f, true)
	end)
	model.AncestryChanged:Connect(function()
		if not model.Parent and not f.finished then
			endFight(f, false) -- removido por fora (DEV "limpar bots")
		end
	end)
	task.spawn(watchLoop, f)
	toastAll("TRAIDOR", ("%s apareceu no santuário atrás da cachoeira%s."):format(traitorName(), if by then " — chamado por " .. by.Name else ""))
	Log.debug(("[TraitorService] traidor invocado por %s (%s, vida %d, dano ×%.1f)"):format(if by then by.Name else "servidor", characterId, humanoid.MaxHealth, CFG.DamageMult))
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
	HealthService.Kill(f.model)
	return true
end

function TraitorService.IsActive(): boolean
	return fight ~= nil
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function TraitorService.Init()
	if not QuestConfig.Enabled then return end
	notifyQuest = Remotes.GetEvent(Remotes.Events.NotifyQuest)
	-- aceitar o capítulo final (ou voltar a falar com o traidor sem ter vencido) = ele aparece no santuário
	QuestService.OnTalk(function(player: Player, ch: QuestConfig.Chapter, phase: string)
		if ch.Id == FINAL_ID and (phase == "accept" or phase == "progress") then
			TraitorService.Summon(player)
		end
	end)
end

function TraitorService.Start()
	if not QuestConfig.Enabled then return end
	findExtras()
	if not spawnPart then
		warn(("[TraitorService] Workspace.Sahur.ArenaExtras sem %s; o traidor nasce no spot Santuario"):format(CFG.SpawnPartName))
	end
	HealthService.Damaged.Event:Connect(function(victim: Model, amount: number, attacker: Combatant.Fighter?)
		local f = fight
		if f and victim == f.model and attacker and Combatant.IsPlayer(attacker) then
			local player = attacker :: Player
			f.damageBy[player] = (f.damageBy[player] or 0) + amount
		end
	end)
	Log.debug(("[TraitorService] traidor = %s (bot %s, vida ×%d, dano ×%.1f)"):format(traitorName(), tostring(CFG.CharacterId), CFG.HealthMult, CFG.DamageMult))
end

return TraitorService
