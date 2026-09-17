--!strict
--[[
	ProcAnimDefs
	Animações PROCEDURAIS (keyframes de pose por junta R6, ver RigPose) para cada ação do jogo, com a
	duração casada com o tempo real da ação (CombatConfig: soco = HitDelay 0,15 s + Cooldown 0,3 s;
	dash = 0,24 × 1,4; etc.). Tocadas pelo ProcAnimController via FX.PlayAnimation:
	  - chave = "<Pasta>/<Nome>" igual a Assets.Animations (Shared/M1_1, Swift/Blink…)
	  - `team = true` = se a equipe colou um id em Animations.model.json, toca o dela em vez desta
	    (padrão false: a procedural manda, mesmo com id — decisão do dono 2026-09-17, as dos packs
	    têm tempo errado). Idle/Walk/Run não têm entrada aqui: continuam as da equipe.
	Frames: { t = segundos, pose = { Junta = { rot = Vector3 (graus), off = Vector3 } }, ease = "out"|"in"|"inout"|"linear" }
	O frame em t=0 é o começo (faltando = neutro); depois do último frame a pose volta ao neutro em `blendOut`.
	Loops (`loop = true`) repetem entre o primeiro e o último frame até StopAnimation.
]]

local V = Vector3.new
local J = {
	Root = "RootJoint",
	Neck = "Neck",
	RA = "Right Shoulder",
	LA = "Left Shoulder",
	RL = "Right Hip",
	LL = "Left Hip",
}

export type JointPose = { rot: Vector3?, off: Vector3? }
export type Pose = { [string]: JointPose }
export type Frame = { t: number, pose: Pose, ease: string? }
export type Clip = { duration: number, frames: { Frame }, loop: boolean?, blendOut: number?, team: boolean?, upperOnly: boolean? }

local function P(t: number, pose: { [string]: JointPose }, ease: string?): Frame
	local p: Pose = {}
	for short, jp in pose do
		p[J[short] or short] = jp
	end
	return { t = t, pose = p, ease = ease }
end

local ProcAnimDefs = {}
local C: { [string]: Clip } = {}
ProcAnimDefs.Clips = C

-- Guarda básica (braços meio erguidos) usada como início/fim dos socos
local GUARD: { [string]: JointPose } = { RA = { rot = V(35, 0, 12) }, LA = { rot = V(45, 0, -12) }, Root = { rot = V(-4, 0, 0) } }

