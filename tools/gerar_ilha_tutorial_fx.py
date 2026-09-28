#!/usr/bin/env python3
"""Gera a primeira ilha aberta de F/X usando apenas primitives/materials nativos."""

import json
import math
import random
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "src/workspace/FXTutorialIsland.model.json"
CX, CZ = 850, 0
rng = random.Random(28)

GRASS = ("LeafyGrass", (.24, .42, .22)); CLIFF = ("Slate", (.25, .27, .29))
SAND = ("Sand", (.78, .69, .48)); STONE = ("Cobblestone", (.43, .44, .46))
WOOD = ("WoodPlanks", (.43, .29, .17)); DARK = ("Basalt", (.16, .18, .21))
LEAF = ("LeafyGrass", (.18, .38, .18)); WATER = ("Glass", (.12, .40, .57))
NEON = ("Neon", (.35, .85, 1)); ROOF = ("Slate", (.22, .12, .13))

folders = {name: [] for name in ("Terrain", "Porto", "Vila", "Treino", "Bosque", "Ruinas", "Portais", "Spawns")}

def part(folder, name, size, pos, mat, rot=(0, 0, 0), cls="Part", **extra):
    material, color = mat
    props = {"Name": name, "Anchored": True, "Position": list(pos), "Size": list(size),
             "Color": list(color), "Material": material, "Orientation": list(rot),
             "TopSurface": "Smooth", "BottomSurface": "Smooth"}
    props.update(extra)
    node = {"name": name, "className": cls, "properties": props}
    folders[folder].append(node)
    return node

def cylinder(folder, name, radius, height, pos, mat, **extra):
    return part(folder, name, (height, radius * 2, radius * 2), pos, mat, (0, 0, 90), Shape="Cylinder", **extra)

def tree(i, x, z, scale=1):
    cylinder("Bosque", f"Tronco{i}", 1.3*scale, 9*scale, (x, 5*scale, z), WOOD)
    part("Bosque", f"Copa{i}", (8*scale, 7*scale, 8*scale), (x, 11*scale, z), LEAF, Shape="Ball")

# Mar dá limite natural e deixa o arquipélago visível. Começa em x=300 para NÃO passar por baixo
# da arena/santuário/cachoeira (x -185..212); antes ia de x=-50 e aparecia dentro do mapa antigo.
part("Terrain", "Mar", (1450, 4, 1000), (1025, -7, CZ), WATER, Transparency=.32, CanCollide=False, CastShadow=False)
# Falésias em camadas: silhueta irregular, sem parede de arena.
for i, (sx, sz, y) in enumerate(((310,230,-3),(285,210,-1),(255,185,1))):
    cylinder("Terrain", f"IlhaCamada{i}", 1, sx, (CX, y, CZ), CLIFF if i < 2 else GRASS)
    # Corrige o cilindro achatado para elipse via Size explícito.
    folders["Terrain"][-1]["properties"]["Size"] = [2, sx, sz]
for i in range(20):
    a = i / 20 * math.tau
    r = rng.uniform(118, 145)
    cylinder("Terrain", f"Praia{i}", 10, .4, (CX+math.cos(a)*r, 2.2, CZ+math.sin(a)*r), SAND, CastShadow=False)

# Eixo principal: porto sul -> vila -> campo de treino -> ruínas norte.
for i in range(15):
    part("Terrain", f"Caminho{i}", (13, .25, 18), (CX+rng.uniform(-2,2), 3.2, 112-i*15), STONE, (0,rng.uniform(-4,4),0))

# Porto e farol.
for i in range(7): part("Porto", f"Cais{i}", (18, 1, 14), (CX, 3, 145+i*12), WOOD)
for side in (-8,8):
    for i in range(8): cylinder("Porto", f"Estaca{side}_{i}", .7, 9, (CX+side, -1, 145+i*12), DARK)
cylinder("Porto", "FarolTorre", 7, 27, (CX-45, 15, 120), STONE)
part("Porto", "FarolLuz", (6,5,6), (CX-45, 30, 120), NEON, Shape="Ball", CastShadow=False)

# Vila tutorial: casas simples em torno de praça aberta.
cylinder("Vila", "Praca", 34, .5, (CX, 3.3, 38), STONE)
for i, a in enumerate((25,95,155,205,275,335)):
    ar=math.radians(a); x=CX+math.cos(ar)*50; z=38+math.sin(ar)*50
    part("Vila", f"Casa{i}", (24,14,20), (x,10,z), WOOD, (0,-a+90,0))
    part("Vila", f"Telhado{i}", (27,3,23), (x,18,z), ROOF, (0,-a+90,8 if i%2 else -8))
part("Vila", "HumanoiderSpot", (8,.4,8), (CX,3.7,38), NEON, Transparency=.65, CanCollide=False)

# Campo de treino aberto, suficientemente largo para o combate battlegrounds.
cylinder("Treino", "ArenaTreino", 42, .4, (CX-62,3.3,-42), SAND)
for i in range(8):
    a=i/8*math.tau
    cylinder("Treino", f"PilarTreino{i}", 1.6, 8, (CX-62+math.cos(a)*35,7.5,-42+math.sin(a)*35), DARK)
for i in range(3): cylinder("Treino", f"DummyPad{i}", 3, .3, (CX-78+i*16,3.7,-42), DARK)

# Bosque lateral cria rota de exploração e quebra a leitura urbana.
for i in range(28):
    a=rng.uniform(0,math.tau); r=rng.uniform(35,95)
    tree(i, CX+58+math.cos(a)*r*.65, -28+math.sin(a)*r, rng.uniform(.75,1.2))

# Ruínas na ponta norte: local do primeiro Rastro de Carlos e futuro guardião.
cylinder("Ruinas", "PatioRuinas", 45, .6, (CX,3.5,-118), STONE)
for i in range(12):
    a=i/12*math.tau; h=rng.choice((7,11,15,19))
    cylinder("Ruinas", f"Coluna{i}", 2, h, (CX+math.cos(a)*36,4+h/2,-118+math.sin(a)*36), STONE)
part("Ruinas", "RastroCarlos01", (5,1,5), (CX,4.3,-118), NEON, Transparency=.2, CanCollide=False)
part("Ruinas", "BossSpawn", (8,.4,8), (CX,3.9,-145), DARK, Transparency=.45, CanCollide=False)

# Portal preserva a arena antiga como ilha PvP; o service adiciona prompts e lógica.
for name, x, z in (("TutorialToArena",CX+105,72),("ArenaToTutorial",85,0),("TutorialToSolPartido",CX-105,72)):
    part("Portais", name, (10,16,2), (x,11,z), DARK)
    part("Portais", name+"Core", (7,12,1), (x,11,z), NEON, Transparency=.25, CanCollide=False)

part("Spawns", "TutorialSpawn", (10,1,10), (CX,4,130), ("Plastic", (.2,.7,.4)), cls="SpawnLocation", Transparency=1, CanCollide=False, Enabled=False, Neutral=True)

children = [{"name": name, "className": "Folder", "children": nodes} for name, nodes in folders.items()]
OUT.write_text(json.dumps({"className":"Model","ignoreUnknownInstances":True,"children":children}, indent=1)+"\n")
print(f"{OUT}: {sum(map(len, folders.values()))} instâncias-base")
