--[[
	MontarRelevoLowPoly — roda NO STUDIO (MCP run_code), modo edição:
		require(game.ServerStorage.FerramentasStudio.MontarRelevoLowPoly)(destino?)
	Pedido do dono (01/10): as duas montanhas (MontanhaSantuario e RochaTaberna) ficaram "estranhas, muitas partes,
	feias, exageradas" com as lascas do montar_relevo.luau (30/09) → deixar SIMPLES mas bonita.
	Estilo LOW-POLY: uma casca de triângulos lisos (2 WedgeParts por triângulo) que embrulha o núcleo original (os
	blocos não mudam): anéis em K ângulos, raio calculado para conter todo o núcleo acima de cada altura (nada fura a
	casca), base com encosta mais deitada (pé do morro), topo arredondado. Cor por faixa (pé = grama/areia do chão,
	meio = rocha, topo = grama/areia) com sombreamento por face (luz fixa) — SmoothPlastic, regra do chão liso.
	ZONAS ficam abertas (porta da Taberna/caverna `cav`, cachoeira + santuário): a casca não cobre.
	Determinístico (seed por alvo). Rodar de novo refaz do zero só o que ele criou em `destino` (padrão
	Workspace.Sahur.RelevoLowPoly).
]]

local S = workspace.Sahur

type Alvo = {
	nome: string,
	nucleo: () -> { BasePart },
	chao: () -> { Instance },
	rocha: { Color3 },
	pe: Color3,
	topo: Color3,
	zonas: { { Vector3 } },
	k: number,
	pico: number, -- quanto o topo sobe acima do núcleo
	encosta: number, -- quanto o pé avança por stud de altura da 1ª faixa (maior = mais deitado)
	seed: number,
}

local ALVOS: { Alvo } = {
	{
		nome = "MontanhaSantuario",
		nucleo = function()
			local l = {}
			for _, p in S.ChaoIlhas.MontanhaSantuario:GetDescendants() do
				if p:IsA("BasePart") then
					table.insert(l, p)
				end
			end
			return l
		end,
		chao = function()
			local l: { Instance } = { workspace.Terrain }
			for _, c in S.ChaoIlhas:GetChildren() do
				if c.Name ~= "MontanhaSantuario" then
					table.insert(l, c)
				end
			end
			return l
		end,
		rocha = { Color3.fromRGB(178, 112, 76), Color3.fromRGB(196, 128, 86), Color3.fromRGB(212, 146, 100) },
		pe = Color3.fromRGB(214, 160, 104),
		topo = Color3.fromRGB(226, 178, 120),
		zonas = { -- cachoeira + entrada do santuário (face sul)
			{ Vector3.new(870, -20, -712), Vector3.new(930, 140, -590) },
		},
		k = 14,
		pico = 8,
		encosta = 0.7,
		seed = 1001,
	},
	{
		nome = "RochaTaberna",
		nucleo = function()
			local l = {}
			for _, p in S.PecasArena.RochaTaberna:GetDescendants() do
				if p:IsA("BasePart") and p.Material ~= Enum.Material.Grass then
					table.insert(l, p)
				end
			end
			return l
		end,
		chao = function()
			return { workspace.Terrain, S.ChaoIlhas }
		end,
		rocha = { Color3.fromRGB(112, 114, 122), Color3.fromRGB(126, 128, 134), Color3.fromRGB(140, 141, 146) },
		pe = Color3.fromRGB(104, 158, 82),
		topo = Color3.fromRGB(110, 164, 86),
		zonas = { -- porta da Taberna (face oeste, moldura da caverna `cav`)
			{ Vector3.new(225, -20, 40), Vector3.new(300, 60, 145) },
		},
		k = 14,
		pico = 6,
		encosta = 0.6,
		seed = 1002,
	},
}

local LUZ = Vector3.new(-0.45, 0.8, -0.35).Unit
local ESPESSURA = 2
local MARGEM = 3

--- Cantos + pontos a cada ~6 studs nas arestas horizontais (topo e base) do bloco.
local function cantos(p: BasePart, out: { Vector3 })
	local h = p.Size / 2
	local nx, nz = math.max(1, math.ceil(p.Size.X / 6)), math.max(1, math.ceil(p.Size.Z / 6))
	for _, sy in { -1, 1 } do
		for i = 0, nx do
			for _, sz in { -1, 1 } do
				table.insert(out, (p.CFrame * CFrame.new(-h.X + p.Size.X * i / nx, h.Y * sy, h.Z * sz)).Position)
			end
		end
		for i = 0, nz do
			for _, sx in { -1, 1 } do
				table.insert(out, (p.CFrame * CFrame.new(h.X * sx, h.Y * sy, -h.Z + p.Size.Z * i / nz)).Position)
			end
		end
	end
end

local function dentroZona(p: Vector3, zonas: { { Vector3 } }): boolean
	for _, z in zonas do
		if p.X > z[1].X and p.X < z[2].X and p.Y > z[1].Y and p.Y < z[2].Y and p.Z > z[1].Z and p.Z < z[2].Z then
			return true
		end
	end
	return false
