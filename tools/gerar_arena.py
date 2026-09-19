#!/usr/bin/env python3
"""
Gera src/workspace/Arena.model.json (Workspace.Sahur.Arena), o mapa livre.

Uso: python3 tools/gerar_arena.py

Layout (320x320, chão em y=0, quase plano):
  - Praça central circular (pedra) com medalhão, 4 caminhos pavimentados
    e 4 trilhas de terra em diagonal.
  - Norte  = Ruínas (colunas quebradas, muretas)
  - Sul    = Mercado (barracas, caixotes, barris)
  - Leste  = Lago raso com pedras
  - Oeste  = Bosque (árvores, troncos, arbustos)
  - Muro de pedra em volta + barreira invisível acima.
  - 12 SpawnLocations invisíveis na pasta Spawns.
Nada aqui usa asset externo: só Parts com Material/Color do Roblox.
"""

import json
import math
import random
from pathlib import Path

# O mapa gerado agora é reserva (ServerStorage.Maps.Arena_Gerada); o mapa livre é o importado
# (src/workspace/Arena.rbxm, ver tools/preparar_mapa.luau). Os extras (spawns, pads, placar)
# saem daqui para src/workspace/ArenaExtras.model.json.
OUT = Path(__file__).resolve().parent.parent / "src" / "maps" / "Arena_Gerada.model.json"
OUT_EXTRAS = Path(__file__).resolve().parent.parent / "src" / "workspace" / "ArenaExtras.model.json"
HALF = 160  # mapa de 320x320

rng = random.Random(7)  # determinístico: regerar dá o mesmo mapa

# ---------------------------------------------------------------------------
# Paleta (materiais nativos + cores escolhidas para não parecer "free model")
# ---------------------------------------------------------------------------
GRASS = ("LeafyGrass", (0.29, 0.42, 0.24))
GRASS_DARK = ("Grass", (0.24, 0.35, 0.20))
DIRT = ("Ground", (0.42, 0.34, 0.25))
STONE = ("Cobblestone", (0.44, 0.44, 0.46))
STONE_LIGHT = ("Slate", (0.60, 0.58, 0.54))
MARBLE = ("Marble", (0.82, 0.80, 0.74))
SAND = ("Sandstone", (0.74, 0.66, 0.50))
LIME = ("Limestone", (0.68, 0.64, 0.56))
BASALT = ("Basalt", (0.30, 0.30, 0.32))
WOOD = ("Wood", (0.45, 0.31, 0.19))
PLANKS = ("WoodPlanks", (0.55, 0.40, 0.25))
FABRIC_R = ("Fabric", (0.62, 0.22, 0.20))
FABRIC_B = ("Fabric", (0.22, 0.34, 0.60))
FABRIC_Y = ("Fabric", (0.80, 0.66, 0.26))
LEAF = ("LeafyGrass", (0.22, 0.46, 0.22))
LEAF2 = ("LeafyGrass", (0.30, 0.52, 0.24))
METAL = ("Metal", (0.24, 0.25, 0.27))
WATER = ("Glass", (0.20, 0.45, 0.62))
MOSS = ("Ground", (0.32, 0.42, 0.26))
NEON_W = ("Neon", (1.0, 0.92, 0.72))
NEON_C = ("Neon", (0.45, 0.85, 1.0))

parts = []


def _base(name, cls, size, pos, mat, extra=None):
    material, color = mat
    props = {
        "Name": name,
        "Anchored": True,
        "Position": [round(pos[0], 3), round(pos[1], 3), round(pos[2], 3)],
        "Size": [round(size[0], 3), round(size[1], 3), round(size[2], 3)],
        "Color": list(color),
        "Material": material,
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
    }
    if extra:
        props.update(extra)
    node = {"name": name, "className": cls, "properties": props}
    parts.append(node)
    return node


def part(name, size, pos, mat, rot=None, **extra):
    if rot is not None:
        extra["Orientation"] = list(rot)
    return _base(name, "Part", size, pos, mat, extra)


def cylinder(name, radius, height, pos, mat, axis="y", **extra):
    """Cilindro com eixo vertical (padrão) ou deitado ('x'/'z')."""
    size = (height, radius * 2, radius * 2)
    rot = {"y": (0, 0, 90), "x": (0, 0, 0), "z": (0, 90, 0)}[axis]
    extra["Shape"] = "Cylinder"
    extra["Orientation"] = list(rot)
    return _base(name, "Part", size, pos, mat, extra)


def ball(name, radius, pos, mat, **extra):
    extra["Shape"] = "Ball"
    return _base(name, "Part", (radius * 2,) * 3, pos, mat, extra)


def wedge(name, size, pos, mat, rot, **extra):
    extra["Orientation"] = list(rot)
    return _base(name, "WedgePart", size, pos, mat, extra)


def light(node, color, brightness=1.5, rng_=18):
    node.setdefault("children", []).append({
        "name": "Light",
        "className": "PointLight",
        "properties": {"Color": list(color), "Brightness": brightness, "Range": rng_, "Shadows": False},
    })


def jitter(a):
    return rng.uniform(-a, a)


# ---------------------------------------------------------------------------
# Chão e caminhos
# ---------------------------------------------------------------------------
part("Ground", (320, 1, 320), (0, -0.5, 0), GRASS)

# manchas de grama escura / terra para quebrar a repetição
for i in range(26):
    x, z = jitter(140), jitter(140)
    if math.hypot(x, z) < 58:
        continue
    r = rng.uniform(7, 16)
    cylinder(f"Patch{i}", r, 0.15, (x, 0.02, z), GRASS_DARK if i % 3 else MOSS, CastShadow=False)

