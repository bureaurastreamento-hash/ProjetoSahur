#!/usr/bin/env python3
"""
Gera os VFX das habilidades em src/assets/VFX/<Personagem>/<Nome>.model.json.

Uso: python3 tools/gerar_vfx.py

Só usa texturas embutidas do engine (rbxasset://textures/particles/*) e Parts Neon,
nada de asset de terceiros. Cada VFX é um Model com:
  - ParticleEmitters com atributo EmitCount (rajada única) ou EmitDuration (aura)
  - Parts Neon com TweenScale/TweenTime (anéis/esferas que crescem e somem)
  - atributo Lifetime no Model quando precisa viver mais que FX.VFXLifetime
Ver FX.SpawnVFX para a semântica dos atributos. Um VFX com o mesmo nome feito pela
equipe no Studio substitui o gerado (Rojo não sobrescreve o que não está aqui).
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "src" / "assets" / "VFX"

SPARK = "rbxasset://textures/particles/sparkles_main.dds"
SMOKE = "rbxasset://textures/particles/smoke_main.dds"
FIRE = "rbxasset://textures/particles/fire_main.dds"
EXPLOSION = "rbxasset://textures/particles/explosion01_core_main.dds"
IMPLOSION = "rbxasset://textures/particles/explosion01_implosion_main.dds"


def cseq(*stops):
    """stops: (t, (r,g,b)) ..."""
    return {"ColorSequence": {"keypoints": [{"time": t, "color": list(c)} for t, c in stops]}}


def nseq(*stops):
    """stops: (t, value) ..."""
    return {"NumberSequence": {"keypoints": [{"time": t, "value": v, "envelope": 0} for t, v in stops]}}


def rng(a, b=None):
    return {"NumberRange": [a, b if b is not None else a]}


def emitter(name, texture, color, size, lifetime, speed, count, spread=(180, 180), light=1, accel=(0, 0, 0),
            drag=0, rot=(-180, 180), rotspeed=(-90, 90), transparency=None, duration=None, orientation=None,
            zoffset=0, brightness=1.5, squash=None, shape=None, shape_style=None, direction=None):
    props = {
        "Rate": 0,
        "Texture": texture,
        "Color": color,
        "Size": size,
        "Lifetime": rng(*lifetime),
        "Speed": rng(*speed),
        "SpreadAngle": {"Vector2": list(spread)},
        "LightEmission": light,
        "Brightness": brightness,
        "Acceleration": list(accel),
        "Drag": drag,
        "Rotation": rng(*rot),
        "RotSpeed": rng(*rotspeed),
        "Transparency": transparency or nseq((0, 0.1), (0.7, 0.4), (1, 1)),
        "ZOffset": zoffset,
    }
    if orientation:
        props["Orientation"] = orientation
    if direction:
        props["EmissionDirection"] = direction  # "Front" = -Z = para onde o personagem olha
    if squash:
        props["Squash"] = squash
    if shape:
        props["Shape"] = shape
    if shape_style:
        props["ShapeStyle"] = shape_style
    attrs = {"EmitCount": count}
    if duration:
        attrs["EmitDuration"] = duration
    return {"name": name, "className": "ParticleEmitter", "properties": props, "attributes": attrs}


def light(name, color, brightness, range_, fade=0.5):
    return {"name": name, "className": "PointLight",
            "properties": {"Color": list(color), "Brightness": brightness, "Range": range_, "Shadows": False},
            "attributes": {"FadeTime": fade}}


def part(name, shape, size, color, scale, time, offset=(0, 0, 0), transparency=0.2, rot=None, children=None):
    """Part Neon que cresce `scale`x em `time` s enquanto some."""
    props = {
        "Name": name, "Anchored": True, "CanCollide": False, "CanQuery": False, "CanTouch": False,
        "CastShadow": False, "Material": "Neon", "Color": list(color), "Transparency": transparency,
        "Size": list(size), "Position": list(offset),
    }
    if shape:
        props["Shape"] = shape
    if rot:
        props["Orientation"] = list(rot)
    return {"name": name, "className": "Part", "properties": props,
            "attributes": {"TweenScale": scale, "TweenTime": time}, "children": children or []}


def ring(name, color, radius, scale, time, y=0.2, thickness=0.35, height=0.3):
    # cilindro deitado: eixo Y => Orientation (0,0,90); Size = (altura, diâmetro, diâmetro)
    return part(name, "Cylinder", (height, radius * 2, radius * 2), color, scale, time, offset=(0, y, 0),
                transparency=0.15, rot=(0, 0, 90))


def anchor(name, children, offset=(0, 0, 0)):
    """Part invisível que carrega emissores (posicionado em relação ao pivot)."""
    return {"name": name, "className": "Part",
            "properties": {"Name": name, "Anchored": True, "CanCollide": False, "CanQuery": False,
                           "CanTouch": False, "CastShadow": False, "Transparency": 1, "Size": [1, 1, 1],
                           "Position": list(offset)},
            "children": children}


def model(name, children, lifetime=None, follow=False):
    # OriginRelative: FX.SpawnVFX trata a Position de cada Part como offset do ponto de spawn
    # Follow: emissores/luzes vão para o HumanoidRootPart e acompanham o personagem (auras)
    node = {"className": "Model", "children": children, "attributes": {"OriginRelative": True}}
    if lifetime:
        node["attributes"]["Lifetime"] = lifetime
    if follow:
        node["attributes"]["Follow"] = True
    return node


ORANGE = (1.0, 0.55, 0.15)
YELLOW = (1.0, 0.85, 0.35)
RED = (0.9, 0.15, 0.1)
CYAN = (0.4, 0.9, 1.0)
WHITE = (1, 1, 1)
VIOLET = (0.65, 0.4, 1.0)
BLUE = (0.35, 0.55, 1.0)
GREEN = (0.45, 1.0, 0.55)
DUST = (0.55, 0.45, 0.35)
GREY = (0.35, 0.35, 0.35)

vfx = {}

# ---------------------------------------------------------------------------
# Brawler
# ---------------------------------------------------------------------------
vfx["Brawler/ShoulderBash"] = model("ShoulderBash", [
    anchor("Feet", [
        emitter("Dust", SMOKE, cseq((0, DUST), (1, (0.3, 0.25, 0.2))), nseq((0, 2), (1, 5)), (0.5, 0.9), (4, 9), 14,
                spread=(60, 60), light=0, accel=(0, 3, 0), drag=2, transparency=nseq((0, 0.4), (1, 1))),
        emitter("Sparks", SPARK, cseq((0, YELLOW), (1, ORANGE)), nseq((0, 0.6), (1, 0)), (0.3, 0.5), (15, 25), 16,
                spread=(40, 40), drag=3, direction="Front"),
    ], offset=(0, -2.5, 0)),
])
vfx["Brawler/ShoulderBash_Hit"] = model("ShoulderBash_Hit", [
    part("Flash", "Ball", (2, 2, 2), ORANGE, 2.5, 0.25, transparency=0.3),
    anchor("Burst", [
        emitter("Sparks", SPARK, cseq((0, WHITE), (0.3, YELLOW), (1, ORANGE)), nseq((0, 0.8), (1, 0)), (0.25, 0.5),
                (20, 35), 22, drag=4),
        emitter("Puff", SMOKE, cseq((0, (0.6, 0.5, 0.4)), (1, GREY)), nseq((0, 1.5), (1, 3.5)), (0.4, 0.6), (5, 8),
                8, light=0, transparency=nseq((0, 0.5), (1, 1))),
    ]),
    light("Light", ORANGE, 2, 14, 0.3),
])
vfx["Brawler/GroundSlam"] = model("GroundSlam", [
    ring("Shockwave", ORANGE, 2, 12, 0.55, y=-2.6),
    ring("Shockwave2", YELLOW, 1.5, 9, 0.4, y=-2.5),
    anchor("Ground", [
        emitter("Dust", SMOKE, cseq((0, DUST), (1, (0.3, 0.25, 0.2))), nseq((0, 3), (1, 7)), (0.8, 1.3), (14, 22), 24,
                spread=(90, 10), light=0, accel=(0, -8, 0), drag=3, transparency=nseq((0, 0.4), (1, 1))),
        emitter("Rocks", SPARK, cseq((0, (0.5, 0.4, 0.3)), (1, (0.3, 0.25, 0.2))), nseq((0, 0.9), (1, 0.6)), (0.6, 1.0),
                (18, 30), 16, spread=(60, 60), light=0, accel=(0, -40, 0), rotspeed=(-400, 400)),
        emitter("Embers", SPARK, cseq((0, YELLOW), (1, RED)), nseq((0, 0.5), (1, 0)), (0.5, 0.9), (12, 24), 20,
                spread=(70, 70), accel=(0, -20, 0), drag=2),
    ], offset=(0, -2.6, 0)),
    light("Light", ORANGE, 3, 20, 0.5),
])
vfx["Brawler/GroundSlam_Hit"] = vfx["Brawler/ShoulderBash_Hit"]
vfx["Brawler/Rampage"] = model("Rampage", [
    part("Pulse", "Ball", (4, 4, 4), RED, 3, 0.4, transparency=0.4),
    anchor("Aura", [
        emitter("Fire", FIRE, cseq((0, YELLOW), (0.4, ORANGE), (1, RED)), nseq((0, 1.6), (0.5, 2.2), (1, 0.4)),
                (0.5, 0.8), (3, 6), 20, spread=(30, 30), accel=(0, 6, 0), drag=1, duration=8,
                transparency=nseq((0, 0.3), (0.6, 0.5), (1, 1)), rot=(0, 0), rotspeed=(0, 0), zoffset=-0.5),
        emitter("Embers", SPARK, cseq((0, YELLOW), (1, RED)), nseq((0, 0.35), (1, 0)), (0.6, 1.1), (3, 7), 12,
                spread=(80, 80), accel=(0, 8, 0), drag=1, duration=8),
    ], offset=(0, -1.5, 0)),
    light("Light", RED, 2.5, 16, 8),
], lifetime=9, follow=True)

# ---------------------------------------------------------------------------
# Swift
# ---------------------------------------------------------------------------
vfx["Swift/Blink"] = model("Blink", [
    part("Flash", "Ball", (3, 3, 3), CYAN, 2.2, 0.3, transparency=0.35),
    ring("Ring", CYAN, 1.5, 4, 0.35, y=-2.6),
    anchor("Burst", [
        emitter("Streaks", SPARK, cseq((0, WHITE), (1, CYAN)), nseq((0, 0.9), (1, 0)), (0.3, 0.5), (18, 30), 26, drag=5,
                orientation="VelocityParallel"),
        emitter("Motes", SPARK, cseq((0, CYAN), (1, BLUE)), nseq((0, 0.4), (1, 0)), (0.5, 0.9), (2, 5), 16, drag=1,
                accel=(0, 4, 0)),
    ]),
    light("Light", CYAN, 2.5, 16, 0.3),
])
vfx["Swift/SweepKick"] = model("SweepKick", [
    ring("Arc", WHITE, 2, 5, 0.3, y=-2.2, height=0.2),
    anchor("Wind", [
        emitter("Wind", SMOKE, cseq((0, WHITE), (1, CYAN)), nseq((0, 1.5), (1, 3)), (0.3, 0.5), (16, 26), 18,
                spread=(90, 5), light=0.6, drag=4, transparency=nseq((0, 0.6), (1, 1))),
        emitter("Streaks", SPARK, cseq((0, WHITE), (1, CYAN)), nseq((0, 0.7), (1, 0)), (0.25, 0.4), (25, 40), 20,
                spread=(90, 5), drag=5, orientation="VelocityParallel"),
    ], offset=(0, -2.2, 0)),
])
vfx["Swift/SweepKick_Hit"] = model("SweepKick_Hit", [
    part("Flash", "Ball", (1.8, 1.8, 1.8), CYAN, 2.5, 0.25, transparency=0.3),
    anchor("Burst", [
        emitter("Sparks", SPARK, cseq((0, WHITE), (1, CYAN)), nseq((0, 0.7), (1, 0)), (0.25, 0.5), (18, 32), 20, drag=4),
    ]),
    light("Light", CYAN, 2, 12, 0.3),
])
vfx["Swift/Tempest"] = model("Tempest", [
    ring("Ring1", CYAN, 2, 6, 0.6, y=-2.5),
    ring("Ring2", WHITE, 1, 5, 0.9, y=-1),
    ring("Ring3", CYAN, 1.5, 5.5, 1.2, y=0.5),
    anchor("Vortex", [
        emitter("Swirl", SPARK, cseq((0, WHITE), (0.5, CYAN), (1, BLUE)), nseq((0, 0.9), (1, 0)), (0.7, 1.2), (14, 22),
                24, spread=(90, 15), drag=2, accel=(0, 10, 0), duration=1.5, orientation="VelocityParallel"),
        emitter("Wind", SMOKE, cseq((0, WHITE), (1, CYAN)), nseq((0, 2), (1, 5)), (0.6, 1.0), (10, 18), 14,
                spread=(90, 20), light=0.5, drag=2, accel=(0, 6, 0), duration=1.5,
                transparency=nseq((0, 0.6), (1, 1))),
        emitter("Motes", SPARK, cseq((0, CYAN), (1, WHITE)), nseq((0, 0.5), (1, 0)), (0.8, 1.4), (3, 8), 14,
                accel=(0, 8, 0), duration=1.5),
    ], offset=(0, -2, 0)),
    light("Light", CYAN, 3, 22, 1.8),
], lifetime=3.5)
vfx["Swift/Tempest_Hit"] = vfx["Swift/SweepKick_Hit"]

# ---------------------------------------------------------------------------
# Mystic
# ---------------------------------------------------------------------------
vfx["Mystic/ArcaneBolt"] = model("ArcaneBolt", [
    part("Flash", "Ball", (1.5, 1.5, 1.5), VIOLET, 2, 0.2, transparency=0.3, offset=(0, 0.5, -2)),
    anchor("Muzzle", [
        emitter("Sparks", SPARK, cseq((0, WHITE), (0.4, VIOLET), (1, BLUE)), nseq((0, 0.6), (1, 0)), (0.2, 0.4),
                (10, 20), 14, spread=(35, 35), drag=3, direction="Front"),
        emitter("Glow", SMOKE, cseq((0, VIOLET), (1, BLUE)), nseq((0, 1), (1, 2.5)), (0.3, 0.5), (1, 3), 6, light=0.8,
                transparency=nseq((0, 0.5), (1, 1))),
    ], offset=(0, 0.5, -2)),
    light("Light", VIOLET, 2, 12, 0.25),
])
vfx["Mystic/ArcaneBolt_Hit"] = model("ArcaneBolt_Hit", [
    part("Flash", "Ball", (2, 2, 2), VIOLET, 3, 0.3, transparency=0.3),
    ring("Ring", BLUE, 1, 4, 0.35, y=0, height=0.2),
    anchor("Burst", [
        emitter("Sparks", SPARK, cseq((0, WHITE), (0.3, VIOLET), (1, BLUE)), nseq((0, 0.8), (1, 0)), (0.3, 0.6),
                (16, 30), 24, drag=4),
        emitter("Glow", SMOKE, cseq((0, VIOLET), (1, BLUE)), nseq((0, 2), (1, 4)), (0.4, 0.6), (2, 5), 8, light=0.8,
                transparency=nseq((0, 0.5), (1, 1))),
    ]),
    light("Light", VIOLET, 3, 16, 0.4),
])
vfx["Mystic/Mend"] = model("Mend", [
    part("Bubble", "Ball", (5, 5, 5), GREEN, 1.4, 0.8, transparency=0.6),
    ring("Ring", GREEN, 1.5, 3, 0.7, y=-2.6, height=0.2),
    anchor("Rise", [
        emitter("Motes", SPARK, cseq((0, WHITE), (0.5, GREEN), (1, (0.3, 0.8, 0.4))), nseq((0, 0.5), (1, 0)),
                (0.9, 1.4), (4, 8), 24, spread=(70, 70), accel=(0, 10, 0), drag=1, rotspeed=(0, 0),
                transparency=nseq((0, 0.2), (1, 1))),
        emitter("Crosses", SPARK, cseq((0, GREEN), (1, WHITE)), nseq((0, 1.2), (1, 0.4)), (0.8, 1.2), (3, 6), 8,
                spread=(60, 60), accel=(0, 6, 0), rot=(45, 45), rotspeed=(0, 0)),
    ], offset=(0, -2, 0)),
    light("Light", GREEN, 2, 14, 0.8),
])
# Aviso do meteoro: anel vermelho pulsando no ponto de impacto durante o Delay (1.2 s)
vfx["Mystic/Meteor"] = model("Meteor", [
    part("Warn1", "Cylinder", (0.25, 28, 28), RED, 1.0, 1.2, offset=(0, 0.35, 0), transparency=0.55, rot=(0, 0, 90)),
    part("Warn2", "Cylinder", (0.3, 4, 4), RED, 7, 1.15, offset=(0, 0.4, 0), transparency=0.25, rot=(0, 0, 90)),
    anchor("Sky", [
        emitter("Embers", SPARK, cseq((0, YELLOW), (1, RED)), nseq((0, 0.6), (1, 0)), (0.8, 1.2), (2, 6), 20,
                spread=(90, 90), accel=(0, -6, 0), duration=1.1),
    ], offset=(0, 1, 0)),
    light("Light", RED, 1.5, 22, 1.2),
], lifetime=1.5)
vfx["Mystic/Meteor_Hit"] = model("Meteor_Hit", [
    part("Core", "Ball", (4, 4, 4), YELLOW, 5, 0.45, transparency=0.1),
    ring("Shockwave", ORANGE, 3, 12, 0.6, y=0.3),
    ring("Shockwave2", YELLOW, 2, 10, 0.45, y=0.5),
    anchor("Blast", [
        emitter("Fireball", EXPLOSION, cseq((0, WHITE), (0.3, YELLOW), (0.7, ORANGE), (1, RED)), nseq((0, 4), (1, 9)),
                (0.5, 0.8), (6, 14), 16, spread=(90, 90), drag=3, transparency=nseq((0, 0.1), (0.6, 0.4), (1, 1))),
        emitter("Smoke", SMOKE, cseq((0, GREY), (1, (0.15, 0.15, 0.15))), nseq((0, 5), (1, 12)), (1.0, 1.6), (8, 16),
                20, spread=(90, 60), light=0, accel=(0, 4, 0), drag=2, transparency=nseq((0, 0.4), (1, 1))),
        emitter("Sparks", SPARK, cseq((0, WHITE), (0.4, YELLOW), (1, RED)), nseq((0, 1), (1, 0)), (0.5, 1.0),
                (30, 55), 30, spread=(90, 90), accel=(0, -30, 0), drag=1),
        emitter("Rocks", SPARK, cseq((0, (0.4, 0.3, 0.25)), (1, (0.2, 0.15, 0.1))), nseq((0, 1.2), (1, 0.8)), (0.7, 1.2),
                (25, 40), 18, spread=(70, 70), light=0, accel=(0, -50, 0), rotspeed=(-500, 500)),
    ], offset=(0, 0.5, 0)),
    light("Light", ORANGE, 5, 32, 0.7),
], lifetime=3)

# ---------------------------------------------------------------------------
# Shared
# ---------------------------------------------------------------------------
vfx["Shared/Finisher"] = model("Finisher", [
    anchor("Wind", [
        emitter("Streaks", SPARK, cseq((0, WHITE), (1, (0.8, 0.85, 0.9))), nseq((0, 0.6), (1, 0)), (0.2, 0.35),
                (25, 40), 14, spread=(25, 25), drag=4, orientation="VelocityParallel", light=0.6, direction="Front"),
        emitter("Puff", SMOKE, cseq((0, WHITE), (1, (0.7, 0.7, 0.75))), nseq((0, 1), (1, 2.5)), (0.25, 0.4), (6, 12),
                6, spread=(30, 30), light=0.2, transparency=nseq((0, 0.6), (1, 1)), direction="Front"),
    ], offset=(0, 0, -2)),
])

# ---------------------------------------------------------------------------
# Escreve
# ---------------------------------------------------------------------------
for key, tree in vfx.items():
    folder, name = key.split("/")
    path = ROOT / folder / f"{name}.model.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(tree, indent=1) + "\n")
    print(path.relative_to(ROOT.parent.parent.parent))
