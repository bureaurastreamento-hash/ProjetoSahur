--!strict
--[[
	DestructionService (servidor)
	Cenário DESTRUTÍVEL estilo Jujutsu Shenanigans (dono, 2026-09-21): as construções de tijolo das duas áreas
	(Workspace.Sahur.ArenaExtras.Destructible, geradas por tools/arena_construcoes.py) e as ÁRVORES da arte
	(Workspace.Sahur.Arena.Trees / Corners.*.Trees) reagem aos ataques.
	  - Tijolo (peça com a tag "Destructible"): toda consulta de ataque da Hitbox (soco, habilidade, boss) que
	    cobre o tijolo chama Hitbox.DestructibleHook → o tijolo desancora, voa para longe de quem bateu, fica
	    DebrisSeconds solto (grupo de colisão Debris: não empurra jogador), some e VOLTA depois de
	    RespawnSeconds no lugar original. Teto de MaxLoose peças soltas ao mesmo tempo (as mais velhas somem).
	  - Árvore (Model da arte, tag "Destructible" nas peças): TOMBA para o lado oposto ao atacante (tween do
	    pivô, sem física — o mesh da arte não é alterado), some e volta em RespawnSeconds.
	  - Lugares úteis não entram: nada da Lojinha/Taberna/santuário é marcado.
	Clientes recebem NotifyDestruction (posições) para poeira/som (DestructionController).
	Servidor autoritativo: a Hitbox só chama o gancho no servidor.
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Hitbox = require(Modules:WaitForChild("Hitbox"))
local Log = require(Modules:WaitForChild("Log"))
local Remotes = require(Modules:WaitForChild("RemoteEvents"))

local DestructionService = {}

DestructionService.Tag = "Destructible"
DestructionService.CollisionGroup = "Debris"
DestructionService.DebrisSeconds = 4.5 -- tijolo solto some depois disso
DestructionService.RespawnSeconds = 50 -- volta ao lugar
DestructionService.MaxLoose = 60 -- teto de peças soltas ao mesmo tempo
DestructionService.MaxPerHit = 22 -- teto de tijolos por golpe (o resto do volume fica)
DestructionService.LaunchSpeed = { 26, 44 }
DestructionService.LaunchUp = { 14, 30 }
DestructionService.TreeFallSeconds = 0.9
DestructionService.TreeDownSeconds = 10 -- árvore caída fica isso antes de sumir/voltar
DestructionService.SkipNames = { ZigCore = true, ZigGold = true }

type BrickInfo = { cframe: CFrame, parent: Instance, loose: boolean, looseSince: number }
type TreeInfo = { center: Vector3, base: Vector3, cframes: { [BasePart]: CFrame }, parent: Instance, down: boolean }

local bricks: { [BasePart]: BrickInfo } = {}
local trees: { [Model]: TreeInfo } = {}
local partToTree: { [BasePart]: Model } = {}
local loose: { BasePart } = {} -- ordem de soltura (para o teto)
local notify: RemoteEvent? = nil

local function rnd(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

-- ---------------------------------------------------------------------------
-- Tijolos
-- ---------------------------------------------------------------------------

local function removeLoose(part: BasePart)
	local idx = table.find(loose, part)
	if idx then
		table.remove(loose, idx)
	end
end

--- Tijolo solto some (fade) e entra na fila de voltar.
local function retire(part: BasePart, info: BrickInfo)
	removeLoose(part)
	if not part.Parent then
		return
	end
	local tween = TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Transparency = 1 })
	tween:Play()
	tween.Completed:Once(function()
		if info.loose then
			part.Parent = nil
		end
	end)
end

local function restore(part: BasePart, info: BrickInfo)
	if not info.loose then
		return
	end
	info.loose = false
	part.Anchored = true
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
	part.CollisionGroup = "Default"
	part.CanCollide = true
	part.CFrame = info.cframe
	part.Transparency = 1
	part.Parent = info.parent
	TweenService:Create(part, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Transparency = 0 }):Play()
