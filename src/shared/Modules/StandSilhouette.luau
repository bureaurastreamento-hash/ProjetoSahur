--!strict
--[[
	StandSilhouette (cliente)
	B4 (dono, 2026-09-24): o Stand NUNCA é um modelo — é uma SILHUETA de luz (peças neon translúcidas em forma
	de R6, maior que o jogador, com a cor do personagem) que flutua atrás/acima do ombro. Aparece na cutscene da
	ult (a partir do estouro) e pisca nas rajadas ORA/MUDA, com os braços socando.
	Só efeito local: cada cliente monta a própria silhueta em Workspace.CurrentCamera (não replica).
	API: Show(character, color, seconds, { punch = bool?, scale = number? }) · Hide(character)
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local StandSilhouette = {}

type Entry = { model: Model, parts: { [string]: BasePart }, conn: RBXScriptConnection, alive: boolean }
type Opts = { punch: boolean?, scale: number? }
local active: { [Model]: Entry } = {}

-- proporções R6 (studs) × escala; offsets relativos ao HumanoidRootPart do jogador
type Limb = { size: Vector3, off: Vector3 }
local LIMBS: { [string]: Limb } = {
	Head = { size = Vector3.new(1.3, 1.3, 1.3), off = Vector3.new(0, 2.25, 0) },
	Torso = { size = Vector3.new(2.2, 2.2, 1.1), off = Vector3.new(0, 0.5, 0) },
	RightArm = { size = Vector3.new(1, 2.2, 1), off = Vector3.new(1.65, 0.5, 0) },
	LeftArm = { size = Vector3.new(1, 2.2, 1), off = Vector3.new(-1.65, 0.5, 0) },
	RightLeg = { size = Vector3.new(1, 2.2, 1), off = Vector3.new(0.55, -1.7, 0) },
	LeftLeg = { size = Vector3.new(1, 2.2, 1), off = Vector3.new(-0.55, -1.7, 0) },
}
local ANCHOR = CFrame.new(-0.9, 1.6, 2.6) -- atrás, um pouco à esquerda e acima do ombro
local TRANSPARENCY = 0.55

local function build(color: Color3, scale: number): (Model, { [string]: BasePart })
	local model = Instance.new("Model")
	model.Name = "StandSilhouette"
	local parts: { [string]: BasePart } = {}
	for name, spec in LIMBS do
		local p = Instance.new("Part")
		p.Name = name
		p.Size = spec.size * scale
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = model
		parts[name] = p
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.6
	light.Range = 12
	light.Parent = parts.Torso
	return model, parts
end

function StandSilhouette.Hide(character: Model)
	local e = active[character]
	if not e then
		return
	end
	active[character] = nil
	e.alive = false
	e.conn:Disconnect()
	for _, p in e.parts do
		TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	end
	task.delay(0.4, function()
		e.model:Destroy()
	end)
end

--- Mostra a silhueta por `seconds` (renova se já estiver visível). punch = braços socando (rajadas).
function StandSilhouette.Show(character: Model, color: Color3, seconds: number, opts: Opts?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local o: Opts = opts or {}
	StandSilhouette.Hide(character)
	local scale = o.scale or 1.2
	local model, parts = build(color, scale)
	model.Parent = Workspace.CurrentCamera
	local t0 = os.clock()
	local punch = o.punch == true
	local e: Entry
	local conn = RunService.RenderStepped:Connect(function()
		if not root.Parent or not e.alive then
			return
		end
		local t = os.clock() - t0
		local bob = math.sin(t * 2.2) * 0.15
		local base = root.CFrame * ANCHOR * CFrame.new(0, bob, 0)
		for name, spec in LIMBS do
			local p = parts[name]
			local off = spec.off * scale
			local cf = base * CFrame.new(off)
			if punch and (name == "RightArm" or name == "LeftArm") then
				-- socos alternados muito rápidos (ORA ORA / MUDA MUDA): braço vai para a frente e volta
				local phase = if name == "RightArm" then 0 else math.pi
				local push = math.max(0, math.sin(t * 28 + phase)) * 1.8 * scale
				cf = base * CFrame.new(off + Vector3.new(0, 0.9 * scale, -push)) * CFrame.Angles(math.rad(-80), 0, 0)
			elseif name == "RightArm" or name == "LeftArm" then
				local sway = math.sin(t * 2.2 + (if name == "RightArm" then 0 else 1)) * 0.12
				cf = base * CFrame.new(off) * CFrame.Angles(math.rad(-25) + sway, 0, if name == "RightArm" then math.rad(12) else math.rad(-12))
			end
			p.CFrame = cf
		end
	end)
	e = { model = model, parts = parts, conn = conn, alive = true }
	active[character] = e
	for _, p in parts do
		TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = TRANSPARENCY }):Play()
	end
	task.delay(seconds, function()
		if active[character] == e then
			StandSilhouette.Hide(character)
		end
	end)
	character.AncestryChanged:Once(function()
		if active[character] == e then
			StandSilhouette.Hide(character)
		end
	end)
end

return StandSilhouette
