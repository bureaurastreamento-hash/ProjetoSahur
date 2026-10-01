--!strict
-- Pequenos bairros portuários aditivos. Não escreve Terrain nem move a arte da equipe.
local Workspace = game:GetService("Workspace")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local Config = require(Modules.PortDistrictConfig)
local Service = {}
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, cf, color, material
	p.Anchored, p.CanTouch, p.Parent = true, false, parent
	return p
end
local function prop(parent: Instance, name: string, at: CFrame, scale: number)
	local library = game.ReplicatedStorage.Assets:FindFirstChild("EnvironmentModels")
	local template = library and library:FindFirstChild(name)
	if not template or not template:IsA("Model") then return end
	local clone = template:Clone(); clone:ScaleTo(scale)
	local box, size = clone:GetBoundingBox()
	clone:PivotTo(at * CFrame.new(0, size.Y / 2, 0) * clone:GetPivot():ToObjectSpace(box):Inverse())
	clone.Parent = parent
end
function Service.Start()
	local sahur = Workspace:WaitForChild("Sahur", 15)
	if not sahur then return end
	local root = Instance.new("Model"); root.Name, root.Parent = "FXPortDistricts", sahur
	for _, district in Config.Districts do
		local model = Instance.new("Model"); model.Name, model.Parent = district.Name, root
		local at = CFrame.lookAt(district.Center, district.Center + district.Outward)
		local added = 0
		for x = -3, 3 do
			for z = -2, 2 do
				local cf = at * CFrame.new(x * 24, -4, z * 16)
				local ray = Workspace:Raycast(cf.Position + Vector3.new(0, 105, 0), Vector3.new(0, -115, 0))
				-- Não cobrir chão/construções existentes. Novos blocos ficam só na água/onde faltava chão.
				if ray and ray.Material ~= Enum.Material.Water and ray.Position.Y > -3 then continue end
				local floor = part(model, "FundacaoPorto", Vector3.new(24, 8, 16), cf, Color3.fromRGB(104, 105, 100), Enum.Material.Slate)
				floor.MaterialVariant = "FX_CC0_Rock"
				local top = part(model, "PraiaPortuaria", Vector3.new(24, .25, 16), cf * CFrame.new(0, 4.125, 0), if district.Sand then Color3.fromRGB(214, 192, 134) else Color3.fromRGB(175, 180, 130), if district.Sand then Enum.Material.Sand else Enum.Material.Grass)
				top.MaterialVariant = if district.Sand then "FX_CC0_Sand" else "FX_CC0_Grass"
				added += 1
			end
		end
		if added == 0 then model:Destroy(); continue end
		local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Include; params.FilterDescendantsInstances = { model }
		for index, offset in { Vector3.new(-24, 0, 16), Vector3.new(24, 0, 16) } do
			local position = at:PointToWorldSpace(offset)
			local ray = Workspace:Raycast(position + Vector3.new(0, 50, 0), Vector3.new(0, -60, 0), params)
			if not ray then continue end
			local house = Instance.new("Model"); house.Name, house.Parent = "CasaPortuaria" .. index, model
			local home = CFrame.new(ray.Position) * at.Rotation
			local wood, brick = Color3.fromRGB(120, 84, 51), if index == 1 then Color3.fromRGB(200, 169, 121) else Color3.fromRGB(177, 194, 186)
			part(house, "Piso", Vector3.new(18, .5, 16), home, wood, Enum.Material.WoodPlanks).MaterialVariant = "FX_CC0_Wood"
			for _, x in {-9, 9} do part(house, "Casa1_Corpo", Vector3.new(.6, 12, 16), home * CFrame.new(x, 6, 0), brick, Enum.Material.Brick).MaterialVariant = "FX_CC0_Brick" end
			part(house, "Casa1_Corpo", Vector3.new(18, 12, .6), home * CFrame.new(0, 6, 8), brick, Enum.Material.Brick).MaterialVariant = "FX_CC0_Brick"
			for _, x in {-6,6} do part(house, "Casa1_Corpo", Vector3.new(6, 12, .6), home * CFrame.new(x,6,-8), brick, Enum.Material.Brick).MaterialVariant = "FX_CC0_Brick" end
			part(house, "Casa1_Corpo", Vector3.new(6, 3, .6), home * CFrame.new(0,10.5,-8), brick, Enum.Material.Brick).MaterialVariant = "FX_CC0_Brick"
			for _, side in {-1,1} do
				part(house,"Telhado",Vector3.new(10.7,.6,19),home*CFrame.new(side*4.8,13.5,0)*CFrame.Angles(0,0,math.rad(-side*18)),Color3.fromRGB(128,64,47),Enum.Material.Brick).MaterialVariant="FX_CC0_Brick"
				part(house,"Viga",Vector3.new(.6,12.2,.6),home*CFrame.new(side*8.8,6,-8.2),wood,Enum.Material.WoodPlanks)
			end
			prop(house,"table",home*CFrame.new(0,.3,2),.65)
			prop(house,"chair",home*CFrame.new(0,.3,-1.5),.8)
			prop(house,"bookcaseClosed",home*CFrame.new(6,.3,6),.75)
			for _, x in {-6,6} do prop(house,"flower_redA",home*CFrame.new(x,.3,-10),1) end
		end
		for index=1,8 do
			local position = at:PointToWorldSpace(Vector3.new(if index%2==0 then -65 else 65,0,(math.ceil(index/2)-2.5)*16))
			local ray = Workspace:Raycast(position+Vector3.new(0,40,0),Vector3.new(0,-50,0),params)
			if ray then prop(model,if index%3==0 then "rock_smallA" else "tree_small",CFrame.new(ray.Position),if index%3==0 then 1.8 else 1.4) end
		end
	end
end
return Service
