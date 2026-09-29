#!/usr/bin/env python3
"""Chão das ilhas do Capítulo 1 feito de PEÇAS (dono, 2026-09-28: "players gostam de simplicidade com coisas bem feitas").

Substitui a parte de terra do Terrain (tools/studio/MontarMundo.luau agora só faz o MAR de água). Saída:
src/workspace/ChaoIlhas.model.json → Workspace.Sahur.ChaoIlhas (Rojo). Rodar de novo depois de mexer aqui.

Forma: cada ilha é uma elipse (WorldConfig.Islands) cortada em faixas retas no eixo Z, com a borda levemente
irregular (determinística) — visual "quadrado", leve e fácil de texturizar:
  - Topo    : topo em y TOP (-0.15; os pisos das construções ficam em 0), até d D_TOPO da elipse.
  - Praia   : um degrau abaixo (TOP_PRAIA), até d D_PRAIA; areia molhada (TOP_MOLHADA) até D_MOLHADA.
  - RAMPAS (WedgePart) em todo o contorno, da areia molhada até dentro d'água: sem elas quem nada fica preso na
    parede da ilha (testado 29/09 com NPC). O contorno é calculado por LINHA de uma grade fixa de Z do mundo.
  - "Lóbulos": elipses extras que alargam a ilha onde a arte ficou perto da costa (Coliseu, vila mesopotâmica).
  - Sobreposições no topo (mesmo nível, recortadas do topo para não dar z-fighting): oásis, areia do Coliseu.
  - Recortes (pisos abaixo de 0): Taberna/Hall e o riacho/lago do jardim — viram um piso mais baixo.
  - Montanha do santuário em DEGRAUS (cachoeira na face sul; interior da casca do santuário oco) e dunas em degraus.
Medidas do santuário e da Taberna tiradas do place via MCP em 2026-09-29 (ArenaExtras.Props).
"""
import json
import math
import random
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "src/workspace/ChaoIlhas.model.json"

TOP = -0.15
TOP_PRAIA = -0.9  # degrau de 0.75 a partir do topo (humanoide sobe andando)
TOP_MOLHADA = -1.7  # areia molhada, 0.3 acima do mar (mar em -2)
RAMPA_FUNDO, RAMPA_COMP = -6.5, 14.0  # rampa (WedgePart) da areia molhada até dentro d'água: ~19°, dá para SAIR nadando
FUNDO = -8.0
FAIXA = 20  # largura (Z) de cada faixa
D_TOPO, D_PRAIA, D_MOLHADA = 0.90, 1.0, 1.06
JITTER = 0.025  # irregularidade da costa (mesma em todas as camadas: os anéis ficam paralelos)

# material, cor (0..1)
def rgb(r, g, b):
    return (round(r / 255, 4), round(g / 255, 4), round(b / 255, 4))

GRAMA_NEVOA = ("Grass", rgb(98, 150, 78))
AREIA = ("Sand", rgb(226, 204, 146))
DESERTO = ("Sand", rgb(214, 156, 98))  # Deserto do Sol: areia avermelhada (deserto com ruínas astecas)
DESERTO_PRAIA = ("Sand", rgb(232, 196, 140))
ROCHA_DESERTO = ("Sandstone", rgb(178, 110, 74))
OASIS = ("LeafyGrass", rgb(82, 146, 64))
AREIA_ARENA = ("Sand", rgb(222, 196, 140))
ECLIPSE = ("Sand", rgb(234, 212, 156))  # Rota do Eclipse: deserto claro
DUNA = ("Sand", rgb(226, 194, 128))
KAME = ("Sand", rgb(236, 214, 160))

ILHAS = [  # = WorldConfig.Islands
    {"id": "PortoDaNevoa", "c": (150, -40), "rx": 330, "rz": 290, "topo": GRAMA_NEVOA, "praia": AREIA, "seed": 1},
    {"id": "DesertoDoSol", "c": (910, -500), "rx": 320, "rz": 305, "topo": DESERTO, "praia": DESERTO_PRAIA, "seed": 2,
     "lobos": [(900, -330, 175, 175), (1150, -440, 110, 100)]},  # Coliseu (fachada r124) e vila mesopotâmica NW
    {"id": "RotaDoEclipse", "c": (1700, -130), "rx": 340, "rz": 290, "topo": ECLIPSE, "praia": AREIA, "seed": 3},
    {"id": "IlhotaKame", "c": (-450, 560), "rx": 300, "rz": 140, "topo": KAME, "praia": AREIA, "seed": 4},
]

