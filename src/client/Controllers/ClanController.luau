--!strict
--[[
	ClanController (cliente)
	UI do clã (StarterGui.ClanGui.Panel, aberto pelo ícone "Clã" (C) do TopbarController):
	  Create -> sem clã: nome + TAG + fundar; convite recebido (Aceitar Y / Recusar N)
	  Info   -> com clã: cabeçalho, abas Membros (clique = selecionar; promover/rebaixar/expulsar) e
	            Convidar (jogadores online sem clã; clique = convidar), depósito no cofre, sair/dissolver
	Só reflete NotifyClan("state"|"invite"|"denied"|"info"); toda decisão é do ClanService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))
local ClanConfig = require(Modules:WaitForChild("ClanConfig"))

local ClanController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local panel: Frame
local createFrame: Frame
local infoFrame: Frame
local nameBox: TextBox
local tagBox: TextBox
local inviteLabel: TextLabel
local acceptButton: TextButton
local declineButton: TextButton
local header: TextLabel
local sub: TextLabel
local tabMembers: TextButton
local tabInvite: TextButton
local list: ScrollingFrame
local rowTemplate: TextButton
local selectedLabel: TextLabel
local promoteButton: TextButton
local demoteButton: TextButton
local kickButton: TextButton
local amountBox: TextBox
local leaveButton: TextButton
local disbandButton: TextButton
local statusLabel: TextLabel
local requestClan: RemoteEvent

local clan: ClanConfig.Clan? = nil
local myRole: string? = nil
local tab: "members" | "invite" = "members"
local selectedId: number? = nil
local pendingInvite = false
local statusToken = 0

local TAB_ON = Color3.fromRGB(70, 140, 217)
local TAB_OFF = Color3.fromRGB(46, 46, 61)

local function get(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child, ("[ClanController] '%s' não encontrado em %s"):format(name, parent:GetFullName()))
	return child
end

local function setStatus(text: string, color: Color3?)
	statusToken += 1
	local token = statusToken
	statusLabel.Text = text
	statusLabel.TextColor3 = color or Color3.fromRGB(158, 158, 173)
	task.delay(4, function()
		if statusToken == token then
			statusLabel.Text = ""
		end
	end)
end

local function clearList()
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") and child ~= rowTemplate then
			child:Destroy()
		end
	end
end

local function addRow(text: string, roleText: string, order: number, onClick: () -> ()): TextButton
	local row = rowTemplate:Clone()
	row.Text = text
	row.LayoutOrder = order
	local role = row:FindFirstChild("Role") :: TextLabel
	role.Text = roleText
	row.Visible = true
	row.MouseButton1Click:Connect(onClick)
	row.Parent = list
	return row
end

local function refreshButtons()
	local c = clan
	local rank = ClanConfig.RoleRank(myRole or "member")
	local isLeader = myRole == "leader"
	local canManage = rank >= ClanConfig.RoleRank("officer")
	local sel = if c and selectedId then c.members[tostring(selectedId)] else nil
	local selRank = if sel then ClanConfig.RoleRank(sel.role) else 0
	local showManage = tab == "members" and sel ~= nil and selectedId ~= localPlayer.UserId
	promoteButton.Visible = showManage and isLeader and sel ~= nil and sel.role ~= "leader"
	demoteButton.Visible = showManage and isLeader and sel ~= nil and sel.role == "officer"
	kickButton.Visible = showManage and canManage and rank > selRank
	selectedLabel.Text = if sel then ("Selecionado: %s (%s)"):format(sel.name, ClanConfig.RoleNames[sel.role] or sel.role) else ""
	leaveButton.Visible = not isLeader
	disbandButton.Visible = isLeader
	tabMembers.BackgroundColor3 = if tab == "members" then TAB_ON else TAB_OFF
	tabInvite.BackgroundColor3 = if tab == "invite" then TAB_ON else TAB_OFF
	tabInvite.Visible = canManage
