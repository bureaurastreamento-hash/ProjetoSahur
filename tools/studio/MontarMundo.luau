--[[
	MontarMundo — só o MAR do arquipélago (Terrain de água). O Rojo sincroniza este ModuleScript em
	ServerStorage.FerramentasStudio; para (re)gerar, no Studio (MCP run_code ou barra de comando):
	    require(game.ServerStorage.FerramentasStudio.MontarMundo:Clone())

	2026-09-29: o CHÃO das ilhas deixou de ser Terrain e virou PEÇAS (tools/gerar_chao_ilhas.py →
	Workspace.Sahur.ChaoIlhas, versionado no git). Aqui ficou só a água de verdade (nado nativo) e o fundo de areia.
	O terreno antigo (ilhas de Terrain, montanha do santuário) está em ServerStorage.Backup_Terreno_2026-09-29:
	    workspace.Terrain:PasteRegion(game.ServerStorage["Backup_Terreno_2026-09-29"], Vector3int16.new(-200, -12, -250), true)
	ATENÇÃO: Terrain:Clear() apaga qualquer edição manual de terreno do dono — perguntar antes de rodar.
]]
local Workspace = game:GetService("Workspace")
local terrain = Workspace.Terrain
local M = Enum.Material

local SEA = -2 -- superfície do mar
local FLOOR = -44 -- fundo do mar no núcleo
local WORLD = { x0 = -800, x1 = 2240, z0 = -1000, z1 = 880 } -- núcleo (mar fundo com areia no fundo)
local OCEAN = { x0 = -3600, x1 = 5000, z0 = -3600, z1 = 3400 } -- mar raso até o horizonte (borda não aparece)

terrain:Clear()
for x = OCEAN.x0, OCEAN.x1 - 1, 2048 do
	for z = OCEAN.z0, OCEAN.z1 - 1, 2048 do
		local sx, sz = math.min(2048, OCEAN.x1 - x), math.min(2048, OCEAN.z1 - z)
		terrain:FillBlock(CFrame.new(x + sx / 2, SEA - 6, z + sz / 2), Vector3.new(sx, 12, sz), M.Water)
		terrain:FillBlock(CFrame.new(x + sx / 2, SEA - 14, z + sz / 2), Vector3.new(sx, 4, sz), M.Sand)
	end
end
local STEP = 512
for x = WORLD.x0, WORLD.x1 - 1, STEP do
	for z = WORLD.z0, WORLD.z1 - 1, STEP do
		local sx, sz = math.min(STEP, WORLD.x1 - x), math.min(STEP, WORLD.z1 - z)
		terrain:FillBlock(CFrame.new(x + sx / 2, (FLOOR + SEA) / 2, z + sz / 2), Vector3.new(sx, SEA - FLOOR, sz), M.Water)
		terrain:FillBlock(CFrame.new(x + sx / 2, FLOOR - 2, z + sz / 2), Vector3.new(sx, 4, sz), M.Sand)
	end
end

-- visual cartoon (combina com a iluminação do EnvironmentService)
terrain.WaterColor = Color3.fromRGB(38, 150, 190)
terrain.WaterTransparency = 0.35
terrain.WaterReflectance = 0.6
terrain.WaterWaveSize = 0.18
terrain.WaterWaveSpeed = 9
terrain:SetMaterialColor(M.Sand, Color3.fromRGB(226, 202, 140))

print(("[montar_mundo] só mar: núcleo %dx%d; chão das ilhas = Workspace.Sahur.ChaoIlhas"):format(WORLD.x1 - WORLD.x0, WORLD.z1 - WORLD.z0))

return true
