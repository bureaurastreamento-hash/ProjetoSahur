--!strict
--[[
	Campanha F/X: atos orientados por dados (StoryConfig), progresso, Rastros de Carlos e falas do Humanoider_20.
	Ao entrar num ato novo, a fala `Intro` (ou o `Guide`) chega como diálogo (qualquer ilha, "pelo comunicador").
	ECOS (escolhas): ato com `Choice` abre a escolha na tela (NotifyStory "choice"); RequestStoryChoice responde,
	grava as flags da opção e conclui o ato. Objetivos "reach_<lugar>" são conferidos pela posição (StoryConfig.Places).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local StoryConfig = require(Modules:WaitForChild("StoryConfig"))
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local Combatant = require(Modules:WaitForChild("Combatant"))
local StandService = require(script.Parent:WaitForChild("StandService"))

local RateLimiter = require(Modules:WaitForChild("RateLimiter"))

local StoryService = {}
local notifyStory: RemoteEvent
local choiceLimiter = RateLimiter.new(3, 1)
local notifyQuest: RemoteEvent

StoryService.GuideUserId = 3792294725 -- Humanoider_20

--- Caixa de diálogo do QuestController. Sem `npc` = Humanoider_20; NPC sem `userId` = sem foto.
function StoryService.Say(player: Player, text: string, npc: string?, userId: number?)
	if player.Parent ~= Players then return end
	notifyQuest:FireClient(player, "dialog", { npc = npc or "Humanoider_20", userId = if npc then userId else StoryService.GuideUserId, kind = "progress", text = text })
end

-- Atos da revisão 1 (ChatGPT, 28/09) → revisão 2 (bíblia do Cap. 1). Quem já tinha passado do Guardião volta para
-- "Calor" (Ilha 2 agora vem antes do conteúdo que ficava no Sol Partido), com as rotas que já tinha abertas.
local function migrate(profile: any)
	local story = profile.story
	if story.rev >= StoryConfig.Revision then return end
	if story.chapter == "cap1" and story.rev < 2 then
		if story.act >= 5 then
			story.act, story.counters = 5, {}
			story.flags.ilha_pilares_unlocked = true
		end
		story.flags.ilha_mar_cinzas_unlocked = nil
		story.rev = 2
	end
	-- rev 2 → 3 (29/09): Ilha 1 ganhou Missões 0, 2, 4 e os dois Ecos na frente/no meio dos atos antigos.
	if story.chapter == "cap1" and story.rev < 3 then
		local map = { [1] = 2, [2] = 4, [3] = 8, [4] = 9 }
		story.act = map[story.act] or (story.act + 6)
		story.counters = {}
	end
	story.rev = StoryConfig.Revision
end

local function current(player: Player)
	local profile = DataService.GetProfile(player)
	local chapter = profile and StoryConfig.Get(profile.story.chapter)
	local act = nil
	if profile and chapter then act = chapter.Acts[profile.story.act] end
	return profile, chapter, act
end

local function payload(player: Player): { [string]: any }?
	local profile, chapter, act = current(player)
	if not profile or not chapter then return nil end
	local objectives = {}
	if act then
		for _, objective in act.Objectives do
			table.insert(objectives, { kind = objective.Kind, goal = objective.Goal, text = objective.Text,
				progress = math.min(profile.story.counters[objective.Kind] or 0, objective.Goal) })
		end
	end
	return { chapter = chapter.Id, chapterTitle = chapter.Title, act = profile.story.act,
		actId = act and act.Id, actTitle = act and act.Title or "Capítulo concluído", hint = act and act.Hint, objectives = objectives }
end

local function push(player: Player, event: string?)
	local data = payload(player)
	if data and player.Parent == Players then notifyStory:FireClient(player, event or "state", data) end
end

local function objectivesDone(profile, act): boolean
	for _, objective in act.Objectives do
		if (profile.story.counters[objective.Kind] or 0) < objective.Goal then return false end
	end
	return true
end

local function apply(player: Player)
	local base = DataService.GetProfile(player)
	if base and base.story.rev < StoryConfig.Revision then
		migrate(base)
		DataService.MarkDirty(player)
	end
	local profile, chapter = current(player)
	if not profile then return end
	if not chapter then
		profile.story.chapter, profile.story.act, profile.story.counters = "cap1", 1, {}
		DataService.MarkDirty(player)
	end
	player:SetAttribute("StoryChapter", profile.story.chapter)
	player:SetAttribute("StoryAct", profile.story.act)
	push(player)
end

-- Abre a escolha (Eco) do ato na tela. Opção com RequiresFlag vai desligada se o jogador não explorou antes.
local function offerChoice(player: Player, act: StoryConfig.Act?)
	local choice = act and act.Choice
	if not choice or player.Parent ~= Players then return end
	local options = {}
	for _, option in choice.Options do
		table.insert(options, { id = option.Id, label = option.Label, desc = option.Desc,
			enabled = option.RequiresFlag == nil or StoryService.HasFlag(player, option.RequiresFlag) })
	end
	notifyStory:FireClient(player, "choice", { id = choice.Id, title = choice.Title, text = choice.Text, options = options })
end

-- Fala de entrada do ato (Intro com IntroNpc, senão o Guide) — ou a escolha, se o ato for um Eco.
local function introduce(player: Player, act: StoryConfig.Act?)
	if not act then return end
	if act.Choice then
		offerChoice(player, act)
	elseif act.Intro then
		StoryService.Say(player, act.Intro, act.IntroNpc)
	elseif act.Guide then
		StoryService.Say(player, act.Guide, act.GuideNpc)
	end
end

-- Conclui o ato atual: grava a flag dele, passa para o próximo e apresenta o ato novo.
local function finishAct(player: Player, profile: any, act: StoryConfig.Act, silent: boolean?)
	if act.UnlockFlag then profile.story.flags[act.UnlockFlag] = true end
	if act.Reward and not profile.story.completed[act.Id] then StandService.Give(player, act.Reward, "story") end
	profile.story.completed[act.Id] = true
	profile.story.act += 1
	profile.story.counters = {}
	DataService.MarkDirty(player); apply(player); push(player, "act")
	local _p, _c, nextAct = current(player)
	if not silent then introduce(player, nextAct) end
end

--- Resposta do Eco: valida (ato atual, opção existe, flag exigida), grava as flags e conclui o ato.
function StoryService.Choose(player: Player, choiceId: any, optionId: any): boolean
	local profile, _chapter, act = current(player)
	local choice = act and act.Choice
	if not profile or not act or not choice or choice.Id ~= choiceId then return false end
	for _, option in choice.Options do
		if option.Id == optionId then
			if option.RequiresFlag and not StoryService.HasFlag(player, option.RequiresFlag) then return false end
			for _, flag in option.Flags do profile.story.flags[flag] = true end
			profile.story.flags[choice.Id .. "_" .. option.Id] = true
			StoryService.Say(player, option.Say)
			finishAct(player, profile, act, true)
			-- a fala do ato seguinte vem depois da reação à escolha (duas caixas ao mesmo tempo se atropelam)
			local _p, _c, nextAct = current(player)
			task.delay(5, function() introduce(player, nextAct) end)
			return true
		end
	end
	return false
end

--- Pistas escondidas que liberam opções dos Ecos (fenda_saida, passagem_capela...).
function StoryService.SetFlag(player: Player, flag: string)
	local profile = DataService.GetProfile(player)
	if not profile or profile.story.flags[flag] then return end
	profile.story.flags[flag] = true
	DataService.MarkDirty(player)
end

--- Conversar com o Humanoider_20: começa a campanha ("chegada") ou repete a fala do ato atual.
function StoryService.TalkToGuide(player: Player)
	local profile, _chapter, act = current(player)
	if not profile then return end
	if act and act.Id == "chegada" then
		profile.story.flags.fx_campaign_started = true
		StoryService.Say(player, act.Guide or "")
		finishAct(player, profile, act, true)
		local _p, _c, nextAct = current(player)
		task.delay(6, function() introduce(player, nextAct) end)
		return
	end
	if act and act.Choice then
		offerChoice(player, act) -- escolha pendente (fechou a tela / reconectou)
		return
	end
	StoryService.Say(player, if act and act.Guide then act.Guide else "Por enquanto, explore. Eu aviso quando a próxima ruptura estabilizar.",
		act and act.GuideNpc)
end

function StoryService.Begin(player: Player): boolean
	local profile, _chapter, act = current(player)
	if not profile or not act or act.Id ~= "chegada" then return false end
	profile.story.flags.fx_campaign_started = true
	finishAct(player, profile, act)
	return true
end

function StoryService.Progress(player: Player, kind: string, amount: number): boolean
	local profile, _chapter, act = current(player)
	if not profile or not act or amount <= 0 then return false end
	local wanted = false
	for _, objective in act.Objectives do if objective.Kind == kind then wanted = true; break end end
	if not wanted then return false end
	profile.story.counters[kind] = (profile.story.counters[kind] or 0) + amount
	if objectivesDone(profile, act) then
		finishAct(player, profile, act)
	else
		DataService.MarkDirty(player); push(player, "state")
	end
	return true
end

--- O ato atual tem objetivo `kind`? (para os services das ilhas darem feedback só quando conta)
function StoryService.Wants(player: Player, kind: string): boolean
	local _profile, _chapter, act = current(player)
	if not act then return false end
	for _, objective in act.Objectives do if objective.Kind == kind then return true end end
	return false
end

function StoryService.ArriveRegion(player: Player, regionId: string)
	local profile, _chapter, act = current(player)
	if profile and act and act.Arrive == regionId then finishAct(player, profile, act) end
end

function StoryService.AdvanceAct(player: Player, expectedAct: number): boolean
	local profile = DataService.GetProfile(player)
	if not profile or profile.story.act ~= expectedAct then return false end
	profile.story.act, profile.story.counters = expectedAct + 1, {}
	DataService.MarkDirty(player); apply(player); push(player, "act")
	return true
end

--- Região da ilha onde o personagem ESTÁ (posição real; o atributo WorldRegion é só o checkpoint salvo).
function StoryService.RegionOf(player: Player): string?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return nil end
	local island = WorldConfig.IslandAt(root.Position)
	return island and island.Region
end

function StoryService.HasFlag(player: Player, flag: string): boolean
	local profile = DataService.GetProfile(player)
	return profile ~= nil and profile.story.flags[flag] == true
end

function StoryService.DiscoverTrace(player: Player, traceId: string): boolean
	local profile = DataService.GetProfile(player)
	if not profile or traceId == "" then return false end
	if profile.story.traces[traceId] then
		StoryService.Progress(player, "trace_" .. traceId, 1)
		return false
	end
	profile.story.traces[traceId] = true
	DataService.MarkDirty(player)
	StoryService.Progress(player, "trace_" .. traceId, 1)
	local info = StoryConfig.Traces[traceId]
	notifyStory:FireClient(player, "trace", { id = traceId, title = "Rastro encontrado · " .. (if info then info.Title else "?"), -- o nome "Carlos" só aparece na Missão 18
		text = if info then info.Text else "Um eco que ninguém soube explicar." })
	return true
end

function StoryService.Init()
	notifyStory = Remotes.GetEvent(Remotes.Events.NotifyStory)
	notifyQuest = Remotes.GetEvent(Remotes.Events.NotifyQuest)
	Remotes.GetEvent(Remotes.Events.RequestStoryState).OnServerEvent:Connect(function(player) push(player) end)
	Remotes.GetEvent(Remotes.Events.RequestStoryChoice).OnServerEvent:Connect(function(player, choiceId, optionId)
		if choiceLimiter:Allow(player) then StoryService.Choose(player, choiceId, optionId) end
	end)
end

function StoryService.Start()
	DataService.ProfileLoaded.Event:Connect(function(player: Player)
		apply(player)
		local _p, _c, act = current(player)
		if act and act.Choice then task.delay(4, function() offerChoice(player, act) end) end -- Eco pendente
	end)
	-- objetivos "reach_<lugar>": confere a posição a cada meio segundo
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local _p, _c, act = current(player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if act and root and root:IsA("BasePart") then
					for _, objective in act.Objectives do
						local placeId = objective.Kind:match("^reach_(.+)$")
						local place = placeId and StoryConfig.Places[placeId]
						if place and (root.Position - place.Position).Magnitude <= place.Radius then
							StoryService.Progress(player, objective.Kind, 1)
							break
						end
					end
				end
			end
		end
	end)
	AchievementService.OnProgress(function(player, kind, amount)
		-- contadores genéricos (kills/parries) só valem na ilha do ato atual (nunca no Coliseu/arena)
		local _profile, _chapter, act = current(player)
		if act and act.Region and StoryService.RegionOf(player) == act.Region then StoryService.Progress(player, kind, amount) end
	end)
	HealthService.FighterDied.Event:Connect(function(victim: Combatant.Fighter, killer: Combatant.Fighter?)
		if not Combatant.IsBot(victim) then return end
		local kind = victim:GetAttribute("StoryKillKind")
		local player = Combatant.PlayerOf(killer)
		if player and typeof(kind) == "string" then StoryService.Progress(player, kind, 1) end
	end)
	for _, player in Players:GetPlayers() do apply(player) end
end

return StoryService
