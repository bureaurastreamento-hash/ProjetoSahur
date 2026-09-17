--!strict
--[[
	ProcAnimController (cliente)
	Toca as animações PROCEDURAIS de ProcAnimDefs (keyframes de pose por junta R6, RigPose) em qualquer
	personagem que este cliente vê. Duas camadas:
	  - BASE (locomoção, Leva 8): Idle/Walk/Run do personagem, escolhidos pela velocidade do Humanoid
	    e com o ciclo acelerando junto. Roda sozinho, sem rede, em todo mundo que aparece no Workspace.
	  - AÇÃO: entra pelo FX.PlayAnimation/StopAnimation (gancho FX.ProcAnim) — se existe clipe para
	    "<Pasta>/<Nome>" e (clipe não é `team` OU o id da equipe está vazio), toca o clipe e a
	    animação da Roblox NÃO é carregada. A ação manda nas juntas que ela mexe; o resto segue a base.
	Um clipe de ação por personagem (o novo substitui o anterior); loops (Block/Grabbed) ficam
	guardados e voltam quando a ação acaba. Só mexe em Motor6D.C0.
	Cada personagem resolve o clipe pelo seu CharacterId (ProcAnimDefs.Resolve): clipe próprio >
	variação de estilo do Shared > Shared cru.
	Atributo `ProcAnimHold` = true no personagem: outro sistema está posando o rig (cutscene do
	despertar) e nós não encostamos nas juntas até ele soltar.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Assets = require(Modules:WaitForChild("Assets"))
local FX = require(Modules:WaitForChild("FX"))
local RigPose = require(Modules:WaitForChild("RigPose"))
local ProcAnimDefs = require(Modules:WaitForChild("ProcAnimDefs"))
local Log = require(Modules:WaitForChild("Log"))

local ProcAnimController = {}

local LOCO = ProcAnimDefs.Locomotion

type Active = {
	key: string,
	clip: ProcAnimDefs.Clip,
	startedAt: number,
	from: RigPose.Pose?, -- pose em que o clipe anterior parou (blend de entrada)
	blendIn: number,
	loop: boolean,
	speed: number,
}
type CharState = {
	joints: { [string]: Motor6D },
	action: Active?,
	held: Active?, -- loop guardado (Block/Grabbed) que volta quando a ação acaba
	last: RigPose.Pose, -- última pose de AÇÃO aplicada (para blends)
	blendOutFrom: RigPose.Pose?,
	blendOutAt: number,
	blendOutSeconds: number,
	-- locomoção
	humanoid: Humanoid?,
	root: BasePart?,
	base: Active?, -- Idle/Walk/Run tocando
	baseName: string?,
	basePose: RigPose.Pose,
	animateOff: boolean,
}
local chars: { [Model]: CharState } = {}

local EASES: { [string]: (number) -> number } = {
	linear = function(x)
		return x
	end,
	out = function(x)
		return 1 - (1 - x) * (1 - x)
	end,
	["in"] = function(x)
		return x * x
	end,
	inout = function(x)
		return x * x * (3 - 2 * x)
	end,
}

local function clipFor(character: Model, key: string): ProcAnimDefs.Clip?
	return ProcAnimDefs.Resolve(key, Assets.CharacterIdOf(character))
end

local function stateFor(character: Model): CharState?
	local s = chars[character]
	if s then
		return s
	end
	local joints = RigPose.Capture(character)
	if not joints then
		return nil
	end
	s = {
		joints = joints,
		action = nil,
		held = nil,
		last = {},
		blendOutFrom = nil,
		blendOutAt = 0,
		blendOutSeconds = 0.12,
		humanoid = character:FindFirstChildOfClass("Humanoid"),
		root = character:FindFirstChild("HumanoidRootPart") :: BasePart?,
		base = nil,
		baseName = nil,
		basePose = {},
		animateOff = false,
	}
	chars[character] = s
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			chars[character] = nil
		end
	end)
	return s
end

--- Pose do clipe em `t` (interpola entre frames; loop repete).
local function poseAt(active: Active, t: number): (RigPose.Pose, boolean)
	local clip = active.clip
	local frames = clip.frames
	local duration = clip.duration
	local finished = false
	if active.loop then
		t = t % duration
	elseif t >= duration then
		t = duration
		finished = true
	end
	local prev = frames[1]
	local nextF = frames[#frames]
	for i = 1, #frames do
		local f = frames[i]
		if f.t <= t then
			prev = f
			nextF = frames[i + 1] or f
		else
			break
		end
	end
	if prev == nextF or nextF.t <= prev.t then
		return prev.pose, finished
	end
	local alpha = (t - prev.t) / (nextF.t - prev.t)
	local easeFn = EASES[nextF.ease or "out"] or EASES.out
	return RigPose.Lerp(prev.pose, nextF.pose, easeFn(alpha)), finished
end

--- Junta a pose da ação por cima da base: a ação manda nas juntas que ela mexe (com peso `w`),
--- as outras continuam na locomoção.
local function overlay(base: RigPose.Pose, action: RigPose.Pose, w: number): RigPose.Pose
	if w >= 1 then
		local out: RigPose.Pose = {}
		for name, jp in base do
			out[name] = jp
		end
		for name, jp in action do
			out[name] = jp
		end
		return out
	end
	local out: RigPose.Pose = {}
	for name, jp in base do
		out[name] = jp
	end
	for name, jp in action do
		local b = base[name]
		local br = (b and b.rot) or Vector3.zero
		local bo = (b and b.off) or Vector3.zero
		out[name] = {
			rot = br:Lerp(jp.rot or Vector3.zero, w),
			off = bo:Lerp(jp.off or Vector3.zero, w),
		}
	end
	return out
end

local function startActive(s: CharState, key: string, clip: ProcAnimDefs.Clip, loop: boolean): Active
	return { key = key, clip = clip, startedAt = os.clock(), from = s.last, blendIn = 0.08, loop = loop, speed = 1 }
end

--- Toca o clipe `key` no personagem. Loops ficam "guardados" por trás das ações.
function ProcAnimController.Play(character: Model, key: string, looped: boolean?): boolean
	local clip = clipFor(character, key)
	if not clip then
		return false
	end
	local s = stateFor(character)
	if not s then
		return false
	end
	local loop = looped == true or clip.loop == true
	local active = startActive(s, key, clip, loop)
	s.blendOutFrom = nil
	if loop then
		s.held = active
	else
		s.action = active
	end
	return true
end

function ProcAnimController.Stop(character: Model, key: string)
	local s = chars[character]
	if not s then
		return
	end
	if s.held and s.held.key == key then
		s.held = nil
		if not s.action then
			s.blendOutFrom = s.last
			s.blendOutAt = os.clock()
		end
	end
	if s.action and s.action.key == key then
		s.action = nil
		s.blendOutFrom = s.last
		s.blendOutAt = os.clock()
	end
end

--- Alguma coisa procedural tocando (ação ou loop)?
function ProcAnimController.IsPlaying(character: Model, key: string?): boolean
	local s = chars[character]
	if not s then
		return false
	end
	if key then
		return (s.action ~= nil and s.action.key == key) or (s.held ~= nil and s.held.key == key)
	end
	return s.action ~= nil or s.held ~= nil
end

-- ---------------------------------------------------------------------------
-- Locomoção (camada de base)
-- ---------------------------------------------------------------------------

--- O script "Animate" padrão mexeria no mesmo corpo por cima da nossa pose: desliga e para as
--- tracks dele (só no personagem deste cliente — nos outros ele já vem desligado de lá).
local function silenceAnimate(character: Model)
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("BaseScript") then
		animate.Disabled = true
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			if track.Priority == Enum.AnimationPriority.Core or track.Priority == Enum.AnimationPriority.Idle or track.Priority == Enum.AnimationPriority.Movement then
				track:Stop(0.1)
			end
		end
	end
end

-- Estados em que o corpo não é nosso (física/animação padrão cuidam)
local FREE_STATES: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.GettingUp] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
	[Enum.HumanoidStateType.Dead] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Climbing] = true,
}

