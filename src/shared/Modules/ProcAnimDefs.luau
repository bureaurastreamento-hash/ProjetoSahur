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
-- HABILIDADES (Leva 3) — duração = CastTime da habilidade (+ o que a ação dura de fato)
-- ---------------------------------------------------------------------------
-- Brawler
C["Brawler/ShoulderBash"] = { -- investida de ombro (0,25 s) — o resto é o Carry
	duration = 0.45,
	frames = {
		P(0, { Root = { rot = V(-10, 25, 0) }, RA = { rot = V(-30, 0, 20) }, LA = { rot = V(40, 0, -10) } }),
		P(0.1, { Root = { rot = V(-28, 40, 0), off = V(0, -0.35, -0.4) }, Neck = { rot = V(10, -25, 0) }, RA = { rot = V(-50, 0, 30) }, LA = { rot = V(60, 0, -10) }, RL = { rot = V(-25, 0, 6) }, LL = { rot = V(30, 0, -6) } }, "out"),
		P(0.45, { Root = { rot = V(-20, 30, 0), off = V(0, -0.3, -0.3) }, RA = { rot = V(-40, 0, 26) }, LA = { rot = V(55, 0, -10) } }, "inout"),
	},
}
C["Brawler/ShoulderBash_Carry"] = { -- segurando o alvo no ombro e arremessando (0,8 s)
	duration = 0.8,
	frames = {
		P(0, { Root = { rot = V(-12, 0, 0), off = V(0, -0.2, 0) }, RA = { rot = V(120, 0, 30) }, LA = { rot = V(120, 0, -30) } }),
		P(0.55, { Root = { rot = V(8, 0, 0), off = V(0, 0.1, 0.3) }, RA = { rot = V(175, 0, 30) }, LA = { rot = V(175, 0, -30) }, Neck = { rot = V(12, 0, 0) } }, "inout"),
		P(0.8, { Root = { rot = V(-26, 0, 0), off = V(0, -0.3, -0.5) }, RA = { rot = V(60, 0, 20) }, LA = { rot = V(60, 0, -20) }, Neck = { rot = V(-8, 0, 0) }, RL = { rot = V(-20, 0, 6) }, LL = { rot = V(26, 0, -6) } }, "out"),
	},
}
C["Brawler/GroundSlam"] = { -- pancada no chão: os dois punhos de cima (0,6 s, impacto em 0,4)
	duration = 0.9,
	frames = {
		P(0, GUARD),
		P(0.22, { Root = { rot = V(14, 0, 0), off = V(0, 0.25, 0) }, Neck = { rot = V(14, 0, 0) }, RA = { rot = V(178, 0, 18) }, LA = { rot = V(178, 0, -18) } }, "out"),
		P(0.4, { Root = { rot = V(-34, 0, 0), off = V(0, -0.8, -0.3) }, Neck = { rot = V(-16, 0, 0) }, RA = { rot = V(12, 0, 12) }, LA = { rot = V(12, 0, -12) }, RL = { rot = V(50, 0, 12) }, LL = { rot = V(50, 0, -12) } }, "in"),
		P(0.65, { Root = { rot = V(-30, 0, 0), off = V(0, -0.75, -0.3) }, Neck = { rot = V(-14, 0, 0) }, RA = { rot = V(16, 0, 12) }, LA = { rot = V(16, 0, -12) }, RL = { rot = V(50, 0, 12) }, LL = { rot = V(50, 0, -12) } }),
		P(0.9, GUARD, "inout"),
	},
}
C["Brawler/Rampage"] = { -- FÚRIA: gira os braços e desce o golpe devastador (0,6 s, impacto em 0,5)
	duration = 1.0,
	frames = {
		P(0, { Root = { rot = V(8, -30, 0) }, RA = { rot = V(150, 0, 70) }, LA = { rot = V(20, 0, -30) } }),
		P(0.25, { Root = { rot = V(16, 30, 0), off = V(0, 0.3, 0) }, Neck = { rot = V(16, 0, 0) }, RA = { rot = V(185, 0, 30) }, LA = { rot = V(150, 0, -60) } }, "inout"),
		P(0.5, { Root = { rot = V(-36, -20, 0), off = V(0, -0.85, -0.6) }, Neck = { rot = V(-18, 0, 0) }, RA = { rot = V(10, 0, 10) }, LA = { rot = V(30, 0, -20) }, RL = { rot = V(-30, 0, 8) }, LL = { rot = V(45, 0, -8) } }, "in"),
		P(0.75, { Root = { rot = V(-32, -18, 0), off = V(0, -0.8, -0.6) }, RA = { rot = V(14, 0, 10) }, LA = { rot = V(30, 0, -20) }, RL = { rot = V(-30, 0, 8) }, LL = { rot = V(45, 0, -8) } }),
		P(1.0, GUARD, "inout"),
	},
}

