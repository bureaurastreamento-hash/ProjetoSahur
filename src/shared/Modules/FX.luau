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

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Assets = require(script.Parent:WaitForChild("Assets"))

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

-- ---------------------------------------------------------------------------
-- Animação
-- ---------------------------------------------------------------------------

local tracks: { [Model]: { [string]: AnimationTrack } } = {}

local r15Animations: { [Animation]: Animation } = {}

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
	local track = trackFor(character, folder, name)
	if not track then
		return nil
	end
	track.Looped = looped == true
	track.Priority = priority or Enum.AnimationPriority.Action
	track:Play(0.1)
	return track
end

function FX.StopAnimation(character: Model, folder: string, name: string)
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
	if activeVFX >= FX.MaxActiveVFX then
		return
	end
	local template = if exact then (if Assets.HasVFX(folder, name) then Assets.GetVFX(folder, name) else nil) else Assets.GetVFX(folder, name)
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
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = math.huge
	lv.VectorVelocity = velocity
	lv.Parent = root
	task.delay(duration, function()
		lv:Destroy()
		attachment:Destroy()
	end)
end

local shakeUntil = 0
local shakeMagnitude = 0
local shakeConnected = false

--- Tremor leve de câmera (magnitude em studs, ~0.3 é sutil).
function FX.Shake(magnitude: number, duration: number)
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

local function playClone(template: Sound, parent: Instance)
	if activeSounds >= FX.MaxActiveSounds then
		return
	end
	local sound = template:Clone()
	sound.Parent = parent
	activeSounds += 1
	sound.Ended:Once(function()
		activeSounds -= 1
		sound:Destroy()
	end)
	sound:Play()
	-- segurança se Ended nunca disparar (id inválido)
	task.delay(10, function()
		if sound.Parent then
			activeSounds -= 1
			sound:Destroy()
		end
	end)
end

--- Som 3D em Assets.Sounds.<folder>.<name>, tocado no personagem.
--- Retorna true se o som existia (tem SoundId) e foi tocado.
function FX.PlaySoundAt(character: Model, folder: string, name: string): boolean
	local template = Assets.GetSound(folder, name)
	local root = character:FindFirstChild("HumanoidRootPart")
	if template and root then
		playClone(template, root)
		return true
	end
	return false
end

--- Som de UI (não posicional).
function FX.PlaySoundUI(folder: string, name: string)
	local template = Assets.GetSound(folder, name)
	if template then
		playClone(template, SoundService)
	end
end

return FX
