--!strict
--[[ Campanha F/X: atos orientados por dados, progresso e Rastros de Carlos. ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local StoryConfig = require(Modules:WaitForChild("StoryConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local Combatant = require(Modules:WaitForChild("Combatant"))

local StoryService = {}
local notifyStory: RemoteEvent

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

function StoryService.Begin(player: Player): boolean
	local profile, _chapter, act = current(player)
	if not profile or not act or act.Id ~= "chegada" then return false end
	profile.story.act, profile.story.counters = 2, {}
	profile.story.flags.fx_campaign_started = true
	DataService.MarkDirty(player); apply(player); push(player, "act")
	return true
end

function StoryService.Progress(player: Player, kind: string, amount: number): boolean
	local profile, _chapter, act = current(player)
	if not profile or not act or amount <= 0 then return false end
	local wanted = false
	for _, objective in act.Objectives do if objective.Kind == kind then wanted = true; break end end
	if not wanted then return false end
	profile.story.counters[kind] = (profile.story.counters[kind] or 0) + amount
	local advanced = objectivesDone(profile, act)
	if advanced then
		profile.story.act += 1
		profile.story.counters = {}
		if act.Id == "guardiao_da_era" then profile.story.flags.ilha_sol_partido_unlocked = true end
		if act.Id == "sentinela_solar" then profile.story.flags.ilha_mar_cinzas_unlocked = true end
	end
	DataService.MarkDirty(player); apply(player); push(player, if advanced then "act" else "state")
	return true
end

function StoryService.ArriveRegion(player: Player, regionId: string)
	local _profile, _chapter, act = current(player)
	if act and act.Id == "rota_sol_partido" and regionId == "ilha_sol_partido" then
		StoryService.AdvanceAct(player, 5)
	end
end

function StoryService.AdvanceAct(player: Player, expectedAct: number): boolean
	local profile = DataService.GetProfile(player)
	if not profile or profile.story.act ~= expectedAct then return false end
	profile.story.act, profile.story.counters = expectedAct + 1, {}
	DataService.MarkDirty(player); apply(player); push(player, "act")
	return true
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
	notifyStory:FireClient(player, "trace", { id = traceId, title = "Rastro de Carlos", text = "Uma gravação quebrada menciona alguém preparando a F/X por dentro." })
	return true
end

function StoryService.Init()
	notifyStory = Remotes.GetEvent(Remotes.Events.NotifyStory)
	Remotes.GetEvent(Remotes.Events.RequestStoryState).OnServerEvent:Connect(function(player) push(player) end)
end

function StoryService.Start()
	DataService.ProfileLoaded.Event:Connect(function(player: Player) apply(player) end)
	AchievementService.OnProgress(function(player, kind, amount)
		local region = player:GetAttribute("WorldRegion")
		if region == "ilha_tutorial" or region == "ilha_sol_partido" then StoryService.Progress(player, kind, amount) end
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