--- Qual locomoção o personagem deveria estar tocando agora (nil = nenhuma: no ar, ragdoll, boss).
local function locomotionFor(character: Model, s: CharState): (string?, number)
	if not LOCO.Enabled then
		return nil, 1
	end
	local humanoid = s.humanoid
	if not humanoid or humanoid.Health <= 0 then
		return nil, 1
	end
	if character:GetAttribute("BossRig") == true or character:GetAttribute("Ragdolled") == true then
		return nil, 1 -- boss tem animações próprias; caído é a física que manda
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player and player:GetAttribute("Ragdolled") == true then
		return nil, 1
	end
	if FREE_STATES[humanoid:GetState()] then
		return nil, 1 -- pulo, queda, ragdoll, sentado: deixa o corpo livre
	end
	local root = s.root
	if not root or not root.Parent then
		local found = character:FindFirstChild("HumanoidRootPart")
		if not found or not found:IsA("BasePart") then
			s.root = nil
			return nil, 1
		end
		root = found
		s.root = found
	end
	local v = (root :: BasePart).AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	if speed < LOCO.WalkThreshold then
		return "Idle", 1
	end
	if speed >= LOCO.RunThreshold then
		return "Run", math.clamp(speed / LOCO.RunReference, 0.6, 1.8)
	end
	return "Walk", math.clamp(speed / LOCO.WalkReference, 0.55, 1.6)
