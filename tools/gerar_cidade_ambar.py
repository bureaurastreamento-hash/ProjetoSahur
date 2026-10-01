#!/usr/bin/env python3
"""Ilha 4 do Capítulo 1 — CIDADE ÂMBAR (BIBLIA_CAMPANHA_CAP1_v0.1.md, Missões 16–20; contrato em CIDADE_AMBAR_INTEGRACAO.md).

Gera `src/workspace/FXCidadeAmbar.model.json` (Workspace.Sahur.FXCidadeAmbar): chão próprio de peças lisas (o mesmo
esquema topo/praia/areia molhada/rampas de tools/gerar_chao_ilhas.py — que NÃO deve ser rodado de novo), ruas, praça,
casas, feira, posto da guarda, escola, parque, pátio do chefe e TODOS os marcadores do contrato. O portal de ida
(`SolPartidoToAmbar`) fica na pasta `PortalRota`, na Rota do Eclipse, ao lado do SolPartidoToPilares.

Fica a leste da Rota do Eclipse, longe dos retângulos de WorldConfig.Islands (CampaignMapRegistration recusa sobreposição).
Só peças SmoothPlastic/Neon, só cor. Rodar de novo SOBRESCREVE edições manuais feitas no Studio dentro deste Model.
"""
import json, math, random
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "src/workspace/FXCidadeAmbar.model.json"
CX, CZ = 2330, -120          # centro da ilha (= AmbarCentro)
RX, RZ = 230, 200            # FXRadiusX/FXRadiusZ (limites da região) = elipse da ilha
TOP, TOP_PRAIA, TOP_MOLHADA = -0.15, -0.9, -1.7
RAMPA_FUNDO, RAMPA_COMP, FUNDO = -6.5, 14.0, -8.0
FAIXA, JITTER = 20, 0.02
D_TOPO, D_PRAIA, D_MOLHADA = 0.90, 1.0, 1.06
LISO, NEON = "SmoothPlastic", "Neon"
rng = random.Random(44)


def rgb(r, g, b):
    return (round(r / 255, 4), round(g / 255, 4), round(b / 255, 4))


GRAMA = rgb(146, 150, 82)       # grama de outono
TERRA = rgb(116, 94, 64)
AREIA = rgb(226, 204, 146)
MOLHADA = tuple(round(c * 0.86, 4) for c in AREIA)
ASFALTO = rgb(78, 74, 72)
CALCADA = rgb(188, 176, 156)
PRACA = rgb(214, 190, 150)
MADEIRA = rgb(120, 84, 54)
MADEIRA_CLARA = rgb(164, 120, 76)
ESCURO = rgb(48, 42, 40)
AGUA = rgb(70, 140, 170)
AMBAR = rgb(255, 170, 60)
PAREDES = [rgb(232, 196, 130), rgb(214, 150, 92), rgb(236, 222, 190), rgb(190, 112, 78), rgb(176, 168, 120),
           rgb(222, 176, 104), rgb(200, 134, 110)]
TELHADOS = [rgb(140, 64, 46), rgb(110, 58, 44), rgb(96, 76, 66), rgb(150, 86, 50)]
JANELA = rgb(250, 226, 160)
COPAS = [rgb(222, 128, 40), rgb(236, 168, 52), rgb(196, 86, 40), rgb(168, 150, 60)]

folders = {}


def add(folder, cls, name, props, children=None, attributes=None):
    node = {"name": name, "className": cls, "properties": props}
    if children:
        node["children"] = children
    if attributes:
        node["attributes"] = attributes
    folders.setdefault(folder, []).append(node)
    return node


def part(folder, name, size, pos, color, yaw=0.0, material=LISO, cls="Part", children=None, attributes=None, **extra):
    props = {"Name": name, "Anchored": True, "Size": [round(v, 3) for v in size],
             "Position": [round(pos[0], 3), round(pos[1], 3), round(pos[2], 3)],
             "Orientation": [0, round(yaw, 3), 0], "Color": list(color), "Material": material,
             "TopSurface": "Smooth", "BottomSurface": "Smooth"}
    props.update(extra)
    return add(folder, cls, name, props, children, attributes)