# praça: três anéis concêntricos
cylinder("Plaza", 52, 0.5, (0, 0.2, 0), STONE)
cylinder("PlazaInner", 34, 0.5, (0, 0.28, 0), STONE_LIGHT)
cylinder("PlazaRing", 20, 0.5, (0, 0.36, 0), SAND)
cylinder("Medallion", 9, 0.5, (0, 0.44, 0), MARBLE)
cylinder("MedallionCore", 3, 0.6, (0, 0.5, 0), NEON_C, CastShadow=False)
# borda da praça (meio-fio)
for i in range(48):
    a = i / 48 * math.tau
    x, z = math.cos(a) * 53, math.sin(a) * 53
    part(f"Curb{i}", (7, 0.9, 1.6), (x, 0.45, z), BASALT, rot=(0, -math.degrees(a) + 90, 0))

# 4 caminhos pavimentados (N, S, L, O) da praça até as zonas
for name, (dx, dz) in {"N": (0, -1), "S": (0, 1), "E": (1, 0), "W": (-1, 0)}.items():
    length = 70
    cx, cz = dx * (52 + length / 2), dz * (52 + length / 2)
    size = (12, 0.3, length) if dx == 0 else (length, 0.3, 12)
    part(f"Path{name}", size, (cx, 0.15, cz), STONE)
    # lajes quebradas nas bordas do caminho
    for k in range(9):
        t = 56 + k * 7.5
        off = rng.choice((-7.5, 7.5))
        px = dx * t + (off if dx == 0 else 0)
        pz = dz * t + (off if dz == 0 else 0)
        part(f"Slab{name}{k}", (rng.uniform(2, 3.5), 0.25, rng.uniform(2, 3.5)), (px, 0.12, pz), STONE_LIGHT,
             rot=(0, rng.uniform(0, 90), 0), CastShadow=False)

# 4 trilhas de terra em diagonal (mais estreitas, meio tortas)
for i, a in enumerate((45, 135, 225, 315)):
    ar = math.radians(a)
    for k in range(7):
        t = 60 + k * 11
        x, z = math.cos(ar) * t + jitter(2), math.sin(ar) * t + jitter(2)
        cylinder(f"Trail{i}_{k}", rng.uniform(4, 6), 0.18, (x, 0.05, z), DIRT, CastShadow=False)

# ---------------------------------------------------------------------------
# Postes e bancos ao redor da praça
# ---------------------------------------------------------------------------
for i in range(8):
    a = i / 8 * math.tau + math.pi / 8
    x, z = math.cos(a) * 44, math.sin(a) * 44
    cylinder(f"LampBase{i}", 1.2, 0.8, (x, 0.9, z), BASALT)
    cylinder(f"LampPole{i}", 0.35, 9, (x, 5.3, z), METAL)
    part(f"LampArm{i}", (0.3, 0.3, 2.4), (x, 9.6, z), METAL, rot=(0, -math.degrees(a) + 90, 0))
    lamp = ball(f"Lamp{i}", 0.9, (x, 9.4, z), NEON_W, CastShadow=False)
    light(lamp, (1.0, 0.85, 0.6), 1.8, 26)

for i in range(4):
    a = i / 4 * math.tau
    x, z = math.cos(a) * 28, math.sin(a) * 28
    ry = -math.degrees(a) + 90
    part(f"BenchSeat{i}", (7, 0.4, 1.8), (x, 1.5, z), PLANKS, rot=(0, ry, 0))
    part(f"BenchBack{i}", (7, 1.6, 0.3), (x + math.cos(a) * 0.9, 2.4, z + math.sin(a) * 0.9), PLANKS, rot=(0, ry, 0))
    for s in (-2.6, 2.6):
        lx = x + math.sin(a) * s
        lz = z - math.cos(a) * s
        part(f"BenchLeg{i}_{s}", (0.4, 1.3, 1.6), (lx, 0.85, lz), METAL, rot=(0, ry, 0))

# floreiras entre os bancos
for i in range(4):
    a = i / 4 * math.tau + math.pi / 4
    x, z = math.cos(a) * 30, math.sin(a) * 30
    part(f"Planter{i}", (4, 1.6, 4), (x, 1.0, z), LIME)
    part(f"PlanterSoil{i}", (3.4, 0.3, 3.4), (x, 1.85, z), DIRT)
    ball(f"PlanterBush{i}", 1.8, (x, 2.9, z), LEAF2)

# placar de líderes: painel de pedra ao lado do caminho norte (SurfaceGui vem do LeaderboardService)
part("LeaderboardBase", (12, 1, 3), (-16, 0.5, -62), BASALT)
part("LeaderboardBoard", (11, 9, 1), (-16, 5.5, -62), ("Slate", (0.12, 0.12, 0.15)), rot=(0, 0, 0))
part("LeaderboardFrame", (12, 10, 0.6), (-16, 5.5, -61.6), STONE_LIGHT)
# bonecos de treino: pontos marcados (o DummyService cria os rigs aqui)
for i, a in enumerate((30, 150, 270)):
    ar = math.radians(a)
    x, z = math.cos(ar) * 16, math.sin(ar) * 16
    cylinder(f"DummyPad{i}", 3, 0.3, (x, 0.55, z), BASALT, CastShadow=False)

# ---------------------------------------------------------------------------
# NORTE — Ruínas
# ---------------------------------------------------------------------------
cz = -118
cylinder("RuinsFloor", 40, 0.4, (0, 0.15, cz), LIME)
cylinder("RuinsFloorInner", 22, 0.4, (0, 0.25, cz), SAND)
part("RuinsDais", (18, 1.5, 18), (0, 0.95, cz), STONE_LIGHT)
part("RuinsDaisTop", (12, 0.6, 12), (0, 1.9, cz), MARBLE)
wedge("RuinsStepS", (18, 1.5, 4), (0, 0.95, cz + 11), STONE_LIGHT, (0, 180, 0))
wedge("RuinsStepN", (18, 1.5, 4), (0, 0.95, cz - 11), STONE_LIGHT, (0, 0, 0))
for i in range(10):
    a = i / 10 * math.tau
    x, z = math.cos(a) * 32, cz + math.sin(a) * 32
    h = rng.choice((5, 7, 9, 11, 4))
    cylinder(f"ColumnBase{i}", 2.2, 1, (x, 0.5, z), STONE_LIGHT)
    cylinder(f"Column{i}", 1.5, h, (x, 1 + h / 2, z), LIME)
    if h >= 9:
        part(f"ColumnCap{i}", (4.2, 1, 4.2), (x, 1 + h + 0.5, z), STONE_LIGHT)