-- Swift
C["Swift/Blink"] = { -- piscar: agacha e some (0,15 s)
	duration = 0.3,
	frames = {
		P(0, {}),
		P(0.08, { Root = { rot = V(-22, 0, 0), off = V(0, -0.5, 0) }, RA = { rot = V(-30, 0, 20) }, LA = { rot = V(-30, 0, -20) }, RL = { rot = V(30, 0, 6) }, LL = { rot = V(30, 0, -6) } }, "out"),
		P(0.3, {}, "inout"),
	},
}
C["Swift/SweepKick"] = { -- rasteira: gira o corpo com a perna esticada (0,4 s, impacto em 0,2)
	duration = 0.55,
	frames = {
		P(0, { Root = { rot = V(-10, -40, 0), off = V(0, -0.4, 0) }, RA = { rot = V(30, 0, 40) }, LA = { rot = V(30, 0, -40) } }),
		P(0.2, { Root = { rot = V(-18, 60, 0), off = V(0, -0.9, 0) }, RL = { rot = V(80, 0, 30) }, LL = { rot = V(60, 0, -20) }, RA = { rot = V(-20, 0, 60) }, LA = { rot = V(40, 0, -60) }, Neck = { rot = V(0, 30, 0) } }, "out"),
		P(0.38, { Root = { rot = V(-14, 110, 0), off = V(0, -0.8, 0) }, RL = { rot = V(70, 0, 30) }, LL = { rot = V(60, 0, -20) }, RA = { rot = V(-10, 0, 50) }, LA = { rot = V(30, 0, -50) } }),
		P(0.55, GUARD, "inout"),
	},
}
C["Swift/TimeDome"] = { -- domínio: estala os dedos com o braço erguido (0,8 s)
	duration = 0.9,
	frames = {
		P(0, { RA = { rot = V(40, 0, 10) }, Root = { rot = V(-4, 0, 0) } }),
		P(0.3, { RA = { rot = V(175, 0, 10) }, LA = { rot = V(20, 0, -20) }, Root = { rot = V(6, -15, 0), off = V(0, 0.15, 0) }, Neck = { rot = V(12, 0, 0) } }, "out"),
		P(0.6, { RA = { rot = V(170, 0, 30) }, LA = { rot = V(20, 0, -20) }, Root = { rot = V(4, -10, 0), off = V(0, 0.1, 0) }, Neck = { rot = V(10, 0, 0) } }),
		P(0.9, {}, "inout"),
	},
}

