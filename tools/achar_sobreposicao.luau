--[[
	achar_sobreposicao.luau — roda NO STUDIO (MCP run_code ou barra de comando). Só LÊ (FIX = false).
	Acha faces COPLANARES sobrepostas entre peças ancoradas do Workspace: é isso que dá o "tremido"
	(z-fighting) quando um modelo passa por cima do outro. Agrupar (Model) NÃO resolve — o que resolve é
	afastar uma das peças alguns centésimos ou apagar a face escondida.
	Saída: lista "A <-> B (face)" no Output e as peças ficam SELECIONADAS no Studio (Explorer/viewport).
	FIX = true: empurra a peça MENOR de cada par 0.02 stud para fora da face (mínimo visível) — reversível
	com Ctrl+Z; só use depois de olhar a lista.
]]

local Workspace = game:GetService("Workspace")
local Selection = game:GetService("Selection")

local FIX = false
local EPS = 0.02 -- distância entre faces para contar como "mesmo plano"
local MIN_OVERLAP = 0.4 -- área sobreposta precisa de pelo menos isto (stud) em cada eixo
local IGNORE = { "Terrain", "Camera", "Barriers", "Cerca" } -- nomes de ancestrais ignorados
local MAX_PARTS = 6000
local SKIP_DOWN = true -- ignora faces de BAIXO coplanares (peças apoiadas no mesmo chão: quase nunca se vê)
local ONLY_CROSS = false -- true = só pares entre MODELOS DIFERENTES do Workspace (o "modelo passando por outro")

local function ignored(inst)
	local p = inst
	while p and p ~= Workspace do
		if table.find(IGNORE, p.Name) or (p:IsA("BasePart") and p.Transparency >= 1) then
			return true
		end
		p = p.Parent
	end
	return false
end

local parts = {}
for _, d in Workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Anchored and not d:IsA("Terrain") and not ignored(d) then
		table.insert(parts, d)
		if #parts >= MAX_PARTS then
			warn("[sobreposicao] limite de peças; aumente MAX_PARTS")
			break
		end
	end
end

-- Verifica B no espaço local de A: só quando B está alinhado a A (giro múltiplo de 90°).
local AXES = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
local function alignedExtents(a, b)
	local rel = a.CFrame:ToObjectSpace(b.CFrame)
	local half = b.Size / 2
	local ext = Vector3.zero
	for i, axis in AXES do
		local v = rel:VectorToWorldSpace(axis) -- eixo de B no espaço de A
		local m = Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
		if math.max(m.X, m.Y, m.Z) < 0.999 then
			return nil -- B torto em relação a A: não dá para comparar faces planas
		end
		local h = if i == 1 then half.X elseif i == 2 then half.Y else half.Z
		ext = ext + m * h
	end
	return rel.Position, ext
end

local found = {}
local seen = {}
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = parts

local FACE = { "X", "Y", "Z" }
for _, a in parts do
	local near = Workspace:GetPartBoundsInBox(a.CFrame, a.Size + Vector3.new(EPS * 2, EPS * 2, EPS * 2), params)
	for _, b in near do
		if b == a or not b.Anchored then
			continue
		end
		local key = if a:GetDebugId() < b:GetDebugId() then a:GetDebugId() .. b:GetDebugId() else b:GetDebugId() .. a:GetDebugId()
		if seen[key] then
			continue
		end
		local center, ext = alignedExtents(a, b)
		if not center then
			continue
		end
		local ha = a.Size / 2
		local lo, hi = center - ext, center + ext
		for i = 1, 3 do
			local aMin, aMax = -ha[FACE[i]], ha[FACE[i]]
			local bMin, bMax = lo[FACE[i]], hi[FACE[i]]
			local coplanar = (math.abs(aMin - bMin) < EPS) or (math.abs(aMax - bMax) < EPS)
			if not coplanar then
				continue
			end
			-- sobreposição real nos outros dois eixos
			local ok = true
			for j = 1, 3 do
				if j ~= i then
					local overlap = math.min(ha[FACE[j]], hi[FACE[j]]) - math.max(-ha[FACE[j]], lo[FACE[j]])
					if overlap < MIN_OVERLAP then
						ok = false
					end
				end
			end
			if ok then
				seen[key] = true
				local side = if math.abs(aMax - bMax) < EPS then "+" .. FACE[i] else "-" .. FACE[i]
				local downward = i == 2 and side == "-Y" and a.CFrame.UpVector.Y > 0.9
				if not (SKIP_DOWN and downward) then
					table.insert(found, { a = a, b = b, face = side, axis = i })
				end
				break
			end
		end
	end
end

local function top(p)
	local q = p
	while q.Parent and q.Parent ~= Workspace do
		q = q.Parent
	end
	return q.Name
end
if ONLY_CROSS then
	local cross = {}
	for _, f in found do
		if top(f.a) ~= top(f.b) then
			table.insert(cross, f)
		end
	end
	found = cross
end
table.sort(found, function(x, y)
	local cx, cy = top(x.a) ~= top(x.b), top(y.a) ~= top(y.b)
	if cx ~= cy then
		return cx -- pares entre modelos diferentes primeiro
	end
	return x.a:GetFullName() < y.a:GetFullName()
end)
local byModel = {}
for _, f in found do
	local k = top(f.a) .. " / " .. top(f.b)
	byModel[k] = (byModel[k] or 0) + 1
end
for k, n in byModel do
	print(("[sobreposicao] %3d pares  %s"):format(n, k))
end
local sel = {}
for _, f in found do
	print(("[sobreposicao] %s%s  <->  %s  (face %s)"):format(if top(f.a) ~= top(f.b) then "ENTRE MODELOS: " else "", f.a:GetFullName(), f.b:GetFullName(), f.face))
	table.insert(sel, f.a)
	table.insert(sel, f.b)
	if FIX then
		local small = if f.a.Size.Magnitude <= f.b.Size.Magnitude then f.a else f.b
		local dir = f.a.CFrame:VectorToWorldSpace(AXES[f.axis]) * (if f.face:sub(1, 1) == "+" then 1 else -1)
		local sign = if small == f.a then -1 else 1 -- a menor entra 0.02 para o lado de dentro dela
		small.CFrame = small.CFrame + dir * (0.02 * sign)
	end
end
Selection:Set(sel)
print(("[sobreposicao] %d par(es) em %d peças%s"):format(#found, #parts, if FIX then " — corrigidos (Ctrl+Z desfaz)" else ""))