# colunas caídas
for i, (x, z, ang) in enumerate(((-18, cz + 24, 20), (22, cz - 20, -35), (-26, cz - 12, 70))):
    cylinder(f"FallenColumn{i}", 1.5, 12, (x, 1.5, z), LIME, axis="x", Orientation=[0, ang, 0])
# muretas em arco (cobertura)
for i in range(6):
    a = math.radians(200 + i * 28)
    x, z = math.cos(a) * 38, cz + math.sin(a) * 38
    part(f"RuinWall{i}", (9, rng.uniform(2.5, 4.5), 2), (x, 1.6, z), STONE, rot=(0, -math.degrees(a) + 90, 0))
# entulho
for i in range(18):
    a = rng.uniform(0, math.tau)
    r = rng.uniform(8, 44)
    x, z = math.cos(a) * r, cz + math.sin(a) * r
    part(f"Rubble{i}", (rng.uniform(1, 3), rng.uniform(0.6, 1.6), rng.uniform(1, 3)), (x, 0.5, z), LIME,
         rot=(rng.uniform(-10, 10), rng.uniform(0, 360), rng.uniform(-10, 10)))

# ---------------------------------------------------------------------------
# SUL — Mercado
# ---------------------------------------------------------------------------
cz = 118
part("MarketFloor", (90, 0.4, 70), (0, 0.15, cz), PLANKS)
part("MarketFloorEdge", (96, 0.3, 76), (0, 0.05, cz), DIRT)
part("MarketWell", (6, 2.5, 6), (0, 1.25, cz), STONE)
cylinder("MarketWellHole", 2, 0.4, (0, 2.5, cz), WATER, Transparency=0.3)
part("MarketWellPost1", (0.5, 5, 0.5), (-2.5, 4.5, cz), WOOD)
part("MarketWellPost2", (0.5, 5, 0.5), (2.5, 4.5, cz), WOOD)
part("MarketWellRoof", (8, 0.5, 4), (0, 7.2, cz), FABRIC_R, rot=(0, 0, 0))

stall_colors = (FABRIC_R, FABRIC_B, FABRIC_Y)
stalls = ((-32, cz - 22, 0), (32, cz - 22, 0), (-32, cz + 22, 180), (32, cz + 22, 180), (-34, cz, 90), (34, cz, -90))
for i, (x, z, ry) in enumerate(stalls):
    col = stall_colors[i % 3]
    part(f"StallCounter{i}", (12, 3, 4), (x, 1.5, z), PLANKS, rot=(0, ry, 0))
    part(f"StallTop{i}", (12.6, 0.4, 4.6), (x, 3.2, z), WOOD, rot=(0, ry, 0))
    ryr = math.radians(ry)
    for s in (-5.5, 5.5):
        px = x + math.cos(ryr) * s
        pz = z - math.sin(ryr) * s
        part(f"StallPost{i}_{s}", (0.5, 9, 0.5), (px, 4.5, pz), WOOD)
    part(f"StallRoof{i}", (13.5, 0.4, 9), (x, 9.2, z), col, rot=(8, ry, 0))
    part(f"StallGoods{i}", (rng.uniform(2, 4), 1.2, 2), (x + jitter(3), 3.9, z), col)
# caixotes e barris espalhados
for i in range(14):
    x, z = jitter(42), cz + jitter(30)
    if math.hypot(x, z - cz) < 8:
        continue
    if i % 3 == 0:
        cylinder(f"Barrel{i}", 1.3, 3, (x, 1.5, z), WOOD)
        cylinder(f"BarrelRing{i}", 1.35, 0.3, (x, 2.2, z), METAL)
    else:
        s = rng.uniform(2.2, 3.4)
        part(f"Crate{i}", (s, s, s), (x, s / 2, z), PLANKS, rot=(0, rng.uniform(0, 90), 0))
# pilha de caixotes (cobertura alta)
for i, (x, z) in enumerate(((-14, cz + 10), (14, cz - 10))):
    part(f"CrateStack{i}A", (4, 4, 4), (x, 2, z), PLANKS)
    part(f"CrateStack{i}B", (4, 4, 4), (x + 4, 2, z), PLANKS, rot=(0, 15, 0))
    part(f"CrateStack{i}C", (4, 4, 4), (x + 2, 6, z), PLANKS, rot=(0, -10, 0))
# cerca
for i in range(12):
    x = -44 + i * 8
    for zz in (cz - 36, cz + 36):
        part(f"FencePost{i}_{zz}", (0.6, 3, 0.6), (x, 1.5, zz), WOOD)
        part(f"FenceRail{i}_{zz}", (8, 0.4, 0.3), (x + 4, 2.4, zz), WOOD)
        part(f"FenceRail2{i}_{zz}", (8, 0.4, 0.3), (x + 4, 1.2, zz), WOOD)

