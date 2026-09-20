--!strict
--[[
	ModsController (cliente)
	Painel MODS (dono, 2026-09-22): entra no dropdown Config (engrenagem) só em SERVIDOR PRIVADO (todo mundo
	vê; só o dono da sala liga/desliga) e SEMPRE para devs (IsDeveloper). Lista o catálogo aprovado
	(ModsConfig) com autor/versão e toggle; o servidor (ModService) decide tudo e devolve NotifyMods.
	Chip "MODS ATIVOS" no HUD quando há mod ligado (créditos ao autor). UI montada em código.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local ModsConfig = require(Modules:WaitForChild("ModsConfig"))
local ModRegistry = require(Modules:WaitForChild("ModRegistry"))
local TopbarController = require(script.Parent:WaitForChild("TopbarController"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local Icon = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Icon"))

local ModsController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local COLOR_BG = Color3.fromRGB(20, 20, 28)
local COLOR_ROW = Color3.fromRGB(33, 33, 43)
local COLOR_ON = Color3.fromRGB(60, 140, 90)
local COLOR_OFF = Color3.fromRGB(70, 70, 84)
local COLOR_TITLE = Color3.fromRGB(89, 166, 255)
local COLOR_TEXT = Color3.fromRGB(235, 235, 240)
local COLOR_SUB = Color3.fromRGB(165, 165, 178)

local gui: ScreenGui
local panel: Frame
local list: ScrollingFrame
local header: TextLabel
local status: TextLabel
local chip: TextLabel
local rows: { [string]: { frame: Frame, toggle: TextButton } } = {}
local modsIcon: any = nil
local state: { [string]: any } = { active = {}, canEdit = false, canSee = false, canActivate = false }
local requestToggle: RemoteEvent

local function mk(class: string, props: { [string]: any }, parent: Instance?): Instance
	local inst = Instance.new(class)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local addRow: (any, number) -> ()

local function buildGui()
	gui = mk("ScreenGui", { Name = "ModsGui", ResetOnSpawn = false, DisplayOrder = 9, IgnoreGuiInset = false }, playerGui) :: ScreenGui
	panel = mk("Frame", { Name = "Panel", Size = UDim2.fromOffset(560, 520), Position = UDim2.new(0.5, -280, 0.5, -260), BackgroundColor3 = COLOR_BG, BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false, Active = true }, gui) :: Frame
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
	mk("TextLabel", { Size = UDim2.new(0, 200, 0, 30), Position = UDim2.fromOffset(14, 8), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = COLOR_TITLE, TextXAlignment = Enum.TextXAlignment.Left, Text = "MODS" }, panel)
	header = mk("TextLabel", { Size = UDim2.new(1, -240, 0, 30), Position = UDim2.fromOffset(90, 8), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COLOR_SUB, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "" }, panel) :: TextLabel
	local close = mk("TextButton", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -40, 0, 10), BackgroundColor3 = COLOR_ROW, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = COLOR_TEXT, Text = "X", BorderSizePixel = 0 }, panel) :: TextButton
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, close)
	close.MouseButton1Click:Connect(function()
		ModsController.SetOpen(false)
	end)
	status = mk("TextLabel", { Size = UDim2.new(1, -28, 0, 34), Position = UDim2.fromOffset(14, 40), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COLOR_SUB, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Text = "" }, panel) :: TextLabel
	list = mk("ScrollingFrame", { Size = UDim2.new(1, -28, 1, -90), Position = UDim2.fromOffset(14, 78), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, panel) :: ScrollingFrame
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	for i, mod in ModsConfig.Catalog do
		addRow(mod, i)
	end
	-- chip no HUD (embaixo do topbar, esquerda): créditos aos autores dos mods ativos
	chip = mk("TextLabel", { Name = "ModsChip", Size = UDim2.fromOffset(420, 22), Position = UDim2.fromOffset(12, 48), BackgroundColor3 = COLOR_BG, BackgroundTransparency = 0.4, BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = COLOR_TITLE, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Visible = false, Text = "" }, gui) :: TextLabel
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, chip)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, chip)
end

