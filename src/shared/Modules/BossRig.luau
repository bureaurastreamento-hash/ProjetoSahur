--!strict
--[[
	BossRig
	Monta um rig animável a partir de um modelo 3D "por partes" (ex.: Tripo com ~70 MeshParts)
	organizado em GRUPOS por membro (Models/Folders chamados Tronco, Cabeça/Cabeca, BracoDir,
	BracoEsq, PernaDir, PernaEsq — ou qualquer nome). Funciona em cima do que o RigEdit fez:
	  • dentro de cada grupo, o "hub" é a parte que é Part0 de Motor6D e nunca Part1 (sem Motor6D:
	    a maior parte do grupo);
	  • o hub do TRONCO vira a raiz; cria Motor6D tronco -> hub de cada outro grupo (Neck,
	    Right Shoulder, Left Shoulder, Right Hip, Left Hip pelos nomes; senão o nome do grupo);
	  • partes sem junta/solda são soldadas (WeldConstraint) à parte com junta mais próxima DO MESMO
	    grupo (micro-detalhes seguem o membro);
	  • cria HumanoidRootPart (invisível, só ele colide) + Motor6D RootJoint -> tronco, e Humanoid
	    R15 (respeita HipHeight) se não existir;
	  • opcionalmente achata (partes como filhas diretas: a Hitbox do jogo só conta filhos diretos).
	Usado pelo BossService em runtime (num clone) e por tools/montar_rig_boss.luau (Command Bar,
	em cima do BossModel do ServerStorage, para animar no Animation Editor).
]]

local BossRig = {}

export type Options = {
	Flatten: boolean?, -- partes como filhas diretas do Model (runtime: sim; Studio: não, mantém os grupos)
	Height: number?, -- altura final (ScaleTo); nil = não escala
	FaceOffset: number?, -- graus para girar a frente do HRP
}

export type Report = { parts: number, motors: number, welded: number, groups: number, root: string, hipHeight: number }

local GROUP_JOINT_NAMES: { [string]: string } = {
	["cabeca"] = "Neck", ["cabeça"] = "Neck", ["head"] = "Neck",
	["bracodir"] = "Right Shoulder", ["bracoesq"] = "Left Shoulder",
	["pernadir"] = "Right Hip", ["pernaesq"] = "Left Hip",
}
local TORSO_NAMES: { [string]: boolean } = { tronco = true, torso = true, corpo = true, body = true }

local function norm(name: string): string
	return name:lower():gsub("[%s_%-]", "")
end

local function partsOf(container: Instance): { BasePart }
	local list = {}
	if container:IsA("BasePart") then
		table.insert(list, container)
	end
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function volume(p: BasePart): number
	return p.Size.X * p.Size.Y * p.Size.Z
end

--- Hub de um conjunto de partes: Part0 de Motor6D que nunca é Part1; senão a maior.
local function hubOf(parts: { BasePart }): BasePart?
	local set: { [BasePart]: boolean } = {}
	for _, p in parts do
		set[p] = true
	end
	local isChild: { [BasePart]: boolean } = {}
	local isParent: { [BasePart]: boolean } = {}
	for _, p in parts do
		for _, m in p:GetChildren() do
			if m:IsA("Motor6D") and m.Part0 and m.Part1 and set[m.Part0] and set[m.Part1] then
				isParent[m.Part0] = true
				isChild[m.Part1] = true
			end
		end
	end
	local best: BasePart? = nil
	for p in isParent do
		if not isChild[p] then
			if not best or volume(p) > volume(best) then
				best = p
			end
		end
	end
	if best then
		return best
	end
	for _, p in parts do
		if p.Name ~= "HumanoidRootPart" and (not best or volume(p) > volume(best)) then
			best = p
		end
	end
	return best
end

local function motor(name: string, part0: BasePart, part1: BasePart): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	m.C1 = CFrame.identity
	m.Parent = part0
	return m
end