# Sobreposições no nível do topo: (ilha, nome, centro, rx, rz, material)
SOBREPOSICOES = [
    ("DesertoDoSol", "Oasis", (900, -668), 140, 72, OASIS),  # jardim/cachoeira = oásis
    ("DesertoDoSol", "AreiaColiseu", (900, -340), 97, 97, AREIA_ARENA),
]
# Recortes: (ilha, nome, x0, x1, z0, z1, topo mais baixo) — pisos das construções abaixo de 0
RECORTES = [
    ("PortoDaNevoa", "Taberna", 272, 392, 20, 142, -0.95),
    # = escavações do Terrain antigo (peças Stream / CascadePool / GardenSlab, com folga de 1)
    ("DesertoDoSol", "Riacho", 889, 912, -705, -645, -1.1),
    ("DesertoDoSol", "Lago", 863, 937, -655, -619, -1.1),
    ("DesertoDoSol", "Laje", 895, 906, -710, -655, -1.1),
]

parts = {}  # pasta -> lista


def part(pasta, nome, x0, x1, y0, y1, z0, z1, mat, **extra):
    material, cor = mat
    props = {
        "Name": nome, "Anchored": True, "CanCollide": True,
        "Position": [round((x0 + x1) / 2, 3), round((y0 + y1) / 2, 3), round((z0 + z1) / 2, 3)],
        "Size": [round(x1 - x0, 3), round(y1 - y0, 3), round(z1 - z0, 3)],
        "Color": list(cor), "Material": material, "TopSurface": "Smooth", "BottomSurface": "Smooth",
    }
    props.update(extra)
    parts.setdefault(pasta, []).append({"name": nome, "className": "Part", "properties": props})


def cunha(pasta, nome, cx, cz, largura, comp, y0, y1, yaw, mat):
    """WedgePart: rampa descendo para a LookVector (frente). yaw 0 → desce para -Z; 180 → +Z; 90 → -X; -90 → +X."""
    material, cor = mat
    parts.setdefault(pasta, []).append({"name": nome, "className": "WedgePart", "properties": {
        "Name": nome, "Anchored": True, "CanCollide": True,
        "Position": [round(cx, 3), round((y0 + y1) / 2, 3), round(cz, 3)],
        "Size": [round(largura, 3), round(y1 - y0, 3), round(comp, 3)],
        "Orientation": [0, yaw, 0], "Color": list(cor), "Material": material,
    }})


def subtrair(r, cortes):
    """Retângulo r=(x0,x1,z0,z1) menos a lista de retângulos → lista de retângulos."""
    res = [r]
    for c in cortes:
        nova = []
        for (x0, x1, z0, z1) in res:
            cx0, cx1, cz0, cz1 = max(x0, c[0]), min(x1, c[1]), max(z0, c[2]), min(z1, c[3])
            if cx0 >= cx1 or cz0 >= cz1:
                nova.append((x0, x1, z0, z1))
                continue
            if z0 < cz0: nova.append((x0, x1, z0, cz0))
            if cz1 < z1: nova.append((x0, x1, cz1, z1))
            if x0 < cx0: nova.append((x0, cx0, cz0, cz1))
            if cx1 < x1: nova.append((cx1, x1, cz0, cz1))
        res = nova
    return [r for r in res if r[1] - r[0] > 0.05 and r[3] - r[2] > 0.05]


def faixas_elipse(cx, cz, rx, rz, escala, rng=None, jitter=0.0, faixa=FAIXA):  # usado nas sobreposições
    """Faixas retangulares que aproximam a elipse (rx, rz)*escala. As faixas seguem uma grade de Z do MUNDO
    (múltiplos de `faixa`), igual para todas as camadas: assim subtrair uma camada da outra só corta em X."""
    out = []
    rze = rz * escala
    zi = math.floor((cz - rze) / faixa) * faixa
    while zi < cz + rze:
        z0, z1 = max(zi, cz - rze), min(zi + faixa, cz + rze)
        zi += faixa
        if z1 - z0 < 1:
            continue
        t = ((z0 + z1) / 2 - cz) / rze
        if abs(t) >= 1:
            continue
        meia = rx * escala * math.sqrt(1 - t * t)
        if rng:
            meia *= 1 + rng.uniform(-jitter, jitter)
        out.append((round(cx - meia, 2), round(cx + meia, 2), round(z0, 2), round(z1, 2)))
    return out


