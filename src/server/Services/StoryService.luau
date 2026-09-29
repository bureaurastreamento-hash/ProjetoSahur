--!strict
--[[
	Campanha F/X: atos orientados por dados (StoryConfig), progresso, Rastros de Carlos e falas do Humanoider_20.
	Ao entrar num ato novo, a fala `Guide` dele chega como diálogo (funciona em qualquer ilha, "pelo comunicador").
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

local StoryService = {}
local notifyStory: RemoteEvent
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

-- Conclui o ato atual: grava a flag dele, passa para o próximo e manda a fala do guia do ato novo.
local function finishAct(player: Player, profile: any, act: StoryConfig.Act, silent: boolean?)
	if act.UnlockFlag then profile.story.flags[act.UnlockFlag] = true end
	if act.Reward and not profile.story.completed[act.Id] then StandService.Give(player, act.Reward, "story") end
	profile.story.completed[act.Id] = true
	profile.story.act += 1
	profile.story.counters = {}
	DataService.MarkDirty(player); apply(player); push(player, "act")
	local _p, _c, nextAct = current(player)
	if not silent and nextAct and nextAct.Guide then StoryService.Say(player, nextAct.Guide) end
end

--- Conversar com o Humanoider_20: começa a campanha ("chegada") ou repete a fala do ato atual.
function StoryService.TalkToGuide(player: Player)
	local profile, _chapter, act = current(player)
	if not profile then return end
	if act and act.Id == "chegada" then
		profile.story.flags.fx_campaign_started = true
		StoryService.Say(player, act.Guide or "")
		finishAct(player, profile, act, true) -- a fala da chegada já explica o próximo passo
		return
	end
	StoryService.Say(player, if act and act.Guide then act.Guide else "Por enquanto, explore. Eu aviso quando a próxima ruptura estabilizar.")
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
end

function StoryService.Start()
	DataService.ProfileLoaded.Event:Connect(function(player: Player) apply(player) end)
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
