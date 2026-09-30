--!strict
--[[ HUD compacto da campanha F/X + ECOS (escolhas na tela) + distorção da estrutura (Missão 0). ]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))

local StoryController = {}
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local title: TextLabel
local body: TextLabel
local choiceGui: ScreenGui
local storyBounds: UISizeConstraint

local function label(parent: Instance, size: UDim2, pos: UDim2, textSize: number, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.Size, item.Position = size, pos
	item.BackgroundTransparency = 1
	item.Font = Enum.Font.GothamMedium
	item.TextSize, item.TextColor3 = textSize, color
	item.TextXAlignment, item.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
	item.TextWrapped = true
	item.Parent = parent
	return item
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "FXStoryGui", false, 7
	gui.Parent = playerGui
	local frame = Instance.new("Frame")
	frame.Size, frame.Position = UDim2.new(1, -32, .4, 0), UDim2.new(0, 16, 0, 72)
	storyBounds = Instance.new("UISizeConstraint")
	storyBounds.MaxSize = Vector2.new(300, 180)
	storyBounds.Parent = frame
	frame.BackgroundColor3, frame.BackgroundTransparency = Color3.fromRGB(12, 20, 28), .2
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 0); corner.Parent = frame
	local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(70, 205, 255); stroke.Transparency = .55; stroke.Parent = frame
	title = label(frame, UDim2.new(1,-20,0,38), UDim2.fromOffset(10,8), 15, Color3.fromRGB(100,220,255))
	title.Font = Enum.Font.GothamBold
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name, scroll.BackgroundTransparency, scroll.BorderSizePixel = "Objectives", 1, 0
	scroll.Position, scroll.Size = UDim2.fromOffset(0, 48), UDim2.new(1, 0, 1, -52)
	scroll.CanvasSize, scroll.AutomaticCanvasSize, scroll.ScrollBarThickness = UDim2.new(), Enum.AutomaticSize.Y, 4
	scroll.Parent = frame
	body = label(scroll, UDim2.new(1,-20,0,0), UDim2.fromOffset(10,0), 13, Color3.fromRGB(235,240,245))
	body.AutomaticSize = Enum.AutomaticSize.Y
end

