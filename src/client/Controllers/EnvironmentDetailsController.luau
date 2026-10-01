--!strict
-- Detalhes locais sem colisão, limitados e removíveis pela configuração do jogador.
local Workspace = game:GetService("Workspace")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local Config = require(Modules.EnvironmentConfig)
local Assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets")
local templates = Assets:WaitForChild("EnvironmentModels", 15)
local Settings = require(script.Parent.SettingsController)
local Controller = {}
local folders: { [Instance]: Folder } = {}
local decorated: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local used = 0
local grassParts = 0
local MAX_PARTS = 420
local function part(folder: Folder, name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3): Part?
	if used >= MAX_PARTS then return nil end
	local item = Instance.new("Part")
	item.Name, item.Size, item.CFrame, item.Material, item.Color = name, size, cf, material, color
	item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery, item.CastShadow = true, false, false, false, false
	item.Parent = folder
	used += 1
	return item
end
local function mesh(folder: Folder, name: string, at: CFrame, scale: number): boolean
	local template = templates and templates:FindFirstChild(name)
	if not template or not template:IsA("Model") then return false end
	local count = 0
	for _, item in template:GetDescendants() do if item:IsA("BasePart") then count += 1 end end
	if count == 0 or used + count > MAX_PARTS then return false end
	local model = template:Clone()
	model:ScaleTo(scale)
	local box, size = model:GetBoundingBox()
	local offset = model:GetPivot():ToObjectSpace(box)
	model:PivotTo(at * CFrame.new(0, size.Y / 2, 0) * offset:Inverse())
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then item.Anchored = true; item.CanCollide = false; item.CanTouch = false; item.CanQuery = false end
	end
	model.Parent = folder
	used += count
	return true
end
local function decorate(source: Instance, root: Instance)
	if Settings.Get("EnvironmentDetails") ~= true or decorated[source] or not source:IsA("Part")
		or not source.Anchored or source.Transparency >= .9 or used >= MAX_PARTS then return end
	decorated[source] = true
	local folder = folders[root]
	if not folder then return end
	local name = source.Name:lower()
	local wood = Color3.fromRGB(92, 66, 42)
	if name:match("^casa%d+_janela$") or name:match("^casa%d+_janelalado$") then
		local at = source.CFrame * CFrame.new(0, -source.Size.Y / 2 - .16, -source.Size.Z / 2 - .24)
		part(folder, "Peitoril", Vector3.new(source.Size.X + .3, .22, .65), at, Enum.Material.WoodPlanks, wood)
		for i = -1, 1 do
			local pot = at * CFrame.new(i * .45, .35, 0)
			part(folder, "Vaso", Vector3.new(.35, .45, .35), pot, Enum.Material.Brick, Color3.fromRGB(153, 96, 66))
			if mesh(folder, "flower_redA", pot * CFrame.new(0, .25, 0), .23) then continue end
			local leaf = part(folder, "Folhas", Vector3.new(.42, .38, .42), pot * CFrame.new(0, .35, 0), Enum.Material.Grass, Color3.fromRGB(62, 105, 66))
			if leaf then leaf.Shape = Enum.PartType.Ball end
		end
	elseif name == "caixote" then
		for _, side in { -1, 1 } do
			part(folder, "TravessaCaixote", Vector3.new(source.Size.X + .05, .12, .12), source.CFrame * CFrame.new(0, source.Size.Y * side * .3, -source.Size.Z / 2 - .03), Enum.Material.WoodPlanks, wood)
		end
	elseif name == "barril" then
		for _, side in { -1, 1 } do
			part(folder, "AroBarril", Vector3.new(source.Size.X + .06, .12, source.Size.Z + .06), source.CFrame * CFrame.new(0, source.Size.Y * side * .32, 0), Enum.Material.Metal, Color3.fromRGB(66, 70, 71))
		end
	elseif name == "barraca_balcao" then
		for i = -1, 1 do
			part(folder, "Sacaria", Vector3.new(.7, .8, .7), source.CFrame * CFrame.new(i * 1.1, source.Size.Y / 2 + .4, 0), Enum.Material.Fabric, Color3.fromRGB(164, 143, 101))
		end
	elseif name:match("^topo%d+$") and Config.Kind(source.Name, source.Material) == "Grass" and source.Size.X >= 10 and source.Size.Z >= 10 then
		if grassParts >= 180 then return end
		local before = used
		local rng = Random.new(math.abs(math.floor(source.Position.X * 13 + source.Position.Z * 31)))
		for _ = 1, 3 do
			local sample = source.CFrame:PointToWorldSpace(Vector3.new(rng:NextNumber(-.4, .4) * source.Size.X, source.Size.Y / 2, rng:NextNumber(-.4, .4) * source.Size.Z))
			local result = Workspace:Raycast(sample + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0))
			if result and result.Instance == source and result.Normal.Y > .9 then
				local at = CFrame.new(result.Position)
				local choice = rng:NextNumber()
				local asset = if choice < .62 then "grass" elseif choice < .8 then "flower_redA" elseif choice < .93 then "rock_smallA" else "tree_small"
				mesh(folder, asset, at * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), if asset == "tree_small" then 1.5 else rng:NextNumber(.7, 1.3))
			end
		end
		grassParts += used - before
	end
end
local function bind(root: Instance)
	if not Config.Roots[root.Name] or folders[root] then return end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "FXDetalhesLocais_" .. root.Name, Workspace
	folders[root] = folder
	for _, item in root:GetDescendants() do decorate(item, root) end
	root.DescendantAdded:Connect(function(item) task.defer(decorate, item, root) end)
	root.AncestryChanged:Connect(function()
		if not root.Parent and folders[root] then
			for _, item in folder:GetDescendants() do if item:IsA("BasePart") then used -= 1 end end
			folder:Destroy(); folders[root] = nil
			for item in decorated do if item:IsDescendantOf(root) then decorated[item] = nil end end
		end
	end)
end
function Controller.Start()
	local sahur = Workspace:WaitForChild("Sahur", 15)
	if not sahur then return end
	for _, root in sahur:GetChildren() do bind(root) end
	sahur.ChildAdded:Connect(bind)
	Settings.Changed.Event:Connect(function(key: string)
		if key ~= "EnvironmentDetails" then return end
		for _, folder in folders do folder:ClearAllChildren() end
		table.clear(decorated); used = 0; grassParts = 0
		if Settings.Get(key) == true then
			for root in folders do for _, item in root:GetDescendants() do decorate(item, root) end end
		end
	end)
end
return Controller
