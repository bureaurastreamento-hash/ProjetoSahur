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

local SoundService = game:GetService("SoundService")
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

local function trackFor(character: Model, folder: string, name: string): AnimationTrack?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
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
function FX.SpawnVFX(character: Model, folder: string, name: string, exact: boolean?)
	if activeVFX >= FX.MaxActiveVFX then
		return
	end
	local template = if exact then (if Assets.HasVFX(folder, name) then Assets.GetVFX(folder, name) else nil) else Assets.GetVFX(folder, name)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not template or not root then
		return
	end
	local clone = template:Clone()
	if clone:IsA("Attachment") then
		clone.Parent = root
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.CFrame = root.CFrame
		clone.Parent = Workspace
	elseif clone:IsA("Model") then
		clone:PivotTo(root.CFrame)
		clone.Parent = Workspace
	else
		clone.Parent = root
	end
	local emitters = {}
	if clone:IsA("ParticleEmitter") then
		table.insert(emitters, clone)
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			table.insert(emitters, d)
		end
	end
	for _, emitter in emitters do
		local count = emitter:GetAttribute("EmitCount")
		emitter:Emit(math.min(FX.MaxEmitPerEmitter, if typeof(count) == "number" then count else 20))
	end
	activeVFX += 1
	task.delay(FX.VFXLifetime, function()
		activeVFX -= 1
		clone:Destroy()
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
function FX.PlaySoundAt(character: Model, folder: string, name: string)
	local template = Assets.GetSound(folder, name)
	local root = character:FindFirstChild("HumanoidRootPart")
	if template and root then
		playClone(template, root)
	end
end

--- Som de UI (não posicional).
function FX.PlaySoundUI(folder: string, name: string)
	local template = Assets.GetSound(folder, name)
	if template then
		playClone(template, SoundService)
	end
end

return FX