--- Linha do painel (catálogo ou mod de teste do Studio). `mod` = { Id, Name, Version, Author, Desc }.
addRow = function(mod: any, i: number)
	if rows[mod.Id] then
		return
	end
	do
		local row = mk("Frame", { Name = mod.Id, Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = COLOR_ROW, BorderSizePixel = 0, LayoutOrder = i }, list) :: Frame
		mk("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
		mk("TextLabel", { Size = UDim2.new(1, -130, 0, 20), Position = UDim2.fromOffset(10, 6), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = COLOR_TEXT, TextXAlignment = Enum.TextXAlignment.Left, Text = ("%s   <font color=\"#A5A5B2\">v%s · por %s</font>"):format(mod.Name, mod.Version, mod.Author), RichText = true, TextTruncate = Enum.TextTruncate.AtEnd }, row)
		mk("TextLabel", { Size = UDim2.new(1, -130, 0, 24), Position = UDim2.fromOffset(10, 26), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COLOR_SUB, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Text = mod.Desc }, row)
		local toggle = mk("TextButton", { Size = UDim2.fromOffset(100, 30), Position = UDim2.new(1, -110, 0, 12), BackgroundColor3 = COLOR_OFF, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = COLOR_TEXT, Text = "DESLIGADO", BorderSizePixel = 0, AutoButtonColor = true }, row) :: TextButton
		mk("UICorner", { CornerRadius = UDim.new(0, 6) }, toggle)
		toggle.MouseButton1Click:Connect(function()
			if not state.canEdit then
				HUDController.ShowToast("Mods", "Só o dono do servidor privado liga mods.", COLOR_SUB)
				return
			end
			local isOn = false
			for _, a in state.active do
				if a.id == mod.Id then
					isOn = true
				end
			end
			requestToggle:FireServer(mod.Id, not isOn)
		end)
		rows[mod.Id] = { frame = row, toggle = toggle }
	end
end

local function render()
	local activeIds: { [string]: boolean } = {}
	local names = {}
	for _, a in state.active do
		activeIds[a.id] = true
		table.insert(names, ("%s (%s)"):format(tostring(a.name), tostring(a.author)))
	end
	for id, row in rows do
		local on = activeIds[id] == true
		row.toggle.Text = if on then "LIGADO" else "DESLIGADO"
		row.toggle.BackgroundColor3 = if on then COLOR_ON else COLOR_OFF
		row.toggle.AutoButtonColor = state.canEdit == true
	end
	if state.private then
		header.Text = ("servidor privado · dono: %s"):format(tostring(state.owner or "?"))
	else
		header.Text = "servidor público"
	end
	if state.canEdit and state.canActivate then
		status.Text = "Você escolhe os mods desta sala. Nada é salvo em servidor privado (pontos, itens, quests). Créditos ao autor de cada mod."
	elseif state.canEdit then
		status.Text = "Só dá para LIGAR mods em servidor privado (ou no Studio). Aqui você só vê o catálogo aprovado."
	else
		status.Text = "Só o dono do servidor privado liga/desliga mods. Quer criar um mod? Kit e tutorial na comunidade do grupo (em breve aqui no jogo)."
	end
	chip.Visible = #names > 0
	chip.Text = "MODS ATIVOS: " .. table.concat(names, " · ")
end

function ModsController.SetOpen(open: boolean)
	panel.Visible = open
	if modsIcon and not open then
		modsIcon:deselect()
	end
end

local function ensureIcon()
	if modsIcon or not state.canSee then
		return
	end
	modsIcon = Icon.new()
		:setLabel("Mods")
		:setCaption("Mods do servidor privado")
		:setOrder(8)
	TopbarController.AddToSettings(modsIcon)
	modsIcon.toggled:Connect(function(isSelected: boolean)
		ModsController.SetOpen(isSelected)
	end)
end

function ModsController.Init()
	ModRegistry.Start() -- mods de asset: CharacterDef/Cosmetics/VFX entram nos módulos do cliente
	requestToggle = Remotes.GetEvent(Remotes.Events.RequestModToggle)
	buildGui()
end

function ModsController.Start()
	Remotes.GetEvent(Remotes.Events.NotifyMods).OnClientEvent:Connect(function(payload: any, result: any)
		if typeof(payload) == "table" then
			state = payload
			-- mods de TESTE (Studio: pastas em ServerStorage.Mods sem entrada no catálogo)
			if typeof(payload.extra) == "table" then
				for i, m in payload.extra do
					addRow({ Id = m.id, Name = ("%s [TESTE]"):format(tostring(m.name)), Version = tostring(m.version), Author = tostring(m.author), Desc = ("%s (%s)"):format(tostring(m.desc), tostring(m.kind)) }, 100 + i)
				end
			end
			ensureIcon()
			render()
		end
		if typeof(result) == "table" then
			HUDController.ShowToast("Mods", tostring(result.message), if result.ok then COLOR_ON else Color3.fromRGB(240, 120, 110))
		end
	end)
end

return ModsController
