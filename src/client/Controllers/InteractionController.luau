--!strict
-- Clique próximo ao alvo; opções usam os ProximityPrompts reais, sem decidir recompensa no cliente.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Controller = {}
local player = Players.LocalPlayer
local shown: { [ProximityPrompt]: boolean } = {}
local gui: ScreenGui
local hint: TextButton
local panel: Frame
local title: TextLabel
local rows: Frame
local current: ProximityPrompt? = nil
local openedAt: BasePart? = nil
local lastClick = 0
local function anchor(prompt: ProximityPrompt): BasePart?
	local p = prompt.Parent
	if p and p:IsA("Attachment") then p = p.Parent end
	if p and p:IsA("BasePart") then return p end
	if p and p:IsA("Model") then return p.PrimaryPart end
	return nil
end
local function eligible(prompt: ProximityPrompt): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local at = anchor(prompt)
	return prompt.Enabled and prompt:IsDescendantOf(workspace) and root ~= nil and at ~= nil
		and (root.Position - at.Position).Magnitude <= prompt.MaxActivationDistance
		and player:GetAttribute("ClientLoading") ~= true and player:GetAttribute("LaunchTitleVisible") ~= true
end
local function close()
	openedAt = nil
	if panel then panel.Visible = false end
	player:SetAttribute("InteractionDialogOpen", false)
end
local function activate(prompt: ProximityPrompt)
	if not eligible(prompt) or os.clock() - lastClick < .25 then return end
	lastClick = os.clock()
	close()
	prompt:InputHoldBegin()
	-- Dá ao engine um frame para processar Begin; a ação continua sem exigir que o jogador segure.
	task.delay(.05, function() if prompt.Parent then prompt:InputHoldEnd() end end)
end
local function button(parent: Instance, text: string, order: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 38)
	b.BackgroundColor3 = Color3.fromRGB(32, 34, 45)
	b.TextColor3 = Color3.fromRGB(245, 232, 208)
	b.Font, b.TextSize, b.TextWrapped = Enum.Font.GothamMedium, 14, true
	b.Text, b.LayoutOrder, b.Parent = text, order, parent
	return b
end
local function interact(prompt: ProximityPrompt)
	local at = anchor(prompt)
	if not at or not eligible(prompt) then return end
	local choices: { ProximityPrompt } = {}
	for other in shown do
		if anchor(other) == at and eligible(other) then table.insert(choices, other) end
	end
	table.sort(choices, function(a, b) return a.ActionText < b.ActionText end)
	if #choices <= 1 then activate(prompt); return end
	for _, child in rows:GetChildren() do if child:IsA("TextButton") then child:Destroy() end end
	title.Text = if at.Parent and at.Parent:IsA("Model") then at.Parent.Name else prompt.ObjectText
	for i, choice in choices do
		local b = button(rows, choice.ActionText .. " · " .. choice.ObjectText, i)
		b.Activated:Connect(function() activate(choice) end)
	end
	local cancel = button(rows, "Até logo", #choices + 1)
	cancel.Activated:Connect(close)
	panel.Size = UDim2.new(0, 340, 0, 56 + (#choices + 1) * 44)
	openedAt, panel.Visible = at, true
	player:SetAttribute("InteractionDialogOpen", true)
	UIS.MouseBehavior = Enum.MouseBehavior.Default
end
-- Chamado pelo CombatController antes de começar socos; não há disputa entre dois listeners.
function Controller.TryInteract(): boolean
	if panel and panel.Visible then return true end
	local camera = workspace.CurrentCamera
	if not camera then return false end
	local pos = UIS:GetMouseLocation()
	local ray = if UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2) else camera:ScreenPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 24, params)
	if not hit then return false end
	for prompt in shown do
		if not eligible(prompt) then continue end
		local at = anchor(prompt) :: BasePart
		local model = at.Parent
		local matches = hit.Instance == at
		if not matches and model and model:IsA("Model") and hit.Instance:IsDescendantOf(model) then
			local _, size = model:GetBoundingBox()
			-- Objetos compactos podem ter o prompt no pivô; modelos de ilha não são alvos inteiros.
			matches = model:FindFirstChildOfClass("Humanoid") ~= nil or math.max(size.X, size.Y, size.Z) <= 32
		end
		if matches then interact(prompt); return true end
	end
	return false
end
function Controller.Init()
	gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "InteractionGui", false, 45
	gui.Parent = player:WaitForChild("PlayerGui")
	hint = button(gui, "", 0)
	hint.AnchorPoint, hint.Position, hint.Size = Vector2.new(.5, 1), UDim2.new(.5, 0, 1, -145), UDim2.fromOffset(340, 38)
	hint.Visible = false
	hint.Activated:Connect(function() if current then interact(current) end end)
	panel = Instance.new("Frame")
	panel.AnchorPoint, panel.Position = Vector2.new(.5, .5), UDim2.fromScale(.5, .65)
	panel.BackgroundColor3, panel.Visible, panel.Parent = Color3.fromRGB(18, 20, 29), false, gui
	title = Instance.new("TextLabel")
	title.Size, title.BackgroundTransparency = UDim2.new(1, -20, 0, 44), 1
	title.Position, title.TextColor3 = UDim2.fromOffset(10, 0), Color3.fromRGB(240, 196, 80)
	title.Font, title.TextSize, title.Parent = Enum.Font.GothamBold, 17, panel
	rows = Instance.new("Frame")
	rows.Size, rows.Position, rows.BackgroundTransparency, rows.Parent = UDim2.new(1, -20, 1, -48), UDim2.fromOffset(10, 44), 1, panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder, layout.Padding, layout.Parent = Enum.SortOrder.LayoutOrder, UDim.new(0, 6), rows
end
function Controller.Start()
	-- Sem tecla associada, os prompts são encontrados pelo alvo/distância, inclusive após preload/streaming.
	for _, item in workspace:GetDescendants() do
		if item:IsA("ProximityPrompt") then shown[item] = true end
	end
	workspace.DescendantAdded:Connect(function(item) if item:IsA("ProximityPrompt") then shown[item] = true end end)
	workspace.DescendantRemoving:Connect(function(item) if item:IsA("ProximityPrompt") then shown[item] = nil end end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < .1 then return end
		elapsed = 0
		current = nil
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local best = math.huge
		for prompt in shown do
			if eligible(prompt) then
				local at = anchor(prompt) :: BasePart
				local d = ((root :: BasePart).Position - at.Position).Magnitude
				if d < best then best, current = d, prompt end
			end
		end
		if openedAt and (not current or anchor(current) ~= openedAt) then close() end
		hint.Visible = current ~= nil and not panel.Visible
		if current then hint.Text = "CLIQUE · " .. current.ObjectText .. " · " .. current.ActionText end
	end)
	player.CharacterAdded:Connect(close)
end
return Controller
