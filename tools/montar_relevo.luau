--[[
	montar_relevo.luau — roda NO STUDIO (MCP run_code), modo edição. Ctrl+Z desfaz. Rodar de novo refaz do zero
	(só apaga o que ele mesmo criou em Workspace.Sahur.Relevo.<Alvo>).
	Pedido do dono (30/09): MontanhaSantuario e RochaTaberna "muito em blocos, sem detalhe, não parece um morro".
	Não apaga nem move os blocos originais (o núcleo): reveste por FORA com lascas de pedra —
	  - Encosta: raios de fora para dentro em volta do núcleo; em cada face acertada entra uma lasca inclinada para
	    dentro (mais deitada embaixo, mais em pé em cima → a silhueta vira encosta).
	  - Pé: pedregulhos grandes e deitados na base.
	  - Topo: raios de cima para baixo; pedras soltas, picos e tufos de grama.
	Toda lasca que encostar em qualquer coisa que não seja o núcleo/chão (Taberna, caverna `cav`, cachoeira,
	santuário, árvores, props) é PULADA, e as ZONAS listadas por alvo ficam sempre livres (porta, cachoeira).
	Material com textura (pedido do dono): Sandstone na montanha do deserto, Slate na rocha (igual à `cav`).
	O chão das ilhas continua liso (regra do chão); grama = SmoothPlastic nas cores do chão.
]]
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local S = workspace.Sahur
local ALVOS = {
	{
		nome = "MontanhaSantuario",
		nucleo = function()
			return S.ChaoIlhas.MontanhaSantuario:GetChildren()
		end,
		material = Enum.Material.Sandstone,
		paleta = { Color3.fromRGB(150, 90, 62), Color3.fromRGB(172, 106, 72), Color3.fromRGB(190, 122, 82), Color3.fromRGB(204, 138, 94) },
		nucleoCor = Color3.fromRGB(132, 80, 56), -- fendas entre as lascas parecem sombra
		grama = 0.4,
		picos = 0.2,
		saiaAltura = 0.25, -- talude até 25% da altura, 50° (pouco espaço até o Coliseu ao norte)
		saiaAngulo = 50,
		cobertura = 0.9, -- areia do deserto por cima
		corCobertura = { Color3.fromRGB(214, 156, 98), Color3.fromRGB(206, 148, 92) },
		zonas = { -- cachoeira + entrada do santuário (face sul)
			{ Vector3.new(872, -10, -700), Vector3.new(928, 130, -596) },
		},
		seed = 30091,
	},
	{
		nome = "RochaTaberna",
		nucleo = function()
			local l = {}
			for _, p in S.PecasArena.RochaTaberna:GetChildren() do
				if p:IsA("BasePart") and p.Material ~= Enum.Material.Grass then
					table.insert(l, p)
				end
			end
			return l
		end,
		material = Enum.Material.Slate,
		paleta = { Color3.fromRGB(98, 98, 104), Color3.fromRGB(112, 111, 116), Color3.fromRGB(124, 122, 126), Color3.fromRGB(134, 132, 134) },
		nucleoCor = Color3.fromRGB(88, 88, 94),
		grama = 0.8,
		picos = 0.08,
		saiaAltura = 0.3, -- talude verde até 30% da altura (morro), 48°
		saiaAngulo = 48,
		cobertura = 0.97,
		corCobertura = { Color3.fromRGB(98, 150, 78), Color3.fromRGB(90, 140, 72) },
		zonas = { -- porta da Taberna (face oeste, moldura da caverna)
			{ Vector3.new(225, -10, 30), Vector3.new(305, 45, 150) },
		},
		seed = 30092,
	},
}

local PASSO, PASSO_Y = 26, 24
local GRAMA = { Color3.fromRGB(98, 150, 78), Color3.fromRGB(84, 132, 66), Color3.fromRGB(110, 160, 84) }
local ARBUSTO = Color3.fromRGB(70, 120, 58)

local pasta = S:FindFirstChild("Relevo")
local rec = ChangeHistoryService:TryBeginRecording("Montar relevo")
if not pasta then
	pasta = Instance.new("Model")
	pasta.Name = "Relevo"
	pasta.Parent = S
end

local function dentroZona(p: Vector3, zonas)
	for _, z in zonas do
		if p.X > z[1].X and p.X < z[2].X and p.Y > z[1].Y and p.Y < z[2].Y and p.Z > z[1].Z and p.Z < z[2].Z then
			return true
		end
	end
	return false
end

