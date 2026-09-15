--[[
	Preview de animações (Script, roda no servidor ao dar Play num place em branco).
	Cria um boneco R6 no meio do mapa e uma GUI (via PreviewGui) com um botão por
	KeyframeSequence da pasta "Sequencias"; clicar toca no boneco. Só funciona no Studio
	(RegisterKeyframeSequence). Para publicar a escolhida: clique direito no KeyframeSequence
	> Save to Roblox (criador = o grupo).
]]
local Players = game:GetService("Players")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = script.Parent
local sequences = folder:WaitForChild("Sequencias")
local guiScript = folder:WaitForChild("PreviewGui")

-- boneco R6
local rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
rig.Name = "PreviewRig"
for _, d in rig:GetDescendants() do
	if d:IsA("Script") or d:IsA("LocalScript") then
		d:Destroy()
	end
end
local humanoid = rig:FindFirstChildOfClass("Humanoid")
local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
humanoid.DisplayName = "Preview"
rig:PivotTo(CFrame.new(0, 5, -8) * CFrame.Angles(0, math.pi, 0))
rig.Parent = workspace

-- registra cada KeyframeSequence e guarda a Animation temporária
local anims = {}
local names = {}
for _, ks in sequences:GetChildren() do
	if ks:IsA("KeyframeSequence") then
		local ok, id = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, ks)
		if ok then
			local anim = Instance.new("Animation")
			anim.Name = ks.Name
			anim.AnimationId = id
			anims[ks.Name] = anim
			table.insert(names, ks.Name)
		else
			warn("[Preview] falhou " .. ks.Name .. ": " .. tostring(id))
		end
	end
end
table.sort(names)
print(("[Preview] %d animações prontas"):format(#names))

local remote = Instance.new("RemoteEvent")
remote.Name = "PreviewPlay"
remote.Parent = ReplicatedStorage
local list = Instance.new("StringValue")
list.Name = "PreviewList"
list.Value = table.concat(names, "\n")
list.Parent = ReplicatedStorage

local current = nil
remote.OnServerEvent:Connect(function(player, name, loop)
	if current then
		current:Stop(0.1)
		current = nil
	end
	local anim = anims[name]
	if not anim then
		return
	end
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = loop == true
	track:Play(0.1)
	current = track
	print(("[Preview] %s (%.2fs)"):format(name, track.Length))
end)

Players.PlayerAdded:Connect(function(player)
	local gui = guiScript:Clone()
	gui.Disabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
end)
for _, player in Players:GetPlayers() do
	local gui = guiScript:Clone()
	gui.Disabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
end