end

local function breakBrick(part: BasePart, info: BrickInfo, from: Vector3?)
	if info.loose then
		return
	end
	info.loose = true
	info.looseSince = os.clock()
	local dir = if from then (part.Position - from) else Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = if dir.Magnitude > 0.05 then dir.Unit else Vector3.new(0, 0, -1)
	part.CollisionGroup = DestructionService.CollisionGroup
	part.Anchored = false
	part.CanCollide = true
	pcall(part.SetNetworkOwner, part, nil)
	part.AssemblyLinearVelocity = dir * rnd(DestructionService.LaunchSpeed) + Vector3.new(0, rnd(DestructionService.LaunchUp), 0)
	part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 18
	table.insert(loose, part)
	-- teto de peças soltas: as mais antigas somem já
	while #loose > DestructionService.MaxLoose do
		local old = table.remove(loose, 1) :: BasePart
		local oi = bricks[old]
		if oi then
			retire(old, oi)
		end
	end
	task.delay(DestructionService.DebrisSeconds, function()
		if info.loose and info.looseSince > 0 then
			retire(part, info)
		end
	end)
	task.delay(DestructionService.RespawnSeconds, function()
		restore(part, info)
	end)
end

-- ---------------------------------------------------------------------------
-- Árvores (tombam)
-- ---------------------------------------------------------------------------

local function setTreeTransparency(info: TreeInfo, value: number, seconds: number)
	for part in info.cframes do
		if seconds > 0 then
			TweenService:Create(part, TweenInfo.new(seconds), { Transparency = value }):Play()
		else
			part.Transparency = value
		end
	end
end

local function toppleTree(model: Model, info: TreeInfo, from: Vector3?)
	if info.down then
		return
	end
	info.down = true
	local dir = if from then (info.center - from) else Vector3.new(1, 0, 0)
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = if dir.Magnitude > 0.05 then dir.Unit else Vector3.new(1, 0, 0)
	-- gira em volta da base: eixo horizontal perpendicular à direção da queda (o pivô da arte não é
	-- confiável, então cada peça gira a partir do CFrame original em volta do pé da árvore)
	local axis = dir:Cross(Vector3.yAxis).Unit
	local base = info.base
	local startAt = os.clock()
	local dur = DestructionService.TreeFallSeconds
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local a = math.clamp((os.clock() - startAt) / dur, 0, 1)
		local ang = math.rad(84) * (a * a) -- acelera como uma queda
		local rot = CFrame.new(base) * CFrame.fromAxisAngle(axis, -ang) * CFrame.new(-base)
		for part, cf in info.cframes do
			part.CFrame = rot * cf
		end
		if a >= 1 or not info.down then
			conn:Disconnect()
		end
	end)
	task.delay(DestructionService.TreeDownSeconds, function()
		if not info.down then
			return
		end
		setTreeTransparency(info, 1, 0.8)
		task.delay(0.9, function()
			if info.down then
				model.Parent = nil
			end
		end)
	end)
	task.delay(DestructionService.RespawnSeconds, function()
		info.down = false
		for part, cf in info.cframes do
			part.CFrame = cf
		end
		setTreeTransparency(info, 1, 0)
		model.Parent = info.parent
		setTreeTransparency(info, 0, 0.8)
	end)
end

-- ---------------------------------------------------------------------------
-- Gancho da Hitbox
-- ---------------------------------------------------------------------------

