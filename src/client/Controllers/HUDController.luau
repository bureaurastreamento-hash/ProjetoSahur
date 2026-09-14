--!strict
--[[
	HUDController (cliente)
	Liga as telas de StarterGui (HUD, CharacterSelect — criadas via Rojo em src/ui/)
	ao estado que vem do servidor. NÃO calcula vida nem cooldown: só mostra o que
	chegou por RemoteEvent ou por atributo replicado do servidor.

	Fontes de verdade:
	  NotifyHealth(current, max)                 -> barra de vida própria
	  Player attr Energy / CharacterId           -> barra de energia, slots, seleção
	  NotifyAbilityCooldown (via AbilityController.CooldownChanged) -> overlay dos slots
	  NotifyAbilityDenied                        -> pisca o slot
	  NotifyMatchState(state, data)              -> topo, placar, banner, tela de seleção
	  NotifyKill(killer, victim)                 -> killfeed
	  Humanoid.Health dos outros (replicado)     -> barra sobre a cabeça
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local FX = require(Modules:WaitForChild("FX"))
local AbilityController = require(script.Parent:WaitForChild("AbilityController"))

local HUDController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local SLOT_KEYS = { "Q", "E", "R" }
local KILLFEED_MAX = 5
local KILLFEED_LIFETIME = 6

local STATE_TEXT = {
	Waiting = "Aguardando jogadores",
	Selecting = "Escolha seu personagem",
	InProgress = "Round em andamento",
	Ending = "Fim do round",
}

-- refs de UI
local hud: ScreenGui
local selectGui: ScreenGui
local stateLabel: TextLabel
local timerLabel: TextLabel
local healthFill: Frame
local healthText: TextLabel
local energyFill: Frame
local energyText: TextLabel
local characterNameLabel: TextLabel
local slots: { Frame } = {}
local killFeed: Frame
local killTemplate: TextLabel
local scoreboard: Frame
local scoreList: Frame
local scoreTemplate: TextLabel
local banner: TextLabel
local selectList: Frame
local selectTemplate: TextButton
local selectHint: TextLabel
local queueButton: TextButton
local coinsLabel: TextLabel
local selectCoinsLabel: TextLabel
local characterButtons: { [string]: TextButton } = {}
local profile: any = nil

local currentState = "Waiting"
local stateData: { [string]: any } = {}
local overheads: { [Model]: BillboardGui } = {}

local requestSelectCharacter: RemoteEvent
local requestQueue: RemoteEvent
local requestUnlockCharacter: RemoteEvent

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function get(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child, ("[HUDController] elemento '%s' não encontrado em %s"):format(name, parent:GetFullName()))
	return child
end

local function setBar(fill: Frame, text: TextLabel, current: number, max: number)
	local ratio = if max > 0 then math.clamp(current / max, 0, 1) else 0
	TweenService:Create(fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(ratio, 1) }):Play()
	text.Text = ("%d / %d"):format(math.floor(current + 0.5), max)
end

local function showBanner(text: string, seconds: number)
	banner.Text = text
	banner.Visible = true
	task.delay(seconds, function()
		if banner.Text == text then
			banner.Visible = false
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Slots de habilidade
-- ---------------------------------------------------------------------------

local function refreshSlots()
	local characterId = localPlayer:GetAttribute("CharacterId")
	local def = if typeof(characterId) == "string" then CharacterDefs.Get(characterId) else nil
	characterNameLabel.Text = if def then def.DisplayName else ""
	for i, slot in slots do
		local ability = def and def.Abilities[i]
		local nameLabel = slot:FindFirstChild("Name") :: TextLabel
		local costLabel = slot:FindFirstChild("Cost") :: TextLabel
		if ability then
			slot.Visible = true
			nameLabel.Text = ability.DisplayName
			costLabel.Text = if ability.EnergyCost > 0 then ("%d energia"):format(ability.EnergyCost) else ""
		else
			slot.Visible = false
		end
	end
end

local function updateCooldowns()
	local now = Workspace:GetServerTimeNow()
	local cooldowns = AbilityController.GetCooldowns()
	local characterId = localPlayer:GetAttribute("CharacterId")
	for i, slot in slots do
		local overlay = slot:FindFirstChild("Cooldown") :: Frame
		local text = slot:FindFirstChild("CooldownText") :: TextLabel
		local cd = cooldowns[i]
		local remaining = if cd then cd.readyAt - now else 0
		if remaining > 0 then
			local ability = if typeof(characterId) == "string" then CharacterDefs.GetAbility(characterId, i) else nil
			local total = if ability then ability.Cooldown else remaining
			overlay.Size = UDim2.fromScale(1, math.clamp(remaining / total, 0, 1))
			text.Text = ("%.1f"):format(remaining)
		else
			overlay.Size = UDim2.fromScale(1, 0)
			text.Text = ""
		end
	end
end

local function flashSlot(slot: number, color: Color3)
	local frame = slots[slot]
	if not frame then
		return
	end
	local original = frame.BackgroundColor3
	frame.BackgroundColor3 = color
	task.delay(0.15, function()
		frame.BackgroundColor3 = original
	end)
end

-- ---------------------------------------------------------------------------
-- Partida / placar / seleção
-- ---------------------------------------------------------------------------

local function refreshScoreboard()
	for _, child in scoreList:GetChildren() do
		if child:IsA("TextLabel") and child ~= scoreTemplate then
			child:Destroy()
		end
	end
	local scores = stateData.scores
	local visible = typeof(scores) == "table" and #scores > 0 and (currentState == "InProgress" or currentState == "Ending")
	scoreboard.Visible = visible
	if not visible then
		return
	end
	for i, entry in scores do
		local row = scoreTemplate:Clone()
		row.Visible = true
		row.LayoutOrder = i
		row.Text = ("%s  %d"):format(entry.name, entry.kills)
		row.TextColor3 = if entry.alive then Color3.new(1, 1, 1) else Color3.fromRGB(140, 140, 140)
		if entry.name == localPlayer.Name then
			row.TextColor3 = if entry.alive then Color3.fromRGB(120, 200, 255) else Color3.fromRGB(80, 120, 150)
		end
		row.Parent = scoreList
	end
end

local function refreshMatchUI()
	stateLabel.Text = STATE_TEXT[currentState] or currentState
	if currentState == "Waiting" and stateData.needed then
		stateLabel.Text ..= ("  (%s/%d)"):format(tostring(stateData.queued or 0), stateData.needed)
	elseif currentState == "InProgress" and stateData.alive then
		stateLabel.Text ..= ("  vivos: %d"):format(stateData.alive)
	end

	local inMatch = localPlayer:GetAttribute("InMatch") == true
	selectGui.Enabled = not inMatch and (currentState == "Waiting" or currentState == "Selecting")
	queueButton.Text = if localPlayer:GetAttribute("InQueue") == true then "Sair da fila" else "Entrar na fila"
	queueButton.BackgroundColor3 = if localPlayer:GetAttribute("InQueue") == true then Color3.fromRGB(160, 60, 60) else Color3.fromRGB(40, 140, 80)
	selectHint.Text = if currentState == "Selecting" then "O round começa em instantes" else "Aguardando jogadores na fila"

	local currentId = localPlayer:GetAttribute("CharacterId")
	for id, b in characterButtons do
		local def = CharacterDefs.Get(id)
		local owned = def ~= nil and (def.UnlockCost <= 0 or (profile ~= nil and table.find(profile.unlockedCharacters, id) ~= nil))
		if owned then
			b.Text = if def then def.DisplayName else id
			b.BackgroundColor3 = if id == currentId then Color3.fromRGB(40, 120, 220) else Color3.fromRGB(50, 50, 60)
		else
			b.Text = ("%s  🔒 %d"):format(if def then def.DisplayName else id, if def then def.UnlockCost else 0)
			b.BackgroundColor3 = Color3.fromRGB(70, 60, 30)
		end
	end
	local coins = localPlayer:GetAttribute("Coins")
	local coinsText = if typeof(coins) == "number" then ("%d moedas"):format(coins) else ""
	coinsLabel.Text = coinsText
	selectCoinsLabel.Text = coinsText
	refreshScoreboard()
end

local function updateTimer()
	local endsAt = stateData.endsAt
	if typeof(endsAt) == "number" then
		local remaining = math.max(0, endsAt - Workspace:GetServerTimeNow())
		timerLabel.Text = ("%d:%02d"):format(remaining // 60, math.floor(remaining % 60))
	else
		timerLabel.Text = ""
	end
end

local function onNotifyMatchState(state: string, data: any)
	currentState = state
	stateData = if typeof(data) == "table" then data else {}
	if state == "Ending" then
		local winners = stateData.winners
		local text = if typeof(winners) == "table" and #winners > 0 then "Vencedor: " .. table.concat(winners, ", ") else "Empate"
		showBanner(text, 6)
		if localPlayer:GetAttribute("InMatch") == true then
			local won = typeof(winners) == "table" and table.find(winners, localPlayer.Name) ~= nil
			FX.PlaySoundUI("Match", if won then "Victory" else "Defeat")
		end
	elseif state == "InProgress" and stateData.eliminated == localPlayer.Name then
		showBanner("Você foi eliminado", 3)
	elseif state == "InProgress" and stateData.mapName and not stateData.eliminated then
		showBanner("LUTEM!", 2)
		if localPlayer:GetAttribute("InMatch") == true then
			FX.PlaySoundUI("Match", "RoundStart")
		end
	end
	refreshMatchUI()
end

-- ---------------------------------------------------------------------------
-- Killfeed
-- ---------------------------------------------------------------------------

local function onNotifyKill(killer: Player?, victim: Player)
	local entry = killTemplate:Clone()
	entry.Visible = true
	entry.Text = if killer then ("%s eliminou %s"):format(killer.Name, victim.Name) else ("%s morreu"):format(victim.Name)
	entry.LayoutOrder = os.clock() * 1000 // 1
	entry.Parent = killFeed
	local entries = {}
	for _, child in killFeed:GetChildren() do
		if child:IsA("TextLabel") and child ~= killTemplate then
			table.insert(entries, child)
		end
	end
	table.sort(entries, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #entries > KILLFEED_MAX do
		local oldest = table.remove(entries, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	task.delay(KILLFEED_LIFETIME, function()
		if entry.Parent then
			entry:Destroy()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Barra de vida dos outros jogadores (Humanoid.Health replicado do servidor)
-- ---------------------------------------------------------------------------

local overheadTemplate: BillboardGui?

local function attachOverhead(player: Player, character: Model)
	if player == localPlayer or not overheadTemplate then
		return
	end
	local head = character:WaitForChild("Head", 5)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not head or not humanoid then
		return
	end
	local gui = overheadTemplate:Clone()
	gui.Adornee = head
	gui.Parent = character
	overheads[character] = gui
	local nameLabel = gui:FindFirstChild("Name") :: TextLabel
	local fill = (gui:FindFirstChild("Bar") :: Frame):FindFirstChild("Fill") :: Frame
	nameLabel.Text = player.Name
	local function update()
		local ratio = if humanoid.MaxHealth > 0 then math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) else 0
		fill.Size = UDim2.fromScale(ratio, 1)
	end
	humanoid.HealthChanged:Connect(update)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	update()
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		attachOverhead(player, character)
	end)
	player.CharacterRemoving:Connect(function(character)
		overheads[character] = nil
	end)
	if player.Character then
		attachOverhead(player, player.Character)
	end
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function HUDController.Init()
	requestSelectCharacter = Remotes.GetEvent(Remotes.Events.RequestSelectCharacter)
	requestQueue = Remotes.GetEvent(Remotes.Events.RequestQueue)
	requestUnlockCharacter = Remotes.GetEvent(Remotes.Events.RequestUnlockCharacter)

	hud = get(playerGui, "HUD") :: ScreenGui
	selectGui = get(playerGui, "CharacterSelect") :: ScreenGui

	local topBar = get(hud, "TopBar")
	stateLabel = get(topBar, "State") :: TextLabel
	timerLabel = get(topBar, "Timer") :: TextLabel

	local vitals = get(hud, "Vitals")
	local health = get(vitals, "Health")
	healthFill = get(health, "Fill") :: Frame
	healthText = get(health, "Text") :: TextLabel
	local energy = get(vitals, "Energy")
	energyFill = get(energy, "Fill") :: Frame
	energyText = get(energy, "Text") :: TextLabel
	characterNameLabel = get(vitals, "CharacterName") :: TextLabel
	coinsLabel = get(vitals, "Coins") :: TextLabel

	local abilities = get(hud, "Abilities")
	for i = 1, #SLOT_KEYS do
		slots[i] = get(abilities, "Slot" .. i) :: Frame
	end

	killFeed = get(hud, "KillFeed") :: Frame
	killTemplate = get(killFeed, "Template") :: TextLabel
	scoreboard = get(hud, "Scoreboard") :: Frame
	scoreList = get(scoreboard, "List") :: Frame
	scoreTemplate = get(scoreList, "Template") :: TextLabel
	banner = get(hud, "Banner") :: TextLabel

	local panel = get(selectGui, "Panel")
	selectList = get(panel, "List") :: Frame
	selectTemplate = get(selectList, "Template") :: TextButton
	selectHint = get(panel, "Hint") :: TextLabel
	queueButton = get(panel, "QueueButton") :: TextButton
	selectCoinsLabel = get(panel, "Coins") :: TextLabel

	local uiAssets = ReplicatedStorage:FindFirstChild("Assets")
	local uiFolder = uiAssets and uiAssets:FindFirstChild("UI")
	overheadTemplate = uiFolder and uiFolder:FindFirstChild("OverheadHealth") :: BillboardGui?
	if not overheadTemplate then
		warn("[HUDController] Assets.UI.OverheadHealth não encontrado; sem barra sobre a cabeça")
	end
end

function HUDController.Start()
	-- Botões de personagem
	for i, id in CharacterDefs.Order do
		local def = CharacterDefs.Get(id)
		local b = selectTemplate:Clone()
		b.Visible = true
		b.LayoutOrder = i
		b.Text = if def then def.DisplayName else id
		b.Parent = selectList
		b.Activated:Connect(function()
			local owned = def ~= nil and (def.UnlockCost <= 0 or (profile ~= nil and table.find(profile.unlockedCharacters, id) ~= nil))
			if owned then
				requestSelectCharacter:FireServer(id)
			else
				requestUnlockCharacter:FireServer(id)
			end
		end)
		characterButtons[id] = b
	end
	queueButton.Activated:Connect(function()
		requestQueue:FireServer(localPlayer:GetAttribute("InQueue") ~= true)
	end)

	-- Servidor -> HUD
	Remotes.GetEvent(Remotes.Events.NotifyHealth).OnClientEvent:Connect(function(current: number, max: number)
		setBar(healthFill, healthText, current, max)
	end)
	Remotes.GetEvent(Remotes.Events.NotifyMatchState).OnClientEvent:Connect(onNotifyMatchState)
	Remotes.GetEvent(Remotes.Events.NotifyKill).OnClientEvent:Connect(onNotifyKill)
	Remotes.GetEvent(Remotes.Events.NotifyProfile).OnClientEvent:Connect(function(data: any, sessionOnly: boolean)
		profile = data
		if sessionOnly then
			showBanner("Sem conexão com os dados: progresso desta sessão não será salvo", 6)
		end
		refreshMatchUI()
	end)
	Remotes.GetEvent(Remotes.Events.NotifyUnlockDenied).OnClientEvent:Connect(function(characterId: string, reason: string)
		local msgs = { coins = "Moedas insuficientes", locked = "Personagem bloqueado", not_loaded = "Dados ainda carregando", already_owned = "Já desbloqueado" }
		showBanner(("%s: %s"):format(characterId, msgs[reason] or reason), 3)
	end)
	localPlayer:GetAttributeChangedSignal("Coins"):Connect(refreshMatchUI)
	Remotes.GetEvent(Remotes.Events.NotifyAbilityDenied).OnClientEvent:Connect(function(slot: number)
		flashSlot(slot, Color3.fromRGB(160, 40, 40))
	end)
	AbilityController.CooldownChanged.Event:Connect(function(slot: number)
		flashSlot(slot, Color3.fromRGB(60, 120, 200))
		updateCooldowns()
	end)

	-- Atributos replicados do servidor
	local function refreshEnergy()
		local e = localPlayer:GetAttribute("Energy")
		setBar(energyFill, energyText, if typeof(e) == "number" then e else 0, CharacterDefs.Energy.Max)
	end
	localPlayer:GetAttributeChangedSignal("Energy"):Connect(refreshEnergy)
	localPlayer:GetAttributeChangedSignal("CharacterId"):Connect(function()
		refreshSlots()
		refreshMatchUI()
	end)
	for _, attr in { "InMatch", "InQueue" } do
		localPlayer:GetAttributeChangedSignal(attr):Connect(refreshMatchUI)
	end

	-- Barras dos outros jogadores
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	-- Loop leve para timer e cooldowns
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			updateTimer()
			updateCooldowns()
		end
	end)

	refreshSlots()
	refreshEnergy()
	refreshMatchUI()
	Log.debug("[HUDController] pronto")
end

return HUDController