def box(folder, name, x0, x1, y0, y1, z0, z1, color, **extra):
    return part(folder, name, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, **extra)


def W(lx, lz):
    """Coordenada local (relativa ao centro) → mundo."""
    return CX + lx, CZ + lz


def rot(x, z, yaw):
    """Gira o deslocamento local (x, z) como CFrame.Angles(0, yaw, 0) do Roblox."""
    a = math.radians(yaw)
    return x * math.cos(a) + z * math.sin(a), -x * math.sin(a) + z * math.cos(a)


def local_part(folder, name, origin, yaw, size, off, color, extra_yaw=0.0, **kw):
    """Peça num referencial local (frente = +Z local) com origem (x, y, z) e giro yaw."""
    dx, dz = rot(off[0], off[2], yaw)
    return part(folder, name, size, (origin[0] + dx, origin[1] + off[1], origin[2] + dz), color, yaw + extra_yaw, **kw)


def marker(name, pos, size=(4, 0.2, 4), yaw=0.0, visible=False, color=AMBAR, collide=False, **kw):
    """Marcador do contrato: BasePart ancorada com nome único (CidadeAmbarService)."""
    return part("Marcadores", name, size, pos, color, yaw, CanCollide=collide, CanQuery=collide,
                Transparency=0 if visible else 1, CastShadow=visible, **kw)


def light(range_, brightness=1.1, color=(1, 0.78, 0.45)):
    return [{"name": "Luz", "className": "PointLight",
             "properties": {"Range": range_, "Brightness": brightness, "Color": list(color), "Shadows": False}}]


# ---------------------------------------------------------------------------------------------------- chão da ilha
def juntar(ivs):
    out = []
    for a, b in sorted(ivs):
        if out and a <= out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], b))
        else:
            out.append((a, b))
    return out


def menos(ivs, cortes):
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


def linhas(escala):
    rows = {}
    rze = RZ * escala
    zi = math.floor((CZ - rze) / FAIXA) * FAIXA
    while zi < CZ + rze:
        tz = (zi + FAIXA / 2 - CZ) / rze
        if abs(tz) < 1:
            r = random.Random(4 * 100003 + int(zi))
            meia = RX * escala * math.sqrt(1 - tz * tz)
            rows[zi] = juntar([(CX - meia * (1 + JITTER * r.uniform(-1, 1)), CX + meia * (1 + JITTER * r.uniform(-1, 1)))])
        zi += FAIXA
    return rows


L_topo, L_praia, L_molhada = linhas(D_TOPO), linhas(D_PRAIA), linhas(D_MOLHADA)
k = 0
for z, ivs in sorted(L_topo.items()):
    for (a, b) in ivs:
        box("Chao", f"Topo{k}", a, b, TOP - 1.2, TOP, z, z + FAIXA, GRAMA)
        box("Chao", f"Corpo{k}", a, b, FUNDO, TOP - 1.2, z, z + FAIXA, TERRA); k += 1
k = 0
for z, ivs in sorted(L_praia.items()):
    for (a, b) in menos(ivs, L_topo.get(z, [])):
        box("Chao", f"Praia{k}", a, b, FUNDO, TOP_PRAIA, z, z + FAIXA, AREIA); k += 1
k = 0
for z, ivs in sorted(L_molhada.items()):
    for (a, b) in menos(ivs, L_praia.get(z, [])):
        box("Chao", f"Molhada{k}", a, b, FUNDO, TOP_MOLHADA, z, z + FAIXA, MOLHADA); k += 1


def cunha(name, cx, cz, largura, comp, yaw):
    part("Chao", name, (largura, TOP_MOLHADA - RAMPA_FUNDO, comp), (cx, (RAMPA_FUNDO + TOP_MOLHADA) / 2, cz), MOLHADA, yaw,
         cls="WedgePart")


