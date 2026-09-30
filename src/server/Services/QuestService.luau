--!strict
--[[
	QuestService (servidor)
	HISTÓRIA em capítulos (dono, 2026-09-22): QuestConfig.Chapters, um NPC por desenvolvedor do grupo
	(TeamConfig) em pé num Spot do mapa com o AVATAR real do membro (CreateHumanoidModelFromUserId) e um
	ProximityPrompt "Falar" (E). Fluxo por jogador (profile.quests):
	  - chapter = capítulo atual; active = já falou com o NPC dele (objetivos contam a partir daí);
	  - counters = progresso do capítulo atual; done[id] = capítulos entregues.
	Progresso vem do AchievementService.OnProgress (kills, parries, duel_wins, boss_kills, bricks...), do atributo
	KillStreak (streak, valor MÁXIMO) e da checagem de posição (visit_<Spot>, a cada 2 s).
	Recompensa ao entregar: pontos de evento, pontos, XP, cosmético/emote (AchievementService.GrantReward).
	Mural das quests: peça Workspace.QuestBoards.QuestBoard na Taberna (parede sul); o CONTEÚDO é por jogador,
	então o QuestController desenha a SurfaceGui no PlayerGui. Servidor autoritativo em tudo.
	Capítulo com `DeliverNpcUserId`: aceita-se com o NpcUserId e entrega-se com o outro (final: o traidor dá o
	capítulo, o Humanoider_20 recebe). `QuestService.OnTalk(fn)` avisa quem quiser (TraitorService invoca o
	NPC hostil ao aceitar/voltar no capítulo final). Servidor privado: funciona, mas nada salva (dono).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local QuestConfig = require(Modules:WaitForChild("QuestConfig"))
local TeamConfig = require(Modules:WaitForChild("TeamConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local ShopNpcService = require(script.Parent:WaitForChild("ShopNpcService"))

local QuestService = {}

QuestService.NpcFolderName = "QuestNpcs"
QuestService.BoardFolderName = "QuestBoards"
-- mural das quests na Taberna (montada por tools/montar_taberna.luau: x 325..381, z 28..129, chão -1): parede SUL
QuestService.BoardCFrame = CFrame.new(353, 7, 28.7) * CFrame.Angles(0, 0, 0)
QuestService.BoardSize = Vector3.new(16, 9, 0.4)

local notifyQuest: RemoteEvent
local npcs: { [number]: Model } = {} -- userId -> modelo
local visitSpots: { [string]: QuestConfig.Spot } = {}
local talkHooks: { (Player, QuestConfig.Chapter, string) -> () } = {} -- (jogador, capítulo, "accept"|"progress"|"done")

--- Outro service quer saber quando alguém aceita/volta/entrega um capítulo (phase = accept|progress|done).
function QuestService.OnTalk(fn: (Player, QuestConfig.Chapter, string) -> ())
	table.insert(talkHooks, fn)
end

local function fireTalk(player: Player, ch: QuestConfig.Chapter, phase: string)
	for _, fn in talkHooks do
		task.spawn(fn, player, ch, phase)
	end
end

-- ---------------------------------------------------------------------------
-- Estado por jogador
-- ---------------------------------------------------------------------------

local function questsOf(player: Player)
	local profile = DataService.GetProfile(player)
	return profile, if profile then profile.quests else nil
end

local function chapterOf(q): QuestConfig.Chapter?
	return QuestConfig.Chapters[q.chapter]
end

--- O progresso é salvo por ÍNDICE (`chapter`) mas os capítulos entregues ficam por Id (`done`): quando a história
--- ganha capítulo no meio (C0, 2026-09-25: cap2b/cap4b), o índice salvo apontaria para o capítulo errado. Aqui o
--- capítulo atual vira o PRIMEIRO ainda não entregue; se mudou, o capítulo em andamento recomeça (fala de novo com o NPC).
local function migrateChapter(player: Player)
	local _, q = questsOf(player)
	if not q then
		return
	end
	local first = #QuestConfig.Chapters + 1
	for i, ch in QuestConfig.Chapters do
		if not q.done[ch.Id] then
			first = i
			break
		end
	end
	if q.chapter ~= first then
		Log.debug(("[QuestService] %s: capítulo %d -> %d (história mudou)"):format(player.Name, q.chapter, first))
		q.chapter = first
		q.active = false
		q.counters = {}
		DataService.MarkDirty(player)
	end
end

local function objectiveDone(q, obj: QuestConfig.Objective): boolean
	return (q.counters[obj.Kind] or 0) >= obj.Goal
end

local function allDone(q, ch: QuestConfig.Chapter): boolean
	for _, obj in ch.Objectives do
		if not objectiveDone(q, obj) then
			return false
		end
	end
	return true
end

local function npcNameOf(ch: QuestConfig.Chapter?): string
	local m = ch and ch.NpcUserId and TeamConfig.ByUserId(ch.NpcUserId)
	return if m then m.DisplayName else "?"
end

--- Quem recebe a entrega e onde fica (DeliverNpcUserId, senão o próprio NPC do capítulo).
local function delivererOf(ch: QuestConfig.Chapter): (string, string)
	local userId = ch.DeliverNpcUserId or ch.NpcUserId
	local m = userId and TeamConfig.ByUserId(userId)
	local spot = QuestConfig.Spots[ch.Spot]
	if ch.DeliverNpcUserId then
		for _, c in QuestConfig.Chapters do
			if c.NpcUserId == ch.DeliverNpcUserId then
				spot = QuestConfig.Spots[c.Spot]
				break
			end
		end
	end
	return if m then m.DisplayName else "?", if spot then spot.Label else ""
end

local function statePayload(player: Player): { [string]: any }?
	local _, q = questsOf(player)
	if not q then
		return nil
	end
	local ch = chapterOf(q)
	local objectives = {}
	if ch then
		for _, obj in ch.Objectives do
			table.insert(objectives, { kind = obj.Kind, goal = obj.Goal, desc = obj.Desc, progress = math.min(q.counters[obj.Kind] or 0, obj.Goal) })
		end
	end
	local spot = ch and QuestConfig.Spots[ch.Spot]
	local npcName, where = npcNameOf(ch), if spot then spot.Label else ""
	if ch and q.active and allDone(q, ch) then
		-- objetivos prontos: o chip aponta para quem RECEBE a entrega (final: Humanoider_20 na Taberna)
		npcName, where = delivererOf(ch)
	end
	return {
		chapter = q.chapter,
		total = #QuestConfig.Chapters,
		active = q.active,
		finished = ch == nil,
		locked = ch ~= nil and ch.Locked == true,
		id = ch and ch.Id,
		title = if ch then ch.Title else "Fim (por enquanto)",
		npc = npcName,
		where = where,
		objectives = objectives,
		complete = ch ~= nil and q.active and allDone(q, ch),
		done = q.done,
	}
end

local function pushState(player: Player)
	local payload = statePayload(player)
	if payload then
		notifyQuest:FireClient(player, "state", payload)
	end
end

-- ---------------------------------------------------------------------------
-- Progresso
-- ---------------------------------------------------------------------------

--- Soma (ou, com `max`, guarda o maior) no contador do capítulo ATIVO. Só conta o que o capítulo pede.
function QuestService.Progress(player: Player, kind: string, amount: number, max: boolean?)
	if not QuestConfig.Enabled then return end
	local _, q = questsOf(player)
	if not q or not q.active then
		return
	end
	local ch = chapterOf(q)
	if not ch or ch.Locked then
		return
	end
	local wanted: QuestConfig.Objective? = nil
	for _, obj in ch.Objectives do
		if obj.Kind == kind then
			wanted = obj
			break
		end
	end
	if not wanted then
		return
	end
	local before = q.counters[kind] or 0
	if before >= wanted.Goal then
		return
	end
	local value = if max or wanted.Max then math.max(before, amount) else before + amount
	q.counters[kind] = value
	DataService.MarkDirty(player)
	if value >= wanted.Goal then
		local complete = allDone(q, ch)
		local npcName, where = delivererOf(ch)
		notifyQuest:FireClient(player, "progress", {
			text = wanted.Desc:format(wanted.Goal) .. " ✔",
			complete = complete,
			npc = npcName,
			where = where,
		})
	end
	pushState(player)
end

--- O jogador está com ESTE capítulo aceito e ainda não entregue?
function QuestService.IsActiveOn(player: Player, chapterId: string): boolean
	local _, q = questsOf(player)
	if not q or not q.active then
		return false
	end
	local ch = chapterOf(q)
	return ch ~= nil and ch.Id == chapterId
end

-- ---------------------------------------------------------------------------
-- Falar com o NPC
-- ---------------------------------------------------------------------------

local function grantReward(player: Player, reward: QuestConfig.Reward): string
	local parts = {}
	if reward.EventPoints and reward.EventPoints > 0 then
		DataService.AddEventPoints(player, reward.EventPoints)
		table.insert(parts, ("%d pontos de evento"):format(reward.EventPoints))
	end
	if reward.Coins and reward.Coins > 0 then
		DataService.AddCoins(player, reward.Coins)
		table.insert(parts, ("%d pontos"):format(reward.Coins))
	end
	if reward.XP and reward.XP > 0 then
		ProgressionService.AddXP(player, reward.XP, "quest")
		table.insert(parts, ("%d XP"):format(reward.XP))
	end
	for _, id in { reward.Cosmetic, reward.Emote } do
		if id then
			local ok = AchievementService.GrantReward(player, id)
			if ok then
				table.insert(parts, id)
			end
		end
	end
	return table.concat(parts, ", ")
end

local function dialog(player: Player, npcUserId: number, text: string, kind: string, extra: { [string]: any }?)
	local m = TeamConfig.ByUserId(npcUserId)
	local data: { [string]: any } = extra or {}
	data.npc = if m then m.DisplayName else "?"
	data.userId = npcUserId
	data.text = text
	data.kind = kind
	notifyQuest:FireClient(player, "dialog", data)
end

local function onTalk(player: Player, npcId: any)
	if not QuestConfig.Enabled then return end
	local userId = tonumber(npcId)
	local npc = userId and npcs[userId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not userId or not npc or not root then
		return
	end
	local npcRoot = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not npcRoot or (npcRoot.Position - root.Position).Magnitude > QuestConfig.TalkDistance + 6 then
		return
	end
	local _, q = questsOf(player)
	if not q then
		return
	end
	local ch = chapterOf(q)
	if not ch then
		dialog(player, userId, "Você já zerou a história (por enquanto). Obrigado por jogar o Sahur!", "idle")
		return
	end
	if ch.Locked then
		dialog(player, userId, "O capítulo final ainda está sendo escrito... Alguém da equipe não é quem diz ser. Em breve.", "locked")
		return
	end
	local deliverTo = ch.DeliverNpcUserId or ch.NpcUserId
	local isGiver = ch.NpcUserId == userId
	local isDeliverer = deliverTo == userId
	if not isGiver and not isDeliverer then
		-- não é o NPC do capítulo atual: aponta para o certo
		local target = npcNameOf(ch)
		local spot = QuestConfig.Spots[ch.Spot]
		-- um NPC pode ter vários capítulos (adryan: cap2b/cap4/final): "já me ajudou" só se nenhum deles está por vir
		local helped, pending = false, false
		for i, c in QuestConfig.Chapters do
			if c.NpcUserId == userId then
				if q.done[c.Id] then
					helped = true
				elseif i > q.chapter then
					pending = true
				end
			end
		end
		if helped and not pending then
			dialog(player, userId, ("Você já me ajudou. Agora é com %s, %s."):format(target, if spot then "em " .. spot.Label else ""), "idle")
		else
			dialog(player, userId, ("Ainda não é comigo. Procure %s %s."):format(target, if spot then "em " .. spot.Label else ""), "idle")
		end
		return
	end
	if not q.active then
		if not isGiver then
			local spot = QuestConfig.Spots[ch.Spot]
			dialog(player, userId, ("Antes fale com %s, %s."):format(npcNameOf(ch), if spot then "em " .. spot.Label else ""), "idle")
			return
		end
		q.active = true
		q.counters = {}
		DataService.MarkDirty(player)
		dialog(player, userId, ch.Intro, "accept", { title = ch.Title })
		pushState(player)
		fireTalk(player, ch, "accept")
		return
	end
	if allDone(q, ch) then
		if not isDeliverer then
			-- o capítulo é entregue com OUTRO NPC (final): o traidor não recebe nada
			local who = if deliverTo then TeamConfig.ByUserId(deliverTo) else nil
			dialog(player, userId, ("...Já acabou? Vai contar para %s. Ele vai adorar saber."):format(if who then who.DisplayName else "?"), "progress")
			return
		end
		local what = grantReward(player, ch.Reward)
		q.done[ch.Id] = true
		q.chapter += 1
		q.active = false
		q.counters = {}
		DataService.MarkDirty(player)
		Log.debug(("[QuestService] %s entregou '%s' (%s)"):format(player.Name, ch.Title, what))
		local nextCh = chapterOf(q)
		dialog(player, userId, ch.Done, "done", {
			title = ch.Title,
			reward = what,
			next = if nextCh and not nextCh.Locked then ("Próximo: %s com %s, em %s"):format(nextCh.Title, npcNameOf(nextCh), (QuestConfig.Spots[nextCh.Spot] or { Label = "" }).Label) else nil,
		})
		pushState(player)
		fireTalk(player, ch, "done")
		return
	end
	if not isGiver then
		local spot = QuestConfig.Spots[ch.Spot]
		dialog(player, userId, ("Ainda não terminou? %s está te esperando, %s."):format(npcNameOf(ch), if spot then "em " .. spot.Label else ""), "idle")
		return
	end
	fireTalk(player, ch, "progress")
	dialog(player, userId, ch.Progress, "progress", { title = ch.Title })
end

--- [DEV/testes] Pula para o capítulo `index` (1..#Chapters+1) sem recompensa; marca os anteriores como feitos.
function QuestService.SetChapter(player: Player, index: number): (boolean, string)
	local _, q = questsOf(player)
	if not q then
		return false, "sem perfil"
	end
	index = math.clamp(math.floor(index), 1, #QuestConfig.Chapters + 1)
	q.chapter = index
	q.active = false
	q.counters = {}
	q.done = {}
	for i = 1, index - 1 do
		q.done[QuestConfig.Chapters[i].Id] = true
	end
	DataService.MarkDirty(player)
	pushState(player)
	local ch = chapterOf(q)
	return true, if ch then ("capítulo %d: %s (fale com %s em %s)"):format(index, ch.Title, npcNameOf(ch), (QuestConfig.Spots[ch.Spot] or { Label = "" }).Label) else "história zerada"
end

--- [DEV/testes] Mesma coisa que apertar E no NPC (sem a checagem de distância).
function QuestService.Talk(player: Player, npcUserId: number)
	local saved = npcs[npcUserId]
	if not saved then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local npcRoot = saved:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and npcRoot then
		local was = root.CFrame
		root.CFrame = npcRoot.CFrame * CFrame.new(0, 0, -4)
		onTalk(player, npcUserId)
		root.CFrame = was
	end
end

-- ---------------------------------------------------------------------------
-- NPCs e mural
-- ---------------------------------------------------------------------------

local RAY = RaycastParams.new()
RAY.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(pos: Vector3): Vector3
	local hit = Workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), RAY)
	return if hit then hit.Position else pos
end

local function buildNpc(member: TeamConfig.Member, spot: QuestConfig.Spot, folder: Folder)
	-- C0 (2026-09-25): sempre rig R6 com a HumanoidDescription do membro (o jogo é R6). CreateHumanoidModelFromUserId
	-- vinha com o rig do avatar (R15 + escalas + roupas em camadas): altura variava (marcador "!" fora da cabeça),
	-- roupa 3D sumia e a pose ficava estranha. Roupa clássica (Shirt/Pants) e acessórios rígidos vêm na description.
	local ok, model = pcall(function()
		local desc = Players:GetHumanoidDescriptionFromUserId(member.UserId)
		-- escalas do avatar não valem em R6; zera para todos os devs terem o mesmo tamanho dos jogadores
		desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale, desc.BodyTypeScale, desc.ProportionScale = 1, 1, 1, 1, 0, 0
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn(("[QuestService] avatar de %s não carregou (%s); usando rig padrão"):format(member.DisplayName, tostring(model)))
		local ok2, fallback = pcall(function()
			return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
		end)
		if not ok2 or not fallback then
			return
		end
		model = fallback
	end
	model.Name = "Quest_" .. member.DisplayName
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = "DEV " .. member.DisplayName
		humanoid.NameDisplayDistance = 60
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		if not humanoid:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = humanoid
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	model:SetAttribute("QuestNpc", member.UserId)
	local ground = groundAt(spot.Pos)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- Apoia a parte MAIS BAIXA do rig no chão (HipHeight mente: R6 vem com 0 e avatar R15 escalado com 3+)
	model:PivotTo(CFrame.new(ground) * CFrame.Angles(0, math.rad(spot.Yaw), 0))
	local lowest = math.huge
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			lowest = math.min(lowest, d.Position.Y - d.Size.Y / 2)
		end
	end
	local lift = if lowest < math.huge then ground.Y - lowest + 0.05 else 3
	model:PivotTo(CFrame.new(ground + Vector3.new(0, lift, 0)) * CFrame.Angles(0, math.rad(spot.Yaw), 0))
	model.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QuestPrompt"
	prompt.ActionText = "Falar"
	prompt.ObjectText = "DEV " .. member.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = QuestConfig.TalkDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = root or model
	prompt.Triggered:Connect(function(player)
		onTalk(player, member.UserId)
	end)
	-- marcador "!" acima da cabeça (o cliente esconde quando não é o NPC do capítulo dele)
	local gui = Instance.new("BillboardGui")
	gui.Name = "QuestMarker"
	gui.Size = UDim2.fromOffset(40, 40)
	gui.StudsOffset = Vector3.new(0, 2.4, 0) -- R6: cabeça 1,2 de altura → "!" logo acima, sem ficar longe
	gui.MaxDistance = 120
	gui.AlwaysOnTop = true
	gui.Adornee = model:FindFirstChild("Head") or root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "!"
	label.TextColor3 = Color3.fromRGB(255, 214, 70)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = model
	npcs[member.UserId] = model
end

local function buildBoard()
	local folder = Workspace:FindFirstChild(QuestService.BoardFolderName) or Instance.new("Folder")
	folder.Name = QuestService.BoardFolderName
	folder.Parent = Workspace
	local old = folder:FindFirstChild("QuestBoard")
	if old then
		old:Destroy()
	end
	local board = Instance.new("Part")
	board.Name = "QuestBoard"
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.Size = QuestService.BoardSize
	board.CFrame = QuestService.BoardCFrame
	board.Material = Enum.Material.Wood
	board.Color = Color3.fromRGB(78, 52, 32)
	board.Parent = folder
	local frame = board:Clone()
	frame.Name = "QuestBoardFrame"
	frame.Size = QuestService.BoardSize + Vector3.new(0.8, 0.8, -0.1)
	frame.CFrame = QuestService.BoardCFrame * CFrame.new(0, 0, 0.1)
	frame.Color = Color3.fromRGB(40, 28, 18)
	frame:ClearAllChildren()
	frame.Parent = folder
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function QuestService.Init()
	notifyQuest = Remotes.GetEvent(Remotes.Events.NotifyQuest)
	if not QuestConfig.Enabled then return end
	Remotes.GetEvent(Remotes.Events.RequestQuestTalk).OnServerEvent:Connect(onTalk)
	-- contadores gerais (kills, parries, duel_wins, boss_kills, bricks, playtime...)
	AchievementService.OnProgress(function(player, kind, amount)
		QuestService.Progress(player, kind, amount)
	end)
	-- spots que algum capítulo pede para visitar
	for _, ch in QuestConfig.Chapters do
		for _, obj in ch.Objectives do
			local spotName = obj.Kind:match("^visit_(.+)$")
			if spotName and QuestConfig.Spots[spotName] then
				visitSpots[spotName] = QuestConfig.Spots[spotName]
			end
		end
	end
end

function QuestService.Start()
	if not QuestConfig.Enabled then return end
	-- Lojinha: NPC no tapete ao lado do vendedor, olhando para onde ele olha
	local lojinha = Workspace:FindFirstChild("Lojinha")
	local spotPart = lojinha and lojinha:FindFirstChild("VendedorSpot") :: BasePart?
	local shopPos = if spotPart then spotPart.Position else ShopNpcService.GetPosition()
	if shopPos then
		-- pé no chão (o root do vendedor fica a ~3 studs; começar o raycast alto pega o toldo da barraca)
		QuestConfig.Spots.Lojinha.Pos = Vector3.new(shopPos.X - 6, if spotPart then shopPos.Y else shopPos.Y - 3, shopPos.Z + 6)
		if spotPart then
			local look = spotPart.CFrame.LookVector
			QuestConfig.Spots.Lojinha.Yaw = math.deg(math.atan2(-look.X, -look.Z))
		end
	end
	local folder = Workspace:FindFirstChild(QuestService.NpcFolderName) or Instance.new("Folder")
	folder.Name = QuestService.NpcFolderName
	folder.Parent = Workspace
	folder:ClearAllChildren()
	RAY.FilterDescendantsInstances = { folder }
	buildBoard()
	local built = 0
	local planned: { [number]: boolean } = {} -- um NPC por membro (cap. 4 e final usam o mesmo adryan_keep)
	for _, ch in QuestConfig.Chapters do
		local member = ch.NpcUserId and TeamConfig.ByUserId(ch.NpcUserId)
		local spot = QuestConfig.Spots[ch.Spot]
		if member and spot and not planned[member.UserId] then
			planned[member.UserId] = true
			task.spawn(function()
				buildNpc(member, spot, folder)
			end)
			built += 1
		end
	end
	Log.debug(("[QuestService] %d capítulos, %d NPCs, %d spots de visita"):format(#QuestConfig.Chapters, built, (function()
		local n = 0
		for _ in visitSpots do
			n += 1
		end
		return n
	end)()))

	DataService.ProfileLoaded.Event:Connect(function(player: Player)
		migrateChapter(player)
		pushState(player)
	end)
	local function hookStreak(player: Player)
		player:GetAttributeChangedSignal("KillStreak"):Connect(function()
			local streak = player:GetAttribute("KillStreak")
			if typeof(streak) == "number" and streak > 0 then
				QuestService.Progress(player, "streak", streak, true)
			end
		end)
	end
	Players.PlayerAdded:Connect(hookStreak)
	for _, p in Players:GetPlayers() do
		hookStreak(p) -- quem já estava (Studio Play)
	end
	-- visitas: checa posição a cada 2 s só de quem tem capítulo ativo com visit_*
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				local _, q = questsOf(player)
				local ch = if q and q.active then chapterOf(q) else nil
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if q and ch and root then
					for _, obj in ch.Objectives do
						local spotName = obj.Kind:match("^visit_(.+)$")
						local spot = spotName and visitSpots[spotName]
						if spot and (q.counters[obj.Kind] or 0) < obj.Goal and (root.Position - spot.Pos).Magnitude <= QuestConfig.VisitRadius then
							QuestService.Progress(player, obj.Kind, 1)
						end
					end
				end
			end
		end
	end)
end

return QuestService
