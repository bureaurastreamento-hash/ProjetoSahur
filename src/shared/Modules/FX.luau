--!strict
--[[
	FX (cliente)
	Helpers de feedback com limites de performance:
	  - Highlight: 1 instância por personagem, reaproveitada (Roblox limita ~31 ativas).
	  - VFX: clones de Assets.VFX com teto de instâncias simultâneas e de partículas
	    por emissão; destruídos automaticamente.
	  - Som: clones de Assets.Sounds tocados na posição (3D) ou na UI, com teto simultâneo.
	Todos os assets são localizados por nome via Assets.luau; ausência = ignora.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Assets = require(script.Parent:WaitForChild("Assets"))
local Log = require(script.Parent:WaitForChild("Log"))
local VFXLibrary = require(script.Parent:WaitForChild("VFXLibrary"))
local CharacterDefs = require(script.Parent:WaitForChild("CharacterDefs"))

local FX = {}

FX.MaxActiveVFX = 12
FX.MaxEmitPerEmitter = 30
FX.MaxActiveSounds = 16
FX.VFXLifetime = 2

local activeVFX = 0
local activeSounds = 0
local highlights: { [Model]: Highlight } = {}
local highlightToken: { [Model]: number } = {}

-- ---------------------------------------------------------------------------
-- Highlight
-- ---------------------------------------------------------------------------

local function getHighlight(character: Model): Highlight
	local existing = highlights[character]
	if existing and existing.Parent == character then
		return existing
	end
	local hl = Instance.new("Highlight")
	hl.Name = "FXHighlight"
	hl.Enabled = false
	hl.Parent = character
	highlights[character] = hl
	character.Destroying:Once(function()
		highlights[character] = nil
		highlightToken[character] = nil
	end)
	return hl
end

--- Pisca o personagem com preenchimento colorido por `duration` segundos.
function FX.Flash(character: Model, color: Color3, duration: number)
	local hl = getHighlight(character)
	hl.FillColor = color
	hl.FillTransparency = 0.4
	hl.OutlineTransparency = 1
	hl.Enabled = true
	local token = (highlightToken[character] or 0) + 1
	highlightToken[character] = token
	task.delay(duration, function()
		if highlightToken[character] == token and hl.Parent then
			hl.Enabled = false
		end
	end)
end

--- Contorno persistente (ex.: bloqueando). `nil` desliga.
function FX.SetOutline(character: Model, color: Color3?)
	local hl = getHighlight(character)
	if color then
		hl.FillTransparency = 1
		hl.OutlineColor = color
		hl.OutlineTransparency = 0
		hl.Enabled = true
	else
		hl.Enabled = false
	end
end

--- Aura persistente (partículas no HRP; ex.: kill streak, cosmético, cena). `nil` desliga.
--- `name` separa auras diferentes no mesmo boneco (padrão "Aura").
function FX.SetAura(character: Model, color: Color3?, name: string?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local auraName = name or "Aura"
	local existing = root:FindFirstChild(auraName)
	if not color then
		if existing then
			existing:Destroy()
		end
		return
	end
	local emitter = (existing :: ParticleEmitter?) or Instance.new("ParticleEmitter")
	emitter.Name = auraName
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.Rate = 25
	emitter.Speed = NumberRange.new(3, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 6, 0)
	emitter.Parent = root
end

-- ---------------------------------------------------------------------------
-- Animação
-- ---------------------------------------------------------------------------

local tracks: { [Model]: { [string]: AnimationTrack } } = {}

local r15Animations: { [Animation]: Animation } = {}

local lengthWarned: { [string]: boolean } = {}

local function trackFor(character: Model, folder: string, name: string): AnimationTrack?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not animator then
		return nil
	end
	local byName = tracks[character]
	if not byName then
		byName = {}
		tracks[character] = byName
		character.Destroying:Once(function()
			tracks[character] = nil
		end)
	end
	local key = folder .. "/" .. name
	local track = byName[key]
	if track then
		return track
	end
	local anim = Assets.GetAnimation(folder, name)
	if not anim then
		return nil
	end
	-- Rig R15 com id alternativo (atributo R15Id): animação R6 não toca em R15 e vice-versa
	local r15Id = anim:GetAttribute("R15Id")
	if humanoid.RigType == Enum.HumanoidRigType.R15 and typeof(r15Id) == "string" and r15Id ~= "" then
		local alt = r15Animations[anim]
		if not alt then
			local created = Instance.new("Animation")
			created.Name = anim.Name .. "_R15"
			created.AnimationId = r15Id
			r15Animations[anim] = created
			alt = created
		end
		anim = alt
	end
	track = animator:LoadAnimation(anim)
	byName[key] = track
	return track
end

--- Toca Assets.Animations.<folder>.<name>. Retorna a track (ou nil se não existir).
function FX.PlayAnimation(character: Model, folder: string, name: string, looped: boolean?, priority: Enum.AnimationPriority?): AnimationTrack?
	folder = Assets.ResolveFolder("Animations", folder, name, character) -- versão do personagem, se houver
	local track = trackFor(character, folder, name)
	if not track then
		return nil
	end
	track.Looped = looped == true
	track.Priority = priority or Enum.AnimationPriority.Action
	track:Play(0.1)
	-- Length 0 depois de carregar = o asset não veio (id errado ou publicado fora do criador do place:
	-- jogo de grupo só carrega animação do grupo). Avisa uma vez por animação, só em Studio.
	local key = folder .. "/" .. name
	if not lengthWarned[key] then
		lengthWarned[key] = true
		task.delay(2, function()
			if track.Length == 0 then
				local anim = track.Animation
				Log.debug(("[FX] animação %s (%s) carregou com duração 0: id errado ou sem permissão (jogo de grupo? place certo?)"):format(
					key, anim and anim.AnimationId or "?"))
			end
		end)
	end
	return track
end

function FX.StopAnimation(character: Model, folder: string, name: string)
	folder = Assets.ResolveFolder("Animations", folder, name, character)
	local byName = tracks[character]
	local track = byName and byName[folder .. "/" .. name]
	if track and track.IsPlaying then
		track:Stop(0.15)
	end
end

-- ---------------------------------------------------------------------------
-- VFX
-- ---------------------------------------------------------------------------

--- Instancia Assets.VFX.<folder>.<name> no personagem (HRP). Sem fallback para Placeholder
--- quando `exact` = true.
--- `at` (opcional) posiciona o efeito num ponto do mundo em vez do personagem
--- (projéteis, áreas à distância); Attachments/emissores soltos ganham uma parte invisível.
---
--- Atributos entendidos (ver tools/gerar_vfx.py):
---   Model:           OriginRelative (Position das Parts = offset do spawn), Lifetime (s),
---                    Follow (emissores/luzes vão para o HRP e acompanham o personagem)
---   BasePart:        TweenScale + TweenTime (cresce e some)
---   ParticleEmitter: EmitCount (rajada única), EmitDuration (fica ligado N s)
---   PointLight:      FadeTime (apaga em N s)
function FX.SpawnVFX(character: Model, folder: string, name: string, exact: boolean?, at: Vector3?)
	-- 1) composição por código (VFXLibrary): tem prioridade sobre packs/alias
	local composed = VFXLibrary.Get(folder, name)
	if composed then
		FX.PlayComposed(character, composed, at)
		return
	end
	local template = if exact then (if Assets.HasVFX(folder, name) then Assets.GetVFX(folder, name) else nil) else Assets.GetVFX(folder, name)
	if template then
		FX.SpawnVFXTemplate(character, template, at)
	end
end

-- ---------------------------------------------------------------------------
-- Composições (VFXLibrary): meshes por SpecialMesh + rajadas de partículas + luz, tudo por código.
-- ---------------------------------------------------------------------------

local EASING: { [string]: Enum.EasingStyle } = {
	Quad = Enum.EasingStyle.Quad,
	Quart = Enum.EasingStyle.Quart,
	Sine = Enum.EasingStyle.Sine,
	Back = Enum.EasingStyle.Back,
	Linear = Enum.EasingStyle.Linear,
	Exponential = Enum.EasingStyle.Exponential,
}

--- Cor do personagem (CharacterDefs.Color) para "$primary"/"$secondary".
local function characterColor(character: Model): Color3
	local id = character:GetAttribute("CharacterId")
	if typeof(id) ~= "string" then
		local player = Players:GetPlayerFromCharacter(character)
		id = player and player:GetAttribute("CharacterId")
	end
	local def = if typeof(id) == "string" then CharacterDefs.Get(id) else nil
	return (def and def.Color) or Color3.fromRGB(255, 255, 255)
end

local function resolveColor(value: any, primary: Color3): Color3
	if typeof(value) == "Color3" then
		return value
	end
	if value == "$secondary" then
		local h, sat, v = primary:ToHSV()
		return Color3.fromHSV(h, sat * 0.5, math.min(1, v * 1.15))
	end
	return primary
end

local function numberSeq(value: any, fallbackA: number, fallbackB: number): NumberSequence
	if typeof(value) == "number" then
		return NumberSequence.new(value)
	elseif typeof(value) == "table" then
		if typeof(value[1]) == "table" then
			local kps = {}
			for _, kp in value do
				table.insert(kps, NumberSequenceKeypoint.new(kp[1], kp[2], kp[3] or 0))
			end
			return NumberSequence.new(kps)
		end
		return NumberSequence.new(value[1], value[2])
	end
	return NumberSequence.new(fallbackA, fallbackB)
end

local function numberRange(value: any, fallbackA: number, fallbackB: number?): NumberRange
	if typeof(value) == "number" then
		return NumberRange.new(value)
	elseif typeof(value) == "table" then
		return NumberRange.new(math.min(value[1], value[2]), math.max(value[1], value[2]))
	end
	return NumberRange.new(fallbackA, fallbackB or fallbackA)
end

local function makeHolder(cf: CFrame, size: Vector3?): Part
	local holder = Instance.new("Part")
	holder.Name = "VFX"
	holder.Size = size or Vector3.one
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.CFrame = cf
	return holder
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true

--- Encosta o CFrame no chão (raycast até 14 studs para baixo), mantendo o giro.
local function snapToGround(cf: CFrame, exclude: { Instance }): CFrame
	groundParams.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(cf.Position + Vector3.new(0, 2, 0), Vector3.new(0, -16, 0), groundParams)
	if hit then
		return CFrame.new(hit.Position + Vector3.new(0, 0.12, 0)) * (cf - cf.Position)
	end
	return cf
end

local function directionFor(name: any): Enum.NormalId
	if name == "up" then
		return Enum.NormalId.Top
	elseif name == "down" then
		return Enum.NormalId.Bottom
	elseif name == "back" then
		return Enum.NormalId.Back
	elseif name == "forward" then
		return Enum.NormalId.Front
	end
	return Enum.NormalId.Top
end

local ORIENT: { [string]: Enum.ParticleOrientation } = {
	FacingCamera = Enum.ParticleOrientation.FacingCamera,
	FacingCameraWorldUp = Enum.ParticleOrientation.FacingCameraWorldUp,
	VelocityParallel = Enum.ParticleOrientation.VelocityParallel,
	VelocityPerpendicular = Enum.ParticleOrientation.VelocityPerpendicular,
}

--- Toca uma composição da VFXLibrary em `character` (ou no ponto `at`). Cores "$primary" = cor do personagem.
function FX.PlayComposed(character: Model, effect: VFXLibrary.Effect, at: Vector3?)
	if activeVFX >= FX.MaxActiveVFX then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root and not at then
		return
	end
	local primary = characterColor(character)
	-- origem: posição + só o giro horizontal (efeito não tomba com o ragdoll)
	local origin: CFrame
	if at then
		local look = if root then Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) else Vector3.new(0, 0, -1)
		origin = CFrame.lookAt(at, at + (if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)))
	else
		local r = root :: BasePart
		local look = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
		origin = CFrame.lookAt(r.Position, r.Position + (if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)))
	end
	local lifetime = effect.lifetime or FX.VFXLifetime
	local trash: { Instance } = {}
	local spinning: { { part: Part, spin: Vector3 } } = {}
	local exclude: { Instance } = { character }
	local camera = Workspace.CurrentCamera

	local function place(layer: any, size: Vector3?): (Part, CFrame)
		local cf = origin
		local off = layer.offset
		if typeof(off) == "CFrame" then
			cf = cf * off
		elseif typeof(off) == "Vector3" then
			cf = cf * CFrame.new(off)
		end
		if layer.ground then
			cf = snapToGround(cf, exclude)
		end
		if layer.camera and camera then
			cf = CFrame.lookAt(cf.Position, camera.CFrame.Position)
		end
		local holder = makeHolder(cf, size)
		holder.Parent = Workspace
		table.insert(trash, holder)
		return holder, cf
	end

	local function runLayer(layer: any)
		local kind = layer.kind
		if kind == "mesh" then
			local def = VFXLibrary.Meshes[layer.mesh]
			if not def then
				return
			end
			local holder = place(layer)
			holder.Transparency = layer.tr0 or 0.15
			holder.Color = resolveColor(layer.color, primary)
			holder.Material = layer.material or Enum.Material.Neon
			if layer.follow and root then
				holder.Anchored = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = holder
				weld.Parent = holder
				holder.Massless = true
			end
			local sm = Instance.new("SpecialMesh")
			sm.MeshType = Enum.MeshType.FileMesh
			sm.MeshId = "rbxassetid://" .. def.id
			local native = math.max(def.size.X, def.size.Y, def.size.Z, 0.01)
			sm.Scale = Vector3.one * (layer.size0 / native)
			sm.Parent = holder
			local info = TweenInfo.new(layer.t or 0.3, EASING[layer.ease or "Quart"] or Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			TweenService:Create(sm, info, { Scale = Vector3.one * (layer.size1 / native) }):Play()
			TweenService:Create(holder, info, { Transparency = layer.tr1 or 1 }):Play()
			if typeof(layer.spin) == "Vector3" then
				table.insert(spinning, { part = holder, spin = layer.spin })
			end
			task.delay((layer.t or 0.3) + 0.05, function()
				if (layer.tr1 or 1) >= 1 then
					holder:Destroy()
				end
			end)
		elseif kind == "emit" then
			local texId = VFXLibrary.Textures[layer.texture]
			if not texId then
				return
			end
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "VFX_" .. tostring(layer.texture)
			emitter.Texture = "rbxassetid://" .. texId
			if typeof(layer.colorSeq) == "table" then
				local kps = {}
				for _, kp in layer.colorSeq do
					table.insert(kps, ColorSequenceKeypoint.new(kp[1], resolveColor(kp[2], primary)))
				end
				emitter.Color = ColorSequence.new(kps)
			else
				emitter.Color = ColorSequence.new(resolveColor(layer.color, primary))
			end
			emitter.Size = numberSeq(layer.sizeSeq or layer.size, 1, 1)
			emitter.Transparency = numberSeq(layer.trSeq, 0, 1)
			if not layer.trSeq then
				emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.25), NumberSequenceKeypoint.new(1, 1) })
			end
			emitter.Lifetime = numberRange(layer.life, 0.4, 0.7)
			emitter.Speed = numberRange(layer.speed, 8, 16)
			local spread = layer.spread
			emitter.SpreadAngle = if typeof(spread) == "table" then Vector2.new(spread[1], spread[2]) else Vector2.new(180, 180)
			emitter.Rotation = numberRange(layer.rot, -180, 180)
			emitter.RotSpeed = numberRange(layer.rotSpeed, 0, 0)
			emitter.LightEmission = layer.light or 1
			emitter.LightInfluence = if layer.light and layer.light < 0.5 then 1 else 0
			emitter.Acceleration = layer.accel or Vector3.zero
			emitter.Drag = layer.drag or 0
			emitter.Orientation = ORIENT[layer.orient or "FacingCamera"] or Enum.ParticleOrientation.FacingCamera
			emitter.ZOffset = layer.zOffset or 0
			emitter.Brightness = layer.brightness or 1.5
			emitter.LockedToPart = layer.lockedToPart == true
			emitter.Shape = if layer.shape == "Sphere" then Enum.ParticleEmitterShape.Sphere
				elseif layer.shape == "Disc" then Enum.ParticleEmitterShape.Disc
				elseif layer.shape == "Cylinder" then Enum.ParticleEmitterShape.Cylinder
				else Enum.ParticleEmitterShape.Box
			emitter.ShapeStyle = if layer.shapeStyle == "Surface" then Enum.ParticleEmitterShapeStyle.Surface else Enum.ParticleEmitterShapeStyle.Volume
			emitter.ShapeInOut = if layer.shapeInOut == "Inward" then Enum.ParticleEmitterShapeInOut.Inward
				elseif layer.shapeInOut == "InAndOut" then Enum.ParticleEmitterShapeInOut.InAndOut
				else Enum.ParticleEmitterShapeInOut.Outward
			emitter.EmissionDirection = directionFor(layer.direction)
			if typeof(layer.flipbook) == "table" then
				local fb = layer.flipbook
				emitter.FlipbookLayout = (Enum.ParticleFlipbookLayout :: any)[fb.layout] or Enum.ParticleFlipbookLayout.None
				emitter.FlipbookMode = (Enum.ParticleFlipbookMode :: any)[fb.mode] or Enum.ParticleFlipbookMode.OneShot
				emitter.FlipbookFramerate = NumberRange.new(fb.fps or 16, fb.fps2 or fb.fps or 16)
				emitter.FlipbookStartRandom = fb.random == true
			end
			emitter.Enabled = false
			emitter.Rate = layer.rate or 0
			if layer.follow and root then
				local att = Instance.new("Attachment")
				att.Name = "VFXAttachment"
				local off = layer.offset
				att.CFrame = if typeof(off) == "Vector3" then CFrame.new(off) elseif typeof(off) == "CFrame" then off else CFrame.new()
				att.Parent = root
				emitter.Parent = att
				table.insert(trash, att)
			else
				local holder = place(layer, layer.shapeSize)
				emitter.Parent = holder
			end
			local count = layer.count or 0
			if typeof(layer.duration) == "number" then
				emitter.Rate = math.min(layer.rate or 20, 60)
				emitter.Enabled = true
				task.delay(layer.duration, function()
					emitter.Enabled = false
				end)
			end
			if count > 0 then
				emitter:Emit(math.min(count, FX.MaxEmitPerEmitter * 2))
			end
		elseif kind == "light" then
			local lightObj = Instance.new("PointLight")
			lightObj.Color = resolveColor(layer.color, primary)
			lightObj.Range = layer.range or 12
			lightObj.Shadows = false
			local target = layer.brightness or 3
			if layer.fadeIn then
				lightObj.Brightness = 0
				TweenService:Create(lightObj, TweenInfo.new(layer.t or 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Brightness = target }):Play()
			else
				lightObj.Brightness = target
				TweenService:Create(lightObj, TweenInfo.new(layer.t or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Brightness = 0 }):Play()
			end
			if root and not layer.offset then
				lightObj.Parent = root
				table.insert(trash, lightObj)
			else
				local holder = place(layer)
				lightObj.Parent = holder
			end
		elseif kind == "pack" then
			local template = Assets.GetVFXPath(layer.path)
			if template then
				FX.SpawnVFXTemplate(character, template, at)
			end
		elseif kind == "sound" then
			FX.PlaySoundAt(character, layer.folder or "Shared", layer.name)
		end
	end

	for _, layer in effect.layers do
		local delay = layer.delay
		if typeof(delay) == "number" and delay > 0 then
			task.delay(delay, runLayer, layer)
		else
			runLayer(layer)
		end
	end

	local spinConn: RBXScriptConnection? = nil
	if #spinning > 0 then
		spinConn = RunService.Heartbeat:Connect(function(dt)
			for _, s in spinning do
				if s.part.Parent then
					s.part.CFrame = s.part.CFrame * CFrame.Angles(math.rad(s.spin.X * dt), math.rad(s.spin.Y * dt), math.rad(s.spin.Z * dt))
				end
			end
		end)
	end
	activeVFX += 1
	task.delay(lifetime, function()
		activeVFX -= 1
		if spinConn then
			spinConn:Disconnect()
		end
		for _, inst in trash do
			inst:Destroy()
		end
	end)
