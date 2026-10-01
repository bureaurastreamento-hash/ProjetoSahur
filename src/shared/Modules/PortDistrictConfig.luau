--!strict
-- Extensões aditivas: não ampliam elipses sobre mar sem criar chão físico correspondente.
local Config = {}
Config.Districts = {
	{ Region = "ilha_tutorial", Name = "bairro_nevoa", Center = Vector3.new(124, -.15, 270), Outward = Vector3.new(0, 0, 1), Sand = false },
	{ Region = "ilha_pilares", Name = "bairro_deserto", Center = Vector3.new(610, -.15, -494), Outward = Vector3.new(-1, 0, 0), Sand = true },
	{ Region = "ilha_sol_partido", Name = "bairro_eclipse", Center = Vector3.new(1834, -.15, 175), Outward = Vector3.new(0, 0, 1), Sand = true },
}
Config.Width, Config.Depth = 168, 80
function Config.Contains(district: any, position: Vector3): boolean
	local right = Vector3.yAxis:Cross(district.Outward)
	local offset = position - district.Center
	return math.abs(offset:Dot(right)) <= Config.Width / 2 and math.abs(offset:Dot(district.Outward)) <= Config.Depth / 2
end
require(script.Parent.IslandLayout).TranslateTable(Config)
return Config
