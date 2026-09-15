--!strict
--[[
	DevController (cliente)
	Menu de desenvolvedor (StarterGui.DevGui, gerado por tools/gerar_devgui.py).
	Só aparece para Players com atributo IsDeveloper (AdminService, nicks em AdminConfig).
	Nenhuma decisão aqui: cada botão vira RequestAdminCommand(nomeDoBotão, args) e o
	servidor valida; o resultado volta por NotifyAdminResult(ok, msg, state) e o painel
	redesenha os toggles com o estado real do alvo.

	Abrir: ícone "Dev" no topbar (TopbarPlus) ou F8.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local Log = require(Modules:WaitForChild("Log"))
local ContentProvider = game:GetService("ContentProvider")
local PackSounds = require(Modules:WaitForChild("PackSounds"))
local VfxPreviewController = require(script.Parent:WaitForChild("VfxPreviewController"))
local Icon = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Icon"))

local DevController = {}

local TOGGLE_KEY = Enum.KeyCode.F8
local MAX_LOG_LINES = 5
local ALL = "*"

local COLOR_OFF = Color3.fromRGB(33, 33, 43)
local COLOR_ON = Color3.fromRGB(60, 140, 90)
local COLOR_SELECTED = Color3.fromRGB(90, 165, 255)

-- Botão -> comando com o valor de qual TextBox (nil = sem args)
local NUMBER_COMMANDS: { [string]: string } = {
	SetCoins = "Coins",
	AddCoins = "Coins",
	SetEnergy = "Energy",
	SetHealth = "Health",
	SetSpeed = "Speed",
	SetDamageMult = "DamageMult",
	SetTime = "Time",
}
local SIMPLE_COMMANDS = {
	"InfiniteEnergy", "NoCooldown", "God", "ClearFlags", "ResetCooldowns", "Heal", "Respawn", "Kill",
	"GrantAll", "RevokeAll", "Teleport", "Bring", "Kick", "ResetData",
	"RespawnDummies", "ToggleDummies", "RefreshLeaderboard", "ServerInfo", "ListPlayers", "GetState", "TestSounds",
}
local TOGGLE_BUTTONS: { [string]: string } = { InfiniteEnergy = "infiniteEnergy", NoCooldown = "noCooldown", God = "god" }

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local panel: Frame
local targetsList: ScrollingFrame
local targetTemplate: TextButton
local charactersList: Frame
local charTemplate: TextButton
local stateLabel: TextLabel
local logLabel: TextLabel

local loggedIn = false
local selectedTarget: string? = nil -- nil = eu; "*" = todos; senão nome
local logLines: { string } = {}
local requestCommand: RemoteEvent
local devIcon: any = nil

local function get(parent: Instance, name: string): Instance
	local inst = parent:FindFirstChild(name)
	assert(inst, ("[DevController] faltando %s em %s"):format(name, parent:GetFullName()))
	return inst
end

local function appendLog(ok: boolean, message: string)
	if message == "" then
		return
	end
	table.insert(logLines, 1, (if ok then "✔ " else "✖ ") .. message)
	while #logLines > MAX_LOG_LINES do
		table.remove(logLines)
	end
	logLabel.Text = table.concat(logLines, "\n")
	logLabel.TextColor3 = if ok then Color3.fromRGB(190, 230, 190) else Color3.fromRGB(240, 170, 160)
end

local function send(command: string, args: { [string]: any }?)
	local payload: { [string]: any } = args or {}
	payload.target = selectedTarget
	requestCommand:FireServer(command, payload)
end

local function requestState()
	if selectedTarget ~= ALL then
		send("GetState")
	else
		stateLabel.Text = "alvo: TODOS os jogadores"
	end
end

-- ---------------------------------------------------------------------------
-- Estado do alvo
-- ---------------------------------------------------------------------------

local function renderState(state: { [string]: any })
	local unlocked = if typeof(state.unlocked) == "table" then table.concat(state.unlocked, ",") else "?"
	stateLabel.Text = ("%s (%d)%s · %s · moedas %d · kills %d · vida %d/%d · energia %s · speed %d · dano x%s\npersonagens: %s"):format(
		tostring(state.name), tonumber(state.userId) or 0, if state.sessionOnly then " [SEM SAVE]" else "",
		tostring(state.characterId), tonumber(state.coins) or 0, tonumber(state.kills) or 0,
		math.floor(tonumber(state.health) or 0), math.floor(tonumber(state.maxHealth) or 0),
		tostring(state.energy), math.floor(tonumber(state.speed) or 0), tostring(state.damageMult),
		unlocked
	)
	for buttonName, key in TOGGLE_BUTTONS do
		local b = panel:FindFirstChild(buttonName) :: TextButton?
		if b then
			b.BackgroundColor3 = if state[key] == true then COLOR_ON else COLOR_OFF
		end
	end
	for _, id in CharacterDefs.Order do
		local b = charactersList:FindFirstChild(id) :: TextButton?
		if b then
			local owned = typeof(state.unlocked) == "table" and table.find(state.unlocked, id) ~= nil
			local def = CharacterDefs.Get(id)
			owned = owned or (def ~= nil and def.UnlockCost <= 0)
			b.BackgroundColor3 = if state.characterId == id then COLOR_SELECTED elseif owned then COLOR_ON else COLOR_OFF
		end
	end
end

-- ---------------------------------------------------------------------------
-- Alvos / personagens
-- ---------------------------------------------------------------------------

local function refreshTargets()
	for _, child in targetsList:GetChildren() do
		if child:IsA("TextButton") and child ~= targetTemplate then
			child:Destroy()
		end
	end
	local function add(text: string, value: string?, order: number)
		local b = targetTemplate:Clone()
		b.Name = value or "me"
		b.Text = text
		b.LayoutOrder = order
		b.Visible = true
		b.BackgroundColor3 = if selectedTarget == value then COLOR_SELECTED else COLOR_OFF
		b.MouseButton1Click:Connect(function()
			selectedTarget = value
			refreshTargets()
			requestState()
		end)
		b.Parent = targetsList
	end
	add("Eu (" .. localPlayer.Name .. ")", nil, 0)
	add("TODOS", ALL, 1)
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	for i, p in list do
		if p ~= localPlayer then
			add(p.Name, p.Name, i + 1)
		end
	end
end

local function buildCharacters()
	for _, id in CharacterDefs.Order do
		local def = CharacterDefs.Get(id)
		if not def then
			continue
		end
		local b = charTemplate:Clone()
		b.Name = id
		b.Text = def.DisplayName
		b.Visible = true
		b.MouseButton1Click:Connect(function()
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
				send("GrantCharacter", { characterId = id })
			elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
				send("RevokeCharacter", { characterId = id })
			else
				send("SetCharacter", { characterId = id })
			end
		end)
		b.Parent = charactersList
	end
end

-- ---------------------------------------------------------------------------
-- Teste de sons dos packs (quais ids a Roblox deixa este jogo tocar)
-- ---------------------------------------------------------------------------

local probing = false
local function probeSounds()
	if probing then
		return
	end
	probing = true
	task.spawn(function()
		local okCount, failCount = 0, 0
		local BATCH = 50
		for start = 1, #PackSounds, BATCH do
			local sounds: { Instance } = {}
			local byInstance: { [Instance]: any } = {}
			for i = start, math.min(start + BATCH - 1, #PackSounds) do
				local entry = PackSounds[i]
				local sound = Instance.new("Sound")
				sound.SoundId = "rbxassetid://" .. tostring(entry.id)
				table.insert(sounds, sound)
				byInstance[sound] = entry
			end
			pcall(function()
				ContentProvider:PreloadAsync(sounds, function(assetId: string, status: Enum.AssetFetchStatus)
					local id = assetId:match("(%d+)")
					for sound, entry in byInstance do
						if tostring(entry.id) == id then
							local ok = status == Enum.AssetFetchStatus.Success
							if ok then
								okCount += 1
							else
								failCount += 1
							end
							warn(("[SoundProbe] %s %s %d %s <%s>"):format(if ok then "OK" else "FAIL", entry.pack, entry.id, entry.name, entry.path))
							byInstance[sound] = nil
							break
						end
					end
				end)
			end)
			for _, sound in sounds do
				sound:Destroy()
			end
			appendLog(true, ("sons: %d/%d testados (ok %d, falha %d)"):format(math.min(start + BATCH - 1, #PackSounds), #PackSounds, okCount, failCount))
			task.wait(0.1)
		end
		warn(("[SoundProbe] FIM ok=%d falha=%d"):format(okCount, failCount))
		probing = false
	end)
end

-- ---------------------------------------------------------------------------
-- Abrir
-- ---------------------------------------------------------------------------

local function setOpen(open: boolean)
	if not open then
		panel.Visible = false
		if devIcon then
			devIcon:deselect()
		end
		return
	end
	if not loggedIn then
		local ok, result = pcall(function()
			return Remotes.GetFunction(Remotes.Functions.FetchAdminLogin):InvokeServer()
		end)
		loggedIn = ok and result == true
		if not loggedIn then
			appendLog(false, "servidor recusou (nick não está em AdminConfig)")
		end
	end
	panel.Visible = true
	refreshTargets()
	requestState()
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function DevController.Init()
	requestCommand = Remotes.GetEvent(Remotes.Events.RequestAdminCommand)
	local gui = playerGui:WaitForChild("DevGui", 15)
	assert(gui, "[DevController] StarterGui.DevGui não chegou (Rojo conectado?)")
	panel = get(gui, "Panel") :: Frame
	targetsList = get(panel, "Targets") :: ScrollingFrame
	targetTemplate = get(targetsList, "Template") :: TextButton
	charactersList = get(panel, "Characters") :: Frame
	charTemplate = get(charactersList, "Template") :: TextButton
	stateLabel = get(panel, "State") :: TextLabel
	logLabel = get(panel, "Log") :: TextLabel
end

function DevController.Start()
	local function enable()
		if devIcon then
			return
		end
		devIcon = Icon.new()
			:setLabel("Dev")
			:setCaption("Menu de desenvolvedor")
			:setCaptionHint(TOGGLE_KEY)
			:bindToggleKey(TOGGLE_KEY)
			:setOrder(9)
			:autoDeselect(false)
		devIcon.toggled:Connect(function(isSelected: boolean)
			setOpen(isSelected)
		end)
		Log.debug("[DevController] jogador é desenvolvedor; ícone Dev ativo")
	end
	if localPlayer:GetAttribute("IsDeveloper") == true then
		enable()
	end
	localPlayer:GetAttributeChangedSignal("IsDeveloper"):Connect(function()
		if localPlayer:GetAttribute("IsDeveloper") == true then
			enable()
		end
	end)

	;(get(panel, "Close") :: TextButton).MouseButton1Click:Connect(function()
		setOpen(false)
	end)
	;(get(panel, "PreviewVfx") :: TextButton).MouseButton1Click:Connect(function()
		VfxPreviewController.SetOpen(true)
	end)
	for command, boxName in NUMBER_COMMANDS do
		local box = get(panel, boxName) :: TextBox
		;(get(panel, command) :: TextButton).MouseButton1Click:Connect(function()
			send(command, { amount = tonumber(box.Text) })
		end)
	end
	for _, command in SIMPLE_COMMANDS do
		(get(panel, command) :: TextButton).MouseButton1Click:Connect(function()
			send(command)
		end)
	end
	buildCharacters()

	Remotes.GetEvent(Remotes.Events.NotifyAdminResult).OnClientEvent:Connect(function(ok: boolean, message: string, state: any)
		appendLog(ok == true, tostring(message))
		if typeof(state) == "table" and state.testSounds == true then
			probeSounds()
		elseif typeof(state) == "table" and selectedTarget ~= ALL then
			renderState(state)
		end
	end)
	-- Estado muda por fora (kill, moedas ganhas...): reflete nos toggles do alvo "eu"
	for _, attr in { "Energy", "Coins", "CharacterId", "Invulnerable", "DevInfiniteEnergy", "DevNoCooldown" } do
		localPlayer:GetAttributeChangedSignal(attr):Connect(function()
			if panel.Visible and selectedTarget == nil then
				requestState()
			end
		end)
	end
	Players.PlayerAdded:Connect(function()
		if panel.Visible then
			refreshTargets()
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		if selectedTarget == p.Name then
			selectedTarget = nil
		end
		if panel.Visible then
			refreshTargets()
		end
	end)
end

return DevController