end

local function refreshList()
	clearList()
	local c = clan
	if not c then
		return
	end
	if tab == "members" then
		local rows = {}
		for id, m in c.members do
			table.insert(rows, { id = tonumber(id) or 0, m = m })
		end
		table.sort(rows, function(a, b)
			local ra, rb = ClanConfig.RoleRank(a.m.role), ClanConfig.RoleRank(b.m.role)
			if ra ~= rb then
				return ra > rb
			end
			return a.m.name:lower() < b.m.name:lower()
		end)
		for i, r in rows do
			local online = Players:GetPlayerByUserId(r.id) ~= nil
			local text = r.m.name .. (if online then "  •" else "")
			local row = addRow(text, ClanConfig.RoleNames[r.m.role] or r.m.role, i, function()
				selectedId = if selectedId == r.id then nil else r.id
				refreshList()
			end)
			if selectedId == r.id then
				row.BackgroundColor3 = TAB_ON
			end
		end
	else
		local i = 0
		for _, other in Players:GetPlayers() do
			local theirTag = other:GetAttribute("ClanTag")
			if other ~= localPlayer and (theirTag == nil or theirTag == "") then
				i += 1
				addRow(other.Name, "convidar", i, function()
					requestClan:FireServer("invite", other.UserId)
				end)
			end
		end
		if i == 0 then
			addRow("ninguém disponível", "", 1, function() end).AutoButtonColor = false
		end
	end
	refreshButtons()
end

local function render()
	local c = clan
	createFrame.Visible = c == nil
	infoFrame.Visible = c ~= nil
	if c then
		header.Text = ("%s  [%s]"):format(c.name, c.tag)
		sub.Text = ("Cofre: %d pontos  ·  Membros: %d/%d  ·  Você: %s"):format(
			c.vault or 0, ClanConfig.MemberCount(c), ClanConfig.MaxMembers, ClanConfig.RoleNames[myRole or "member"] or "?")
		if selectedId and not c.members[tostring(selectedId)] then
			selectedId = nil
		end
		refreshList()
	end
end

local function hideInvite()
	pendingInvite = false
	inviteLabel.Text = ""
	acceptButton.Visible = false
	declineButton.Visible = false
end

local function onNotifyClan(event: string, data: any)
	data = if typeof(data) == "table" then data else {}
	if event == "state" then
		clan = if typeof(data.clan) == "table" then data.clan else nil
		myRole = if typeof(data.role) == "string" then data.role else nil
		if clan then
			hideInvite()
		end
		render()
	elseif event == "invite" then
		pendingInvite = true
		inviteLabel.Text = ("%s te convidou para %s [%s]"):format(tostring(data.from), tostring(data.name), tostring(data.tag))
		acceptButton.Visible = true
		declineButton.Visible = true
		setStatus("Convite de clã recebido! (C abre o painel)", Color3.fromRGB(255, 205, 80))
		panel.Visible = true
		local seconds = tonumber(data.seconds) or ClanConfig.InviteSeconds
		task.delay(seconds, function()
			if pendingInvite then
				hideInvite()
			end
		end)
	elseif event == "denied" then
		setStatus(tostring(data.reason), Color3.fromRGB(230, 70, 70))
	elseif event == "info" then
		setStatus(tostring(data.message), Color3.fromRGB(120, 255, 140))
	end
end