# ---------------------------------------------------------------------------
# LESTE — Lago
# ---------------------------------------------------------------------------
cx = 118
# o chão é um bloco só, então o lago fica "em cima": areia baixa + lâmina d'água sem colisão
cylinder("LakeShore", 40, 0.5, (cx, 0.25, 0), SAND, CastShadow=False)
cylinder("Lake", 35, 0.3, (cx, 0.6, 0), WATER, Transparency=0.35, Reflectance=0.25, CanCollide=False, CastShadow=False)
cylinder("LakeDeep", 18, 0.3, (cx, 0.62, 0), ("Glass", (0.12, 0.32, 0.5)), Transparency=0.45, CanCollide=False,
         CastShadow=False)
# ilha central
cylinder("Island", 9, 1.4, (cx, 0.3, 0), MOSS)
cylinder("IslandRock", 3, 3, (cx + 2, 1.8, -2), BASALT)
tree_positions = [(cx - 3, 3)]
# passarela de madeira atravessando o lago
for i in range(9):
    x = cx - 34 + i * 8.5
    part(f"Dock{i}", (8.5, 0.6, 5), (x, 0.7, 0), PLANKS)
    if i % 2 == 0:
        for zz in (-2.8, 2.8):
            part(f"DockPost{i}_{zz}", (0.7, 2.6, 0.7), (x, 0.5, zz), WOOD)
# pedras na água e na margem
for i in range(20):
    a = rng.uniform(0, math.tau)
    r = rng.uniform(12, 42)
    x, z = cx + math.cos(a) * r, math.sin(a) * r
    if abs(z) < 4 and x < cx:
        continue
    s = rng.uniform(1.5, 4.5)
    ball(f"LakeRock{i}", s / 2, (x, s * 0.25, z), BASALT if i % 2 else ("Slate", (0.40, 0.40, 0.40)))
# juncos
for i in range(24):
    a = rng.uniform(0, math.tau)
    r = rng.uniform(33, 39)
    x, z = cx + math.cos(a) * r, math.sin(a) * r
    cylinder(f"Reed{i}", 0.15, rng.uniform(2.5, 4), (x, 1.5, z), ("Grass", (0.36, 0.48, 0.20)), CanCollide=False,
             CastShadow=False)
# pontos de pesca (plataformas de pedra)
for i, a in enumerate((60, -60, 150, -150)):
    ar = math.radians(a)
    x, z = cx + math.cos(ar) * 39, math.sin(ar) * 39
    part(f"FishSpot{i}", (7, 0.8, 7), (x, 0.4, z), STONE_LIGHT, rot=(0, rng.uniform(0, 45), 0))

# ---------------------------------------------------------------------------
# OESTE — Bosque
# ---------------------------------------------------------------------------
cx = -118
cylinder("WoodsFloor", 44, 0.3, (cx, 0.05, 0), MOSS, CastShadow=False)
for i in range(16):
    a = i / 16 * math.tau + jitter(0.15)
    r = rng.choice((22, 30, 38))
    x, z = cx + math.cos(a) * r + jitter(3), math.sin(a) * r + jitter(3)
    if abs(z) < 7 and x > cx + 10:  # deixa o caminho livre
        continue
    tree_positions.append((x, z))
tree_positions += [(cx, 0), (cx - 12, 14), (cx + 8, -16)]
for i, (x, z) in enumerate(tree_positions):
    h = rng.uniform(7, 11)
    cylinder(f"Trunk{i}", rng.uniform(0.9, 1.4), h, (x, h / 2, z), WOOD)
    ball(f"Canopy{i}A", rng.uniform(4, 5.5), (x, h + 2, z), LEAF, CanCollide=False)
    ball(f"Canopy{i}B", rng.uniform(3, 4), (x + jitter(2.5), h + 3.5, z + jitter(2.5)), LEAF2, CanCollide=False)
    ball(f"Canopy{i}C", rng.uniform(2.5, 3.5), (x + jitter(2.5), h + 0.5, z + jitter(2.5)), LEAF, CanCollide=False)
# troncos caídos e tocos
for i in range(5):
    x, z = cx + jitter(36), jitter(36)
    cylinder(f"Log{i}", 1.1, rng.uniform(7, 11), (x, 1.1, z), WOOD, axis="x", Orientation=[0, rng.uniform(0, 180), 0])
for i in range(6):
    x, z = cx + jitter(40), jitter(40)
    cylinder(f"Stump{i}", 1.4, 1.2, (x, 0.6, z), WOOD)
# arbustos e cogumelos
for i in range(18):
    x, z = cx + jitter(42), jitter(42)
    ball(f"Bush{i}", rng.uniform(1.4, 2.4), (x, 1.2, z), LEAF2 if i % 2 else LEAF, CanCollide=False)
for i in range(8):
    x, z = cx + jitter(38), jitter(38)
    cylinder(f"MushStem{i}", 0.35, 1.2, (x, 0.6, z), ("SmoothPlastic", (0.9, 0.86, 0.78)), CanCollide=False)
    cap = cylinder(f"MushCap{i}", 1.1, 0.5, (x, 1.35, z), ("SmoothPlastic", (0.75, 0.25, 0.22)), CanCollide=False)
    if i % 2 == 0:
        light(cap, (1.0, 0.5, 0.4), 0.8, 8)
# clareira com pedra runa (ponto de referência)
part("RuneStone", (3, 7, 1.2), (cx - 30, 3.5, -30), BASALT, rot=(0, 30, 5))
rune = part("RuneGlyph", (1.6, 3, 0.2), (cx - 30 + 0.4, 4, -30 - 0.55), NEON_C, rot=(0, 30, 0), CanCollide=False,
            CastShadow=False)
light(rune, (0.45, 0.85, 1.0), 1.2, 16)