local function onHit(parts: { BasePart }, attacker: Model)
	local root = attacker and attacker:FindFirstChild("HumanoidRootPart")
	local from = if root and root:IsA("BasePart") then root.Position else nil
	local positions: { Vector3 } = {}
	local treePositions: { Vector3 } = {}
	local n = 0
	for _, part in parts do
		local bi = bricks[part]
		if bi then
			if not bi.loose and n < DestructionService.MaxPerHit then
				n += 1
				table.insert(positions, part.Position)
				breakBrick(part, bi, from)
			end
			continue
		end
		local tree = partToTree[part]
		local ti = tree and trees[tree]
		if tree and ti and not ti.down then
			table.insert(treePositions, ti.base)
			toppleTree(tree, ti, from)
		end
	end
	if notify then
		if #positions > 0 then
			notify:FireAllClients(attacker, positions, "brick")
		end
		if #treePositions > 0 then
			notify:FireAllClients(attacker, treePositions, "tree")
		end
	end
end

-- ---------------------------------------------------------------------------
-- Registro
-- ---------------------------------------------------------------------------

local function registerBrick(part: BasePart)
	if bricks[part] or DestructionService.SkipNames[part.Name] or not part.Anchored then
		return
	end
	bricks[part] = { cframe = part.CFrame, parent = part.Parent :: Instance, loose = false, looseSince = 0 }
	CollectionService:AddTag(part, DestructionService.Tag)
end

local function registerTree(model: Model)
	if trees[model] then
		return
	end
	local cframes: { [BasePart]: CFrame } = {}
	local anyPart = false
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			anyPart = true
			partToTree[d] = model
			cframes[d] = d.CFrame
			d.CanQuery = true -- os meshes da arte vêm com CanQuery false: a Hitbox não os acharia
			CollectionService:AddTag(d, DestructionService.Tag)
		end
	end
	if anyPart then
		local cf, size = model:GetBoundingBox()
		trees[model] = { center = cf.Position, base = cf.Position - Vector3.new(0, size.Y / 2, 0), cframes = cframes, parent = model.Parent :: Instance, down = false }
	end
end

--- Quantos tijolos/árvores estão registrados (painel DEV / testes).
function DestructionService.Count(): (number, number)
	local b, t = 0, 0
	for _ in bricks do
		b += 1
	end
	for _ in trees do
		t += 1
	end
	return b, t
end

--- Solta tudo de volta (DEV): restaura o cenário na hora.
function DestructionService.RestoreAll()
	for part, info in bricks do
		restore(part, info)
	end
	for model, info in trees do
		if info.down then
			info.down = false
			for part, cf in info.cframes do
				part.CFrame = cf
			end
			setTreeTransparency(info, 0, 0)
			model.Parent = info.parent
		end
	end
end

function DestructionService.Init()
	notify = Remotes.GetEvent(Remotes.Events.NotifyDestruction)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(DestructionService.CollisionGroup)
	end)
	pcall(function()
		-- entulho não empurra jogador nem outro entulho; bate só no cenário (Default)
		PhysicsService:CollisionGroupSetCollidable(DestructionService.CollisionGroup, DestructionService.CollisionGroup, false)
		PhysicsService:CollisionGroupSetCollidable(DestructionService.CollisionGroup, "Grabbed", false)
	end)
end

function DestructionService.Start()
	local sahur = Workspace:FindFirstChild("Sahur")
	if not sahur then
		return
	end
	local extras = sahur:FindFirstChild("ArenaExtras")
	local folder = extras and extras:FindFirstChild("Destructible")
	if folder then
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") then
				registerBrick(d)
			end
		end
	end
	local arena = sahur:FindFirstChild("Arena")
	if arena then
		for _, d in arena:GetDescendants() do
			-- árvores da arte: Trees.Model.<Oak|Pine> e Corners.Model.Trees.<Oak|Pine>
			if d:IsA("Model") and (d.Name == "Oak" or d.Name == "Pine") then
				registerTree(d)
			end
		end
	end
	-- Os personagens ficam no grupo Default, então o entulho ainda bate neles (como no JJS). Entulho x entulho
	-- e entulho x agarrado não colidem (Init).
	Hitbox.DestructibleHook = onHit
	local b, t = DestructionService.Count()
	Log.debug(("[DestructionService] %d tijolos, %d árvores destrutíveis"):format(b, t))
end

return DestructionService
