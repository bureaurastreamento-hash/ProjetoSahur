--!strict
--[[ HUD compacto da campanha F/X. ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))

local StoryController = {}
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local title: TextLabel
local body: TextLabel

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
	frame.Size, frame.Position = UDim2.fromOffset(300, 112), UDim2.new(0, 16, 0, 72)
	frame.BackgroundColor3, frame.BackgroundTransparency = Color3.fromRGB(12, 20, 28), .2
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 9); corner.Parent = frame
	local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(70, 205, 255); stroke.Transparency = .55; stroke.Parent = frame
	title = label(frame, UDim2.new(1,-20,0,38), UDim2.fromOffset(10,8), 15, Color3.fromRGB(100,220,255))
	title.Font = Enum.Font.GothamBold
	body = label(frame, UDim2.new(1,-20,1,-48), UDim2.fromOffset(10,42), 13, Color3.fromRGB(235,240,245))
end

local function render(data: any)
	title.Text = ("F/X · %s\n%s"):format(tostring(data.chapterTitle), tostring(data.actTitle))
	local lines = {}
	for _, objective in data.objectives or {} do
		local item = objective :: any
		table.insert(lines, ("%s %s  %d/%d"):format(if item.progress >= item.goal then "✓" else "•", tostring(item.text), item.progress, item.goal))
	end
	body.Text = if #lines > 0 then table.concat(lines, "\n") else tostring(data.hint or "Explore a região atual.")
end

function StoryController.Init() build() end
function StoryController.Start()
	Remotes.GetEvent(Remotes.Events.NotifyStory).OnClientEvent:Connect(function(event: string, data: any)
		if event == "trace" then
			HUDController.ShowToast(tostring(data.title), tostring(data.text), Color3.fromRGB(80,210,255))
		elseif event == "locked" then
			HUDController.ShowToast("Rota selada", tostring(data.text), Color3.fromRGB(255,170,70))
		else
			render(data)
			if event == "act" then HUDController.ShowToast("Campanha F/X", tostring(data.actTitle), Color3.fromRGB(80,210,255)) end
		end
	end)
	Remotes.GetEvent(Remotes.Events.RequestStoryState):FireServer()
end
return StoryController
