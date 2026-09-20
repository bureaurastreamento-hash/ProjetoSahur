--!strict
--[[
	UpdateLogController
	Tela "Novidades" (StarterGui.UpdateLogGui): abre sozinha, uma vez por versão publicada, quando o
	servidor manda NotifyUpdateLog (D4); e pode ser revista pelo item Config → Novidades (FetchUpdateLog).
	Discreta: tween curto de entrada, sem som. Ao fechar a versão vista vai para o servidor
	(RequestUpdateSeen) e ele grava no perfil. "versões anteriores" percorre a lista do config.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local UpdateLogConfig = require(Modules:WaitForChild("UpdateLogConfig"))
local Icon = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Icon"))
local TopbarController = require(script.Parent:WaitForChild("TopbarController"))

local UpdateLogController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local panel: Frame
local versionLabel: TextLabel
local headlineLabel: TextLabel
local list: ScrollingFrame
local template: TextLabel
local closeButton: TextButton
local olderButton: TextButton
local hintLabel: TextLabel

local versions: { UpdateLogConfig.Entry } = UpdateLogConfig.Versions -- o servidor pode mandar a lista dele (Fetch)
local shownIndex = 1
local pendingSeen: string? = nil -- versão que precisa ser confirmada ao fechar (só quando abriu sozinha)
local icon: any = nil
local rows: { Instance } = {}

local function get(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child, ("[UpdateLogController] '%s' não encontrado em %s"):format(name, parent:GetFullName()))
	return child
end

local function render(entry: UpdateLogConfig.Entry)
	for _, row in rows do
		row:Destroy()
	end
	table.clear(rows)
	versionLabel.Text = ("versão %s · %s"):format(entry.Version, entry.Date)
	headlineLabel.Text = entry.Title
	for i, item in entry.Items do
		local row = template:Clone()
		row.Name = "Item" .. i
		row.Text = "•  " .. item
		row.LayoutOrder = i
		row.Visible = true
		row.Parent = list
		table.insert(rows, row)
	end
	list.CanvasPosition = Vector2.zero
	olderButton.Visible = #versions > 1
	olderButton.Text = if shownIndex < #versions then "versões anteriores" else "voltar à mais nova"
	hintLabel.Text = if pendingSeen then "aparece uma vez por atualização" else ("%d de %d"):format(shownIndex, #versions)
end

local function show(entry: UpdateLogConfig.Entry)
	render(entry)
	if panel.Visible then
		return
	end
	panel.Visible = true
	-- entrada discreta: cresce de 92% com fade curto
	local finalSize = panel.Size
	panel.Size = UDim2.new(finalSize.X.Scale * 0.92, finalSize.X.Offset * 0.92, finalSize.Y.Scale * 0.92, finalSize.Y.Offset * 0.92)
	panel.BackgroundTransparency = 1
	TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = finalSize, BackgroundTransparency = 0.28 }):Play()
end

local function close()
	if not panel.Visible then
		return
	end
	panel.Visible = false
	if pendingSeen then
		Remotes.GetEvent(Remotes.Events.RequestUpdateSeen):FireServer(pendingSeen)
		pendingSeen = nil
	end
	if icon and icon.isSelected then
		icon:deselect()
	end
end

--- Abre a versão `index` da lista (1 = mais nova).
local function showIndex(index: number)
	shownIndex = math.clamp(index, 1, math.max(1, #versions))
	local entry = versions[shownIndex]
	if entry then
		show(entry)
	end
end

function UpdateLogController.Init()
	local gui = playerGui:WaitForChild("UpdateLogGui", 15)
	assert(gui, "[UpdateLogController] StarterGui.UpdateLogGui não chegou (Rojo conectado?)")
	panel = get(gui, "Panel") :: Frame
	versionLabel = get(panel, "Version") :: TextLabel
	headlineLabel = get(panel, "Headline") :: TextLabel
	list = get(panel, "List") :: ScrollingFrame
	template = get(list, "Template") :: TextLabel
	closeButton = get(panel, "Close") :: TextButton
	olderButton = get(panel, "Older") :: TextButton
	hintLabel = get(panel, "Hint") :: TextLabel
end

function UpdateLogController.Start()
	closeButton.MouseButton1Click:Connect(close)
	olderButton.MouseButton1Click:Connect(function()
		showIndex(if shownIndex < #versions then shownIndex + 1 else 1)
	end)

	-- Config → Novidades: rever a qualquer hora (lista do servidor, para bater com o build dele)
	icon = Icon.new():setLabel("Novidades"):setCaption("O que mudou nas últimas atualizações"):setOrder(2)
	icon.toggled:Connect(function(isSelected: boolean)
		if not isSelected then
			close()
			return
		end
		task.spawn(function()
			local ok, data = pcall(function()
				return Remotes.GetFunction(Remotes.Functions.FetchUpdateLog):InvokeServer()
			end)
			if ok and typeof(data) == "table" and typeof(data.versions) == "table" and #data.versions > 0 then
				versions = data.versions
			end
			pendingSeen = nil
			showIndex(1)
		end)
	end)
	TopbarController.AddToSettings(icon)

	-- publicada e ainda não vista: abre sozinha (o servidor só manda uma vez por versão, até fechar)
	Remotes.GetEvent(Remotes.Events.NotifyUpdateLog).OnClientEvent:Connect(function(entry: any)
		if typeof(entry) ~= "table" or typeof(entry.Version) ~= "string" then
			return
		end
		pendingSeen = entry.Version
		-- a lista local pode não ter essa versão (build velho no cliente é raro, mas não custa)
		local index = nil
		for i, e in versions do
			if e.Version == entry.Version then
				index = i
				break
			end
		end
		if not index then
			table.insert(versions, 1, entry)
			index = 1
		end
		-- espera o jogador estar de fato no jogo (personagem carregado) antes de pôr a tela na frente
		task.delay(2, function()
			showIndex(index :: number)
		end)
	end)
end

return UpdateLogController
