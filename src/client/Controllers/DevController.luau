--!strict
--[[
	DevController (cliente)
	Menu de desenvolvedor (StarterGui.DevGui). Só aparece para Players com atributo
	IsDeveloper (definido por AdminService a partir dos nicks em AdminConfig).
	Nenhuma decisão aqui: todo botão vira RequestAdminCommand e o servidor valida.

	Abrir: ícone "Dev" no topbar (TopbarPlus) ou a tecla TOGGLE_KEY (F8).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local Log = require(Modules:WaitForChild("Log"))
local Icon = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Icon"))

local DevController = {}

local TOGGLE_KEY = Enum.KeyCode.F8
local MAX_LOG_LINES = 6

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local panel: Frame
local targetsList: ScrollingFrame
local targetTemplate: TextButton
local charactersList: Frame
local charTemplate: TextButton
local amountBox: TextBox
local logLabel: TextLabel

local loggedIn = false
local selectedTarget: string? = nil -- nome do jogador; nil = eu
local logLines: { string } = {}
local requestCommand: RemoteEvent
local devIcon: any = nil

local function get(parent: Instance, name: string): Instance
	local inst = parent:FindFirstChild(name)
	assert(inst, ("[DevController] faltando %s em %s"):format(name, parent:GetFullName()))
	return inst
end

local function appendLog(ok: boolean, message: string)
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

local function amount(): number?
	return tonumber(amountBox.Text)
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
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	for i, p in list do
		local b = targetTemplate:Clone()
		local isMe = p == localPlayer
		local isSelected = (selectedTarget == nil and isMe) or selectedTarget == p.Name
		b.Name = p.Name
		b.Text = if isMe then "Eu (" .. p.Name .. ")" else p.Name
		b.LayoutOrder = if isMe then 0 else i
		b.Visible = true
		b.BackgroundColor3 = if isSelected then Color3.fromRGB(90, 165, 255) else Color3.fromRGB(33, 33, 43)
		b.MouseButton1Click:Connect(function()
			selectedTarget = if isMe then nil else p.Name
			refreshTargets()
		end)
		b.Parent = targetsList
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
-- Abrir / login
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
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function DevController.Init()
	requestCommand = Remotes.GetEvent(Remotes.Events.RequestAdminCommand)
	-- PlayerGui recebe as telas do StarterGui só no spawn; espera em vez de falhar
	local gui = playerGui:WaitForChild("DevGui", 15)
	assert(gui, "[DevController] StarterGui.DevGui não chegou (Rojo conectado?)")
	panel = get(gui, "Panel") :: Frame
	targetsList = get(panel, "Targets") :: ScrollingFrame
	targetTemplate = get(targetsList, "Template") :: TextButton
	charactersList = get(panel, "Characters") :: Frame
	charTemplate = get(charactersList, "Template") :: TextButton
	amountBox = get(panel, "Amount") :: TextBox
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

	;(get(panel, "SetCoins") :: TextButton).MouseButton1Click:Connect(function()
		send("SetCoins", { amount = amount() })
	end)
	;(get(panel, "AddCoins") :: TextButton).MouseButton1Click:Connect(function()
		send("AddCoins", { amount = amount() })
	end)
	;(get(panel, "SetEnergy") :: TextButton).MouseButton1Click:Connect(function()
		send("SetEnergy", { amount = amount() })
	end)
	for _, command in { "Heal", "Kill", "God", "Teleport", "Bring", "Kick", "ResetData", "ListPlayers" } do
		(get(panel, command) :: TextButton).MouseButton1Click:Connect(function()
			send(command)
		end)
	end
	buildCharacters()

	Remotes.GetEvent(Remotes.Events.NotifyAdminResult).OnClientEvent:Connect(function(ok: boolean, message: string)
		appendLog(ok == true, tostring(message))
	end)
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