k = 0
for z, ivs in sorted(L_molhada.items()):  # beira d'água sempre com rampa (nadador não fica preso em parede)
    for (a, b) in ivs:
        cunha(f"Rampa{k}", a - RAMPA_COMP / 2, z + FAIXA / 2, FAIXA, RAMPA_COMP, 90); k += 1
        cunha(f"Rampa{k}", b + RAMPA_COMP / 2, z + FAIXA / 2, FAIXA, RAMPA_COMP, -90); k += 1
    for (a, b) in menos(ivs, L_molhada.get(z + FAIXA, [])):
        cunha(f"Rampa{k}", (a + b) / 2, z + FAIXA + RAMPA_COMP / 2, b - a, RAMPA_COMP, 180); k += 1
    for (a, b) in menos(ivs, L_molhada.get(z - FAIXA, [])):
        cunha(f"Rampa{k}", (a + b) / 2, z - RAMPA_COMP / 2, b - a, RAMPA_COMP, 0); k += 1

# ---------------------------------------------------------------------------------------------------- ruas e praça
RUA_Y1, CALC_Y1, PRACA_Y1 = 0.05, 0.25, 0.35
x0, x1 = W(-132, 0)[0], W(150, 0)[0]
box("Ruas", "Avenida", x0, x1, TOP - 0.1, RUA_Y1, CZ - 9, CZ + 9, ASFALTO)
for s in (-1, 1):
    box("Ruas", f"CalcadaAvenida{s}", x0, x1, TOP - 0.1, CALC_Y1, CZ + s * 12 - 3, CZ + s * 12 + 3, CALCADA)
for i, x in enumerate(range(-128, 150, 16)):  # faixa central tracejada
    if abs(x) > 30:
        box("Ruas", f"Faixa{i}", CX + x, CX + x + 7, RUA_Y1, RUA_Y1 + 0.02, CZ - 0.4, CZ + 0.4, rgb(236, 210, 120))
for nome, (z0, z1) in (("RuaNorte", (-165, -15)), ("RuaSul", (15, 160))):
    box("Ruas", nome, CX - 8, CX + 8, TOP - 0.1, RUA_Y1, CZ + z0, CZ + z1, ASFALTO)
    for s in (-1, 1):
        box("Ruas", f"Calcada{nome}{s}", CX + s * 11 - 3, CX + s * 11 + 3, TOP - 0.1, CALC_Y1, CZ + z0, CZ + z1, CALCADA)

# praça (octógono de faixas) + fonte; o centro da região é a fonte
for i in range(8):
    a = i * 22.5
    part("Praca", f"Piso{i}", (52, PRACA_Y1 - TOP + 0.1, 21.6), (CX, (TOP - 0.1 + PRACA_Y1) / 2, CZ), PRACA, a)
part("Praca", "FonteBase", (1.6, 18, 18), (CX, PRACA_Y1 + 0.8, CZ), rgb(170, 150, 120), 0, Shape="Cylinder",
     Orientation=[0, 0, 90])
part("Praca", "FonteAgua", (0.4, 15.6, 15.6), (CX, PRACA_Y1 + 1.5, CZ), AGUA, 0, Shape="Cylinder",
     Orientation=[0, 0, 90], Transparency=0.25, CanCollide=False)
part("Praca", "FontePilar", (6, 2.4, 2.4), (CX, PRACA_Y1 + 4, CZ), rgb(190, 170, 136), 0, Shape="Cylinder",
     Orientation=[0, 0, 90])
part("Praca", "FonteTaca", (1, 7, 7), (CX, PRACA_Y1 + 7, CZ), rgb(190, 170, 136), 0, Shape="Cylinder",
     Orientation=[0, 0, 90])
part("Praca", "FonteBrilho", (1.6, 1.6, 1.6), (CX, PRACA_Y1 + 8.2, CZ), AMBAR, 0, material=NEON, Shape="Ball",
     CanCollide=False, children=light(18, 1.4))
for i in range(4):  # bancos virados para a fonte
    a = i * 90 + 45
    bx, bz = rot(0, 17, a)
    org = (CX + bx, PRACA_Y1, CZ + bz)
    local_part("Praca", f"Banco{i}", org, a, (7, 0.5, 2), (0, 1.6, 0), MADEIRA_CLARA)
    local_part("Praca", f"BancoEncosto{i}", org, a, (7, 1.6, 0.4), (0, 2.6, 0.9), MADEIRA_CLARA)
    for s in (-1, 1):
        local_part("Praca", f"BancoPe{i}_{s}", org, a, (0.5, 1.4, 1.6), (s * 2.8, 0.7, 0), ESCURO)

