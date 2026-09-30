--!strict
--[[
	WorldShopController — painel do MERCADOR ERRANTE e da FORJA do Ferreiro (WorldEventsService). O servidor manda
	a lista pronta (preço, custo, se dá para comprar/forjar); aqui só desenha e pede. Fecha sozinho quando o
	jogador se afasta, quando o mercador vai embora ou no X / Esc.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))

local WorldShopController = {}

local localPlayer = Players.LocalPlayer
local BG = Color3.fromRGB(12, 20, 28)
local ROW = Color3.fromRGB(22, 32, 42)
local ACCENT = Color3.fromRGB(70, 205, 255)
local OFF = Color3.fromRGB(70, 78, 88)
local TEXT = Color3.fromRGB(235, 240, 245)
local MUTED = Color3.fromRGB(150, 160, 170)
local CLOSE_DISTANCE = 26

local gui: ScreenGui
local panel: Frame
local title: TextLabel
local subtitle: TextLabel
local list: ScrollingFrame
local openKind: string? = nil
local openedAt: Vector3? = nil

local function label(parent: Instance, text: string, size: number, color: Color3, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	l.TextSize, l.TextColor3, l.Text = size, color, text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function close()
	panel.Visible = false
	openKind = nil
end

local function render(data: any)
	title.Text = tostring(data.title or "")
	subtitle.Text = tostring(data.subtitle or "")
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, entry in (if typeof(data.entries) == "table" then data.entries else {}) do
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -8, 0, 74)
		row.BackgroundColor3 = ROW
		row.BorderSizePixel = 0
		row.Parent = list
		local s = Instance.new("UIStroke")
		s.Color = if typeof(entry.color) == "Color3" then entry.color else ACCENT
		s.Transparency = 0.5
		s.Parent = row
		local name = label(row, tostring(entry.name), 14, s.Color, true)
		name.Position, name.Size = UDim2.fromOffset(10, 6), UDim2.new(1, -150, 0, 18)
		local desc = label(row, tostring(entry.desc or ""), 12, MUTED)
		desc.Position, desc.Size = UDim2.fromOffset(10, 26), UDim2.new(1, -150, 0, 44)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = entry.can == true
		b.BackgroundColor3 = if entry.can == true then ACCENT else OFF
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.TextColor3 = Color3.fromRGB(15, 15, 20)
		b.Text = ("%s · %d"):format(tostring(entry.action or "Comprar"), tonumber(entry.price) or 0)
		b.Position, b.Size = UDim2.new(1, -134, 0.5, -16), UDim2.fromOffset(124, 32)
		b.Parent = row
		b.Activated:Connect(function()
			if openKind then
				Remotes.GetEvent(Remotes.Events.RequestWorldShop):FireServer(openKind, tostring(entry.id))
			end
		end)
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "WorldShopGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	panel = Instance.new("Frame")
	panel.Name = "Painel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.42, 0, 0.6, 0)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize, limit.MaxSize = Vector2.new(340, 300), Vector2.new(620, 620)
	limit.Parent = panel
	local s = Instance.new("UIStroke")
	s.Color, s.Transparency = ACCENT, 0.6
	s.Parent = panel
	title = label(panel, "", 20, TEXT, true)
	title.Position, title.Size = UDim2.fromOffset(16, 12), UDim2.new(1, -70, 0, 26)
	subtitle = label(panel, "", 13, MUTED)
	subtitle.Position, subtitle.Size = UDim2.fromOffset(16, 40), UDim2.new(1, -32, 0, 34)
	local x = Instance.new("TextButton")
	x.Text, x.Font, x.TextSize, x.TextColor3 = "X", Enum.Font.GothamBold, 18, TEXT
	x.BackgroundColor3, x.BorderSizePixel = ROW, 0
	x.Position, x.Size = UDim2.new(1, -44, 0, 10), UDim2.fromOffset(34, 30)
	x.Parent = panel
	x.Activated:Connect(close)
	list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position, list.Size = UDim2.fromOffset(12, 80), UDim2.new(1, -24, 1, -92)
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
end

function WorldShopController.Start()
	build()
	Remotes.GetEvent(Remotes.Events.NotifyWorldShop).OnClientEvent:Connect(function(event: string, data: any)
		if event == "open" then
			openKind = tostring(data.kind)
			local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
			openedAt = if root and root:IsA("BasePart") then root.Position else nil
			render(data)
			panel.Visible = true
		elseif event == "close" then
			if openKind == data.kind then
				close()
			end
		elseif event == "result" then
			HUDController.ShowToast(tostring(data.title), tostring(data.text))
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
			close()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if not panel.Visible or not openedAt then
			return
		end
		local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (root.Position - openedAt).Magnitude > CLOSE_DISTANCE then
			close()
		end
	end)
end

return WorldShopController