for _, alvo in ALVOS do
	local R = Random.new(alvo.seed)
	local function rn(a, b)
		return a + R:NextNumber() * (b - a)
	end
	local velho = pasta:FindFirstChild(alvo.nome)
	if velho then
		velho:Destroy()
	end
	local dest = Instance.new("Folder")
	dest.Name = alvo.nome
	dest.Parent = pasta

	local nucleo = alvo.nucleo()
	local mn, mx = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, p in nucleo do
		local cf, sz = p.CFrame, p.Size / 2
		for _, c in { Vector3.new(1, 1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(1, -1, -1), Vector3.new(-1, -1, -1) } do
			local w = cf:PointToWorldSpace(sz * c)
			mn, mx = mn:Min(w), mx:Max(w)
		end
		if alvo.nucleoCor then
			p.Color = alvo.nucleoCor
		end
	end
	local chaoY, topoY = 0, mx.Y

	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = nucleo
	local ignorar = table.clone(nucleo)
	table.insert(ignorar, S.ChaoIlhas)
	table.insert(ignorar, pasta)
	table.insert(ignorar, workspace.Terrain)
	for _, p in S.PecasArena.RochaTaberna:GetChildren() do
		table.insert(ignorar, p) -- faixas de grama do pé da rocha
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = ignorar

	local function cor(f)
		local pal = alvo.paleta
		local x = math.clamp(f, 0, 1) * (#pal - 1)
		local i = math.floor(x)
		local c = pal[i + 1]:Lerp(pal[math.min(i + 2, #pal)], x - i)
		local j = rn(-0.03, 0.03)
		return Color3.new(math.clamp(c.R * (1 + j), 0, 1), math.clamp(c.G * (1 + j), 0, 1), math.clamp(c.B * (1 + j), 0, 1))
	end
	local feitas, puladas = 0, 0
	local function por(nome, cf: CFrame, tam: Vector3, c: Color3, material, forma, semTeste: boolean?): boolean
		if not semTeste then
			if dentroZona(cf.Position, alvo.zonas) then
				puladas += 1
				return false
			end
			if #workspace:GetPartBoundsInBox(cf, tam + Vector3.new(2, 2, 2), op) > 0 then
				puladas += 1
				return false
			end
		end
		local p = Instance.new("Part")
		p.Name = nome
		p.Anchored = true
		p.Size = tam
		p.CFrame = cf
		p.Color = c
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if forma then
			p.Shape = forma
		end
		p.Parent = dest
		feitas += 1
		return true
	end

	-- lados: raios horizontais de fora para dentro
	local lados = {
		{ "x", mx.Z + 40, Vector3.new(0, 0, -1), mn.X, mx.X },
		{ "x", mn.Z - 40, Vector3.new(0, 0, 1), mn.X, mx.X },
		{ "z", mx.X + 40, Vector3.new(-1, 0, 0), mn.Z, mx.Z },
		{ "z", mn.X - 40, Vector3.new(1, 0, 0), mn.Z, mx.Z },
	}
	local alcance = (mx - mn).Magnitude + 80
	local function raioLado(lado, t, h)
		local o = if lado[1] == "x" then Vector3.new(t, h, lado[2]) else Vector3.new(lado[2], h, t)
		return workspace:Raycast(o, lado[3] * alcance, rp)
	end
	for _, lado in lados do
		-- encosta
		for t = lado[4] - 8, lado[5] + 8, PASSO do
			for h = chaoY + (topoY - chaoY) * alvo.saiaAltura * 0.95, topoY - 4, PASSO_Y do -- abaixo disso é o talude
				local hit = raioLado(lado, t + rn(-4, 4), h + rn(-3, 3))
				if hit and math.abs(hit.Normal.Y) < 0.6 then
					local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
					local f = (hit.Position.Y - chaoY) / (topoY - chaoY)
					local W, H, T = rn(28, 44) * (1.15 - 0.3 * f), rn(20, 30), rn(8, 14)
					local tilt = (40 - 28 * f) + rn(-4, 4)
					local centro = hit.Position + n * (T / 2 - rn(1, 3))
					local cf = CFrame.lookAt(centro, centro - n)
						* CFrame.Angles(math.rad(-tilt), math.rad(rn(-6, 6)), math.rad(rn(-4, 4)))
					por("Encosta", cf, Vector3.new(W, H, T), cor(f), alvo.material)
				end
			end
		end
		-- saia (talude): cada rampa vai do CHÃO, a `dist` studs da parede, até a parede na altura `alt` — a superfície de
		-- cima fica exatamente na linha da encosta (nada pendurado no ar); cobertura por cima (grama/areia)
		for t = lado[4] - 10, lado[5] + 10, PASSO * 0.8 do
			local hTopo = chaoY + (topoY - chaoY) * alvo.saiaAltura * rn(0.85, 1.15)
			local hit = raioLado(lado, t + rn(-5, 5), hTopo)
			if hit and math.abs(hit.Normal.Y) < 0.6 then
				local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
				local dist = (hTopo - chaoY) / math.tan(math.rad(alvo.saiaAngulo + rn(-5, 5)))
				local B = Vector3.new(hit.Position.X, chaoY - 1.5, hit.Position.Z) + n * dist
				local Tp = hit.Position - n * 2
				local dir = (Tp - B).Unit
				local lado3 = Vector3.yAxis:Cross(n).Unit
				local nrm = lado3:Cross(dir).Unit
				local W, T, L = rn(30, 44), rn(10, 16), (Tp - B).Magnitude
				local meio = (B + Tp) / 2
				local cf = CFrame.fromMatrix(meio - nrm * (T / 2), lado3, nrm)
				if por("Saia", cf, Vector3.new(W, T, L), cor(0.15), alvo.material) and R:NextNumber() < alvo.cobertura then
					por("CoberturaSaia", CFrame.fromMatrix(meio + nrm * 0.55, lado3, nrm), Vector3.new(W * rn(0.9, 0.98), 1.2, L * rn(0.8, 0.95)),
						alvo.corCobertura[R:NextInteger(1, #alvo.corCobertura)], Enum.Material.SmoothPlastic, nil, true)
				end
			end
		end
		-- ombro: lascas bem deitadas na borda do topo (arredonda a quina de cima)
		for t = lado[4] - 8, lado[5] + 8, PASSO do
			local hit = raioLado(lado, t + rn(-4, 4), topoY - rn(6, 12))
			if hit and math.abs(hit.Normal.Y) < 0.6 then
				local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
				local W, H, T = rn(26, 40), rn(22, 30), rn(8, 12)
				local centro = hit.Position + n * (T / 2 - 2) + Vector3.new(0, 4, 0)
				local cf = CFrame.lookAt(centro, centro - n)
					* CFrame.Angles(math.rad(-rn(58, 70)), math.rad(rn(-6, 6)), math.rad(rn(-4, 4)))
				por("Ombro", cf, Vector3.new(W, H, T), cor(1), alvo.material)
			end
		end
	end

	-- topo: raios de cima para baixo
	for x = mn.X + 4, mx.X - 4, PASSO * 0.9 do
		for z = mn.Z + 4, mx.Z - 4, PASSO * 0.9 do
			local o = Vector3.new(x + rn(-5, 5), topoY + 60, z + rn(-5, 5))
			local hit = workspace:Raycast(o, Vector3.new(0, -(topoY + 80), 0), rp)
			if hit and hit.Normal.Y > 0.8 then
				local f = (hit.Position.Y - chaoY) / (topoY - chaoY)
				local roll = R:NextNumber()
				if roll < alvo.grama then
					-- tufo de grama (placa baixa) + arbusto
					local a, b = rn(20, 34), rn(20, 34)
					local cf = CFrame.new(hit.Position + Vector3.new(0, 0.4, 0))
						* CFrame.Angles(math.rad(rn(-4, 4)), math.rad(rn(0, 360)), math.rad(rn(-4, 4)))
					por("Grama", cf, Vector3.new(a, 1.4, b), GRAMA[R:NextInteger(1, #GRAMA)], Enum.Material.SmoothPlastic)
					if R:NextNumber() < 0.5 then
						local d = rn(6, 11)
						por("Arbusto", CFrame.new(hit.Position + Vector3.new(rn(-4, 4), d * 0.3, rn(-4, 4))), Vector3.one * d,
							ARBUSTO, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
					end
				elseif f > 0.9 and roll < alvo.grama + alvo.picos then
					-- pico: rocha alta levemente torta (quebra a linha reta do topo)
					local a, h = rn(14, 22), rn(14, 26)
					local cf = CFrame.new(hit.Position + Vector3.new(0, h / 2 - 3, 0))
						* CFrame.Angles(math.rad(rn(-9, 9)), math.rad(rn(0, 360)), math.rad(rn(-9, 9)))
					por("Pico", cf, Vector3.new(a, h, a * rn(0.7, 1.1)), cor(1), alvo.material)
				else
					-- pedra solta meio enterrada
					local sx, sy, sz = rn(12, 24), rn(3, 6), rn(12, 24)
					local cf = CFrame.new(hit.Position + Vector3.new(0, sy / 2 - 2.5, 0))
						* CFrame.Angles(math.rad(rn(-8, 8)), math.rad(rn(0, 360)), math.rad(rn(-8, 8)))
					por("Pedra", cf, Vector3.new(sx, sy, sz), cor(f), alvo.material)
				end
			end
		end
	end
	print(("[relevo] %s: %d peças novas, %d puladas (encostariam em algo)"):format(alvo.nome, feitas, puladas))
end
if rec then
	ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
