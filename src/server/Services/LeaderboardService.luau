--!strict
--[[
	LeaderboardService (servidor)
	Placar de líderes global por kills totais (OrderedDataStore "Leaderboard_Kills_v1").
	  - Publica o total do jogador (profile.stats.kills) ao sair e a cada PUBLISH_INTERVAL.
	  - A cada REFRESH_INTERVAL busca o top N e desenha num SurfaceGui na Part
	    Workspace.Sahur.Arena...LeaderboardBoard (criada por tools/gerar_arena.py).
	Sem a Part, o serviço só publica. Nada replica para o cliente além do próprio GUI.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Log = require(Modules:WaitForChild("Log"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local LeaderboardService = {}

local STORE_NAME = "Leaderboard_Kills_v1"
local TOP_N = 10
local REFRESH_INTERVAL = 60
local PUBLISH_INTERVAL = 120
local BOARD_NAME = "LeaderboardBoard"

local store: OrderedDataStore? = nil
local nameCache: { [number]: string } = {}
local rows: { TextLabel } = {}
local lastPublished: { [Player]: number } = {}

local function getStore(): OrderedDataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[LeaderboardService] sem DataStore: " .. tostring(result))
	end
	return store
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
		name = if ok then result else ("#" .. userId)
	end
	nameCache[userId] = name :: string
	return name :: string
end

-- ---------------------------------------------------------------------------
-- Publicar
-- ---------------------------------------------------------------------------

local function publish(player: Player)
	if DataService.IsSessionOnly(player) then
		return -- perfil temporário: não polui o ranking
	end
	local profile = DataService.GetProfile(player)
	local s = getStore()
	if not profile or not s then
		return
	end
	local kills = profile.stats.kills
	if kills <= 0 or lastPublished[player] == kills then
		return
	end
	local ok, err = pcall(s.SetAsync, s, tostring(player.UserId), kills)
	if ok then
		lastPublished[player] = kills
	else
		warn(("[LeaderboardService] SetAsync %s: %s"):format(player.Name, tostring(err)))
	end
end

-- ---------------------------------------------------------------------------
-- Painel
-- ---------------------------------------------------------------------------

local function findBoard(): BasePart?
	local sahur = Workspace:FindFirstChild("Sahur")
	local arena = sahur and sahur:FindFirstChild("Arena")
	if not arena then
		return nil
	end
	local board = arena:FindFirstChild(BOARD_NAME, true)
	return if board and board:IsA("BasePart") then board else nil
end

local function buildGui(board: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = "🏆 TOP KILLS"
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
		rows[i] = row
	end
end

local function refresh()
	local s = getStore()
	if not s or #rows == 0 then
		return
	end
	local ok, pages = pcall(s.GetSortedAsync, s, false, TOP_N)
	if not ok then
		warn("[LeaderboardService] GetSortedAsync: " .. tostring(pages))
		return
	end
	local entries = (pages :: DataStorePages):GetCurrentPage()
	for i = 1, TOP_N do
		local entry = entries[i]
		local row = rows[i]
		if entry then
			local userId = tonumber(entry.key) or 0
			row.Text = ("%2d.  %s  —  %d"):format(i, nameFor(userId), entry.value)
		else
			row.Text = ("%2d.  —"):format(i)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function LeaderboardService.Start()
	if RunService:IsStudio() then
		Log.debug("[LeaderboardService] Studio: DataStore só funciona com 'Enable Studio Access to API Services'")
	end
	local board = findBoard()
	if board then
		buildGui(board)
	else
		warn("[LeaderboardService] Part " .. BOARD_NAME .. " não encontrada no mapa; só publicando")
	end

	Players.PlayerRemoving:Connect(function(player)
		publish(player)
		lastPublished[player] = nil
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
