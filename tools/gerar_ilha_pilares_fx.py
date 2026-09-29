#!/usr/bin/env python3
"""Ilha 2 do Capítulo 1 — DESERTO DO SOL (Parte 2 / Battle Tendency; BIBLIA_CAMPANHA_CAP1_v0.1.md).
Ids/nomes de arquivo continuam "Pilares" (ilha_pilares, FXPilaresIsland) para não quebrar saves e o Rojo.
Ruínas astecas, santuário na montanha da cachoeira (= "A Câmara", Missão 9) e COLISEU.

O jardim amazônico, a cachoeira e o santuário do boss são a ArenaExtras (tools/gerar_arena.py, translado
OFF_SANTUARIO); o piso e os 16 pilares do coliseu vieram da arena antiga (src/workspace/Coliseu.rbxm,
tools/desmontar_arena.luau). Aqui: muralha/arquibancada do coliseu, praça de chegada e portais.
Chão = Terrain (tools/studio/MontarMundo.luau), y = 0.
"""
import json
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "src/workspace/FXPilaresIsland.model.json"
CX, CZ = 900, -340  # centro do coliseu (= COLISEU em desmontar_arena.luau)
TRAVERTINE = ("Limestone", (.80, .74, .62)); STONE = ("Cobblestone", (.52, .50, .46)); DARK = ("Basalt", (.2, .18, .17))
SAND = ("Sand", (.74, .66, .5)); NEON = ("Neon", (.35, .85, 1)); BRONZE = ("Metal", (.55, .38, .2))
folders = {n: [] for n in ("Coliseu", "Chegada", "Historia", "Portais", "Spawns")}


def part(f, n, s, p, m, r=(0, 0, 0), cls="Part", **x):
    mat, col = m
    props = {"Name": n, "Anchored": True, "Position": [round(v, 3) for v in p], "Size": [round(v, 3) for v in s],
             "Color": list(col), "Material": mat, "Orientation": [round(v, 3) for v in r],
             "TopSurface": "Smooth", "BottomSurface": "Smooth"}
    props.update(x)
    folders[f].append({"name": n, "className": cls, "properties": props})


def cyl(f, n, rad, h, p, m, **x):
    part(f, n, (h, rad * 2, rad * 2), p, m, (0, 0, 90), Shape="Cylinder", **x)


def ring_segment(f, n, radius, a, width, size_y, y, depth, mat, **x):
    """Bloco tangente ao anel no ângulo a (graus); face larga virada para o centro."""
    ar = math.radians(a)
    part(f, n, (width, size_y, depth), (CX + math.cos(ar) * radius, y, CZ + math.sin(ar) * radius), mat, (0, 90 - a, 0), **x)


# Arena de areia sobre os ladrilhos (anel entre o piso de ladrilhos r72 e o muro r96)
for i in range(36):
    a = i * 10
    ring_segment("Coliseu", f"AreiaAnel{i}", 84, a, 15.5, .3, .15, 24, SAND)

# Muro do pódio (r 96) com 2 portões: oeste (180°, praça de chegada) e norte (270°, santuário)
GATES = (180, 270)
N = 32
for i in range(N):
    a = i * 360 / N
    if any(abs((a - g + 180) % 360 - 180) < 8 for g in GATES):
        continue
    ring_segment("Coliseu", f"Podio{i}", 96, a, 19.5, 7, 3.5, 3, TRAVERTINE)
# Arquibancada: 4 degraus subindo para fora
for t in range(4):
    r = 101 + t * 5
    for i in range(N + 8):
        a = i * 360 / (N + 8)
        if any(abs((a - g + 180) % 360 - 180) < 9 for g in GATES):
            continue
        ring_segment("Coliseu", f"Degrau{t}_{i}", r, a, 2 * math.pi * r / (N + 8) + .6, 7 + t * 4, (7 + t * 4) / 2, 5, STONE)
# Fachada externa com arcos: pilares + vergas (r 124), 2 andares
for i in range(N + 8):
    a = i * 360 / (N + 8)
    if any(abs((a - g + 180) % 360 - 180) < 9 for g in GATES):
        continue
    ring_segment("Coliseu", f"FachadaPilar{i}", 124, a, 4, 34, 17, 5, TRAVERTINE)
    ring_segment("Coliseu", f"FachadaVerga{i}", 124, a + 180 / (N + 8), 2 * math.pi * 124 / (N + 8) + 1, 3, 15, 5, TRAVERTINE)
    ring_segment("Coliseu", f"FachadaTopo{i}", 124, a + 180 / (N + 8), 2 * math.pi * 124 / (N + 8) + 1, 4, 33, 5, TRAVERTINE)
