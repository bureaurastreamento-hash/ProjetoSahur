--!strict
--[[
	TrailerController (cliente)
	Câmera e cartelas do trailer (TrailerService manda os eventos por NotifyTrailer):
	  begin              esconde HUD/topbar, barras pretas, câmera Scriptable
	  shot { from, to, t, fov?, ease?, look? }             dolly de CFrame a CFrame (look = nome de Model a olhar)
	  shot { orbit, radius, height, from, to, t, fov? }    órbita em volta do Model `orbit` (graus from→to)
	  title { text, seconds, sub? }                        cartela
	  fade { seconds }                                     escurece
	  end                                                  devolve tudo
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("RemoteEvents"))
local Log = require(Modules:WaitForChild("Log"))

local TrailerController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local active = false
local gui: ScreenGui? = nil
local titleLabel: TextLabel? = nil
local subLabel: TextLabel? = nil
local fadeFrame: Frame? = nil
local hiddenGuis: { ScreenGui } = {}
local savedCameraType = Enum.CameraType.Custom
local savedFov = 70
local shotConn: RBXScriptConnection? = nil
local titleToken = 0

local EASE: { [string]: Enum.EasingStyle } = { Sine = Enum.EasingStyle.Sine, Quad = Enum.EasingStyle.Quad, Linear = Enum.EasingStyle.Linear, Quart = Enum.EasingStyle.Quart }

local function buildGui(): ScreenGui
	local sg = Instance.new("ScreenGui")
	sg.Name = "TrailerGui"
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 100
	sg.ResetOnSpawn = false
	for _, side in { "Top", "Bottom" } do
		local bar = Instance.new("Frame")
		bar.Name = "Bar" .. side
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Size = UDim2.new(1, 0, 0.11, 0)
		bar.Position = if side == "Top" then UDim2.new(0, 0, 0, 0) else UDim2.new(0, 0, 0.89, 0)
		bar.Parent = sg
	end
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 72)
	t.Position = UDim2.new(0, 0, 0.66, 0)
	t.Font = Enum.Font.GothamBlack
	t.TextSize = 58
	t.TextColor3 = Color3.fromRGB(255, 245, 230)
	t.TextStrokeTransparency = 0.5
	t.TextTransparency = 1
	t.Text = ""
	t.Parent = sg
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, 0, 0, 30)
	sub.Position = UDim2.new(0, 0, 0.66, 74)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 22
	sub.TextColor3 = Color3.fromRGB(230, 220, 205)
	sub.TextStrokeTransparency = 0.6
	sub.TextTransparency = 1
	sub.Text = ""
	sub.Parent = sg
	local fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BorderSizePixel = 0
	fade.Size = UDim2.new(1, 0, 1, 0)
	fade.BackgroundTransparency = 1
	fade.ZIndex = 5
	fade.Parent = sg
	titleLabel, subLabel, fadeFrame = t, sub, fade
	return sg
end

local function stopShot()
	if shotConn then
		shotConn:Disconnect()
		shotConn = nil
	end
end

local function findModel(name: any): Model?
	if typeof(name) ~= "string" then
		return nil
	end
	local m = Workspace:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

local function modelPos(m: Model?): Vector3?
	if not m then
		return nil
	end
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else m:GetPivot().Position
end

local function onShot(data: { [string]: any })
	local camera = Workspace.CurrentCamera
	if not camera or not active then
		return
	end
	stopShot()
	local t0 = os.clock()
	local dur = tonumber(data.t) or 4
	local fov = tonumber(data.fov) or 60
	local style = EASE[data.ease or "Linear"] or Enum.EasingStyle.Linear
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = fov
	local lookName = data.look
	shotConn = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((os.clock() - t0) / dur, 0, 1)
		local a = TweenService:GetValue(alpha, style, Enum.EasingDirection.InOut)
		local cf: CFrame
		if data.orbit then
			local center = modelPos(findModel(data.orbit)) or Vector3.zero
			local ang = math.rad((data.from or 0) + ((data.to or 360) - (data.from or 0)) * a)
			local radius = tonumber(data.radius) or 12
			local height = tonumber(data.height) or 3
			local pos = center + Vector3.new(math.cos(ang) * radius, height, math.sin(ang) * radius)
			cf = CFrame.lookAt(pos, center + Vector3.new(0, 2, 0))
		else
			local from: CFrame = data.from
			local to: CFrame = data.to
			cf = from:Lerp(to, a)
			if lookName then
				local p = modelPos(findModel(lookName))
				if p then
					cf = CFrame.lookAt(cf.Position, p + Vector3.new(0, 1.5, 0))
				end
			end
		end
		camera.CFrame = cf
	end)
end

local function onTitle(data: { [string]: any })
	if not titleLabel or not subLabel then
		return
	end
	titleToken += 1
	local my = titleToken
	local seconds = tonumber(data.seconds) or 3
	titleLabel.Text = tostring(data.text or "")
	subLabel.Text = tostring(data.sub or "")
	local tin = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(titleLabel, tin, { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
	TweenService:Create(subLabel, tin, { TextTransparency = 0.1, TextStrokeTransparency = 0.6 }):Play()
	task.delay(seconds, function()
		if my ~= titleToken then
			return
		end
		local tout = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(titleLabel, tout, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(subLabel, tout, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local function begin()
	if active then
		return
	end
	active = true
	local camera = Workspace.CurrentCamera
	if camera then
		savedCameraType = camera.CameraType
		savedFov = camera.FieldOfView
	end
	table.clear(hiddenGuis)
	for _, g in playerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	local sg = buildGui()
	sg.Parent = playerGui
	gui = sg
end

local function finish()
	if not active then
		return
	end
	active = false
	stopShot()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = savedCameraType
		camera.FieldOfView = savedFov
	end
	for _, g in hiddenGuis do
		if g.Parent then
			g.Enabled = true
		end
	end
	table.clear(hiddenGuis)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)
	if gui then
		gui:Destroy()
		gui = nil
	end
end

function TrailerController.Start()
	Remotes.GetEvent(Remotes.Events.NotifyTrailer).OnClientEvent:Connect(function(event: string, data: any)
		data = if typeof(data) == "table" then data else {}
		if event == "begin" then
			begin()
			localPlayer:SetAttribute("TrailerWatching", true) -- CutsceneController: efeitos de "quem assiste" mesmo longe
		elseif event == "shot" then
			onShot(data)
		elseif event == "title" then
			onTitle(data)
		elseif event == "fade" then
			if fadeFrame then
				TweenService:Create(fadeFrame, TweenInfo.new(tonumber(data.seconds) or 2, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { BackgroundTransparency = 0 }):Play()
			end
		elseif event == "end" then
			finish()
			localPlayer:SetAttribute("TrailerWatching", nil)
		end
	end)
	Log.debug("[TrailerController] pronto")
end

return TrailerController
