--[[
	restaurar_workspace.luau — roda com Lune: ~/.rokit/bin/lune run tools/restaurar_workspace.luau <dump.jsonl> <saida.rbxm>
	Reconstrói em .rbxm o que o dono montou À MÃO no Workspace (tudo fora de `Workspace.Sahur`: Taberna,
	Moveis taverna, cav, LojinhaDecor, casas, árvores...) a partir de um dump JSONL tirado no Studio via MCP
	(ver PROGRESSO "backup do Workspace do dono"). É um backup de SEGURANÇA, best-effort:
	  - Part/MeshPart/SpawnLocation/Seat: CFrame, Size, Color, Material, Transparency, Reflectance, Anchored,
	    CanCollide, CastShadow, Shape, MeshId/TextureID.
	  - SpecialMesh, luzes, Fire, Decal, Attachment, Sound, SurfaceAppearance, TextLabel.
	  - UnionOperation NÃO tem como ser reconstruída por propriedades: vira um Part "placeholder" com o
	    atributo `UnionPerdida = true` (mesmo tamanho/posição) — se precisar restaurar, pegar a união do
	    histórico de versões do place (Team Create).
	Para restaurar no Studio: Insert from File do .rbxm gerado (não passa pelo Rojo).
]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local dumpPath, outPath = process.args[1], process.args[2]
assert(dumpPath and outPath, "uso: lune run tools/restaurar_workspace.luau <dump.jsonl> <saida.rbxm>")

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end
local function col(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end
local function cf(t)
	return CFrame.new(table.unpack(t))
end

local root = Instance.new("Folder")
root.Name = process.args[3] or "WorkspaceDono"
local byId = { [0] = root }
local perdidas, total = 0, 0

for line in fs.readFile(dumpPath):gmatch("[^\n]+") do
	local e = serde.decode("json", line)
	local class = e.c
	local inst
	if class == "UnionOperation" then
		inst = Instance.new("Part")
		inst:SetAttribute("UnionPerdida", true)
		perdidas += 1
	else
		local ok, made = pcall(Instance.new, class)
		if ok then
			inst = made
		else
			inst = Instance.new("Folder")
			inst:SetAttribute("ClasseOriginal", class)
		end
	end
	inst.Name = e.n
	total += 1
	pcall(function()
		if inst:IsA("BasePart") then
			inst.CFrame = cf(e.cf)
			inst.Size = v3(e.sz)
			inst.Color = col(e.col)
			inst.Material = Enum.Material[e.mat] or Enum.Material.Plastic
			inst.Transparency = e.tr or 0
			inst.Reflectance = e.re or 0
			inst.Anchored = e.an ~= false
			inst.CanCollide = e.cc ~= false
			inst.CastShadow = e.cs ~= false
			if e.sh and inst:IsA("Part") then
				inst.Shape = Enum.PartType[e.sh] or Enum.PartType.Block
			end
			if inst:IsA("MeshPart") then
				inst.MeshId = e.mesh or ""
				inst.TextureID = e.tex or ""
			end
			if inst:IsA("SpawnLocation") and e.neutral ~= nil then
				inst.Neutral = e.neutral
			end
		elseif class == "SpecialMesh" then
			inst.MeshId = e.mesh or ""
			inst.TextureId = e.tex or ""
			inst.Scale = v3(e.sc)
			inst.MeshType = Enum.MeshType[e.mt] or Enum.MeshType.FileMesh
		elseif inst:IsA("Light") then
			inst.Color = col(e.col)
			inst.Brightness = e.br
			inst.Shadows = e.sh == true
			if e.rg then
				inst.Range = e.rg
			end
			if class == "SpotLight" then
				inst.Angle = e.ang
				inst.Face = Enum.NormalId[e.face]
			end
		elseif class == "Fire" then
			inst.Size = e.sz
			inst.Heat = e.heat
			inst.Color = col(e.col)
			inst.SecondaryColor = col(e.col2)
		elseif class == "Decal" then
			inst.Texture = e.tex
			inst.Face = Enum.NormalId[e.face]
			inst.Transparency = e.tr or 0
		elseif class == "Attachment" then
			inst.CFrame = cf(e.cf)
		elseif class == "Sound" then
			inst.SoundId = e.sid
			inst.Volume = e.vol
			inst.Looped = e.loop
			inst.Playing = e.play
		elseif class == "SurfaceAppearance" then
			inst.ColorMap = e.cm or ""
			inst.NormalMap = e.nm or ""
			inst.RoughnessMap = e.rm or ""
			inst.MetalnessMap = e.mm or ""
		elseif class == "TextLabel" then
			inst.Text = e.text or ""
		end
	end)
	byId[e.id] = inst
	inst.Parent = byId[e.p] or root
end

fs.writeFile(outPath, roblox.serializeModel({ root }))
print(("gravado %s: %d instâncias (%d uniões viraram placeholder)"):format(outPath, total, perdidas))
