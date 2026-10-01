--!strict
-- Tools nativas, com equipar separado dos slots 1–4 do Stand.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Controls = require(ReplicatedStorage.Shared.Modules.Controls)
local FX = require(ReplicatedStorage.Shared.Modules.FX)
local Controller = {}
local player = Players.LocalPlayer
local gui: ScreenGui
local row: ScrollingFrame
local backpack: Backpack
local queued = false
local function equip(tool: Tool)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or player:GetAttribute("PreLaunchLocked") == true
		or player:GetAttribute("ClientLoading") == true or player:GetAttribute("LaunchTitleVisible") == true then return end
	if tool.Parent == character then humanoid:UnequipTools() else humanoid:EquipTool(tool) end
end
local function listTools(): { Tool }
	local tools: { Tool } = {}
	for _, container in { backpack, player.Character } do
		if container then
			for _, item in container:GetChildren() do
				if item:IsA("Tool") then table.insert(tools, item) end
			end
		end
	end
	table.sort(tools, function(a, b) return a.Name < b.Name end)
	return tools
end
local function render()
	queued = false
	for _, child in row:GetChildren() do if child:IsA("TextButton") then child:Destroy() end end
	local tools = listTools()
	for _, tool in tools do
		local button = Instance.new("TextButton")
		button.Name = tool.Name
		button.Size = UDim2.fromOffset(132, 42)
		button.BackgroundColor3 = if tool.Parent == player.Character then Color3.fromRGB(120, 95, 42) else Color3.fromRGB(30, 30, 41)
		button.TextColor3 = Color3.fromRGB(244, 231, 205)
		button.Font = Enum.Font.GothamMedium
		button.TextSize = 13
		button.TextWrapped = true
		button.Text = tool.Name
		button.Parent = row
		button.Activated:Connect(function() equip(tool) end)
	end
	gui.Enabled = #tools > 0 and player:GetAttribute("PreLaunchLocked") ~= true and player:GetAttribute("ClientLoading") ~= true and player:GetAttribute("LaunchTitleVisible") ~= true
end
local function refresh()
	if queued then return end
	queued = true
	task.defer(render)
end
function Controller.Init()
	backpack = player:WaitForChild("Backpack") :: Backpack
	gui = Instance.new("ScreenGui")
	gui.Name = "EquipmentGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 12, 1, if UserInputService.TouchEnabled then -160 else -24)
	panel.Size = UDim2.new(if UserInputService.TouchEnabled then .42 else .3, 0, 0, 74)
	panel.BackgroundTransparency = 1
	panel.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 22)
	title.Text = if UserInputService.TouchEnabled then "EQUIPAMENTOS · TOQUE" else "EQUIPAMENTOS · X / CLIQUE"
	title.TextColor3 = Color3.fromRGB(240, 196, 80)
	title.TextSize = 12
	title.Font = Enum.Font.GothamBold
	title.Parent = panel
	row = Instance.new("ScrollingFrame")
	row.Position = UDim2.fromOffset(0, 24)
	row.Size = UDim2.new(1, 0, 0, 48)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ScrollBarThickness = 3
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new()
	row.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.Name
	layout.Parent = row
	gui.Parent = player:WaitForChild("PlayerGui")
end
function Controller.Start()
	local function hideNative()
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
	end
	hideNative()
	backpack.ChildAdded:Connect(refresh)
	backpack.ChildRemoved:Connect(refresh)
	local function watch(character: Model)
		character.ChildAdded:Connect(function(child)
			refresh()
			if child:IsA("Tool") and child:GetAttribute("WeaponId") then FX.PlaySoundAt(character, "Weapon", "Draw") end
		end)
		character.ChildRemoved:Connect(refresh)
		refresh()
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then watch(player.Character) end
	player:GetAttributeChangedSignal("PreLaunchLocked"):Connect(refresh)
	player:GetAttributeChangedSignal("ClientLoading"):Connect(refresh)
	player:GetAttributeChangedSignal("LaunchTitleVisible"):Connect(refresh)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() or input.KeyCode ~= Controls.Keyboard.ToolCycle then return end
		local tools = listTools()
		local equipped = 0
		for i, tool in tools do if tool.Parent == player.Character then equipped = i end end
		if equipped == #tools then
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum:UnequipTools() end
		elseif tools[equipped + 1] then equip(tools[equipped + 1]) end
	end)
	refresh()
end
return Controller
