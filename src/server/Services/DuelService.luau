--!strict
--[[
	DuelService (servidor)
	Duelos opt-in dentro do mapa livre. Não mexe no MatchService (loop de rounds):
	cada duelo é uma cópia de ServerStorage.Maps[DuelConfig.MapName] colocada longe/alto
	do mapa (slot próprio), com os participantes teleportados para lá.

	Convites 1v1: RequestDuel("challenge", userId) -> alvo recebe NotifyDuel("invite") ->
	RequestDuel("accept"/"decline"). Quem desafiou pode "cancel". Em duelo, "leave" = desiste.

	Salas 2v2: "create_room" cria uma sala (dono = primeiro membro); "join_room" (hostUserId)
	entra; "switch_team" troca de time se houver vaga; "leave_room" sai (sala vazia some).
	Com DuelConfig.TeamSize * 2 membros o duelo começa sozinho. A lista de salas vai para
	todo mundo em NotifyDuel("rooms") a cada mudança (e "list_rooms" pede a lista).

	Fim: só um time vivo, tempo esgotado (empate) ou queda da arena. Recompensa via
	DataService.RecordMatchResult (kills/mortes já são contadas pelo MatchService no mapa
	livre, então aqui passamos kills = 0 para não contar duas vezes).

	Contrato via atributos do Player (MatchConfig): InMatch, TeamId, CanFight; mais DuelId.
	A estrutura de times aceita NvN (StartDuel recebe { {time1}, {time2} }).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local DuelConfig = require(Modules:WaitForChild("DuelConfig"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local LobbyService = require(script.Parent:WaitForChild("LobbyService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))

local DuelService = {}

type Participant = {
	player: Player,
	teamId: number,
	alive: boolean,
	left: boolean, -- saiu do servidor: não volta nos próximos rounds
}

type Duel = {
	id: number,
	slot: number,
	map: Model,
	origin: CFrame,
	participants: { Participant },
	byPlayer: { [Player]: Participant },
	startedAt: number, -- os.clock(), quando o combate liberou
	endsAt: number,
	finished: boolean,
	winnerTeam: number?, -- -1 = empate
	round: number, -- round atual (1..MaxRounds)
	wins: { [number]: number }, -- teamId -> rounds vencidos
}

type Invite = {
	from: Player,
	target: Player,
	expiresAt: number,
}

type RoomMember = {
	player: Player,
	teamId: number,
}

type Room = {
	host: Player,
	members: { RoomMember },
	starting: boolean,
}

local DUELS_FOLDER = "Duels"
local requestLimiter = RateLimiter.new(4, 2)

local notifyDuel: RemoteEvent
local duelsFolder: Folder
local invitesByTarget: { [Player]: Invite } = {}
local invitesByFrom: { [Player]: Invite } = {}
local duels: { [number]: Duel } = {}
local duelByPlayer: { [Player]: Duel } = {}
local slotsInUse: { [number]: boolean } = {}
local nextDuelId = 0
local rooms: { [Player]: Room } = {} -- por host
local roomByPlayer: { [Player]: Room } = {}

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

local function serverTimeIn(seconds: number): number
	return Workspace:GetServerTimeNow() + seconds
end

local function notify(player: Player, event: string, data: { [string]: any })
	if player.Parent == Players then
		data.event = event
		notifyDuel:FireClient(player, event, data)
	end
end

local function notifyAll(duel: Duel, event: string, data: { [string]: any })
	for _, p in duel.participants do
		notify(p.player, event, table.clone(data))
	end
end

local function isBusy(player: Player): boolean
	return player:GetAttribute("InMatch") == true or duelByPlayer[player] ~= nil or roomByPlayer[player] ~= nil
end

local function allocateSlot(): number?
	for i = 1, DuelConfig.MaxConcurrent do
		if not slotsInUse[i] then
			slotsInUse[i] = true
			return i
		end
	end
	return nil
end

local function slotOrigin(slot: number): CFrame
	-- grade simples: 4 por linha
	local col = (slot - 1) % 4
	local row = (slot - 1) // 4
	return CFrame.new(DuelConfig.ArenaOrigin + Vector3.new(col * DuelConfig.ArenaSpacing, 0, row * DuelConfig.ArenaSpacing))
end

local function spawnCFrames(map: Model): { CFrame }
	local result: { CFrame } = {}
	local folder = map:FindFirstChild("Spawns")
	if folder then
		local parts: { BasePart } = {}
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
		table.sort(parts, function(a, b)
			return a.Name < b.Name
		end)
		for _, part in parts do
			table.insert(result, CFrame.new(part.Position + Vector3.new(0, 3, 0)))
		end
	end
	if #result == 0 then
		table.insert(result, map:GetPivot() + Vector3.new(0, 3, 0))
	end
	return result
end

local function aliveTeams(duel: Duel): { [number]: number }
	local teams: { [number]: number } = {}
	for _, p in duel.participants do
		if p.alive then
			teams[p.teamId] = (teams[p.teamId] or 0) + 1
		end
	end
	return teams
end

local function winnerNames(duel: Duel, teamId: number?): { string }
	local names = {}
	if not teamId or teamId < 0 then
		return names
	end
	for _, p in duel.participants do
		if p.teamId == teamId then
			table.insert(names, p.player.Name)
		end
	end
	return names
end

local function stateData(duel: Duel): { [string]: any }
	local players = {}
	for _, p in duel.participants do
		table.insert(players, { name = p.player.Name, teamId = p.teamId, alive = p.alive })
	end
	return {
		duelId = duel.id,
		endsAt = serverTimeIn(duel.endsAt - os.clock()),
		players = players,
		round = duel.round,
		wins = { duel.wins[1] or 0, duel.wins[2] or 0 },
		roundsToWin = DuelConfig.RoundsToWin,
	}
end

-- ---------------------------------------------------------------------------
-- Convites
-- ---------------------------------------------------------------------------

local function closeInvite(invite: Invite, reason: string)
	if invitesByTarget[invite.target] ~= invite then
		return
	end
	invitesByTarget[invite.target] = nil
	invitesByFrom[invite.from] = nil
	notify(invite.from, "invite_closed", { reason = reason, other = invite.target.Name })
	notify(invite.target, "invite_closed", { reason = reason, other = invite.from.Name })
end

local function challenge(from: Player, targetUserId: any)
	if typeof(targetUserId) ~= "number" then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == from then
		notify(from, "denied", { reason = "Jogador não encontrado." })
		return
	end
	if isBusy(from) then
		notify(from, "denied", { reason = "Você já está em um duelo." })
		return
	end
	if isBusy(target) then
		notify(from, "denied", { reason = ("%s já está em um duelo."):format(target.Name) })
		return
	end
	if invitesByFrom[from] then
		notify(from, "denied", { reason = "Você já tem um desafio pendente." })
		return
	end
	if invitesByTarget[target] then
		notify(from, "denied", { reason = ("%s já tem um desafio pendente."):format(target.Name) })
		return
	end
	local invite: Invite = { from = from, target = target, expiresAt = os.clock() + DuelConfig.InviteTimeout }
	invitesByTarget[target] = invite
	invitesByFrom[from] = invite
	local expiresAt = serverTimeIn(DuelConfig.InviteTimeout)
	notify(target, "invite", { fromName = from.Name, fromUserId = from.UserId, expiresAt = expiresAt })
	notify(from, "invite_sent", { targetName = target.Name, expiresAt = expiresAt })
	Log.debug(("[DuelService] %s desafiou %s"):format(from.Name, target.Name))
	task.delay(DuelConfig.InviteTimeout, function()
		closeInvite(invite, "expired")
	end)
end

-- ---------------------------------------------------------------------------
-- Salas 2v2
-- ---------------------------------------------------------------------------

local function roomsData(): { [string]: any }
	local out = {}
	for host, room in rooms do
		local members = {}
		for _, m in room.members do
			table.insert(members, { name = m.player.Name, userId = m.player.UserId, teamId = m.teamId })
		end
		table.insert(out, { hostName = host.Name, hostUserId = host.UserId, members = members, size = DuelConfig.TeamSize * 2 })
	end
	table.sort(out, function(a, b)
		return a.hostName < b.hostName
	end)
	return { rooms = out }
end

local function broadcastRooms()
	notifyDuel:FireAllClients("rooms", roomsData())
end

local function teamCount(room: Room, teamId: number): number
	local n = 0
	for _, m in room.members do
		if m.teamId == teamId then
			n += 1
		end
	end
	return n
end

local function removeFromRoom(player: Player, reason: string)
	local room = roomByPlayer[player]
	if not room then
		return
	end
	roomByPlayer[player] = nil
	for i, m in room.members do
		if m.player == player then
			table.remove(room.members, i)
			break
		end
	end
	notify(player, "room_left", { reason = reason })
	if #room.members == 0 then
		rooms[room.host] = nil
	elseif room.host == player then
		rooms[room.host] = nil
		room.host = room.members[1].player
		rooms[room.host] = room
	end
	broadcastRooms()
end

local function addToRoom(room: Room, player: Player)
	-- entra no time com menos gente (empate = time 1)
	local teamId = if teamCount(room, 2) < teamCount(room, 1) then 2 else 1
	table.insert(room.members, { player = player, teamId = teamId })
	roomByPlayer[player] = room
	notify(player, "room_joined", { hostUserId = room.host.UserId })
	broadcastRooms()
end

local function tryStartRoom(room: Room)
	local size = DuelConfig.TeamSize
	if room.starting or #room.members < size * 2 or teamCount(room, 1) ~= size or teamCount(room, 2) ~= size then
		return
	end
	room.starting = true
	local teams: { { Player } } = { {}, {} }
	for _, m in room.members do
		table.insert(teams[m.teamId], m.player)
	end
	-- desfaz a sala antes de iniciar (isBusy passa a ser o duelo)
	rooms[room.host] = nil
	for _, m in room.members do
		roomByPlayer[m.player] = nil
	end
	broadcastRooms()
	local ok, err = DuelService.StartDuel(teams)
	if not ok then
		for _, m in room.members do
			notify(m.player, "denied", { reason = err })
		end
	end
end

local function createRoom(player: Player)
	if isBusy(player) or invitesByFrom[player] or invitesByTarget[player] then
		notify(player, "denied", { reason = "Você já está em um duelo ou desafio." })
		return
	end
	local room: Room = { host = player, members = {}, starting = false }
	rooms[player] = room
	addToRoom(room, player)
	Log.debug(("[DuelService] %s criou uma sala 2v2"):format(player.Name))
end

local function joinRoom(player: Player, hostUserId: any)
	if typeof(hostUserId) ~= "number" then
		return
	end
	local host = Players:GetPlayerByUserId(hostUserId)
	local room = host and rooms[host]
	if not room then
		notify(player, "denied", { reason = "Essa sala não existe mais." })
		return
	end
	if isBusy(player) or invitesByFrom[player] or invitesByTarget[player] then
		notify(player, "denied", { reason = "Você já está em um duelo ou desafio." })
		return
	end
	if #room.members >= DuelConfig.TeamSize * 2 then
		notify(player, "denied", { reason = "A sala está cheia." })
		return
	end
	addToRoom(room, player)
	tryStartRoom(room)
end

local function switchTeam(player: Player)
	local room = roomByPlayer[player]
	if not room or room.starting then
		return
	end
	for _, m in room.members do
		if m.player == player then
			local other = if m.teamId == 1 then 2 else 1
			if teamCount(room, other) >= DuelConfig.TeamSize then
				notify(player, "denied", { reason = "O outro time está cheio." })
				return
			end
			m.teamId = other
			break
		end
	end
	broadcastRooms()
	tryStartRoom(room)
end

-- ---------------------------------------------------------------------------
-- Duelo
-- ---------------------------------------------------------------------------

local function spawnParticipant(duel: Duel, participant: Participant, cf: CFrame)
	local player = participant.player
	player:SetAttribute("InMatch", true)
	player:SetAttribute("TeamId", participant.teamId)
	player:SetAttribute("DuelId", duel.id)
	player:SetAttribute("CanFight", false) -- libera depois da contagem
	CharacterService.Load(player) -- reseta vida/energia/cooldowns (services escutam CharacterAdded)
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 5)
	task.wait()
	AntiExploitService.Grace(player, 3)
	character:PivotTo(cf)
end

--- Devolve o jogador ao mapa livre (atributos + respawn se ainda estiver na arena).
local function returnToWorld(player: Player, reloadCharacter: boolean)
	duelByPlayer[player] = nil
	player:SetAttribute("DuelId", nil)
	if player.Parent ~= Players then
		return
	end
	LobbyService.SendToLobby(player, false)
	if reloadCharacter then
		AntiExploitService.Grace(player, 3)
		CharacterService.Load(player)
	end
end

local function eliminate(duel: Duel, participant: Participant, reason: string)
	if not participant.alive or duel.finished then
		return
	end
	participant.alive = false
	participant.player:SetAttribute("CanFight", false)
	local data = stateData(duel)
	data.eliminated = participant.player.Name
	data.reason = reason
	notifyAll(duel, "state", data)
end

local function checkWinner(duel: Duel, timedOut: boolean): number?
	local teams = aliveTeams(duel)
	local remaining, lastTeam = 0, nil
	for teamId in teams do
		remaining += 1
		lastTeam = teamId
	end
	if remaining <= 1 then
		return lastTeam or -1
	end
	if timedOut then
		return -1
	end
	return nil
end

local function finishDuel(duel: Duel)
	duel.finished = true
	duels[duel.id] = nil
	for _, p in duel.participants do
		p.player:SetAttribute("CanFight", false)
	end
	local names = winnerNames(duel, duel.winnerTeam)
	-- Elo (só 1v1 com vencedor): winner +K(1-E), loser -K·E
	local ratingDelta: { [Player]: number } = {}
	if #duel.participants == 2 and duel.winnerTeam and duel.winnerTeam >= 0 then
		local a, b = duel.participants[1], duel.participants[2]
		local pa, pb = DataService.GetProfile(a.player), DataService.GetProfile(b.player)
		if pa and pb then
			local ra, rb = pa.rating or DuelConfig.RatingStart, pb.rating or DuelConfig.RatingStart
			local ea = 1 / (1 + 10 ^ ((rb - ra) / 400))
			local sa = if a.teamId == duel.winnerTeam then 1 else 0
			local da = math.floor(DuelConfig.RatingK * (sa - ea) + 0.5)
			pa.rating = math.max(0, ra + da)
			pb.rating = math.max(0, rb - da)
			ratingDelta[a.player] = da
			ratingDelta[b.player] = -da
			DataService.MarkDirty(a.player)
			DataService.MarkDirty(b.player)
		end
	end
	for _, p in duel.participants do
		if p.player.Parent == Players then
			local won = duel.winnerTeam ~= nil and duel.winnerTeam >= 0 and p.teamId == duel.winnerTeam
			DataService.RecordMatchResult(p.player, won, 0, false)
			ProgressionService.OnDuelResult(p.player, won)
			local delta = ratingDelta[p.player]
			if delta then
				local profile = DataService.GetProfile(p.player)
				notify(p.player, "rating", { delta = delta, rating = if profile then profile.rating else 0 })
			end
		end
	end
	Log.debug(("[DuelService] duelo %d: %s (%d x %d)"):format(duel.id, if #names > 0 then "venceu " .. table.concat(names, ", ") else "empate", duel.wins[1] or 0, duel.wins[2] or 0))
	notifyAll(duel, "end", { winners = names, endsAt = serverTimeIn(DuelConfig.EndTime), wins = { duel.wins[1] or 0, duel.wins[2] or 0 } })
	task.wait(DuelConfig.EndTime)
	for _, p in duel.participants do
		-- quem morreu já renasceu no mapa livre; quem ainda está na arena recarrega
		returnToWorld(p.player, p.alive)
	end
	duel.map:Destroy()
	slotsInUse[duel.slot] = nil
end

--- Um round: contagem, combate, vencedor do round (teamId ou -1 = empate). nil se o duelo acabou antes.
local function runRound(duel: Duel): number?
	notifyAll(duel, "start", { countdown = DuelConfig.Countdown, endsAt = serverTimeIn(DuelConfig.Countdown), players = stateData(duel).players, round = duel.round, wins = { duel.wins[1] or 0, duel.wins[2] or 0 }, roundsToWin = DuelConfig.RoundsToWin })
	task.wait(DuelConfig.Countdown)
	if duel.finished then
		return nil
	end
	duel.startedAt = os.clock()
	duel.endsAt = duel.startedAt + DuelConfig.RoundTime
	for _, p in duel.participants do
		if p.alive and p.player.Parent == Players then
			p.player:SetAttribute("CanFight", true)
		end
	end
	notifyAll(duel, "state", stateData(duel))

	local floorY = duel.origin.Position.Y - DuelConfig.FallDepth
	while not duel.finished do
		-- caiu da arena = eliminado
		for _, p in duel.participants do
			if p.alive then
				local root = p.player.Character and p.player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and root.Position.Y < floorY then
					eliminate(duel, p, "fell")
					if p.player.Character then
						HealthService.Kill(p.player.Character)
					end
				end
			end
		end
		local winner = checkWinner(duel, os.clock() >= duel.endsAt)
		if winner ~= nil then
			return winner
		end
		task.wait(0.25)
	end
	return nil
end

--- Time com mais rounds vencidos (-1 = empate).
local function seriesLeader(duel: Duel): number
	local w1, w2 = duel.wins[1] or 0, duel.wins[2] or 0
	if w1 == w2 then
		return -1
	end
	return if w1 > w2 then 1 else 2
end

local function runDuel(duel: Duel)
	local spawns = spawnCFrames(duel.map)
	local half = math.max(1, #spawns // 2)
	while not duel.finished do
		duel.round += 1
		if duel.round > 1 then
			-- Round novo: todo mundo que ainda está no servidor volta para a arena, vivo
			local used: { [number]: number } = {}
			for _, p in duel.participants do
				if not p.left and p.player.Parent == Players then
					p.alive = true
					local base = if p.teamId == 1 then 1 else half + 1
					local k = (used[p.teamId] or 0)
					used[p.teamId] = k + 1
					task.spawn(spawnParticipant, duel, p, spawns[((base - 1 + k) % #spawns) + 1])
				end
			end
			task.wait(0.5)
		end
		local roundWinner = runRound(duel)
		if roundWinner == nil then
			return
		end
		if roundWinner >= 0 then
			duel.wins[roundWinner] = (duel.wins[roundWinner] or 0) + 1
		end
		for _, p in duel.participants do
			p.player:SetAttribute("CanFight", false)
		end
		local w1, w2 = duel.wins[1] or 0, duel.wins[2] or 0
		local seriesOver = w1 >= DuelConfig.RoundsToWin or w2 >= DuelConfig.RoundsToWin or duel.round >= DuelConfig.MaxRounds
		notifyAll(duel, "round_end", {
			round = duel.round,
			roundWinners = winnerNames(duel, roundWinner),
			wins = { w1, w2 },
			roundsToWin = DuelConfig.RoundsToWin,
			seriesOver = seriesOver,
			endsAt = serverTimeIn(DuelConfig.BetweenRounds),
		})
		if seriesOver then
			duel.winnerTeam = seriesLeader(duel)
			finishDuel(duel)
			return
		end
		task.wait(DuelConfig.BetweenRounds)
	end
end

--- Inicia um duelo entre times (cada entrada = lista de Players). Retorna false se não deu.
function DuelService.StartDuel(teams: { { Player } }): (boolean, string)
	local template = ServerStorage:FindFirstChild("Maps") and ServerStorage.Maps:FindFirstChild(DuelConfig.MapName)
	if not template or not template:IsA("Model") then
		return false, ("mapa %s não existe em ServerStorage.Maps"):format(DuelConfig.MapName)
	end
	local slot = allocateSlot()
	if not slot then
		return false, "todas as arenas estão ocupadas, tente de novo em instantes"
	end

	nextDuelId += 1
	local map = template:Clone()
	map.Name = ("Duel_%d"):format(nextDuelId)
	for _, d in map:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d.Enabled = false -- ninguém deve renascer aqui
		end
	end
	local origin = slotOrigin(slot)
	map:PivotTo(origin)
	map.Parent = duelsFolder

	local duel: Duel = {
		id = nextDuelId,
		slot = slot,
		map = map,
		origin = origin,
		participants = {},
		byPlayer = {},
		startedAt = 0,
		endsAt = os.clock() + DuelConfig.Countdown + DuelConfig.RoundTime,
		finished = false,
		winnerTeam = nil,
		round = 0,
		wins = {},
	}
	for teamId, members in teams do
		for _, player in members do
			local participant: Participant = { player = player, teamId = teamId, alive = true, left = false }
			table.insert(duel.participants, participant)
			duel.byPlayer[player] = participant
			duelByPlayer[player] = duel
		end
	end
	duels[duel.id] = duel

	local spawns = spawnCFrames(map)
	-- times em spawns opostos: time 1 nos primeiros, time 2 a partir da metade
	local half = math.max(1, #spawns // 2)
	local used: { [number]: number } = {}
	for _, p in duel.participants do
		local base = if p.teamId == 1 then 1 else half + 1
		local k = (used[p.teamId] or 0)
		used[p.teamId] = k + 1
		local cf = spawns[((base - 1 + k) % #spawns) + 1]
		task.spawn(spawnParticipant, duel, p, cf)
	end
	task.wait(0.5)
	task.spawn(runDuel, duel)
	return true, "ok"
end

-- ---------------------------------------------------------------------------
-- Requests
-- ---------------------------------------------------------------------------

local function onRequest(player: Player, action: any, targetUserId: any)
	if not requestLimiter:Allow(player) or typeof(action) ~= "string" then
		return
	end
	if action == "challenge" then
		challenge(player, targetUserId)
	elseif action == "accept" then
		local invite = invitesByTarget[player]
		if not invite then
			return
		end
		local from = invite.from
		invitesByTarget[player] = nil
		invitesByFrom[from] = nil
		if from.Parent ~= Players or isBusy(from) or isBusy(player) then
			notify(player, "invite_closed", { reason = "unavailable", other = from.Name })
			notify(from, "invite_closed", { reason = "unavailable", other = player.Name })
			return
		end
		local ok, err = DuelService.StartDuel({ { from }, { player } })
		if not ok then
			notify(player, "denied", { reason = err })
			notify(from, "denied", { reason = err })
		end
	elseif action == "decline" then
		local invite = invitesByTarget[player]
		if invite then
			closeInvite(invite, "declined")
		end
	elseif action == "cancel" then
		local invite = invitesByFrom[player]
		if invite then
			closeInvite(invite, "cancelled")
		end
	elseif action == "create_room" then
		createRoom(player)
	elseif action == "join_room" then
		joinRoom(player, targetUserId)
	elseif action == "switch_team" then
		switchTeam(player)
	elseif action == "leave_room" then
		removeFromRoom(player, "left")
	elseif action == "list_rooms" then
		notify(player, "rooms", roomsData())
	elseif action == "leave" then
		local duel = duelByPlayer[player]
		local participant = duel and duel.byPlayer[player]
		if duel and participant and participant.alive then
			eliminate(duel, participant, "left")
			if player.Character then
				HealthService.Kill(player.Character)
			end
		end
	end
end

local function onDied(victim: Player, killer: Player?)
	local duel = duelByPlayer[victim]
	local participant = duel and duel.byPlayer[victim]
	if duel and participant then
		eliminate(duel, participant, "died")
		-- Melhor de 3: continua no duelo. O respawn automático cai no mapa (CanFight=false) e o
		-- próximo round traz de volta; se a série acabou, finishDuel devolve ao mapa livre.
	end
end

local function onPlayerRemoving(player: Player)
	local invite = invitesByTarget[player] or invitesByFrom[player]
	if invite then
		closeInvite(invite, "unavailable")
	end
	removeFromRoom(player, "unavailable")
	local duel = duelByPlayer[player]
	local participant = duel and duel.byPlayer[player]
	if duel and participant then
		participant.left = true
		eliminate(duel, participant, "left")
		duelByPlayer[player] = nil
	end
end

--- Duelo do jogador (ou nil). Usado por outros services/admin.
function DuelService.GetDuelId(player: Player): number?
	local duel = duelByPlayer[player]
	return if duel then duel.id else nil
end

function DuelService.Init()
	notifyDuel = Remotes.GetEvent(Remotes.Events.NotifyDuel)
	local existing = Workspace:FindFirstChild(DUELS_FOLDER)
	if existing then
		existing:Destroy()
	end
	duelsFolder = Instance.new("Folder")
	duelsFolder.Name = DUELS_FOLDER
	duelsFolder.Parent = Workspace
end

function DuelService.Start()
	Remotes.GetEvent(Remotes.Events.RequestDuel).OnServerEvent:Connect(onRequest)
	HealthService.Died.Event:Connect(onDied)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Log.debug(("[DuelService] pronto (mapa %s, até %d arenas)"):format(DuelConfig.MapName, DuelConfig.MaxConcurrent))
end

return DuelService
