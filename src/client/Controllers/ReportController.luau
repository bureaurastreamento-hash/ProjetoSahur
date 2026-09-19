--!strict
--[[
	ReportController (cliente)
	UI de denúncia (StarterGui.ReportGui): escolhe um jogador da lista, um motivo predefinido
	(ReportConfig.Reasons) e escreve um texto livre opcional; RequestReport manda tudo pro
	servidor (ReportService valida e grava). Ícone "Denunciar" pendurado no dropdown de Perfil.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local ReportConfig = require(Modules:WaitForChild("ReportConfig"))
local Icon = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Icon"))
local TopbarController = require(script.Parent:WaitForChild("TopbarController"))

local ReportController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local panel: Frame
local playersList: ScrollingFrame
local playerTemplate: TextButton
local reasonsFrame: Frame
local reasonTemplate: TextButton
local textBox: TextBox
local statusLabel: TextLabel
local submitButton: TextButton

local selectedPlayer: string? = nil
local selectedReason: string? = nil

local SELECTED = Color3.fromRGB(90, 165, 255)
local OFF = Color3.fromRGB(33, 33, 43)

local function get(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child, ("[ReportController] '%s' não encontrado em %s"):format(name, parent:GetFullName()))
	return child
end

local function refreshPlayers()
	for _, child in playersList:GetChildren() do
		if child:IsA("TextButton") and child ~= playerTemplate then
			child:Destroy()
		end
	end
	for _, player in Players:GetPlayers() do
		if player == localPlayer then
			continue
		end
		local row = playerTemplate:Clone()
		row.Name = player.Name
		row.Text = player.Name
		row.Visible = true
		row.BackgroundColor3 = if selectedPlayer == player.Name then SELECTED else OFF
		row.MouseButton1Click:Connect(function()
			selectedPlayer = player.Name
			refreshPlayers()
		end)
		row.Parent = playersList
	end
end

local function refreshReasons()
	for _, child in reasonsFrame:GetChildren() do
		if child:IsA("TextButton") and child ~= reasonTemplate then
			child:Destroy()
		end
	end
	for i, reason in ReportConfig.Reasons do
		local row = reasonTemplate:Clone()
		row.Name = reason.Id
		row.Text = reason.Label
		row.LayoutOrder = i
		row.Visible = true
		row.BackgroundColor3 = if selectedReason == reason.Id then SELECTED else OFF
		row.MouseButton1Click:Connect(function()
			selectedReason = reason.Id
			refreshReasons()
		end)
		row.Parent = reasonsFrame
	end
end

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		selectedPlayer = nil
		selectedReason = nil
		textBox.Text = ""
		statusLabel.Text = ""
		refreshPlayers()
		refreshReasons()
	end
end

local function submit()
	if not selectedPlayer then
		statusLabel.Text = "escolha um jogador"
		return
	end
	if not selectedReason then
		statusLabel.Text = "escolha um motivo"
		return
	end
	Remotes.GetEvent(Remotes.Events.RequestReport):FireServer(selectedPlayer, selectedReason, textBox.Text)
	statusLabel.Text = "enviando..."
end

function ReportController.Init()
	local gui = playerGui:WaitForChild("ReportGui", 15)
	assert(gui, "[ReportController] StarterGui.ReportGui não chegou (Rojo conectado?)")
	panel = get(gui, "Panel") :: Frame
	playersList = get(panel, "Players") :: ScrollingFrame
	playerTemplate = get(playersList, "Template") :: TextButton
	reasonsFrame = get(panel, "Reasons") :: Frame
	reasonTemplate = get(reasonsFrame, "Template") :: TextButton
	textBox = get(panel, "Text") :: TextBox
	statusLabel = get(panel, "Status") :: TextLabel
	submitButton = get(panel, "Submit") :: TextButton
end

function ReportController.Start()
	local icon = Icon.new()
		:setLabel("Denunciar")
		:setCaption("Denunciar um jogador (motivo + detalhes)")
		:bindToggleItem(panel)
		:setOrder(3)
	icon.toggled:Connect(function(isSelected: boolean)
		setOpen(isSelected)
	end)
	TopbarController.AddToProfile(icon)

	submitButton.MouseButton1Click:Connect(submit)

	Remotes.GetEvent(Remotes.Events.NotifyReport).OnClientEvent:Connect(function(ok: boolean, message: string)
		statusLabel.Text = tostring(message)
		if ok then
			task.delay(1.2, function()
				if panel.Visible then
					setOpen(false)
					icon:deselect()
				end
			end)
		end
	end)

	Players.PlayerAdded:Connect(function()
		if panel.Visible then
			refreshPlayers()
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		if selectedPlayer == p.Name then
			selectedPlayer = nil
		end
		if panel.Visible then
			refreshPlayers()
		end
	end)
end

return ReportController