function ClanController.Start()
	local gui = get(playerGui, "ClanGui")
	panel = get(gui, "Panel") :: Frame
	createFrame = get(panel, "Create") :: Frame
	infoFrame = get(panel, "Info") :: Frame
	nameBox = get(createFrame, "Name") :: TextBox
	tagBox = get(createFrame, "Tag") :: TextBox
	inviteLabel = get(createFrame, "Invite") :: TextLabel
	acceptButton = get(createFrame, "Accept") :: TextButton
	declineButton = get(createFrame, "Decline") :: TextButton
	header = get(infoFrame, "Header") :: TextLabel
	sub = get(infoFrame, "Sub") :: TextLabel
	tabMembers = get(infoFrame, "TabMembers") :: TextButton
	tabInvite = get(infoFrame, "TabInvite") :: TextButton
	list = get(infoFrame, "List") :: ScrollingFrame
	rowTemplate = get(list, "Template") :: TextButton
	selectedLabel = get(infoFrame, "Selected") :: TextLabel
	promoteButton = get(infoFrame, "Promote") :: TextButton
	demoteButton = get(infoFrame, "Demote") :: TextButton
	kickButton = get(infoFrame, "Kick") :: TextButton
	amountBox = get(infoFrame, "Amount") :: TextBox
	leaveButton = get(infoFrame, "Leave") :: TextButton
	disbandButton = get(infoFrame, "Disband") :: TextButton
	statusLabel = get(panel, "Status") :: TextLabel
	requestClan = Remotes.GetEvent(Remotes.Events.RequestClan)

	local submit = get(createFrame, "Submit") :: TextButton
	submit.Text = ("FUNDAR — %d pts"):format(ClanConfig.CreateCost)
	submit.MouseButton1Click:Connect(function()
		requestClan:FireServer("create", nameBox.Text, tagBox.Text)
	end)
	acceptButton.MouseButton1Click:Connect(function()
		requestClan:FireServer("accept")
		hideInvite()
	end)
	declineButton.MouseButton1Click:Connect(function()
		requestClan:FireServer("decline")
		hideInvite()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not pendingInvite then
			return
		end
		if input.KeyCode == Enum.KeyCode.Y then
			requestClan:FireServer("accept")
			hideInvite()
		elseif input.KeyCode == Enum.KeyCode.N then
			requestClan:FireServer("decline")
			hideInvite()
		end
	end)

	tabMembers.MouseButton1Click:Connect(function()
		tab = "members"
		refreshList()
	end)
	tabInvite.MouseButton1Click:Connect(function()
		tab = "invite"
		selectedId = nil
		refreshList()
	end)
	promoteButton.MouseButton1Click:Connect(function()
		if selectedId then
			requestClan:FireServer("promote", selectedId)
		end
	end)
	demoteButton.MouseButton1Click:Connect(function()
		if selectedId then
			requestClan:FireServer("demote", selectedId)
		end
	end)
	kickButton.MouseButton1Click:Connect(function()
		if selectedId then
			requestClan:FireServer("kick", selectedId)
			selectedId = nil
		end
	end)
	local depositButton = get(infoFrame, "Deposit") :: TextButton
	depositButton.MouseButton1Click:Connect(function()
		requestClan:FireServer("deposit", tonumber(amountBox.Text) or 0)
		amountBox.Text = ""
	end)
	leaveButton.MouseButton1Click:Connect(function()
		requestClan:FireServer("leave")
	end)
	-- dissolver: 2 cliques em 3 s para não perder o clã num clique errado
	local disbandArmedUntil = 0
	disbandButton.MouseButton1Click:Connect(function()
		if os.clock() < disbandArmedUntil then
			requestClan:FireServer("disband")
			disbandArmedUntil = 0
			disbandButton.Text = "DISSOLVER"
		else
			disbandArmedUntil = os.clock() + 3
			disbandButton.Text = "CONFIRMAR?"
			task.delay(3, function()
				if os.clock() >= disbandArmedUntil then
					disbandButton.Text = "DISSOLVER"
				end
			end)
		end
	end)

	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			requestClan:FireServer("refresh")
			refreshList()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if panel.Visible then
			refreshList()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if panel.Visible then
			refreshList()
		end
	end)

	Remotes.GetEvent(Remotes.Events.NotifyClan).OnClientEvent:Connect(onNotifyClan)
	render()
	Log.debug("[ClanController] pronto")
end

return ClanController
