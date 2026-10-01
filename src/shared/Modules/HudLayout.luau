--!strict
-- Apresentação somente; valores chegam do servidor pelos controllers existentes.
local Layout = {}
Layout.Ink = Color3.fromRGB(18, 25, 35)
Layout.Gold = Color3.fromRGB(238, 193, 78)
local function text(parent: Instance, name: string, value: string, size: UDim2, position: UDim2, pixels: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name, label.Text, label.Size, label.Position = name, value, size, position
	label.BackgroundTransparency, label.BorderSizePixel = 1, 0
	label.Font, label.TextSize = Enum.Font.GothamBlack, pixels
	label.TextColor3, label.TextStrokeTransparency = Color3.fromRGB(248, 246, 228), .35
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end
local function border(frame: GuiObject, color: Color3)
	for _, child in frame:GetChildren() do
		if child:IsA("UICorner") or child:IsA("UIStroke") then child:Destroy() end
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.ApplyStrokeMode = color, 2, Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
end
function Layout.Apply(hud: ScreenGui): (TextLabel, TextLabel)
	local vitals = hud:WaitForChild("Vitals") :: Frame
	vitals.Size, vitals.Position = UDim2.fromOffset(320, 242), UDim2.new(0, 18, 1, -20)
	vitals.BackgroundTransparency = 1
	local coins = hud:WaitForChild("Coins") :: TextLabel
	coins.Parent, coins.AnchorPoint = vitals, Vector2.zero
	coins.Size, coins.Position = UDim2.fromOffset(310, 34), UDim2.fromOffset(0, 0)
	coins.Font, coins.TextSize, coins.TextColor3 = Enum.Font.GothamBlack, 28, Color3.fromRGB(123, 238, 114)
	coins.TextStrokeTransparency, coins.TextXAlignment = .1, Enum.TextXAlignment.Left
	local level = vitals:WaitForChild("LevelBadge") :: Frame
	level.Size, level.Position, level.BackgroundTransparency = UDim2.fromOffset(150, 34), UDim2.fromOffset(0, 34), 1
	for _, child in level:GetChildren() do
		if child:IsA("TextLabel") and child.Name ~= "Value" then child.Visible = false end
		if child:IsA("UICorner") or child:IsA("UIStroke") then child:Destroy() end
	end
	local value = level:WaitForChild("Value") :: TextLabel
	value.Size, value.Position, value.Font, value.TextSize = UDim2.fromScale(1, 1), UDim2.new(), Enum.Font.GothamBlack, 29
	value.TextXAlignment, value.TextStrokeTransparency, value.Text = Enum.TextXAlignment.Left, .1, "Nv. 1"
	local xp = vitals:WaitForChild("XP") :: Frame
	xp.Size, xp.Position, xp.BackgroundColor3 = UDim2.fromOffset(310, 16), UDim2.fromOffset(0, 73), Layout.Ink
	border(xp, Layout.Gold)
	local xpFill = xp:WaitForChild("Fill") :: Frame
	xpFill.BackgroundColor3 = Color3.fromRGB(174, 93, 228)
	local xpText = text(xp, "Progress", "0 / 100 XP", UDim2.fromScale(1, 1), UDim2.new(), 12)
	xpText.TextXAlignment, xpText.ZIndex = Enum.TextXAlignment.Center, 3
	local bars: { { Name: string, Y: number, Height: number, Color: Color3 } } = { { Name = "Health", Y = 97, Height = 43, Color = Color3.fromRGB(68, 186, 72) }, { Name = "Energy", Y = 150, Height = 33, Color = Color3.fromRGB(23, 156, 200) } }
	for _, spec in bars do
		local bar = vitals:WaitForChild(spec.Name) :: Frame
		bar.Size, bar.Position = UDim2.fromOffset(310, spec.Height), UDim2.fromOffset(0, spec.Y)
		bar.BackgroundColor3, bar.BackgroundTransparency = Layout.Ink, 0
		border(bar, Layout.Gold)
		local fill = bar:WaitForChild("Fill") :: Frame
		fill.BackgroundColor3, fill.BackgroundTransparency = spec.Color, 0
		for _, child in fill:GetChildren() do if child:IsA("UICorner") then child:Destroy() end end
		local label = bar:WaitForChild("Text") :: TextLabel
		label.AnchorPoint = Vector2.zero
		label.TextColor3 = Color3.fromRGB(250, 248, 236)
		label.Position, label.Size = UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0)
		label.Font, label.TextSize, label.TextStrokeTransparency = Enum.Font.GothamBlack, if spec.Name == "Health" then 20 else 16, .15
		label.TextXAlignment, label.ZIndex = Enum.TextXAlignment.Left, 3
	end
	local name = vitals:WaitForChild("CharacterName") :: TextLabel
	name.Position, name.Size, name.TextSize = UDim2.fromOffset(0, 189), UDim2.fromOffset(310, 20), 15
	name.TextXAlignment, name.TextColor3 = Enum.TextXAlignment.Left, Layout.Gold
	local counter = vitals:WaitForChild("Counter") :: Frame
	counter.Position, counter.Size = UDim2.fromOffset(0, 230), UDim2.fromOffset(310, 8)
	local dash = vitals:WaitForChild("DashChips") :: Frame
	dash.Position, dash.Size = UDim2.fromOffset(310, 215), UDim2.fromOffset(142, 12)
	local reputation = text(vitals, "Reputation", "Escolha sua facção", UDim2.fromOffset(165, 18), UDim2.fromOffset(0, 211), 12)
	local abilities = hud:WaitForChild("Abilities") :: Frame
	abilities.Position, abilities.Size = UDim2.new(.5, 60, 1, -20), UDim2.fromOffset(424, 74)
	for _, slot in abilities:GetChildren() do
		if not slot:IsA("Frame") then continue end
		slot.Size, slot.BackgroundColor3, slot.BackgroundTransparency = UDim2.fromOffset(64, 74), Layout.Ink, .1
		border(slot, Layout.Gold)
		local overlay = slot:FindFirstChild("CooldownText") :: TextLabel?
		if overlay then overlay.TextSize = 14 end
		local slotName = slot:FindFirstChild("Name") :: TextLabel?
		if slotName then slotName.TextSize, slotName.TextColor3, slotName.TextStrokeTransparency = 12, Color3.fromRGB(246, 239, 211), .4 end
		local key = slot:FindFirstChild("Key") :: TextLabel?
		if key then key.Font, key.TextSize, key.TextColor3 = Enum.Font.GothamBlack, 15, Layout.Gold end
	end
	return xpText, reputation
end
return Layout
