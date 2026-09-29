#!/usr/bin/env python3
"""Ilha 1 do Capítulo 1 — PORTO DA NÉVOA (Parte 1; BIBLIA_CAMPANHA_CAP1_v0.1.md): vila vitoriana com névoa, porto e ruínas góticas.

Layout do mundo (2026-09-28): a ilha fica em volta da Taberna (colina de pedra a leste, x 255..410) e do
Parque Vitoriano (peças da arena antiga). O CHÃO é Terrain (tools/studio/MontarMundo.luau), então aqui só entram
as construções, com o chão em y = 0. Nomes NÃO podem repetir os da ArenaExtras (BossSpawn/DummyPad são do
santuário e dos bonecos de treino): aqui é GuardiaoSpawn / VagantePad.
"""

import json
import math
import random
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "src/workspace/FXTutorialIsland.model.json"
rng = random.Random(28)

STONE = ("Cobblestone", (.43, .44, .46)); WOOD = ("WoodPlanks", (.43, .29, .17)); DARK = ("Basalt", (.16, .18, .21))
BRICK = ("Brick", (.42, .22, .18)); PLASTER = ("SmoothPlastic", (.78, .74, .66)); ROOF = ("Slate", (.22, .12, .13))
GLASS = ("Glass", (.95, .8, .45)); NEON = ("Neon", (.35, .85, 1)); IRON = ("Metal", (.12, .12, .13))

folders = {name: [] for name in ("Porto", "Vila", "Treino", "Ruinas", "Portais", "Spawns")}


def part(folder, name, size, pos, mat, rot=(0, 0, 0), cls="Part", **extra):
    material, color = mat
    props = {"Name": name, "Anchored": True, "Position": [round(v, 3) for v in pos], "Size": [round(v, 3) for v in size],
             "Color": list(color), "Material": material, "Orientation": list(rot),
             "TopSurface": "Smooth", "BottomSurface": "Smooth"}
    props.update(extra)
    node = {"name": name, "className": cls, "properties": props}
    folders[folder].append(node)
    return node


def cylinder(folder, name, radius, height, pos, mat, **extra):
    return part(folder, name, (height, radius * 2, radius * 2), pos, mat, (0, 0, 90), Shape="Cylinder", **extra)


def light(node, color=(1, .75, .45), brightness=1.4, rng_=22):
    node.setdefault("children", []).append({"name": "Light", "className": "PointLight",
                                            "properties": {"Color": list(color), "Brightness": brightness, "Range": rng_}})


def lamp(folder, name, x, z):
    cylinder(folder, name + "Poste", .35, 9, (x, 4.5, z), IRON)
    light(part(folder, name + "Luz", (1.4, 1.8, 1.4), (x, 9.6, z), GLASS, CastShadow=False))


# ---------------------------------------------------------------------------
# Porto (sul): cais de madeira, farol e lampiões — é onde o jogador chega.
PX, PZ = 40, 200
for i in range(7):
    part("Porto", f"Cais{i}", (18, 1, 12), (PX, .5, PZ + i * 12), WOOD)
for side in (-8, 8):
    for i in range(7):
        cylinder("Porto", f"Estaca{side}_{i}", .7, 12, (PX + side, -4, PZ + i * 12), DARK)
for i, z in enumerate((PZ + 10, PZ + 46)):
    lamp("Porto", f"LampiaoCais{i}", PX - 9, z)
cylinder("Porto", "FarolBase", 10, 4, (-40, 2, 205), STONE)
cylinder("Porto", "FarolTorre", 7, 30, (-40, 19, 205), PLASTER)
for i in range(3):
    cylinder("Porto", f"FarolFaixa{i}", 7.2, 2, (-40, 10 + i * 9, 205), ("SmoothPlastic", (.55, .12, .12)))
light(part("Porto", "FarolLuz", (6, 5, 6), (-40, 36.5, 205), NEON, Shape="Ball", CastShadow=False), (.6, .9, 1), 4, 60)
part("Porto", "FarolTopo", (9, 1, 9), (-40, 34, 205), IRON)

# Caminho de pedra: porto -> praça da vila -> acampamento -> ruínas (norte).
for i in range(26):
    z = PZ - 12 - i * 14
    x = PX + (0 if z > 60 else (z - 60) * 0.35) + rng.uniform(-1.5, 1.5)
    part("Vila", f"Caminho{i}", (12, .3, 15), (x, .15, z), STONE, (0, rng.uniform(-5, 5), 0))