# ---------------------------------------------------------------------------
# Muro externo (baixo, de pedra) + barreira invisível
# ---------------------------------------------------------------------------
for side, (x, z, sx, sz) in {"N": (0, -HALF, 320, 4), "S": (0, HALF, 320, 4), "E": (HALF, 0, 4, 320), "W": (-HALF, 0, 4, 320)}.items():
    part(f"Wall{side}", (sx, 6, sz), (x, 3, z), STONE)
    part(f"WallCap{side}", (sx + 1, 0.8, sz + 1), (x, 6.4, z), STONE_LIGHT)
    part(f"Barrier{side}", (sx, 60, sz), (x, 36, z), ("SmoothPlastic", (0, 0, 0)), Transparency=1, CastShadow=False,
         CanQuery=False)
for i, (x, z) in enumerate(((-HALF, -HALF), (HALF, -HALF), (HALF, HALF), (-HALF, HALF))):
    cylinder(f"Tower{i}", 5, 12, (x, 6, z), STONE)
    cylinder(f"TowerCap{i}", 5.6, 1, (x, 12.5, z), STONE_LIGHT)
    lamp = ball(f"TowerLamp{i}", 1.2, (x, 14, z), NEON_W, CastShadow=False)
    light(lamp, (1.0, 0.85, 0.6), 1.5, 40)
# pilares no muro a cada 40 studs
for t in range(-120, 121, 40):
    for name, (x, z) in {"N": (t, -HALF), "S": (t, HALF), "E": (HALF, t), "W": (-HALF, t)}.items():
        part(f"WallPillar{name}{t}", (5, 8, 5), (x, 4, z), BASALT)
# arbustos e pedras soltas pelo gramado
for i in range(40):
    x, z = jitter(150), jitter(150)
    if math.hypot(x, z) < 56 or abs(x) < 8 or abs(z) < 8:
        continue
    if math.hypot(x - 118, z) < 44 or math.hypot(x + 118, z) < 46 or math.hypot(x, z - 118) < 42 or math.hypot(x, z + 118) < 42:
        continue
    if i % 4 == 0:
        ball(f"FieldRock{i}", rng.uniform(1, 2.2), (x, 0.4, z), ("Slate", (0.42, 0.42, 0.42)))
    else:
        ball(f"FieldBush{i}", rng.uniform(1.2, 2.2), (x, 1.0, z), LEAF2, CanCollide=False)

# ---------------------------------------------------------------------------
# Spawns (12): 4 entre as zonas + 2 por zona, longe do centro
# ---------------------------------------------------------------------------
spawn_points = [
    (84, -84), (-84, -84), (84, 84), (-84, 84),  # diagonais
    (-30, -140), (30, -140),  # ruínas
    (-40, 140), (40, 140),  # mercado
    (140, -46), (140, 46),  # lago (margem)
    (-140, -30), (-140, 30),  # bosque
]
spawns = []
for i, (x, z) in enumerate(spawn_points, start=1):
    spawns.append({
        "name": f"Spawn{i:02d}",
        "className": "SpawnLocation",
        "properties": {
            "Name": f"Spawn{i:02d}",
            "Anchored": True,
            "Position": [x, 1, z],
            "Size": [8, 1, 8],
            "Neutral": True,
            "Duration": 0,
            "Transparency": 1,
            "CanCollide": False,
            "CastShadow": False,
        },
    })

# ---------------------------------------------------------------------------
# Monta a árvore: pastas por zona ajudam a equipe a achar as coisas no Explorer
# ---------------------------------------------------------------------------
def folder(name, items):
    return {"name": name, "className": "Folder", "children": items}


zones = {"Ground": [], "Plaza": [], "Ruins": [], "Market": [], "Lake": [], "Woods": [], "Walls": []}
prefix_map = [
    ("Ruin", "Ruins"), ("Column", "Ruins"), ("FallenColumn", "Ruins"), ("Rubble", "Ruins"),
    ("Market", "Market"), ("Stall", "Market"), ("Barrel", "Market"), ("Crate", "Market"), ("Fence", "Market"),
    ("Lake", "Lake"), ("Island", "Lake"), ("Dock", "Lake"), ("Reed", "Lake"), ("FishSpot", "Lake"),
    ("Woods", "Woods"), ("Trunk", "Woods"), ("Canopy", "Woods"), ("Log", "Woods"), ("Stump", "Woods"),
    ("Bush", "Woods"), ("Mush", "Woods"), ("Rune", "Woods"),
    ("Wall", "Walls"), ("Barrier", "Walls"), ("Tower", "Walls"),
    ("Plaza", "Plaza"), ("Medallion", "Plaza"), ("Leaderboard", "Plaza"), ("DummyPad", "Plaza"), ("Curb", "Plaza"), ("Lamp", "Plaza"), ("Bench", "Plaza"),
    ("Planter", "Plaza"), ("Path", "Plaza"), ("Slab", "Plaza"), ("Trail", "Plaza"),
]
for p in parts:
    name = p["name"]
    zone = "Ground"
    for prefix, z in prefix_map:
        if name.startswith(prefix):
            zone = z
            break
    zones[zone].append(p)

# Pontos de captura da guerra de clã (WarService recolore conforme o dono): A oeste, B praça, C leste
capture_points = []
for name, (x, z) in (("A", (-100, 0)), ("B", (0, 0)), ("C", (100, 0))):
    capture_points.append(cylinder(f"{name}", 12, 0.3, (x, 0.8, z), ("Neon", (0.7, 0.7, 0.75)), CanCollide=False,
                                   CastShadow=False, Transparency=0.35))
    parts.remove(capture_points[-1])

tree = {
    "className": "Model",
    "children": [folder(z, items) for z, items in zones.items()] + [folder("Spawns", spawns), folder("CapturePoints", capture_points)],
}

OUT.write_text(json.dumps(tree, indent=1))
print(f"{OUT}: {len(parts)} partes + {len(spawns)} spawns")

