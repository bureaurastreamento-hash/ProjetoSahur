--!strict
--[[
	VendorController (cliente)
	Painel do VENDEDOR da Lojinha (VendorGui.Panel): abre pelo ProximityPrompt "ShopPrompt" do NPC
	(ShopNpcService) e fecha sozinho quando o jogador se afasta (VendorConfig.Range).
	  Aba COMPRAR: catálogo de VendorConfig (roleta, personagens, capas, auras, emotes, itens de EVENTO)
	    com preço em pontos ou pontos de evento; clique = RequestVendor("buy"/"roll").
	  Aba TROCAR: lista de jogadores do servidor; clique = TradeController.Propose (RequestTrade "invite").
	Saldos vêm do NotifyProfile (coins / eventPoints). Tudo validado no servidor (VendorService).
	API: VendorController.Open() / Close() / IsOpen() (TradeController usa).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local VendorConfig = require(Modules:WaitForChild("VendorConfig"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local CosmeticsConfig = require(Modules:WaitForChild("CosmeticsConfig"))
local FX = require(Modules:WaitForChild("FX"))
local TopbarController = require(script.Parent:WaitForChild("TopbarController"))

local VendorController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local panel: Frame
local coinsLabel: TextLabel
local hint: TextLabel
local list: ScrollingFrame
local rowTemplate: TextButton
local sectionTemplate: TextLabel
local playersList: ScrollingFrame
local playerTemplate: TextButton
local tabShop: TextButton
local tabTrade: TextButton
local requestVendor: RemoteEvent
local profile: any = nil
local currentTab = "shop"
local hintTimer = 0

--- Chamado pela aba TROCAR (TradeController registra no Start).
VendorController.OnPropose = nil :: ((Player) -> ())?

local GOLD = Color3.fromRGB(255, 200, 70)
local MUTED = Color3.fromRGB(150, 150, 160)
local GREEN = Color3.fromRGB(90, 205, 130)
local TAB_ON = Color3.fromRGB(60, 120, 200)
local TAB_OFF = Color3.fromRGB(26, 26, 31)

local DENY_TEXT: { [string]: string } = {
	coins = "Pontos insuficientes.",
	event_points = "Pontos de evento insuficientes (ganhe nos mini eventos do Canion).",
	already_owned = "Você já tem este item.",
	not_loaded = "Seus dados ainda não carregaram (ou não salvam nesta sessão).",
	far = "Chegue mais perto do vendedor.",
	unavailable = "Este item não está à venda assim.",
	all_owned = "Você já tem tudo da roleta!",
	unknown = "Item desconhecido.",
	vip = "Este é do passe VIP (Loja, L).",
	early = "Ainda não liberado.",
}

local function get(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child, ("[VendorController] '%s' não encontrado em %s"):format(name, parent:GetFullName()))
	return child
end

local function defaultHint(): string
	return if currentTab == "shop"
		then "Compre com pontos (ganhos jogando) ou pontos de EVENTO. Só visual: nada dá vantagem."
		else "Escolha um jogador para propor uma troca. Os dois precisam estar aqui no vendedor."
end

local function setHint(text: string, seconds: number?)
	hint.Text = text
	hintTimer += 1
	local my = hintTimer
	if seconds then
		task.delay(seconds, function()
			if hintTimer == my then
				hint.Text = defaultHint()
			end
		end)
	end
end

local function refreshCoins()
	local coins = localPlayer:GetAttribute("Coins")
	local ev = localPlayer:GetAttribute("EventPoints")
	coinsLabel.Text = ("%d pts  ·  %d de evento"):format(if typeof(coins) == "number" then coins else 0, if typeof(ev) == "number" then ev else 0)
end

local function ownsEntry(entry: VendorConfig.Entry): boolean
	if not profile then
		return false
	end
	if entry.kind == "character" then
		return table.find(profile.unlockedCharacters or {}, entry.id) ~= nil
	elseif entry.kind == "cosmetic" then
		local c = profile.cosmetics
		return typeof(c) == "table" and table.find(c.owned or {}, entry.id) ~= nil
	elseif entry.kind == "emote" then
		return table.find(profile.emotes or {}, entry.id) ~= nil
	end
	return false
end

local function clear(container: Instance, keep: { Instance })
	for _, child in container:GetChildren() do
		if (child:IsA("TextButton") or child:IsA("TextLabel")) and not table.find(keep, child) then
			child:Destroy()
		end
	end
end

local function buildShop()
	clear(list, { rowTemplate, sectionTemplate })
	local order = 0
	local catalog = VendorConfig.Catalog()
	for _, group in VendorConfig.GroupOrder do
		local any = false
		for _, entry in catalog do
			if entry.group == group then
				any = true
				break
			end
		end
		if not any then
			continue
		end
		order += 1
		local section = sectionTemplate:Clone()
		section.Visible = true
		section.LayoutOrder = order
		section.Text = group
		section.Parent = list
		for _, entry in catalog do
			if entry.group ~= group then
				continue
			end
			order += 1
			local row = rowTemplate:Clone()
			row.Visible = true
			row.LayoutOrder = order
			;(row:FindFirstChild("Name") :: TextLabel).Text = entry.name
			local swatch = row:FindFirstChild("Swatch") :: Frame
			swatch.Visible = entry.color ~= nil
			if entry.color then
				swatch.BackgroundColor3 = entry.color
			end
			local price = row:FindFirstChild("Price") :: TextLabel
			local owned = entry.kind ~= "roll" and ownsEntry(entry)
			if owned then
				price.Text = "JÁ TEM"
				price.TextColor3 = MUTED
			elseif entry.eventPrice then
				price.Text = ("%d de evento"):format(entry.eventPrice)
				price.TextColor3 = GREEN
			else
				price.Text = ("%d pts"):format(entry.price or 0)
				price.TextColor3 = GOLD
			end
			row.Activated:Connect(function()
				if entry.kind == "roll" then
					requestVendor:FireServer("roll")
				elseif not owned then
					requestVendor:FireServer("buy", entry.id, if entry.eventPrice then "event" else "points")
				end
			end)
			row.Parent = list
		end
	end
end

local function buildPlayers()
	clear(playersList, { playerTemplate })
	for _, p in Players:GetPlayers() do
		if p == localPlayer then
			continue
		end
		local row = playerTemplate:Clone()
		row.Name = p.Name
		row.Visible = true
		row.Text = p.DisplayName
		row.Activated:Connect(function()
			if VendorController.OnPropose then
				VendorController.OnPropose(p)
			end
		end)
		row.Parent = playersList
	end
	if #Players:GetPlayers() <= 1 then
		hint.Text = "Ninguém mais no servidor para trocar."
	end
end

local function setTab(tab: string)
	currentTab = tab
	tabShop.BackgroundColor3 = if tab == "shop" then TAB_ON else TAB_OFF
	tabTrade.BackgroundColor3 = if tab == "trade" then TAB_ON else TAB_OFF
	list.Visible = tab == "shop"
	playersList.Visible = tab == "trade"
	hintTimer += 1
	hint.Text = defaultHint()
	if tab == "shop" then
		buildShop()
	else
		buildPlayers()
	end
end

local function vendorPosition(): Vector3?
	local npc = Workspace:FindFirstChild("Vendedor")
	local root = if npc then npc:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root.Position else nil
end

function VendorController.IsOpen(): boolean
	return panel.Visible
end

function VendorController.Open()
	TopbarController.CloseAll()
	panel.Visible = true
	refreshCoins()
	setTab(currentTab)
end

function VendorController.Close()
	panel.Visible = false
end

function VendorController.Init()
	requestVendor = Remotes.GetEvent(Remotes.Events.RequestVendor)
	local gui = get(playerGui, "VendorGui")
	panel = get(gui, "Panel") :: Frame
	coinsLabel = get(panel, "Coins") :: TextLabel
	hint = get(panel, "Hint") :: TextLabel
	list = get(panel, "List") :: ScrollingFrame
	rowTemplate = get(list, "Template") :: TextButton
	sectionTemplate = get(list, "Section") :: TextLabel
	playersList = get(panel, "Players") :: ScrollingFrame
	playerTemplate = get(playersList, "Template") :: TextButton
	local tabs = get(panel, "Tabs")
	tabShop = get(tabs, "TabShop") :: TextButton
	tabTrade = get(tabs, "TabTrade") :: TextButton
end

function VendorController.Start()
	tabShop.Activated:Connect(function()
		setTab("shop")
	end)
	tabTrade.Activated:Connect(function()
		setTab("trade")
	end)
	;(get(panel, "Close") :: TextButton).Activated:Connect(VendorController.Close)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if player == localPlayer and prompt.Name == "ShopPrompt" then
			if panel.Visible then
				VendorController.Close()
			else
				VendorController.Open()
			end
		end
	end)
	-- afastou do vendedor = painel fecha (a mesa de troca é do TradeController e fica)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if not panel.Visible then
			return
		end
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local pos = vendorPosition()
		local root = if localPlayer.Character then localPlayer.Character:FindFirstChild("HumanoidRootPart") else nil
		if pos and root and root:IsA("BasePart") and (root.Position - pos).Magnitude > VendorConfig.Range then
			VendorController.Close()
		end
	end)

	localPlayer:GetAttributeChangedSignal("Coins"):Connect(refreshCoins)
	localPlayer:GetAttributeChangedSignal("EventPoints"):Connect(refreshCoins)
	Remotes.GetEvent(Remotes.Events.NotifyProfile).OnClientEvent:Connect(function(p: any)
		if typeof(p) == "table" then
			profile = p
			if panel.Visible and currentTab == "shop" then
				buildShop()
			end
		end
	end)
	Remotes.GetEvent(Remotes.Events.NotifyVendor).OnClientEvent:Connect(function(event: string, data: any)
		data = if typeof(data) == "table" then data else {}
		if event == "bought" then
			local what = if data.kind == "character" then "Personagem" else "Item"
			setHint(("%s comprado: %s (-%d %s)"):format(what, tostring(data.name), tonumber(data.price) or 0, if data.currency == "event" then "de evento" else "pts"), 4)
			FX.PlaySoundUI("Match", "Victory")
			if data.kind == "character" then
				local def = CharacterDefs.Get(tostring(data.id))
				if def then
					setHint(("%s desbloqueado! Escolha em Personagens (V)."):format(def.DisplayName), 5)
				end
			end
			if panel.Visible and currentTab == "shop" then
				task.delay(0.2, buildShop)
			end
		elseif event == "denied" then
			setHint(DENY_TEXT[tostring(data.reason)] or tostring(data.reason), 4)
		end
	end)
	Players.PlayerAdded:Connect(function()
		if panel.Visible and currentTab == "trade" then
			buildPlayers()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if panel.Visible and currentTab == "trade" then
			task.defer(buildPlayers)
		end
	end)
	Log.debug(("[VendorController] pronto (%d itens; roleta %d pts)"):format(#VendorConfig.Catalog(), CosmeticsConfig.RollCost))
end

return VendorController