# ---------------------------------------------------------------------------
# Vila vitoriana em anel em volta da praça (Humanoider_20 no centro). Aberturas N/S para o caminho.
VX, VZ = 40, 110
cylinder("Vila", "Praca", 34, .5, (VX, .25, VZ), STONE)
part("Vila", "HumanoiderSpot", (8, .4, 8), (VX, .7, VZ), NEON, Transparency=.65, CanCollide=False)
cylinder("Vila", "FonteBase", 6, 2, (VX + 16, 1, VZ - 14), STONE)
cylinder("Vila", "FonteAgua", 5, .4, (VX + 16, 2.1, VZ - 14), ("Glass", (.3, .55, .7)), Transparency=.3)
for i, a in enumerate((20, 55, 125, 160, 200, 235, 305, 340)):
    ar = math.radians(a)
    x, z = VX + math.cos(ar) * 58, VZ + math.sin(ar) * 58
    yaw = -a + 90
    floors = 2 if i % 3 else 3
    h = 10 * floors
    wall = BRICK if i % 2 else PLASTER
    part("Vila", f"Casa{i}", (22, h, 18), (x, h / 2, z), wall, (0, yaw, 0))
    part("Vila", f"Telhado{i}", (24, 3, 20), (x, h + 1.5, z), ROOF, (0, yaw, 0))
    part("Vila", f"Chamine{i}", (3, 7, 3), (x + math.cos(ar) * 6, h + 4, z + math.sin(ar) * 6), BRICK, (0, yaw, 0))
    # porta virada para a praça + janelas acesas
    fx, fz = VX + math.cos(ar) * 48.9, VZ + math.sin(ar) * 48.9
    part("Vila", f"Porta{i}", (5, 8, .6), (fx, 4, fz), WOOD, (0, yaw, 0))
    for f in range(floors):
        w = part("Vila", f"Janela{i}_{f}", (8, 3.5, .5), (fx, 8 + f * 10, fz), GLASS, (0, yaw, 0), CastShadow=False)
        if f == 0:
            light(w, brightness=.8, rng_=14)
for i, a in enumerate((0, 90, 180, 270)):
    ar = math.radians(a + 45)
    lamp("Vila", f"LampiaoPraca{i}", VX + math.cos(ar) * 30, VZ + math.sin(ar) * 30)

# ---------------------------------------------------------------------------
# Acampamento dos Vagantes da Fratura (tutorial de combate): arena de areia com estacas.
TX, TZ = -60, -80
cylinder("Treino", "ArenaTreino", 42, .4, (TX, .2, TZ), ("Sand", (.62, .56, .44)))
for i in range(10):
    a = i / 10 * math.tau
    cylinder("Treino", f"EstacaTreino{i}", 1.4, 7 + (i % 3) * 2, (TX + math.cos(a) * 38, 4, TZ + math.sin(a) * 38), DARK)
for i in range(3):
    cylinder("Treino", f"VagantePad{i}", 3, .3, (TX - 16 + i * 16, .45, TZ), DARK, Transparency=.5)
light(part("Treino", "FogueiraTreino", (4, 1, 4), (TX, .7, TZ + 22), ("Neon", (1, .45, .15)), CastShadow=False), (1, .5, .2), 2, 26)

# ---------------------------------------------------------------------------
# Ruínas góticas ao norte: primeiro Rastro de Carlos e o Herdeiro da Névoa (GuardiaoSpawn).
RX, RZ = -20, -190
cylinder("Ruinas", "PatioRuinas", 45, .6, (RX, .3, RZ), STONE)
for i in range(12):
    a = i / 12 * math.tau
    h = rng.choice((7, 11, 15, 19, 24))
    cylinder("Ruinas", f"Coluna{i}", 2, h, (RX + math.cos(a) * 36, h / 2, RZ + math.sin(a) * 36), STONE)
    if h >= 19:
        part("Ruinas", f"Arco{i}", (10, 2, 3), (RX + math.cos(a) * 36, h + 1, RZ + math.sin(a) * 36), STONE,
             (0, -math.degrees(a) + 90, 0))
part("Ruinas", "Capela", (26, 22, 4), (RX, 11, RZ - 46), DARK)
part("Ruinas", "CapelaTorre", (8, 34, 8), (RX + 14, 17, RZ - 46), DARK)
part("Ruinas", "Rosacea", (8, 8, .6), (RX, 15, RZ - 43.6), ("Neon", (.55, .2, .25)), Shape="Cylinder", CastShadow=False)
part("Ruinas", "RastroCarlos01", (5, 1, 5), (RX, 1.1, RZ), NEON, Transparency=.2, CanCollide=False)
part("Ruinas", "GuardiaoSpawn", (8, .4, 8), (RX, .8, RZ - 27), DARK, Transparency=.45, CanCollide=False)

# ---------------------------------------------------------------------------
# Portal para o Deserto do Sol (nordeste, na direção dela). O WorldPortalService liga pelo NOME.
for name, x, z in (("TutorialToPilares", 380, -190),):
    part("Portais", name, (10, 16, 2), (x, 8, z), DARK, (0, 45, 0))
    part("Portais", name + "Core", (7, 12, 1), (x, 8, z), NEON, (0, 45, 0), Transparency=.25, CanCollide=False)

part("Spawns", "TutorialSpawn", (10, 1, 10), (PX, 1, PZ - 15), ("Plastic", (.2, .7, .4)), cls="SpawnLocation",
     Transparency=1, CanCollide=False, Enabled=False, Neutral=True)

children = [{"name": name, "className": "Folder", "children": nodes} for name, nodes in folders.items()]
OUT.write_text(json.dumps({"className": "Model", "ignoreUnknownInstances": True, "children": children}, indent=1) + "\n")
print(f"{OUT}: {sum(map(len, folders.values()))} instâncias-base")