# ---------------------------------------------------------------------------
# Extras para o mapa importado (piso 380x580 centrado em 0, topo em y=0)
# ---------------------------------------------------------------------------
parts.clear()
part("LeaderboardBase", (12, 1, 3), (-30, 0.5, -70), BASALT)
part("LeaderboardBoard", (11, 9, 1), (-30, 5.5, -70), ("Slate", (0.12, 0.12, 0.15)))
part("LeaderboardFrame", (12, 10, 0.6), (-30, 5.5, -69.6), STONE_LIGHT)
part("RatingBase", (12, 1, 3), (30, 0.5, -70), BASALT)
part("RatingBoard", (11, 9, 1), (30, 5.5, -70), ("Slate", (0.12, 0.12, 0.15)))
part("RatingFrame", (12, 10, 0.6), (30, 5.5, -69.6), STONE_LIGHT)
part("ClanBase", (12, 1, 3), (0, 0.5, -76), BASALT)
part("ClanBoard", (11, 9, 1), (0, 5.5, -76), ("Slate", (0.12, 0.12, 0.15)))
part("ClanFrame", (12, 10, 0.6), (0, 5.5, -75.6), STONE_LIGHT)
for i, a in enumerate((30, 150, 270)):
    ar = math.radians(a)
    cylinder(f"DummyPad{i}", 3, 0.3, (math.cos(ar) * 18, 0.15, math.sin(ar) * 18), BASALT, CastShadow=False)
# ---------------------------------------------------------------------------
# SANTUÁRIO DO BOSS (ao sul, z ~ 150..240): piso circular de pedra escura, anel de pilares com
# braseiros, runas no chão, estátuas quebradas, caminho de lajes desde a praça. BossService acha
# por nome: BossAltar (ProximityPrompt), BossSpawn (nasce), BossArena (centro/raio da luta).
# ---------------------------------------------------------------------------
def fire(node, color=(1.0, 0.45, 0.15), size=1.2, rate=18):
    node.setdefault("children", []).append({
        "name": "Fire", "className": "ParticleEmitter",
        "properties": {
            "Color": {"ColorSequence": {"keypoints": [{"time": 0, "color": list(color)}, {"time": 1, "color": [0.4, 0.05, 0.0]}]}},
            "Size": {"NumberSequence": {"keypoints": [{"time": 0, "value": size, "envelope": 0}, {"time": 1, "value": 0, "envelope": 0}]}},
            "Transparency": {"NumberSequence": {"keypoints": [{"time": 0, "value": 0.2, "envelope": 0}, {"time": 1, "value": 1, "envelope": 0}]}},
            "Rate": rate, "Lifetime": {"NumberRange": [0.6, 1.1]}, "Speed": {"NumberRange": [2, 4]},
            "SpreadAngle": {"Vector2": [12, 12]}, "LightEmission": 1, "Acceleration": {"Vector3": [0, 3, 0]},
        },
    })

SANCT_Z = 195
SANCT_R = 44
# Onde o dono POSICIONOU o santuário no Studio (2026-09-16, lido via MCP): o conjunto é gerado em volta
# de (0, 0, SANCT_Z) e depois movido/girado em bloco para cá. Mudar aqui, nunca no Studio + aqui.
SANCT_WORLD = (97.75, 0.6, 231.625)  # centro final (x, deslocamento y, z)
SANCT_YAW = 180  # giro em graus no eixo Y
DARK_STONE = ("Slate", (0.13, 0.13, 0.16))
RUNE_RED = ("Neon", (0.85, 0.20, 0.20))
# caminho de lajes (BossPathSlab0..13): o dono posiciona no Studio, o place é o dono delas
# (2026-09-19). Rojo ignora o que não conhece dentro de Props (ignoreUnknownInstances).
# As duas chamadas mantêm a sequência do rng igual à de antes, senão o resto do mapa mexe.
for i in range(14):
    jitter(0.6)
    jitter(6)
# piso: disco de pedra escura + anel externo claro + degrau
cylinder("BossFloor", SANCT_R, 1.2, (0, 0.6 - 0.6, SANCT_Z), DARK_STONE)
cylinder("BossFloorRing", SANCT_R + 3, 0.8, (0, 0.4 - 0.6, SANCT_Z), BASALT)
cylinder("BossFloorInner", 14, 0.3, (0, 0.75, SANCT_Z), ("Slate", (0.09, 0.09, 0.11)))
# runas no chão: cruz + anel de traços neon (só visual; o anel vermelho da luta é do BossService)
for i in range(12):
    a = i / 12 * math.tau
    r = 22
    part(f"BossRune{i}", (1.2, 0.15, 4), (math.cos(a) * r, 0.7, SANCT_Z + math.sin(a) * r), RUNE_RED,
         rot=(0, -math.degrees(a), 0), CastShadow=False)
part("BossRuneLineA", (0.6, 0.12, 30), (0, 0.72, SANCT_Z), RUNE_RED, CastShadow=False)
part("BossRuneLineB", (30, 0.12, 0.6), (0, 0.72, SANCT_Z), RUNE_RED, CastShadow=False)
# anel de pilares com braseiros
for i in range(10):
    a = i / 10 * math.tau + math.pi / 10
    x, z = math.cos(a) * (SANCT_R - 5), SANCT_Z + math.sin(a) * (SANCT_R - 5)
    cylinder(f"BossPillar{i}", 1.3, 11, (x, 5.5, z), STONE_LIGHT)
    part(f"BossPillarCap{i}", (3.4, 0.8, 3.4), (x, 11.4, z), BASALT)
    brazier = cylinder(f"BossBrazier{i}", 1.1, 0.8, (x, 12.2, z), ("Metal", (0.2, 0.18, 0.16)))
    fire(brazier)
    light(brazier, (1.0, 0.5, 0.2), 2.0, 22)