end

--- Instancia um template qualquer (usado pelo preview de VFX do menu Dev).
function FX.SpawnVFXTemplate(character: Model, template: Instance, at: Vector3?)
	if activeVFX >= FX.MaxActiveVFX then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not template or (not root and not at) then
		return
	end
	local cframe = if at then CFrame.new(at) else (root :: BasePart).CFrame
	local lifetimeAttr = template:GetAttribute("Lifetime")
	local lifetime = if typeof(lifetimeAttr) == "number" then lifetimeAttr else FX.VFXLifetime
	local anchor: BasePart? = if at then nil else root
	if at then
		local holder = Instance.new("Part")
		holder.Name = "VFXAnchor"
		holder.Size = Vector3.one
		holder.Transparency = 1
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.CastShadow = false
		holder.CFrame = cframe
		holder.Parent = Workspace
		anchor = holder
		task.delay(lifetime, function()
			holder:Destroy()
		end)
	end
	local clone = template:Clone()
	if clone:IsA("Folder") then
		-- Packs guardam efeitos em Folders: vira Model para poder posicionar
		local model = Instance.new("Model")
		model.Name = clone.Name
		for _, child in clone:GetChildren() do
			child.Parent = model
		end
		for k, v in clone:GetAttributes() do
			model:SetAttribute(k, v)
		end
		clone:Destroy()
		clone = model
	end
	local originRelative = clone:GetAttribute("OriginRelative") == true
	if clone:IsA("Attachment") then
		clone.Parent = anchor
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.CFrame = cframe
		clone.Parent = Workspace
	elseif clone:IsA("Model") then
		if originRelative then
			-- CFrame de cada Part no template é relativo ao ponto de spawn (segue a rotação do personagem)
			for _, d in clone:GetDescendants() do
				if d:IsA("BasePart") then
					d.CFrame = cframe * d.CFrame
				end
			end
		else
			clone:PivotTo(cframe)
		end
		clone.Parent = Workspace
	else
		clone.Parent = anchor
	end

	local emitters = {}
	if clone:IsA("ParticleEmitter") then
		table.insert(emitters, clone)
	end
	local follow = clone:GetAttribute("Follow") == true and root ~= nil
	for _, d in clone:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			table.insert(emitters, d)
			if follow then
				d.Parent = root
			end
		elseif d:IsA("PointLight") then
			if follow then
				d.Parent = root
			end
			local fade = d:GetAttribute("FadeTime")
			if typeof(fade) == "number" then
				TweenService:Create(d, TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Brightness = 0 }):Play()
			end
		elseif d:IsA("BillboardGui") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy() -- lixo de packs ("DELETE ME", scripts de demo)
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			local scale = d:GetAttribute("TweenScale")
			local time = d:GetAttribute("TweenTime")
			if typeof(scale) == "number" and typeof(time) == "number" then
				TweenService:Create(d, TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Size = d.Size * scale,
					Transparency = 1,
				}):Play()
			end
		end
	end
	local followed: { Instance } = {}
	for _, emitter in emitters do
		-- Packs costumam vir com emissão contínua (Rate > 0): convertemos em uma rajada única
		local count = emitter:GetAttribute("EmitCount")
		local burst = if typeof(count) == "number" then count else math.clamp(math.floor(emitter.Rate * 0.5), 8, FX.MaxEmitPerEmitter)
		local duration = emitter:GetAttribute("EmitDuration")
		if typeof(duration) == "number" then
			-- Aura: emissão contínua limitada, com teto de partículas por segundo
			emitter.Rate = math.min(emitter.Rate > 0 and emitter.Rate or burst, FX.MaxEmitPerEmitter)
			emitter.Enabled = true
			task.delay(duration, function()
				emitter.Enabled = false
			end)
		else
			emitter.Enabled = false
			emitter:Emit(math.min(FX.MaxEmitPerEmitter, burst))
		end
		if emitter.Parent == root then
			table.insert(followed, emitter)
		end
	end
	if follow then
		for _, d in (root :: BasePart):GetChildren() do
			if d:IsA("PointLight") and d:GetAttribute("FadeTime") ~= nil then
				table.insert(followed, d)
			end
		end
	end
	activeVFX += 1
	task.delay(lifetime, function()
		activeVFX -= 1
		clone:Destroy()
		for _, inst in followed do
			inst:Destroy()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Movimento / câmera / números
-- ---------------------------------------------------------------------------

local hitstopToken: { [Model]: number } = {}

--- Congela as animações do personagem por `seconds` (hitstop). Só visual.
function FX.Hitstop(character: Model, seconds: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local token = (hitstopToken[character] or 0) + 1
	hitstopToken[character] = token
	local tracks = animator:GetPlayingAnimationTracks()
	for _, track in tracks do
		track:AdjustSpeed(0)
	end
	task.delay(seconds, function()
		if hitstopToken[character] ~= token then
			return
		end
		hitstopToken[character] = nil
		for _, track in tracks do
			if track.IsPlaying then
				track:AdjustSpeed(1)
			end
		end
	end)
end

--- Rastro atrás do HRP por `duration` segundos (dash, blink, knockback).
function FX.Trail(character: Model, color: Color3, duration: number, width: number?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local w = (width or 2) / 2
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, w, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -w, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	trail.Lifetime = 0.25
	trail.LightEmission = 0.8
	trail.FaceCamera = true
	trail.Parent = root
	task.delay(duration, function()
		trail.Enabled = false
		task.delay(trail.Lifetime, function()
			trail:Destroy()
			a0:Destroy()
			a1:Destroy()
		end)
	end)
end

--- Aplica velocidade constante ao HRP por `duration` (só faz sentido no personagem local).
function FX.Push(character: Model, velocity: Vector3, duration: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	-- um empurrão por vez: o anterior (e seu Attachment) sai antes de somar outro
	for _, child in root:GetChildren() do
		if child.Name == "FXPush" then
			child:Destroy()
		end
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "FXPush"
	attachment.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "FXPush"
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = math.huge
	lv.VectorVelocity = velocity
	lv.Parent = root
	task.delay(duration, function()
		if lv.Parent then
			lv:Destroy()
		end
		if attachment.Parent then
			attachment:Destroy()
		end
	end)
end

local shakeUntil = 0
local shakeMagnitude = 0
local shakeConnected = false

--- Tremor leve de câmera (magnitude em studs, ~0.3 é sutil).
--- Desligáveis pelo jogador (SettingsController): tremor de tela e vibração (gamepad).
FX.ShakeEnabled = true
FX.Haptic = nil :: ((strength: number, seconds: number) -> ())?

function FX.Shake(magnitude: number, duration: number)
	if FX.Haptic then
		FX.Haptic(math.clamp(magnitude, 0, 1), math.min(duration, 0.3))
	end
	if not FX.ShakeEnabled then
		return
	end
	shakeMagnitude = math.max(shakeMagnitude, magnitude)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
	if shakeConnected then
		return
	end
	shakeConnected = true
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local remaining = shakeUntil - os.clock()
		if remaining <= 0 then
			conn:Disconnect()
			shakeConnected = false
			shakeMagnitude = 0
			return
		end
		local m = shakeMagnitude * math.min(1, remaining / 0.15)
		camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * m, (math.random() - 0.5) * m, 0)
	end)
end

local activeNumbers = 0
FX.MaxDamageNumbers = 20

--- Número flutuante sobre o personagem.
function FX.DamageNumber(character: Model, text: string, color: Color3)
	if activeNumbers >= FX.MaxDamageNumbers then
		return
	end
	local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(100, 40)
	gui.StudsOffset = Vector3.new(math.random(-1, 1), 2.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 22
	label.Parent = gui
	gui.Parent = character
	activeNumbers += 1
	TweenService:Create(gui, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = gui.StudsOffset + Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.75, function()
		activeNumbers -= 1
		gui:Destroy()
	end)
end

-- ---------------------------------------------------------------------------
-- Som
-- ---------------------------------------------------------------------------

-- Fade para o som não entrar/cortar seco (decisão do dono 2026-09-16): 0 → Volume em FadeIn,
-- Volume → 0 nos últimos FadeOut segundos. Sons mais curtos que FadeIn+FadeOut tocam sem fade.
FX.SoundFadeIn = 0.15
FX.SoundFadeOut = 0.3

local function fadeOut(sound: Sound)
	if not sound.Parent or not sound.IsPlaying then
		return
	end
	TweenService:Create(sound, TweenInfo.new(FX.SoundFadeOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Volume = 0 }):Play()
end

--- Toca um clone do som; devolve uma função que o interrompe (com fade) ou nil se o teto foi atingido.
local function playClone(template: Sound, parent: Instance): (() -> ())?
	if activeSounds >= FX.MaxActiveSounds then
		return nil
	end
	local sound = template:Clone()
	local target = template.Volume
	sound.Parent = parent
	activeSounds += 1
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		activeSounds -= 1
		sound:Destroy()
	end
	sound.Ended:Once(finish)
	sound.Stopped:Once(finish)
	sound.Volume = 0
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(FX.SoundFadeIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = target }):Play()
	task.spawn(function()
		-- TimeLength só existe depois de carregar; espera no máximo 3 s
		if not sound.IsLoaded then
			local t0 = os.clock()
			repeat
				task.wait(0.05)
			until sound.IsLoaded or done or os.clock() - t0 > 3
		end
		if done then
			return
		end
		local length = sound.TimeLength / math.max(sound.PlaybackSpeed, 0.01)
		if length > FX.SoundFadeIn + FX.SoundFadeOut and not sound.Looped then
			local wait = length - sound.TimePosition / math.max(sound.PlaybackSpeed, 0.01) - FX.SoundFadeOut
			task.delay(math.max(wait, 0), fadeOut, sound)
		end
		-- segurança se Ended nunca disparar (id inválido / som em loop)
		if not sound.Looped then
			task.delay(math.max(10, length + 1), finish)
		end
	end)
	return function()
		if not done then
			fadeOut(sound)
			task.delay(FX.SoundFadeOut + 0.05, finish)
		end
	end
end

--- Som 3D em Assets.Sounds.<folder>.<name>, tocado no personagem.
--- Retorna true se o som existia (tem SoundId) e foi tocado.
function FX.PlaySoundAt(character: Model, folder: string, name: string): boolean
	local template = Assets.GetSound(Assets.ResolveFolder("Sounds", folder, name, character), name)
	local root = character:FindFirstChild("HumanoidRootPart")
	if template and root then
		playClone(template, root)
		return true
	end
	return false
end

--- Igual a PlaySoundAt, mas devolve a função que PARA o som (com fade). Para sons em loop/longos
--- que precisam acabar num momento exato (ex.: carga da cutscene do despertar).
function FX.PlaySoundAtStoppable(character: Model, folder: string, name: string): (() -> ())?
	local template = Assets.GetSound(Assets.ResolveFolder("Sounds", folder, name, character), name)
	local root = character:FindFirstChild("HumanoidRootPart")
	if template and root then
		return playClone(template, root)
	end
	return nil
end

--- Som de UI (não posicional).
function FX.PlaySoundUI(folder: string, name: string)
	local template = Assets.GetSound(folder, name)
	if template then
		playClone(template, SoundService)
	end
end

return FX