end

local function shade(base: Color3, normal: Vector3): Color3
	local k = 0.82 + 0.28 * math.clamp(normal:Dot(LUZ), -0.2, 1)
	return Color3.new(math.clamp(base.R * k, 0, 1), math.clamp(base.G * k, 0, 1), math.clamp(base.B * k, 0, 1))
end

local function wedge(parent: Instance, color: Color3): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = "Face"
	w.Anchored = true
	w.Material = Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Color = color
	w.Parent = parent
	return w
end

--- Triângulo (a, b, c) com 2 wedges; `inward` = direção para dentro do morro (a espessura vai para dentro).
local function triangulo(parent: Instance, a: Vector3, b: Vector3, c: Vector3, inward: Vector3, color: Color3): { WedgePart }
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-4 then
		return {}
	end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	if height < 0.05 then
		return {}
	end
	local shift = inward * (ESPESSURA / 2)
	local w1 = wedge(parent, color)
	w1.Size = Vector3.new(ESPESSURA, height, math.max(0.05, math.abs(ab:Dot(back))))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2 + shift, right, up, back)
	local w2 = wedge(parent, color)
	w2.Size = Vector3.new(ESPESSURA, height, math.max(0.05, math.abs(ac:Dot(back))))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2 + shift, -right, up, -back)
	return { w1, w2 }
end

