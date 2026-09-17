--!strict
--[[
	ProcAnimController (cliente)
	Toca as animações PROCEDURAIS de ProcAnimDefs (keyframes de pose por junta R6, RigPose) em qualquer
	personagem que este cliente vê. Entra pelo FX.PlayAnimation/StopAnimation (gancho FX.ProcAnim):
	  - se existe clipe para "<Pasta>/<Nome>" e (clipe não é `team` OU o id da equipe está vazio),
	    toca o clipe e a animação da Roblox NÃO é carregada.
	Um clipe "de ação" por personagem (o novo substitui o anterior); loops (Block/Grabbed) ficam
	guardados e voltam quando a ação acaba. Só mexe em Motor6D.C0 (compõe com Idle/Walk da equipe).
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local FX = require(Modules:WaitForChild("FX"))
local RigPose = require(Modules:WaitForChild("RigPose"))
local ProcAnimDefs = require(Modules:WaitForChild("ProcAnimDefs"))
local Log = require(Modules:WaitForChild("Log"))

local ProcAnimController = {}

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
	last: RigPose.Pose, -- última pose aplicada (para blends)
	blendOutFrom: RigPose.Pose?,
	blendOutAt: number,
	blendOutSeconds: number,
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

local function stateFor(character: Model): CharState?
	local s = chars[character]
	if s then
		return s
	end
	local joints = RigPose.Capture(character)
	if not joints then
		return nil
	end
	s = { joints = joints, action = nil, held = nil, last = {}, blendOutFrom = nil, blendOutAt = 0, blendOutSeconds = 0.12 }
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

local function startActive(s: CharState, key: string, clip: ProcAnimDefs.Clip, loop: boolean): Active
	return { key = key, clip = clip, startedAt = os.clock(), from = s.last, blendIn = 0.08, loop = loop, speed = 1 }
end

--- Toca o clipe `key` no personagem. Loops ficam "guardados" por trás das ações.
function ProcAnimController.Play(character: Model, key: string, looped: boolean?): boolean
	local clip = ProcAnimDefs.Get(key)
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
		if not s.action then
			-- nada por cima: o loop toca direto
		end
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

local function step()
	local now = os.clock()
	for character, s in chars do
		if not character.Parent then
			chars[character] = nil
			continue
		end
		local target: RigPose.Pose? = nil
		local active = s.action or s.held
		if active then
			local t = (now - active.startedAt) * active.speed
			local pose, finished = poseAt(active, t)
			-- blend de entrada a partir da pose em que estávamos
			if active.from and t < active.blendIn then
				pose = RigPose.Lerp(active.from, pose, t / active.blendIn)
			end
			target = pose
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
				target = {}
			else
				target = RigPose.Lerp(s.blendOutFrom, {}, EASES.inout(alpha))
			end
		else
			continue -- neutro e parado: não toca nas juntas (deixa Idle/Walk/cutscene em paz)
		end
		if target then
			RigPose.Apply(s.joints, target)
			s.last = target
		end
	end
end

function ProcAnimController.Init()
	-- gancho no FX: quem chamar PlayAnimation/StopAnimation cai aqui quando existe clipe procedural
	FX.ProcAnim = {
		Wants = function(key: string, hasTeamId: boolean): boolean
			local clip = ProcAnimDefs.Get(key)
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
	local n = 0
	for _ in ProcAnimDefs.Clips do
		n += 1
	end
	Log.debug(("[ProcAnimController] %d animação(ões) procedural(is)"):format(n))
end

return ProcAnimController
