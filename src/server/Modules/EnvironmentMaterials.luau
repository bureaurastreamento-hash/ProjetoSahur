--!strict
-- Aparência de runtime: não escreve mapa/place nem muda volume de Terrain.
local Workspace = game:GetService("Workspace")
local MaterialService = game:GetService("MaterialService")
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
local Config = require(Modules.EnvironmentConfig)
local Log = require(Modules.Log)
local Service = {}
local variants: { [string]: string } = {}
local function apply(instance: Instance)
	if not instance:IsA("BasePart") or not instance.Anchored or instance.Transparency >= .9 or instance:IsA("MeshPart") then return end
	if instance.Material == Enum.Material.Neon or instance.MaterialVariant ~= "" then return end
	local kind = Config.Kind(instance.Name, instance.Material)
	local entry = kind and Config.Materials[kind]
	if not entry then return end
	-- Material altera física por padrão: conservar as propriedades do material anterior.
	if not instance.CustomPhysicalProperties then instance.CustomPhysicalProperties = PhysicalProperties.new(instance.Material) end
	instance.Material = entry.Base
	if kind and variants[kind] then instance.MaterialVariant = variants[kind] end
end
function Service.Start()
	for kind, entry in Config.Materials do
		if entry.ColorMap:match("^rbxassetid://%d+$") then
			local name = "FX_CC0_" .. kind
			if not MaterialService:FindFirstChild(name) then
				local variant = Instance.new("MaterialVariant")
				variant.Name, variant.BaseMaterial, variant.StudsPerTile = name, entry.Base, entry.Tile
				variant.ColorMap, variant.NormalMap, variant.RoughnessMap = entry.ColorMap, entry.NormalMap, entry.RoughnessMap
				variant.Parent = MaterialService
			end
			variants[kind] = name
		end
	end
	local sahur = Workspace:WaitForChild("Sahur", 15)
	if not sahur then return end
	local function bind(root: Instance)
		if not Config.Roots[root.Name] then return end
		for _, item in root:GetDescendants() do apply(item) end
		root.DescendantAdded:Connect(apply)
	end
	for _, root in sahur:GetChildren() do bind(root) end
	sahur.ChildAdded:Connect(bind)
	local water = Workspace.Terrain
	water.WaterColor, water.WaterTransparency, water.WaterReflectance = Color3.fromRGB(32, 104, 146), .3, .18
	water.WaterWaveSize, water.WaterWaveSpeed = .35, 14
	Log.debug("[EnvironmentMaterials] materiais dos cenários gerados e aparência da água preparados")
end
return Service