local function montar(alvo: Alvo, destino: Instance)
	local old = destino:FindFirstChild(alvo.nome)
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = alvo.nome
	model.Parent = destino

	local pts: { Vector3 } = {}
	for _, p in alvo.nucleo() do
		cantos(p, pts)
	end
	if #pts == 0 then
		warn("[RelevoLowPoly] núcleo vazio: " .. alvo.nome)
		return
	end
	local minY, maxY = math.huge, -math.huge
	local cx, cz = 0, 0
	local mnX, mxX, mzMin, mzMax = math.huge, -math.huge, math.huge, -math.huge
	for _, p in pts do
		minY, maxY = math.min(minY, p.Y), math.max(maxY, p.Y)
		mnX, mxX, mzMin, mzMax = math.min(mnX, p.X), math.max(mxX, p.X), math.min(mzMin, p.Z), math.max(mzMax, p.Z)
	end
	cx, cz = (mnX + mxX) / 2, (mzMin + mzMax) / 2
	local center = Vector3.new(cx, 0, cz)

	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = alvo.chao()
	local function chaoEm(x: number, z: number): number?
		local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), rp)
		return if hit then hit.Position.Y else nil
	end
	local g0 = chaoEm(cx + (mxX - mnX) * 0.6, cz) or chaoEm(cx - (mxX - mnX) * 0.6, cz) or minY
	local top = maxY

	-- contorno RADIAL justo: raio inicial = maior raio do núcleo (acima de y) no próprio setor; depois, todo ponto
	-- que ficar fora da aresta entre os dois vértices que o cercam empurra os dois para fora só o necessário.
	local K0 = alvo.k
	local passo = 2 * math.pi / K0
	local cacheRaios: { [number]: { number } } = {}
	local function raios(y: number): { number }
		local key = math.floor(y)
		local cached = cacheRaios[key]
		if cached then
			return cached
		end
		local acima: { Vector2 } = {}
		for _, p in pts do
			if p.Y >= y - 2 then
				table.insert(acima, Vector2.new(p.X - cx, p.Z - cz))
			end
		end
		local r = table.create(K0, 4)
		local function ang(v: Vector2): number
			return math.atan2(v.Y, v.X) % (2 * math.pi)
		end
		for _, v in acima do
			local i = math.floor(ang(v) / passo + 0.5) % K0 + 1
			r[i] = math.max(r[i], v.Magnitude)
		end
		for _ = 1, 30 do
			local mudou = false
			for _, v in acima do
				local i = math.floor(ang(v) / passo) % K0 + 1
				local j = i % K0 + 1
				local ti, tj = (i - 1) * passo, (j - 1) * passo
				local A = Vector2.new(math.cos(ti), math.sin(ti)) * r[i]
				local B = Vector2.new(math.cos(tj), math.sin(tj)) * r[j]
				local e = B - A
				local n = Vector2.new(e.Y, -e.X)
				if n:Dot(A) < 0 then
					n = -n
				end
				local lim = n:Dot(A)
				if lim > 0 and n:Dot(v) > lim * 1.0001 then
					local f = n:Dot(v) / lim
					r[i] *= f
					r[j] *= f
					mudou = true
				end
			end
			if not mudou then
				break
			end
		end
		cacheRaios[key] = r
		return r
	end
	local function vertice(theta: number, y: number, mult: number): Vector3
		local k = math.floor(theta / passo + 0.5) % K0 + 1
		local rr = raios(y)[k] * mult + MARGEM
		return center + Vector3.new(math.cos(theta) * rr, 0, math.sin(theta) * rr)
	end

	-- nada de fora (Coliseu, templos, tijolos, parque) pode ficar dentro da casca: testa o segmento a→b
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	local excl: { Instance } = { model, workspace.Terrain }
	for _, i in alvo.chao() do
		table.insert(excl, i)
	end
	for _, p in alvo.nucleo() do
		table.insert(excl, p)
	end
	local velho = S:FindFirstChild("Relevo")
	if velho then
		table.insert(excl, velho)
	end
	op.FilterDescendantsInstances = excl
	local function livre(a: Vector3, b: Vector3): boolean
		for i = 0, 6 do
			if #workspace:GetPartBoundsInRadius(a:Lerp(b, i / 6), 4, op) > 0 then
				return false
			end
		end
		return true
	end

	local rng = Random.new(alvo.seed)
	local K = alvo.k
	local fracs = { 0.32, 0.6, 0.84, 1 }
	local rings: { { Vector3 } } = {}
	-- anéis de cima: o anel j cobre tudo acima do anel ANTERIOR (nada entre dois anéis fura a casca); o último fica
	-- na altura do topo do núcleo, e o pico só arredonda por cima
	local anterior = g0
	for j, f in fracs do
		local ring: { Vector3 } = {}
		local level = if f >= 1 then top + 1 else g0 + (top - g0) * f
		for k = 0, K - 1 do
			local theta = (k / K) * math.pi * 2
			local v = vertice(theta, anterior, rng:NextNumber(1, 1.05))
			local jitter = if f >= 1 then rng:NextNumber(0, 2) else rng:NextNumber(-0.03, 0.03) * (top - g0)
			ring[k + 1] = Vector3.new(v.X, level + jitter, v.Z)
		end
		rings[j + 1] = ring
		anterior = level
	end
	-- pé: avança da 1ª faixa conforme a altura (encosta), assentado no chão, enterrado 1.5; recua até a encosta
	-- não tocar em nada (no mínimo, o contorno que ainda cobre o núcleo inteiro)
	local base: { Vector3 } = {}
	for k = 1, K do
		local up = rings[2][k]
		local theta = ((k - 1) / K) * math.pi * 2
		local upH = Vector3.new(up.X, 0, up.Z)
		local dir = (upH - center).Unit
		local rMin = (vertice(theta, minY, 1) - center).Magnitude
		local rUp = (upH - center).Magnitude
		local r = math.max(rMin, rUp + (up.Y - g0) * alvo.encosta * rng:NextNumber(0.85, 1.15))
		while r > rMin do
			local p = center + dir * r
			if livre(up, Vector3.new(p.X, (chaoEm(p.X, p.Z) or g0) + 2, p.Z)) then
				break
			end
			r = math.max(rMin, r - 3)
		end
		local p = center + dir * r
		local gy = chaoEm(p.X, p.Z) or g0
		base[k] = Vector3.new(p.X, gy - 1.5, p.Z)
	end
	rings[1] = base
	local apex = Vector3.new(cx + rng:NextNumber(-4, 4), top + alvo.pico, cz + rng:NextNumber(-4, 4))

	local function corFaixa(band: number): Color3
		if band == 1 then
			return alvo.pe
		elseif band == #rings then
			return alvo.topo
		end
		return alvo.rocha[math.clamp(band - 1, 1, #alvo.rocha)]
	end
	local pulados = 0
	local function face(a: Vector3, b: Vector3, c: Vector3, band: number)
		local mid = (a + b + c) / 3
		if dentroZona(mid, alvo.zonas) then
			return
		end
		local n = (b - a):Cross(c - a).Unit
		local inward = Vector3.new(cx, mid.Y, cz) - mid
		if n:Dot(inward) > 0 then
			n = -n
		end
		-- face que encostaria em algo de fora (jardim/templos/Coliseu colados no núcleo) não entra
		local ws = triangulo(model, a, b, c, -n, shade(corFaixa(band), n))
		for _, w in ws do
			if #workspace:GetPartsInPart(w, op) > 0 then
				for _, x in ws do
					x:Destroy()
				end
				pulados += 1
				return
			end
		end
	end
	for j = 1, #rings - 1 do
		local lo, hi = rings[j], rings[j + 1]
		for k = 1, K do
			local k2 = k % K + 1
			face(lo[k], lo[k2], hi[k2], j)
			face(lo[k], hi[k2], hi[k], j)
		end
	end
	local last = rings[#rings]
	for k = 1, K do
		face(last[k], last[k % K + 1], apex, #rings)
	end
	print(("[RelevoLowPoly] %s: %d peças, %d faces puladas (encostavam em algo)"):format(alvo.nome, #model:GetChildren(), pulados))
end

return function(destino: Instance?)
	local alvoPai = destino or S:FindFirstChild("RelevoLowPoly")
	if not alvoPai then
		local m = Instance.new("Model")
		m.Name = "RelevoLowPoly"
		m.Parent = S
		alvoPai = m
	end
	for _, alvo in ALVOS do
		montar(alvo, alvoPai :: Instance)
	end
end
