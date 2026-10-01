--!strict
-- Capitão próprio, sem avatares/skins dos Anciões nem código de modelos externos.
local Appearance = {}
function Appearance.Create(at: CFrame): Model?
	local description = Instance.new("HumanoidDescription")
	local fur = Color3.fromRGB(145, 73, 30)
	description.HeadColor, description.LeftArmColor, description.RightArmColor = fur, fur, fur
	description.TorsoColor = Color3.fromRGB(227, 232, 216)
	description.LeftLegColor, description.RightLegColor = Color3.fromRGB(31, 47, 73), Color3.fromRGB(31, 47, 73)
	local ok, model = pcall(function() return game:GetService("Players"):CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6) end)
	if not ok then warn("[VesselService] falha ao criar o capitão"); return nil end
	model.Name = "Capitão Forever"
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	root.Anchored = true
	model:PivotTo(at) -- move também a cabeça antes de criar os detalhes ancorados
	for _, item in model:GetDescendants() do if item:IsA("BasePart") then item.CanCollide = false end end
	local face = head:FindFirstChild("face"); if face then face:Destroy() end
	local function piece(name: string, size: Vector3, offset: Vector3, color: Color3, ball: boolean)
		local item = Instance.new("Part")
		item.Name, item.Size, item.Color = name, size, color
		item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
		item.Material, item.CFrame, item.Parent = Enum.Material.SmoothPlastic, head.CFrame * CFrame.new(offset), model
		if ball then item.Shape = Enum.PartType.Ball end
	end
	local skin = Color3.fromRGB(102, 69, 49)
	piece("Focinho", Vector3.new(1.25, .9, .45), Vector3.new(0, -.15, -.64), skin, true)
	for _, side in { -1, 1 } do
		piece("Bochecha", Vector3.new(.75, 1.2, .5), Vector3.new(side * .67, -.05, -.45), fur, true)
		piece("Orelha", Vector3.new(.4, .65, .3), Vector3.new(side * 1.1, .05, 0), skin, true)
		piece("Olho", Vector3.new(.12, .14, .08), Vector3.new(side * .27, .22, -.86), Color3.new(.03, .03, .03), true)
	end
	piece("Quepe", Vector3.new(2.05, .5, 1.55), Vector3.new(0, .65, 0), Color3.fromRGB(238, 235, 220), false)
	piece("Pala", Vector3.new(1.65, .12, .55), Vector3.new(0, .48, -.95), Color3.fromRGB(25, 39, 67), false)
	piece("Insígnia", Vector3.new(.22, .2, .08), Vector3.new(0, .67, -.81), Color3.fromRGB(238, 194, 78), false)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.DisplayName = "Forever · Strength"; humanoid.NameDisplayDistance = 40 end
	return model
end
return Appearance