local function render(data: any)
	title.Text = ("F/X · %s\n%s"):format(tostring(data.chapterTitle), tostring(data.actTitle))
	local lines = {}
	for _, objective in data.objectives or {} do
		local item = objective :: any
		table.insert(lines, ("%s %s  %d/%d"):format(if item.progress >= item.goal then "✓" else "•", tostring(item.text), item.progress, item.goal))
	end
	body.Text = if #lines > 0 then table.concat(lines, "\n") else tostring(data.hint or "Explore a região atual.")
	local optional = data.optional or {}
	for _, quest in optional do
		table.insert(lines, ("Opcional: %s%s"):format(tostring(quest.title), if quest.ready then " → entregue ao Humanoider" else ""))
	end
	if #optional > 0 then
		body.Text ..= "\n\n" .. table.concat(lines, "\n", #lines - #optional + 1)
	end
	storyBounds.MaxSize = Vector2.new(300, math.min(300, 100 + #(data.objectives or {}) * 38 + #optional * 60))
end

-- ECO: escolha na tela. Opção trancada (não explorou) aparece apagada com "?" no lugar da descrição.
local function showChoice(data: any)
	if choiceGui then choiceGui:Destroy() end
	choiceGui = Instance.new("ScreenGui")
	choiceGui.Name, choiceGui.ResetOnSpawn, choiceGui.DisplayOrder = "FXChoiceGui", false, 20
	choiceGui.Parent = playerGui
	local dim = Instance.new("Frame")
	dim.Size, dim.BackgroundColor3, dim.BackgroundTransparency = UDim2.fromScale(1, 1), Color3.new(0, 0, 0), 0.45
	dim.Parent = choiceGui
	local options = if typeof(data.options) == "table" then data.options else {}
	local panel = Instance.new("ScrollingFrame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	local contentHeight = 150 + #options * 62
	panel.Size = UDim2.new(1, -24, 1, -80)
	panel.CanvasSize = UDim2.fromOffset(0, contentHeight)
	panel.ScrollBarThickness = 5
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(520, contentHeight)
	bounds.Parent = panel
	panel.BackgroundColor3, panel.BackgroundTransparency = Color3.fromRGB(12, 20, 28), 0.04
	panel.Parent = choiceGui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 0); corner.Parent = panel
	local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(255, 170, 70); stroke.Thickness = 2; stroke.Parent = panel
	local head = label(panel, UDim2.new(1, -32, 0, 30), UDim2.fromOffset(16, 14), 20, Color3.fromRGB(255, 190, 90))
	head.Font = Enum.Font.GothamBlack
	head.Text = tostring(data.title)
	local text = label(panel, UDim2.new(1, -32, 0, 80), UDim2.fromOffset(16, 50), 15, Color3.fromRGB(235, 240, 245))
	text.Text = tostring(data.text)
	for i, option in options do
		local o = option :: any
		local b = Instance.new("TextButton")
		b.Position = UDim2.new(0, 16, 0, 130 + (i - 1) * 62)
		b.Size = UDim2.new(1, -32, 0, 54)
		b.AutoButtonColor = o.enabled == true
		b.BackgroundColor3 = if o.enabled then Color3.fromRGB(34, 52, 68) else Color3.fromRGB(28, 30, 34)
		b.Text = ""
		b.Parent = panel
		local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 0); bc.Parent = b
		local name = label(b, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 6), 16, if o.enabled then Color3.new(1, 1, 1) else Color3.fromRGB(110, 115, 120))
		name.Font = Enum.Font.GothamBold
		name.Text = if o.enabled then tostring(o.label) else "???"
		local desc = label(b, UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 30), 13, Color3.fromRGB(160, 170, 180))
		desc.Text = if o.enabled then tostring(o.desc) else "Você ainda não conhece este caminho."
		if o.enabled then
			b.Activated:Connect(function()
				Remotes.GetEvent(Remotes.Events.RequestStoryChoice):FireServer(data.id, o.id)
				choiceGui:Destroy()
			end)
		end
	end
end

-- Missão 0: por menos de um segundo, outro lugar (flash azulado + cor estourada) e volta.
local function distort()
	local flash = Instance.new("ScreenGui")
	flash.Name, flash.IgnoreGuiInset, flash.DisplayOrder = "FXDistort", true, 30
	flash.Parent = playerGui
	local f = Instance.new("Frame")
	f.Size, f.BackgroundColor3, f.BackgroundTransparency = UDim2.fromScale(1, 1), Color3.fromRGB(170, 230, 255), 1
	f.Parent = flash
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "FXDistortColor"
	cc.Parent = Lighting
	TweenService:Create(f, TweenInfo.new(0.12), { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(cc, TweenInfo.new(0.12), { Saturation = -1, Contrast = 0.8, TintColor = Color3.fromRGB(255, 170, 120) }):Play()
	task.delay(0.55, function()
		TweenService:Create(f, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		local back = TweenService:Create(cc, TweenInfo.new(0.6), { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) })
		back:Play()
		back.Completed:Wait()
		cc:Destroy()
		flash:Destroy()
	end)
end

function StoryController.Init() build() end
function StoryController.Start()
	Remotes.GetEvent(Remotes.Events.NotifyStory).OnClientEvent:Connect(function(event: string, data: any)
		if event == "trace" then
			HUDController.ShowToast(tostring(data.title), tostring(data.text), Color3.fromRGB(80,210,255))
		elseif event == "locked" then
			HUDController.ShowToast("Rota selada", tostring(data.text), Color3.fromRGB(255,170,70))
		elseif event == "choice" then
			showChoice(data)
		elseif event == "distort" then
			distort()
		else
			render(data)
			if event == "act" then HUDController.ShowToast("Campanha F/X", tostring(data.actTitle), Color3.fromRGB(80,210,255)) end
		end
	end)
	Remotes.GetEvent(Remotes.Events.RequestStoryState):FireServer()
end
return StoryController
