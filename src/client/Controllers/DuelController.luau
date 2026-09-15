--!strict
--[[
	DuelController (cliente)
	UI dos duelos 1v1 (StarterGui.DuelGui):
	  Panel      -> lista de jogadores (clique = desafiar), status, cancelar/desistir
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

local inDuel = false
local pendingInvite = false -- convite recebido aberto
local outgoing = false -- desafio enviado esperando resposta
local timerEndsAt: number? = nil
local timerPrefix = ""

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
end

-- ---------------------------------------------------------------------------
-- Lista de jogadores
-- ---------------------------------------------------------------------------

local function refreshList()
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") and child ~= rowTemplate then
			child:Destroy()
		end
	end
	local count = 0
	for _, player in Players:GetPlayers() do
		if player == localPlayer then
			continue
		end
		count += 1
		local row = rowTemplate:Clone()
		row.Name = player.Name
		row.Text = "  " .. player.DisplayName .. if player.DisplayName ~= player.Name then " (@" .. player.Name .. ")" else ""
		local busy = player:GetAttribute("InMatch") == true
		local action = row:FindFirstChild("Action") :: TextLabel
		action.Text = if busy then "EM DUELO" else "DESAFIAR"
		action.TextColor3 = if busy then Color3.fromRGB(160, 160, 170) else Color3.fromRGB(120, 220, 150)
		row.Visible = true
		row.Parent = list
		row.MouseButton1Click:Connect(function()
			if inDuel or outgoing then
				return
			end
			requestDuel:FireServer("challenge", player.UserId)
		end)
	end
	if count == 0 then
		setStatus("Ninguém mais no servidor para desafiar.")
	end
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
	elseif event == "start" then
		inDuel = true
		outgoing = false
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
	requestDuel = Remotes.GetEvent(Remotes.Events.RequestDuel)

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
	refreshButtons()
	Log.debug("[DuelController] pronto (Y/N respondem convites)")
end

return DuelController
