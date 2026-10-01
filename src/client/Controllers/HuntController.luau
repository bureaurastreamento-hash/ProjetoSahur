--!strict
local Players = game:GetService("Players")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules.RemoteEvents)
local HUD = require(script.Parent.HUDController)
local Controller = {}
local gui: ScreenGui
local panel: Frame
local list: ScrollingFrame
local stateLabel: TextLabel
local function send(action: string, id: number?)
	Remotes.GetEvent(Remotes.Events.RequestHunt):FireServer(action, id)
end
local function label(parent: Instance, value: string, size: number): TextLabel
	local item = Instance.new("TextLabel")
	item.Text, item.TextSize, item.Font = value, size, Enum.Font.GothamMedium
	item.BackgroundTransparency, item.TextColor3, item.TextWrapped = 1, Color3.fromRGB(230, 235, 240), true
	item.Parent = parent
	return item
end
local function button(parent: Instance, value: string): TextButton
	local item = Instance.new("TextButton")
	item.Text, item.Font, item.TextSize = value, Enum.Font.GothamBold, 14
	item.BackgroundColor3, item.TextColor3, item.BorderSizePixel = Color3.fromRGB(41, 92, 112), Color3.new(1, 1, 1), 0
	item.Parent = parent
	local corner = Instance.new("UICorner"); corner.CornerRadius, corner.Parent = UDim.new(0, 6), item
	return item
end
local function render(data: any)
	for _, child in list:GetChildren() do if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end end
	stateLabel.Text = if data.active then ("Caçando %s · até %s · sem GPS"):format(tostring(data.active.name), os.date("%H:%M", data.active.expires))
		else ("Vitória válida: +%d moedas e %d XP base. Alvos avisados; contrato vale %d min."):format(data.coins, data.xp, data.duration / 60)
	for i, target in data.targets or {} do
		local row = Instance.new("Frame")
		row.LayoutOrder, row.Size, row.BackgroundColor3, row.BorderSizePixel = i, UDim2.new(1, -8, 0, 76), Color3.fromRGB(25, 37, 47), 0
		row.Parent = list
		local name = label(row, ("%s · Nv. %d\nBounty: %d"):format(tostring(target.name), target.level, target.bounty), 15)
		name.Position, name.Size, name.TextXAlignment = UDim2.fromOffset(12, 6), UDim2.new(.7, -20, 1, -12), Enum.TextXAlignment.Left
		local accept = button(row, if data.active then "Em caçada" else "Aceitar")
		accept.Position, accept.Size, accept.Active = UDim2.new(.7, 0, .5, -20), UDim2.new(.3, -10, 0, 40), data.active == nil
		accept.Activated:Connect(function() if not data.active then send("accept", target.userId) end end)
	end
	if #(data.targets or {}) == 0 then
		local empty = label(list, "Nenhum procurado elegível neste servidor. Procure Fora da Lei com bounty de 50 mil ou mais e nível próximo ao seu.", 16)
		empty.Size = UDim2.new(1, -12, 0, 110)
	end
end
function Controller.Toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then send("refresh") end
end
function Controller.Init()
	gui = Instance.new("ScreenGui")
	gui.Name, gui.DisplayOrder, gui.ResetOnSpawn, gui.Parent = "HuntGui", 25, false, Players.LocalPlayer:WaitForChild("PlayerGui")
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.9, .8)
	panel.BackgroundColor3, panel.BorderSizePixel, panel.Visible, panel.Parent = Color3.fromRGB(12, 21, 30), 0, false, gui
	local bounds = Instance.new("UISizeConstraint"); bounds.MaxSize, bounds.Parent = Vector2.new(650, 580), panel
	local title = label(panel, "CONTRATOS DE CAÇADOR", 21)
	title.Position, title.Size = UDim2.fromOffset(12, 10), UDim2.new(1, -80, 0, 38)
	local close = button(panel, "X")
	close.Position, close.Size = UDim2.new(1, -52, 0, 10), UDim2.fromOffset(40, 36)
	close.Activated:Connect(function() panel.Visible = false end)
	stateLabel = label(panel, "Carregando contratos…", 14)
	stateLabel.Position, stateLabel.Size = UDim2.fromOffset(12, 55), UDim2.new(1, -24, 0, 64)
	list = Instance.new("ScrollingFrame")
	list.Position, list.Size = UDim2.fromOffset(12, 126), UDim2.new(1, -24, 1, -188)
	list.BackgroundTransparency, list.BorderSizePixel, list.ScrollBarThickness = 1, 0, 4
	list.CanvasSize, list.AutomaticCanvasSize, list.Parent = UDim2.new(), Enum.AutomaticSize.Y, panel
	local layout = Instance.new("UIListLayout"); layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 8), Enum.SortOrder.LayoutOrder, list
	local refresh = button(panel, "Atualizar")
	refresh.Position, refresh.Size = UDim2.new(0, 12, 1, -50), UDim2.new(.5, -18, 0, 38)
	refresh.Activated:Connect(function() send("refresh") end)
	local cancel = button(panel, "Cancelar caçada")
	cancel.Position, cancel.Size = UDim2.new(.5, 6, 1, -50), UDim2.new(.5, -18, 0, 38)
	cancel.Activated:Connect(function() send("cancel") end)
end
function Controller.Start()
	Remotes.GetEvent(Remotes.Events.NotifyHunt).OnClientEvent:Connect(function(event, data)
		if event == "state" then render(data)
		else
			HUD.ShowToast("Caçada", tostring(data.text or ""))
			if panel.Visible then send("refresh") end
		end
	end)
end
return Controller
