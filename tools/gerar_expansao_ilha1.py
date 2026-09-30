#!/usr/bin/env python3
"""Expansão da Ilha 1 — Porto da Névoa (dono, 30/09: "vila muito pequena, nem parece de verdade"; "NPCs mais separados,
aumentar o lugar, bem feito, nada pela metade"). Gera DOIS modelos novos (não toca no chão/ilha existentes):

  src/workspace/FXVilaNova.model.json   → Workspace.Sahur.FXVilaNova   (bairro a sudoeste do anel da vila)
  src/workspace/FXCamposNevoa.model.json → Workspace.Sahur.FXCamposNevoa (ilhota de farm a oeste, com ponte)

Estilo = o do chão das ilhas: peças lisas (SmoothPlastic, só cor) e formas simples bem acabadas.
Inimigos: BaseParts `MobPad` com atributos (MobKind/MobName/MobTier/...), lidos pelo MobPadService.
Moradores andando: `VilaWaypoint` (invisíveis), lidos pelo VillagerService.

⚠ Depois que o dono editar esses modelos à mão no Studio e a edição for CAPTURADA (tools/capturar_mapa.sh),
NÃO rodar este gerador de novo (sobrescreve o que ele fez) — ver SINCRONIZACAO_MANUAL.md.
"""
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LISO = "SmoothPlastic"


def rgb(r, g, b):
    return [r, g, b]