-- Mystic
C["Mystic/ArcaneBolt"] = { -- empurra a mão para a frente (0,3 s)
	duration = 0.4,
	frames = {
		P(0, { RA = { rot = V(40, 0, 20) }, LA = { rot = V(30, 0, -10) }, Root = { rot = V(0, 20, 0) } }),
		P(0.12, { RA = { rot = V(95, 0, -4) }, LA = { rot = V(20, 0, -14) }, Root = { rot = V(-6, -14, 0), off = V(0, -0.05, -0.2) } }, "out"),
		P(0.4, {}, "inout"),
	},
}
C["Mystic/Mend"] = { -- cura: mãos ao peito e abre (0,6 s)
	duration = 0.8,
	frames = {
		P(0, { RA = { rot = V(70, -50, -30) }, LA = { rot = V(70, 50, 30) }, Neck = { rot = V(-14, 0, 0) }, Root = { rot = V(-6, 0, 0) } }),
		P(0.35, { RA = { rot = V(80, -55, -35) }, LA = { rot = V(80, 55, 35) }, Neck = { rot = V(-16, 0, 0) }, Root = { rot = V(-8, 0, 0), off = V(0, -0.1, 0) } }, "inout"),
		P(0.6, { RA = { rot = V(120, 0, 60) }, LA = { rot = V(120, 0, -60) }, Neck = { rot = V(12, 0, 0) }, Root = { rot = V(8, 0, 0), off = V(0, 0.15, 0) } }, "out"),
		P(0.8, {}, "inout"),
	},
}
C["Mystic/Meteor"] = { -- meteoro: ergue os dois braços ao céu e baixa apontando (0,8 s)
	duration = 1.2,
	frames = {
		P(0, { RA = { rot = V(60, 0, 20) }, LA = { rot = V(60, 0, -20) } }),
		P(0.35, { RA = { rot = V(185, 0, 30) }, LA = { rot = V(185, 0, -30) }, Root = { rot = V(14, 0, 0), off = V(0, 0.2, 0) }, Neck = { rot = V(22, 0, 0) } }, "out"),
		P(0.8, { RA = { rot = V(100, 0, 10) }, LA = { rot = V(100, 0, -10) }, Root = { rot = V(-10, 0, 0) }, Neck = { rot = V(-6, 0, 0) } }, "in"),
		P(1.2, {}, "inout"),
	},
}