function BossRig.Assemble(model: Model, options: Options?): Report
	local opts: Options = options or {}
	for _, d in model:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BodyMover") then
			d:Destroy()
		end
	end
	-- grupos = filhos diretos que são Model/Folder com partes dentro; partes soltas na raiz = grupo "raiz"
	type Group = { name: string, parts: { BasePart }, hub: BasePart? }
	local groups: { Group } = {}
	local loose: { BasePart } = {}
	for _, child in model:GetChildren() do
		if (child:IsA("Model") or child:IsA("Folder")) then
			local ps = partsOf(child)
			if #ps > 0 then
				table.insert(groups, { name = child.Name, parts = ps, hub = nil })
			end
		elseif child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			table.insert(loose, child)
		end
	end
	if #loose > 0 then
		table.insert(groups, { name = "Tronco", parts = loose, hub = nil })
	end
	local allParts: { BasePart } = {}
	for _, g in groups do
		g.hub = hubOf(g.parts)
		for _, p in g.parts do
			table.insert(allParts, p)
		end
	end
	if #allParts == 0 then
		error("[BossRig] modelo sem partes")
	end

	-- quem já está preso em algo (Motor6D/Weld/WeldConstraint como Part1)
	local jointed: { [BasePart]: boolean } = {}
	local motors = 0
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			motors += 1
			jointed[d.Part0] = true
			jointed[d.Part1] = true
		elseif (d:IsA("Weld") or d:IsA("WeldConstraint")) and d.Part0 and d.Part1 then
			jointed[d.Part1] = true
		end
	end

	-- tronco = grupo com nome de tronco; senão o grupo de maior volume
	local torso: Group? = nil
	for _, g in groups do
		if TORSO_NAMES[norm(g.name)] then
			torso = g
			break
		end
	end
	if not torso then
		local bestVol = 0
		for _, g in groups do
			local v = 0
			for _, p in g.parts do
				v += volume(p)
			end
			if v > bestVol then
				bestVol, torso = v, g
			end
		end
	end
	local torsoHub = (torso :: Group).hub :: BasePart

	-- juntas tronco -> membros (só se o hub do membro ainda não estiver preso a nada)
	for _, g in groups do
		if g ~= torso and g.hub and not jointed[g.hub] then
			local jointName = GROUP_JOINT_NAMES[norm(g.name)] or g.name
			motor(jointName, torsoHub, g.hub)
			motors += 1
			jointed[g.hub] = true
		end
	end
	jointed[torsoHub] = true

	-- partes soltas: solda na parte com junta mais próxima do MESMO grupo (senão do modelo todo)
	local welded = 0
	local function nearestJointed(part: BasePart, pool: { BasePart }): BasePart?
		local best, bestDist = nil, math.huge
		for _, cand in pool do
			if cand ~= part and jointed[cand] then
				local dist = (cand.Position - part.Position).Magnitude
				if dist < bestDist then
					best, bestDist = cand, dist
				end
			end
		end
		return best
	end
	for _, g in groups do
		for _, p in g.parts do
			if not jointed[p] then
				local anchor = nearestJointed(p, g.parts) or nearestJointed(p, allParts) or torsoHub
				local w = Instance.new("WeldConstraint")
				w.Name = "AutoWeld"
				w.Part0 = anchor
				w.Part1 = p
				w.Parent = p
				jointed[p] = true
				welded += 1
			end
		end
	end

	-- HRP + RootJoint + Humanoid
	local bcf, bbox = model:GetBoundingBox()
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		local r = Instance.new("Part")
		r.Name = "HumanoidRootPart"
		r.Transparency = 1
		r.CastShadow = false
		r.Size = Vector3.new(math.clamp(bbox.X * 0.3, 2, 8), math.clamp(bbox.Y * 0.5, 2, 30), math.clamp(bbox.Z * 0.3, 2, 8))
		r.CFrame = CFrame.new(Vector3.new(torsoHub.Position.X, bcf.Position.Y, torsoHub.Position.Z)) * CFrame.Angles(0, math.rad(opts.FaceOffset or 0), 0)
		r.Parent = model
		root = r
	end
	local rootPart = root :: BasePart
	local hasRootJoint = false
	for _, m in rootPart:GetChildren() do
		if m:IsA("Motor6D") then
			hasRootJoint = true
		end
	end
	if not hasRootJoint then
		motor("RootJoint", rootPart, torsoHub)
		motors += 1
	end
	-- física: nada ancorado; só o HRP colide; partes sem massa
	for _, p in allParts do
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = true
		p.Massless = true
	end
	rootPart.Anchored = false
	rootPart.CanCollide = true
	rootPart.CanQuery = true
	rootPart.Massless = false
	model.PrimaryPart = rootPart
	-- Head para nome/vida: o hub do grupo "Cabeça" ganha o nome Head se não houver
	if not model:FindFirstChild("Head", true) then
		for _, g in groups do
			if GROUP_JOINT_NAMES[norm(g.name)] == "Neck" and g.hub then
				g.hub.Name = "Head"
				break
			end
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.Parent = model

	-- achatar (runtime): partes como filhas diretas; grupos vazios somem
	if opts.Flatten then
		for _, p in allParts do
			p.Parent = model
		end
		for _, g in model:GetChildren() do
			if (g:IsA("Model") or g:IsA("Folder")) and #g:GetDescendants() == 0 then
				g:Destroy()
			end
		end
	end
	-- escala + HipHeight (pé do HRP -> pé do modelo)
	if opts.Height and bbox.Y > 0.1 then
		pcall(function()
			model:ScaleTo(model:GetScale() * (opts.Height :: number) / bbox.Y)
		end)
	end
	local cf2, size2 = model:GetBoundingBox()
	humanoid.HipHeight = math.max(0, (rootPart.Position.Y - rootPart.Size.Y / 2) - (cf2.Position.Y - size2.Y / 2))
	return { parts = #allParts, motors = motors, welded = welded, groups = #groups, root = torsoHub.Name, hipHeight = humanoid.HipHeight }
end

return BossRig