# postes com luz quente ao longo da avenida e das ruas
postes = [(x, s * 14.5) for x in range(-130, 150, 40) for s in (-1, 1)] + [(s * 13.5, z) for z in (-60, -120, 60, 120) for s in (-1, 1)]
for i, (lx, lz) in enumerate(postes):
    x, z = W(lx, lz)
    part("Postes", f"Poste{i}", (0.6, 12, 0.6), (x, CALC_Y1 + 6, z), ESCURO)
    part("Postes", f"Lampiao{i}", (1.4, 1.6, 1.4), (x, CALC_Y1 + 12.6, z), AMBAR, material=NEON, CanCollide=False,
         children=light(20) if i % 2 == 0 else None)


# ---------------------------------------------------------------------------------------------------- casas
def casa(name, lx, lz, w, d, h, yaw, folder="Casas", andares=1, cor=None, telhado=None, oca=False, base_y=TOP):
    """Casa simples: corpo, porta, janelas e telhado de duas águas. Frente = +Z local (yaw gira)."""
    cor = cor or rng.choice(PAREDES)
    telhado = telhado or rng.choice(TELHADOS)
    org = (CX + lx, base_y, CZ + lz)
    if oca:  # paredes com vão de porta (a Casa Vazia, Missão 20)
        t = 0.8
        local_part(folder, f"{name}_Piso", org, yaw, (w, 0.3, d), (0, 0.15, 0), MADEIRA)
        local_part(folder, f"{name}_Fundo", org, yaw, (w, h, t), (0, h / 2, -d / 2 + t / 2), cor)
        for s in (-1, 1):
            local_part(folder, f"{name}_Lado{s}", org, yaw, (t, h, d), (s * (w / 2 - t / 2), h / 2, 0), cor)
            lado = (w - 5) / 2
            local_part(folder, f"{name}_Frente{s}", org, yaw, (lado, h, t), (s * (2.5 + lado / 2), h / 2, d / 2 - t / 2), cor)
        local_part(folder, f"{name}_Verga", org, yaw, (5, h - 8, t), (0, 8 + (h - 8) / 2, d / 2 - t / 2), cor)
        local_part(folder, f"{name}_Forro", org, yaw, (w, 0.6, d), (0, h - 0.3, 0), cor)
    else:
        local_part(folder, f"{name}_Corpo", org, yaw, (w, h, d), (0, h / 2, 0), cor)
        local_part(folder, f"{name}_Porta", org, yaw, (4, 7.5, 0.4), (0, 3.75, d / 2 + 0.2), MADEIRA)
    por_andar = h / andares
    for a in range(andares):
        y = a * por_andar + por_andar * 0.6
        for s in (-1, 1):
            if w >= 14:
                local_part(folder, f"{name}_Janela{a}_{s}", org, yaw, (3, 3, 0.3), (s * (w / 4 + 1), y, d / 2 + 0.15), JANELA)
        if a > 0:
            local_part(folder, f"{name}_JanelaMeio{a}", org, yaw, (3, 3, 0.3), (0, y, d / 2 + 0.15), JANELA)
    rh = min(7.0, d * 0.4)
    # duas águas: cumeeira ao longo de X local; cada metade desce para fora (frente/fundo)
    local_part(folder, f"{name}_TelhadoFrente", org, yaw, (w + 1.6, rh, d / 2 + 0.8), (0, h + rh / 2, d / 4 + 0.4), telhado,
               extra_yaw=180, cls="WedgePart")
    local_part(folder, f"{name}_TelhadoFundo", org, yaw, (w + 1.6, rh, d / 2 + 0.8), (0, h + rh / 2, -d / 4 - 0.4), telhado,
               cls="WedgePart")
    if rng.random() < 0.4 and not oca:
        local_part(folder, f"{name}_Chamine", org, yaw, (2, rh + 3, 2), (w / 4, h + (rh + 3) / 2, -d / 6), rgb(120, 80, 66))


