--!strict
local Players = game:GetService("Players")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local Goals = require(Modules.GoalsConfig)
local Remotes = require(Modules.RemoteEvents)
local Controller = {}
local panel: Frame
local body: TextLabel
function Controller.Toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then Remotes.GetEvent(Remotes.Events.RequestProfile):FireServer() end
end
function Controller.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Parent = "GoalsGui", false, 24, Players.LocalPlayer:WaitForChild("PlayerGui")
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.9, .8)
	panel.BackgroundColor3, panel.BorderSizePixel, panel.Visible, panel.Parent = Color3.fromRGB(12, 21, 30), 0, false, gui
	local bounds = Instance.new("UISizeConstraint"); bounds.MaxSize, bounds.Parent = Vector2.new(650, 600), panel
	local title = Instance.new("TextLabel")
	title.Text, title.Font, title.TextSize, title.TextColor3 = "MEUS OBJETIVOS", Enum.Font.GothamBold, 23, Color3.fromRGB(87, 208, 224)
	title.BackgroundTransparency, title.Position, title.Size, title.Parent = 1, UDim2.fromOffset(12, 10), UDim2.new(1, -80, 0, 40), panel
	local close = Instance.new("TextButton")
	close.Text, close.TextColor3, close.BackgroundColor3, close.BorderSizePixel = "X", Color3.new(1, 1, 1), Color3.fromRGB(42, 69, 83), 0
	close.Position, close.Size, close.Parent = UDim2.new(1, -50, 0, 12), UDim2.fromOffset(36, 36), panel
	close.Activated:Connect(function() panel.Visible = false end)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency, scroll.BorderSizePixel, scroll.ScrollBarThickness = 1, 0, 5
	scroll.Position, scroll.Size, scroll.CanvasSize, scroll.AutomaticCanvasSize = UDim2.fromOffset(14, 62), UDim2.new(1, -28, 1, -76), UDim2.new(), Enum.AutomaticSize.Y
	scroll.Parent = panel
	body = Instance.new("TextLabel")
	body.BackgroundTransparency, body.TextColor3, body.TextSize, body.Font = 1, Color3.fromRGB(231, 236, 242), 16, Enum.Font.GothamMedium
	body.TextXAlignment, body.TextYAlignment, body.TextWrapped = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top, true
	body.Text, body.Size, body.AutomaticSize, body.Parent = "Carregando seus objetivos…", UDim2.new(1, -12, 0, 0), Enum.AutomaticSize.Y, scroll
end
function Controller.Start()
	Remotes.GetEvent(Remotes.Events.NotifyProfile).OnClientEvent:Connect(function(profile)
		local lines = {}
		for _, row in Goals.Rows(profile) do table.insert(lines, row.title .. "\n" .. row.text) end
		body.Text = table.concat(lines, "\n\n")
	end)
end
return Controller
