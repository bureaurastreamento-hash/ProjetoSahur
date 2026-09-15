--[[
	podar_vfx.luau (roda com Lune: ~/.rokit/bin/lune run tools/podar_vfx.luau)
	Lê todos os caminhos "Packs/<Pack>/<Arquivo>/..." em src/shared/Modules/Assets.luau e gera em
	src/assets/VFX/Packs/<Pack>/<Arquivo>.rbxm SÓ as subárvores usadas, a partir dos packs completos
	em packs/VFX/<Pack>/<Arquivo>.rbxm. Rodar sempre que mudar Assets.VFXPack.
	Motivo: os packs completos têm ~95k instâncias (ParticleEmitters, KeyframeSequences de cutscene);
	replicar isso em ReplicatedStorage derruba FPS/memória. Para navegar o pack inteiro no Preview
	de VFX (F7): Studio > ReplicatedStorage.Assets.VFX.Packs > clique direito > Insert from File >
	packs/VFX/<Pack>/<Arquivo>.rbxm (e apague depois; o Rojo ignora o que não conhece).
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local ORIGEM = "packs/VFX"
local DESTINO = "src/assets/VFX/Packs"

local src = fs.readFile("src/shared/Modules/Assets.luau")
-- por arquivo: lista de caminhos internos (a partir da raiz do .rbxm)
local porArquivo: { [string]: { string } } = {}
local vistos = {}
for path in src:gmatch('"Packs/([^"]+)"') do
	if not vistos[path] then
		vistos[path] = true
		local pack, arquivo, resto = path:match("^([^/]+)/([^/]+)/?(.*)$")
		if pack and arquivo then
			local chave = pack .. "/" .. arquivo
			porArquivo[chave] = porArquivo[chave] or {}
			table.insert(porArquivo[chave], resto or "")
		end
	end
end

local function ensureDir(p)
	if not fs.isDir(p) then
		fs.writeDir(p)
	end
end
ensureDir(DESTINO)

-- limpa os arquivos podados antigos (só subpastas; ParticlePack.rbxm fica)
for _, n in fs.readDir(DESTINO) do
	local p = DESTINO .. "/" .. n
	if fs.isDir(p) then
		fs.removeDir(p)
	end
end

local LIXO = { Script = true, LocalScript = true, ModuleScript = true, Sound = true, KeyframeSequence = true, Animation = true, BillboardGui = true }

local totalInst, arquivos = 0, 0
local chaves = {}
for k in porArquivo do
	table.insert(chaves, k)
end
table.sort(chaves)
for _, chave in chaves do
	local caminhos = porArquivo[chave]
	local pack, arquivo = chave:match("^([^/]+)/(.+)$")
	local origem = ("%s/%s/%s.rbxm"):format(ORIGEM, pack, arquivo)
	if not fs.isFile(origem) then
		warn("pack não encontrado: " .. origem .. " (extraia com tools/extrair_pack.luau vfx)")
		continue
	end
	local modelo = roblox.deserializeModel(fs.readFile(origem))
	local raiz = modelo[1]
	if not raiz then
		warn("vazio: " .. origem)
		continue
	end
	-- marca o que fica: cada alvo + ancestrais + descendentes
	local manter: { [any]: boolean } = { [raiz] = true }
	for _, resto in caminhos do
		local cur = raiz
		if resto ~= "" then
			for seg in resto:gmatch("[^/]+") do
				cur = cur and cur:FindFirstChild(seg)
			end
		end
		if not cur then
			warn(("caminho não existe no pack: Packs/%s/%s"):format(chave, resto))
			continue
		end
		local a = cur
		while a do
			manter[a] = true
			a = a.Parent
		end
		for _, d in cur:GetDescendants() do
			manter[d] = true
		end
	end
	-- remove o resto (de baixo pra cima, sem mexer em quem já foi destruído)
	local remover = {}
	for _, d in raiz:GetDescendants() do
		if not manter[d] or LIXO[d.ClassName] then
			table.insert(remover, d)
		end
	end
	for _, d in remover do
		if d.Parent then
			d:Destroy()
		end
	end
	local n = 1 + #raiz:GetDescendants()
	totalInst += n
	arquivos += 1
	ensureDir(DESTINO .. "/" .. pack)
	fs.writeFile(("%s/%s/%s.rbxm"):format(DESTINO, pack, arquivo), roblox.serializeModel({ raiz }))
	print(("  %-45s %5d instâncias  (%d efeito(s))"):format(chave .. ".rbxm", n, #caminhos))
end
print(("FIM: %d arquivos, %d instâncias em %s"):format(arquivos, totalInst, DESTINO))
