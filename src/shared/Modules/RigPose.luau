--!strict
--[[
	RigPose
	Poses procedurais no rig R6 mexendo no Motor6D.C0 (compõe com o Animator: a animação da equipe
	continua mexendo o Transform por cima). Usado pelo ProcAnimController (socos, reações, dash,
	habilidades) e pelo CutsceneController (despertar).

	Original(motor) guarda o C0 "de fábrica" de cada junta na PRIMEIRA vez que a vemos — todos os
	sistemas partem do mesmo original, então nunca acumulam pose sobre pose.

	Convenções (espaço do Torso/HRP, ângulos em GRAUS):
	  rot.X > 0 = braço/perna para a FRENTE (levantar); Root/Neck rot.X > 0 = inclinar para TRÁS
	  rot.Z     = abrir para o lado (direito +, esquerdo −)
	  rot.Y     = girar (torso/cabeça para o lado)
	  off       = deslocamento em studs (só faz sentido no RootJoint: corpo inteiro; Y − = agachar)
]]

local RigPose = {}

export type JointPose = { rot: Vector3?, off: Vector3? }
export type Pose = { [string]: JointPose }

RigPose.Joints = { "RootJoint", "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" }

local originals: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

function RigPose.Original(motor: Motor6D): CFrame
	local c = originals[motor]
	if not c then
		c = motor.C0
		originals[motor] = c
	end
	return c
end

--- Junta o rig (nome → Motor6D) do personagem R6. nil se não achou pelo menos 4 juntas.
function RigPose.Capture(character: Model): { [string]: Motor6D }?
	local joints: { [string]: Motor6D } = {}
	local found = 0
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and table.find(RigPose.Joints, d.Name) then
			joints[d.Name] = d
			RigPose.Original(d)
			found += 1
		end
	end
	return if found >= 4 then joints else nil
end

--- C0 alvo para a pose de UMA junta (rotação em volta do pivô da junta + deslocamento).
function RigPose.Target(original: CFrame, jp: JointPose?): CFrame
	if not jp then
		return original
	end
	local pivot = original.Position
	local rot = jp.rot or Vector3.zero
	local off = jp.off or Vector3.zero
	return CFrame.new(off) * CFrame.new(pivot) * CFrame.fromEulerAnglesXYZ(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)) * CFrame.new(-pivot) * original
end

--- Interpola duas poses (juntas ausentes = neutro).
function RigPose.Lerp(a: Pose, b: Pose, alpha: number): Pose
	local out: Pose = {}
	for _, name in RigPose.Joints do
		local ja, jb = a[name], b[name]
		if ja or jb then
			local ra = (ja and ja.rot) or Vector3.zero
			local rb = (jb and jb.rot) or Vector3.zero
			local oa = (ja and ja.off) or Vector3.zero
			local ob = (jb and jb.off) or Vector3.zero
			out[name] = { rot = ra:Lerp(rb, alpha), off = oa:Lerp(ob, alpha) }
		end
	end
	return out
end

--- Aplica a pose (juntas ausentes voltam ao original).
function RigPose.Apply(joints: { [string]: Motor6D }, pose: Pose)
	for name, motor in joints do
		motor.C0 = RigPose.Target(RigPose.Original(motor), pose[name])
	end
end

return RigPose
