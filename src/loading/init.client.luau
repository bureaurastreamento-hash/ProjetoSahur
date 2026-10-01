--!strict
-- ReplicatedFirst: tela imediata, pré-carga seletiva e prazo limitado. Não pré-carrega o mapa inteiro.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(14, 15, 23)
background.Parent = gui
local function label(text: string, y: number, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(.9, .08)
	l.Position = UDim2.fromScale(.05, y)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.fromRGB(238, 229, 212)
	l.TextSize = size
	l.TextWrapped = true
	l.Text = text
	l.Parent = background
	return l
end
label("BIZARRE SHOWDOWN F/X", .35, 30)
local status = label("Preparando o mundo…", .46, 16)
label("1–4 habilidades  ·  X equipamentos  ·  M mochila", .68, 14)
local track = Instance.new("Frame")
track.Size = UDim2.fromScale(.6, .009)
track.Position = UDim2.fromScale(.2, .59)
track.BackgroundColor3 = Color3.fromRGB(45, 44, 55)
track.BorderSizePixel = 0
track.Parent = background
local fill = track:Clone()
fill.Size = UDim2.fromScale(0, 1)
fill.Position = UDim2.fromScale(0, 0)
fill.BackgroundColor3 = Color3.fromRGB(240, 196, 80)
fill.Parent = track
local skip = Instance.new("TextButton")
skip.Size = UDim2.fromScale(.4, .05)
skip.Position = UDim2.fromScale(.3, .79)
skip.BackgroundTransparency = 1
skip.TextColor3 = Color3.fromRGB(240, 196, 80)
skip.TextSize = 15
skip.Text = "Continuar carregando em segundo plano"
skip.Visible = false
skip.Parent = background
gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()
ContextActionService:BindActionAtPriority("LoadingInput", function() return Enum.ContextActionResult.Sink end, false, 3000,
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space,
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
	Enum.UserInputType.MouseButton1, Enum.KeyCode.Thumbstick1, Enum.KeyCode.ButtonA)
local finished = false
local function finish()
	if finished then return end
	finished = true
	ContextActionService:UnbindAction("LoadingInput")
	player:SetAttribute("ClientAssetsReady", true)
	player:SetAttribute("ClientLoading", false)
	gui:Destroy()
end
player:SetAttribute("ClientLoading", true)
skip.Activated:Connect(finish)
task.delay(12, function() if not finished then skip.Visible = true end end)
task.delay(30, finish) -- rede lenta/asset privado nunca prende o jogador

task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	local assets = ReplicatedStorage:WaitForChild("Assets", 15)
	if not assets then finish(); return end
	local selected: { Instance } = {}
	local function include(folder: Instance?)
		if not folder then return end
		for _, item in folder:GetDescendants() do
			if item:IsA("Animation") or item:IsA("Sound") or item:IsA("ParticleEmitter")
				or item:IsA("MeshPart") or item:IsA("SpecialMesh") or item:IsA("ImageLabel") then
				table.insert(selected, item)
			end
		end
	end
	local animations = assets:FindFirstChild("Animations")
	local sounds = assets:FindFirstChild("Sounds")
	local vfx = assets:FindFirstChild("VFX")
	include(animations and animations:FindFirstChild("Shared"))
	include(sounds and sounds:FindFirstChild("Shared"))
	include(vfx and vfx:FindFirstChild("Shared"))
	include(vfx and vfx:FindFirstChild("CC0"))
	include(assets:FindFirstChild("UI"))
	include(assets:FindFirstChild("Cursors"))
	include(assets:FindFirstChild("CombatModels"))
	include(assets:FindFirstChild("WeaponSounds"))
	local completed, failures = 0, 0
	for first = 1, #selected, 8 do
		local batch = {}
		for i = first, math.min(first + 7, #selected) do table.insert(batch, selected[i]) end
		local ok = pcall(function()
			ContentProvider:PreloadAsync(batch, function(_, result)
				if result ~= Enum.AssetFetchStatus.Success then failures += 1 end
			end)
		end)
		if not ok then failures += 1 end
		completed += #batch
		if not finished then
			status.Text = ("Preparando combate: %d / %d"):format(completed, #selected)
			TweenService:Create(fill, TweenInfo.new(.15), { Size = UDim2.fromScale(completed / math.max(1, #selected), 1) }):Play()
		end
	end
	player:SetAttribute("ClientPreloadFailures", failures)
	player:SetAttribute("ClientPreloadedCount", completed)
	finish()
end)
