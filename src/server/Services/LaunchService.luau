--!strict
--[[
	LaunchService (servidor) — modo PRÉ-LANÇAMENTO (LaunchConfig). Para quem está "preso" ao lobby:
	  - nasce no Coliseu (WorldService lê LaunchConfig) e, se sair da área (ou cair), volta para o centro;
	  - facção pendente desligada (senão ninguém toma dano no lobby) e atributo PreLaunchLocked para o cliente
	    esconder história/objetivos/caçadas (IntroController);
	  - pode testar qualquer kit da lista (só na sessão, todas as teclas: atributo LobbyTest);
	  - bonecos de treino (bots com o combate real, só revidam, sem XP/loot) ficam no Coliseu.
	Doações (Developer Products de LaunchConfig.Donations): o recibo passa pelo ShopService (único ProcessReceipt) e
	cai em RecordDonation — total por jogador num DataStore com os PurchaseIds (não conta 2×) + placar ordenado.
	Apoiador = atributo Supporter (só visual).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local RateLimiter = require(Modules:WaitForChild("RateLimiter"))
local LaunchConfig = require(Modules:WaitForChild("LaunchConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))

local Services = script.Parent
local WorldService = require(Services:WaitForChild("WorldService"))
local FactionService = require(Services:WaitForChild("FactionService"))
local AbilityService = require(Services:WaitForChild("AbilityService"))
local AntiExploitService = require(Services:WaitForChild("AntiExploitService"))
local BotService = require(Services:WaitForChild("BotService"))
local ShopService = require(Services:WaitForChild("ShopService"))

local LaunchService = {}

local limiter = RateLimiter.new(3, 1)
local notify: RemoteEvent
local store: DataStore? = nil
local board: OrderedDataStore? = nil
local boardCache: { { name: string, amount: number } } = {}
local donated: { [number]: number } = {} -- userId -> total (cache da sessão)
local lobbyBots: { Model } = {}

local function lobbySpawn(): CFrame
	return CFrame.new(LaunchConfig.LobbyCenter + Vector3.new(0, 6, 0))
end

local function applyLock(player: Player)
	local locked = LaunchConfig.Locked(player)
	player:SetAttribute("PreLaunchLocked", locked)
	if not locked then
		player:SetAttribute("LobbyTest", nil)
	end
	WorldService.Refresh(player)
	FactionService.Refresh(player)
end

-- ---------------------------------------------------------------------------
-- Doações
-- ---------------------------------------------------------------------------

local function refreshBoard()
	local b = board
	if not b then
		return
	end
	local ok, pages = pcall(function()
		return b:GetSortedAsync(false, LaunchConfig.BoardSize)
	end)
	if not ok or not pages then
		return
	end
	local list: { { name: string, amount: number } } = {}
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(entry.key)
		local name = "?"
		if userId then
			local okName, n = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if okName and n then
				name = n
			end
		end
		table.insert(list, { name = name, amount = tonumber(entry.value) or 0 })
	end
	boardCache = list
	notify:FireAllClients("board", { board = boardCache })
end

local function setSupporter(player: Player, total: number)
	donated[player.UserId] = total
	player:SetAttribute("Supporter", if total > 0 then true else nil)
	player:SetAttribute("Donated", total)
end

local function loadDonated(player: Player)
	local s = store
	if not s then
		return
	end
	local ok, data = pcall(function()
		return s:GetAsync("u_" .. player.UserId)
	end)
	if ok and typeof(data) == "table" and player.Parent == Players then
		setSupporter(player, tonumber(data.total) or 0)
	end
end

--- Registra uma doação (chamado pelo ShopService no ProcessReceipt). true = gravou (ou já estava gravada).
function LaunchService.RecordDonation(userId: number, amount: number, purchaseId: string): boolean
	local s = store
	if not s then
		return false
	end
	local total = 0
	local ok, err = pcall(function()
		s:UpdateAsync("u_" .. userId, function(old: any)
			local data = if typeof(old) == "table" then old else { total = 0, receipts = {} }
			data.receipts = data.receipts or {}
			if not data.receipts[purchaseId] then
				data.receipts[purchaseId] = amount
				data.total = (tonumber(data.total) or 0) + amount
			end
			total = data.total
			return data
		end)
	end)
	if not ok then
		warn("[LaunchService] doação não gravou: " .. tostring(err))
		return false
	end
	local b = board
	if b then
		pcall(function()
			b:SetAsync(tostring(userId), total)
		end)
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		setSupporter(player, total)
		notify:FireClient(player, "thanks", { amount = amount, total = total })
	end
	task.spawn(refreshBoard)
	Log.info(("[LaunchService] doação de %d Robux (usuário %d, total %d)"):format(amount, userId, total))
	return true
end

-- ---------------------------------------------------------------------------
-- Lobby
-- ---------------------------------------------------------------------------

local function spawnLobbyBots()
	for _, m in lobbyBots do
		if m.Parent then
			BotService.Remove(m)
		end
	end
	table.clear(lobbyBots)
	if not LaunchConfig.PreLaunch then
		return
	end
	local kits = LaunchConfig.TestKits
	for i = 1, LaunchConfig.LobbyBots do
		local ang = (i / LaunchConfig.LobbyBots) * math.pi * 2
		local pos = LaunchConfig.LobbyCenter + Vector3.new(math.cos(ang) * 28, 4, math.sin(ang) * 28)
		local model = BotService.Spawn({
			Name = "Treino " .. i,
			CharacterId = kits[(i % #kits) + 1],
			CFrame = CFrame.lookAt(pos, LaunchConfig.LobbyCenter + Vector3.new(0, 4, 0)),
			Behavior = "passive", -- só revida quem bate
			Respawn = true,
			RespawnSeconds = 8,
			Team = "lobby_treino",
			Attributes = { LobbyBot = true },
			Tuning = { LeashRadius = 30 },
		})
		if model then
			table.insert(lobbyBots, model)
		end
	end
end

local function onRequest(player: Player, action: any, arg: any)
	if not limiter:Allow(player) or not LaunchConfig.Locked(player) then
		return
	end
	if action == "kit" then
		if typeof(arg) ~= "string" or not table.find(LaunchConfig.TestKits, arg) or not CharacterDefs.Get(arg) then
			return
		end
		local ok, why = AbilityService.CanChangeCharacter(player)
		if not ok then
			notify:FireClient(player, "info", { text = why })
			return
		end
		player:SetAttribute("LobbyTest", true) -- todas as teclas liberadas (sem maestria), só no lobby
		AbilityService.ForceCharacter(player, arg)
		notify:FireClient(player, "info", { text = "Testando: " .. ((CharacterDefs.Get(arg) :: any).DisplayName or arg) })
	elseif action == "donate" then
		local d = if typeof(arg) == "string" then LaunchConfig.GetDonation(arg) else nil
		if not d then
			return
		end
		if d.productId <= 0 then
			notify:FireClient(player, "info", { text = "Doações em breve!" })
			return
		end
		MarketplaceService:PromptProductPurchase(player, d.productId)
	end
end

local function leash()
	local r2 = LaunchConfig.LobbyRadius * LaunchConfig.LobbyRadius
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("PreLaunchLocked") ~= true then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local d = root.Position - LaunchConfig.LobbyCenter
		if d.X * d.X + d.Z * d.Z > r2 or root.Position.Y < LaunchConfig.LobbyCenter.Y - 40 then
			AntiExploitService.Grace(player, 2)
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = lobbySpawn()
		end
	end
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function LaunchService.Init()
	notify = Remotes.GetEvent(Remotes.Events.NotifyLaunch)
	if game.PlaceId ~= 0 then
		pcall(function()
			store = DataStoreService:GetDataStore(LaunchConfig.DonationStore)
			board = DataStoreService:GetOrderedDataStore(LaunchConfig.DonationBoard)
		end)
	end
	ShopService.DonationHook = LaunchService.RecordDonation
end

function LaunchService.Start()
	Remotes.GetEvent(Remotes.Events.RequestLaunch).OnServerEvent:Connect(onRequest)
	Remotes.GetFunction(Remotes.Functions.FetchLaunch).OnServerInvoke = function(player: Player)
		return { board = boardCache, donated = donated[player.UserId] or 0, preLaunch = LaunchConfig.PreLaunch }
	end
	local function setup(player: Player)
		applyLock(player)
		player:GetAttributeChangedSignal("IsDeveloper"):Connect(function()
			applyLock(player)
		end)
		player:GetAttributeChangedSignal("PreLaunchView"):Connect(function()
			applyLock(player)
			if player.Character then
				player.Character:PivotTo(if LaunchConfig.Locked(player) then lobbySpawn() else (WorldService.SpawnCFrame(player) or lobbySpawn()))
			end
		end)
		task.spawn(loadDonated, player)
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		task.spawn(setup, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		donated[player.UserId] = nil
	end)
	if LaunchConfig.PreLaunch then
		task.delay(3, spawnLobbyBots)
		local acc = 0
		RunService.Heartbeat:Connect(function(dt)
			acc += dt
			if acc >= 0.5 then
				acc = 0
				leash()
			end
		end)
	end
	task.spawn(refreshBoard)
	task.spawn(function()
		while true do
			task.wait(120)
			refreshBoard()
		end
	end)
end

return LaunchService