def juntar(ivs):
    """União de intervalos [a, b]."""
    out = []
    for a, b in sorted(ivs):
        if out and a <= out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], b))
        else:
            out.append((a, b))
    return [(round(a, 2), round(b, 2)) for a, b in out]


def menos(ivs, cortes):
    """Intervalos ivs menos a união `cortes`."""
    res = list(ivs)
    for (c0, c1) in cortes:
        nova = []
        for (a, b) in res:
            if c1 <= a or c0 >= b:
                nova.append((a, b)); continue
            if a < c0: nova.append((a, c0))
            if c1 < b: nova.append((c1, b))
        res = nova
    return [(a, b) for a, b in res if b - a > 0.05]


# ---------------------------------------------------------------------------
# Ilhas
for ilha in ILHAS:
    cx, cz = ilha["c"]
    rx, rz = ilha["rx"], ilha["rz"]
    nome = ilha["id"]
    pasta = nome
    sobre = [(s[1], s[2], s[3], s[4], s[5]) for s in SOBREPOSICOES if s[0] == nome]
    rec = [r[1:] for r in RECORTES if r[0] == nome]
    # retângulos das sobreposições e recortes (tirados do topo)
    buracos = []
    rec_rects = [(x0, x1, z0, z1) for (_, x0, x1, z0, z1, _t) in rec]
    for (sn, (sx, sz), srx, srz, smat) in sobre:
        k = 0
        for f in faixas_elipse(sx, sz, srx, srz, 1.0, faixa=12):
            for r in subtrair(f, rec_rects):
                part(pasta, f"{sn}{k}", r[0], r[1], TOP - 1.2, TOP, r[2], r[3], smat); k += 1
            buracos.append(f)
    feitos = []
    for (rn, x0, x1, z0, z1, topo) in rec:
        for k, r in enumerate(subtrair((x0, x1, z0, z1), feitos)):
            part(pasta, f"Recorte{rn}{k}", r[0], r[1], FUNDO, topo, r[2], r[3], ilha["topo"])
        feitos.append((x0, x1, z0, z1))
        buracos.append((x0, x1, z0, z1))
    # Camadas por LINHA (grade fixa de Z do mundo): união da elipse principal com os lóbulos.
    elipses = [(cx, cz, rx, rz)] + list(ilha.get("lobos", []))
    def linhas(escala):
        rows = {}
        for (ex, ez, erx, erz) in elipses:
            rze = erz * escala
            zi = math.floor((ez - rze) / FAIXA) * FAIXA
            while zi < ez + rze:
                tz = (zi + FAIXA / 2 - ez) / rze
                if abs(tz) < 1:
                    r = random.Random(ilha["seed"] * 100003 + int(zi))
                    meia = erx * escala * math.sqrt(1 - tz * tz)
                    rows.setdefault(zi, []).append((ex - meia * (1 + JITTER * r.uniform(-1, 1)), ex + meia * (1 + JITTER * r.uniform(-1, 1))))
                zi += FAIXA
        return {z: juntar(iv) for z, iv in rows.items()}
    L_topo, L_praia, L_molhada = linhas(D_TOPO), linhas(D_PRAIA), linhas(D_MOLHADA)
    def anel(fora, dentro):
        return [(a, b, z, z + FAIXA) for z, ivs in sorted(fora.items()) for (a, b) in menos(ivs, dentro.get(z, []))]
    topo = [(a, b, z, z + FAIXA) for z, ivs in sorted(L_topo.items()) for (a, b) in ivs]
    k = 0
    for f in topo:
        for r in subtrair(f, buracos):
            part(pasta, f"Topo{k}", r[0], r[1], TOP - 1.2, TOP, r[2], r[3], ilha["topo"]); k += 1
    # corpo embaixo do topo (sobreposições inclusas; recortes têm corpo próprio)
    corpo_mat = ilha["praia"] if ilha["topo"][0] == "Sand" else ("Ground", rgb(110, 92, 66))
    k = 0
    for f in topo:
        for r in subtrair(f, rec_rects):
            part(pasta, f"Corpo{k}", r[0], r[1], FUNDO, TOP - 1.2, r[2], r[3], corpo_mat); k += 1
    for k, r in enumerate(anel(L_praia, L_topo)):
        part(pasta, f"Praia{k}", r[0], r[1], FUNDO, TOP_PRAIA, r[2], r[3], ilha["praia"])
    molhada = (ilha["praia"][0], tuple(round(c * 0.86, 4) for c in ilha["praia"][1]))
    for k, r in enumerate(anel(L_molhada, L_praia)):
        part(pasta, f"Molhada{k}", r[0], r[1], FUNDO, TOP_MOLHADA, r[2], r[3], molhada)
    # rampas no contorno externo (pontas de cada linha em X + trechos expostos em Z)
    k = 0
    h0, h1 = RAMPA_FUNDO, TOP_MOLHADA
    for z, ivs in sorted(L_molhada.items()):
        for (a, b) in ivs:
            cunha(pasta, f"Rampa{k}", a - RAMPA_COMP / 2, z + FAIXA / 2, FAIXA, RAMPA_COMP, h0, h1, 90, molhada); k += 1
            cunha(pasta, f"Rampa{k}", b + RAMPA_COMP / 2, z + FAIXA / 2, FAIXA, RAMPA_COMP, h0, h1, -90, molhada); k += 1
        for (a, b) in menos(ivs, L_molhada.get(z + FAIXA, [])):  # borda +Z exposta
            cunha(pasta, f"Rampa{k}", (a + b) / 2, z + FAIXA + RAMPA_COMP / 2, b - a, RAMPA_COMP, h0, h1, 180, molhada); k += 1
        for (a, b) in menos(ivs, L_molhada.get(z - FAIXA, [])):  # borda -Z exposta
            cunha(pasta, f"Rampa{k}", (a + b) / 2, z - RAMPA_COMP / 2, b - a, RAMPA_COMP, h0, h1, 0, molhada); k += 1

