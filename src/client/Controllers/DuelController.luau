--!strict
--[[
	DuelController (cliente)
	UI dos duelos (StarterGui.DuelGui):
	  Panel      -> aba 1v1: lista de jogadores (clique = desafiar), cancelar/desistir
	                aba 2v2: salas abertas (clique = entrar), criar sala, trocar de time, sair
	  Invite     -> convite recebido (Aceitar Y / Recusar N)
	  DuelStatus -> contagem/timer/resultado no topo durante o duelo
	Só reflete NotifyDuel; toda decisão é do DuelService.
	O ícone "Duelo" do topo é criado pelo TopbarController (bindToggleItem no Panel).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local FX = require(Modules:WaitForChild("FX"))

local DuelController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local panel: Frame
local list: ScrollingFrame
local rowTemplate: TextButton
local statusLabel: TextLabel
local leaveButton: TextButton
local cancelButton: TextButton
local inviteFrame: Frame
local inviteText: TextLabel
local duelStatus: TextLabel
local requestDuel: RemoteEvent
local hint: TextLabel
local tab1v1: TextButton
local tab2v2: TextButton
local createRoomButton: TextButton
local switchTeamButton: TextButton
local leaveRoomButton: TextButton

local inDuel = false
local pendingInvite = false -- convite recebido aberto
local outgoing = false -- desafio enviado esperando resposta
local timerEndsAt: number? = nil
local timerPrefix = ""
local mode: "1v1" | "2v2" = "1v1"
local rooms: { any } = {} -- última lista de salas recebida do servidor
local myRoomHost: number? = nil -- userId do dono da sala em que estou

local TAB_ON = Color3.fromRGB(70, 140, 217)
local TAB_OFF = Color3.fromRGB(46, 46, 61)
local HINT_1V1 = "Clique em um jogador para desafiar. Vitória = +50 moedas."
local HINT_2V2 = "Entre em uma sala ou crie a sua. Com 4 jogadores o duelo começa sozinho."

local REASONS = {
	expired = "O desafio expirou.",
	declined = "%s recusou o desafio.",
	cancelled = "%s cancelou o desafio.",
	unavailable = "%s não está mais disponível.",
}

local function get(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child, ("[DuelController] '%s' não encontrado em %s"):format(name, parent:GetFullName()))
	return child
end

local function setStatus(text: string)
	statusLabel.Text = text
end

local function refreshButtons()
	leaveButton.Visible = inDuel
	cancelButton.Visible = outgoing and not inDuel
	local inRoom = myRoomHost ~= nil
	createRoomButton.Visible = mode == "2v2" and not inDuel and not inRoom and not outgoing
	switchTeamButton.Visible = mode == "2v2" and inRoom and not inDuel
	leaveRoomButton.Visible = mode == "2v2" and inRoom and not inDuel
end

local function clearList()
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") and child ~= rowTemplate then
			child:Destroy()
		end
	end
end

local function addRow(name: string, text: string, actionText: string, color: Color3, onClick: (() -> ())?): TextButton
	local row = rowTemplate:Clone()
	row.Name = name
	row.Text = text
	local action = row:FindFirstChild("Action") :: TextLabel
	action.Text = actionText
	action.TextColor3 = color
	row.Visible = true
	row.Parent = list
	if onClick then
		row.MouseButton1Click:Connect(onClick)
	end
	return row
end

-- ---------------------------------------------------------------------------
-- Lista de jogadores
-- ---------------------------------------------------------------------------

local GRAY = Color3.fromRGB(160, 160, 170)
local GREEN = Color3.fromRGB(120, 220, 150)
local TEAM_COLORS = { Color3.fromRGB(110, 170, 255), Color3.fromRGB(255, 140, 110) }

local function refreshPlayers()
	clearList()
	local count = 0
	for _, player in Players:GetPlayers() do
		if player == localPlayer then
			continue
		end
		count += 1
		local text = "  " .. player.DisplayName .. if player.DisplayName ~= player.Name then " (@" .. player.Name .. ")" else ""
		local busy = player:GetAttribute("InMatch") == true
		addRow(player.Name, text, if busy then "EM DUELO" else "DESAFIAR", if busy then GRAY else GREEN, function()
			if inDuel or outgoing or myRoomHost then
				return
			end
			requestDuel:FireServer("challenge", player.UserId)
		end)
	end
	if count == 0 then
		setStatus("Ninguém mais no servidor para desafiar.")
	end
end

local function refreshRooms()
	clearList()
	if myRoomHost then
		-- dentro de uma sala: mostra os membros por time
		local room = nil
		for _, r in rooms do
			if r.hostUserId == myRoomHost then
				room = r
			end
		end
		if room then
			local size = tonumber(room.size) or 4
			for teamId = 1, 2 do
				local n = 0
				for _, m in room.members do
					if m.teamId == teamId then
						n += 1
						local me = m.userId == localPlayer.UserId
						addRow(tostring(m.name), "  " .. tostring(m.name) .. if me then " (você)" else "", "TIME " .. teamId, TEAM_COLORS[teamId])
					end
				end
				for _ = n + 1, size // 2 do
					addRow("vaga", "  (vaga)", "TIME " .. teamId, GRAY)
				end
			end
			setStatus(("Sala de %s: %d/%d jogadores."):format(tostring(room.hostName), #room.members, size))
		end
		return
	end
	local count = 0
	for _, r in rooms do
		count += 1
		local size = tonumber(r.size) or 4
		local full = #r.members >= size
		addRow(tostring(r.hostName), ("  Sala de %s (%d/%d)"):format(tostring(r.hostName), #r.members, size), if full then "CHEIA" else "ENTRAR", if full then GRAY else GREEN, function()
			if inDuel or outgoing or myRoomHost or full then
				return
			end
			requestDuel:FireServer("join_room", r.hostUserId)
		end)
	end
	if count == 0 then
		setStatus("Nenhuma sala aberta. Crie a sua!")
	end
end

local function refreshList()
	if mode == "2v2" then
		refreshRooms()
	else
		refreshPlayers()
	end
end

local function setMode(newMode: "1v1" | "2v2")
	mode = newMode
	tab1v1.BackgroundColor3 = if mode == "1v1" then TAB_ON else TAB_OFF
	tab2v2.BackgroundColor3 = if mode == "2v2" then TAB_ON else TAB_OFF
	hint.Text = if mode == "2v2" then HINT_2V2 else HINT_1V1
	if mode == "2v2" then
		requestDuel:FireServer("list_rooms")
	end
	refreshList()
	refreshButtons()
end

-- ---------------------------------------------------------------------------
-- Eventos do servidor
-- ---------------------------------------------------------------------------

local function showInvite(fromName: string)
	pendingInvite = true
	inviteText.Text = ("%s te desafiou para um duelo!"):format(fromName)
	inviteFrame.Visible = true
	FX.PlaySoundUI("Shared", "UltReady")
end

local function hideInvite()
	pendingInvite = false
	inviteFrame.Visible = false
end

local function onNotifyDuel(event: string, data: any)
	data = if typeof(data) == "table" then data else {}
	if event == "invite" then
		showInvite(tostring(data.fromName))
	elseif event == "invite_sent" then
		outgoing = true
		setStatus(("Desafio enviado para %s. Aguardando..."):format(tostring(data.targetName)))
	elseif event == "invite_closed" then
		outgoing = false
		hideInvite()
		local fmt = REASONS[data.reason] or "Desafio encerrado."
		setStatus(fmt:format(tostring(data.other)))
	elseif event == "denied" then
		outgoing = false
		setStatus(tostring(data.reason))
	elseif event == "rooms" then
		rooms = if typeof(data.rooms) == "table" then data.rooms else {}
		if mode == "2v2" and panel.Visible then
			refreshRooms()
		end
	elseif event == "room_joined" then
		myRoomHost = tonumber(data.hostUserId)
		if mode ~= "2v2" then
			setMode("2v2")
		end
		setStatus("Você entrou na sala. Aguardando jogadores...")
	elseif event == "room_left" then
		myRoomHost = nil
		setStatus(if data.reason == "unavailable" then "A sala foi desfeita." else "Você saiu da sala.")
		if mode == "2v2" and panel.Visible then
			refreshRooms()
		end
	elseif event == "start" then
		inDuel = true
		outgoing = false
		myRoomHost = nil
		hideInvite()
		panel.Visible = false
		timerPrefix = "Preparar... "
		timerEndsAt = tonumber(data.endsAt)
		duelStatus.Visible = true
		setStatus("Em duelo.")
		FX.PlaySoundUI("Match", "RoundStart")
	elseif event == "state" then
		if data.eliminated == localPlayer.Name then
			setStatus(if data.reason == "fell" then "Você caiu da arena." else "Você foi eliminado.")
		elseif data.eliminated then
			setStatus(("%s foi eliminado."):format(tostring(data.eliminated)))
		end
		if timerPrefix ~= "" and data.endsAt and not data.eliminated then
			timerPrefix = "LUTEM! "
			timerEndsAt = tonumber(data.endsAt)
		elseif data.endsAt then
			timerEndsAt = tonumber(data.endsAt)
		end
	elseif event == "end" then
		inDuel = false
		timerEndsAt = nil
		local winners = data.winners
		local won = typeof(winners) == "table" and table.find(winners, localPlayer.Name) ~= nil
		local text = if typeof(winners) == "table" and #winners > 0 then (if won then "VITÓRIA!" else "Derrota — venceu " .. table.concat(winners, ", ")) else "Empate"
		duelStatus.Text = text
		duelStatus.Visible = true
		setStatus(text)
		FX.PlaySoundUI("Match", if won then "Victory" else "Defeat")
		task.delay(tonumber(data.endsAt) and math.max(1, (tonumber(data.endsAt) :: number) - Workspace:GetServerTimeNow()) or 4, function()
			if not inDuel then
				duelStatus.Visible = false
			end
		end)
	end
	refreshButtons()
end

local function tickTimer()
	if not timerEndsAt or not inDuel then
		return
	end
	local remaining = math.max(0, timerEndsAt - Workspace:GetServerTimeNow())
	if timerPrefix == "Preparar... " then
		duelStatus.Text = ("Preparar... %d"):format(math.ceil(remaining))
	else
		duelStatus.Text = ("%d:%02d"):format(remaining // 60, math.floor(remaining % 60))
	end
end

-- ---------------------------------------------------------------------------
-- Start
-- ---------------------------------------------------------------------------

function DuelController.Start()
	local gui = get(playerGui, "DuelGui")
	panel = get(gui, "Panel") :: Frame
	list = get(panel, "List") :: ScrollingFrame
	rowTemplate = get(list, "Template") :: TextButton
	statusLabel = get(panel, "Status") :: TextLabel
	leaveButton = get(panel, "Leave") :: TextButton
	cancelButton = get(panel, "Cancel") :: TextButton
	inviteFrame = get(gui, "Invite") :: Frame
	inviteText = get(inviteFrame, "Text") :: TextLabel
	duelStatus = get(gui, "DuelStatus") :: TextLabel
	hint = get(panel, "Hint") :: TextLabel
	tab1v1 = get(panel, "Tab1v1") :: TextButton
	tab2v2 = get(panel, "Tab2v2") :: TextButton
	createRoomButton = get(panel, "CreateRoom") :: TextButton
	switchTeamButton = get(panel, "SwitchTeam") :: TextButton
	leaveRoomButton = get(panel, "LeaveRoom") :: TextButton
	requestDuel = Remotes.GetEvent(Remotes.Events.RequestDuel)

	tab1v1.MouseButton1Click:Connect(function()
		setMode("1v1")
	end)
	tab2v2.MouseButton1Click:Connect(function()
		setMode("2v2")
	end)
	createRoomButton.MouseButton1Click:Connect(function()
		requestDuel:FireServer("create_room")
	end)
	switchTeamButton.MouseButton1Click:Connect(function()
		requestDuel:FireServer("switch_team")
	end)
	leaveRoomButton.MouseButton1Click:Connect(function()
		requestDuel:FireServer("leave_room")
	end)

	local acceptButton = get(inviteFrame, "Accept") :: TextButton
	local declineButton = get(inviteFrame, "Decline") :: TextButton
	acceptButton.MouseButton1Click:Connect(function()
		requestDuel:FireServer("accept")
		hideInvite()
	end)
	declineButton.MouseButton1Click:Connect(function()
		requestDuel:FireServer("decline")
		hideInvite()
	end)
	leaveButton.MouseButton1Click:Connect(function()
		requestDuel:FireServer("leave")
	end)
	cancelButton.MouseButton1Click:Connect(function()
		requestDuel:FireServer("cancel")
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not pendingInvite then
			return
		end
		if input.KeyCode == Enum.KeyCode.Y then
			requestDuel:FireServer("accept")
			hideInvite()
		elseif input.KeyCode == Enum.KeyCode.N then
			requestDuel:FireServer("decline")
			hideInvite()
		end
	end)

	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			if mode == "2v2" then
				requestDuel:FireServer("list_rooms")
			end
			refreshList()
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		if panel.Visible then
			refreshList()
		end
		player:GetAttributeChangedSignal("InMatch"):Connect(function()
			if panel.Visible then
				refreshList()
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function()
		if panel.Visible then
			task.defer(refreshList)
		end
	end)
	for _, player in Players:GetPlayers() do
		player:GetAttributeChangedSignal("InMatch"):Connect(function()
			if panel.Visible then
				refreshList()
			end
		end)
	end

	Remotes.GetEvent(Remotes.Events.NotifyDuel).OnClientEvent:Connect(onNotifyDuel)
	task.spawn(function()
		while true do
			tickTimer()
			task.wait(0.2)
		end
	end)
	setMode("1v1")
	Log.debug("[DuelController] pronto (Y/N respondem convites; abas 1v1/2v2)")
end

return DuelController
