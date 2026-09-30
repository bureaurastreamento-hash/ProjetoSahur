--[[
	corrigir_sobreposicao.luau — roda NO STUDIO (MCP run_code), modo edição. Ctrl+Z desfaz.
	Acha faces COPLANARES com área em comum entre Parts retangulares ancoradas (é o "tremido"/z-fighting — ver
	achar_sobreposicao.luau, que só lista) e resolve recuando SÓ a face da peça MENOR 0.04 stud para dentro
	(tamanho -0.04 e centro 0.02 para trás naquele eixo; a face do outro lado não se mexe). Invisível a olho e não
	quebra tijolo destrutível (a checagem de apoio do DestructionService tolera 0.5 stud). Repete até zerar.
	Não mexe em MeshPart/Union/Wedge nem nos modelos soltos de arte (Arvore*/Pedra*). Faces de baixo não contam.
]]
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local EPS, MIN, RECUO = 0.02, 0.4, 0.04
local function ignorado(p: Instance): boolean
	local q = p
	while q and q.Parent ~= workspace do
		q = q.Parent
	end
	return q == nil or q:IsA("Camera") or q.Name:match("^Arvore") ~= nil or q.Name:match("^Pedra") ~= nil
end

local AX = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
local F = { "X", "Y", "Z" }
local function ext(a: BasePart, b: BasePart)
	local rel = a.CFrame:ToObjectSpace(b.CFrame)
	local half = b.Size / 2
	local e = Vector3.zero
	for i, ax in AX do
		local v = rel:VectorToWorldSpace(ax)
		local m = Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
		if math.max(m.X, m.Y, m.Z) < 0.999 then
			return nil
		end
		e += m * (if i == 1 then half.X elseif i == 2 then half.Y else half.Z)
	end
	return rel.Position, e
end

local function recuar(p: BasePart, dirMundo: Vector3)
	local l = p.CFrame:VectorToObjectSpace(dirMundo)
	local a = Vector3.new(math.abs(l.X), math.abs(l.Y), math.abs(l.Z))
	local eixo = if a.X >= a.Y and a.X >= a.Z then Vector3.xAxis elseif a.Y >= a.Z then Vector3.yAxis else Vector3.zAxis
	local sinal = if l:Dot(eixo) > 0 then 1 else -1
	if (p.Size * eixo).Magnitude <= RECUO * 3 then
		return
	end
	p.Size -= eixo * RECUO
	p.CFrame *= CFrame.new(-eixo * sinal * RECUO / 2)
end

local rec = ChangeHistoryService:TryBeginRecording("Corrigir sobreposições")
local total = 0
for passada = 1, 4 do
	local parts = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("Part") and d.Shape == Enum.PartType.Block and d.Anchored and d.Transparency < 1 and not ignorado(d) then
			table.insert(parts, d)
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = parts
	local visto, pares = {}, {}
	for _, a in parts do
		for _, b in workspace:GetPartBoundsInBox(a.CFrame, a.Size + Vector3.one * EPS * 2, params) do
			if b == a then
				continue
			end
			local ia, ib = a:GetDebugId(), b:GetDebugId()
			local k = if ia < ib then ia .. ib else ib .. ia
			if visto[k] then
				continue
			end
			local c, e = ext(a, b)
			if not c then
				continue
			end
			local ha = a.Size / 2
			local lo, hi = c - e, c + e
			for i = 1, 3 do
				local ok = true
				for j = 1, 3 do
					if j ~= i and math.min(ha[F[j]], hi[F[j]]) - math.max(-ha[F[j]], lo[F[j]]) < MIN then
						ok = false
					end
				end
				if not ok then
					continue
				end
				for _, sinal in { 1, -1 } do
					local fa = sinal * ha[F[i]]
					local fb = if sinal == 1 then hi[F[i]] else lo[F[i]]
					if math.abs(fa - fb) < EPS then
						local dir = a.CFrame:VectorToWorldSpace(AX[i] * sinal)
						if dir.Y < -0.9 then
							continue -- face de baixo: não aparece
						end
						visto[k] = true
						table.insert(pares, { a = a, b = b, dir = dir })
					end
				end
			end
		end
	end
	if #pares == 0 then
		break
	end
	for _, p in pares do
		local menor = if p.a.Size.X * p.a.Size.Y * p.a.Size.Z <= p.b.Size.X * p.b.Size.Y * p.b.Size.Z then p.a else p.b
		recuar(menor, p.dir)
	end
	total += #pares
	print(("[sobreposicao] passada %d: %d faces recuadas"):format(passada, #pares))
end
if rec then
	ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
print(("[sobreposicao] total: %d faces recuadas"):format(total))
