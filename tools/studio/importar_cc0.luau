-- Executar só na place correta em modo Edit. Assets próprios importados, sem scripts/plugins.
assert(game.PlaceId == 85844807133499, "Place incorreta")
local HttpService = game:GetService("HttpService")
local folder = game.ReplicatedStorage.Assets:FindFirstChild("EnvironmentModels") or Instance.new("Folder", game.ReplicatedStorage.Assets)
folder.Name = "EnvironmentModels"
local boats = { ["ship-ocean-liner"] = true, ["boat-speed-a"] = true, ["boat-row-small"] = true }
local ids = { ["ship-ocean-liner"] = 84710281897900, ["boat-speed-a"] = 94207452050463, ["boat-row-small"] = 91806077781344, bookcaseClosed = 95098288309064, chair = 110404845357017, table = 95930305770366, flower_redA = 81989885210046, grass = 113450962422701, rock_smallA = 88287860157468, tree_small = 122521087433356 }
local function encode(instance)
	local item = { name = instance.Name, className = instance.ClassName, properties = {}, children = {} }
	local props = item.properties
	if instance:IsA("BasePart") then
		props.Size = { instance.Size.X, instance.Size.Y, instance.Size.Z }
		props.CFrame = { instance.CFrame:GetComponents() }
		props.Color = { instance.Color.R, instance.Color.G, instance.Color.B }
		props.Anchored, props.CanCollide, props.CanTouch, props.CanQuery = true, false, false, false
		props.Material = instance.Material.Name
	end
	if instance:IsA("MeshPart") then
		props.MeshId, props.TextureID = instance.MeshId, instance.TextureID
		props.CollisionFidelity = "Box"
	end
	for _, child in instance:GetChildren() do
		if child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart") then table.insert(item.children, encode(child)) end
	end
	return item
end
local output = {}
for name, id in ids do
	local model = folder:FindFirstChild(name)
	if not model then
		model = game:GetService("InsertService"):LoadAsset(id)
		model.Name = name
		for _, d in model:GetDescendants() do if d:IsA("BaseScript") or d:IsA("PackageLink") then d:Destroy() end end
		model.Parent = folder
	end
	if boats[name] then
		for _, d in model:GetDescendants() do if d:IsA("MeshPart") then d.TextureID = "rbxassetid://70871606143749"; d.Color = Color3.new(1, 1, 1) end end
	end
	output[name] = encode(model)
end
print(HttpService:JSONEncode(output))
