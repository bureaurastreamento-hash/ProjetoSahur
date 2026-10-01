--!strict
-- Translação do mapa da equipe somente no runtime; coordenadas de edição/arquivos ficam intactas.
local Layout = {}
Layout.Version = 1
local zones = {
	{ min = Vector2.new(510, -1050), max = Vector2.new(1270, -40), offset = Vector3.new(0, 0, -1100) },
	{ min = Vector2.new(1280, -750), max = Vector2.new(2180, 380), offset = Vector3.new(300, 0, -1400) },
	{ min = Vector2.new(-820, 390), max = Vector2.new(-90, 840), offset = Vector3.new(-300, 0, 500) },
}
function Layout.OffsetAt(position: Vector3): Vector3
	for _, zone in zones do
		if position.X >= zone.min.X and position.X <= zone.max.X and position.Z >= zone.min.Y and position.Z <= zone.max.Y then return zone.offset end
	end
	return Vector3.zero
end
function Layout.Position(position: Vector3): Vector3
	return position + Layout.OffsetAt(position)
end
function Layout.TranslateTable(value: any)
	local visited: { [any]: boolean } = {}
	local function walk(t: any)
		if typeof(t) ~= "table" or visited[t] then return end
		visited[t] = true
		for key, item in t do
			if typeof(item) == "Vector3" then t[key] = Layout.Position(item)
			elseif typeof(item) == "Vector2" then
				local p = Layout.Position(Vector3.new(item.X, 0, item.Y));t[key] = Vector2.new(p.X, p.Z)
			elseif typeof(item) == "table" then walk(item) end
		end
	end
	walk(value)
end
return Layout
