--!strict
--[[
	DuelService (servidor)
	Duelos opt-in dentro do mapa livre. Não mexe no MatchService (loop de rounds):
	cada duelo é uma cópia de ServerStorage.Maps[DuelConfig.MapName] colocada longe/alto
	do mapa (slot próprio), com os participantes teleportados para lá.

	Convites: RequestDuel("challenge", userId) -> alvo recebe NotifyDuel("invite") ->
	RequestDuel("accept"/"decline"). Quem desafiou pode "cancel". Em duelo, "leave" = desiste.

	Fim: só um time vivo, tempo esgotado (empate) ou queda da arena. Recompensa via
	DataService.RecordMatchResult (kills/mortes já são contadas pelo MatchService no mapa
	livre, então aqui passamos kills = 0 para não contar duas vezes).

	Contrato via atributos do Player (MatchConfig): InMatch, TeamId, CanFight; mais DuelId.
	A estrutura de times já aceita NvN; hoje o fluxo de convite só monta 1v1.
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
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local LobbyService = require(script.Parent:WaitForChild("LobbyService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))

local DuelService = {}

type Participant = {
	player: Player,
	teamId: number,
	alive: boolean,
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
}

type Invite = {
	from: Player,
	target: Player,
	expiresAt: number,
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
	return player:GetAttribute("InMatch") == true or duelByPlayer[player] ~= nil
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
-- Duelo
-- ---------------------------------------------------------------------------

local function spawnParticipant(duel: Duel, participant: Participant, cf: CFrame)
	local player = participant.player
	player:SetAttribute("InMatch", true)
	player:SetAttribute("TeamId", participant.teamId)
	player:SetAttribute("DuelId", duel.id)
	player:SetAttribute("CanFight", false) -- libera depois da contagem
	player:LoadCharacter() -- reseta vida/energia/cooldowns (services escutam CharacterAdded)
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
		player:LoadCharacter()
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
	for _, p in duel.participants do
		if p.player.Parent == Players then
			local won = duel.winnerTeam ~= nil and duel.winnerTeam >= 0 and p.teamId == duel.winnerTeam
			DataService.RecordMatchResult(p.player, won, 0, false)
		end
	end
	Log.debug(("[DuelService] duelo %d: %s"):format(duel.id, if #names > 0 then "venceu " .. table.concat(names, ", ") else "empate"))
	notifyAll(duel, "end", { winners = names, endsAt = serverTimeIn(DuelConfig.EndTime) })
	task.wait(DuelConfig.EndTime)
	for _, p in duel.participants do
		-- quem morreu já renasceu no mapa livre; quem ainda está na arena recarrega
		returnToWorld(p.player, p.alive)
	end
	duel.map:Destroy()
	slotsInUse[duel.slot] = nil
end

local function runDuel(duel: Duel)
	-- contagem
	notifyAll(duel, "start", { countdown = DuelConfig.Countdown, endsAt = serverTimeIn(DuelConfig.Countdown), players = stateData(duel).players })
	task.wait(DuelConfig.Countdown)
	if duel.finished then
		return
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
			duel.winnerTeam = winner
			finishDuel(duel)
			return
		end
		task.wait(0.25)
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
	}
	for teamId, members in teams do
		for _, player in members do
			local participant: Participant = { player = player, teamId = teamId, alive = true }
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
		-- o respawn automático vai para o mapa livre; solta os atributos já
		returnToWorld(victim, false)
	end
end

local function onPlayerRemoving(player: Player)
	local invite = invitesByTarget[player] or invitesByFrom[player]
	if invite then
		closeInvite(invite, "unavailable")
	end
	local duel = duelByPlayer[player]
	local participant = duel and duel.byPlayer[player]
	if duel and participant then
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
