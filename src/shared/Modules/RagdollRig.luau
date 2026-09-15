--!strict
--[[
	RagdollRig
	Solta/prende as juntas de um personagem R6 (reversível). Usado pelo servidor:
	  - RagdollService: ragdoll de combate (levanta depois)
	  - HealthService: ragdoll de morte (nunca levanta)
	Apply desliga cada Motor6D (não destrói: a animação volta a funcionar no Release) e cria
	um BallSocketConstraint no lugar; membros passam a colidir e o HRP deixa de colidir.
	PlatformStand no Humanoid faz o boneco cair; o cliente dono da física simula o resto.
]]

local RagdollRig = {}

local FOLDER_NAME = "RagdollJoints"
local ATTR_WAS_COLLIDE = "RagdollWasCollide"

function RagdollRig.IsApplied(character: Model): boolean
	return character:FindFirstChild(FOLDER_NAME) ~= nil
end

function RagdollRig.Apply(character: Model)
	if RagdollRig.IsApplied(character) then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.RequiresNeck = false -- pescoço desligado não pode contar como morte
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			local a0 = Instance.new("Attachment")
			a0.Name = d.Name .. "_A0"
			a0.CFrame = d.C0
			a0.Parent = d.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = d.Name .. "_A1"
			a1.CFrame = d.C1
			a1.Parent = d.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = d.Name
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.UpperAngle = 60
			socket.TwistLowerAngle = -45
			socket.TwistUpperAngle = 45
			socket.Parent = folder
			-- ObjectValue guarda o motor para religar no Release
			local ref = Instance.new("ObjectValue")
			ref.Name = "Motor"
			ref.Value = d
			ref.Parent = socket
			d.Enabled = false
		elseif d:IsA("BasePart") then
			d:SetAttribute(ATTR_WAS_COLLIDE, d.CanCollide)
			d.CanCollide = d.Name ~= "HumanoidRootPart"
		end
	end
	folder.Parent = character
	if humanoid then
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
	end
end

function RagdollRig.Release(character: Model)
	local folder = character:FindFirstChild(FOLDER_NAME)
	if not folder then
		return
	end
	for _, socket in folder:GetChildren() do
		if socket:IsA("BallSocketConstraint") then
			local ref = socket:FindFirstChild("Motor") :: ObjectValue?
			local motor = ref and ref.Value
			if socket.Attachment0 then
				socket.Attachment0:Destroy()
			end
			if socket.Attachment1 then
				socket.Attachment1:Destroy()
			end
			if motor and motor:IsA("Motor6D") then
				motor.Enabled = true
			end
		end
	end
	folder:Destroy()
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			local was = d:GetAttribute(ATTR_WAS_COLLIDE)
			if typeof(was) == "boolean" then
				d.CanCollide = was
				d:SetAttribute(ATTR_WAS_COLLIDE, nil)
			end
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
	end
end

return RagdollRig