# Portões: arco de pedra + tochas de bronze
for g in GATES:
    ar = math.radians(g)
    for side in (-1, 1):
        o = math.radians(g + 90)
        x = CX + math.cos(ar) * 124 + math.cos(o) * 11 * side
        z = CZ + math.sin(ar) * 124 + math.sin(o) * 11 * side
        part("Coliseu", f"Portao{g}Pilar{side}", (6, 30, 6), (x, 15, z), TRAVERTINE, (0, 90 - g, 0))
        cyl("Coliseu", f"Portao{g}Tocha{side}", .8, 4, (x + math.cos(ar) * 4, 20, z + math.sin(ar) * 4), BRONZE)
    part("Coliseu", f"Portao{g}Verga", (28, 5, 6), (CX + math.cos(ar) * 124, 32.5, CZ + math.sin(ar) * 124), TRAVERTINE, (0, 90 - g, 0))

# Praça de chegada (oeste do coliseu, perto da praia) + portais
AX, AZ = 690, -420
cyl("Chegada", "Praca", 24, .5, (AX, .25, AZ), STONE)
for i in range(8):
    a = i / 8 * math.tau
    cyl("Chegada", f"Coluna{i}", 1.6, 12, (AX + math.cos(a) * 21, 6, AZ + math.sin(a) * 21), TRAVERTINE)
for name, dz in (("PilaresToTutorial", -30), ("PilaresToSolPartido", 30)):
    part("Portais", name, (10, 16, 2), (AX - 22, 8, AZ + dz), DARK, (0, 90, 0))
    part("Portais", name + "Core", (7, 12, 1), (AX - 22, 8, AZ + dz), NEON, (0, 90, 0), Transparency=.25, CanCollide=False)
# ---------------------------------------------------------------------------
# Campanha (DesertoDoSolService liga pelo NOME). Alturas conferidas por raycast no place (2026-09-29).
# Missão 7 — escavação a leste: os Homens de Pedra despertaram cedo por causa da F/X.
EX, EZ = 1070, -490
for i in range(10):
    a = i / 10 * math.tau
    part("Historia", f"EscavacaoBorda{i}", (9, 2.5, 3), (EX + math.cos(a) * 34, 1, EZ + math.sin(a) * 34), SAND,
         (0, 90 - math.degrees(a), 0))
for i, (x, z, r) in enumerate(((-12, 8, 20), (0, -22, -35), (2, 18, 70))):  # estátuas deitadas meio enterradas
    part("Historia", f"HomemDePedraDormindo{i}", (4, 3, 11), (EX + x, .9, EZ + z), DARK, (0, r, 0))
for i, (x, z) in enumerate(((-10, 20), (10, -5), (-30, 10), (30, -20))):
    part("Historia", f"EscavacaoPad{i}", (6, .3, 6), (EX + x, .3, EZ + z), NEON, Transparency=.75, CanCollide=False)
# Missão 8 — o mestre da respiração e o discípulo de treino, perto da praça de chegada.
part("Historia", "MestreSpot", (4, .3, 4), (720, .3, -470), SAND, Transparency=1, CanCollide=False)
part("Historia", "DiscipuloPad", (6, .3, 6), (735, .3, -485), NEON, Transparency=.75, CanCollide=False)
# Missões 9–10 — dentro do santuário (entrada pela cachoeira ao sul; altar do ritual antigo fica em z -557).
part("Historia", "CamaraMarker", (6, 1, 6), (884, .8, -575), NEON, Transparency=.55, CanCollide=False)
part("Historia", "SacerdoteSpawn", (8, .4, 8), (900, .6, -600), DARK, Transparency=1, CanCollide=False)

part("Spawns", "PilaresSpawn", (10, 1, 10), (AX, 1, AZ), ("Plastic", (.8, .7, .4)), cls="SpawnLocation",
     Transparency=1, CanCollide=False, Enabled=False, Neutral=True)

children = [{"name": n, "className": "Folder", "children": v} for n, v in folders.items()]
OUT.write_text(json.dumps({"className": "Model", "ignoreUnknownInstances": True, "children": children}, indent=1) + "\n")
print(f"{OUT}: {sum(map(len, folders.values()))} instâncias-base")
