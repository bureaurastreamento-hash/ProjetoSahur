--[[
	escavar_muralha.luau (roda com Lune: ~/.rokit/bin/lune run tools/escavar_muralha.luau)
	Abre um VÃO dentro da muralha sul (Workspace.Sahur.Arena.Walls.Model.Rocks) para a CÂMARA DO SANTUÁRIO
	(gerada pelo gerar_arena.py em ArenaExtras.Props: SanctShell*, BossAltar, BossSpawn...). Faz o mesmo que
	o dono fez à mão para a caverna da Taberna: as rochas que cruzam a câmara ficam mais curtas e sobem, de
	modo que o FUNDO delas passa a ser CAVE_TOP (o teto da câmara fecha o vão por dentro). Idempotente:
	rodar de novo não muda nada. Só mexe nas rochas cuja caixa cruza a região abaixo.
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local ARQ = "src/workspace/Arena.rbxm"
-- região da câmara (x/z do mundo) e altura do fundo das rochas depois de escavar
local X0, X1 = 30, 166
local Z0, Z1 = 380, 470
local CAVE_TOP = 34

local model = roblox.deserializeModel(fs.readFile(ARQ))
local root = model[1]
local rocks = root:FindFirstChild("Walls"):FindFirstChild("Model"):FindFirstChild("Rocks")
assert(rocks, "Rocks não achado")

local n, ja = 0, 0
for _, p in rocks:GetChildren() do
	if not p:IsA("BasePart") then
		continue
	end
	local cf = p.CFrame
	local pos, size = cf.Position, p.Size
	local _, ry = cf:ToOrientation()
	local ex = math.abs(math.sin(ry)) * size.Z / 2 + math.abs(math.cos(ry)) * size.X / 2
	local ez = math.abs(math.cos(ry)) * size.Z / 2 + math.abs(math.sin(ry)) * size.X / 2
	local bottom, top = pos.Y - size.Y / 2, pos.Y + size.Y / 2
	local cruza = pos.X + ex > X0 and pos.X - ex < X1 and pos.Z + ez > Z0 and pos.Z - ez < Z1 and bottom < CAVE_TOP
	if not cruza then
		continue
	end
	if math.abs(bottom - CAVE_TOP) < 0.05 then
		ja += 1
		continue
	end
	local newH = top - CAVE_TOP
	assert(newH > 10, "rocha ficaria baixa demais")
	p.Size = Vector3.new(size.X, newH, size.Z)
	p.CFrame = CFrame.new(pos.X, CAVE_TOP + newH / 2, pos.Z) * (cf - cf.Position)
	n += 1
	print(("rocha x %.0f..%.0f z %.0f..%.0f: fundo %.0f -> %d (altura %.0f -> %.0f)"):format(pos.X - ex, pos.X + ex, pos.Z - ez, pos.Z + ez, bottom, CAVE_TOP, size.Y, newH))
end
if n > 0 then
	fs.writeFile(ARQ, roblox.serializeModel(model))
end
print(("%d rochas escavadas, %d já estavam; gravado=%s"):format(n, ja, tostring(n > 0)))
