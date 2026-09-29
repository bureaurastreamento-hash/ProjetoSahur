#!/usr/bin/env python3
"""Ilha 3 do Capítulo 1 — ROTA DO ECLIPSE (Parte 3; BIBLIA_CAMPANHA_CAP1_v0.1.md): trecho do deserto egípcio, cânion, oásis e templo.

Layout do mundo (2026-09-28): o chão é Terrain (tools/studio/MontarMundo.luau); o bazar mesopotâmico
(zigurate + mercado, vila SE da arena antiga) fica a oeste desta área (ArenaExtras.Destructible).
Tudo aqui foi gerado com o chão em y=8 e desce DY para o chão em y=0.
"""
import json, math, random
from pathlib import Path
OUT=Path(__file__).resolve().parent.parent/"src/workspace/FXSolPartidoIsland.model.json"
CX,CZ=1800,-200; DY=-8; rng=random.Random(29)
SAND=("Sandstone",(.72,.49,.24)); ROCK=("Rock",(.39,.23,.15)); DARK=("Basalt",(.18,.14,.13))
GOLD=("Metal",(.75,.52,.16)); WATER=("Glass",(.08,.48,.62)); GREEN=("LeafyGrass",(.22,.46,.22)); NEON=("Neon",(1,.55,.12))
folders={n:[] for n in ("Canion","Oasis","Inimigos","Templo","Portais","Spawns")}
def part(f,n,s,p,m,r=(0,0,0),cls="Part",**x):
 mat,col=m; props={"Name":n,"Anchored":True,"Position":[p[0],p[1]+DY,p[2]],"Size":list(s),"Color":list(col),"Material":mat,"Orientation":list(r),"TopSurface":"Smooth","BottomSurface":"Smooth"}; props.update(x)
 folders[f].append({"name":n,"className":cls,"properties":props})
def cyl(f,n,rad,h,p,m,**x): part(f,n,(h,rad*2,rad*2),p,m,(0,0,90),Shape="Cylinder",**x)

for i in range(32):
 a=rng.uniform(0,math.tau); r=rng.uniform(65,140); h=rng.uniform(12,42)
 part("Canion",f"Rocha{i}",(rng.uniform(10,24),h,rng.uniform(10,25)),(CX+math.cos(a)*r,7+h/2,CZ+math.sin(a)*r),ROCK,(rng.uniform(-8,8),rng.uniform(0,180),rng.uniform(-6,6)))
for i in range(18):
 z=92-i*10
 part("Canion",f"Trilha{i}",(12,.3,14),(CX-55+math.sin(i*.5)*14,8.1,CZ+z),DARK,(0,rng.uniform(-10,10),0))
for i,(x,z) in enumerate(((-70,55),(-45,20),(-72,-18),(-35,-48),(25,-34))):
 part("Inimigos",f"EnemyPad{i}",(6,.3,6),(CX+x,8.3,CZ+z),NEON,Transparency=.75,CanCollide=False)

# Oásis baixo a leste, contraste visual e área segura.
cyl("Oasis","Agua",28,.5,(CX+67,8,CZ+48),WATER,Transparency=.25,CanCollide=False)
for i in range(10):
 a=i/10*math.tau; x=CX+67+math.cos(a)*34; z=CZ+48+math.sin(a)*34
 cyl("Oasis",f"Palmeira{i}",1,11,(x,14,z),DARK)
 part("Oasis",f"Copa{i}",(9,3,9),(x,21,z),GREEN,(0,i*37,0),Shape="Ball")

# Templo escalonado ao norte: rota vertical, bem diferente da primeira ilha.
for level in range(5):
 w=86-level*13; z=-78-level*10; y=10+level*7
 part("Templo",f"Nivel{level}",(w,6,34),(CX,y,CZ+z),DARK)
 part("Templo",f"Rampa{level}",(16,2,18),(CX,y+4,CZ+z+25),SAND,(18,0,0))
for side in (-28,28):
 for i in range(4): cyl("Templo",f"Coluna{side}_{i}",2,16,(CX+side,24,CZ-86-i*12),GOLD)
part("Templo","AltarSolar",(14,4,14),(CX,47,CZ-123),GOLD)
part("Templo","SolFraturado",(10,10,2),(CX,58,CZ-130),NEON,Shape="Ball",CastShadow=False)
part("Templo","TempleMarker",(8,1,8),(CX,49,CZ-123),NEON,Transparency=.55,CanCollide=False)
part("Templo","SolarBossSpawn",(9,1,9),(CX,49,CZ-105),DARK,Transparency=.5,CanCollide=False)

part("Portais","SolPartidoToPilares",(10,16,2),(CX-105,16,CZ+78),DARK)
part("Portais","SolPartidoToPilaresCore",(7,12,1),(CX-105,16,CZ+78),NEON,Transparency=.25,CanCollide=False)
part("Spawns","SolPartidoSpawn",(10,1,10),(CX-90,9,CZ+70),("Plastic",(.9,.6,.2)),cls="SpawnLocation",Transparency=1,CanCollide=False,Enabled=False,Neutral=True)
children=[{"name":n,"className":"Folder","children":v} for n,v in folders.items()]
OUT.write_text(json.dumps({"className":"Model","ignoreUnknownInstances":True,"children":children},indent=1)+"\n")
print(f"{OUT}: {sum(map(len,folders.values()))} instâncias-base")
