--[[
	extrair_pack.luau (roda com Lune: ~/.rokit/bin/lune run tools/extrair_pack.luau <modo> <arquivo.rbxl>)
	Extrai dos packs em AssetsPacks/:
	  kfs     -> KeyframeSequences para src/import/Animacoes/<Pack>/<Nome>.rbxm
	             (ServerStorage.Import via Rojo; no Studio: clique direito > Save to Roblox
	              para virar uma Animation SUA, aí o id vai em src/assets/Animations.model.json)
	  sons    -> lista todos os SoundIds únicos em scratch/sons_<Pack>.json
	  listar  -> imprime a árvore dos Folders de VFX (para escolher o que extrair)
	  vfx <caminho> [...]    -> extrai para src/assets/VFX/Packs/<Pack>/<Nome>.rbxm (replicado, para FX)
	  import <caminho> [...] -> extrai para src/import/<Pack>/<Nome>.rbxm (ServerStorage.Import, só olhar)
	  ("<pasta>/*" = cada Folder/Model filho vira um arquivo)
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")

local mode = process.args[1]
local file = process.args[2]
assert(mode and file, "uso: lune run tools/extrair_pack.luau <kfs|sons|listar|vfx> <arquivo.rbxl> [caminhos...]")

local packName = file:match("%] ([^/]+)%.rbx[lm]$") or file:match("([^/]+)%.rbx[lm]$") or "Pack"
packName = packName:gsub("%s+", ""):gsub("[^%w]", "")

local game = roblox.deserializePlace(fs.readFile(file))

local function safeName(name: string): string
	local s = name:gsub("[^%w%-_ ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	return if s == "" then "SemNome" else s
end

local function ensureDir(path: string)
	if not fs.isDir(path) then
		fs.writeDir(path)
	end
end

local function fullName(inst): string
	local parts = {}
	local cur = inst
	while cur and cur.ClassName ~= "DataModel" do
		table.insert(parts, 1, cur.Name)
		cur = cur.Parent
	end
	return table.concat(parts, "/")
end

local function findByPath(path: string)
	local cur = game
	for seg in path:gmatch("[^/]+") do
		local nxt = cur:FindFirstChild(seg)
		if not nxt then
			return nil
		end
		cur = nxt
	end
	return cur
end

if mode == "kfs" then
	local dir = "src/import/Animacoes/" .. packName
	ensureDir("src/import/Animacoes")
	ensureDir(dir)
	local seen = {}
	local n = 0
	for _, inst in game:GetDescendants() do
		if inst.ClassName == "KeyframeSequence" then
			local base = safeName(inst.Name)
			local name = base
			local i = 2
			while seen[name] do
				name = ("%s_%d"):format(base, i)
				i += 1
			end
			seen[name] = true
			local clone = inst:Clone()
			clone.Name = name
			fs.writeFile(("%s/%s.rbxm"):format(dir, name), roblox.serializeModel({ clone }))
			n += 1
			print(("  %s  <- %s (%d keyframes)"):format(name, fullName(inst), #inst:GetChildren()))
		end
	end
	print(("%d KeyframeSequence(s) em %s"):format(n, dir))
elseif mode == "sons" then
	local ids = {}
	local list = {}
	for _, inst in game:GetDescendants() do
		if inst.ClassName == "Sound" then
			local okId, id = pcall(function()
				return tostring(inst.SoundId)
			end)
			local num = okId and id:match("(%d+)") or nil
			if num and not ids[num] then
				ids[num] = true
				local okVol, vol = pcall(function()
					return inst.Volume
				end)
				table.insert(list, { id = num, name = inst.Name, path = fullName(inst), volume = if okVol then vol else 0.5 })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.path < b.path
	end)
	ensureDir("scratch")
	local out = ("scratch/sons_%s.json"):format(packName)
	fs.writeFile(out, serde.encode("json", list, true))
	print(("%d sons únicos em %s"):format(#list, out))
elseif mode == "listar" then
	local maxDepth = tonumber(process.args[3]) or 3
	local function walk(inst, depth)
		if depth > maxDepth then
			return
		end
		local kids = inst:GetChildren()
		local counts = {}
		for _, d in inst:GetDescendants() do
			counts[d.ClassName] = (counts[d.ClassName] or 0) + 1
		end
		local summary = {}
		for _, cls in { "ParticleEmitter", "MeshPart", "Beam", "Trail", "Sound", "Animation", "Script", "LocalScript", "ModuleScript" } do
			if counts[cls] then
				table.insert(summary, ("%s=%d"):format(cls, counts[cls]))
			end
		end
		print(("%s%s [%s] %s"):format(("  "):rep(depth), inst.Name, inst.ClassName, table.concat(summary, " ")))
		for _, k in kids do
			if k.ClassName == "Folder" or k.ClassName == "Model" or k.ClassName == "Configuration" then
				walk(k, depth + 1)
			end
		end
	end
	for _, path in { "ReplicatedStorage", "ServerStorage", "Workspace", "ReplicatedFirst", "StarterPack", "Lighting" } do
		local svc = game:FindFirstChild(path)
		if svc then
			walk(svc, 0)
		end
	end
elseif mode == "vfx" or mode == "import" then
	local dir = if mode == "vfx" then "src/assets/VFX/Packs/" .. packName else "src/import/" .. packName
	ensureDir(if mode == "vfx" then "src/assets/VFX/Packs" else "src/import")
	ensureDir(dir)
	local targets = {}
	for i = 3, #process.args do
		local path = process.args[i]
		if path:sub(-2) == "/*" then
			local parent = findByPath(path:sub(1, -3))
			if parent then
				for _, k in parent:GetChildren() do
					if k.ClassName == "Folder" or k.ClassName == "Model" then
						table.insert(targets, k)
					end
				end
			else
				warn("não achei: " .. path)
			end
		else
			local inst = findByPath(path)
			if inst then
				table.insert(targets, inst)
			else
				warn("não achei: " .. path)
			end
		end
	end
	local seen = {}
	for _, inst in targets do
		local path = fullName(inst)
		local clone = inst:Clone()
		-- sem scripts, GUIs de demo nem Sounds (SoundId de outra conta -> "not authorized" no Studio;
		-- som do jogo vem de Assets.Sounds via Sounds.model.json)
		for _, d in clone:GetDescendants() do
			if d.ClassName == "Script" or d.ClassName == "LocalScript" or d.ClassName == "ModuleScript" or d.ClassName == "BillboardGui" or d.ClassName == "Sound" then
				d:Destroy()
			end
		end
		local name = safeName(clone.Name)
		local k = 2
		while seen[name] do
			name = ("%s_%d"):format(safeName(clone.Name), k)
			k += 1
		end
		seen[name] = true
		clone.Name = name
		fs.writeFile(("%s/%s.rbxm"):format(dir, name), roblox.serializeModel({ clone }))
		print(("  %s/%s.rbxm  <- %s (%d instâncias)"):format(dir, name, path, #clone:GetDescendants()))
	end
else
	error("modo desconhecido: " .. mode)
end
