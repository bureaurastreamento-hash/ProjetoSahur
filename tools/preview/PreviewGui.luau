-- LocalScript: lista as animações (StringValue PreviewList) e manda tocar (RemoteEvent PreviewPlay).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage:WaitForChild("PreviewPlay")
local list = ReplicatedStorage:WaitForChild("PreviewList")

local gui = Instance.new("ScreenGui")
gui.Name = "AnimPreview"
gui.ResetOnSpawn = false
gui.Parent = script.Parent

local frame = Instance.new("ScrollingFrame")
frame.Size = UDim2.new(0, 300, 1, -120)
frame.Position = UDim2.new(0, 10, 0, 60)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.ScrollBarThickness = 6
frame.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = frame

local loopBox = Instance.new("TextButton")
loopBox.Size = UDim2.new(0, 300, 0, 30)
loopBox.Position = UDim2.new(0, 10, 0, 26)
loopBox.Text = "Loop: OFF (clique para alternar)"
loopBox.Font = Enum.Font.GothamBold
loopBox.TextSize = 14
loopBox.TextColor3 = Color3.new(1, 1, 1)
loopBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
loopBox.Parent = gui
local loop = false
loopBox.MouseButton1Click:Connect(function()
	loop = not loop
	loopBox.Text = "Loop: " .. (loop and "ON" or "OFF") .. " (clique para alternar)"
end)

local i = 0
for name in list.Value:gmatch("[^\n]+") do
	i += 1
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -8, 0, 26)
	b.LayoutOrder = i
	b.Text = "  " .. name
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Font = Enum.Font.Gotham
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	b.Parent = frame
	b.MouseButton1Click:Connect(function()
		remote:FireServer(name, loop)
	end)
end
frame.CanvasSize = UDim2.new(0, 0, 0, i * 28)