n = 0
# Avenida, lado norte (frente para +Z = yaw 0) e lado sul (frente para -Z = yaw 180)
for lx in (-105, -80, -55, -30, 30, 55, 80, 105, 128):
    w = rng.choice((16, 18, 20)) if lx != 128 else 16
    d = 18
    casa(f"CasaN{n}", lx, -15 - d / 2 - 1, w, d, rng.choice((11, 12, 18)), 0, andares=2 if rng.random() < 0.4 else 1); n += 1
for lx in (-105, -80, 128):
    d = 18
    casa(f"CasaS{n}", lx, 15 + d / 2 + 1, 18, d, rng.choice((11, 12, 18)), 180); n += 1
# Rua norte-sul: oeste (frente +X = yaw 90) e leste (frente -X = yaw -90)
for lz in (-55, -80, -105, -130, 50, 75, 100, 125):
    casa(f"CasaO{n}", -14 - 10, lz, 18, 18, rng.choice((11, 12, 18)), 90); n += 1
for lz in (-55, -80, 50):
    casa(f"CasaL{n}", 14 + 10, lz, 18, 18, rng.choice((11, 12, 18)), -90); n += 1

# Café (sul da avenida, oeste do cruzamento) com mesas na calçada
casa("Cafe", -48, 15 + 11 + 1, 28, 22, 12, 180, cor=rgb(196, 120, 82), telhado=rgb(90, 60, 50))
for i, lx in enumerate((-60, -36)):
    x, z = W(lx, 31)
    part("Casas", f"CafeToldo{i}", (10, 0.4, 5), (x, 9, z - 14.5), rgb(200, 60, 50), CanCollide=False)
for i, lx in enumerate((-58, -40)):
    x, z = W(lx, 17.5)
    part("Casas", f"CafeMesa{i}", (0.4, 3, 3), (x, 0.25 + 1.6, z), MADEIRA_CLARA, Shape="Cylinder", Orientation=[0, 0, 90])

# Feira (sul da avenida, leste do cruzamento): bancas com toldo e caixotes
for i, lx in enumerate((48, 70, 92)):
    x, z = W(lx, 30)
    part("Feira", f"Balcao{i}", (12, 3.4, 4), (x, TOP + 1.7, z), MADEIRA)
    for s in (-1, 1):
        part("Feira", f"Haste{i}_{s}", (0.5, 9, 0.5), (x + s * 5.5, TOP + 4.5, z - 1.5), ESCURO)
    part("Feira", f"Toldo{i}", (13, 0.4, 6), (x, TOP + 9, z - 1), [rgb(214, 96, 50), rgb(70, 130, 110), rgb(230, 170, 60)][i],
         CanCollide=False)
