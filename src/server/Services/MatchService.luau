--!strict
--[[
	MatchService (servidor)
	Máquina de estados do round:
	  Waiting -> Selecting -> InProgress -> Ending -> Waiting ...
	Usa LobbyService (fila), ArenaService (mapa/spawns) e HealthService (sinal Died,
	respawn). Não toca em CombatService/AbilityService: o "contrato" é via atributos
	do Player (CanFight, InMatch, TeamId) descritos em MatchConfig.

	Vitória: só um time com jogadores vivos. Tempo esgotado: time com mais kills.
	Estado é transmitido por NotifyMatchState(state, data) a todos.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local MatchConfig = require(Modules:WaitForChild("MatchConfig"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local LobbyService = require(script.Parent:WaitForChild("LobbyService"))
local ArenaService = require(script.Parent:WaitForChild("ArenaService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))

local MatchService = {}

type Participant = {
	player: Player,
	teamId: number,
	alive: boolean,
	kills: number,
}

type Round = {
	participants: { Participant },
	byPlayer: { [Player]: Participant },
	endsAt: number, -- os.clock()
	mapName: string,
	finished: boolean,
	winnerTeam: number?,
}

local state = "Waiting"
local round: Round? = nil
local notifyMatchState: RemoteEvent

-- ---------------------------------------------------------------------------
-- Broadcast
-- ---------------------------------------------------------------------------

local function serverTimeIn(seconds: number): number
	return Workspace:GetServerTimeNow() + seconds
end

local function setState(newState: string, data: { [string]: any })
	state = newState
	data.state = newState
	Log.debug(("[MatchService] -> %s"):format(newState))
	notifyMatchState:FireAllClients(newState, data)
end

function MatchService.GetState(): string
	return state
end

-- ---------------------------------------------------------------------------
-- Times e vitória
-- ---------------------------------------------------------------------------

local function assignTeams(players: { Player }, teamSize: number): { Participant }
	local shuffled = table.clone(players)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	local participants = {}
	for i, player in shuffled do
		local teamId = if teamSize <= 0 then i else math.ceil(i / teamSize)
		table.insert(participants, { player = player, teamId = teamId, alive = true, kills = 0 })
	end
	return participants
end

local function aliveTeams(r: Round): { [number]: number }
	local teams: { [number]: number } = {}
	for _, p in r.participants do
		if p.alive then
			teams[p.teamId] = (teams[p.teamId] or 0) + 1
		end
	end
	return teams
end

local function countAlive(r: Round): number
	local n = 0
	for _, p in r.participants do
		if p.alive then
			n += 1
		end
	end
	return n
end

--- Retorna o time vencedor (ou nil se ainda não acabou). -1 = empate.
local function checkWinner(r: Round, timedOut: boolean): number?
	local teams = aliveTeams(r)
	local remaining = 0
	local lastTeam: number? = nil
	for teamId in teams do
		remaining += 1
		lastTeam = teamId
	end
	if remaining <= 1 then
		return lastTeam or -1
	end
	if timedOut then
		local killsByTeam: { [number]: number } = {}
		for _, p in r.participants do
			killsByTeam[p.teamId] = (killsByTeam[p.teamId] or 0) + p.kills
		end
		local best, bestTeam, tie = -1, -1, false
		for teamId, kills in killsByTeam do
			if kills > best then
				best, bestTeam, tie = kills, teamId, false
			elseif kills == best then
				tie = true
			end
		end
		return if tie then -1 else bestTeam
	end
	return nil
end

--- Placar serializável para a HUD: { {name, kills, alive, teamId}, ... }
local function scoresData(r: Round): { { [string]: any } }
	local out = {}
	for _, p in r.participants do
		table.insert(out, { name = p.player.Name, kills = p.kills, alive = p.alive, teamId = p.teamId })
	end
	table.sort(out, function(a, b)
		if a.kills ~= b.kills then
			return a.kills > b.kills
		end
		return a.name < b.name
	end)
	return out
end

local function winnerNames(r: Round, teamId: number?): { string }
	local names = {}
	if not teamId or teamId < 0 then
		return names
	end
	for _, p in r.participants do
		if p.teamId == teamId then
			table.insert(names, p.player.Name)
		end
	end
	return names
end

-- ---------------------------------------------------------------------------
-- Eventos
-- ---------------------------------------------------------------------------

local function eliminate(participant: Participant, killer: Player?)
	if not participant.alive then
		return
	end
	participant.alive = false
	participant.player:SetAttribute("CanFight", false)
	if round and killer then
		local kp = round.byPlayer[killer]
		if kp and kp.teamId ~= participant.teamId then
			kp.kills += 1
		end
	end
	if round then
		notifyMatchState:FireAllClients("InProgress", {
			state = "InProgress",
			endsAt = serverTimeIn(round.endsAt - os.clock()),
			mapName = round.mapName,
			alive = countAlive(round),
			scores = scoresData(round),
			eliminated = participant.player.Name,
		})
	end
end

local function onDied(victim: Player, killer: Player?)
	if MatchConfig.FreeRoam then
		DataService.RecordDeath(victim)
		victim:SetAttribute("SessionDeaths", ((victim:GetAttribute("SessionDeaths") :: number?) or 0) + 1)
		if killer and killer ~= victim then
			DataService.RecordKill(killer)
			killer:SetAttribute("SessionKills", ((killer:GetAttribute("SessionKills") :: number?) or 0) + 1)
		end
		return
	end
	if state ~= "InProgress" or not round then
		return
	end
	local participant = round.byPlayer[victim]
	if participant then
		eliminate(participant, killer)
	end
end

local function onPlayerRemoving(player: Player)
	if round then
		local participant = round.byPlayer[player]
		if participant then
			eliminate(participant, nil)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Fases
-- ---------------------------------------------------------------------------

local function spawnParticipant(participant: Participant, cf: CFrame)
	local player = participant.player
	player:SetAttribute("InMatch", true)
	player:SetAttribute("TeamId", participant.teamId)
	player:SetAttribute("CanFight", true)
	player:LoadCharacter() -- reseta vida/energia/cooldowns (services escutam CharacterAdded)
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 5)
	task.wait() -- deixa o spawn padrão assentar antes de mover
	AntiExploitService.Grace(player, 2)
	character:PivotTo(cf)
end

local function waitingPhase()
	local mode = MatchConfig.GetMode()
	setState("Waiting", { needed = mode.MinPlayers, queued = LobbyService.GetQueueCount() })
	while LobbyService.GetQueueCount() < mode.MinPlayers do
		task.wait(1)
	end
end

--- Retorna false se a fila esvaziou durante a seleção.
local function selectingPhase(): boolean
	local mode = MatchConfig.GetMode()
	local endsAt = os.clock() + MatchConfig.SelectTime
	setState("Selecting", { endsAt = serverTimeIn(MatchConfig.SelectTime), queued = LobbyService.GetQueueCount() })
	while os.clock() < endsAt do
		task.wait(0.5)
		if LobbyService.GetQueueCount() < mode.MinPlayers then
			return false
		end
	end
	return true
end

local function startRound(players: { Player }): Round?
	local mode = MatchConfig.GetMode()
	local map = ArenaService.LoadNextMap()
	if not map then
		return nil
	end
	local participants = assignTeams(players, mode.TeamSize)
	local r: Round = {
		participants = participants,
		byPlayer = {},
		endsAt = os.clock() + MatchConfig.RoundTime,
		mapName = ArenaService.GetCurrentMapName() or "?",
		finished = false,
		winnerTeam = nil,
	}
	for _, p in participants do
		r.byPlayer[p.player] = p
	end
	round = r

	local spawns = ArenaService.AllocateSpawns(#participants)
	for i, p in participants do
		task.spawn(spawnParticipant, p, spawns[i] or CFrame.new(0, 10, 0))
	end
	task.wait(0.5)

	setState("InProgress", {
		endsAt = serverTimeIn(MatchConfig.RoundTime),
		mapName = r.mapName,
		alive = countAlive(r),
		scores = scoresData(r),
		mode = MatchConfig.Mode,
	})
	return r
end

local function inProgressPhase(r: Round)
	while true do
		local timedOut = os.clock() >= r.endsAt
		local winner = checkWinner(r, timedOut)
		if winner ~= nil then
			r.winnerTeam = winner
			r.finished = true
			return
		end
		task.wait(0.25)
	end
end

local function endingPhase(r: Round)
	for _, p in r.participants do
		p.player:SetAttribute("CanFight", false)
	end
	local names = winnerNames(r, r.winnerTeam)
	for _, p in r.participants do
		if p.player.Parent == Players then
			local won = r.winnerTeam ~= nil and r.winnerTeam >= 0 and p.teamId == r.winnerTeam
			DataService.RecordMatchResult(p.player, won, p.kills, not p.alive)
		end
	end
	Log.debug(("[MatchService] fim do round: %s"):format(if #names > 0 then table.concat(names, ", ") else "empate"))
	setState("Ending", { winners = names, endsAt = serverTimeIn(MatchConfig.EndTime), mapName = r.mapName, scores = scoresData(r) })
	task.wait(MatchConfig.EndTime)

	for _, p in r.participants do
		if p.player.Parent == Players then
			LobbyService.SendToLobby(p.player, true)
			-- quem morreu já renasceu no lobby sozinho; só recarrega quem ainda está na arena
			if p.alive then
				p.player:LoadCharacter()
			end
		end
	end
	round = nil
	ArenaService.Unload()
end

local function loop()
	while true do
		waitingPhase()
		if not selectingPhase() then
			continue
		end
		local mode = MatchConfig.GetMode()
		local players = LobbyService.TakeFromQueue(mode.MaxPlayers)
		if #players < mode.MinPlayers then
			for _, p in players do
				LobbyService.SendToLobby(p, true)
			end
			continue
		end
		local r = startRound(players)
		if not r then
			warn("[MatchService] não foi possível iniciar o round (sem mapa?)")
			for _, p in players do
				LobbyService.SendToLobby(p, true)
			end
			task.wait(5)
			continue
		end
		inProgressPhase(r)
		endingPhase(r)
	end
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function MatchService.Init()
	notifyMatchState = Remotes.GetEvent(Remotes.Events.NotifyMatchState)
end

function MatchService.Start()
	HealthService.Died.Event:Connect(onDied)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	if MatchConfig.FreeRoam then
		state = "FreeRoam"
		local function onPlayer(player: Player)
			player:SetAttribute("SessionKills", 0)
			player:SetAttribute("SessionDeaths", 0)
			task.wait(1)
			notifyMatchState:FireClient(player, "FreeRoam", { state = "FreeRoam" })
		end
		Players.PlayerAdded:Connect(onPlayer)
		for _, p in Players:GetPlayers() do
			task.spawn(onPlayer, p)
		end
		Log.info("[MatchService] modo MAPA LIVRE (sem rounds)")
		return
	end

	-- jogador que entra no meio recebe o estado atual
	Players.PlayerAdded:Connect(function(player)
		task.wait(1)
		if round and state == "InProgress" then
			notifyMatchState:FireClient(player, state, {
				state = state,
				endsAt = serverTimeIn(round.endsAt - os.clock()),
				mapName = round.mapName,
				alive = countAlive(round),
				scores = scoresData(round),
			})
		else
			notifyMatchState:FireClient(player, state, { state = state, queued = LobbyService.GetQueueCount() })
		end
	end)
	task.spawn(loop)
end

return MatchService
