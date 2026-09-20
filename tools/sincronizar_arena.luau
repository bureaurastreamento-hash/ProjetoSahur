--[[
	sincronizar_arena.luau (roda com Lune: ~/.rokit/bin/lune run tools/sincronizar_arena.luau <dump.txt> [aplicar])
	Grava no src/workspace/Arena.rbxm o que o dono MOVEU/REDIMENSIONOU no Studio (senão o Rojo sobrescreve
	de volta ao reconectar). <dump.txt> = saída do trecho abaixo rodado no Studio (MCP run_code ou barra de
	comando), uma entrada por peça:  Nome,px,py,pz,sx,sy,sz,ox,oy,oz  (separadas por ";" ou quebra de linha).
	Casa as peças por conteúdo (nome + tamanho + posição + orientação); o que sobra de um lado e do outro
	é o que mudou. Sem "aplicar" só lista; com "aplicar" pareia as sobras (mesmo nome, mais perto) e
	reescreve o .rbxm.
	Trecho para o Studio:
	    local L = {}; local function r(v) return string.format("%.2f", v) end
	    for _,d in workspace.Sahur.Arena:GetDescendants() do if d:IsA("BasePart") then
	      local p,s,o = d.Position,d.Size,d.Orientation
	      L[#L+1] = table.concat({d.Name,r(p.X),r(p.Y),r(p.Z),r(s.X),r(s.Y),r(s.Z),r(o.X),r(o.Y),r(o.Z)}, ",") end end
	    for k = 1, #L, 60 do print(table.concat(L, ";", k, math.min(k+59, #L))) end
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local ARQ = "src/workspace/Arena.rbxm"
local dumpPath = process.args[1]
local aplicar = process.args[2] == "aplicar"
assert(dumpPath, "uso: lune run tools/sincronizar_arena.luau <dump.txt> [aplicar]")

local function r2(v)
	local x = math.floor(v * 10 + 0.5) / 10 + 0 -- "+ 0" mata o -0.0
	if x == 0 then
		x = 0
	end
	return ("%.1f"):format(x)
end
local function key(name, pos, size, ori)
	return table.concat({ name, r2(pos[1]), r2(pos[2]), r2(pos[3]), r2(size[1]), r2(size[2]), r2(size[3]),
		r2(ori[1]), r2(ori[2]), r2(ori[3]) }, "|")
end

-- lê o dump do Studio
local studio = {}
local texto = fs.readFile(dumpPath):gsub("%[OUTPUT%]%s*", "")
for linha in texto:gmatch("[^;\n]+") do
	local c = {}
	for f in linha:gmatch("[^,]+") do
		c[#c + 1] = f
	end
	if #c == 11 and tonumber(c[1]) then
		table.remove(c, 1) -- formato antigo com índice
	end
	if #c == 10 and tonumber(c[2]) then
		local e = {
			name = c[1],
			pos = { tonumber(c[2]), tonumber(c[3]), tonumber(c[4]) },
			size = { tonumber(c[5]), tonumber(c[6]), tonumber(c[7]) },
			ori = { tonumber(c[8]), tonumber(c[9]), tonumber(c[10]) },
		}
		e.key = key(e.name, e.pos, e.size, e.ori)
		studio[#studio + 1] = e
	end
end

local model = roblox.deserializeModel(fs.readFile(ARQ))
local root = model[1]
local arquivo = {}
local function walk(inst)
	for _, c in inst:GetChildren() do
		if c:IsA("BasePart") then
			local cf = c.CFrame
			local rx, ry, rz = cf:ToOrientation()
			local e = {
				inst = c,
				name = c.Name,
				pos = { cf.Position.X, cf.Position.Y, cf.Position.Z },
				size = { c.Size.X, c.Size.Y, c.Size.Z },
				ori = { math.deg(rx), math.deg(ry), math.deg(rz) },
			}
			e.key = key(e.name, e.pos, e.size, e.ori)
			arquivo[#arquivo + 1] = e
		end
		walk(c)
	end
end
walk(root)
print(("Studio: %d peças | arquivo: %d peças"):format(#studio, #arquivo))

-- casa iguais (mesmo nome e todos os valores dentro da tolerância)
local function igual(a, b)
	for k = 1, 3 do
		if math.abs(a.pos[k] - b.pos[k]) > 0.03 or math.abs(a.size[k] - b.size[k]) > 0.03 then
			return false
		end
		local d = math.abs(a.ori[k] - b.ori[k]) % 360
		if math.min(d, 360 - d) > 0.06 then
			return false
		end
	end
	return true
end
local porNome = {}
for _, e in ipairs(arquivo) do
	porNome[e.name] = porNome[e.name] or {}
	table.insert(porNome[e.name], e)
end
local sobraStudio = {}
for _, e in ipairs(studio) do
	local achou
	for _, a in ipairs(porNome[e.name] or {}) do
		if not a.casado and igual(a, e) then
			achou = a
			break
		end
	end
	if achou then
		achou.casado = true
	else
		sobraStudio[#sobraStudio + 1] = e
	end
end
local sobraArquivo = {}
for _, e in ipairs(arquivo) do
	if not e.casado then
		sobraArquivo[#sobraArquivo + 1] = e
	end
end

local function fmt(v)
	return ("(%.2f, %.2f, %.2f)"):format(v[1], v[2], v[3])
end
print(("Sobras: %d no Studio (mudadas) | %d no arquivo (originais)"):format(#sobraStudio, #sobraArquivo))
for _, e in ipairs(sobraArquivo) do
	print("  ARQUIVO " .. e.inst:GetFullName() .. " pos " .. fmt(e.pos) .. " size " .. fmt(e.size) .. " ori " .. fmt(e.ori))
end
for _, e in ipairs(sobraStudio) do
	print("  STUDIO  " .. e.name .. " pos " .. fmt(e.pos) .. " size " .. fmt(e.size) .. " ori " .. fmt(e.ori))
end

if not aplicar then
	return
end
-- pareia por nome + menor distância (posição e tamanho)
local n = 0
for _, s in ipairs(sobraStudio) do
	local melhor, melhorD
	for _, a in ipairs(sobraArquivo) do
		if not a.usado and a.name == s.name then
			local d = 0
			for k = 1, 3 do
				d += (a.pos[k] - s.pos[k]) ^ 2 + (a.size[k] - s.size[k]) ^ 2
			end
			if not melhorD or d < melhorD then
				melhor, melhorD = a, d
			end
		end
	end
	if melhor then
		melhor.usado = true
		melhor.inst.Size = Vector3.new(s.size[1], s.size[2], s.size[3])
		melhor.inst.CFrame = CFrame.new(s.pos[1], s.pos[2], s.pos[3])
			* CFrame.fromOrientation(math.rad(s.ori[1]), math.rad(s.ori[2]), math.rad(s.ori[3]))
		n += 1
		print(("  aplicado: %s  %s -> %s"):format(melhor.inst:GetFullName(), fmt(melhor.pos), fmt(s.pos)))
	else
		print("  SEM PAR no arquivo: " .. s.name .. " " .. fmt(s.pos))
	end
end
if n > 0 then
	fs.writeFile(ARQ, roblox.serializeModel(model))
	print(("gravado %s (%d peças)"):format(ARQ, n))
end
