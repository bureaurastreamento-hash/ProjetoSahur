--!strict
--[[
	InventoryController — MOCHILA (tecla M ou menu lateral, MenuController): Stand ativo + maestria, raça e itens
	(Flechas, Discos de Stand, Essências). Mostra o sorteio da Flecha e, se já havia um Stand, a escolha
	"usar agora (perde o atual)" / "guardar". Tudo decidido no StandService; aqui só desenha e pede.
	Dados: NotifyProfile (profile.power/race/inventory/mastery) e NotifyStand (eventos).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Controls = require(Modules:WaitForChild("Controls"))
local CharacterDefs = require(Modules:WaitForChild("CharacterDefs"))
local StandConfig = require(Modules:WaitForChild("StandConfig"))
local BuildConfig = require(Modules.BuildConfig)
local InventoryView = require(Modules.InventoryView)
local ProgressionConfig = require(Modules:WaitForChild("ProgressionConfig"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))

local InventoryController = {}

local localPlayer = Players.LocalPlayer
local BG = Color3.fromRGB(12, 20, 28)
local ACCENT = Color3.fromRGB(70, 205, 255)
local TEXT = Color3.fromRGB(235, 240, 245)
local MUTED = Color3.fromRGB(150, 160, 170)

local profile: any = nil
local gui: ScreenGui
local panel: Frame
local header: TextLabel
local list: ScrollingFrame
local rollFrame: Frame
local search: TextBox
local selectedTab = "all"
local tabButtons: { [string]: TextButton } = {}

local function corner(parent: Instance, _r: number)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number)
	local s = Instance.new("UIStroke"); s.Color = color; s.Transparency = transparency; s.Parent = parent
end

local function label(parent: Instance, text: string, size: number, color: Color3, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	l.TextSize, l.TextColor3, l.Text = size, color, text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize, b.TextColor3, b.Text = 14, Color3.fromRGB(15, 15, 20), text
	b.Parent = parent
	corner(b, 6)
	return b
end

local function standName(id: string): string
	local def = CharacterDefs.Get(id)
	return if def then def.DisplayName else id
end

-- "Maestria 3 · próxima: tecla 3 no nível 4"
local function masteryLine(standId: string): string
	local level = ProgressionConfig.MasteryLevel(profile and profile.mastery and profile.mastery[standId] or 0)
	local nextKey, nextLevel = nil, math.huge
	for slot, req in StandConfig.SlotUnlock do
		if req > level and req < nextLevel then
			nextKey, nextLevel = if slot == CharacterDefs.PASSIVE_SLOT then "R" else tostring(slot), req
		end
	end
	if StandConfig.AwakenUnlock > level and StandConfig.AwakenUnlock < nextLevel then
		nextKey, nextLevel = "G (despertar)", StandConfig.AwakenUnlock
	end
	if not nextKey then
		return ("Maestria %d · todas as teclas liberadas"):format(level)
	end
	return ("Maestria %d · próxima: tecla %s na maestria %d"):format(level, nextKey, nextLevel)
end

local function render()
	if not panel or not profile then return end
	local power = profile.power or ""
	local rarity = if power ~= "" then StandConfig.RarityOf(power) else nil
	local race = StandConfig.GetRace(profile.race or "Humano")
	header.Text = if power ~= ""
		then ("Stand: %s  (%s)\n%s\nRaça: %s"):format(standName(power), rarity and rarity.Name or "?", masteryLine(power), race and race.Name or "Humano")
		else ("Sem Stand (humano)\nUse uma Flecha para despertar um Stand.\nRaça: %s"):format(race and race.Name or "Humano")
	local build = profile.build or {}
	local weaponLevel = localPlayer:GetAttribute("WeaponMastery") or 1
	local styleLevel = localPlayer:GetAttribute("StyleMastery") or 1
	local weaponDef = BuildConfig.Weapon(build.weapon or "")
	local weapon = if weaponDef then ("%s (%s) · maestria %d"):format(weaponDef.Name, weaponDef.Rarity, weaponLevel) else "Sem arma"
	local style = if build.style == BuildConfig.StyleId then ("%s %d · maestria %d"):format(BuildConfig.StyleName, build.techniqueTier or 1, styleLevel) else "Sem estilo"
	header.Text ..= "\n" .. weapon .. "\n" .. style
	header.TextColor3 = if rarity then rarity.Color else TEXT
	for _, child in list:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
	end
	for id, tab in tabButtons do
		tab.BackgroundColor3 = if id == selectedTab then ACCENT else Color3.fromRGB(35, 45, 55)
		tab.TextColor3 = if id == selectedTab then BG else TEXT
	end
	if selectedTab == "build" then
		local equipped = label(list, weapon .. "\n\n" .. style .. "\n\nEquipe os itens pela barra de equipamentos (clique/toque ou X). Técnica e maestrias pertencem ao seu perfil.", 14, TEXT)
		equipped.Size = UDim2.new(1, -8, 0, 130)
		return
	end
	local ids = {}
	for id, n in profile.inventory or {} do
		if typeof(n) == "number" and n > 0 then
			local info = StandConfig.ItemInfo(id, function(ref) return standName(ref) end)
			if info and InventoryView.Matches(selectedTab, search.Text, id, info.Name, info.Kind) then table.insert(ids, id) end
		end
	end
	table.sort(ids, function(a, b)
		return (if a == "flecha" then "0" else a) < (if b == "flecha" then "0" else b)
	end)
	if #ids == 0 then
		local empty = label(list, "Nenhum item nesta aba/busca. Flechas vêm da história, de chefes, missões e trocas.", 13, MUTED)
		empty.Size = UDim2.new(1, -8, 0, 40)
		return
	end
	for i, id in ids do
		local info = StandConfig.ItemInfo(id, function(ref) return standName(ref) end)
		if info then
			local row = Instance.new("Frame")
			row.LayoutOrder = i
			local rowHeight = if id == "flecha" then 118 else 78
			row.Size = UDim2.new(1, -8, 0, rowHeight)
			row.BackgroundColor3 = Color3.fromRGB(22, 32, 42)
			row.Parent = list
			corner(row, 6)
			stroke(row, info.Color, 0.5)
			local name = label(row, ("%s  ×%d"):format(info.Name, profile.inventory[id]), 14, info.Color, true)
			name.Position, name.Size = UDim2.fromOffset(10, 6), UDim2.new(1, -110, 0, 18)
			local desc = label(row, info.Desc, 12, MUTED)
			desc.Position, desc.Size = UDim2.fromOffset(10, 26), UDim2.new(1, -110, 0, rowHeight - 30)
			if info.Kind ~= "material" then -- material só serve na forja
				local use = button(row, "Usar", ACCENT)
				use.Position, use.Size = UDim2.new(1, -90, 0.5, -15), UDim2.fromOffset(80, 30)
				use.Activated:Connect(function()
					Remotes.GetEvent(Remotes.Events.RequestUseItem):FireServer(id)
				end)
			end
		end
	end
end

local function toggle(open: boolean?)
	panel.Visible = if open == nil then not panel.Visible else open
	if panel.Visible then render() end
end

-- Sorteio da Flecha: nome + raridade; se já tinha Stand, escolher.
local function showRoll(data: any)
	for _, c in rollFrame:GetChildren() do
		if not c:IsA("UICorner") and not c:IsA("UIStroke") then c:Destroy() end
	end
	local stand = data.stand or {}
	local color = if typeof(stand.color) == "Color3" then stand.color else ACCENT
	local title = label(rollFrame, if data.blessed then "ABENÇOADO! VOCÊ NASCEU COM UM STAND"
		elseif data.repeated then "REPETIDO · guardado na mochila" else "A FLECHA ESCOLHEU", 15, MUTED, true)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Position, title.Size = UDim2.fromOffset(0, 12), UDim2.new(1, 0, 0, 20)
	local name = label(rollFrame, tostring(stand.name), 30, color, true)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.Position, name.Size = UDim2.fromOffset(0, 36), UDim2.new(1, 0, 0, 36)
	local rarityLabel = label(rollFrame, tostring(stand.rarity), 16, color, true)
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Center
	rarityLabel.Position, rarityLabel.Size = UDim2.fromOffset(0, 74), UDim2.new(1, 0, 0, 20)
	rollFrame.Visible = true
	;(rollFrame:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = color
	if data.equipped then
		rollFrame.Size = UDim2.new(1, -24, 0, 110)
		task.delay(4, function() rollFrame.Visible = false end)
		return
	end
	rollFrame.Size = UDim2.new(1, -24, 0, 160)
	local current = data.current or {}
	local use = button(rollFrame, ("Usar agora (perde %s)"):format(tostring(current.name)), color)
	use.Position, use.Size = UDim2.new(0, 14, 1, -52), UDim2.new(0.5, -20, 0, 38)
	local keep = button(rollFrame, "Guardar na mochila", MUTED)
	keep.Position, keep.Size = UDim2.new(0.5, 6, 1, -52), UDim2.new(0.5, -20, 0, 38)
	use.Activated:Connect(function()
		Remotes.GetEvent(Remotes.Events.RequestArrowChoice):FireServer("usar")
		rollFrame.Visible = false
	end)
	keep.Activated:Connect(function()
		Remotes.GetEvent(Remotes.Events.RequestArrowChoice):FireServer("guardar")
		rollFrame.Visible = false
		HUDController.ShowToast("Guardado na mochila", "Disco de Stand: " .. tostring(stand.name), color)
	end)
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "InventoryGui", false, 9
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Visible = false
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position, panel.Size = UDim2.fromScale(0.5, 0.5), UDim2.new(1, -24, 1, -80)
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(520, 560)
	bounds.Parent = panel
	panel.BackgroundColor3, panel.BackgroundTransparency = BG, 0.08
	panel.Parent = gui
	corner(panel, 10)
	stroke(panel, ACCENT, 0.45)
	local title = label(panel, "MOCHILA", 18, ACCENT, true)
	title.Position, title.Size = UDim2.fromOffset(16, 12), UDim2.new(1, -60, 0, 22)
	local close = button(panel, "X", Color3.fromRGB(60, 70, 80))
	close.TextColor3 = TEXT
	close.Position, close.Size = UDim2.new(1, -44, 0, 10), UDim2.fromOffset(32, 28)
	close.Activated:Connect(function() toggle(false) end)
	header = label(panel, "", 14, TEXT, true)
	header.Position, header.Size = UDim2.fromOffset(16, 42), UDim2.new(1, -32, 0, 110)
	local tabs = Instance.new("Frame")
	tabs.Name, tabs.BackgroundTransparency = "Tabs", 1
	tabs.Position, tabs.Size = UDim2.fromOffset(12, 158), UDim2.new(1, -24, 0, 44)
	tabs.Parent = panel
	for i, tab in InventoryView.Tabs do
		local b = button(tabs, tab.Label, ACCENT)
		b.Name, b.TextSize = tab.Id, 12
		b.Position, b.Size = UDim2.new((i - 1) / #InventoryView.Tabs, 0, 0, 0), UDim2.new(1 / #InventoryView.Tabs, -4, 1, 0)
		tabButtons[tab.Id] = b
		b.Activated:Connect(function() selectedTab = tab.Id; render() end)
	end
	search = Instance.new("TextBox")
	search.Name, search.PlaceholderText, search.Text = "Search", "Buscar item...", ""
	search.ClearTextOnFocus = false
	search.Font, search.TextSize, search.TextColor3 = Enum.Font.GothamMedium, 14, TEXT
	search.BackgroundColor3 = Color3.fromRGB(22, 32, 42)
	search.Position, search.Size = UDim2.fromOffset(12, 210), UDim2.new(1, -24, 0, 40)
	search.Parent = panel
	search:GetPropertyChangedSignal("Text"):Connect(render)
	list = Instance.new("ScrollingFrame")
	list.Position, list.Size = UDim2.fromOffset(12, 258), UDim2.new(1, -24, 1, -270)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local function fit()
		local compact = panel.AbsoluteSize.Y < 420
		header.Visible = not compact
		tabs.Position = UDim2.fromOffset(12, if compact then 46 else 158)
		search.Position = UDim2.fromOffset(12, if compact then 98 else 210)
		local y = if compact then 146 else 258
		list.Position, list.Size = UDim2.fromOffset(12, y), UDim2.new(1, -24, 1, -y - 12)
	end
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	rollFrame = Instance.new("Frame")
	rollFrame.Visible = false
	rollFrame.AnchorPoint = Vector2.new(0.5, 0)
	rollFrame.Position, rollFrame.Size = UDim2.new(0.5, 0, 0, 90), UDim2.new(1, -24, 0, 160)
	rollFrame.BackgroundColor3, rollFrame.BackgroundTransparency = BG, 0.05
	rollFrame.Parent = gui
	local rollLimit = Instance.new("UISizeConstraint")
	rollLimit.MaxSize = Vector2.new(380, 160)
	rollLimit.Parent = rollFrame
	corner(rollFrame, 10)
	stroke(rollFrame, ACCENT, 0.2)
end

--- Abre/fecha a mochila (tecla M e menu lateral, MenuController).
function InventoryController.Toggle()
	toggle()
end

function InventoryController.Init()
	build()
end

function InventoryController.Start()
	Remotes.GetEvent(Remotes.Events.NotifyProfile).OnClientEvent:Connect(function(p: any)
		if typeof(p) == "table" then
			profile = p
			if panel.Visible then render() end
		end
	end)
	Remotes.GetEvent(Remotes.Events.NotifyStand).OnClientEvent:Connect(function(event: string, data: any)
		data = if typeof(data) == "table" then data else {}
		if event == "roll" then
			showRoll(data)
		elseif event == "equip" then
			local stand = data.stand or {}
			HUDController.ShowToast("Stand ativo: " .. tostring(stand.name), tostring(stand.rarity), stand.color)
		elseif event == "race" then
			HUDController.ShowToast("Raça: " .. tostring(data.name), nil, nil)
		elseif event == "item" then
			HUDController.ShowToast(("Recebido: %s ×%d"):format(tostring(data.name), tonumber(data.amount) or 1), "Mochila (M)", ACCENT)
		elseif event == "denied" then
			HUDController.ShowToast(tostring(data.text), nil, Color3.fromRGB(255, 170, 70))
		end
	end)
	-- tecla de Stand trancada por maestria / humano apertando G (AbilityService)
	local lastDeniedToast = 0
	Remotes.GetEvent(Remotes.Events.NotifyAbilityDenied).OnClientEvent:Connect(function(_slot: number, reason: string)
		if typeof(reason) ~= "string" or os.clock() - lastDeniedToast < 1.5 then return end
		local need = reason:match("^mastery:(%d+)$")
		if need then
			lastDeniedToast = os.clock()
			HUDController.ShowToast("Tecla trancada", ("Precisa de maestria %s neste Stand (lute para subir)"):format(need), Color3.fromRGB(255, 170, 70))
		elseif reason == "no_awaken" then
			lastDeniedToast = os.clock()
			HUDController.ShowToast("Sem Stand, sem despertar", "Use uma Flecha (mochila, M)", Color3.fromRGB(255, 170, 70))
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and Controls.ActionOf(input) == "Inventory" then
			toggle()
		end
	end)
end

return InventoryController
