--[[
	preparar_mapa.luau — monta src/workspace/Arena.rbxm a partir de um mapa importado.
	Uso: ~/.rokit/bin/lune run tools/preparar_mapa.luau src/import/ShadowBattlegroundsfull/MainMap.rbxm

	- remove placares/GUIs/sons do pack (Donation Leaderboard, LeaderBoards, Spawns vazio)
	- recentra o mapa: centro do piso (Tiles) vai para (0, 0, 0), topo do piso em y = 0
	- otimização: CastShadow = false em piso/bordas/cantos (parts planas), Anchored em tudo
	- os extras nossos (Spawns, DummyPads, LeaderboardBoard, barreira) ficam em
	  src/workspace/ArenaExtras.model.json (gerado por tools/gerar_arena.py --extras)
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local src = process.args[1] or "src/import/ShadowBattlegroundsfull/MainMap.rbxm"
local model = roblox.deserializeModel(fs.readFile(src))[1]
model.Name = "Arena"

for _, name in { "Donation Leaderboard", "LeaderBoards", "Spawns" } do
	local c = model:FindFirstChild(name)
	if c then
		c:Destroy()
	end
end
for _, d in model:GetDescendants() do
	local cls = d.ClassName
	if cls == "Sound" or cls == "SurfaceGui" or cls == "BillboardGui" or cls == "Script" or cls == "LocalScript" or cls == "ModuleScript" or cls == "BoolValue" then
		d:Destroy()
	end
end

-- bounds do piso
local function bounds(inst)
	local lo, hi
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			local p, s = d.CFrame.Position, d.Size
			local a, b = p - s / 2, p + s / 2
			lo = if lo then Vector3.new(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) else a
			hi = if hi then Vector3.new(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) else b
		end
	end
	return lo, hi
end
local floor = model:FindFirstChild("Tiles") or model:FindFirstChild("Inner") or model
local lo, hi = bounds(floor)
local center = (lo + hi) / 2
local offset = Vector3.new(-center.X, -hi.Y, -center.Z)
print(("piso: %s .. %s -> deslocando %s"):format(tostring(lo), tostring(hi), tostring(offset)))

local flat = { Tiles = true, Ground = true, Road = true, Outter = true, Borders = true, Corners = true, Grass = true }
local n = 0
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		d.CFrame = d.CFrame + offset
		d.Anchored = true
		local top = d
		while top.Parent and top.Parent ~= model do
			top = top.Parent
		end
		if flat[top.Name] then
			d.CastShadow = false
		end
		n += 1
	end
end
local lo2, hi2 = bounds(model)
print(("%d parts; bounds finais %s .. %s"):format(n, tostring(lo2), tostring(hi2)))
fs.writeFile("src/workspace/Arena.rbxm", roblox.serializeModel({ model }))
print("-> src/workspace/Arena.rbxm")
