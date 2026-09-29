--!strict
--[[
	MenuController — MENU LATERAL na tela (HUD estilo Blox Fruits, dono 28/09: "menus na tela; o dropdown do topbar
	fica só para menus sérios"). Botões à esquerda, no meio da tela; cada um abre o mesmo painel da tecla dele.
	Painéis: InventoryController (Mochila) e TopbarController.Toggle (Loja, Visual, Perfil, Conquistas, Duelo, Clã, Placar).
]]
local Players = game:GetService("Players")

local InventoryController = require(script.Parent:WaitForChild("InventoryController"))
local TopbarController = require(script.Parent:WaitForChild("TopbarController"))

local MenuController = {}

local BG = Color3.fromRGB(14, 22, 30)
local ACCENT = Color3.fromRGB(70, 205, 255)
local TEXT = Color3.fromRGB(235, 240, 245)
local KEY = Color3.fromRGB(255, 210, 90)

-- ordem de cima para baixo: nome, tecla (só o texto), ação
local ITEMS: { { string } } = {
	{ "Mochila", "M" },
	{ "Loja", "L" },
	{ "Visual", "K" },
	{ "Perfil", "P" },
	{ "Conquistas", "" },
	{ "Duelo", "J" },
	{ "Clã", "C" },
	{ "Placar", "Tab" },
}

local function open(name: string)
	if name == "Mochila" then
		InventoryController.Toggle()
	else
		TopbarController.Toggle(name)
	end
end

function MenuController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "SideMenu", false, 6
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local column = Instance.new("Frame")
	column.Name = "Column"
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, 12, 0.5, 10)
	if game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled then
		column.Position = UDim2.new(0, 12, 0.5, 60) -- toque: abaixo do status (que sobe), longe do analógico
		local scale = Instance.new("UIScale"); scale.Scale = 0.8; scale.Parent = column
	end
	column.Size = UDim2.fromOffset(92, #ITEMS * 44)
	column.BackgroundTransparency = 1
	column.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = column
	for i, entry in ITEMS do
		local name, key = entry[1], entry[2]
		local b = Instance.new("TextButton")
		b.Name = name
		b.LayoutOrder = i
		b.Size = UDim2.fromOffset(92, 38)
		b.BackgroundColor3, b.BackgroundTransparency = BG, 0.15
		b.AutoButtonColor = true
		b.Text = ""
		b.Parent = column
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
		local s = Instance.new("UIStroke"); s.Color = ACCENT; s.Transparency = 0.6; s.Parent = b
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position, label.Size = UDim2.fromOffset(10, 0), UDim2.new(1, -36, 1, 0)
		label.Font, label.TextSize, label.TextColor3 = Enum.Font.GothamBold, 14, TEXT
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = name
		label.Parent = b
		if key ~= "" then
			local k = Instance.new("TextLabel")
			k.BackgroundTransparency = 1
			k.AnchorPoint = Vector2.new(1, 0.5)
			k.Position, k.Size = UDim2.new(1, -8, 0.5, 0), UDim2.fromOffset(28, 18)
			k.Font, k.TextSize, k.TextColor3 = Enum.Font.GothamBlack, 12, KEY
			k.TextXAlignment = Enum.TextXAlignment.Right
			k.Text = key
			k.Parent = b
		end
		b.Activated:Connect(function()
			open(name)
		end)
	end
end

return MenuController