for i in range(6):
    x, z = W(104 + (i % 3) * 4.2, 36 + (i // 3) * 4.2)
    part("Feira", f"Caixote{i}", (4, 4, 4), (x, TOP + 2, z), MADEIRA_CLARA, rng.uniform(-8, 8))

# Posto da Guarda (norte, a leste da rua): onde se conectam as pistas
x, z = W(62, -92)
casa("PostoGuarda", 62, -92, 40, 22, 16, 0, folder="PostoGuarda", andares=2, cor=rgb(214, 206, 190), telhado=rgb(70, 74, 90))
part("PostoGuarda", "Placa", (16, 2.4, 0.4), (x, 13.5, z + 11.4), rgb(40, 60, 100))
part("PostoGuarda", "Mastro", (0.5, 22, 0.5), (x - 24, TOP + 11, z + 14), ESCURO)
part("PostoGuarda", "Bandeira", (5, 3, 0.2), (x - 21.3, TOP + 20, z + 14), AMBAR)

# Escola (sul, leste da rua), frente para a rua (-X)
casa("Escola", 98, 108, 34, 46, 18, -90, folder="Escola", andares=2, cor=rgb(232, 210, 170), telhado=rgb(130, 60, 44))
x, z = W(98 - 23.3, 108)
part("Escola", "Relogio", (0.4, 5, 5), (x, 21, z), rgb(245, 240, 225), Shape="Cylinder", Orientation=[0, 0, 0])
part("Escola", "Ponteiro", (0.3, 2.2, 0.4), (x - 0.3, 21.8, z), ESCURO)

# Parque (sudoeste): árvores de outono, caminho e bancos
for i in range(9):
    lx, lz = -60 - (i % 3) * 26 + rng.uniform(-5, 5), 55 + (i // 3) * 30 + rng.uniform(-5, 5)
    x, z = W(lx, lz)
    hgt = rng.uniform(9, 13)
    part("Parque", f"Tronco{i}", (hgt, 1.6, 1.6), (x, TOP + hgt / 2, z), MADEIRA, Shape="Cylinder", Orientation=[0, 0, 90])
    copa = rng.uniform(8, 11)
    part("Parque", f"Copa{i}", (copa, copa, copa), (x, TOP + hgt + copa * 0.25, z), rng.choice(COPAS), Shape="Ball")
box("Parque", "Caminho", W(-140, 0)[0], W(-40, 0)[0], TOP - 0.1, TOP + 0.1, CZ + 92, CZ + 98, rgb(206, 182, 140))
for i, lx in enumerate((-110, -84)):
    org = (CX + lx, TOP, CZ + 101)
    local_part("Parque", f"Banco{i}", org, 180, (7, 0.5, 2), (0, 1.6, 0), MADEIRA_CLARA)
    local_part("Parque", f"BancoEncosto{i}", org, 180, (7, 1.6, 0.4), (0, 2.6, 0.9), MADEIRA_CLARA)
    for s in (-1, 1):
        local_part("Parque", f"BancoPe{i}_{s}", org, 180, (0.5, 1.4, 1.6), (s * 2.8, 0.7, 0), ESCURO)
# árvores soltas pela cidade
for i, (lx, lz) in enumerate(((-150, -60), (-150, 60), (150, -60), (160, 70), (-60, -140), (60, -150), (140, 140), (-120, -110))):
    x, z = W(lx, lz)
    part("Parque", f"TroncoSolto{i}", (10, 1.4, 1.4), (x, TOP + 5, z), MADEIRA, Shape="Cylinder", Orientation=[0, 0, 90])
    part("Parque", f"CopaSolta{i}", (9, 9, 9), (x, TOP + 12, z), rng.choice(COPAS), Shape="Ball")

# Chegada (oeste): cais de madeira, píer para o mar, placa da cidade
box("Chegada", "Cais", CX - 200, CX - 132, TOP - 0.1, 0.25, CZ - 32, CZ + 32, MADEIRA_CLARA)
for i in range(10):
    box("Chegada", f"Tabua{i}", CX - 200 + i * 6.8, CX - 199.6 + i * 6.8, 0.25, 0.3, CZ - 32, CZ + 32, MADEIRA)
box("Chegada", "Pier", CX - 262, CX - 200, -0.2, 0.25, CZ - 5, CZ + 5, MADEIRA_CLARA)
for i, px in enumerate(range(-258, -200, 10)):
    for s in (-1, 1):
        part("Chegada", f"Estaca{i}_{s}", (1, 9, 1), (CX + px, -4.5, CZ + s * 5.5), MADEIRA)
x, z = W(-132, -22)
part("Chegada", "PlacaPoste1", (0.8, 9, 0.8), (x, 4.5, z - 5), ESCURO)
part("Chegada", "PlacaPoste2", (0.8, 9, 0.8), (x, 4.5, z + 5), ESCURO)
part("Chegada", "PlacaCidade", (0.5, 3, 11), (x, 8, z), rgb(110, 60, 36))
part("Chegada", "PlacaCidadeBrilho", (0.2, 0.6, 10), (x - 0.3, 8, z), AMBAR, material=NEON, CanCollide=False)
# marco do checkpoint: pilar com lanterna; a plaqueta (marcador) recebe o prompt
x, z = W(-150, -14)
part("Chegada", "MarcoPilar", (2, 5, 2), (x, 0.25 + 2.5, z), rgb(170, 150, 120))
part("Chegada", "MarcoLanterna", (1.4, 1.4, 1.4), (x, 0.25 + 5.7, z), AMBAR, material=NEON, CanCollide=False, children=light(14))

# portais (mesmo formato dos outros: moldura escura + núcleo neon), virados para dentro da cidade
for nome, lz, cor in (("AmbarToSolPartido", 22, AMBAR), ("AmbarToCosta", -22, rgb(250, 210, 90))):
    x, z = W(-190, lz)
    part("Portais", nome, (10, 16, 2), (x, 8, z), ESCURO, 90)
    part("Portais", nome + "Core", (7, 12, 1), (x + 0.3, 8, z), cor, 90, material=NEON, Transparency=0.25, CanCollide=False)
# portal de ida, na Rota do Eclipse ao lado do SolPartidoToPilares (1695, 8, -122)
part("PortalRota", "SolPartidoToAmbar", (10, 16, 2), (1695, 8, -152), ESCURO)
part("PortalRota", "SolPartidoToAmbarCore", (7, 12, 1), (1695, 8, -152), AMBAR, material=NEON, Transparency=0.25, CanCollide=False)

# Pátio do chefe (leste, fim da avenida): galpão abandonado e caixotes
box("Patio", "PisoPatio", CX + 150, CX + 200, TOP - 0.1, RUA_Y1, CZ - 34, CZ + 34, rgb(96, 90, 84))
for i, (lx, lz, w, d) in enumerate(((176, -38, 46, 3), (176, 38, 46, 3), (201.5, 0, 3, 36))):
    x, z = W(lx, lz)
    part("Patio", f"Muro{i}", (w, 4, d), (x, TOP + 2, z), rgb(150, 120, 96))
for i in range(5):
    x, z = W(rng.uniform(160, 198), rng.choice((-26, 26)) + rng.uniform(-4, 4))
    part("Patio", f"Caixa{i}", (4, 4, 4), (x, RUA_Y1 + 2, z), MADEIRA, rng.uniform(0, 45))
for i, lz in enumerate((-30, 30)):
    x, z = W(200, lz)
    part("Patio", f"PostePatio{i}", (0.6, 14, 0.6), (x, 7, z), ESCURO)
    part("Patio", f"LuzPatio{i}", (1.6, 1.2, 1.6), (x, 14.4, z), rgb(255, 120, 60), material=NEON, CanCollide=False,
         children=light(26, 1.3, (1, 0.5, 0.3)))

# ---------------------------------------------------------------------------------------------------- pistas (visuais)
x, z = W(-70, -15)
part("Pistas", "CartazPoste", (0.4, 6, 0.4), (x, 0.25 + 3, z), ESCURO)
x, z = W(-90, 101)
part("Pistas", "Mochila", (1.6, 1.4, 1), (x - 1.5, 2.5, z), rgb(70, 90, 130))
x, z = W(122, -62)
part("Pistas", "Mesinha", (3, 2.6, 3), (x, TOP + 1.3, z), MADEIRA)
for i, (lx, lz) in enumerate(((-70, -48), (-66, -45), (128, 106), (131, 110))):
    x, z = W(lx, lz)
    part("Pistas", f"Mancha{i}", (rng.uniform(2, 3.5), 0.05, rng.uniform(2, 3.5)), (x, TOP + 0.03, z), rgb(60, 40, 70),
         rng.uniform(0, 90), CanCollide=False, Transparency=0.2)
x, z = W(45, -78)
part("Pistas", "QuadroPistasPes", (0.4, 3, 0.4), (x, TOP + 1.5, z), ESCURO)

# ---------------------------------------------------------------------------------------------------- marcadores do contrato
def chao(lx, lz, y):
    x, z = W(lx, lz)
    return (x, y + 0.1, z)


marker("AmbarCentro", (CX, PRACA_Y1 + 1, CZ), size=(2, 2, 2))
marker("AmbarSpawn", chao(-160, 0, 0.25), size=(10, 0.2, 10), yaw=-90)
x, z = W(-149, -14)
marker("AmbarCheckpoint", (x, 0.25 + 3.4, z), size=(0.3, 1.6, 1.4), visible=True, color=rgb(60, 50, 44), collide=True)
marker("AmbarHumanoider", chao(-146, 16, 0.25), yaw=-90)
marker("AmbarMorador1", chao(19, -16, PRACA_Y1), yaw=-140)
marker("AmbarMorador2", chao(70, 25, TOP), yaw=0)
x, z = W(108.2, 44.2)
marker("AmbarTarefa", (x, TOP + 2, z), size=(4, 4, 4), visible=True, color=rgb(196, 150, 90), collide=True)
x, z = W(-70, -15)
marker("AmbarDesaparecimento1", (x, 0.25 + 5.2, z + 0.3), size=(3, 2.4, 0.2), visible=True, color=rgb(236, 228, 200))
x, z = W(-90, 101)
marker("AmbarDesaparecimento2", (x + 1, 2.4, z), size=(1.2, 1.2, 0.3), visible=True, color=rgb(236, 228, 200))
x, z = W(122, -62)
marker("AmbarFotografia", (x, TOP + 2.75, z), size=(1.4, 0.15, 1), visible=True, color=rgb(220, 200, 160))
marker("AmbarCena1", chao(-68, -46, TOP), size=(3, 0.2, 3))
marker("AmbarCena2", chao(129, 108, TOP), size=(3, 0.2, 3))
marker("AmbarTestemunha", chao(-48, 12, 0.25), yaw=180)
x, z = W(45, -78)
marker("AmbarPadrao", (x, TOP + 3.6, z), size=(4, 2.6, 0.3), visible=True, color=rgb(120, 86, 60))
x, z = W(78, -78)
marker("AmbarContrapista", (x, TOP + 1.2, z), size=(2.4, 2.4, 1.6), visible=True, color=rgb(86, 96, 120), collide=True)
casa("CasaVazia", 135, -102, 18, 18, 11, 0, folder="CasaVazia", oca=True, cor=rgb(176, 160, 140), telhado=rgb(80, 66, 60))
x, z = W(135, -106)
marker("AmbarCasa", (x, TOP + 4.5, z), size=(0.3, 5, 2), visible=True, color=rgb(170, 90, 255), material=NEON)
marker("AmbarBossSpawn", chao(185, 0, RUA_Y1), size=(9, 0.2, 9), yaw=90)

# moradores passeando (VillagerService agrupa os pontos por Model)
for i, (lx, lz) in enumerate(((-120, 12), (-80, -12), (-40, 12), (-14, -40), (-14, 50), (14, 100), (40, -12), (80, 12),
                              (110, -12), (14, -120), (-14, 130), (60, 20))):
    x, z = W(lx, lz)
    part("Waypoints", "VilaWaypoint", (2, 1, 2), (x, 1, z), AMBAR, CanCollide=False, CanQuery=False, Transparency=1)

# ---------------------------------------------------------------------------------------------------- validação e saída
nomes = {}
for lista in folders.values():
    for n_ in lista:
        nomes[n_["name"]] = nomes.get(n_["name"], 0) + 1
for nome in [n_["name"] for n_ in folders["Marcadores"]]:
    assert nomes[nome] == 1, f"nome repetido: {nome}"
    p = next(n_ for n_ in folders["Marcadores"] if n_["name"] == nome)["properties"]["Position"]
    dx, dz = (p[0] - CX) / RX, (p[2] - CZ) / RZ
    assert dx * dx + dz * dz <= 0.85, f"{nome} fora da área segura da elipse ({dx * dx + dz * dz:.2f})"

children = [{"name": n_, "className": "Folder", "children": v} for n_, v in folders.items()]
OUT.write_text(json.dumps({"className": "Model", "ignoreUnknownInstances": True,
                           "attributes": {"FXRadiusX": RX, "FXRadiusZ": RZ, "VillagerCount": 9},
                           "children": children}, indent=1) + "\n")
print(f"{OUT}: {sum(map(len, folders.values()))} instâncias-base")
for n_, v in folders.items():
    print(f"  {n_}: {len(v)}")