# ---------------------------------------------------------------------------
# Montanha do santuário (Deserto do Sol): casca do santuário x 832..968, z -623..-533, y -4..34 (oca).
# Enchimentos da arte (SanctFillW/E) vão de x 802 a 1014. Face sul (z -623) = paredão da cachoeira (topo da queda y 92).
# Degraus: oeste e fundo (norte, z+). Leste é paredão: a escavação e as ruínas mesopotâmicas ficam ali (x ≥ 1030).
M = "MontanhaSantuario"
X0, X1, Z0, Z1, TOPO_M = 800, 1016, -623, -517, 95.0
CASCA = (832, 969, -623, -533)
part(M, "Topo", X0, X1, 34, TOPO_M, Z0, Z1, ROCHA_DESERTO)
for i, r in enumerate(subtrair((X0, X1, Z0, Z1), [CASCA])):
    part(M, f"Base{i}", r[0], r[1], FUNDO, 34, r[2], r[3], ROCHA_DESERTO)
DEGRAUS = 4
PASSO_O, PASSO_N, PASSO_L = 14, 10, 4
ant = (X0, X1, Z0, Z1)
for n in range(1, DEGRAUS + 1):
    alto = TOPO_M - n * (TOPO_M / (DEGRAUS + 1))
    atual = (X0 - PASSO_O * n, X1 + PASSO_L * n, Z0, Z1 + PASSO_N * n)
    for i, r in enumerate(subtrair(atual, [ant])):
        part(M, f"Degrau{n}_{i}", r[0], r[1], FUNDO, alto, r[2], r[3], ROCHA_DESERTO)
    ant = atual

# Dunas em degraus (Rota do Eclipse) — mesmas caixas do MontarMundo antigo (x0, x1, z0, z1, topo)
for d, (x0, x1, z0, z1, alto) in enumerate(((1860, 1930, -40, 20, 9), (1560, 1640, -330, -280, 12), (1960, 2000, -260, -150, 16))):
    niveis = 4
    for n in range(niveis):
        m = (niveis - 1 - n) * 9  # margem: degrau de baixo é o mais largo
        y1 = TOP + alto * (n + 1) / niveis
        part("Dunas", f"Duna{d}_{n}", x0 - m, x1 + m, TOP - 1, y1, z0 - m, z1 + m, DUNA if n % 2 == 0 else ("Sand", rgb(232, 204, 142)))

# ---------------------------------------------------------------------------
children = [{"name": nome, "className": "Folder", "children": lista} for nome, lista in parts.items()]
OUT.write_text(json.dumps({"className": "Model", "ignoreUnknownInstances": True, "children": children}, indent=1) + "\n")
print(f"{OUT}: {sum(map(len, parts.values()))} peças em {len(parts)} pastas")
for nome, lista in parts.items():
    print(f"  {nome}: {len(lista)}")