-- ---------------------------------------------------------------------------
-- SOCOS (M1): 0,45 s cada = HitDelay 0,15 (impacto) + Cooldown 0,3 (recuo)
-- ---------------------------------------------------------------------------
C["Shared/M1_1"] = { -- jab direito
	duration = 0.45,
	frames = {
		P(0, GUARD),
		P(0.06, { RA = { rot = V(20, 0, 8) }, LA = { rot = V(50, 0, -14) }, Root = { rot = V(-6, 12, 0) } }, "in"),
		P(0.15, { RA = { rot = V(92, 0, -6) }, LA = { rot = V(40, 0, -16) }, Root = { rot = V(-8, -18, 0), off = V(0, -0.1, -0.25) }, Neck = { rot = V(-4, 0, 0) } }, "out"),
		P(0.26, { RA = { rot = V(88, 0, -4) }, LA = { rot = V(40, 0, -16) }, Root = { rot = V(-7, -16, 0), off = V(0, -0.1, -0.25) } }),
		P(0.45, GUARD, "inout"),
	},
}
C["Shared/M1_2"] = { -- jab esquerdo (espelho)
	duration = 0.45,
	frames = {
		P(0, GUARD),
		P(0.06, { LA = { rot = V(20, 0, -8) }, RA = { rot = V(50, 0, 14) }, Root = { rot = V(-6, -12, 0) } }, "in"),
		P(0.15, { LA = { rot = V(92, 0, 6) }, RA = { rot = V(40, 0, 16) }, Root = { rot = V(-8, 18, 0), off = V(0, -0.1, -0.25) }, Neck = { rot = V(-4, 0, 0) } }, "out"),
		P(0.26, { LA = { rot = V(88, 0, 4) }, RA = { rot = V(40, 0, 16) }, Root = { rot = V(-7, 16, 0), off = V(0, -0.1, -0.25) } }),
		P(0.45, GUARD, "inout"),
	},
}
C["Shared/M1_3"] = { -- gancho direito (vem de fora)
	duration = 0.45,
	frames = {
		P(0, GUARD),
		P(0.07, { RA = { rot = V(30, 0, 70) }, LA = { rot = V(50, 0, -14) }, Root = { rot = V(-6, 28, 0) } }, "in"),
		P(0.15, { RA = { rot = V(85, 0, 10) }, LA = { rot = V(40, 0, -16) }, Root = { rot = V(-10, -30, 0), off = V(0, -0.15, -0.3) }, Neck = { rot = V(-6, 0, 0) } }, "out"),
		P(0.27, { RA = { rot = V(80, 0, 0) }, LA = { rot = V(40, 0, -16) }, Root = { rot = V(-8, -26, 0), off = V(0, -0.15, -0.3) } }),
		P(0.45, GUARD, "inout"),
	},
}
C["Shared/M1_4"] = { -- finisher: direto pesado com o corpo inteiro (empurra)
	duration = 0.5,
	frames = {
		P(0, GUARD),
		P(0.06, { RA = { rot = V(-20, 0, 14) }, LA = { rot = V(55, 0, -14) }, Root = { rot = V(4, 22, 0), off = V(0, -0.15, 0.2) } }, "in"),
		P(0.15, { RA = { rot = V(100, 0, -8) }, LA = { rot = V(30, 0, -18) }, Root = { rot = V(-16, -30, 0), off = V(0, -0.3, -0.7) }, Neck = { rot = V(-8, 0, 0) }, RL = { rot = V(-18, 0, 4) }, LL = { rot = V(24, 0, -4) } }, "out"),
		P(0.3, { RA = { rot = V(96, 0, -6) }, LA = { rot = V(30, 0, -18) }, Root = { rot = V(-14, -26, 0), off = V(0, -0.3, -0.7) }, RL = { rot = V(-18, 0, 4) }, LL = { rot = V(24, 0, -4) } }),
		P(0.5, GUARD, "inout"),
	},
}
C["Shared/Uppercut"] = { -- soco subindo: braço vem de baixo e sobe; corpo estica
	duration = 0.5,
	frames = {
		P(0, { RA = { rot = V(-30, 0, 10) }, LA = { rot = V(40, 0, -14) }, Root = { rot = V(-14, 14, 0), off = V(0, -0.5, 0) } }),
		P(0.12, { RA = { rot = V(160, 0, -4) }, LA = { rot = V(30, 0, -18) }, Root = { rot = V(12, -10, 0), off = V(0, 0.35, -0.2) }, Neck = { rot = V(14, 0, 0) }, RL = { rot = V(-10, 0, 4) }, LL = { rot = V(10, 0, -4) } }, "out"),
		P(0.3, { RA = { rot = V(150, 0, -4) }, LA = { rot = V(30, 0, -18) }, Root = { rot = V(10, -8, 0), off = V(0, 0.3, -0.2) }, Neck = { rot = V(12, 0, 0) } }),
		P(0.5, GUARD, "inout"),
	},
}
C["Shared/Downslam"] = { -- soco caindo: os dois braços de cima para baixo, corpo agacha
	duration = 0.5,
	frames = {
		P(0, { RA = { rot = V(175, 0, 20) }, LA = { rot = V(175, 0, -20) }, Root = { rot = V(10, 0, 0), off = V(0, 0.2, 0) }, Neck = { rot = V(10, 0, 0) } }),
		P(0.12, { RA = { rot = V(20, 0, 10) }, LA = { rot = V(20, 0, -10) }, Root = { rot = V(-30, 0, 0), off = V(0, -0.6, -0.3) }, Neck = { rot = V(-14, 0, 0) }, RL = { rot = V(40, 0, 10) }, LL = { rot = V(40, 0, -10) } }, "in"),
		P(0.32, { RA = { rot = V(25, 0, 10) }, LA = { rot = V(25, 0, -10) }, Root = { rot = V(-26, 0, 0), off = V(0, -0.55, -0.3) }, Neck = { rot = V(-12, 0, 0) }, RL = { rot = V(40, 0, 10) }, LL = { rot = V(40, 0, -10) } }),
		P(0.5, GUARD, "inout"),
	},
}