-- Guardian
C["Guardian/ShieldBash"] = { -- investida com o escudo à frente (0,22 s)
	duration = 0.4,
	frames = {
		P(0, { LA = { rot = V(80, 0, -10) }, RA = { rot = V(20, 0, 20) }, Root = { rot = V(-8, -20, 0) } }),
		P(0.1, { LA = { rot = V(95, 0, 0) }, RA = { rot = V(10, 0, 26) }, Root = { rot = V(-24, -30, 0), off = V(0, -0.3, -0.4) }, Neck = { rot = V(8, 15, 0) }, RL = { rot = V(-22, 0, 6) }, LL = { rot = V(28, 0, -6) } }, "out"),
		P(0.4, { LA = { rot = V(90, 0, 0) }, RA = { rot = V(10, 0, 26) }, Root = { rot = V(-18, -24, 0), off = V(0, -0.25, -0.3) } }, "inout"),
	},
}
C["Guardian/ShieldBash_Carry"] = { -- ergue o alvo no escudo e esmaga (0,8 s)
	duration = 0.8,
	frames = {
		P(0, { LA = { rot = V(120, 0, -10) }, RA = { rot = V(40, 0, 20) }, Root = { rot = V(4, 0, 0) } }),
		P(0.5, { LA = { rot = V(175, 0, -10) }, RA = { rot = V(60, 0, 30) }, Root = { rot = V(12, 0, 0), off = V(0, 0.2, 0) }, Neck = { rot = V(18, 0, 0) } }, "inout"),
		P(0.8, { LA = { rot = V(30, 0, -10) }, RA = { rot = V(20, 0, 30) }, Root = { rot = V(-30, 0, 0), off = V(0, -0.7, -0.4) }, Neck = { rot = V(-14, 0, 0) }, RL = { rot = V(45, 0, 10) }, LL = { rot = V(45, 0, -10) } }, "in"),
	},
}
C["Guardian/Fortify"] = { -- fortificar: bate no peito e fecha a guarda (0,3 s)
	duration = 0.5,
	frames = {
		P(0, { RA = { rot = V(80, -40, -30) }, Root = { rot = V(6, 0, 0) } }),
		P(0.15, { RA = { rot = V(70, -60, -40) }, LA = { rot = V(40, 0, -20) }, Root = { rot = V(-6, 0, 0), off = V(0, -0.2, 0) }, Neck = { rot = V(-6, 0, 0) } }, "out"),
		P(0.5, GUARD, "inout"),
	},
}
C["Guardian/Quake"] = { -- terremoto: pula e crava os punhos, três batidas (1,2 s = 3 × 0,4)
	duration = 1.4,
	frames = {
		P(0, { RA = { rot = V(170, 0, 20) }, LA = { rot = V(170, 0, -20) }, Root = { rot = V(12, 0, 0), off = V(0, 0.3, 0) }, Neck = { rot = V(14, 0, 0) } }),
		P(0.4, { RA = { rot = V(15, 0, 14) }, LA = { rot = V(15, 0, -14) }, Root = { rot = V(-32, 0, 0), off = V(0, -0.8, -0.2) }, Neck = { rot = V(-14, 0, 0) }, RL = { rot = V(48, 0, 12) }, LL = { rot = V(48, 0, -12) } }, "in"),
		P(0.6, { RA = { rot = V(120, 0, 20) }, LA = { rot = V(120, 0, -20) }, Root = { rot = V(0, 0, 0), off = V(0, -0.2, 0) } }, "out"),
		P(0.8, { RA = { rot = V(15, 0, 14) }, LA = { rot = V(15, 0, -14) }, Root = { rot = V(-32, 0, 0), off = V(0, -0.8, -0.2) }, Neck = { rot = V(-14, 0, 0) }, RL = { rot = V(48, 0, 12) }, LL = { rot = V(48, 0, -12) } }, "in"),
		P(1.0, { RA = { rot = V(120, 0, 20) }, LA = { rot = V(120, 0, -20) }, Root = { rot = V(0, 0, 0), off = V(0, -0.2, 0) } }, "out"),
		P(1.2, { RA = { rot = V(15, 0, 14) }, LA = { rot = V(15, 0, -14) }, Root = { rot = V(-32, 0, 0), off = V(0, -0.8, -0.2) }, Neck = { rot = V(-14, 0, 0) }, RL = { rot = V(48, 0, 12) }, LL = { rot = V(48, 0, -12) } }, "in"),
		P(1.4, GUARD, "inout"),
	},
}

