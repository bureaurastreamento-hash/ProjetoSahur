--!strict
--[[
	LeaderboardService (servidor)
	Placares globais (OrderedDataStore), um por "board":
	  - kills:  total de kills (profile.stats.kills), painel Workspace.Sahur...LeaderboardBoard
	  - rating: Elo de duelo 1v1 (profile.rating), painel Workspace.Sahur...RatingBoard
	Publica o valor do jogador ao sair e a cada PUBLISH_INTERVAL; a cada REFRESH_INTERVAL busca o
	top N de cada board, desenha no SurfaceGui do painel (criado por tools/gerar_arena.py, ArenaExtras)
	e manda NotifyLeaderboard({ kills = rows, rating = rows }) para o Perfil. Sem a Part, só publica.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Log = require(Modules:WaitForChild("Log"))
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local DuelConfig = require(Modules:WaitForChild("DuelConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local LeaderboardService = {}

local TOP_N = 10
local REFRESH_INTERVAL = 60
local PUBLISH_INTERVAL = 120

type Row = { name: string, value: number }
type Board = {
	key: string,
	storeName: string,
	boardName: string, -- Part no mapa
	title: string,
	-- valor a publicar (nil = não entra no ranking)
	valueOf: (profile: any) -> number?,
	store: OrderedDataStore?,
	storeFailed: boolean,
	rows: { TextLabel },
	lastPublished: { [Player]: number },
	lastRows: { Row },
}

local function board(key: string, storeName: string, boardName: string, title: string, valueOf: (any) -> number?): Board
	return {
		key = key,
		storeName = storeName,
		boardName = boardName,
		title = title,
		valueOf = valueOf,
		store = nil,
		storeFailed = false,
		rows = {},
		lastPublished = {},
		lastRows = {},
	}
end

local boards: { Board } = {
	board("kills", "Leaderboard_Kills_v1", "LeaderboardBoard", "🏆 TOP KILLS", function(profile)
		local kills = profile.stats.kills
		return if kills > 0 then kills else nil
	end),
	-- rating só entra depois do 1º duelo (sai do valor inicial)
	board("rating", "Leaderboard_Rating_v1", "RatingBoard", "⚔️ TOP RATING 1v1", function(profile)
		local rating = profile.rating
		return if typeof(rating) == "number" and rating ~= DuelConfig.RatingStart then rating else nil
	end),
}

local nameCache: { [number]: string } = {}
local notifyLeaderboard: RemoteEvent

local function getStore(b: Board): OrderedDataStore?
	if b.store or b.storeFailed then
		return b.store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(b.storeName)
	end)
	if ok then
		b.store = result
	else
		b.storeFailed = true
		warn(("[LeaderboardService] sem DataStore %s: %s"):format(b.storeName, tostring(result)))
	end
	return b.store
end

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local online = Players:GetPlayerByUserId(userId)
	local name = if online then online.Name else nil
	if not name then
		local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		name = if ok then result else ("#" .. tostring(userId))
	end
	nameCache[userId] = name :: string
	return name :: string
end

local function publish(player: Player)
	if DataService.IsSessionOnly(player) then
		return -- perfil temporário: não polui o ranking
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	for _, b in boards do
		local s = getStore(b)
		local value = b.valueOf(profile)
		if s and value and b.lastPublished[player] ~= value then
			local ok, err = pcall(s.SetAsync, s, tostring(player.UserId), value)
			if ok then
				b.lastPublished[player] = value
			else
				warn(("[LeaderboardService] SetAsync %s/%s: %s"):format(b.key, player.Name, tostring(err)))
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Painel
-- ---------------------------------------------------------------------------

local function findBoard(name: string): BasePart?
	local arena = Workspace:FindFirstChild("Sahur") -- Arena (importado) + ArenaExtras (spawns/pads/placar)
	if not arena then
		return nil
	end
	local part = arena:FindFirstChild(name, true)
	return if part and part:IsA("BasePart") then part else nil
end

local function buildGui(b: Board, part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = part

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = b.title
	title.Font = Enum.Font.GothamBold
	title.TextSize = 40
	title.TextColor3 = Color3.fromRGB(255, 210, 90)
	title.Parent = gui

	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, -30, 1, -80)
	list.Position = UDim2.new(0, 15, 0, 70)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for i = 1, TOP_N do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 26)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.Gotham
		row.TextSize = 22
		row.TextColor3 = if i <= 3 then Color3.fromRGB(255, 235, 170) else Color3.fromRGB(220, 220, 225)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.LayoutOrder = i
		row.Text = ("%2d.  —"):format(i)
		row.Parent = list
		b.rows[i] = row
	end
end

local function payload(): { [string]: { Row } }
	local out = {}
	for _, b in boards do
		out[b.key] = b.lastRows
	end
	return out
end

local function refreshBoard(b: Board)
	local s = getStore(b)
	if not s then
		return
	end
	local ok, pages = pcall(s.GetSortedAsync, s, false, TOP_N)
	if not ok then
		warn(("[LeaderboardService] GetSortedAsync %s: %s"):format(b.key, tostring(pages)))
		return
	end
	local entries = (pages :: DataStorePages):GetCurrentPage()
	b.lastRows = {}
	for i = 1, TOP_N do
		local entry = entries[i]
		local row = b.rows[i]
		if entry then
			local userId = tonumber(entry.key) or 0
			local name = nameFor(userId)
			table.insert(b.lastRows, { name = name, value = entry.value })
			if row then
				row.Text = ("%2d.  %s  —  %d"):format(i, name, entry.value)
			end
		elseif row then
			row.Text = ("%2d.  —"):format(i)
		end
	end
end

local function refresh()
	for _, b in boards do
		refreshBoard(b)
	end
	notifyLeaderboard:FireAllClients(payload())
end

--- [Admin] Publica todo mundo e redesenha.
function LeaderboardService.Refresh()
	for _, player in Players:GetPlayers() do
		for _, b in boards do
			b.lastPublished[player] = nil
		end
		publish(player)
	end
	refresh()
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function LeaderboardService.Init()
	notifyLeaderboard = Remotes.GetEvent(Remotes.Events.NotifyLeaderboard)
end

function LeaderboardService.Start()
	Players.PlayerAdded:Connect(function(player)
		notifyLeaderboard:FireClient(player, payload())
	end)
	if RunService:IsStudio() then
		Log.debug("[LeaderboardService] Studio: DataStore só funciona com 'Enable Studio Access to API Services'")
	end
	for _, b in boards do
		local part = findBoard(b.boardName)
		if part then
			buildGui(b, part)
		else
			warn("[LeaderboardService] Part " .. b.boardName .. " não encontrada no mapa; só publicando")
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		publish(player)
		for _, b in boards do
			b.lastPublished[player] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(PUBLISH_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(publish, player)
			end
		end
	end)
	task.spawn(function()
		task.wait(3)
		while true do
			refresh()
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return LeaderboardService
