--!strict
--[[
	ProcAnimDefs
	Animações PROCEDURAIS (keyframes de pose por junta R6, ver RigPose) para cada ação do jogo, com a
	duração casada com o tempo real da ação (CombatConfig: soco = HitDelay 0,15 s + Cooldown 0,3 s;
	dash = 0,24 × 1,4; etc.). Tocadas pelo ProcAnimController via FX.PlayAnimation:
	  - chave = "<Pasta>/<Nome>" igual a Assets.Animations (Shared/M1_1, Swift/Blink…)
	  - `team = true` = se a equipe colou um id em Animations.model.json, toca o dela em vez desta
	    (padrão false: a procedural manda, mesmo com id — decisão do dono 2026-09-17, as dos packs
	    têm tempo errado). Idle/Walk/Run também são procedurais (seção LOCOMOÇÃO, Leva 8): cada
	    personagem tem o seu jeito de ficar parado/andar/correr, tocado como camada de BASE.
	  - Quem não tem clipe próprio "<Personagem>/<Nome>" ganha uma VARIAÇÃO do Shared pelo estilo do
	    personagem (ProcAnimDefs.Styles + Resolve): nada fica igual entre personagens.
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
-- EMOTES / CENAS (Leva 4) — roda B. Andar cancela (CosmeticsController)
-- ---------------------------------------------------------------------------
C["Emotes/wave"] = { -- acenar: braço direito alto balançando 2×
	duration = 2.0,
	frames = {
		P(0, {}),
		P(0.3, { RA = { rot = V(170, 0, 30) }, Neck = { rot = V(0, -10, 0) }, Root = { rot = V(0, -8, 0) } }, "out"),
		P(0.6, { RA = { rot = V(175, 0, 55) }, Neck = { rot = V(0, -12, 0) }, Root = { rot = V(0, -8, 0) } }, "inout"),
		P(0.9, { RA = { rot = V(170, 0, 25) }, Neck = { rot = V(0, -8, 0) }, Root = { rot = V(0, -8, 0) } }, "inout"),
		P(1.2, { RA = { rot = V(175, 0, 55) }, Neck = { rot = V(0, -12, 0) }, Root = { rot = V(0, -8, 0) } }, "inout"),
		P(1.5, { RA = { rot = V(170, 0, 25) }, Neck = { rot = V(0, -8, 0) }, Root = { rot = V(0, -8, 0) } }, "inout"),
		P(2.0, {}, "inout"),
	},
}
C["Emotes/taunt"] = { -- provocar: "vem" com a mão, cabeça inclinada
	duration = 2.4,
	frames = {
		P(0, {}),
		P(0.3, { RA = { rot = V(80, 0, 10) }, Neck = { rot = V(-8, 0, 14) }, Root = { rot = V(6, 0, 0), off = V(0, 0.05, 0) } }, "out"),
		P(0.6, { RA = { rot = V(60, 0, -10) }, Neck = { rot = V(-8, 0, 14) }, Root = { rot = V(6, 0, 0) } }, "inout"),
		P(0.9, { RA = { rot = V(85, 0, 10) }, Neck = { rot = V(-8, 0, 14) }, Root = { rot = V(6, 0, 0) } }, "inout"),
		P(1.2, { RA = { rot = V(60, 0, -10) }, Neck = { rot = V(-8, 0, 14) }, Root = { rot = V(6, 0, 0) } }, "inout"),
		P(1.5, { RA = { rot = V(85, 0, 10) }, Neck = { rot = V(-8, 0, 14) }, Root = { rot = V(6, 0, 0) } }, "inout"),
		P(1.9, { RA = { rot = V(20, 0, 30) }, LA = { rot = V(20, 0, -30) }, Neck = { rot = V(14, 0, 0) }, Root = { rot = V(10, 0, 0), off = V(0, 0.1, 0) } }, "out"),
		P(2.4, {}, "inout"),
	},
}
C["Emotes/dance"] = { -- dançar: quadril e braços alternando, 3 ciclos de 1,6 s
	duration = 4.8,
	frames = (function()
		local frames: { Frame } = {}
		local A: { [string]: JointPose } = { Root = { rot = V(0, -14, 6), off = V(0, -0.15, 0) }, RA = { rot = V(120, 0, 40) }, LA = { rot = V(20, 0, -40) }, Neck = { rot = V(0, 10, -6) }, RL = { rot = V(0, 0, 10) } }
		local B: { [string]: JointPose } = { Root = { rot = V(0, 0, 0), off = V(0, 0.05, 0) }, RA = { rot = V(70, 0, 60) }, LA = { rot = V(70, 0, -60) }, Neck = { rot = V(-6, 0, 0) } }
		local Cc: { [string]: JointPose } = { Root = { rot = V(0, 14, -6), off = V(0, -0.15, 0) }, RA = { rot = V(20, 0, 40) }, LA = { rot = V(120, 0, -40) }, Neck = { rot = V(0, -10, 6) }, LL = { rot = V(0, 0, -10) } }
		for cycle = 0, 2 do
			local t0 = cycle * 1.6
			table.insert(frames, P(t0, A, "inout"))
			table.insert(frames, P(t0 + 0.4, B, "inout"))
			table.insert(frames, P(t0 + 0.8, Cc, "inout"))
			table.insert(frames, P(t0 + 1.2, B, "inout"))
		end
		table.insert(frames, P(4.8, {}, "inout"))
		return frames
	end)(),
}
C["Emotes/bow"] = { -- reverência: curva o tronco com o braço no peito
	duration = 2.2,
	frames = {
		P(0, {}),
		P(0.5, { Root = { rot = V(-40, 0, 0), off = V(0, -0.2, 0.2) }, Neck = { rot = V(-10, 0, 0) }, RA = { rot = V(70, -50, -30) }, LA = { rot = V(-20, 0, -20) } }, "inout"),
		P(1.5, { Root = { rot = V(-42, 0, 0), off = V(0, -0.2, 0.2) }, Neck = { rot = V(-10, 0, 0) }, RA = { rot = V(70, -50, -30) }, LA = { rot = V(-20, 0, -20) } }),
		P(2.2, {}, "inout"),
	},
}
C["Emotes/flex"] = { -- músculo: braços dobrados para cima, alternando o lado
	duration = 2.6,
	frames = {
		P(0, {}),
		P(0.4, { RA = { rot = V(90, 0, 90) }, LA = { rot = V(90, 0, -90) }, Root = { rot = V(6, 0, 0), off = V(0, 0.05, 0) }, Neck = { rot = V(6, 0, 0) } }, "out"),
		P(0.8, { RA = { rot = V(100, 0, 100) }, LA = { rot = V(100, 0, -100) }, Root = { rot = V(8, -20, 0) }, Neck = { rot = V(4, 20, 0) } }, "inout"),
		P(1.4, { RA = { rot = V(100, 0, 100) }, LA = { rot = V(100, 0, -100) }, Root = { rot = V(8, 20, 0) }, Neck = { rot = V(4, -20, 0) } }, "inout"),
		P(2.0, { RA = { rot = V(100, 0, 100) }, LA = { rot = V(100, 0, -100) }, Root = { rot = V(8, 0, 0) }, Neck = { rot = V(6, 0, 0) } }, "inout"),
		P(2.6, {}, "inout"),
	},
}
C["Emotes/scene_power"] = { -- cena: despertar (carrega curvado e explode de braços abertos, 5 s)
	duration = 5.0,
	frames = {
		P(0, {}),
		P(0.8, { Root = { rot = V(-14, 0, 0), off = V(0, -0.4, 0) }, Neck = { rot = V(-20, 0, 0) }, RA = { rot = V(-25, 0, 16) }, LA = { rot = V(-25, 0, -16) }, RL = { rot = V(0, 0, 16) }, LL = { rot = V(0, 0, -16) } }, "inout"),
		P(2.2, { Root = { rot = V(-20, 0, 0), off = V(0, -0.55, 0) }, Neck = { rot = V(-28, 0, 0) }, RA = { rot = V(-40, 0, 24) }, LA = { rot = V(-40, 0, -24) }, RL = { rot = V(0, 0, 20) }, LL = { rot = V(0, 0, -20) } }, "inout"),
		P(2.6, { Root = { rot = V(14, 0, 0), off = V(0, 0.45, 0) }, Neck = { rot = V(28, 0, 0) }, RA = { rot = V(40, 0, 90) }, LA = { rot = V(40, 0, -90) }, RL = { rot = V(0, 0, 10) }, LL = { rot = V(0, 0, -10) } }, "out"),
		P(4.4, { Root = { rot = V(10, 0, 0), off = V(0, 0.35, 0) }, Neck = { rot = V(24, 0, 0) }, RA = { rot = V(45, 0, 85) }, LA = { rot = V(45, 0, -85) }, RL = { rot = V(0, 0, 10) }, LL = { rot = V(0, 0, -10) } }),
		P(5.0, {}, "inout"),
	},
}
C["Emotes/scene_dark"] = { -- cena: trevas (cabeça baixa, mão erguida fechando devagar, 5 s)
	duration = 5.0,
	frames = {
		P(0, {}),
		P(0.8, { Root = { rot = V(-8, 0, 0) }, Neck = { rot = V(-30, 0, 0) }, RA = { rot = V(100, 0, -10) }, LA = { rot = V(-10, 0, -10) } }, "inout"),
		P(2.6, { Root = { rot = V(-10, 0, 0) }, Neck = { rot = V(-32, 0, 0) }, RA = { rot = V(115, 0, -14) }, LA = { rot = V(-10, 0, -10) } }, "inout"),
		P(3.2, { Root = { rot = V(8, 0, 0), off = V(0, 0.1, 0) }, Neck = { rot = V(16, 0, 0) }, RA = { rot = V(140, 0, -20) }, LA = { rot = V(-10, 0, -10) } }, "out"),
		P(4.4, { Root = { rot = V(8, 0, 0), off = V(0, 0.1, 0) }, Neck = { rot = V(16, 0, 0) }, RA = { rot = V(140, 0, -20) }, LA = { rot = V(-10, 0, -10) } }),
		P(5.0, {}, "inout"),
	},
}
C["Emotes/scene_storm"] = { -- cena: tempestade (braços ao céu, gira o tronco, 5 s)
	duration = 5.0,
	frames = {
		P(0, {}),
		P(0.7, { Root = { rot = V(10, -20, 0), off = V(0, 0.2, 0) }, Neck = { rot = V(24, 0, 0) }, RA = { rot = V(175, 0, 40) }, LA = { rot = V(175, 0, -40) } }, "out"),
		P(2.0, { Root = { rot = V(12, 20, 0), off = V(0, 0.25, 0) }, Neck = { rot = V(26, 0, 0) }, RA = { rot = V(180, 0, 50) }, LA = { rot = V(180, 0, -50) } }, "inout"),
		P(3.3, { Root = { rot = V(12, -20, 0), off = V(0, 0.25, 0) }, Neck = { rot = V(26, 0, 0) }, RA = { rot = V(180, 0, 50) }, LA = { rot = V(180, 0, -50) } }, "inout"),
		P(4.3, { Root = { rot = V(-20, 0, 0), off = V(0, -0.4, -0.2) }, Neck = { rot = V(-12, 0, 0) }, RA = { rot = V(30, 0, 20) }, LA = { rot = V(30, 0, -20) } }, "in"),
		P(5.0, {}, "inout"),
	},
}

-- ---------------------------------------------------------------------------
-- LOCOMOÇÃO (Leva 8): Idle/Walk/Run PROCEDURAIS, um jeito por personagem.
-- O ProcAnimController mantém isso como camada de BASE (por baixo dos socos/habilidades) em todo
-- personagem que o cliente vê, escolhendo Idle/Walk/Run pela velocidade e acelerando o ciclo junto.
-- `Locomotion.Enabled = false` devolve tudo para as animações da equipe (MovementController).
-- ---------------------------------------------------------------------------
ProcAnimDefs.Locomotion = {
	Enabled = true,
	WalkThreshold = 1.5, -- studs/s a partir de onde deixa de ser Idle
	RunThreshold = 19, -- acima disso vira Run (corrida = WalkSpeed 24 no CombatConfig)
	WalkReference = 16, -- velocidade em que o ciclo do Walk toca em 1×
	RunReference = 24,
}

type Loco = {
	-- Idle
	idleCycle: number,
	breath: number, -- quanto o tronco sobe/desce respirando (studs)
	idleLean: number, -- inclinação do tronco parado (graus; − = para a frente)
	idleSway: number, -- balanço lateral do corpo parado
	idleArm: Vector3, -- repouso do braço direito (o esquerdo é espelhado no Z)
	idleHead: Vector3,
	idleLegOut: number, -- afastamento dos pés
	idleAccentR: Vector3?, -- tempero que aparece no meio do ciclo (braço direito)
	idleAccentL: Vector3?,
	-- Walk / Run
	walkCycle: number,
	walkLeg: number,
	walkArm: number,
	walkArmOut: number,
	walkLean: number,
	walkBob: number,
	walkSway: number,
	walkTwist: number, -- quanto o tronco gira acompanhando o passo
	runCycle: number,
	runLeg: number,
	runArm: number,
	runLean: number,
	runBob: number,
	runTwist: number,
}

local function vadd(a: Vector3, b: Vector3?): Vector3
	return if b then a + b else a
end

--- Monta Idle/Walk/Run (loops) de um personagem a partir do jeito dele de se mexer.
local function locomotion(p: Loco): { [string]: Clip }
	local ic = p.idleCycle
	local armR, armL = p.idleArm, V(p.idleArm.X, -p.idleArm.Y, -p.idleArm.Z)
	local legR, legL = V(0, 0, p.idleLegOut), V(0, 0, -p.idleLegOut)
	local function idleFrame(t: number, k: number, accent: boolean, ease: string?): Frame
		-- k = −1..1: fase da respiração (1 = peito cheio)
		local up = p.breath * k
		return P(t, {
			Root = { rot = V(p.idleLean - 1.2 * k, 0, p.idleSway * k), off = V(0, up, 0) },
			Neck = { rot = p.idleHead + V(1.5 * k, p.idleSway * 1.5 * k, 0) },
			RA = { rot = vadd(armR + V(-2 * k, 0, 1.5 * k), if accent then p.idleAccentR else nil) },
			LA = { rot = vadd(armL + V(-2 * k, 0, -1.5 * k), if accent then p.idleAccentL else nil) },
			RL = { rot = legR },
			LL = { rot = legL },
		}, ease)
	end
	local idle: Clip = {
		duration = ic,
		loop = true,
		frames = {
			idleFrame(0, -1, false),
			idleFrame(ic * 0.3, 1, false, "inout"),
			idleFrame(ic * 0.55, -0.4, true, "inout"),
			idleFrame(ic * 0.8, 0.6, true, "inout"),
			idleFrame(ic, -1, false, "inout"),
		},
	}

	--- Um passo: `s` = +1 (perna direita à frente) ou −1 (espelho); `pass` = pé passando (pernas juntas).
	local function step(t: number, s: number, cycleLeg: number, cycleArm: number, lean: number, bob: number, twist: number, pass: boolean, ease: string?): Frame
		local leg = if pass then 0 else cycleLeg * s
		local arm = if pass then 0 else cycleArm * s
		return P(t, {
			Root = {
				rot = V(lean, twist * s, (if pass then 0 else p.walkSway * s)),
				off = V(0, (if pass then bob else -bob * 0.4), 0),
			},
			Neck = { rot = V(-lean * 0.35, -twist * 0.6 * s, 0) },
			RA = { rot = V(-arm, 0, p.walkArmOut) },
			LA = { rot = V(arm, 0, -p.walkArmOut) },
			RL = { rot = V(leg, 0, p.idleLegOut * 0.6) },
			LL = { rot = V(-leg, 0, -p.idleLegOut * 0.6) },
		}, ease)
	end

	local wc = p.walkCycle
	local walk: Clip = {
		duration = wc,
		loop = true,
		frames = {
			step(0, 1, p.walkLeg, p.walkArm, p.walkLean, p.walkBob, p.walkTwist, false),
			step(wc * 0.25, 1, p.walkLeg, p.walkArm, p.walkLean, p.walkBob, p.walkTwist, true, "inout"),
			step(wc * 0.5, -1, p.walkLeg, p.walkArm, p.walkLean, p.walkBob, p.walkTwist, false, "inout"),
			step(wc * 0.75, -1, p.walkLeg, p.walkArm, p.walkLean, p.walkBob, p.walkTwist, true, "inout"),
			step(wc, 1, p.walkLeg, p.walkArm, p.walkLean, p.walkBob, p.walkTwist, false, "inout"),
		},
	}
	local rc = p.runCycle
	local run: Clip = {
		duration = rc,
		loop = true,
		frames = {
			step(0, 1, p.runLeg, p.runArm, p.runLean, p.runBob, p.runTwist, false),
			step(rc * 0.25, 1, p.runLeg, p.runArm, p.runLean, p.runBob, p.runTwist, true, "inout"),
			step(rc * 0.5, -1, p.runLeg, p.runArm, p.runLean, p.runBob, p.runTwist, false, "inout"),
			step(rc * 0.75, -1, p.runLeg, p.runArm, p.runLean, p.runBob, p.runTwist, true, "inout"),
			step(rc, 1, p.runLeg, p.runArm, p.runLean, p.runBob, p.runTwist, false, "inout"),
		},
	}
	return { Idle = idle, Walk = walk, Run = run }
end

-- Base (quem não tem personagem definido): postura neutra que respira
local LOCO_DEFS: { [string]: Loco } = {
	Shared = {
		idleCycle = 3.6, breath = 0.09, idleLean = -2, idleSway = 1.2,
		idleArm = V(6, 0, 7), idleHead = V(0, 0, 0), idleLegOut = 3,
		walkCycle = 1.0, walkLeg = 26, walkArm = 22, walkArmOut = 6, walkLean = -6, walkBob = 0.12, walkSway = 2, walkTwist = 5,
		runCycle = 0.66, runLeg = 42, runArm = 46, runLean = -14, runBob = 0.2, runTwist = 9,
	},
	-- Brawler: pesado, ombros largos, gingado de boxeador; corre socando o ar
	Brawler = {
		idleCycle = 3.0, breath = 0.14, idleLean = -5, idleSway = 2.4,
		idleArm = V(14, 0, 16), idleHead = V(-3, 0, 0), idleLegOut = 6,
		idleAccentR = V(10, 0, 4), idleAccentL = V(8, 0, -4), -- ergue a guarda de vez em quando
		walkCycle = 1.05, walkLeg = 24, walkArm = 18, walkArmOut = 15, walkLean = -8, walkBob = 0.16, walkSway = 4, walkTwist = 7,
		runCycle = 0.62, runLeg = 40, runArm = 52, runLean = -18, runBob = 0.26, runTwist = 12,
	},
	-- Swift: leve, na ponta dos pés, tronco à frente; corre com os braços baixos e soltos
	Swift = {
		idleCycle = 2.2, breath = 0.07, idleLean = -8, idleSway = 3.2,
		idleArm = V(-6, 0, 5), idleHead = V(4, 0, 0), idleLegOut = 2,
		idleAccentR = V(-8, 0, 2), idleAccentL = V(12, 0, -2), -- troca o peso de pé
		walkCycle = 0.8, walkLeg = 30, walkArm = 26, walkArmOut = 4, walkLean = -10, walkBob = 0.1, walkSway = 2, walkTwist = 4,
		runCycle = 0.46, runLeg = 52, runArm = 30, runLean = -26, runBob = 0.14, runTwist = 6,
	},
	-- Mystic: quase flutuando, braços à frente como se segurasse algo; passo curto e suave
	Mystic = {
		idleCycle = 4.4, breath = 0.12, idleLean = 2, idleSway = 1.0,
		idleArm = V(28, 0, 10), idleHead = V(3, 0, 0), idleLegOut = 2,
		idleAccentR = V(14, -10, -6), idleAccentL = V(6, 8, 6), -- desenha algo no ar
		walkCycle = 1.15, walkLeg = 20, walkArm = 10, walkArmOut = 10, walkLean = -3, walkBob = 0.08, walkSway = 1, walkTwist = 3,
		runCycle = 0.72, runLeg = 34, runArm = 22, runLean = -12, runBob = 0.16, runTwist = 6,
	},
	-- Guardian: firme, pés fincados, escudo (braço esquerdo) sempre erguido; passo militar
	Guardian = {
		idleCycle = 3.8, breath = 0.1, idleLean = -3, idleSway = 0.8,
		idleArm = V(10, 0, 12), idleHead = V(-2, 0, 0), idleLegOut = 7,
		idleAccentR = V(4, 0, 6), idleAccentL = V(34, 0, -6), -- ajeita o escudo
		walkCycle = 1.2, walkLeg = 22, walkArm = 12, walkArmOut = 12, walkLean = -4, walkBob = 0.2, walkSway = 3, walkTwist = 3,
		runCycle = 0.78, runLeg = 34, runArm = 26, runLean = -12, runBob = 0.28, runTwist = 7,
	},
	-- Sahur: ritmado, batendo o compasso; anda gingando como quem toca tambor
	Sahur = {
		idleCycle = 2.6, breath = 0.1, idleLean = -2, idleSway = 3.6,
		idleArm = V(34, 0, 14), idleHead = V(0, 0, 0), idleLegOut = 4,
		idleAccentR = V(26, 0, 6), idleAccentL = V(-14, 0, -6), -- toque no ar, alternado
		walkCycle = 0.92, walkLeg = 28, walkArm = 24, walkArmOut = 13, walkLean = -5, walkBob = 0.18, walkSway = 5, walkTwist = 9,
		runCycle = 0.58, runLeg = 44, runArm = 48, runLean = -16, runBob = 0.24, runTwist = 13,
	},
	-- Overlord: postura de quem não corre de ninguém; ombros para trás, passo largo e lento
	Overlord = {
		idleCycle = 4.0, breath = 0.13, idleLean = 4, idleSway = 1.6,
		idleArm = V(-10, 0, 18), idleHead = V(-6, 0, 0), idleLegOut = 6,
		idleAccentR = V(6, 0, 10), idleAccentL = V(-4, 0, -12),
		walkCycle = 1.3, walkLeg = 24, walkArm = 14, walkArmOut = 17, walkLean = 2, walkBob = 0.14, walkSway = 4, walkTwist = 8,
		runCycle = 0.8, runLeg = 38, runArm = 34, runLean = -10, runBob = 0.22, runTwist = 11,
	},
}
for charId, def in LOCO_DEFS do
	for name, clip in locomotion(def) do
		C[charId .. "/" .. name] = clip
	end
end

-- ---------------------------------------------------------------------------
-- ESTILO por personagem (Leva 8): quem não tem clipe próprio de uma ação ganha uma VARIAÇÃO do
-- clipe Shared — amplitude, postura e tempero de braço diferentes, para nada ficar igual entre
-- personagens. `ProcAnimDefs.Resolve("Shared/M1_1", "Swift")` devolve a variação (em cache).
-- ---------------------------------------------------------------------------
export type Style = {
	amp: number, -- multiplica as rotações do clipe (força do gesto)
	off: number, -- multiplica os deslocamentos do corpo
	lean: number, -- graus somados ao tronco durante o clipe (− = mais à frente)
	twist: number, -- giro extra do tronco
	head: number, -- inclinação extra da cabeça
	accentR: Vector3?, -- tempero somado ao braço direito (só onde o clipe já mexe nele)
	accentL: Vector3?,
}
ProcAnimDefs.Styles = {
	Brawler = { amp = 1.15, off = 1.2, lean = -4, twist = 4, head = -3, accentR = V(0, 0, 8), accentL = V(0, 0, -8) },
	Swift = { amp = 0.88, off = 0.9, lean = -7, twist = 8, head = 4, accentR = V(-6, 0, 0), accentL = V(-6, 0, 0) },
	Mystic = { amp = 0.92, off = 0.85, lean = 3, twist = -5, head = 3, accentR = V(10, -8, 0), accentL = V(6, 8, 0) },
	Guardian = { amp = 1.08, off = 0.8, lean = -2, twist = -3, head = -2, accentR = V(0, 0, 6), accentL = V(16, 0, -4) },
	Sahur = { amp = 1.05, off = 1.1, lean = -1, twist = 10, head = 2, accentR = V(8, 0, 4), accentL = V(-8, 0, -4) },
	Overlord = { amp = 1.2, off = 1.05, lean = 4, twist = -6, head = -5, accentR = V(-6, 0, 10), accentL = V(-6, 0, -10) },
} :: { [string]: Style }

local function styled(clip: Clip, s: Style): Clip
	local frames: { Frame } = {}
	for i, f in clip.frames do
		local pose: Pose = {}
		for joint, jp in f.pose do
			local rot = (jp.rot or Vector3.zero) * s.amp
			local off = (jp.off or Vector3.zero) * s.off
			if joint == J.Root then
				rot += V(s.lean, s.twist, 0)
			elseif joint == J.Neck then
				rot += V(s.head, 0, 0)
			elseif joint == J.RA and s.accentR then
				rot += s.accentR
			elseif joint == J.LA and s.accentL then
				rot += s.accentL
			end
			pose[joint] = { rot = rot, off = off }
		end
		frames[i] = { t = f.t, pose = pose, ease = f.ease }
	end
	return { duration = clip.duration, frames = frames, loop = clip.loop, blendOut = clip.blendOut, team = clip.team, upperOnly = clip.upperOnly }
end

local styleCache: { [string]: Clip } = {}

--- Clipe da ação `key` ("Pasta/Nome") para o personagem `charId`:
---   1) clipe próprio "<charId>/<Nome>"  2) variação de estilo do Shared  3) o Shared cru.
function ProcAnimDefs.Resolve(key: string, charId: string?): Clip?
	local own = if charId then C[charId .. "/" .. (key:match("/(.+)$") or key)] else nil
	if own then
		return own
	end
	local base = C[key]
	if not base or not charId or not key:match("^Shared/") then
		return base
	end
	local style = ProcAnimDefs.Styles[charId]
	if not style then
		return base
	end
	local cacheKey = charId .. "|" .. key
	local cached = styleCache[cacheKey]
	if not cached then
		cached = styled(base, style)
		styleCache[cacheKey] = cached
	end
	return cached
end

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