-- ---------------------------------------------------------------------------
-- REAÇÕES
-- ---------------------------------------------------------------------------
C["Shared/Hit"] = { -- levou soco: tranco para trás, cabeça vai junto
	duration = 0.3,
	frames = {
		P(0, {}),
		P(0.06, { Root = { rot = V(14, 8, 0), off = V(0, 0, 0.35) }, Neck = { rot = V(18, 10, 0) }, RA = { rot = V(-15, 0, 22) }, LA = { rot = V(-10, 0, -18) } }, "out"),
		P(0.3, {}, "inout"),
	},
}
C["Shared/Parry"] = { -- desvio: braço esquerdo varre a frente, corpo gira
	duration = 0.32,
	frames = {
		P(0, { LA = { rot = V(60, 0, -40) }, Root = { rot = V(-2, -14, 0) } }),
		P(0.1, { LA = { rot = V(85, 0, 40) }, RA = { rot = V(30, 0, 20) }, Root = { rot = V(-4, 22, 0) }, Neck = { rot = V(0, -10, 0) } }, "out"),
		P(0.32, GUARD, "inout"),
	},
}
C["Shared/Block"] = { -- guarda fechada (loop): antebraços cruzados na frente do rosto, meio agachado
	duration = 1.2,
	loop = true,
	frames = {
		P(0, { RA = { rot = V(105, 0, -30) }, LA = { rot = V(110, 0, 30) }, Root = { rot = V(-8, 0, 0), off = V(0, -0.2, 0) }, Neck = { rot = V(-6, 0, 0) }, RL = { rot = V(0, 0, 8) }, LL = { rot = V(0, 0, -8) } }),
		P(0.6, { RA = { rot = V(108, 0, -32) }, LA = { rot = V(113, 0, 32) }, Root = { rot = V(-9, 0, 0), off = V(0, -0.24, 0) }, Neck = { rot = V(-6, 0, 0) }, RL = { rot = V(0, 0, 8) }, LL = { rot = V(0, 0, -8) } }, "inout"),
		P(1.2, { RA = { rot = V(105, 0, -30) }, LA = { rot = V(110, 0, 30) }, Root = { rot = V(-8, 0, 0), off = V(0, -0.2, 0) }, Neck = { rot = V(-6, 0, 0) }, RL = { rot = V(0, 0, 8) }, LL = { rot = V(0, 0, -8) } }, "inout"),
	},
}
C["Shared/BlockHit"] = { -- impacto absorvido por cima da guarda
	duration = 0.22,
	frames = {
		P(0, { RA = { rot = V(105, 0, -30) }, LA = { rot = V(110, 0, 30) }, Root = { rot = V(-8, 0, 0), off = V(0, -0.2, 0) } }),
		P(0.05, { RA = { rot = V(95, 0, -26) }, LA = { rot = V(100, 0, 26) }, Root = { rot = V(2, 0, 0), off = V(0, -0.25, 0.3) }, Neck = { rot = V(6, 0, 0) } }, "out"),
		P(0.22, { RA = { rot = V(105, 0, -30) }, LA = { rot = V(110, 0, 30) }, Root = { rot = V(-8, 0, 0), off = V(0, -0.2, 0) } }, "inout"),
	},
}
C["Shared/Grabbed"] = { -- preso no agarrão (loop): se debate, pernas soltas
	duration = 0.6,
	loop = true,
	frames = {
		P(0, { RA = { rot = V(40, 0, 70) }, LA = { rot = V(20, 0, -60) }, Root = { rot = V(-12, 0, 6) }, Neck = { rot = V(-10, 12, 0) }, RL = { rot = V(24, 0, 8) }, LL = { rot = V(-14, 0, -8) } }),
		P(0.3, { RA = { rot = V(20, 0, 60) }, LA = { rot = V(45, 0, -75) }, Root = { rot = V(-14, 0, -6) }, Neck = { rot = V(-8, -12, 0) }, RL = { rot = V(-14, 0, 8) }, LL = { rot = V(24, 0, -8) } }, "inout"),
		P(0.6, { RA = { rot = V(40, 0, 70) }, LA = { rot = V(20, 0, -60) }, Root = { rot = V(-12, 0, 6) }, Neck = { rot = V(-10, 12, 0) }, RL = { rot = V(24, 0, 8) }, LL = { rot = V(-14, 0, -8) } }, "inout"),
	},
}

