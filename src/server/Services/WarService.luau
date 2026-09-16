--!strict
--[[
	WarService (servidor)
	Guerra de clã = DOMINAÇÃO (WarConfig). Dois clãs numa cópia de ServerStorage.Maps[MapName] no céu
	(mesmo esquema do DuelService, região própria): pontos A/B/C (pasta CapturePoints) mudam de dono
	quando só um time fica dentro por CaptureSeconds; ponto dominado rende PointsPerSecond. Acaba por
	ScoreToWin, tempo (mais pontos ganha; empate possível) ou quando um lado fica sem ninguém.

	Fila: RequestWar("queue") por líder/oficial põe o clã com os membros online (não ocupados) na fila;
	com dois clãs, começa. Morreu = renasce no spawn do time (Player.RespawnLocation na arena) com
	RespawnProtection s sem CanFight.

	Contrato de atributos (MatchConfig): InMatch, TeamId (1/2), CanFight; mais WarId.
	Recompensas: pontos por jogador + cofre do clã (ClanService.AddToVault) + clan.wins.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local WarConfig = require(Modules:WaitForChild("WarConfig"))
local ClanConfig = require(Modules:WaitForChild("ClanConfig"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local LobbyService = require(script.Parent:WaitForChild("LobbyService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AntiExploitService = require(script.Parent:WaitForChild("AntiExploitService"))
local ClanService = require(script.Parent:WaitForChild("ClanService"))
local DuelService = require(script.Parent:WaitForChild("DuelService"))

local WarService = {}

type Participant = { player: Player, teamId: number, left: boolean }
type Zone = { name: string, part: BasePart, owner: number, progressTeam: number, progress: number }
type War = {
	id: number,
	slot: number,
	map: Model,
	tags: { string }, -- [teamId] = tag
	names: { string },
	participants: { Participant },
	byPlayer: { [Player]: Participant },
	zones: { Zone },
	scores: { number },
	spawns: { SpawnLocation }, -- [teamId]
	endsAt: number,
	finished: boolean,
	winnerTeam: number?,
}
type QueueEntry = { tag: string, name: string, by: Player, members: { Player } }

local WARS_FOLDER = "Wars"
local warsFolder: Folder
local notifyWar: RemoteEvent
local wars: { [number]: War } = {}
local warByPlayer: { [Player]: War } = {}
local queue: { QueueEntry } = {}
local slotsInUse: { [number]: boolean } = {}
local nextWarId = 0
local requestLimiter = RateLimiter.new(4, 2)

-- ---------------------------------------------------------------------------
-- Util
-- ---------------------------------------------------------------------------

local function notify(player: Player, event: string, data: { [string]: any })
	if player.Parent == Players then
		data.event = event
		notifyWar:FireClient(player, event, data)
	end
end

local function notifyAll(war: War, event: string, data: { [string]: any })
	for _, p in war.participants do
		notify(p.player, event, table.clone(data))
	end
end

local function isBusy(player: Player): boolean
	return player:GetAttribute("InMatch") == true or warByPlayer[player] ~= nil or DuelService.GetDuelId(player) ~= nil
end

local function allocateSlot(): number?
	for i = 1, WarConfig.MaxConcurrent do
		if not slotsInUse[i] then
			slotsInUse[i] = true
			return i
		end
	end
	return nil
end

local function slotOrigin(slot: number): CFrame
	return CFrame.new(WarConfig.ArenaOrigin + Vector3.new((slot - 1) * WarConfig.ArenaSpacing, 0, 0))
end

local function stateData(war: War): { [string]: any }
	local zones = {}
	for _, z in war.zones do
		table.insert(zones, { name = z.name, owner = z.owner, progressTeam = z.progressTeam, progress = z.progress })
	end
	return {
		id = war.id,
		tags = war.tags,
		names = war.names,
		scores = war.scores,
		zones = zones,
		endsAtServerTime = Workspace:GetServerTimeNow() + math.max(0, war.endsAt - os.clock()),
		scoreToWin = WarConfig.ScoreToWin,
	}
end

local function queueEntryOf(tag: string): (QueueEntry?, number?)
	for i, e in queue do
		if e.tag == tag then
			return e, i
		end
	end
	return nil, nil
end

-- ---------------------------------------------------------------------------
-- Arena
-- ---------------------------------------------------------------------------

local function zoneColor(teamId: number): Color3
	return WarConfig.TeamColors[teamId] or WarConfig.NeutralColor
end

local function findZones(map: Model): { Zone }
	local zones: { Zone } = {}
	local folder = map:FindFirstChild("CapturePoints")
	if folder then
		local parts: { BasePart } = {}
		for _, c in folder:GetChildren() do
			if c:IsA("BasePart") then
				table.insert(parts, c)
			end
		end
		table.sort(parts, function(a, b)
			return a.Name < b.Name
		end)
		for _, p in parts do
			p.Color = WarConfig.NeutralColor
			table.insert(zones, { name = p.Name, part = p, owner = 0, progressTeam = 0, progress = 0 })
		end
	end
	return zones
end

local function teamSpawnCFrames(map: Model): { CFrame }
	local result: { CFrame } = {}
	local folder = map:FindFirstChild("Spawns")
	if folder then
		local parts: { BasePart } = {}
		for _, c in folder:GetChildren() do
			if c:IsA("BasePart") then
				table.insert(parts, c)
			end
		end
		table.sort(parts, function(a, b)
			return a.Name < b.Name
		end)
		-- time 1 = primeiro spawn, time 2 = o mais distante dele
		if #parts >= 2 then
			local first = parts[1]
			local far, farDist = parts[2], 0
			for _, p in parts do
				local d = (p.Position - first.Position).Magnitude
				if d > farDist then
					far, farDist = p, d
				end
			end
			result = { first.CFrame, far.CFrame }
		elseif #parts == 1 then
			result = { parts[1].CFrame, parts[1].CFrame }
		end
	end
	if #result == 0 then
		local pivot = map:GetPivot()
		result = { pivot * CFrame.new(-80, 3, 0), pivot * CFrame.new(80, 3, 0) }
	end
	return result
end

--- SpawnLocation por time: só quem tem Player.RespawnLocation apontando para ela renasce lá
--- (TeamColor exclusiva evita que CharacterService.pickSpawn a sorteie para os outros).
local function makeTeamSpawn(map: Model, cf: CFrame, teamId: number): SpawnLocation
	local s = Instance.new("SpawnLocation")
	s.Name = "WarSpawn" .. teamId
	s.Size = Vector3.new(8, 1, 8)
	s.CFrame = cf
	s.Anchored = true
	s.CanCollide = false
	s.Transparency = 1
	s.Neutral = false
	s.TeamColor = BrickColor.new("Really black")
	s.Duration = 0
	s.Enabled = true
	s.Parent = map
	return s
end

local function spawnParticipant(war: War, participant: Participant)
	local player = participant.player
	player:SetAttribute("InMatch", true)
	player:SetAttribute("TeamId", participant.teamId)
	player:SetAttribute("WarId", war.id)
	player:SetAttribute("CanFight", false)
	player.RespawnLocation = war.spawns[participant.teamId]
	CharacterService.Load(player) -- nasce no RespawnLocation
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 5)
	AntiExploitService.Grace(player, 3)
end

local function returnToWorld(player: Player)
	warByPlayer[player] = nil
	player:SetAttribute("WarId", nil)
	if player.Parent ~= Players then
		return
	end
	(player :: any).RespawnLocation = nil
	LobbyService.SendToLobby(player, false)
	AntiExploitService.Grace(player, 3)
	CharacterService.Load(player)
end

-- ---------------------------------------------------------------------------
-- Loop
-- ---------------------------------------------------------------------------

local function alivePlayersInZone(war: War, zone: Zone): { [number]: number }
	local counts: { [number]: number } = {}
	local center = zone.part.Position
	local r2 = WarConfig.CaptureRadius * WarConfig.CaptureRadius
	for _, p in war.participants do
		local character = p.player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not p.left and root and HealthService.IsAlive(character) and p.player:GetAttribute("CanFight") == true then
			local d = root.Position - center
			if d.X * d.X + d.Z * d.Z <= r2 and math.abs(d.Y) < 20 then
				counts[p.teamId] = (counts[p.teamId] or 0) + 1
			end
		end
	end
	return counts
end

local function tickZones(war: War, dt: number)
	for _, z in war.zones do
		local counts = alivePlayersInZone(war, z)
		local present, only = 0, 0
		for teamId in counts do
			present += 1
			only = teamId
		end
		if present == 1 and only ~= z.owner then
			-- um time sozinho: avança a captura desse time
			if z.progressTeam ~= only then
				z.progressTeam = only
				z.progress = 0
			end
			z.progress = math.min(1, z.progress + dt / WarConfig.CaptureSeconds)
			if z.progress >= 1 then
				z.owner = only
				z.progress = 0
				z.progressTeam = 0
				z.part.Color = zoneColor(only)
				Log.debug(("[WarService] ponto %s capturado por %s"):format(z.name, war.tags[only] or "?"))
			end
		elseif present == 0 and z.progress > 0 then
			z.progress = math.max(0, z.progress - dt / WarConfig.CaptureSeconds) -- some devagar
		end
	end
end

local function teamHasPlayers(war: War, teamId: number): boolean
	for _, p in war.participants do
		if p.teamId == teamId and not p.left and p.player.Parent == Players then
			return true
		end
	end
	return false
end

local function finishWar(war: War)
	war.finished = true
	wars[war.id] = nil
	local winner = war.winnerTeam
	for _, p in war.participants do
		p.player:SetAttribute("CanFight", false)
	end
	-- recompensas
	for teamId = 1, 2 do
		local won = winner == teamId
		local tag = war.tags[teamId]
		if tag then
			ClanService.AddToVault(tag, if won then WarConfig.Rewards.WinnerVault else WarConfig.Rewards.LoserVault)
			if won then
				ClanService.AddWin(tag)
			end
		end
	end
	for _, p in war.participants do
		if p.player.Parent == Players then
			local won = winner == p.teamId
			DataService.RewardCoins(p.player, if won then WarConfig.Rewards.WinnerCoins else WarConfig.Rewards.LoserCoins)
		end
	end
	local data = stateData(war)
	data.winnerTeam = winner or -1
	data.winnerTag = if winner then war.tags[winner] else nil
	notifyAll(war, "end", data)
	Log.debug(("[WarService] guerra %d: %s x %s → %s (%d–%d)"):format(war.id, war.tags[1], war.tags[2],
		if winner then war.tags[winner] else "empate", war.scores[1], war.scores[2]))
	task.wait(WarConfig.EndTime)
	for _, p in war.participants do
		returnToWorld(p.player)
	end
	war.map:Destroy()
	slotsInUse[war.slot] = nil
end

local function runWar(war: War)
	-- contagem
	local data = stateData(war)
	data.countdown = WarConfig.Countdown
	notifyAll(war, "start", data)
	task.wait(WarConfig.Countdown)
	if war.finished then
		return
	end
	for _, p in war.participants do
		if not p.left then
			p.player:SetAttribute("CanFight", true)
		end
	end
	war.endsAt = os.clock() + WarConfig.Duration
	local lastState = 0
	local accum = 0
	while not war.finished do
		local dt = task.wait(WarConfig.Tick)
		tickZones(war, dt)
		accum += dt
		if accum >= 1 then
			accum -= 1
			for _, z in war.zones do
				if z.owner > 0 then
					war.scores[z.owner] += WarConfig.PointsPerSecond
				end
			end
		end
		-- fim?
		local winner: number? = nil
		local timedOut = os.clock() >= war.endsAt
		if not teamHasPlayers(war, 1) then
			winner = 2
		elseif not teamHasPlayers(war, 2) then
			winner = 1
		elseif war.scores[1] >= WarConfig.ScoreToWin or war.scores[2] >= WarConfig.ScoreToWin or timedOut then
			winner = if war.scores[1] > war.scores[2] then 1 elseif war.scores[2] > war.scores[1] then 2 else nil
			if not winner and not timedOut then
				winner = nil -- ambos cruzaram juntos: segue até desempatar ou acabar o tempo
			elseif not winner then
				war.winnerTeam = nil
				break
			end
		end
		if winner then
			war.winnerTeam = winner
			break
		end
		if os.clock() - lastState >= 1 then
			lastState = os.clock()
			notifyAll(war, "state", stateData(war))
		end
	end
	finishWar(war)
end

local function startWar(a: QueueEntry, b: QueueEntry): (boolean, string)
	local template = ServerStorage:FindFirstChild("Maps") and ServerStorage.Maps:FindFirstChild(WarConfig.MapName)
	if not template or not template:IsA("Model") then
		return false, ("mapa %s não existe em ServerStorage.Maps"):format(WarConfig.MapName)
	end
	local slot = allocateSlot()
	if not slot then
		return false, "arenas de guerra ocupadas; aguarde"
	end
	nextWarId += 1
	local map = template:Clone()
	map.Name = ("War_%d"):format(nextWarId)
	for _, d in map:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d.Enabled = false
		end
	end
	map:PivotTo(slotOrigin(slot))
	map.Parent = warsFolder
	local spawnCfs = teamSpawnCFrames(map)
	local war: War = {
		id = nextWarId,
		slot = slot,
		map = map,
		tags = { a.tag, b.tag },
		names = { a.name, b.name },
		participants = {},
		byPlayer = {},
		zones = findZones(map),
		scores = { 0, 0 },
		spawns = { makeTeamSpawn(map, spawnCfs[1] + Vector3.new(0, 1, 0), 1), makeTeamSpawn(map, spawnCfs[2] + Vector3.new(0, 1, 0), 2) },
		endsAt = os.clock() + WarConfig.Countdown + WarConfig.Duration,
		finished = false,
		winnerTeam = nil,
	}
	if #war.zones == 0 then
		warn("[WarService] mapa sem pasta CapturePoints; guerra sem pontos (empate garantido)")
	end
	for teamId, entry in { a, b } do
		for _, player in entry.members do
			if player.Parent == Players and not isBusy(player) then
				local participant: Participant = { player = player, teamId = teamId, left = false }
				table.insert(war.participants, participant)
				war.byPlayer[player] = participant
				warByPlayer[player] = war
			end
		end
	end
	wars[war.id] = war
	for _, p in war.participants do
		task.spawn(spawnParticipant, war, p)
	end
	task.wait(0.5)
	task.spawn(runWar, war)
	return true, "ok"
end

local function tryMatch()
	while #queue >= 2 do
		local a = table.remove(queue, 1) :: QueueEntry
		local b = table.remove(queue, 1) :: QueueEntry
		local ok, err = startWar(a, b)
		if not ok then
			warn("[WarService] " .. err)
			table.insert(queue, 1, b)
			table.insert(queue, 1, a)
			return
		end
	end
end

-- ---------------------------------------------------------------------------
-- Fila
-- ---------------------------------------------------------------------------

local function onlineMembers(tag: string, clan: ClanConfig.Clan): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if ClanService.GetTag(p) == tag and clan.members[tostring(p.UserId)] and not isBusy(p) then
			table.insert(list, p)
			if #list >= WarConfig.MaxPerSide then
				break
			end
		end
	end
	return list
end

local function notifyMembers(members: { Player }, event: string, data: { [string]: any })
	for _, p in members do
		notify(p, event, table.clone(data))
	end
end

local function queueClan(player: Player)
	local clan = ClanService.GetClan(player)
	local me = clan and clan.members[tostring(player.UserId)]
	if not clan or not me then
		return notify(player, "denied", { reason = "você não está em um clã" })
	end
	if ClanConfig.RoleRank(me.role) < ClanConfig.RoleRank("officer") then
		return notify(player, "denied", { reason = "só líder e oficiais declaram guerra" })
	end
	if queueEntryOf(clan.tag) then
		return notify(player, "denied", { reason = "o clã já está na fila" })
	end
	local members = onlineMembers(clan.tag, clan)
	if #members < WarConfig.MinPerSide then
		return notify(player, "denied", { reason = ("precisa de %d membro(s) online e livres"):format(WarConfig.MinPerSide) })
	end
	table.insert(queue, { tag = clan.tag, name = clan.name, by = player, members = members })
	notifyMembers(members, "queue", { queued = true, tag = clan.tag, position = #queue, by = player.Name })
	Log.debug(("[WarService] [%s] entrou na fila com %d"):format(clan.tag, #members))
	tryMatch()
end

local function leaveQueue(player: Player)
	local tag = ClanService.GetTag(player)
	local entry, idx = if tag then queueEntryOf(tag) else nil, nil
	if not entry or not idx then
		return notify(player, "denied", { reason = "o clã não está na fila" })
	end
	local clan = ClanService.GetClan(player)
	local me = clan and clan.members[tostring(player.UserId)]
	if not me or ClanConfig.RoleRank(me.role) < ClanConfig.RoleRank("officer") then
		return notify(player, "denied", { reason = "só líder e oficiais tiram o clã da fila" })
	end
	table.remove(queue, idx :: number)
	notifyMembers(entry.members, "queue", { queued = false, tag = entry.tag })
end

local function onRequest(player: Player, action: any)
	if not requestLimiter:Allow(player) then
		return
	end
	if action == "queue" then
		queueClan(player)
	elseif action == "leave" then
		leaveQueue(player)
	elseif action == "refresh" then
		local war = warByPlayer[player]
		if war and not war.finished then
			notify(player, "state", stateData(war))
		else
			local tag = ClanService.GetTag(player)
			local entry, idx = if tag then queueEntryOf(tag) else nil, nil
			notify(player, "queue", { queued = entry ~= nil, tag = tag, position = idx })
		end
	end
end

-- ---------------------------------------------------------------------------
-- Eventos
-- ---------------------------------------------------------------------------

local function onCharacterAdded(player: Player)
	local war = warByPlayer[player]
	if not war or war.finished then
		return
	end
	-- renasceu na arena: proteção curta
	player:SetAttribute("InMatch", true)
	player:SetAttribute("TeamId", (war.byPlayer[player] :: Participant).teamId)
	player:SetAttribute("CanFight", false)
	task.delay(WarConfig.RespawnProtection, function()
		if warByPlayer[player] == war and not war.finished then
			player:SetAttribute("CanFight", true)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	local war = warByPlayer[player]
	local participant = war and war.byPlayer[player]
	if war and participant then
		participant.left = true
		warByPlayer[player] = nil
	end
	for i = #queue, 1, -1 do
		local e = queue[i]
		local idx = table.find(e.members, player)
		if idx then
			table.remove(e.members, idx)
			if #e.members == 0 then
				table.remove(queue, i)
			end
		end
	end
end

--- Guerra do jogador (ou nil).
function WarService.GetWarId(player: Player): number?
	local war = warByPlayer[player]
	return if war then war.id else nil
end

function WarService.Init()
	notifyWar = Remotes.GetEvent(Remotes.Events.NotifyWar)
	local existing = Workspace:FindFirstChild(WARS_FOLDER)
	if existing then
		existing:Destroy()
	end
	warsFolder = Instance.new("Folder")
	warsFolder.Name = WARS_FOLDER
	warsFolder.Parent = Workspace
end

function WarService.Start()
	Remotes.GetEvent(Remotes.Events.RequestWar).OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			onCharacterAdded(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			onCharacterAdded(player)
		end)
	end
	Log.debug(("[WarService] pronto (mapa %s, %d pontos por segundo)"):format(WarConfig.MapName, WarConfig.PointsPerSecond))
end

return WarService