# estátuas quebradas (guardiões) nas entradas leste/oeste
for sx, name in ((-1, "W"), (1, "E")):
    bx = sx * (SANCT_R - 12)
    part(f"BossStatueBase{name}", (5, 2, 5), (bx, 1.7, SANCT_Z), BASALT)
    part(f"BossStatueBody{name}", (2.6, 6, 2), (bx, 5.7, SANCT_Z), DARK_STONE, rot=(0, 0, sx * 6))
    part(f"BossStatueHead{name}", (1.8, 1.8, 1.8), (bx + sx * 0.6, 9.5, SANCT_Z), DARK_STONE, rot=(0, sx * 30, sx * 12))
    part(f"BossStatueArm{name}", (1, 4, 1), (bx - sx * 2.0, 6.5, SANCT_Z + 0.5), DARK_STONE, rot=(0, 0, -sx * 35))
# altar ao NORTE do disco (quem chega da praça vê primeiro), boss nasce no centro
ALTAR_Z = SANCT_Z - 30
part("BossAltarBase", (16, 1, 16), (0, 1.2, ALTAR_Z), BASALT)
part("BossAltarStep", (12, 1, 12), (0, 2.2, ALTAR_Z), STONE_LIGHT)
part("BossAltar", (4, 3.2, 4), (0, 4.3, ALTAR_Z), ("Slate", (0.10, 0.10, 0.13)))
altar_rune = part("BossAltarRune", (2.6, 0.2, 2.6), (0, 6.0, ALTAR_Z), RUNE_RED, CastShadow=False)
light(altar_rune, (0.9, 0.2, 0.2), 2.5, 24)
for i in range(4):
    a = math.radians(45 + i * 90)
    px, pz = math.cos(a) * 7, ALTAR_Z + math.sin(a) * 7
    cylinder(f"BossAltarPillar{i}", 0.8, 7, (px, 4.7, pz), STONE_LIGHT)
    torch = cylinder(f"BossAltarTorch{i}", 0.5, 0.5, (px, 8.4, pz), ("Metal", (0.2, 0.18, 0.16)))
    fire(torch, size=0.8, rate=12)
    light(torch, (1.0, 0.45, 0.2), 1.5, 16)
# --- ambientação do altar (ritual das caveiras: RitualService acende as tochas e põe uma caveira em cada
# BossAltarSkullSocket{i} conforme os jogadores coletam; a runa acende quando o ritual completa à noite)
BONE = ("SmoothPlastic", (0.86, 0.82, 0.70))
BONE_OLD = ("Sand", (0.70, 0.64, 0.52))
for i in range(4):
    a = math.radians(45 + i * 90)
    sx, sz = math.cos(a) * 4.6, ALTAR_Z + math.sin(a) * 4.6
    cylinder(f"BossAltarSkullSocket{i}", 0.9, 0.5, (sx, 2.95, sz), ("Slate", (0.10, 0.10, 0.13)))
    part(f"BossAltarSocketRune{i}", (1.2, 0.08, 1.2), (sx, 3.24, sz), ("Neon", (0.35, 0.08, 0.08)), rot=(0, 45, 0), CastShadow=False)
# pilhas de ossos/caveiras velhas nos cantos da base
for i, (ox, oz) in enumerate(((-6.2, -5.5), (6.4, -5.2), (-6.0, 5.8), (6.1, 6.0))):
    for j in range(4):
        r = 0.55 + rng.uniform(-0.1, 0.15)
        ball(f"BossBonePile{i}_{j}", r, (ox + jitter(1.1), 1.7 + (0.5 if j == 3 else 0) + r * 0.5, ALTAR_Z + oz + jitter(1.1)), BONE_OLD, CastShadow=False)
    part(f"BossBoneLong{i}", (0.35, 0.35, 2.6), (ox + jitter(0.8), 1.9, ALTAR_Z + oz + jitter(0.8)), BONE, rot=(0, rng.uniform(0, 180), 0), CastShadow=False)
# rachaduras no chão que "vazam" luz vermelha a partir do altar (acendem com o ritual)
for i in range(8):
    a = math.radians(i * 45 + 22)
    ln = rng.uniform(5, 8.5)
    cx, cz = math.cos(a) * (8 + ln / 2), ALTAR_Z + math.sin(a) * (8 + ln / 2)
    part(f"BossCrack{i}", (0.35, 0.12, ln), (cx, 0.72, cz), ("Neon", (0.30, 0.06, 0.06)), rot=(0, -math.degrees(a) + 90, 0), CastShadow=False)
# arco de pedra atrás do altar (moldura do santuário) com correntes penduradas
for sx in (-1, 1):
    cylinder(f"BossArchPost{'W' if sx < 0 else 'E'}", 1.2, 14, (sx * 9, 8.2, ALTAR_Z - 9), DARK_STONE)
part("BossArchTop", (21, 2.2, 2.6), (0, 15.6, ALTAR_Z - 9), DARK_STONE)
part("BossArchKey", (3, 3.2, 2.9), (0, 16.4, ALTAR_Z - 9), BASALT)
for i, cx in enumerate((-5.5, -2, 2, 5.5)):
    part(f"BossChain{i}", (0.3, rng.uniform(3.5, 6.5), 0.3), (cx, 12.2, ALTAR_Z - 9), ("Metal", (0.25, 0.24, 0.24)), rot=(0, 0, jitter(6)), CastShadow=False)
