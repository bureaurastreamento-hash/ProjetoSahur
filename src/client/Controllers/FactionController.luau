--!strict
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local Config = require(Modules.FactionConfig)
local Remotes = require(Modules.RemoteEvents)
local Controller = {}
local player = Players.LocalPlayer
local gui: ScreenGui
local status: TextLabel
local buttons: { TextButton } = {}
local selected: string? = nil
local manualOpen = false
local function text(parent: Instance, value: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency, label.TextColor3 = 1, Color3.fromRGB(238, 238, 230)
	label.Font, label.TextSize, label.TextWrapped = Enum.Font.GothamMedium, size, true
	label.Text, label.Parent = value, parent
	return label
end
local function refresh(_profile: any)
 gui.Enabled = (manualOpen or player:GetAttribute("FactionChoiceRequired") == true)
  and player:GetAttribute("LaunchTitleVisible") ~= true
 player:SetAttribute("FactionMenuOpen", gui.Enabled)
 if gui.Enabled then
  if not selected then status.Text = "Seu progresso fica salvo nas duas facções. Pode trocar pelo Menu → Facção." end
  for _, button in buttons do button.Active = selected == nil; button.AutoButtonColor = selected == nil end
 elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
  GuiService.SelectedObject = nil
 end
end
function Controller.Toggle()
 manualOpen = not manualOpen
 selected = nil
 refresh(nil)
end
function Controller.Init()
	gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.IgnoreGuiInset = "FactionGui", false, 80, true
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local backdrop = Instance.new("Frame")
	backdrop.Size, backdrop.BackgroundColor3 = UDim2.fromScale(1, 1), Color3.fromRGB(8, 14, 22)
	backdrop.BackgroundTransparency, backdrop.BorderSizePixel, backdrop.Active = .08, 0, true
	backdrop.Parent = gui
	local panel = Instance.new("ScrollingFrame")
	panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.new(.94, 0, .86, 0)
	panel.BackgroundTransparency, panel.BorderSizePixel, panel.ScrollBarThickness = 1, 0, 4
	panel.CanvasSize, panel.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
	panel.Parent = backdrop
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize, bounds.Parent = Vector2.new(650, 640), panel
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 16), Enum.SortOrder.LayoutOrder, panel
	local title = text(panel, "BIZARRE SHOWDOWN F/X", 24)
	title.Size, title.LayoutOrder, title.Font = UDim2.new(1, -8, 0, 64), 1, Enum.Font.GothamBlack
	local subtitle = text(panel, "ESCOLHA SUA FACÇÃO", 30)
	subtitle.Size, subtitle.LayoutOrder = UDim2.new(1, -8, 0, 40), 2
	for i, entry in Config.List do
		local button = Instance.new("TextButton")
		button.Name, button.LayoutOrder, button.Size = entry.Id, i + 2, UDim2.new(1, -8, 0, 118)
		button.BackgroundColor3, button.BorderSizePixel, button.Text = Color3.fromRGB(238, 193, 78), 0, ""
		button.Selectable, button.Parent = true, panel
		button.AutoButtonColor = true
		local stroke = Instance.new("UIStroke"); stroke.Color, stroke.Thickness, stroke.ApplyStrokeMode, stroke.Parent = Color3.fromRGB(18, 25, 35), 3, Enum.ApplyStrokeMode.Border, button
		local name = text(button, entry.Name:upper(), 25)
		name.TextColor3, name.Font, name.TextXAlignment = Color3.fromRGB(18, 25, 35), Enum.Font.GothamBlack, Enum.TextXAlignment.Left
		name.Position, name.Size = UDim2.fromOffset(16, 8), UDim2.new(1, -32, 0, 36)
		local description = text(button, entry.Description, 15)
		description.TextColor3, description.TextXAlignment = Color3.fromRGB(18, 25, 35), Enum.TextXAlignment.Left
		description.Position, description.Size = UDim2.fromOffset(16, 48), UDim2.new(1, -32, 0, 62)
		button.Activated:Connect(function()
			if selected then return end
			selected = entry.Id
			status.Text = "Salvando sua escolha…"
			Remotes.GetEvent(Remotes.Events.RequestFaction):FireServer(entry.Id)
		end)
		table.insert(buttons, button)
	end
 local close = Instance.new("TextButton")
 close.Size, close.Position, close.Text = UDim2.fromOffset(44,44), UDim2.new(1,-56,0,12), "×"
 close.BackgroundTransparency, close.TextColor3, close.TextSize, close.Parent = 1, Color3.fromRGB(238,193,78), 26, backdrop
 close.Activated:Connect(function()
  if player:GetAttribute("FactionChoiceRequired") == true then return end
  manualOpen, selected = false, nil
  refresh(nil)
 end)
	status = text(panel, "Carregando seu perfil…", 14)
	status.Size, status.LayoutOrder = UDim2.new(1, -8, 0, 66), 5
end
function Controller.Start()
	Remotes.GetEvent(Remotes.Events.NotifyProfile).OnClientEvent:Connect(refresh)
	Remotes.GetEvent(Remotes.Events.NotifyFaction).OnClientEvent:Connect(function(event, data)
		if event == "chosen" then manualOpen, selected = false, nil; refresh(nil)
		elseif event == "waiting" then status.Text = "Preparando seu personagem… sua escolha será aplicada ao carregar." end
	end)
 for _, attribute in {"FactionChoiceRequired", "LaunchTitleVisible"} do
  player:GetAttributeChangedSignal(attribute):Connect(function() refresh(nil) end)
 end
	Remotes.GetEvent(Remotes.Events.RequestProfile):FireServer()
	refresh(nil)
end
return Controller