-- Sahur
C["Sahur/Bombo"] = { -- bombo: batida dupla no "tambor" à frente (0,5 s, impacto em 0,35)
	duration = 0.7,
	frames = {
		P(0, { RA = { rot = V(120, 0, 30) }, LA = { rot = V(60, 0, -20) }, Root = { rot = V(6, 0, 0) } }),
		P(0.18, { RA = { rot = V(50, 0, 10) }, LA = { rot = V(130, 0, -30) }, Root = { rot = V(-8, 0, 0), off = V(0, -0.15, 0) } }, "in"),
		P(0.35, { RA = { rot = V(45, 0, 10) }, LA = { rot = V(45, 0, -10) }, Root = { rot = V(-24, 0, 0), off = V(0, -0.5, -0.2) }, Neck = { rot = V(-10, 0, 0) }, RL = { rot = V(30, 0, 8) }, LL = { rot = V(30, 0, -8) } }, "in"),
		P(0.7, GUARD, "inout"),
	},
}
C["Sahur/Toque"] = { -- toque de guerra: braços abertos, peito estufado (0,6 s)
	duration = 0.8,
	frames = {
		P(0, { RA = { rot = V(60, 0, 40) }, LA = { rot = V(60, 0, -40) } }),
		P(0.3, { RA = { rot = V(40, 0, 100) }, LA = { rot = V(40, 0, -100) }, Root = { rot = V(14, 0, 0), off = V(0, 0.2, 0) }, Neck = { rot = V(18, 0, 0) } }, "out"),
		P(0.8, {}, "inout"),
	},
}
C["Sahur/Ritmo"] = { -- ritmo final: batidas alternadas rápidas (1,5 s = 6 × 0,25)
	duration = 1.7,
	frames = {
		P(0, { RA = { rot = V(130, 0, 30) }, LA = { rot = V(40, 0, -20) }, Root = { rot = V(-10, 10, 0), off = V(0, -0.3, 0) } }),
		P(0.25, { RA = { rot = V(40, 0, 20) }, LA = { rot = V(130, 0, -30) }, Root = { rot = V(-12, -10, 0), off = V(0, -0.35, 0) } }, "inout"),
		P(0.5, { RA = { rot = V(130, 0, 30) }, LA = { rot = V(40, 0, -20) }, Root = { rot = V(-10, 10, 0), off = V(0, -0.3, 0) } }, "inout"),
		P(0.75, { RA = { rot = V(40, 0, 20) }, LA = { rot = V(130, 0, -30) }, Root = { rot = V(-12, -10, 0), off = V(0, -0.35, 0) } }, "inout"),
		P(1.0, { RA = { rot = V(130, 0, 30) }, LA = { rot = V(40, 0, -20) }, Root = { rot = V(-10, 10, 0), off = V(0, -0.3, 0) } }, "inout"),
		P(1.25, { RA = { rot = V(40, 0, 20) }, LA = { rot = V(130, 0, -30) }, Root = { rot = V(-12, -10, 0), off = V(0, -0.35, 0) } }, "inout"),
		P(1.5, { RA = { rot = V(20, 0, 14) }, LA = { rot = V(20, 0, -14) }, Root = { rot = V(-28, 0, 0), off = V(0, -0.7, -0.3) }, Neck = { rot = V(-12, 0, 0) } }, "in"),
		P(1.7, GUARD, "inout"),
	},
}

-- Overlord (admin) — reaproveita
C["Overlord/Smite"] = C["Brawler/GroundSlam"]
C["Overlord/Warp"] = C["Swift/Blink"]
C["Overlord/Clutch"] = C["Guardian/ShieldBash"]
C["Overlord/Clutch_Carry"] = { -- giro: braços abertos rodando (1,6 s)
	duration = 1.6,
	loop = true,
	frames = {
		P(0, { RA = { rot = V(90, 0, 60) }, LA = { rot = V(90, 0, -60) }, Root = { rot = V(-6, 0, 0), off = V(0, -0.2, 0) } }),
		P(0.8, { RA = { rot = V(95, 0, 70) }, LA = { rot = V(95, 0, -70) }, Root = { rot = V(-8, 0, 0), off = V(0, -0.25, 0) } }, "inout"),
		P(1.6, { RA = { rot = V(90, 0, 60) }, LA = { rot = V(90, 0, -60) }, Root = { rot = V(-6, 0, 0), off = V(0, -0.2, 0) } }, "inout"),
	},
}
C["Overlord/Cataclysm"] = C["Brawler/Rampage"]

-- ---------------------------------------------------------------------------
-- DESPERTAR: poses por personagem (CutsceneController lê AwakeningPoses[CharacterId]; ausente = padrão)
-- Chaves: charge1, charge2, charge3, burst, stance
-- ---------------------------------------------------------------------------
local function pose(p: { [string]: JointPose }): Pose
	return P(0, p).pose