# ---------------------------------------------------------------------------
# Geometria: CFrame como posição + matriz 3x3 (linhas) → formato implícito do Rojo (12 números)
def rot_y(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_x(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_z(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def apply(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


IDENT = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


def cf(pos, m=IDENT):
    return [round(pos[0], 3), round(pos[1], 3), round(pos[2], 3)] + [round(m[i][j], 6) for i in range(3) for j in range(3)]


def node(name, cls, props=None, children=None, attrs=None):
    n = {"name": name, "className": cls, "properties": props or {}}
    if children:
        n["children"] = children
    if attrs:
        n["attributes"] = attrs
    return n


def part(name, size, pos, color, m=IDENT, material=LISO, cls="Part", extra=None, children=None, attrs=None):
    props = {"Anchored": True, "Size": [round(s, 3) for s in size], "CFrame": cf(pos, m), "Color3uint8": None,
             "Material": material, "TopSurface": "Smooth", "BottomSurface": "Smooth"}
    del props["Color3uint8"]
    props["Color"] = [round(c / 255, 4) for c in color]
    if extra:
        props.update(extra)
    return node(name, cls, props, children, attrs)


class Local:
    """Construtor com origem/rotação (casa girada): peças em coordenadas locais."""

    def __init__(self, origin, yaw, out):
        self.o, self.m, self.out = origin, rot_y(yaw), out

    def put(self, name, size, lpos, color, lm=IDENT, **kw):
        wp = apply(self.m, lpos)
        pos = [self.o[0] + wp[0], self.o[1] + wp[1], self.o[2] + wp[2]]
        self.out.append(part(name, size, pos, color, mul(self.m, lm), **kw))


# ---------------------------------------------------------------------------
# Paleta (casas da vila existente: bege liso e tijolo avermelhado)
PAREDES = [rgb(226, 214, 190), rgb(214, 196, 168), rgb(236, 228, 210), rgb(200, 178, 150), rgb(188, 206, 214)]
TELHADOS = [rgb(126, 62, 48), rgb(98, 70, 58), rgb(70, 82, 98), rgb(140, 84, 52)]
MADEIRA = rgb(104, 74, 52)
MADEIRA_ESC = rgb(72, 52, 38)
VIDRO = rgb(54, 70, 86)
PEDRA = rgb(148, 142, 134)
PEDRA_ESC = rgb(112, 106, 100)
RUA = rgb(158, 150, 138)
FLOR = [rgb(210, 70, 80), rgb(240, 200, 70), rgb(160, 90, 200), rgb(240, 240, 240)]
FOLHA = rgb(88, 138, 70)
TOP = -0.15  # topo do chão das ilhas


def casa(out, nome, cx, cz, w, d, andares, yaw, rng):
    """Casa fechada (não entra) com fundação, cantos de madeira, porta, janelas, jardineiras, telhado de duas águas
    com beiral, oitões e chaminé. Frente = -Z local."""
    L = Local([cx, TOP, cz], yaw, out)
    parede, telhado = rng.choice(PAREDES), rng.choice(TELHADOS)
    h = 10 * andares
    base = 0.9
    L.put(f"{nome}_Fundacao", [w + 1.2, base + 0.2, d + 1.2], [0, base / 2 - 0.1, 0], PEDRA_ESC)
    L.put(f"{nome}_Corpo", [w, h, d], [0, base + h / 2, 0], parede)
    for sx in (-1, 1):
        for sz in (-1, 1):
            L.put(f"{nome}_Canto", [0.9, h, 0.9], [sx * (w / 2 - 0.35), base + h / 2, sz * (d / 2 - 0.35)], MADEIRA)
    if andares > 1:
        L.put(f"{nome}_Faixa", [w + 0.3, 0.7, d + 0.3], [0, base + 10, 0], MADEIRA)
    # porta + moldura + degrau
    L.put(f"{nome}_Porta", [3.4, 6.6, 0.3], [0, base + 3.3, -d / 2 - 0.12], MADEIRA_ESC)
    L.put(f"{nome}_Moldura", [4.4, 7.4, 0.2], [0, base + 3.7, -d / 2 - 0.02], MADEIRA)
    L.put(f"{nome}_Degrau", [5, 0.5, 1.6], [0, base - 0.1, -d / 2 - 0.8], PEDRA)
    # janelas (frente dos dois lados da porta; laterais) em cada andar
    for a in range(andares):
        y = base + 5.2 + a * 10
        xs = [x for x in (-w / 2 + 3.2, w / 2 - 3.2) if abs(x) > 3.6]
        if a > 0:
            xs.append(0)
        for x in xs:
            L.put(f"{nome}_Janela", [2.4, 2.8, 0.25], [x, y, -d / 2 - 0.16], VIDRO)
            L.put(f"{nome}_JanelaMoldura", [3.0, 3.4, 0.15], [x, y, -d / 2 - 0.06], MADEIRA)
            if a == 0 and rng.random() < 0.7:
                L.put(f"{nome}_Jardineira", [3.0, 0.7, 0.8], [x, y - 2.1, -d / 2 - 0.45], MADEIRA)
                L.put(f"{nome}_Flores", [2.7, 0.6, 0.6], [x, y - 1.55, -d / 2 - 0.45], rng.choice(FLOR))
        for sx in (-1, 1):
            L.put(f"{nome}_JanelaLado", [0.25, 2.8, 2.4], [sx * (w / 2 + 0.16), y, 0], VIDRO)
            L.put(f"{nome}_JanelaLadoMoldura", [0.15, 3.4, 3.0], [sx * (w / 2 + 0.06), y, 0], MADEIRA)
    # telhado de duas águas (cumeeira ao longo de X), 35°, beiral de 1.2
    topo = base + h
    th = math.radians(35)
    hd = d / 2 + 1.2
    rise = hd * math.tan(th)
    comp = hd / math.cos(th)
    for sz in (-1, 1):
        # água: desce da cumeeira (z=0) para a borda (z=±hd)
        L.put(f"{nome}_Telhado", [w + 2.4, 0.7, comp], [0, topo + rise / 2 + 0.25, sz * hd / 2], telhado, rot_x(sz * 35))
    L.put(f"{nome}_Cumeeira", [w + 2.6, 0.8, 0.9], [0, topo + rise + 0.45, 0], MADEIRA_ESC)
    # oitões (triângulos na cor da parede) — WedgePart: sobe para +Z local
    r0 = (d / 2) * math.tan(th)
    for sx in (-1, 1):
        for sz in (-1, 1):
            m = rot_y(0 if sz < 0 else 180)
            L.put(f"{nome}_Oitao", [0.6, r0, d / 2], [sx * (w / 2 - 0.3), topo + r0 / 2, sz * d / 4], parede, m, cls="WedgePart")
    if rng.random() < 0.6:
        L.put(f"{nome}_Chamine", [1.8, rise + 3, 1.8], [w / 4, topo + (rise + 3) / 2 + 0.5, d / 5], rgb(150, 80, 64), material="Brick")


def poste(out, x, z, nome="Poste"):
    out.append(part(f"{nome}_Haste", [0.5, 9, 0.5], [x, TOP + 4.5, z], rgb(52, 54, 60), material="Metal"))
    out.append(part(f"{nome}_Braco", [2.2, 0.3, 0.3], [x + 0.9, TOP + 8.8, z], rgb(52, 54, 60), material="Metal"))
    luz = node("Luz", "PointLight", {"Range": 18, "Brightness": 0.9, "Color": [1, 0.82, 0.55], "Shadows": False})
    out.append(part(f"{nome}_Lanterna", [1.1, 1.3, 1.1], [x + 1.8, TOP + 8.1, z], rgb(255, 214, 140), material="Neon",
                    extra={"Transparency": 0.15}, children=[luz]))


def arvore(out, x, z, rng, escala=1.0, nome="Arvore"):
    """Árvore low-poly: tronco + 2–3 blocos de copa girados (mesmo estilo liso das ilhas)."""
    h = rng.uniform(7, 10) * escala
    out.append(part(f"{nome}_Tronco", [1.4 * escala, h, 1.4 * escala], [x, TOP + h / 2, z], rgb(100, 72, 50)))
    for i in range(rng.randint(2, 3)):
        s = rng.uniform(6, 9) * escala * (1 - i * 0.18)
        y = TOP + h + s * 0.25 + i * s * 0.45
        m = mul(rot_y(rng.uniform(0, 90)), rot_x(rng.uniform(-8, 8)))
        verde = rgb(int(72 + rng.uniform(-8, 20)), int(128 + rng.uniform(-10, 25)), int(60 + rng.uniform(-8, 12)))
        out.append(part(f"{nome}_Copa", [s, s * 0.8, s], [x + rng.uniform(-1, 1), y, z + rng.uniform(-1, 1)], verde, m))


def pedra(out, x, z, rng, nome="Rocha"):
    s = rng.uniform(2.5, 6)
    m = mul(rot_y(rng.uniform(0, 90)), rot_x(rng.uniform(-15, 15)))
    out.append(part(nome, [s * 1.3, s * 0.8, s], [x, TOP + s * 0.25, z], rgb(132, 128, 122), m))


def waypoint(out, x, z, nome="VilaWaypoint"):
    out.append(part(nome, [2, 1, 2], [x, TOP + 0.5, z], rgb(255, 255, 255),
                    extra={"Transparency": 1, "CanCollide": False, "CanQuery": False, "CanTouch": False}))


def rua(out, x0, x1, z0, z1, nome="Rua"):
    out.append(part(nome, [x1 - x0, 0.3, z1 - z0], [(x0 + x1) / 2, TOP + 0.06, (z0 + z1) / 2], RUA))


# ===========================================================================
# VILA NOVA (a sudoeste do anel; o bosquinho da arte em x -88..-33, z 95..145 fica como área verde)
def vila_nova():
    """Bairro novo na faixa livre ao NORTE dos bonecos de treino (DummyPads em -96,29 / -64,29 / -80,2) e ao sul do
    bosquinho da arte (x -88..-33, z 95..145). Fenda instável (-115,-20) e saída (-138,3) ficam livres."""
    rng = random.Random(3001)
    out = []
    SX0, SX1, SZ0, SZ1 = -90, -63.5, 50, 70  # praça do mercado
    SXC, SZC = (SX0 + SX1) / 2, (SZ0 + SZ1) / 2
    out.append(part("PracaMercado", [SX1 - SX0, 0.3, SZ1 - SZ0], [SXC, TOP + 0.07, SZC], rgb(172, 162, 146)))
    for (x, z) in [(SX0 + 2, SZ0 + 2), (SX1 - 2, SZ0 + 2), (SX0 + 2, SZ1 - 2), (SX1 - 2, SZ1 - 2)]:
        out.append(part("PracaCanto", [4, 0.32, 4], [x, TOP + 0.08, z], PEDRA_ESC))
    rua(out, -90, -22, 71, 79, "RuaDoMercado")  # liga a praça ao anel da vila (entre a Casa4 e a Casa5)
    rua(out, -80, -72, 36, 50, "CaminhoDosBonecos")  # desce até o treino de bonecos
    # poço no centro da praça
    out.append(part("Poco_Base", [3, 7, 7], [SXC, TOP + 1.5, SZC], PEDRA, rot_z(90), extra={"Shape": "Cylinder"}))
    out.append(part("Poco_Agua", [0.3, 5.6, 5.6], [SXC, TOP + 2.9, SZC], rgb(60, 110, 140), rot_z(90), extra={"Shape": "Cylinder"}))
    for sx in (-1, 1):
        out.append(part("Poco_Coluna", [0.6, 6, 0.6], [SXC + sx * 3, TOP + 5, SZC], MADEIRA))
    out.append(part("Poco_Telhado", [8, 0.6, 5], [SXC, TOP + 8.3, SZC], rgb(126, 62, 48)))
    # barracas do mercado (cantos da praça, viradas para o poço)
    toldos = [rgb(180, 60, 60), rgb(60, 120, 170), rgb(210, 170, 60), rgb(90, 150, 90)]
    for i, (x, z, yaw) in enumerate([(-84, 66, 0), (-68, 66, 0), (-84, 54, 180), (-68, 54, 180)]):
        L = Local([x, TOP, z], yaw, out)
        L.put("Barraca_Balcao", [6, 3, 2.2], [0, 1.5, 0], MADEIRA)
        L.put("Barraca_Tampo", [6.4, 0.3, 2.6], [0, 3.1, 0], MADEIRA_ESC)
        for sx in (-1, 1):
            L.put("Barraca_Poste", [0.4, 7, 0.4], [sx * 2.9, 3.5, 1.5], MADEIRA_ESC)
        L.put("Barraca_Toldo", [7, 0.3, 4.2], [0, 7.1, 0.4], toldos[i], rot_x(-12), material="Fabric")
        for k in range(3):
            L.put("Barraca_Mercadoria", [1.1, 1, 1.1], [-1.9 + k * 1.9, 3.8, 0], rng.choice(FLOR + [rgb(200, 150, 90)]))
    # casas (cx, cz, largura, fundo, andares, yaw — frente para a rua/praça)
    casas = [
        (-100, 50, 16, 12, 2, -90),   # oeste da praça
        (-100, 67, 14, 12, 1, -90),
        (-117, 50, 12, 10, 1, -90),
        (-55, 50, 16, 12, 1, 90),     # leste da praça
        (-38, 52, 14, 12, 2, 180),
        (-58, 87, 14, 10, 2, 0),      # norte da rua do mercado
        (-95, 86, 14, 10, 1, 0),
        (-40, 36, 14, 10, 1, 0),      # leste dos bonecos
        (-40, 4, 14, 10, 2, 180),
        (-50, -12, 16, 12, 1, 90),
    ]
    for i, (x, z, w, d, a, yaw) in enumerate(casas):
        casa(out, f"Casa{i + 1:02d}", x, z, w, d, a, yaw, rng)
    # postes ao longo da rua e na praça
    for (x, z) in [(-92, 72), (-60, 81), (-45, 69.5), (-30, 81), (-60, 48), (-92, 48), (-82, 40), (-33, 20)]:
        poste(out, x, z)
    # bancos, barris e caixotes
    for (x, z, yaw) in [(-76, 51.2, 180), (-76, 68.8, 0)]:
        L = Local([x, TOP, z], yaw, out)
        L.put("Banco_Assento", [4.5, 0.4, 1.4], [0, 1.4, 0], MADEIRA)
        L.put("Banco_Encosto", [4.5, 1.4, 0.3], [0, 2.2, 0.6], MADEIRA)
        for sx in (-1, 1):
            L.put("Banco_Pe", [0.4, 1.2, 1.2], [sx * 1.8, 0.6, 0], MADEIRA_ESC)
    for (x, z) in [(-91.5, 60), (-91.5, 62.4), (-47, 69.5), (-110, 60), (-64, 44), (-30, 44)]:
        out.append(part("Barril", [2.6, 1.9, 1.9], [x, TOP + 1.3, z], rgb(120, 82, 52), rot_z(90), extra={"Shape": "Cylinder"}))
    for (x, z) in [(-63.5, 60.5), (-63.5, 63), (-110, 44), (-48, 26)]:
        s = rng.uniform(1.6, 2.4)
        out.append(part("Caixote", [s, s, s], [x, TOP + s / 2, z], rgb(150, 110, 70), rot_y(rng.uniform(0, 40))))
    for (x, z) in [(-120, 66), (-26, 58), (-28, -22)]:
        arvore(out, x, z, rng, 0.8, "ArvoreVila")
    # rota dos moradores (VillagerService): praça, rua até o anel e o caminho dos bonecos
    for (x, z) in [(-80, 58), (-72, 64), (-76, 75), (-60, 75), (-40, 75), (-25, 75), (-76, 42), (-95, 75), (-50, 60), (-33, 30)]:
        waypoint(out, x, z)
    return out


# ===========================================================================
# CAMPOS DA NÉVOA — ilhota de farm (mesmo método de camadas do gerar_chao_ilhas.py) + ponte
CX, CZ, RX, RZ = -470, -60, 190, 230
FAIXA = 20
D_TOPO, D_PRAIA, D_MOLHADA = 0.90, 1.0, 1.06
TOP_PRAIA, TOP_MOLHADA = -0.9, -1.7
RAMPA_FUNDO, RAMPA_COMP = -6.5, 14.0
FUNDO = -13.0
JITTER = 0.03
GRAMA_CAMPO = rgb(112, 158, 82)
AREIA = rgb(226, 204, 146)
MOLHADA = [round(c * 0.86) for c in AREIA]
TERRA = rgb(110, 92, 66)


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
                nova.append((a, b))
                continue
            if a < c0:
                nova.append((a, c0))
            if c1 < b:
                nova.append((c1, b))
        res = nova
    return [(a, b) for a, b in res if b - a > 0.05]


def linhas(escala, seed=7):
    rows = {}
    rze = RZ * escala
    zi = math.floor((CZ - rze) / FAIXA) * FAIXA
    while zi < CZ + rze:
        tz = (zi + FAIXA / 2 - CZ) / rze
        if abs(tz) < 1:
            r = random.Random(seed * 100003 + int(zi))
            meia = RX * escala * math.sqrt(1 - tz * tz)
            rows[zi] = juntar([(CX - meia * (1 + JITTER * r.uniform(-1, 1)), CX + meia * (1 + JITTER * r.uniform(-1, 1)))])
        zi += FAIXA
    return rows


def caixa(nome, x0, x1, y0, y1, z0, z1, cor):
    return part(nome, [x1 - x0, y1 - y0, z1 - z0], [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], cor)


def cunha(nome, cx, cz, largura, comp, y0, y1, yaw, cor):
    return part(nome, [largura, y1 - y0, comp], [cx, (y0 + y1) / 2, cz], cor, rot_y(yaw), cls="WedgePart")


def dentro_topo(x, z, margem=0.0):
    t = ((x - CX) / (RX * D_TOPO)) ** 2 + ((z - CZ) / (RZ * D_TOPO)) ** 2
    return t <= (1 - margem) ** 2


def campos():
    rng = random.Random(3002)
    chao, deco, pads = [], [], []
    Lt, Lp, Lm = linhas(D_TOPO), linhas(D_PRAIA), linhas(D_MOLHADA)
    k = 0
    for z, ivs in sorted(Lt.items()):
        for (a, b) in ivs:
            chao.append(caixa(f"Topo{k}", a, b, TOP - 1.2, TOP, z, z + FAIXA, GRAMA_CAMPO))
            chao.append(caixa(f"Corpo{k}", a, b, FUNDO, TOP - 1.2, z, z + FAIXA, TERRA))
            k += 1

    def anel(fora, dentro):
        return [(a, b, z, z + FAIXA) for z, ivs in sorted(fora.items()) for (a, b) in menos(ivs, dentro.get(z, []))]

    for i, (a, b, z0, z1) in enumerate(anel(Lp, Lt)):
        chao.append(caixa(f"Praia{i}", a, b, FUNDO, TOP_PRAIA, z0, z1, AREIA))
    for i, (a, b, z0, z1) in enumerate(anel(Lm, Lp)):
        chao.append(caixa(f"Molhada{i}", a, b, FUNDO, TOP_MOLHADA, z0, z1, MOLHADA))
    # rampas + pés (sem vão embaixo: tudo desce até FUNDO)
    k = 0

    def rampa(cx, cz, larg, yaw):
        nonlocal k
        chao.append(cunha(f"Rampa{k}", cx, cz, larg, RAMPA_COMP, RAMPA_FUNDO, TOP_MOLHADA, yaw, MOLHADA))
        chao.append(part(f"PeRampa{k}", [larg, RAMPA_FUNDO - FUNDO, RAMPA_COMP], [cx, (RAMPA_FUNDO + FUNDO) / 2, cz], MOLHADA, rot_y(yaw)))
        k += 1

    for z, ivs in sorted(Lm.items()):
        for (a, b) in ivs:
            rampa(a - RAMPA_COMP / 2, z + FAIXA / 2, FAIXA, 90)
            rampa(b + RAMPA_COMP / 2, z + FAIXA / 2, FAIXA, -90)
        for (a, b) in menos(ivs, Lm.get(z + FAIXA, [])):
            rampa((a + b) / 2, z + FAIXA + RAMPA_COMP / 2, b - a, 180)
        for (a, b) in menos(ivs, Lm.get(z - FAIXA, [])):
            rampa((a + b) / 2, z - RAMPA_COMP / 2, b - a, 0)

    # ponte do Porto da Névoa (topo em x≈-147) até o topo dos Campos (x≈-299), em z -60
    px0, px1, pz = -305, -142, -60
    deco.append(part("Ponte_Deck", [px1 - px0, 0.8, 10], [(px0 + px1) / 2, 0.0, pz], MADEIRA))
    for x in range(px0 + 4, px1, 3):
        deco.append(part("Ponte_Tabua", [0.35, 0.12, 9.6], [x, 0.46, pz], MADEIRA_ESC))
    for x in range(px0, px1 + 1, 12):
        for sz in (-1, 1):
            deco.append(part("Ponte_Poste", [0.7, 4.2, 0.7], [x, 1.7, pz + sz * 4.6], MADEIRA_ESC))
            deco.append(part("Ponte_Pilar", [1.2, 13.2, 1.2], [x, -6.8, pz + sz * 4.2], MADEIRA_ESC))
    for sz in (-1, 1):
        deco.append(part("Ponte_Corrimao", [px1 - px0, 0.5, 0.5], [(px0 + px1) / 2, 3.6, pz + sz * 4.6], MADEIRA))
    # placa na cabeceira dos Campos
    placa_gui = node("SurfaceGui", "SurfaceGui", {"Face": "Front", "SizingMode": "PixelsPerStud", "PixelsPerStud": 40},
                     [node("Texto", "TextLabel", {"Size": {"UDim2": [[1, 0], [1, 0]]}, "BackgroundTransparency": 1,
                                                  "Text": "CAMPOS DA NÉVOA\nfarm · Capataz a oeste", "TextScaled": True,
                                                  "Font": "GothamBold", "TextColor3": [0.95, 0.92, 0.85]})])
    deco.append(part("Placa_Poste", [0.6, 7, 0.6], [-296, TOP + 3.5, -69], MADEIRA_ESC))
    deco.append(part("Placa", [7, 3, 0.4], [-296, TOP + 6, -69], MADEIRA, rot_y(-90), children=[placa_gui]))

    # zonas de inimigos (bem separadas): Clareira (leste, perto da ponte), Bosque (centro), Acampamento (oeste)
    def pad(nome, x, z, kind, mob_name, tier, **extra):
        attrs = {"MobKind": kind, "MobName": mob_name, "MobTier": tier}
        attrs.update(extra)
        pads.append(part(nome, [4, 0.3, 4], [x, TOP + 0.2, z], rgb(120, 110, 90),
                         extra={"Transparency": 1, "CanCollide": False, "CanQuery": False, "CanTouch": False}, attrs=attrs))

    clareira = [(-340, -20), (-352, -95), (-385, -40), (-330, -130)]
    bosque = [(-450, -150), (-490, -110), (-440, -60), (-505, -175), (-470, -20)]
    acamp = [(-560, 20), (-520, 55), (-585, 70)]
    for i, (x, z) in enumerate(clareira):
        pad(f"MobPad_Clareira{i}", x, z, "fx_campos_enemy", "Vagante da Névoa", 1)
    for i, (x, z) in enumerate(bosque):
        pad(f"MobPad_Bosque{i}", x, z, "fx_campos_enemy", "Vagante da Névoa", 1)
    for i, (x, z) in enumerate(acamp):
        pad(f"MobPad_Acampamento{i}", x, z, "fx_campos_forte", "Bandido da Névoa", 2)
    pad("MobPad_Capataz", -560, 95, "fx_capataz", "Capataz da Névoa", 2, MobBoss=True, MobHealth=650, MobDamage=0.85,
        MobBehavior="reactive", MobTerritory=24)

    ocupados = clareira + bosque + acamp + [(-560, 95)]

    def livre(x, z, raio):
        return dentro_topo(x, z, 0.06) and all((x - a) ** 2 + (z - b) ** 2 > raio ** 2 for (a, b) in ocupados) \
            and not (abs(z - pz) < 9 and x > -330)

    # acampamento dos bandidos: tendas, fogueira, cerca
    for (x, z, yaw, cor) in [(-575, 40, 30, rgb(150, 120, 90)), (-540, 80, -20, rgb(120, 100, 80)), (-600, 95, 70, rgb(140, 110, 80))]:
        L = Local([x, TOP, z], yaw, deco)
        L.put("Tenda", [7, 0.3, 5.2], [0, 2.6, -1.6], cor, rot_x(-45), material="Fabric")
        L.put("Tenda", [7, 0.3, 5.2], [0, 2.6, 1.6], cor, rot_x(45), material="Fabric")
        L.put("Tenda_Mastro", [7.4, 0.3, 0.3], [0, 4.4, 0], MADEIRA_ESC)
    deco.append(part("Fogueira_Pedras", [0.8, 5, 5], [-560, TOP + 0.4, 55], PEDRA_ESC, rot_z(90), extra={"Shape": "Cylinder"}))
    fogo = node("Luz", "PointLight", {"Range": 22, "Brightness": 1.4, "Color": [1, 0.6, 0.25]})
    deco.append(part("Fogueira_Fogo", [1.6, 2.2, 1.6], [-560, TOP + 1.6, 55], rgb(255, 140, 50), material="Neon",
                     extra={"Transparency": 0.2, "CanCollide": False}, children=[fogo]))
    for i in range(14):
        a = math.radians(200 + i * 11)
        x, z = -560 + math.cos(a) * 58, 60 + math.sin(a) * 50
        if dentro_topo(x, z, 0.04):
            deco.append(part("Cerca_Estaca", [0.6, 3.4, 0.6], [x, TOP + 1.7, z], MADEIRA_ESC, rot_y(rng.uniform(-8, 8))))
    # árvores (mais densas no Bosque) e pedras espalhadas
    n = 0
    for _ in range(900):
        if n >= 70:
            break
        x, z = rng.uniform(CX - RX, CX + RX), rng.uniform(CZ - RZ, CZ + RZ)
        no_bosque = (x - -470) ** 2 + (z - -100) ** 2 < 95 ** 2
        if rng.random() > (0.85 if no_bosque else 0.25):
            continue
        if livre(x, z, 12):
            arvore(deco, x, z, rng, rng.uniform(0.9, 1.4), "ArvoreCampo")
            ocupados.append((x, z))
            n += 1
    for _ in range(300):
        x, z = rng.uniform(CX - RX, CX + RX), rng.uniform(CZ - RZ, CZ + RZ)
        if livre(x, z, 8) and rng.random() < 0.3:
            pedra(deco, x, z, rng, "RochaCampo")
            ocupados.append((x, z))
    # trilha de terra batida da ponte até o acampamento
    for i in range(18):
        t = i / 17
        x, z = -300 + (-560 + 300) * t, -60 + (40 + 60) * t + math.sin(t * 5) * 18
        deco.append(part("Trilha", [9, 0.25, 9], [x, TOP + 0.05, z], rgb(150, 128, 92), rot_y(rng.uniform(0, 45))))
    return [node("Chao", "Folder", {}, chao), node("Decoracao", "Folder", {}, deco), node("Inimigos", "Folder", {}, pads)]


def salvar(nome, filhos):
    path = ROOT / "src/workspace" / f"{nome}.model.json"
    data = {"className": "Model", "ignoreUnknownInstances": True, "children": filhos}
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n")

    def conta(n):
        return 1 + sum(conta(c) for c in n.get("children", []))
    print(f"{path.relative_to(ROOT)}: {sum(conta(c) for c in filhos)} instâncias")


if __name__ == "__main__":
    salvar("FXVilaNova", vila_nova())
    salvar("FXCamposNevoa", campos())
