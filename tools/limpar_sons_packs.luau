--[[
	limpar_sons_packs.luau (roda com Lune: ~/.rokit/bin/lune run tools/limpar_sons_packs.luau)
	Remove instâncias Sound dos .rbxm já extraídos em src/assets/VFX/Packs e src/import.
	Motivo: os SoundIds dos packs são de outra conta e geram "User is not authorized to access Asset"
	ao abrir o place. Som do jogo vem só de Assets.Sounds (Sounds.model.json).
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local total, arquivos = 0, 0

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif name:sub(-5) == ".rbxm" then
			local model = roblox.deserializeModel(fs.readFile(path))
			local removidos = 0
			for _, root in model do
				if root.ClassName == "Sound" then
					continue
				end
				for _, d in root:GetDescendants() do
					if d.ClassName == "Sound" then
						d:Destroy()
						removidos += 1
					end
				end
			end
			if removidos > 0 then
				fs.writeFile(path, roblox.serializeModel(model))
				print(("  %s: -%d Sound"):format(path, removidos))
				total += removidos
				arquivos += 1
			end
		end
	end
end

for _, dir in { "src/assets/VFX/Packs", "src/import" } do
	if fs.isDir(dir) then
		walk(dir)
	end
end
print(("FIM: %d Sound removidos em %d arquivos"):format(total, arquivos))
