--!strict
--[[
	LobbyController (cliente)
	UI mínima do lobby/partida (TODO: substituir pela HUD/arte final):
	  - faixa no topo com estado do round e cronômetro
	  - painel de seleção de personagem (visível fora do round)
	  - botão entrar/sair da fila
	Só envia RequestSelectCharacter / RequestQueue e reage a NotifyMatchState
	e aos atributos do Player (CharacterId, InQueue, InMatch).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))

local LobbyController = {}

local localPlayer = Players.LocalPlayer

local requestSelectCharacter: RemoteEvent
local requestQueue: RemoteEvent

local currentState = "Waiting"
local stateData: { [string]: any } = {}

local statusLabel: TextLabel
local selectPanel: Frame
local queueButton: TextButton
local characterButtons: { [string]: TextButton } = {}

local STATE_TEXT = {
	Waiting = "Aguardando jogadores",
	Selecting = "Escolha seu personagem",
	InProgress = "Round em andamento",
	Ending = "Fim do round",
}

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------

local function makeButton(parent: Instance, text: string, size: UDim2, pos: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	b.AutoButtonColor = true
	b.Parent = parent
	return b
end

local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyUI"
	gui.ResetOnSpawn = false

	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(0, 420, 0, 44)
	statusLabel.Position = UDim2.new(0.5, -210, 0, 8)
	statusLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	statusLabel.BackgroundTransparency = 0.4
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 18
	statusLabel.Text = ""
	statusLabel.Parent = gui

	selectPanel = Instance.new("Frame")
	selectPanel.Size = UDim2.new(0, 360, 0, 60 + 44 * #CharacterDefs.Order)
	selectPanel.Position = UDim2.new(0.5, -180, 0.5, -selectPanel.Size.Y.Offset / 2)
	selectPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	selectPanel.BackgroundTransparency = 0.15
	selectPanel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "Personagem"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = selectPanel

	for i, id in CharacterDefs.Order do
		local def = CharacterDefs.Get(id)
		local b = makeButton(selectPanel, def and def.DisplayName or id, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 40 + (i - 1) * 44))
		b.Activated:Connect(function()
			requestSelectCharacter:FireServer(id)
		end)
		characterButtons[id] = b
	end

	queueButton = makeButton(gui, "", UDim2.new(0, 200, 0, 36), UDim2.new(0.5, -100, 1, -50))
	queueButton.Activated:Connect(function()
		requestQueue:FireServer(localPlayer:GetAttribute("InQueue") ~= true)
	end)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

local function refresh()
	local now = Workspace:GetServerTimeNow()
	local text = STATE_TEXT[currentState] or currentState
	local endsAt = stateData.endsAt
	if typeof(endsAt) == "number" then
		text ..= ("  %ds"):format(math.max(0, math.ceil(endsAt - now)))
	end
	if currentState == "Waiting" and stateData.needed then
		text ..= ("  (%s/%d na fila)"):format(tostring(stateData.queued or 0), stateData.needed)
	elseif currentState == "InProgress" and stateData.alive then
		text ..= ("  vivos: %d"):format(stateData.alive)
	elseif currentState == "Ending" then
		local winners = stateData.winners
		if typeof(winners) == "table" and #winners > 0 then
			text ..= "  vencedor: " .. table.concat(winners, ", ")
		else
			text ..= "  empate"
		end
	end
	statusLabel.Text = text

	local inMatch = localPlayer:GetAttribute("InMatch") == true
	selectPanel.Visible = not inMatch and (currentState == "Waiting" or currentState == "Selecting")
	queueButton.Visible = not inMatch
	queueButton.Text = if localPlayer:GetAttribute("InQueue") == true then "Sair da fila" else "Entrar na fila"

	local currentId = localPlayer:GetAttribute("CharacterId")
	for id, b in characterButtons do
		b.BackgroundColor3 = if id == currentId then Color3.fromRGB(40, 120, 220) else Color3.fromRGB(50, 50, 60)
	end
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function LobbyController.Init()
	requestSelectCharacter = Remotes.GetEvent(Remotes.Events.RequestSelectCharacter)
	requestQueue = Remotes.GetEvent(Remotes.Events.RequestQueue)
end

function LobbyController.Start()
	buildUI()
	Remotes.GetEvent(Remotes.Events.NotifyMatchState).OnClientEvent:Connect(function(state: string, data: any)
		currentState = state
		stateData = if typeof(data) == "table" then data else {}
		if state == "Ending" or state == "InProgress" then
			-- TODO(launch): reduzir log
			print(("[LobbyController] %s %s"):format(state, if stateData.winners then table.concat(stateData.winners, ", ") else ""))
		end
		refresh()
	end)
	for _, attr in { "InMatch", "InQueue", "CharacterId" } do
		localPlayer:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			refresh()
		end
	end)
	refresh()
	-- TODO(launch): reduzir log
	print("[LobbyController] pronto")
end

return LobbyController
