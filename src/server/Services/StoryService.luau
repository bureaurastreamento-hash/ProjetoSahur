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
local SidequestConfig = require(Modules.SidequestConfig)
local WorldConfig = require(Modules:WaitForChild("WorldConfig"))
local ProgressionConfig = require(Modules.ProgressionConfig)
local DataService = require(script.Parent:WaitForChild("DataService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local Combatant = require(Modules:WaitForChild("Combatant"))
local StandService = require(script.Parent:WaitForChild("StandService"))
local BuildService = require(script.Parent.BuildService)
local ProgressionService = require(script.Parent.ProgressionService)

local RateLimiter = require(Modules:WaitForChild("RateLimiter"))

local StoryService = {}
local StoryNavigation = require(script.Parent.Parent.Modules.StoryNavigation)
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
	-- rev 3 → 4: inserir Eco após Sol Negro e Viajante após Caçados, mantendo o ato em curso.
	-- Não apagar contadores, escolhas, Rastros nem rotas que já estavam liberadas.
	if story.chapter == "cap1" and story.rev < 4 then
		local oldAct = story.act
		if oldAct >= 16 then story.act += 1 end
		if oldAct >= 18 then story.act += 1 end
	end
	-- Rev4 terminava no ato 22. Saves além desse limite voltam só à chegada, sem perder flags/itens.
	if story.chapter == "cap1" and story.rev < 5 and story.act > 22 then
		story.act, story.counters = 22, {}
	end
	-- Rev5 terminava na espera pela Costa (30); não pular a chegada de um mapa futuro.
	if story.chapter == "cap1" and story.rev < 6 and story.act > 30 then
		story.act, story.counters = 30, {}
	end
	-- Rev6 terminava na espera pela Fortaleza (39); manter chegada como limite antigo.
	if story.chapter == "cap1" and story.rev < 7 and story.act > 39 then
		story.act, story.counters = 39, {}
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

-- Nível mínimo do ato (dono 30/09: "prender"): abaixo dele o objetivo não conta e a dica manda treinar.
local function levelLocked(profile: any, act: StoryConfig.Act?): boolean
	return act ~= nil and act.MinLevel ~= nil and (profile.level or 1) < act.MinLevel
end

local TRAINING_HINT = {
	ilha_tutorial = "Treine nos Campos da Névoa (oeste da vila, pela ponte): Vagantes e o Capataz.",
	ilha_pilares = "Treine contra os Homens de Pedra do Deserto do Sol.",
	ilha_sol_partido = "Treine contra os Caçadores de Recompensa da Rota do Eclipse.",
}
local function lockedHint(profile: any, act: StoryConfig.Act): string
	return ("Nível %d necessário (você está no %d). %s"):format(act.MinLevel or 1, profile.level or 1,
		TRAINING_HINT[act.Region or ""] or "Treine derrotando inimigos da região.")
end
local lockedWarned: { [Player]: number } = {}

local function payload(player: Player): { [string]: any }?
	local profile, chapter, act = current(player)
	if not profile or not chapter then return nil end
	local objectives = {}
	if act then
		for _, objective in act.Objectives do
			if objective.WhenFlag and not profile.story.flags[objective.WhenFlag] then continue end
			table.insert(objectives, { kind = objective.Kind, goal = objective.Goal, text = objective.Text,
				progress = math.min(profile.story.counters[objective.Kind] or 0, objective.Goal) })
		end
	end
	local locked = levelLocked(profile, act)
	return { chapter = chapter.Id, chapterTitle = chapter.Title, act = profile.story.act,
		actId = act and act.Id, actTitle = act and act.Title or "Capítulo concluído",
		hint = if locked then lockedHint(profile, act) else act and act.Hint, lockedLevel = if locked and act then act.MinLevel else nil,
		navigation = StoryNavigation.Next(act, objectives, locked), xp = act and act.XP or 0, coins = act and act.Coins or 0,
		objectives = objectives, optional = SidequestConfig.State(profile.story.flags) }
end

local function push(player: Player, event: string?)
	local data = payload(player)
	if data and player.Parent == Players then notifyStory:FireClient(player, event or "state", data) end
end

function StoryService.Refresh(player: Player)
	push(player)
end

local function objectivesDone(profile, act): boolean
	for _, objective in act.Objectives do
		if objective.WhenFlag and not profile.story.flags[objective.WhenFlag] then continue end
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
	-- O contador antigo desta missão vinha de kills PvP. Nunca reaproveitar como Vagantes.
	local _, _, act = current(player)
	if act and act.Id == "primeiros_golpes" and (profile.story.counters.kills or 0) > 0 then
		profile.story.counters.kills = 0
		DataService.MarkDirty(player)
	end
	if not chapter then
		profile.story.chapter, profile.story.act, profile.story.counters = "cap1", 1, {}
		DataService.MarkDirty(player)
	end
	player:SetAttribute("StoryChapter", profile.story.chapter)
	player:SetAttribute("StoryAct", profile.story.act)
	push(player)
end

local function pendingDesertEco(profile): boolean
	return profile.story.chapter == "cap1" and profile.story.act > 16
		and (profile.story.completed.sol_negro == true or profile.story.flags.ilha_sol_partido_unlocked == true)
		and not profile.story.completed.eco_deserto
end

-- Abre a escolha (Eco) do ato na tela. Opção com RequiresFlag vai desligada se o jogador não explorou antes.
local function offerChoice(player: Player, act: StoryConfig.Act?)
	local choice = act and act.Choice
	if not choice or player.Parent ~= Players then return end
	local profile = DataService.GetProfile(player)
	if not profile or not act or not objectivesDone(profile, act) then return end
	local chapter = StoryConfig.Get(profile.story.chapter)
	local active = chapter and chapter.Acts[profile.story.act]
	local catchup = choice.Id == "rota_inicial" and profile.story.chapter == "cap1" and profile.story.act > 3 and profile.build.route == ""
	local desertCatchup = choice.Id == "eco_ilha2" and pendingDesertEco(profile)
	if not catchup and not desertCatchup and (not active or not active.Choice or active.Choice.Id ~= choice.Id) then return end
	local options = {}
	for _, option in choice.Options do
		table.insert(options, { id = option.Id, label = option.Label, desc = option.Desc,
			enabled = option.RequiresFlag == nil or StoryService.HasFlag(player, option.RequiresFlag) })
	end
	notifyStory:FireClient(player, "choice", { id = choice.Id, title = choice.Title, text = choice.Text, options = options })
end

-- Fala de entrada do ato (Intro com IntroNpc, senão o Guide) — ou a escolha, se o ato for um Eco.
-- O Ancião (Guide sem GuideNpc) só aparece em diálogo nos atos `Key`; nos outros a missão chega como aviso
-- discreto (dono 30/09: "ancião ali, na próxima esquina outro ancião"). A fala continua no NPC dele na vila.
local function introduce(player: Player, act: StoryConfig.Act?)
	if not act then return end
	local profile = DataService.GetProfile(player)
	if act.Choice and profile and objectivesDone(profile, act) then
		offerChoice(player, act)
	elseif act.Intro then
		StoryService.Say(player, act.Intro, act.IntroNpc)
	elseif act.Guide and (act.Key or act.GuideNpc ~= nil) then
		StoryService.Say(player, act.Guide, act.GuideNpc)
	elseif profile then
		local first = act.Objectives[1]
		local text = if levelLocked(profile, act) then lockedHint(profile, act)
			elseif first then first.Text else (act.Hint or "Fale com o Humanoider_20 na vila.")
		notifyQuest:FireClient(player, "toast", { title = ("Missão %s · %s"):format(act.Mission or "", act.Title), text = text })
	end
end

-- Conclui o ato atual: grava a flag dele, passa para o próximo e apresenta o ato novo.
local function finishAct(player: Player, profile: any, act: StoryConfig.Act, silent: boolean?)
	if act.UnlockFlag then profile.story.flags[act.UnlockFlag] = true end
	if not profile.story.completed[act.Id] then
		if act.Reward then StandService.Give(player, act.Reward, "story") end
		-- toda missão paga algo na hora (dono 30/09: recompensa visível a cada passo)
		if act.XP then ProgressionService.AddXP(player, act.XP, "story") end
		if act.Coins then DataService.RewardCoins(player, act.Coins) end
		if act.Id == "eco_capela" then
			if profile.build.route ~= "manifestacao" then StandService.Give(player, { flecha = 1 }, "story") end
			BuildService.CompleteIsland(player)
		end
	end
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
	if not profile or not act then return false end
	-- Perfis que já passaram pela Missão 2 podem escolher sem reiniciar a campanha.
	local routeCatchup = choiceId == "rota_inicial" and profile.story.chapter == "cap1" and profile.story.act > 3 and profile.build.route == ""
	local desertCatchup = choiceId == "eco_ilha2" and pendingDesertEco(profile)
	local catchup = routeCatchup or desertCatchup
	if routeCatchup then choice = StoryConfig.Chapters[1].Acts[3].Choice end
	if desertCatchup then
		local desertAct = StoryConfig.Act("eco_deserto")
		choice = desertAct and desertAct.Choice
	end
	if not choice or choice.Id ~= choiceId or (not catchup and not objectivesDone(profile, act)) then return false end
	for _, option in choice.Options do
		if option.Id == optionId then
			if option.RequiresFlag and not StoryService.HasFlag(player, option.RequiresFlag) then return false end
			if choice.Id == "rota_inicial" then
				if not BuildService.SelectRoute(player, option.Id) then return false end
				if option.Id == "manifestacao" and not profile.story.completed.eco_capela then
					StandService.Give(player, { flecha = 1 }, "story")
				end
			elseif choice.Id == "tecnica_m8" and option.Id == "aprender" then
				BuildService.LearnTechnique(player)
			end
			for _, flag in option.Flags do profile.story.flags[flag] = true end
			profile.story.flags[choice.Id .. "_" .. option.Id] = true
			StoryService.Say(player, option.Say, if choice.Id == "tecnica_m8" then "Mestre da Respiração" else nil)
			if option.RetryObjective then
				profile.story.counters[option.RetryObjective] = 0
				profile.story.counters["seen_" .. option.RetryObjective] = nil
				DataService.MarkDirty(player); push(player)
				return true
			end
			if catchup then
				if desertCatchup then
					profile.story.completed.eco_deserto = true
					profile.story.flags.ilha_sol_partido_unlocked = true
				end
				DataService.MarkDirty(player)
				push(player)
				offerChoice(player, act)
				return true
			end
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
	if act and act.Choice and objectivesDone(profile, act) then
		offerChoice(player, act) -- escolha pendente (fechou a tela / reconectou)
		return
	end
	local summary = SidequestConfig.EchoSummary(profile.story.flags)
	local guideText = if act and act.Guide then act.Guide else "Por enquanto, explore. Eu aviso quando a próxima ruptura estabilizar."
	StoryService.Say(player, if summary ~= "" then summary .. " " .. guideText else guideText, act and act.GuideNpc)
end

function StoryService.Begin(player: Player): boolean
	local profile, _chapter, act = current(player)
	if not profile or not act or act.Id ~= "chegada" then return false end
	profile.story.flags.fx_campaign_started = true
	finishAct(player, profile, act)
	return true
end

function StoryService.Progress(player: Player, kind: string, amount: number, silent: boolean?): boolean
	local profile, _chapter, act = current(player)
	if not profile or not act or amount <= 0 then return false end
	-- O Avatar só conclui a campanha se as três âncoras foram ativadas antes de sua derrota.
	if kind == "fx_mare_avatar" and (profile.story.counters.fx_mare_ancora or 0) < 3 then return false end
	local wanted = false
	for _, objective in act.Objectives do if objective.Kind == kind and (not objective.WhenFlag or profile.story.flags[objective.WhenFlag]) then wanted = true; break end end
	if not wanted then return false end
	if levelLocked(profile, act) then
		local now = os.clock()
		if (lockedWarned[player] or 0) < now then
			lockedWarned[player] = now + 8
			notifyQuest:FireClient(player, "toast", { title = "Ainda não", text = lockedHint(profile, act) })
		end
		return false
	end
	profile.story.counters[kind] = (profile.story.counters[kind] or 0) + amount
	if objectivesDone(profile, act) then
		if act.Choice then
			DataService.MarkDirty(player); push(player); offerChoice(player, act)
		else
			finishAct(player, profile, act, silent)
		end
	else
		DataService.MarkDirty(player); push(player, "state")
	end
	return true
end

--- O ato atual tem objetivo `kind`? (para os services das ilhas darem feedback só quando conta)
function StoryService.Wants(player: Player, kind: string): boolean
	local profile, _chapter, act = current(player)
	if not profile or not act or levelLocked(profile, act) then return false end
	for _, objective in act.Objectives do
		if objective.Kind == kind and (not objective.WhenFlag or profile.story.flags[objective.WhenFlag]) then return true end
	end
	return false
end

--- Uma pista/morador só conta uma vez por ato; o identificador vem do serviço, nunca do cliente.
function StoryService.ProgressOnce(player: Player, kind: string, key: string, silent: boolean?): boolean
	local profile = DataService.GetProfile(player)
	if not profile or not StoryService.Wants(player, kind) then return false end
	local seen = "seen_" .. key
	if profile.story.counters[seen] then return false end
	profile.story.counters[seen] = 1
	return StoryService.Progress(player, kind, 1, silent)
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

--- Só aceita interação perto do marcador REAL fornecido pelo serviço da ilha.
function StoryService.CanInteract(player: Player, marker: BasePart, radius: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player.Parent == Players and root ~= nil and root:IsA("BasePart")
		and humanoid ~= nil and humanoid.Health > 0 and (root.Position - marker.Position).Magnitude <= radius
end

function StoryService.OfferDesertEco(player: Player)
	local profile, _chapter, act = current(player)
	if not profile then return end
	if (act and act.Id == "eco_deserto") or pendingDesertEco(profile) then
		offerChoice(player, StoryConfig.Act("eco_deserto"))
	end
end

function StoryService.DesertState(player: Player): string
	if StoryService.HasFlag(player, "eco_ilha2_selou") then return "A entidade está selada. A Câmara foi preservada." end
	if StoryService.HasFlag(player, "eco_ilha2_destruiu") then return "A entidade não despertará. Ruínas importantes foram perdidas." end
	if StoryService.HasFlag(player, "eco_ilha2_transferiu") then return "A entidade não despertará. Uma anomalia menor permanente ficou na região." end
	return "Os mecanismos da Câmara indicam uma sequência: II, I, III. É possível preparar uma transferência de energia."
end

--- Puzzle opcional da Câmara: ordem II → I → III; um erro reinicia só a tentativa.
function StoryService.AlignChamberSeal(player: Player, seal: number, marker: BasePart): boolean
	local profile = DataService.GetProfile(player)
	if not profile or not StoryService.CanInteract(player, marker, 14) or StoryService.RegionOf(player) ~= "ilha_pilares" then return false end
	if seal ~= 1 and seal ~= 2 and seal ~= 3 then return false end
	if profile.story.flags.camara_transferencia_preparada then
		if not profile.story.flags.relic_camara_rewarded then
			profile.story.flags.relic_camara_rewarded = true
			DataService.AddItem(player, "mat:selo_solar", 1)
			DataService.MarkDirty(player)
		end
		return true
	end
	local flags = profile.story.flags
	local step = if flags.camara_puzzle_etapa_2 then 3 elseif flags.camara_puzzle_etapa_1 then 2 else 1
	local sequence = { 2, 1, 3 }
	if seal ~= sequence[step] then
		flags.camara_puzzle_etapa_1, flags.camara_puzzle_etapa_2 = false, false
		DataService.MarkDirty(player)
		StoryService.Say(player, "Os mecanismos voltaram à posição inicial. A sequência indicada é II, I, III.")
		return false
	end
	if step == 3 then
		flags.camara_transferencia_preparada = true
		if not flags.relic_camara_rewarded then
			flags.relic_camara_rewarded = true
			DataService.AddItem(player, "mat:selo_solar", 1)
		end
		StoryService.Say(player, "Os mecanismos estão alinhados. A transferência de energia está preparada.")
	else
		flags["camara_puzzle_etapa_" .. step] = true
		StoryService.Say(player, "Um dos mecanismos se alinhou. Continue a sequência: II, I, III.")
	end
	DataService.MarkDirty(player)
	return true
end

function StoryService.TalkToTraveler(player: Player, marker: BasePart): boolean
	if not StoryService.CanInteract(player, marker, 14) or StoryService.RegionOf(player) ~= "ilha_sol_partido" then return false end
	local profile, _chapter, act = current(player)
	if not profile then return false end
	if (act and act.Id == "o_viajante") or profile.story.flags.viajante_conhecido or (profile.story.chapter == "cap1" and profile.story.act > 19) then
		StoryService.SetFlag(player, "viajante_conhecido")
		StoryService.Say(player, "Este lugar não existe de onde eu vim. Atravessei uma ruptura por acidente e apareci aqui. Não foi só um pedaço do meu mundo: eu também atravessei.", "O Viajante")
		-- Preserva a fala do viajante antes de apresentar o próximo ato.
		if act and act.Id == "o_viajante" then
			profile.story.counters.fx_viajante = 1
			finishAct(player, profile, act, true)
			local _p, _c, nextAct = current(player)
			task.delay(6, function() introduce(player, nextAct) end)
		elseif not profile.story.completed.o_viajante then
			profile.story.completed.o_viajante = true
			DataService.MarkDirty(player)
		end
		return true
	end
	StoryService.Say(player, "Ainda estou tentando entender como cheguei aqui.", "O Viajante")
	return false
end

function StoryService.HasCompleted(player: Player, actId: string): boolean
	local profile = DataService.GetProfile(player)
	return profile ~= nil and profile.story.completed[actId] == true
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
	Remotes.GetEvent(Remotes.Events.RequestStoryState).OnServerEvent:Connect(function(player)
		if not choiceLimiter:Allow(player) then return end
		push(player)
		local _profile, _chapter, act = current(player)
		offerChoice(player, act)
		if _profile and _profile.story.chapter == "cap1" and _profile.story.act > 3 and _profile.build.route == "" then
			local routeAct = table.clone(StoryConfig.Chapters[1].Acts[3])
			routeAct.Objectives = {}
			offerChoice(player, routeAct)
		end
	end)
	Remotes.GetEvent(Remotes.Events.RequestStoryChoice).OnServerEvent:Connect(function(player, choiceId, optionId)
		if choiceLimiter:Allow(player) then StoryService.Choose(player, choiceId, optionId) end
	end)
end

function StoryService.Start()
	DataService.ProfileLoaded.Event:Connect(function(player: Player)
		-- subiu de nível: atualiza a dica e avisa quando o ato travado liberou
		local lastLevel = (DataService.GetProfile(player) or { level = 1 }).level
		player:GetAttributeChangedSignal("Level"):Connect(function()
			local profile, _c, act = current(player)
			if not profile then return end
			if act and act.MinLevel and lastLevel < act.MinLevel and profile.level >= act.MinLevel then
				notifyQuest:FireClient(player, "toast", { title = "Você está pronto", text = ("Missão %s · %s"):format(act.Mission or "", act.Title) })
			end
			lastLevel = profile.level
			push(player)
		end)
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
				if _p and act and root and root:IsA("BasePart") then
					for _, objective in act.Objectives do
						local placeId = objective.Kind:match("^reach_(.+)$")
						local place = placeId and StoryConfig.Places[placeId]
						if place and (_p.story.counters[objective.Kind] or 0) < objective.Goal and (root.Position - place.Position).Magnitude <= place.Radius then
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
		if typeof(kind) ~= "string" then return end
		local reward = ProgressionConfig.Npcs[kind]
		if reward and reward.Boss then
			for _, participant in HealthService.PveParticipants(victim :: Model) do
				if kind == "fx_mare_colapso_boss" then
					local key = victim:GetAttribute("StoryObjectiveKey")
					if key == "mare_colapso_1" or key == "mare_colapso_2" then StoryService.ProgressOnce(participant, kind, key) end
				else
					StoryService.Progress(participant, kind, 1)
				end
			end
		elseif player then
			StoryService.Progress(player, kind, 1)
		end
	end)
	for _, player in Players:GetPlayers() do apply(player) end
end

return StoryService
