--!strict
--[[
	TournamentService (servidor)
	Evento de admin "ÚLTIMO DE PÉ" (dono, D3 2026-09-23). Roda POR CIMA do mapa livre: nada de arena separada.
	Máquina de estados: idle → signup (inscrição aberta, RequestTournament "join"/"leave") → countdown (times
	formados, atributos marcados) → running (quem morre por qualquer causa sai; companheiro não machuca
	companheiro — HealthService.IsInvulnerable lê TournamentTeam) → fim (sobrou 1 time = prêmio; estourou o
	tempo = empate sem prêmio) → idle.
	Modos (TournamentConfig.Modes): solo / duo (duplas na ordem de inscrição; ímpar sobra sozinho) / clan (time =
	clã; sem clã não entra). Bots NÃO participam (só Players). Sair do servidor = eliminado.
	DEV: TournamentOpen { mode, coins, eventPoints, cosmetic } → Open; TournamentStart → Begin (fecha a inscrição e inicia agora);
	TournamentCancel. Servidor autoritativo em tudo; o cliente só reflete NotifyTournament.
	FUTURO (anotado, não feito): morte súbita (área que encolhe), prêmio em Robux/payout.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local TournamentConfig = require(Modules:WaitForChild("TournamentConfig"))
local CosmeticsConfig = require(Modules:WaitForChild("CosmeticsConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local HealthService = require(script.Parent:WaitForChild("HealthService"))
local ClanService = require(script.Parent:WaitForChild("ClanService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))

local TournamentService = {}

type Phase = "idle" | "signup" | "countdown" | "running"
type Team = { id: string, label: string, members: { Player }, alive: number }
type Reward = TournamentConfig.Reward

local phase: string = "idle" -- Phase (string para o narrowing do luau-lsp não reclamar após as trocas)
local mode: string = "solo"
local reward: Reward = TournamentConfig.DefaultReward
local signups: { Player } = {} -- ordem de inscrição
local signedUp: { [Player]: boolean } = {}
local teams: { [string]: Team } = {}
local teamOf: { [Player]: string } = {}
local alive: { [Player]: boolean } = {}
local endsAt = 0 -- Workspace:GetServerTimeNow() em que a fase atual acaba (0 = sem prazo)
local token = 0 -- invalida timers agendados de fases anteriores

local notify: RemoteEvent

-- ---------------------------------------------------------------------------
-- Estado / broadcast
-- ---------------------------------------------------------------------------

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function teamsAlive(): number
	local n = 0
	for _, team in teams do
		if team.alive > 0 then
			n += 1
		end
	end
	return n
end

local function rewardText(r: Reward): string
	local parts = {}
	if r.Coins > 0 then
		table.insert(parts, ("%d pontos"):format(r.Coins))
	end
	if r.EventPoints > 0 then
		table.insert(parts, ("%d de evento"):format(r.EventPoints))
	end
	if r.XP > 0 then
		table.insert(parts, ("%d XP"):format(r.XP))
	end
	if r.Cosmetic then
		local item = CosmeticsConfig.GetItem(r.Cosmetic) or CosmeticsConfig.GetEmote(r.Cosmetic)
		table.insert(parts, if item then item.Name else r.Cosmetic)
	end
	return table.concat(parts, " · ")
end

local function statePayload(player: Player): { [string]: any }
	local modeDef = TournamentConfig.Modes[mode]
	return {
		phase = phase,
		mode = mode,
		modeLabel = if modeDef then modeDef.Label else mode,
		endsAt = endsAt,
		players = if phase == "signup" then #signups else count(alive),
		alive = count(alive),
		teamsAlive = teamsAlive(),
		joined = signedUp[player] == true,
		inGame = alive[player] == true,
		reward = rewardText(reward),
	}
end

function TournamentService.GetPhase(): string
	return phase
end

local function pushAll()
	for _, p in Players:GetPlayers() do
		notify:FireClient(p, "state", statePayload(p))
	end
end

local function deny(player: Player, message: string)
	notify:FireClient(player, "denied", { message = message })
end

-- ---------------------------------------------------------------------------
-- Ciclo
-- ---------------------------------------------------------------------------

local function clearAttributes(player: Player)
	player:SetAttribute(TournamentConfig.AttrIn, nil)
	player:SetAttribute(TournamentConfig.AttrTeam, nil)
end

local function reset()
	for p in signedUp do
		clearAttributes(p)
	end
	for p in alive do
		clearAttributes(p)
	end
	phase = "idle"
	signups = {}
	signedUp = {}
	teams = {}
	teamOf = {}
	alive = {}
	endsAt = 0
	token += 1
end

local function grant(player: Player, r: Reward): string
	local parts = {}
	if r.Coins > 0 then
		DataService.AddCoins(player, r.Coins)
		table.insert(parts, ("%d pontos"):format(r.Coins))
	end
	if r.EventPoints > 0 then
		DataService.AddEventPoints(player, r.EventPoints)
		table.insert(parts, ("%d de evento"):format(r.EventPoints))
	end
	if r.XP > 0 then
		ProgressionService.AddXP(player, r.XP, "tournament")
		table.insert(parts, ("%d XP"):format(r.XP))
	end
	if r.Cosmetic then
		local ok = AchievementService.GrantReward(player, r.Cosmetic)
		if ok then
			table.insert(parts, r.Cosmetic)
		end
	end
	local profile = DataService.GetProfile(player)
	if profile then
		profile.stats.tournamentWins += 1
		DataService.MarkDirty(player)
	end
	AchievementService.Progress(player, "tournament_wins", 1)
	return table.concat(parts, ", ")
end

local function finish(winner: Team?)
	local payload: { [string]: any } = { mode = mode, reward = rewardText(reward) }
	if winner then
		local names = {}
		for _, p in winner.members do
			table.insert(names, p.DisplayName)
			if p.Parent == Players then
				grant(p, reward)
			end
		end
		payload.winner = winner.label
		payload.winners = names
		Log.debug(("[TournamentService] fim: venceu %s (%s) — %s"):format(winner.label, table.concat(names, ", "), payload.reward))
	else
		Log.debug("[TournamentService] fim: empate (tempo esgotado ou todos eliminados)")
	end
	reset()
	notify:FireAllClients("end", payload)
	pushAll()
end

local function checkEnd()
	if phase ~= "running" then
		return
	end
	local left = teamsAlive()
	if left == 1 then
		for _, team in teams do
			if team.alive > 0 then
				finish(team)
				return
			end
		end
	elseif left == 0 then
		finish(nil)
	end
end

local function eliminate(player: Player, reason: string)
	if not alive[player] then
		return
	end
	alive[player] = nil
	clearAttributes(player)
	local team = teams[teamOf[player] or ""]
	if team then
		team.alive = math.max(0, team.alive - 1)
	end
	Log.debug(("[TournamentService] %s eliminado (%s); vivos: %d"):format(player.Name, reason, count(alive)))
	notify:FireAllClients("eliminated", { name = player.DisplayName, alive = count(alive), teamsAlive = teamsAlive(), reason = reason })
	pushAll()
	checkEnd()
end

--- Monta os times a partir dos inscritos conforme o modo. Devolve false se não dá para começar.
local function buildTeams(): (boolean, string)
	teams = {}
	teamOf = {}
	local present: { Player } = {}
	for _, p in signups do
		if p.Parent == Players then
			table.insert(present, p)
		end
	end
	if #present < TournamentConfig.MinPlayers then
		return false, ("só %d inscrito(s); mínimo %d"):format(#present, TournamentConfig.MinPlayers)
	end
	local function put(p: Player, id: string, label: string)
		local team = teams[id]
		if not team then
			team = { id = id, label = label, members = {}, alive = 0 }
			teams[id] = team
		end
		table.insert(team.members, p)
		team.alive += 1
		teamOf[p] = id
	end
	if mode == "clan" then
		for _, p in present do
			local tag = ClanService.GetTag(p)
			if tag then
				put(p, "clan_" .. tag, "[" .. tag .. "]")
			end
		end
	elseif mode == "duo" then
		for i, p in present do
			local n = math.ceil(i / 2)
			local mate = if i % 2 == 1 then present[i + 1] else present[i - 1]
			put(p, "duo_" .. n, if mate then p.DisplayName .. " & " .. mate.DisplayName else p.DisplayName)
		end
	else
		for _, p in present do
			put(p, "solo_" .. p.UserId, p.DisplayName)
		end
	end
	if count(teams) < TournamentConfig.MinTeams then
		return false, ("só %d time(s); mínimo %d"):format(count(teams), TournamentConfig.MinTeams)
	end
	return true, ""
end

local function begin(myToken: number)
	if myToken ~= token or phase ~= "countdown" then
		return
	end
	phase = "running"
	endsAt = Workspace:GetServerTimeNow() + TournamentConfig.MaxSeconds
	for p in alive do
		local character = p.Character
		if character then
			HealthService.Heal(character, 10000)
		end
	end
	Log.debug(("[TournamentService] começou: %d jogador(es), %d time(s), modo %s"):format(count(alive), count(teams), mode))
	notify:FireAllClients("start", { mode = mode, players = count(alive), teamsAlive = teamsAlive() })
	pushAll()
	local runToken = token
	task.delay(TournamentConfig.MaxSeconds, function()
		if runToken == token and TournamentService.GetPhase() == "running" then
			finish(nil)
		end
	end)
end

--- Fecha a inscrição, forma os times e inicia a contagem. (ok, mensagem)
function TournamentService.Begin(): (boolean, string)
	if phase ~= "signup" then
		return false, "não há inscrição aberta"
	end
	local ok, why = buildTeams()
	if not ok then
		Log.debug("[TournamentService] cancelado ao iniciar: " .. why)
		reset()
		notify:FireAllClients("end", { cancelled = true, message = "Torneio cancelado: " .. why })
		pushAll()
		return false, "cancelado: " .. why
	end
	phase = "countdown"
	token += 1
	local myToken = token
	alive = {}
	for p, id in teamOf do
		alive[p] = true
		p:SetAttribute(TournamentConfig.AttrIn, true)
		p:SetAttribute(TournamentConfig.AttrTeam, id)
	end
	endsAt = Workspace:GetServerTimeNow() + TournamentConfig.CountdownSeconds
	pushAll()
	task.delay(TournamentConfig.CountdownSeconds, begin, myToken)
	return true, ("contagem de %d s: %d jogador(es) em %d time(s)"):format(TournamentConfig.CountdownSeconds, count(alive), count(teams))
end

--- Abre a inscrição. opts = { mode = "solo"|"duo"|"clan", coins?, eventPoints?, xp?, cosmetic? }
function TournamentService.Open(opts: { [string]: any }?): (boolean, string)
	if phase ~= "idle" then
		return false, "já tem torneio em andamento (cancele antes)"
	end
	local o: { [string]: any } = opts or {}
	local m = if typeof(o.mode) == "string" and TournamentConfig.Modes[o.mode] then o.mode else "solo"
	local base = TournamentConfig.DefaultReward
	local r: Reward = {
		Coins = if typeof(o.coins) == "number" and o.coins >= 0 then math.floor(o.coins) else base.Coins,
		EventPoints = if typeof(o.eventPoints) == "number" and o.eventPoints >= 0 then math.floor(o.eventPoints) else base.EventPoints,
		XP = if typeof(o.xp) == "number" and o.xp >= 0 then math.floor(o.xp) else base.XP,
		Cosmetic = nil,
	}
	if typeof(o.cosmetic) == "string" and o.cosmetic ~= "" then
		if CosmeticsConfig.GetItem(o.cosmetic) or CosmeticsConfig.GetEmote(o.cosmetic) then
			r.Cosmetic = o.cosmetic
		else
			return false, ("cosmético '%s' não existe em CosmeticsConfig"):format(o.cosmetic)
		end
	end
	reset()
	mode = m
	reward = r
	phase = "signup"
	endsAt = Workspace:GetServerTimeNow() + TournamentConfig.SignupSeconds
	local myToken = token
	Log.debug(("[TournamentService] inscrição aberta: modo %s, prêmio %s"):format(mode, rewardText(reward)))
	pushAll()
	task.delay(TournamentConfig.SignupSeconds, function()
		if myToken == token and TournamentService.GetPhase() == "signup" then
			TournamentService.Begin()
		end
	end)
	return true, ("inscrição aberta (%s, %d s) — prêmio: %s"):format(TournamentConfig.Modes[mode].Label, TournamentConfig.SignupSeconds, rewardText(reward))
end

function TournamentService.Cancel(): (boolean, string)
	if phase == "idle" then
		return false, "não há torneio"
	end
	reset()
	notify:FireAllClients("end", { cancelled = true, message = "Torneio cancelado pelo administrador." })
	pushAll()
	return true, "torneio cancelado"
end

function TournamentService.IsIn(player: Player): boolean
	return alive[player] == true
end

-- ---------------------------------------------------------------------------
-- Pedidos do jogador
-- ---------------------------------------------------------------------------

local function join(player: Player)
	if phase ~= "signup" then
		deny(player, if phase == "idle" then "Nenhum torneio aberto." else "A inscrição já fechou.")
		return
	end
	if signedUp[player] then
		return
	end
	if mode == "clan" and not ClanService.GetTag(player) then
		deny(player, "Este torneio é de CLÃS: entre num clã para participar.")
		return
	end
	signedUp[player] = true
	table.insert(signups, player)
	player:SetAttribute(TournamentConfig.AttrIn, true)
	Log.debug(("[TournamentService] %s inscrito (%d)"):format(player.Name, #signups))
	pushAll()
end

local function leave(player: Player)
	if phase == "signup" and signedUp[player] then
		signedUp[player] = nil
		local i = table.find(signups, player)
		if i then
			table.remove(signups, i)
		end
		clearAttributes(player)
		pushAll()
	elseif alive[player] then
		eliminate(player, "desistiu")
	end
end

-- ---------------------------------------------------------------------------
-- Boot
-- ---------------------------------------------------------------------------

function TournamentService.Init()
	notify = Remotes.GetEvent(Remotes.Events.NotifyTournament)
end

function TournamentService.Start()
	local limiter = RateLimiter.new(5, 5)
	Remotes.GetEvent(Remotes.Events.RequestTournament).OnServerEvent:Connect(function(player, action)
		if not limiter:Allow(player) then
			return
		end
		if action == "join" then
			join(player)
		elseif action == "leave" then
			leave(player)
		elseif action == "refresh" then
			notify:FireClient(player, "state", statePayload(player))
		end
	end)
	HealthService.Died.Event:Connect(function(victim: Player, killer: Player?)
		if alive[victim] then
			eliminate(victim, if killer then "derrotado por " .. killer.DisplayName else "caiu")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if alive[player] then
			eliminate(player, "saiu do servidor")
		elseif signedUp[player] then
			leave(player)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if player.Parent == Players then
				notify:FireClient(player, "state", statePayload(player))
			end
		end)
	end)
	Log.debug("[TournamentService] pronto (Último de pé: DEV abre a inscrição)")
end

return TournamentService