-- ---------------------------------------------------------------------------
-- MOVIMENTO
-- ---------------------------------------------------------------------------
C["Shared/Dash"] = { -- dash para a frente/lado: corpo inclina, braços para trás (0,24 × 1,4 = 0,34 s)
	duration = 0.34,
	frames = {
		P(0, {}),
		P(0.06, { Root = { rot = V(-30, 0, 0), off = V(0, -0.35, 0) }, Neck = { rot = V(16, 0, 0) }, RA = { rot = V(-45, 0, 16) }, LA = { rot = V(-45, 0, -16) }, RL = { rot = V(22, 0, 4) }, LL = { rot = V(-22, 0, -4) } }, "out"),
		P(0.24, { Root = { rot = V(-26, 0, 0), off = V(0, -0.3, 0) }, Neck = { rot = V(14, 0, 0) }, RA = { rot = V(-40, 0, 16) }, LA = { rot = V(-40, 0, -16) }, RL = { rot = V(-22, 0, 4) }, LL = { rot = V(22, 0, -4) } }, "inout"),
		P(0.34, {}, "inout"),
	},
}
C["Shared/DashBack"] = { -- dash para trás: corpo inclina para trás, braços para a frente
	duration = 0.34,
	frames = {
		P(0, {}),
		P(0.06, { Root = { rot = V(24, 0, 0), off = V(0, -0.25, 0) }, Neck = { rot = V(-10, 0, 0) }, RA = { rot = V(50, 0, 10) }, LA = { rot = V(50, 0, -10) }, RL = { rot = V(-20, 0, 6) }, LL = { rot = V(20, 0, -6) } }, "out"),
		P(0.24, { Root = { rot = V(20, 0, 0), off = V(0, -0.2, 0) }, Neck = { rot = V(-8, 0, 0) }, RA = { rot = V(45, 0, 10) }, LA = { rot = V(45, 0, -10) }, RL = { rot = V(20, 0, 6) }, LL = { rot = V(-20, 0, -6) } }, "inout"),
		P(0.34, {}, "inout"),
	},
}
C["Shared/RagdollCancel"] = { -- levantou no Q: explode do chão com os braços abertos
	duration = 0.4,
	frames = {
		P(0, { Root = { rot = V(-30, 0, 0), off = V(0, -1.0, 0) }, RA = { rot = V(20, 0, 10) }, LA = { rot = V(20, 0, -10) }, RL = { rot = V(60, 0, 10) }, LL = { rot = V(60, 0, -10) } }),
		P(0.15, { Root = { rot = V(8, 0, 0), off = V(0, 0.25, 0) }, RA = { rot = V(60, 0, 80) }, LA = { rot = V(60, 0, -80) }, Neck = { rot = V(8, 0, 0) } }, "out"),
		P(0.4, {}, "inout"),
	},
}

-- ---------------------------------------------------------------------------
-- CUTSCENE do despertar (só as poses usadas pelo CutsceneController estão lá; aqui nada)
-- ---------------------------------------------------------------------------

function ProcAnimDefs.Get(key: string): Clip?
	return C[key]
end

return ProcAnimDefs