# névoa baixa e brasas em volta do altar
_mist = part("BossAltarMist", (18, 0.2, 18), (0, 1.9, ALTAR_Z), BASALT, Transparency=1, CanCollide=False, CastShadow=False)
_mist.setdefault("children", []).append({
    "name": "Mist", "className": "ParticleEmitter",
    "properties": {
        "Color": {"ColorSequence": {"keypoints": [{"time": 0, "color": [0.55, 0.2, 0.2]}, {"time": 1, "color": [0.2, 0.05, 0.08]}]}},
        "Size": {"NumberSequence": {"keypoints": [{"time": 0, "value": 4, "envelope": 0}, {"time": 1, "value": 7, "envelope": 0}]}},
        "Transparency": {"NumberSequence": {"keypoints": [{"time": 0, "value": 1, "envelope": 0}, {"time": 0.3, "value": 0.85, "envelope": 0}, {"time": 1, "value": 1, "envelope": 0}]}},
        "Rate": 4, "Lifetime": {"NumberRange": [4, 6]}, "Speed": {"NumberRange": [0.4, 1.0]}, "SpreadAngle": {"Vector2": [80, 80]},
        "Rotation": {"NumberRange": [0, 360]}, "RotSpeed": {"NumberRange": [-8, 8]}, "LightEmission": 0.15,
    },
})
_embers = part("BossAltarEmbers", (6, 0.2, 6), (0, 6.2, ALTAR_Z), BASALT, Transparency=1, CanCollide=False, CastShadow=False)
_embers.setdefault("children", []).append({
    "name": "Embers", "className": "ParticleEmitter",
    "properties": {
        "Color": {"ColorSequence": {"keypoints": [{"time": 0, "color": [1.0, 0.35, 0.2]}, {"time": 1, "color": [0.5, 0.05, 0.0]}]}},
        "Size": {"NumberSequence": {"keypoints": [{"time": 0, "value": 0.18, "envelope": 0.05}, {"time": 1, "value": 0, "envelope": 0}]}},
        "Transparency": {"NumberSequence": {"keypoints": [{"time": 0, "value": 0.1, "envelope": 0}, {"time": 1, "value": 1, "envelope": 0}]}},
        "Rate": 10, "Lifetime": {"NumberRange": [1.5, 3]}, "Speed": {"NumberRange": [1, 2.5]}, "SpreadAngle": {"Vector2": [60, 60]},
        "Acceleration": {"Vector3": [0, 1.5, 0]}, "LightEmission": 1, "Drag": 1,
    },
})
part("BossSpawn", (6, 1, 6), (0, 1.5, SANCT_Z), BASALT, Transparency=1, CanCollide=False, CastShadow=False)
part("BossArena", (1, 1, 1), (0, 1.5, SANCT_Z), BASALT, Transparency=1, CanCollide=False, CastShadow=False)
extra_spawns = []
for i in range(12):
    a = i / 12 * math.tau
    x, z = math.cos(a) * 110, math.sin(a) * 170
    extra_spawns.append({
        "name": f"Spawn{i + 1:02d}", "className": "SpawnLocation",
        "properties": {"Name": f"Spawn{i + 1:02d}", "Anchored": True, "Position": [round(x, 2), 1, round(z, 2)],
                       "Size": [8, 1, 8], "Neutral": True, "Duration": 0, "Transparency": 1,
                       "CanCollide": False, "CastShadow": False},
    })
# ---------------------------------------------------------------------------
# PONTOS DA FLECHA (ritual do boss): lugares fáceis e ACESOS pelo mapa. RitualService sorteia UM
# ArrowSpot* e põe a flecha perdida em cima (caiu do céu; quem pega vira o boss no altar à noite).
# Cada ponto = pedestal baixo + poste com lanterna (luz quente) para ser visto de longe, também à noite.
# Coordenadas no mapa importado (chão y≈0, área andável ±240). NÃO passam pelo giro do santuário.
# ---------------------------------------------------------------------------
ARROW_SPOTS = [(-160, -160), (160, -160), (-205, 10), (205, 25), (-168, 188), (5, -215), (190, 150), (-45, 120)]
for i, (sx, sz) in enumerate(ARROW_SPOTS):
    cylinder(f"ArrowPad{i}", 2.6, 0.5, (sx, 0.25, sz), BASALT)
    part(f"ArrowSpot{i}", (1.6, 0.6, 1.6), (sx, 0.8, sz), ("Slate", (0.14, 0.14, 0.17)))
    cylinder(f"ArrowPost{i}", 0.25, 7, (sx + 2.2, 3.5, sz + 2.2), ("Metal", (0.2, 0.19, 0.18)))
    part(f"ArrowPostArm{i}", (2.2, 0.25, 0.25), (sx + 1.2, 6.9, sz + 2.2), ("Metal", (0.2, 0.19, 0.18)))
    lantern = part(f"ArrowLantern{i}", (0.9, 1.1, 0.9), (sx + 0.3, 6.3, sz + 2.2), ("Neon", (1.0, 0.78, 0.45)), CastShadow=False)
    light(lantern, (1.0, 0.75, 0.45), 2.2, 26)

# aplica o deslocamento/giro do santuário em todas as partes Boss* (altar, spawn, arena, pilares...)
_yaw = math.radians(SANCT_YAW)
for node in parts:
    if not node["name"].startswith("Boss"):
        continue
    pr = node["properties"]
    x, y, z = pr["Position"]
    dx, dz = x, z - SANCT_Z
    rx = dx * math.cos(_yaw) + dz * math.sin(_yaw)
    rz = -dx * math.sin(_yaw) + dz * math.cos(_yaw)
    pr["Position"] = [round(SANCT_WORLD[0] + rx, 3), round(y + SANCT_WORLD[1], 3), round(SANCT_WORLD[2] + rz, 3)]
    ox, oy, oz = pr.get("Orientation", [0, 0, 0])
    pr["Orientation"] = [ox, (oy + SANCT_YAW + 180) % 360 - 180, oz]

props = folder("Props", list(parts))
props["ignoreUnknownInstances"] = True  # o que o dono move/cria em Props no Studio fica como está
extras = {"className": "Model", "ignoreUnknownInstances": True,
          "children": [props, folder("Spawns", extra_spawns)]}
OUT_EXTRAS.write_text(json.dumps(extras, indent=1))
print(f"{OUT_EXTRAS}: {len(parts)} partes + {len(extra_spawns)} spawns")