end
ProcAnimDefs.AwakeningPoses = {
	Brawler = { -- punhos cerrados para baixo, tremendo; estoura de braços abertos
		charge1 = pose({ Root = { rot = V(-10, 0, 0), off = V(0, -0.3, 0) }, Neck = { rot = V(-16, 0, 0) }, RA = { rot = V(-20, 0, 18) }, LA = { rot = V(-20, 0, -18) }, RL = { rot = V(0, 0, 14) }, LL = { rot = V(0, 0, -14) } }),
		charge2 = pose({ Root = { rot = V(-18, 0, 0), off = V(0, -0.5, 0) }, Neck = { rot = V(-26, 0, 0) }, RA = { rot = V(-35, 0, 26) }, LA = { rot = V(-35, 0, -26) }, RL = { rot = V(0, 0, 20) }, LL = { rot = V(0, 0, -20) } }),
		charge3 = pose({ Root = { rot = V(-8, 0, 0), off = V(0, -0.35, 0) }, Neck = { rot = V(8, 0, 0) }, RA = { rot = V(-10, 0, 40) }, LA = { rot = V(-10, 0, -40) }, RL = { rot = V(0, 0, 18) }, LL = { rot = V(0, 0, -18) } }),
		burst = pose({ Root = { rot = V(14, 0, 0), off = V(0, 0.45, 0) }, Neck = { rot = V(28, 0, 0) }, RA = { rot = V(40, 0, 95) }, LA = { rot = V(40, 0, -95) }, RL = { rot = V(0, 0, 10) }, LL = { rot = V(0, 0, -10) } }),
		stance = pose({ Root = { rot = V(-6, 0, 0) }, RA = { rot = V(60, 0, 20) }, LA = { rot = V(75, 0, -30) }, RL = { rot = V(0, 0, 10) }, LL = { rot = V(0, 0, -10) } }),
	},
	Swift = { -- agachado como corredor; estoura esticado
		charge1 = pose({ Root = { rot = V(-20, 0, 0), off = V(0, -0.5, 0) }, Neck = { rot = V(10, 0, 0) }, RA = { rot = V(-30, 0, 10) }, LA = { rot = V(50, 0, -10) }, RL = { rot = V(30, 0, 6) }, LL = { rot = V(-20, 0, -6) } }),
		charge2 = pose({ Root = { rot = V(-30, 0, 0), off = V(0, -0.8, 0) }, Neck = { rot = V(16, 0, 0) }, RA = { rot = V(-45, 0, 14) }, LA = { rot = V(60, 0, -12) }, RL = { rot = V(40, 0, 6) }, LL = { rot = V(-26, 0, -6) } }),
		charge3 = pose({ Root = { rot = V(-36, 0, 0), off = V(0, -0.9, 0) }, Neck = { rot = V(20, 0, 0) }, RA = { rot = V(-55, 0, 16) }, LA = { rot = V(70, 0, -12) }, RL = { rot = V(46, 0, 6) }, LL = { rot = V(-30, 0, -6) } }),
		burst = pose({ Root = { rot = V(10, 0, 0), off = V(0, 0.6, 0) }, Neck = { rot = V(20, 0, 0) }, RA = { rot = V(170, 0, 40) }, LA = { rot = V(170, 0, -40) }, RL = { rot = V(-10, 0, 8) }, LL = { rot = V(10, 0, -8) } }),
		stance = pose({ Root = { rot = V(-10, 20, 0), off = V(0, -0.2, 0) }, RA = { rot = V(30, 0, 30) }, LA = { rot = V(80, 0, -20) }, RL = { rot = V(12, 0, 8) }, LL = { rot = V(-12, 0, -8) } }),
	},
	Mystic = { -- braços erguidos conjurando; estoura de braços em cruz
		charge1 = pose({ Root = { rot = V(-4, 0, 0) }, Neck = { rot = V(10, 0, 0) }, RA = { rot = V(120, 0, 30) }, LA = { rot = V(120, 0, -30) } }),
		charge2 = pose({ Root = { rot = V(-8, 0, 0), off = V(0, -0.2, 0) }, Neck = { rot = V(18, 0, 0) }, RA = { rot = V(150, 0, 40) }, LA = { rot = V(150, 0, -40) } }),
		charge3 = pose({ Root = { rot = V(-12, 0, 0), off = V(0, -0.35, 0) }, Neck = { rot = V(-10, 0, 0) }, RA = { rot = V(90, -40, -20) }, LA = { rot = V(90, 40, 20) } }),
		burst = pose({ Root = { rot = V(12, 0, 0), off = V(0, 0.5, 0) }, Neck = { rot = V(26, 0, 0) }, RA = { rot = V(185, 0, 45) }, LA = { rot = V(185, 0, -45) } }),
		stance = pose({ Root = { rot = V(-4, 0, 0) }, RA = { rot = V(70, -30, -10) }, LA = { rot = V(50, 0, -40) } }),
	},
	Guardian = { -- postura de escudo, pés fincados; estoura batendo no chão
		charge1 = pose({ Root = { rot = V(-10, 0, 0), off = V(0, -0.35, 0) }, LA = { rot = V(90, 0, -10) }, RA = { rot = V(-20, 0, 24) }, RL = { rot = V(0, 0, 22) }, LL = { rot = V(0, 0, -22) } }),
		charge2 = pose({ Root = { rot = V(-16, 0, 0), off = V(0, -0.55, 0) }, LA = { rot = V(100, 0, -10) }, RA = { rot = V(-30, 0, 30) }, RL = { rot = V(0, 0, 26) }, LL = { rot = V(0, 0, -26) }, Neck = { rot = V(-10, 0, 0) } }),
		charge3 = pose({ Root = { rot = V(10, 0, 0), off = V(0, 0.2, 0) }, LA = { rot = V(120, 0, -10) }, RA = { rot = V(175, 0, 30) }, Neck = { rot = V(14, 0, 0) } }),
		burst = pose({ Root = { rot = V(-30, 0, 0), off = V(0, -0.8, -0.2) }, Neck = { rot = V(-12, 0, 0) }, RA = { rot = V(20, 0, 14) }, LA = { rot = V(90, 0, -10) }, RL = { rot = V(48, 0, 14) }, LL = { rot = V(48, 0, -14) } }),
		stance = pose({ Root = { rot = V(-6, 0, 0), off = V(0, -0.15, 0) }, LA = { rot = V(90, 0, -6) }, RA = { rot = V(30, 0, 24) }, RL = { rot = V(0, 0, 14) }, LL = { rot = V(0, 0, -14) } }),
	},
	Sahur = { -- braços de tambor batendo; estoura com os braços ao alto
		charge1 = pose({ Root = { rot = V(-8, 0, 0), off = V(0, -0.2, 0) }, RA = { rot = V(120, 0, 30) }, LA = { rot = V(50, 0, -20) } }),
		charge2 = pose({ Root = { rot = V(-10, 0, 0), off = V(0, -0.3, 0) }, RA = { rot = V(50, 0, 20) }, LA = { rot = V(125, 0, -30) } }),
		charge3 = pose({ Root = { rot = V(-14, 0, 0), off = V(0, -0.4, 0) }, RA = { rot = V(130, 0, 34) }, LA = { rot = V(130, 0, -34) }, Neck = { rot = V(-8, 0, 0) } }),
		burst = pose({ Root = { rot = V(14, 0, 0), off = V(0, 0.5, 0) }, Neck = { rot = V(26, 0, 0) }, RA = { rot = V(180, 0, 60) }, LA = { rot = V(180, 0, -60) } }),
		stance = pose({ Root = { rot = V(-6, 10, 0) }, RA = { rot = V(90, 0, 30) }, LA = { rot = V(60, 0, -30) } }),
	},
}

-- ---------------------------------------------------------------------------
-- CUTSCENE do despertar: poses padrão continuam no CutsceneController
-- ---------------------------------------------------------------------------

function ProcAnimDefs.Get(key: string): Clip?
	return C[key]
end

return ProcAnimDefs
