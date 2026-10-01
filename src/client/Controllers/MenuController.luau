--!strict
--[[
	MenuController — MENU LATERAL na tela (HUD estilo Blox Fruits, dono 28/09: "menus na tela; o dropdown do topbar
	fica só para menus sérios"). Botões à esquerda, no meio da tela; cada um abre o mesmo painel da tecla dele.
	Painéis: InventoryController (Mochila) e TopbarController.Toggle (Loja, Visual, Perfil, Conquistas, Duelo, Clã, Placar).
]]
local Players = game:GetService("Players")

local InventoryController = require(script.Parent:WaitForChild("InventoryController"))
local TopbarController = require(script.Parent:WaitForChild("TopbarController"))

local HuntController = require(script.Parent.HuntController)
local GoalsController = require(script.Parent.GoalsController)
local FX = require(game:GetService("ReplicatedStorage").Shared.Modules.FX)
local MenuController = {}

-- ordem de cima para baixo: nome, tecla (só o texto), ação
local ITEMS: { { string } } = {
	{ "Mochila", "M" },
	{ "Objetivos", "" },
	{ "Loja", "L" },
	{ "Visual", "K" },
	{ "Perfil", "P" },
	{ "Conquistas", "" },
	{ "Duelo", "J" },
	{ "Caçadas", "" },
	{ "Clã", "C" },
	{ "Placar", "Tab" },
}

local function open(name: string)
	if name == "Mochila" then
		InventoryController.Toggle()
	elseif name == "Objetivos" then
		GoalsController.Toggle()
	elseif name == "Caçadas" then
		HuntController.Toggle()
	else
		TopbarController.Toggle(name)
	end
end

function MenuController.Init()
	local UserInputService = game:GetService("UserInputService")
	local Workspace = game:GetService("Workspace")
	local Ink = Color3.fromRGB(18, 25, 35)
	local Gold = Color3.fromRGB(238, 193, 78)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "SideMenu", false, 6
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local container = Instance.new("Frame")
	container.Name, container.BackgroundTransparency = "Menu", 1
	container.AnchorPoint, container.Position = Vector2.new(0, 1), UDim2.new(0, 18, 1, -276)
	container.Size = UDim2.fromOffset(310, 98)
	container.Parent = gui
	local scale = Instance.new("UIScale"); scale.Parent = container
	local column = Instance.new("ScrollingFrame")
	column.Name, column.Visible = "More", false
	column.AnchorPoint, column.Position, column.Size = Vector2.new(0, 1), UDim2.fromOffset(326, 98), UDim2.fromOffset(176, 320)
	column.BackgroundColor3, column.BackgroundTransparency = Ink, .05
	column.BorderSizePixel, column.ScrollBarThickness = 0, 4
	column.CanvasSize, column.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
	column.Parent = container
	local layout = Instance.new("UIListLayout"); layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 8), Enum.SortOrder.LayoutOrder, column
	local function button(parent: Instance, name: string, key: string): TextButton
		local item = Instance.new("TextButton")
		item.Name, item.Text = name, name .. (if key ~= "" then "  [" .. key .. "]" else "")
		item.Size = UDim2.fromOffset(150, 44)
		item.BackgroundColor3, item.TextColor3, item.BorderSizePixel = Gold, Ink, 0
		item.Font, item.TextSize, item.Selectable = Enum.Font.GothamBlack, 16, true
		item.Parent = parent
		local stroke = Instance.new("UIStroke"); stroke.Color, stroke.Thickness, stroke.ApplyStrokeMode, stroke.Parent = Ink, 2, Enum.ApplyStrokeMode.Border, item
		return item
	end
	local names = { { "Mochila", "M" }, { "Perfil", "P" }, { "Objetivos", "" }, { "Menu", "" } }
	for index, row in names do
		local item = button(container, row[1], row[2])
		item.Position = UDim2.fromOffset(((index - 1) % 2) * 160, math.floor((index - 1) / 2) * 54)
		item.Activated:Connect(function()
			FX.PlaySoundUI("CC0", "click_001")
			if row[1] == "Menu" then column.Visible = not column.Visible
			else column.Visible = false; open(row[1]) end
		end)
	end
	for i, row in ITEMS do
		if row[1] == "Mochila" or row[1] == "Perfil" or row[1] == "Objetivos" then continue end
		local item = button(column, row[1], row[2]); item.Size, item.LayoutOrder = UDim2.new(1, -8, 0, 44), i
		item.Activated:Connect(function()
			FX.PlaySoundUI("CC0", "click_001"); column.Visible = false; open(row[1]) end)
	end
	local function responsive()
		local camera = Workspace.CurrentCamera
		if not camera then return end
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		scale.Scale = if touch then math.clamp(camera.ViewportSize.Y / 760, .65, .9) else math.clamp(camera.ViewportSize.X / 1440, .78, 1.1)
		container.Position = if touch then UDim2.fromOffset(14, 92 + 242 * scale.Scale + 110 * scale.Scale) else UDim2.new(0, 18, 1, -20 - 252 * scale.Scale)
	end
	responsive()
	if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(responsive) end
end

return MenuController