end

local function updateBase(character: Model, s: CharState, now: number)
	local name, rate = locomotionFor(character, s)
	if not name then
		s.base = nil
		s.baseName = nil
		s.basePose = {}
		return
	end
	if not s.animateOff then
		s.animateOff = true
		silenceAnimate(character)
	end
	if s.baseName ~= name then
		local clip = clipFor(character, "Shared/" .. name)
		if not clip then
			s.base = nil
			s.baseName = nil
			s.basePose = {}
			return
		end
		s.baseName = name
		s.base = { key = "Shared/" .. name, clip = clip, startedAt = now, from = s.basePose, blendIn = 0.2, loop = true, speed = rate }
	end
	local base = s.base
	if not base then
		return
	end
	base.speed = rate
	local pose = poseAt(base, (now - base.startedAt) * base.speed)
	local t = now - base.startedAt
	if base.from and t < base.blendIn then
		pose = RigPose.Lerp(base.from, pose, t / base.blendIn)
	end
	s.basePose = pose
end

local function step()
	local now = os.clock()
	for character, s in chars do
		if not character.Parent then
			chars[character] = nil
			continue
		end
		if character:GetAttribute("ProcAnimHold") == true then
			-- alguém está posando este rig por fora (cutscene do despertar): não encostar nas juntas
			s.base, s.baseName, s.basePose = nil, nil, {}
			s.action, s.held, s.blendOutFrom = nil, nil, nil
			s.last = {}
			continue
		end
		updateBase(character, s, now)
		local target: RigPose.Pose? = nil
		local active = s.action or s.held
		if active then
			local t = (now - active.startedAt) * active.speed
			local pose, finished = poseAt(active, t)
			-- blend de entrada a partir da pose em que estávamos
			local w = 1
			if active.from and t < active.blendIn then
				pose = RigPose.Lerp(active.from, pose, t / active.blendIn)
				w = t / active.blendIn
			end
			s.last = pose
			target = overlay(s.basePose, pose, w)
			if finished and active == s.action then
				s.action = nil
				if s.held then
					s.held.from = pose
					s.held.startedAt = now
				else
					s.blendOutFrom = pose
					s.blendOutAt = now
				end
			end
		elseif s.blendOutFrom then
			local alpha = (now - s.blendOutAt) / s.blendOutSeconds
			if alpha >= 1 then
				s.blendOutFrom = nil
				s.last = {}
				target = s.basePose
			else
				target = overlay(s.basePose, s.blendOutFrom, 1 - EASES.inout(alpha))
			end
		elseif s.baseName then
			target = s.basePose
		else
			continue -- neutro e parado: não toca nas juntas (deixa cutscene/animação da equipe em paz)
		end
		if target then
			RigPose.Apply(s.joints, target)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Quem entra na camada de locomoção: todo personagem com Humanoid que aparece no Workspace
-- ---------------------------------------------------------------------------

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	if not model:FindFirstChildOfClass("Humanoid") then
		return
	end
	task.defer(function()
		if model.Parent and LOCO.Enabled then
			stateFor(model)
		end
	end)
end

function ProcAnimController.Init()
	-- gancho no FX: quem chamar PlayAnimation/StopAnimation cai aqui quando existe clipe procedural
	FX.ProcAnim = {
		Wants = function(key: string, hasTeamId: boolean, character: Model?): boolean
			local clip = if character then clipFor(character, key) else ProcAnimDefs.Get(key)
			if not clip then
				return false
			end
			return not (clip.team == true and hasTeamId)
		end,
		Play = ProcAnimController.Play,
		Stop = ProcAnimController.Stop,
	}
end

function ProcAnimController.Start()
	RunService.Heartbeat:Connect(step)
	if LOCO.Enabled then
		for _, child in Workspace:GetChildren() do
			watch(child)
		end
		Workspace.ChildAdded:Connect(watch)
		local function hookPlayer(player: Player)
			if player.Character then
				watch(player.Character)
			end
			player.CharacterAdded:Connect(watch)
		end
		for _, player in Players:GetPlayers() do
			hookPlayer(player)
		end
		Players.PlayerAdded:Connect(hookPlayer)
	end
	local n = 0
	for _ in ProcAnimDefs.Clips do
		n += 1
	end
	Log.debug(("[ProcAnimController] %d animação(ões) procedural(is); locomoção %s"):format(n, if LOCO.Enabled then "ligada" else "desligada"))
end

return ProcAnimController
