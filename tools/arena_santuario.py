"""
arena_santuario.py — SANTUÁRIO DO BOSS DENTRO DA MURALHA SUL + JARDIM DA CACHOEIRA (usado por gerar_arena.py).

Dono (2026-09-21): o altar/spawn do boss ficam DENTRO da muralha; de fora só se vê a cachoeira caindo da
rocha, com floresta/vegetação mesopotâmica em volta. O altar antigo (pedra escura, runas vermelhas, ossos)
saiu. A muralha é aberta por tools/escavar_muralha.luau (rochas de x 30..166 / z 380..470 sobem até o
fundo ficar em y 34); aqui a CÂMARA fecha esse vão por dentro (casca de rocha) e o resto da região
(x 0..30 e 166..210) é tapado com blocos de rocha.

v2 (dono, 2026-09-21 → feito 2026-09-22): lá fora é "AMAZÔNIA ANTIGA + TEMPLOS ASTECAS" — cachoeira em
patamares, opaca e cheia, mata fechada (sumaúmas com raízes tabulares, samambaias gigantes, bananeiras/
heliconias, cipós, bromélias, troncos caídos, nevoeiro baixo) e duas pirâmides escalonadas com escadaria,
serpentes emplumadas e altar no topo + ruínas tomadas pela mata. Som da cachoeira = waterfall3_looped do
pack JJS (72131057531506, público; o id antigo 9120386436 tinha 0,4 s e virava BUZINA em loop).

Nomes que os serviços procuram (RitualService/BossService/BossFormService): BossAltar (prompts E/F),
BossAltarRune (acende no ritual), BossCrack0..7 (idem), BossSpawn (boss nasce), BossArena (centro da luta).
"""

import math

# --- geometria da câmara (mundo) -------------------------------------------------------------
CX = 98.0              # eixo x do santuário (mesmo da cachoeira)
IN_X0, IN_X1 = 34.0, 162.0   # interior x
IN_Z0, IN_Z1 = 388.0, 462.0  # interior z (frente = 388, fundo = 462)
FLOOR_Y = 0.0          # topo do piso da câmara
CEIL_Y = 30.0          # pé-direito
SHELL = 4.0            # espessura da casca
CAVE_TOP = 34.0        # fundo das rochas escavadas (= topo da laje do teto)
DOOR_HALF = 14.0       # meia largura do túnel de entrada
DOOR_H = 16.0          # altura do túnel
FACE_Z = 380.0         # face externa da muralha (frente da casca)
OUT_GROUND = -0.87     # topo do chão do mapa em frente (Outter / Ground do canto)

ROCK = ("Slate", (0.388, 0.384, 0.392))
ROCK_DARK = ("Slate", (0.30, 0.29, 0.30))
SAND = ("Sandstone", (0.77, 0.66, 0.46))
SAND_DARK = ("Sandstone", (0.63, 0.52, 0.35))
BRICK = ("Brick", (0.66, 0.50, 0.34))
LAPIS = ("SmoothPlastic", (0.13, 0.24, 0.63))
LAPIS_GLOW = ("Neon", (0.30, 0.50, 1.0))
GOLD = ("Metal", (0.84, 0.69, 0.30))
GOLD_GLOW = ("Neon", (1.0, 0.86, 0.45))
WATER = ("Glass", (0.47, 0.74, 0.92))
WATER_FF = ("ForceField", (0.47, 0.74, 0.92))
WATER_WHITE = ("ForceField", (0.88, 0.94, 1.0))
CLAY = ("Slate", (0.59, 0.39, 0.27))
TRUNK = ("Wood", (0.43, 0.31, 0.20))
PALM_LEAF = ("Grass", (0.27, 0.51, 0.24))
CEDAR = ("LeafyGrass", (0.16, 0.36, 0.20))
CEDAR2 = ("LeafyGrass", (0.22, 0.44, 0.24))
TAMARISK = ("LeafyGrass", (0.40, 0.55, 0.30))
REED = ("Grass", (0.36, 0.50, 0.22))
MOSS = ("Grass", (0.24, 0.40, 0.20))
GARDEN = ("LeafyGrass", (0.25, 0.40, 0.21))
FLOWER = [("Fabric", (0.90, 0.35, 0.40)), ("Fabric", (0.95, 0.80, 0.30)), ("Fabric", (0.75, 0.45, 0.85))]
NEON_FIRE = ("Neon", (1.0, 0.55, 0.2))
IRON = ("Metal", (0.22, 0.20, 0.19))


def build(ctx):
    part, cylinder, ball, wedge, light, fire, rng, jitter = (
        ctx["part"], ctx["cylinder"], ctx["ball"], ctx["wedge"], ctx["light"], ctx["fire"], ctx["rng"], ctx["jitter"])

    def emitter(node, name, color, size0, size1, rate, life, speed, spread, extra=None):
        props = {
            "Color": {"ColorSequence": {"keypoints": [{"time": 0, "color": list(color)}, {"time": 1, "color": list(color)}]}},
            "Size": {"NumberSequence": {"keypoints": [{"time": 0, "value": size0, "envelope": 0}, {"time": 1, "value": size1, "envelope": 0}]}},
            "Transparency": {"NumberSequence": {"keypoints": [{"time": 0, "value": 0.5, "envelope": 0}, {"time": 1, "value": 1, "envelope": 0}]}},
            "Rate": rate, "Lifetime": {"NumberRange": list(life)}, "Speed": {"NumberRange": list(speed)},
            "SpreadAngle": {"Vector2": [spread, spread]}, "Rotation": {"NumberRange": [0, 360]}, "RotSpeed": {"NumberRange": [-15, 15]},
        }
        if extra:
            props.update(extra)
        node.setdefault("children", []).append({"name": name, "className": "ParticleEmitter", "properties": props})

    # =========================================================================================
    # CASCA DA CÂMARA (rocha) — fecha o vão escavado na muralha
    # =========================================================================================
    ox0, ox1 = IN_X0 - SHELL, IN_X1 + SHELL          # 30..166
    oz0, oz1 = FACE_Z, IN_Z1 + SHELL + 4            # 380..470
    wall_h = CAVE_TOP - (FLOOR_Y - SHELL)           # -4..34
    wall_cy = (CAVE_TOP + FLOOR_Y - SHELL) / 2
    # piso e teto
    part("SanctShellFloor", (ox1 - ox0, SHELL, oz1 - oz0), (CX, FLOOR_Y - SHELL / 2, (oz0 + oz1) / 2), SAND_DARK)
    part("SanctShellCeil", (ox1 - ox0, CAVE_TOP - CEIL_Y, oz1 - oz0), (CX, (CAVE_TOP + CEIL_Y) / 2, (oz0 + oz1) / 2), ROCK)
    # laterais e fundo
    part("SanctShellW", (SHELL, wall_h, oz1 - oz0), (ox0 + SHELL / 2, wall_cy, (oz0 + oz1) / 2), ROCK)
    part("SanctShellE", (SHELL, wall_h, oz1 - oz0), (ox1 - SHELL / 2, wall_cy, (oz0 + oz1) / 2), ROCK)
    part("SanctShellBack", (ox1 - ox0, wall_h, oz1 - IN_Z1), (CX, wall_cy, (IN_Z1 + oz1) / 2), ROCK)
    # frente (face da muralha) com a abertura do túnel
    fz = (FACE_Z + IN_Z0) / 2
    fd = IN_Z0 - FACE_Z
    part("SanctShellFrontW", (CX - DOOR_HALF - ox0, wall_h, fd), ((ox0 + CX - DOOR_HALF) / 2, wall_cy, fz), ROCK)
    part("SanctShellFrontE", (ox1 - (CX + DOOR_HALF), wall_h, fd), ((ox1 + CX + DOOR_HALF) / 2, wall_cy, fz), ROCK)
    part("SanctShellFrontTop", (DOOR_HALF * 2, CAVE_TOP - DOOR_H, fd), (CX, (CAVE_TOP + DOOR_H) / 2, fz), ROCK)
    # tapa-buracos onde as rochas subiram fora da câmara (x 0..30 e 166..210)
    part("SanctFillW", (ox0 - 0, CAVE_TOP - OUT_GROUND, 92), (ox0 / 2, (CAVE_TOP + OUT_GROUND) / 2, 378 + 46), ROCK)
    part("SanctFillE", (212 - ox1, CAVE_TOP - OUT_GROUND, 104), ((212 + ox1) / 2, (CAVE_TOP + OUT_GROUND) / 2, 368 + 52), ROCK)
    # pedregulhos na base da face (disfarçam a emenda rocha nova / rocha antiga)
    for i in range(22):
        x = rng.uniform(2, 208)
        if abs(x - CX) < DOOR_HALF + 6:
            continue
        r = rng.uniform(2.5, 5.5)
        ball(f"SanctBoulder{i}", r, (x, OUT_GROUND + r * 0.55, FACE_Z - r * 0.6 + rng.uniform(-1, 1)), ROCK_DARK if i % 2 else ROCK)
    for i in range(6):
        r = rng.uniform(3, 6)
        ball(f"SanctBoulderTop{i}", r, (rng.uniform(20, 180), CAVE_TOP + rng.uniform(-3, 2), FACE_Z - r * 0.4), ROCK_DARK)

    # =========================================================================================
    # TÚNEL + INTERIOR
    # =========================================================================================
    # piso: tabuleiro de arenito claro/escuro (12x12) + tapete central de lápis-lazúli até o altar
    tile = 12.0
    nx = int((IN_X1 - IN_X0) // tile)
    nz = int((IN_Z1 - IN_Z0) // tile)
    for ix in range(nx + 1):
        for iz in range(nz + 1):
            x = IN_X0 + tile / 2 + ix * tile
            z = IN_Z0 + tile / 2 + iz * tile
            if x + tile / 2 > IN_X1 + 0.1 or z + tile / 2 > IN_Z1 + 0.1:
                continue
            part(f"SanctTile{ix}_{iz}", (tile - 0.3, 0.3, tile - 0.3), (x, FLOOR_Y + 0.15, z), SAND if (ix + iz) % 2 else SAND_DARK, CastShadow=False)
    ALTAR_Z = IN_Z1 - 16.0  # 446
    part("SanctCarpet", (10, 0.32, ALTAR_Z - 12 - IN_Z0), (CX, FLOOR_Y + 0.2, (IN_Z0 + ALTAR_Z - 12) / 2), LAPIS, CastShadow=False)
    part("SanctCarpetGoldW", (0.6, 0.34, ALTAR_Z - 12 - IN_Z0), (CX - 5.2, FLOOR_Y + 0.2, (IN_Z0 + ALTAR_Z - 12) / 2), GOLD, CastShadow=False)
    part("SanctCarpetGoldE", (0.6, 0.34, ALTAR_Z - 12 - IN_Z0), (CX + 5.2, FLOOR_Y + 0.2, (IN_Z0 + ALTAR_Z - 12) / 2), GOLD, CastShadow=False)
    # túnel: piso de lajes + lápis nas paredes + névoa
    part("SanctTunnelFloor", (DOOR_HALF * 2, 0.3, fd + 1), (CX, FLOOR_Y + 0.15, fz), SAND_DARK, CastShadow=False)
    for sx in (-1, 1):
        part(f"SanctTunnelBand{'W' if sx < 0 else 'E'}", (0.3, 1.2, fd + 1), (CX + sx * (DOOR_HALF - 0.15), FLOOR_Y + 8, fz), LAPIS, CastShadow=False)

    # ALTAR: zigurate de 5 degraus no fundo; em cima o pedestal da flecha (BossAltar) e a placa que acende
    y = FLOOR_Y
    for i, w in enumerate((26, 21, 16.5, 12.5, 9)):
        h = 1.7
        part(f"SanctZig{i}", (w, h, w * 0.8), (CX, y + h / 2, ALTAR_Z), SAND if i % 2 == 0 else SAND_DARK)
        if i % 2 == 1:
            part(f"SanctZigBand{i}", (w + 0.1, 0.35, w * 0.8 + 0.1), (CX, y + h - 0.35, ALTAR_Z), LAPIS)
        y += h
    ALTAR_TOP = y  # 8.5
    # escada frontal
    for i in range(5):
        part(f"SanctStair{i}", (6, 0.34, 1.7), (CX, FLOOR_Y + 0.17 + i * 1.7 + 1.53, ALTAR_Z - 10.4 + i * 1.5), SAND_DARK)
    part("BossAltar", (4.2, 3.0, 4.2), (CX, ALTAR_TOP + 1.5, ALTAR_Z), SAND_DARK)
    part("BossAltarCap", (4.6, 0.4, 4.6), (CX, ALTAR_TOP + 3.1, ALTAR_Z), GOLD)
    rune = part("BossAltarRune", (2.6, 0.2, 2.6), (CX, ALTAR_TOP + 3.4, ALTAR_Z), LAPIS_GLOW, CastShadow=False)
    light(rune, (0.4, 0.6, 1.0), 2.0, 26)
    # chifres de ouro nos 4 cantos do pedestal (altares mesopotâmicos)
    for i, (dx, dz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        part(f"SanctHorn{i}", (0.6, 1.4, 0.6), (CX + dx * 1.9, ALTAR_TOP + 3.7, ALTAR_Z + dz * 1.9), GOLD, rot=(dx * 10, 0, -dz * 10))
    # rachaduras de luz (BossCrack*) irradiando do altar pelo piso: acendem no ritual
    for i in range(8):
        a = math.radians(200 + i * 20)
        ln = rng.uniform(8, 14)
        cx_, cz_ = CX + math.cos(a) * (14 + ln / 2), ALTAR_Z + math.sin(a) * (14 + ln / 2)
        part(f"BossCrack{i}", (0.4, 0.14, ln), (cx_, FLOOR_Y + 0.36, cz_), ("Neon", (0.12, 0.20, 0.45)), rot=(0, -math.degrees(a) + 90, 0), CastShadow=False)
    # relevo no fundo: disco solar alado (ouro) + faixa de lápis + tabuletas cuneiformes
    bz = IN_Z1 - 0.6
    part("SanctBandLapis", (IN_X1 - IN_X0 - 2, 2.2, 0.5), (CX, 24, bz), LAPIS)
    part("SanctBandGoldA", (IN_X1 - IN_X0 - 2, 0.4, 0.55), (CX, 25.3, bz), GOLD)
    part("SanctBandGoldB", (IN_X1 - IN_X0 - 2, 0.4, 0.55), (CX, 22.7, bz), GOLD)
    disc = cylinder("SanctSunDisc", 4.2, 0.6, (CX, 17.5, bz), GOLD_GLOW, axis="z", CastShadow=False)
    light(disc, (1.0, 0.8, 0.4), 1.6, 30)
    cylinder("SanctSunRing", 5.0, 0.4, (CX, 17.5, bz + 0.05), GOLD, axis="z")
    for sx in (-1, 1):
        for k, (ln, yy, tilt) in enumerate(((12, 17.5, 0), (11, 16.0, -8), (9.5, 14.7, -16))):
            part(f"SanctWing{'W' if sx < 0 else 'E'}{k}", (ln, 1.1, 0.5), (CX + sx * (5 + ln / 2), yy, bz), GOLD, rot=(0, 0, sx * tilt))
    for i, x in enumerate((IN_X0 + 8, IN_X0 + 20, IN_X1 - 8, IN_X1 - 20)):
        t = part(f"SanctTablet{i}", (5, 7, 0.6), (x, 10, bz), SAND)
        for r in range(7):
            part(f"SanctCunei{i}_{r}", (3.8, 0.22, 0.2), (x + rng.uniform(-0.3, 0.3), 12.8 - r * 0.9, bz - 0.35), ("Slate", (0.36, 0.28, 0.20)), CanCollide=False, CastShadow=False)
    # estátuas guardiãs (touros alados, "lamassu") flanqueando o altar
    for sx, name in ((-1, "W"), (1, "E")):
        bx = CX + sx * 20
        part(f"SanctLamassuBase{name}", (7, 1.5, 11), (bx, FLOOR_Y + 0.75, ALTAR_Z), SAND_DARK)
        part(f"SanctLamassuBody{name}", (5, 4.5, 9), (bx, FLOOR_Y + 3.75, ALTAR_Z), SAND)
        for j in range(4):
            part(f"SanctLamassuLeg{name}{j}", (1.2, 2.2, 1.2), (bx + (-1.5 if j % 2 else 1.5), FLOOR_Y + 2.6, ALTAR_Z + (-3.2 if j < 2 else 3.2)), SAND)
        part(f"SanctLamassuChest{name}", (4.2, 4, 3), (bx, FLOOR_Y + 6.5, ALTAR_Z - 4.5), SAND)
        part(f"SanctLamassuHead{name}", (3, 3.2, 3), (bx, FLOOR_Y + 9.6, ALTAR_Z - 5.2), SAND)
        part(f"SanctLamassuBeard{name}", (2.2, 2.4, 1.2), (bx, FLOOR_Y + 8.0, ALTAR_Z - 6.4), SAND_DARK)
        cylinder(f"SanctLamassuCrown{name}", 1.7, 1.2, (bx, FLOOR_Y + 11.6, ALTAR_Z - 5.2), GOLD)
        for k in range(3):
            wedge(f"SanctLamassuWing{name}{k}", (0.6, 5 - k, 6 - k * 1.2), (bx + sx * 2.6, FLOOR_Y + 7.5 + k * 0.6, ALTAR_Z + 1 + k * 1.4), SAND_DARK, (0, 0 if sx > 0 else 180, 0))
    # colunas com capitel de palmeira (2 fileiras) + braseiros nas bases
    for sx in (-1, 1):
        for k, z in enumerate((IN_Z0 + 10, IN_Z0 + 26, IN_Z0 + 42)):
            x = CX + sx * 36
            part(f"SanctColBase{'W' if sx < 0 else 'E'}{k}", (5, 1.2, 5), (x, FLOOR_Y + 0.6, z), SAND_DARK)
            cylinder(f"SanctCol{'W' if sx < 0 else 'E'}{k}", 1.7, CEIL_Y - 4, (x, FLOOR_Y + 1.2 + (CEIL_Y - 4) / 2, z), SAND)
            for b in range(3):
                part(f"SanctColBand{'W' if sx < 0 else 'E'}{k}_{b}", (3.7, 0.5, 3.7), (x, FLOOR_Y + 6 + b * 8, z), LAPIS)
            for leaf in range(6):
                a = leaf * 60
                part(f"SanctColLeaf{'W' if sx < 0 else 'E'}{k}_{leaf}", (1.4, 0.4, 4.2), (x + math.cos(math.radians(a)) * 2.4, CEIL_Y - 2.4, z + math.sin(math.radians(a)) * 2.4), GOLD, rot=(0, -a + 90, -25))
            if k % 2 == 0:
                bx = x - sx * 6
                cylinder(f"SanctBrazierStand{'W' if sx < 0 else 'E'}{k}", 0.5, 3.2, (bx, FLOOR_Y + 1.6, z), IRON)
                bowl = cylinder(f"SanctBrazier{'W' if sx < 0 else 'E'}{k}", 1.5, 0.9, (bx, FLOOR_Y + 3.6, z), IRON)
                fire(bowl, (1.0, 0.55, 0.2), 1.4, 22)
                light(bowl, (1.0, 0.6, 0.3), 1.8, 28)
    # lamparinas penduradas do teto (correntes + chama)
    for i, (x, z) in enumerate(((CX - 18, IN_Z0 + 18), (CX + 18, IN_Z0 + 18), (CX - 18, IN_Z0 + 44), (CX + 18, IN_Z0 + 44), (CX, IN_Z0 + 31))):
        part(f"SanctChain{i}", (0.25, 7, 0.25), (x, CEIL_Y - 3.5, z), IRON, CastShadow=False)
        bowl = cylinder(f"SanctLampBowl{i}", 1.1, 0.7, (x, CEIL_Y - 7.3, z), GOLD)
        flame = ball(f"SanctLampFlame{i}", 0.45, (x, CEIL_Y - 6.6, z), NEON_FIRE, CastShadow=False)
        light(flame, (1.0, 0.75, 0.45), 1.4, 24)
    # tanques laterais com água e lótus (o riacho da cachoeira "entra" na câmara)
    for sx in (-1, 1):
        x = CX + sx * 55
        part(f"SanctPoolRim{'W' if sx < 0 else 'E'}", (12, 1.0, 50), (x, FLOOR_Y + 0.5, IN_Z0 + 32), SAND_DARK)
        part(f"SanctPool{'W' if sx < 0 else 'E'}", (10, 0.4, 48), (x, FLOOR_Y + 0.9, IN_Z0 + 32), WATER, Transparency=0.35, Reflectance=0.25, CanCollide=False, CastShadow=False)
        for i in range(6):
            lx, lz = x + rng.uniform(-3.5, 3.5), IN_Z0 + 32 + rng.uniform(-21, 21)
            cylinder(f"SanctLotus{'W' if sx < 0 else 'E'}{i}", 1.0, 0.12, (lx, FLOOR_Y + 1.16, lz), ("Grass", (0.3, 0.5, 0.25)), CanCollide=False, CastShadow=False)
            ball(f"SanctLotusFlower{'W' if sx < 0 else 'E'}{i}", 0.35, (lx, FLOOR_Y + 1.4, lz), FLOWER[i % 3], CanCollide=False, CastShadow=False)
    # urnas encostadas nas laterais
    for i in range(8):
        sx = -1 if i % 2 else 1
        x = CX + sx * (IN_X1 - CX - 3)
        z = IN_Z0 + 6 + i * 7
        cylinder(f"SanctUrn{i}", 1.2, 2.8, (x, FLOOR_Y + 1.4, z), CLAY)
        cylinder(f"SanctUrnNeck{i}", 0.8, 0.6, (x, FLOOR_Y + 3.1, z), ("Slate", (0.5, 0.33, 0.23)))
    # poeira dourada no ar
    dust = part("SanctDust", (IN_X1 - IN_X0 - 10, 1, IN_Z1 - IN_Z0 - 10), (CX, 12, (IN_Z0 + IN_Z1) / 2), SAND, Transparency=1, CanCollide=False, CanQuery=False, CastShadow=False)
    emitter(dust, "Dust", (1.0, 0.85, 0.55), 0.12, 0.05, 6, (6, 10), (0.2, 0.6), 180, {"LightEmission": 0.6})
    # pontos que os serviços usam: boss nasce/luta no centro da câmara
    part("BossSpawn", (6, 1, 6), (CX, FLOOR_Y + 1.5, IN_Z0 + 30), SAND, Transparency=1, CanCollide=False, CastShadow=False)
    part("BossArena", (1, 1, 1), (CX, FLOOR_Y + 1.5, IN_Z0 + 34), SAND, Transparency=1, CanCollide=False, CastShadow=False)

    # =========================================================================================
    # FORA v2: cachoeira em PATAMARES + lago + AMAZÔNIA ANTIGA + TEMPLOS ASTECAS
    # =========================================================================================
    VEIL_W = DOOR_HALF * 2 + 6  # 34
    POOL_Z = FACE_Z - 12
    TOP_Y = CAVE_TOP + 52  # nascente lá em cima na rocha
    WET_ROCK = ("Slate", (0.30, 0.31, 0.33))
    STONE = ("Cobblestone", (0.52, 0.52, 0.50))
    STONE_DARK = ("Slate", (0.40, 0.41, 0.40))
    JADE = ("SmoothPlastic", (0.16, 0.52, 0.38))
    FEATHER = ("Fabric", (0.10, 0.60, 0.45))
    FEATHER_RED = ("Fabric", (0.80, 0.20, 0.15))
    GLYPH = [("SmoothPlastic", (0.80, 0.30, 0.20)), ("SmoothPlastic", (0.20, 0.55, 0.60)), ("SmoothPlastic", (0.85, 0.70, 0.25))]
    JUNGLE = ("LeafyGrass", (0.13, 0.33, 0.15))
    JUNGLE2 = ("LeafyGrass", (0.18, 0.42, 0.18))
    FERN = ("Grass", (0.20, 0.48, 0.18))
    BANANA = ("Grass", (0.25, 0.55, 0.20))
    HELICONIA = ("Fabric", (0.90, 0.25, 0.15))
    BROMELIA = ("Fabric", (0.85, 0.35, 0.45))
    LIANA = ("Wood", (0.30, 0.25, 0.16))
    BARK = ("Wood", (0.36, 0.28, 0.20))
    BARK_GREY = ("Wood", (0.50, 0.46, 0.40))

    def beam(name, p0, p1, radius, mat, **extra):
        """cilindro entre dois pontos (cipó, raiz, tronco caído)."""
        dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
        ln = math.sqrt(dx * dx + dy * dy + dz * dz)
        if ln < 0.1:
            return None
        yaw = math.degrees(math.atan2(-dz, dx))
        pitch = math.degrees(math.asin(max(-1, min(1, dy / ln))))
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
        return part(name, (ln, radius * 2, radius * 2), mid, mat, rot=(0, yaw, pitch), Shape="Cylinder", **extra)

    # --- cachoeira: 3 patamares de rocha saindo da muralha, lençol opaco + espuma em cada queda ---
    TIERS = [(TOP_Y, 0), (TOP_Y - 18, 3.0), (TOP_Y - 36, 5.5)]  # (y do patamar, quanto salta da face)
    prev_y = TOP_Y + 6
    for t, (ty, jut) in enumerate(TIERS):
        w = VEIL_W * (0.55 + t * 0.2)
        ledge = part(f"CascadeLedge{t}", (w + 8, 2.5, 6 + jut), (CX, ty, FACE_Z - 1 - (6 + jut) / 2), WET_ROCK, Reflectance=0.25)
        for k in range(3):  # rochas molhadas na beira do patamar
            ball(f"CascadeLedgeRock{t}_{k}", rng.uniform(1.4, 2.6), (CX + (-1 if k % 2 else 1) * (w / 2 + 2 + k), ty + 1.5, FACE_Z - 2 - jut * 0.5), WET_ROCK, Reflectance=0.3)
        # bacia rasa no patamar (o lençol de cima cai aqui)
        part(f"CascadeBasin{t}", (w + 2, 0.4, 4 + jut), (CX, ty + 1.45, FACE_Z - 1 - (4 + jut) / 2), WATER, Transparency=0.25, Reflectance=0.35, CanCollide=False, CanQuery=False, CastShadow=False)
        # lençol caindo do patamar de cima até este
        h = prev_y - ty
        zf = FACE_Z - 1.5 - jut
        part(f"CascadeSheet{t}", (w, h, 1.6), (CX, ty + h / 2, zf), WATER, Transparency=0.15, Reflectance=0.2, CanCollide=False, CanQuery=False, CastShadow=False)
        part(f"CascadeFoam{t}", (w + 1.5, h, 0.8), (CX, ty + h / 2, zf - 1.2), WATER_WHITE, Transparency=0.35, CanCollide=False, CanQuery=False, CastShadow=False)
        part(f"CascadeFoamB{t}", (w * 0.6, h, 0.5), (CX + jitter(w * 0.15), ty + h / 2, zf - 1.9), ("Neon", (0.95, 0.98, 1.0)), Transparency=0.6, CanCollide=False, CanQuery=False, CastShadow=False)
        spl = part(f"CascadeSplash{t}", (w, 0.2, 3), (CX, ty + 1.8, zf - 1), WATER, Transparency=1, CanCollide=False, CanQuery=False, CastShadow=False)
        emitter(spl, "Spray", (0.92, 0.97, 1.0), 1.5, 5, 10, (1.0, 1.8), (3, 7), 50, {"LightEmission": 0.15})
        prev_y = ty + 1.5
    # queda final: do último patamar até o lago, na frente da boca do túnel (véu continua atravessável)
    last_y = TIERS[-1][0] + 1.5
    part("CascadeVeil", (VEIL_W, last_y - OUT_GROUND, 1.8), (CX, (last_y + OUT_GROUND) / 2, FACE_Z - 2.4), WATER, Transparency=0.18, Reflectance=0.2, CanCollide=False, CanQuery=False, CastShadow=False)
    part("CascadeVeilWhite", (VEIL_W + 2, last_y - OUT_GROUND, 0.8), (CX, (last_y + OUT_GROUND) / 2, FACE_Z - 3.5), WATER_WHITE, Transparency=0.35, CanCollide=False, CanQuery=False, CastShadow=False)
    for k in range(4):  # cordões de espuma mais brancos
        part(f"CascadeVeilCord{k}", (rng.uniform(2, 4), last_y - OUT_GROUND, 0.5), (CX - VEIL_W / 2 + 4 + k * (VEIL_W - 8) / 3 + jitter(1.5), (last_y + OUT_GROUND) / 2, FACE_Z - 4.1), ("Neon", (0.95, 0.98, 1.0)), Transparency=0.55, CanCollide=False, CanQuery=False, CastShadow=False)
    # lago mais fundo e largo (atravessável) + leito + rochas molhadas na borda
    part("CascadePool", (VEIL_W + 34, 0.6, 30), (CX, OUT_GROUND + 0.3, POOL_Z - 2), WATER, Transparency=0.3, Reflectance=0.35, CanCollide=False, CanQuery=False, CastShadow=False)
    part("CascadePoolBed", (VEIL_W + 38, 0.35, 34), (CX, OUT_GROUND + 0.05, POOL_Z - 2), ("Pebble", (0.38, 0.37, 0.34)), CanCollide=False, CastShadow=False)
    for i in range(18):
        a = rng.uniform(0, math.pi)
        r = rng.uniform(VEIL_W / 2 + 12, VEIL_W / 2 + 19)
        sz = rng.uniform(1.4, 3.6)
        ball(f"CascadeRock{i}", sz / 2, (CX + math.cos(a) * r, OUT_GROUND + sz * 0.25, POOL_Z + 2 - math.sin(a) * r * 0.55), WET_ROCK if i % 2 else ("Slate", (0.45, 0.44, 0.42)), Reflectance=0.3 if i % 2 else 0.1)
    mist = part("CascadeMist", (VEIL_W + 10, 0.2, 8), (CX, OUT_GROUND + 1, FACE_Z - 5), WATER, Transparency=1, CanCollide=False, CanQuery=False, CastShadow=False)
    emitter(mist, "Mist", (0.9, 0.96, 1.0), 4, 12, 24, (1.8, 3.0), (2, 6), 70, {"LightEmission": 0.2})
    emitter(mist, "Drops", (0.9, 0.96, 1.0), 0.3, 0.0, 60, (0.5, 0.9), (8, 16), 75, {"Acceleration": {"Vector3": [0, -40, 0]}})
    fall = part("CascadeFall", (VEIL_W * 0.55, 0.2, 1), (CX, TOP_Y + 5, FACE_Z - 1.5), WATER, Transparency=1, CanCollide=False, CanQuery=False, CastShadow=False)
    emitter(fall, "Fall", (0.9, 0.96, 1.0), 0.8, 0.3, 40, (2.0, 2.6), (0, 1), 4, {"Acceleration": {"Vector3": [0, -28, 0]}, "EmissionDirection": "Bottom"})
    # som de verdade (waterfall3_looped do pack JJS, público — testado via MCP 2026-09-22)
    mist.setdefault("children", []).append({"name": "Cachoeira", "className": "Sound", "properties": {
        "SoundId": "rbxassetid://72131057531506", "Looped": True, "Volume": 0.7, "RollOffMaxDistance": 120, "RollOffMinDistance": 16, "Playing": True}})
    light(mist, (0.6, 0.8, 1.0), 0.8, 30)
    # arco-íris leve na névoa (7 faixas finas em arco, bem transparentes)
    RAINBOW = [(1.0, 0.2, 0.2), (1.0, 0.6, 0.1), (1.0, 0.95, 0.2), (0.3, 0.9, 0.3), (0.2, 0.6, 1.0), (0.3, 0.3, 0.9), (0.6, 0.3, 0.9)]
    for c, col in enumerate(RAINBOW):
        rr = 24 - c * 0.9
        for sgm in range(10):
            a0 = math.radians(15 + sgm * 15)
            a1 = math.radians(15 + (sgm + 1) * 15)
            p0 = (CX + math.cos(a0) * rr, OUT_GROUND + 2 + math.sin(a0) * rr, POOL_Z - 8)
            p1 = (CX + math.cos(a1) * rr, OUT_GROUND + 2 + math.sin(a1) * rr, POOL_Z - 8)
            beam(f"Rainbow{c}_{sgm}", p0, p1, 0.4, ("Neon", col), Transparency=0.78, CanCollide=False, CanQuery=False, CastShadow=False)
    # riacho saindo do lago pelo jardim (para o norte), com pedrinhas
    for i in range(6):
        z = POOL_Z - 18 - i * 9
        x = CX + math.sin(i * 0.9) * 6
        part(f"StreamSeg{i}", (7 - i * 0.4, 0.3, 10), (x, OUT_GROUND + 0.18, z), WATER, rot=(0, math.cos(i * 0.9) * 20, 0), Transparency=0.4, Reflectance=0.2, CanCollide=False, CanQuery=False, CastShadow=False)
        part(f"StreamBed{i}", (9 - i * 0.4, 0.2, 11), (x, OUT_GROUND + 0.04, z), ("Pebble", (0.42, 0.40, 0.36)), rot=(0, math.cos(i * 0.9) * 20, 0), CanCollide=False, CastShadow=False)

    # --- MATA: chão de selva, clareira em volta do lago e do caminho ----------------------------
    GX0, GX1, GZ0, GZ1 = 24, 176, 298, FACE_Z - 4
    cylinder("GardenFloorA", 46, 0.2, (CX - 38, OUT_GROUND + 0.1, 340), JUNGLE, CastShadow=False)
    cylinder("GardenFloorB", 46, 0.2, (CX + 38, OUT_GROUND + 0.1, 340), JUNGLE, CastShadow=False)
    cylinder("GardenFloorC", 36, 0.2, (CX, OUT_GROUND + 0.12, 312), JUNGLE2, CastShadow=False)
    for i in range(9):  # caminho de lajes da praça até o lago
        z = 296 + i * 7
        part(f"GardenSlab{i}", (rng.uniform(3, 4.5), 0.3, rng.uniform(2.6, 3.6)), (CX + jitter(2.5), OUT_GROUND + 0.22, z), STONE_DARK, rot=(0, rng.uniform(-25, 25), 0), CastShadow=False)

    # (a arte tem um pinheiro em (110, 337): nada nasce a menos de 14 studs dele)
    ART_TREE = (110, 337)
    TEMPLE_X = 50  # pirâmides em CX ± TEMPLE_X (x 33..63 e 133..163), z 301..331; escadaria para o meio
    TEMPLE_Z = 316  # (o pinheiro da arte em (110, 337) fica 21 studs ao sul da escadaria leste)

    def free(x, z, r=8):
        if math.hypot(x - ART_TREE[0], z - ART_TREE[1]) < 14:
            return False
        if abs(x - CX) < 6 and z > 300:  # caminho + riacho
            return False
        if abs(x - CX) < VEIL_W / 2 + 18 and z > POOL_Z - 20:  # lago
            return False
        for sx in (-1, 1):  # pirâmides + escadaria (que desce 22 studs para o lado da clareira)
            dxr = (x - (CX + sx * TEMPLE_X)) * sx  # > 0 = para fora, < 0 = para a clareira
            if -40 - r * 0.5 < dxr < 16 + r * 0.5 and abs(z - TEMPLE_Z) < 16 + r * 0.5:
                return False
        return True

    tops = []  # copas das árvores altas (para os cipós)

    def kapok(x, z, h):
        """sumaúma: tronco alto cinza, raízes tabulares (wedges) e copa larga em guarda-chuva."""
        cylinder(f"KapokTrunk{x:.0f}_{z:.0f}", 1.6, h, (x, OUT_GROUND + h / 2, z), BARK_GREY)
        cylinder(f"KapokTrunkB{x:.0f}_{z:.0f}", 2.4, 5, (x, OUT_GROUND + 2.5, z), BARK_GREY)
        for i in range(6):
            a = i * 60 + rng.uniform(-12, 12)
            ar = math.radians(a)
            ln = rng.uniform(5, 8)
            wedge(f"KapokRoot{x:.0f}_{z:.0f}_{i}", (1.0, rng.uniform(4, 7), ln), (x + math.cos(ar) * (ln / 2 + 1.5), OUT_GROUND + 2.5, z - math.sin(ar) * (ln / 2 + 1.5)), BARK_GREY, rot=(0, a + 180, 0))
        top = (x, OUT_GROUND + h, z)
        for i in range(7):
            a = i * 51 + rng.uniform(-15, 15)
            ar = math.radians(a)
            r = rng.uniform(6, 10)
            bx, bz = x + math.cos(ar) * r * 0.75, z + math.sin(ar) * r * 0.75
            beam(f"KapokBranch{x:.0f}_{z:.0f}_{i}", (x, top[1] - 2, z), (bx, top[1] + rng.uniform(0, 3), bz), 0.5, BARK_GREY, CanCollide=False, CanQuery=False)
            ball(f"KapokCanopy{x:.0f}_{z:.0f}_{i}", rng.uniform(5, 7.5), (bx, top[1] + rng.uniform(1, 4), bz), JUNGLE if i % 2 else JUNGLE2, CanCollide=False, CanQuery=False)
        ball(f"KapokCanopyTop{x:.0f}_{z:.0f}", 6, (x, top[1] + 5, z), JUNGLE2, CanCollide=False, CanQuery=False)
        for i in range(3):  # bromélias no tronco
            a = math.radians(rng.uniform(0, 360))
            yy = OUT_GROUND + rng.uniform(6, h - 6)
            ball(f"Bromelia{x:.0f}_{z:.0f}_{i}", 0.9, (x + math.cos(a) * 1.9, yy, z + math.sin(a) * 1.9), BROMELIA, CanCollide=False, CanQuery=False, CastShadow=False)
            ball(f"BromeliaLeaf{x:.0f}_{z:.0f}_{i}", 1.3, (x + math.cos(a) * 2.2, yy - 0.5, z + math.sin(a) * 2.2), FERN, CanCollide=False, CanQuery=False, CastShadow=False)
        tops.append((x, top[1] + 2, z))

    def jungle_tree(x, z, h):
        """árvore média de mata fechada: tronco escuro + copa densa de bolas."""
        cylinder(f"JTrunk{x:.0f}_{z:.0f}", 0.9, h * 0.6, (x, OUT_GROUND + h * 0.3, z), BARK)
        for i in range(5):
            ball(f"JCanopy{x:.0f}_{z:.0f}_{i}", rng.uniform(3.5, 5.5), (x + jitter(3), OUT_GROUND + h * 0.6 + rng.uniform(0, 4), z + jitter(3)), JUNGLE if i % 2 else JUNGLE2, CanCollide=False, CanQuery=False)
        tops.append((x, OUT_GROUND + h * 0.6 + 3, z))

    def fern(x, z, s=1.0):
        """samambaia gigante: folhas radiais inclinadas para cima."""
        n = 9
        for i in range(n):
            a = i * 360 / n + rng.uniform(-10, 10)
            ar = math.radians(a)
            ln = rng.uniform(4, 6) * s
            part(f"Fern{x:.0f}_{z:.0f}_{i}", (ln, 0.12, 1.4 * s), (x + math.cos(ar) * ln * 0.45, OUT_GROUND + 1.2 * s + ln * 0.25, z - math.sin(ar) * ln * 0.45), FERN, rot=(0, a, 32), CanCollide=False, CanQuery=False, CastShadow=False)

    def banana(x, z):
        """bananeira/heliconia: pseudocaule + folhas largas + cachos vermelhos."""
        h = rng.uniform(5, 8)
        cylinder(f"BananaStem{x:.0f}_{z:.0f}", 0.35, h, (x, OUT_GROUND + h / 2, z), BANANA)
        for i in range(6):
            a = i * 60 + rng.uniform(-15, 15)
            ar = math.radians(a)
            ln = rng.uniform(5, 7)
            part(f"BananaLeaf{x:.0f}_{z:.0f}_{i}", (ln, 0.12, 2.2), (x + math.cos(ar) * ln * 0.4, OUT_GROUND + h - 0.5 + ln * 0.15, z - math.sin(ar) * ln * 0.4), BANANA, rot=(0, a, 20 - i * 3), CanCollide=False, CanQuery=False, CastShadow=False)
        for i in range(3):
            part(f"Heliconia{x:.0f}_{z:.0f}_{i}", (0.6, 0.35, 1.8), (x + jitter(1.2), OUT_GROUND + h - 1.5 - i * 0.7, z + jitter(1.2)), HELICONIA, rot=(0, rng.uniform(0, 360), 30), CanCollide=False, CanQuery=False, CastShadow=False)

    def fallen_log(x, z):
        a = rng.uniform(0, math.pi)
        ln = rng.uniform(8, 13)
        p0 = (x - math.cos(a) * ln / 2, OUT_GROUND + 0.9, z - math.sin(a) * ln / 2)
        p1 = (x + math.cos(a) * ln / 2, OUT_GROUND + 1.4, z + math.sin(a) * ln / 2)
        beam(f"FallenLog{x:.0f}_{z:.0f}", p0, p1, 1.0, BARK)
        for i in range(3):
            t = (i + 1) / 4
            part(f"FallenLogMoss{x:.0f}_{z:.0f}_{i}", (2.2, 0.3, 1.6), (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t + 1.0, p0[2] + (p1[2] - p0[2]) * t), MOSS, rot=(0, math.degrees(-a), 0), CanCollide=False, CanQuery=False, CastShadow=False)
        fern(x + jitter(3), z + jitter(3), 0.7)

    # árvores altas (sumaúmas) em anel em volta da clareira, árvores médias preenchendo
    kapoks = [(CX - 34, 372), (CX + 36, 371), (CX - 68, 362), (CX + 70, 360), (CX - 28, 306), (CX + 30, 304), (CX - 72, 316), (CX + 74, 312), (CX - 60, 342), (CX + 64, 344)]
    for x, z in kapoks:
        if free(x, z, 10):
            kapok(x, z, rng.uniform(26, 34))
    placed = 0
    for _ in range(80):
        if placed >= 14:
            break
        x, z = rng.uniform(GX0 + 4, GX1 - 4), rng.uniform(GZ0 + 3, GZ1 - 8)
        if free(x, z, 6) and all(math.hypot(x - kx, z - kz) > 9 for kx, _, kz in tops):
            jungle_tree(x, z, rng.uniform(14, 20))
            placed += 1
    # cipós entre copas próximas (pendurados: passam por um ponto mais baixo no meio)
    n_lianas = 0
    for i, a in enumerate(tops):
        for b in tops[i + 1:]:
            d = math.hypot(a[0] - b[0], a[2] - b[2])
            if 10 < d < 34 and n_lianas < 22:
                sag = rng.uniform(4, 8)
                mid = ((a[0] + b[0]) / 2 + jitter(2), min(a[1], b[1]) - sag, (a[2] + b[2]) / 2 + jitter(2))
                beam(f"Liana{n_lianas}A", a, mid, 0.18, LIANA, CanCollide=False, CanQuery=False, CastShadow=False)
                beam(f"Liana{n_lianas}B", mid, b, 0.18, LIANA, CanCollide=False, CanQuery=False, CastShadow=False)
                n_lianas += 1
    for i, (x, y, z) in enumerate(tops[:8]):  # cipós pendurados até perto do chão
        ln = rng.uniform(8, 14)
        beam(f"LianaDrop{i}", (x + jitter(4), y - 1, z + jitter(4)), (x + jitter(6), max(OUT_GROUND + 2, y - 1 - ln), z + jitter(6)), 0.15, LIANA, CanCollide=False, CanQuery=False, CastShadow=False)
    for i in range(22):
        x, z = rng.uniform(GX0, GX1), rng.uniform(GZ0, GZ1)
        if free(x, z, 4):
            fern(x, z, rng.uniform(0.8, 1.4))
    for i in range(14):
        x, z = rng.uniform(GX0, GX1), rng.uniform(GZ0, GZ1)
        if free(x, z, 4):
            banana(x, z)
    for i in range(6):
        x, z = rng.uniform(GX0 + 8, GX1 - 8), rng.uniform(GZ0 + 6, GZ1 - 12)
        if free(x, z, 7):
            fallen_log(x, z)
    for i in range(24):
        x, z = rng.uniform(GX0, GX1), rng.uniform(GZ0, GZ1)
        if free(x, z, 2):
            part(f"GardenMoss{i}", (rng.uniform(2, 6), 0.15, rng.uniform(2, 6)), (x, OUT_GROUND + 0.16, z), MOSS, rot=(0, rng.uniform(0, 360), 0), CanCollide=False, CanQuery=False, CastShadow=False)
    for i in range(30):
        x, z = rng.uniform(GX0, GX1), rng.uniform(GZ0, GZ1)
        if free(x, z, 2):
            ball(f"GardenFlower{i}", rng.uniform(0.35, 0.6), (x, OUT_GROUND + 0.45, z), FLOWER[i % 3], CanCollide=False, CanQuery=False, CastShadow=False)
    # nevoeiro baixo rente ao chão da mata
    fog = part("JungleFog", (150, 1, 76), (CX, OUT_GROUND + 1.2, 337), SAND, Transparency=1, CanCollide=False, CanQuery=False, CastShadow=False)
    emitter(fog, "Fog", (0.80, 0.88, 0.80), 10, 16, 6, (6, 9), (0.3, 0.8), 180, {"Transparency": {"NumberSequence": {"keypoints": [{"time": 0, "value": 1, "envelope": 0}, {"time": 0.3, "value": 0.86, "envelope": 0}, {"time": 0.7, "value": 0.86, "envelope": 0}, {"time": 1, "value": 1, "envelope": 0}]}}})

    # --- TEMPLOS ASTECAS: pirâmide escalonada de cada lado, escadaria para a clareira ----------
    def temple(sx, name):
        x0, z0 = CX + sx * TEMPLE_X, TEMPLE_Z
        tiers = [(30, 4.0), (24, 3.6), (18, 3.2), (12, 2.8), (7, 2.4)]
        yy = OUT_GROUND
        for t, (w, h) in enumerate(tiers):
            part(f"Temple{name}Tier{t}", (w, h, w), (x0, yy + h / 2, z0), STONE if t % 2 == 0 else STONE_DARK)
            # cornija de pedra mais clara + glifos coloridos na face virada para a clareira (lado -sx)
            part(f"Temple{name}Cornice{t}", (w + 0.6, 0.5, w + 0.6), (x0, yy + h - 0.25, z0), ("Cobblestone", (0.62, 0.62, 0.58)))
            for g in range(int(w // 3)):
                part(f"Temple{name}Glyph{t}_{g}", (0.15, 1.2, 1.2), (x0 - sx * (w / 2 + 0.05), yy + h / 2, z0 - w / 2 + 2 + g * 3), GLYPH[(t + g) % 3], CanCollide=False, CanQuery=False, CastShadow=False)
            yy += h
        top_y = yy
        # escadaria central na face voltada para a clareira (lado -sx), com corrimões-serpente
        total_h = top_y - OUT_GROUND
        run = 22
        steps = 16
        for k in range(steps):
            sy = OUT_GROUND + (k + 0.5) * total_h / steps
            dx = (run - k * run / steps)
            part(f"Temple{name}Step{k}", (run / steps + 0.4, total_h / steps, 6), (x0 - sx * (15 + dx - run / steps / 2), sy, z0), ("Cobblestone", (0.58, 0.57, 0.53)))
        for side in (-1, 1):
            beam(f"Temple{name}Rail{'N' if side < 0 else 'S'}", (x0 - sx * (15 + run), OUT_GROUND + 1.2, z0 + side * 3.6), (x0 - sx * 15.5, top_y + 0.8, z0 + side * 3.6), 0.45, STONE_DARK)
            # cabeça de serpente emplumada no pé do corrimão
            hx, hz = x0 - sx * (15 + run + 1.5), z0 + side * 3.6
            ball(f"Temple{name}SerpentHead{'N' if side < 0 else 'S'}", 1.4, (hx, OUT_GROUND + 1.6, hz), JADE)
            part(f"Temple{name}SerpentJaw{'N' if side < 0 else 'S'}", (2.2, 0.6, 1.4), (hx - sx * 1.2, OUT_GROUND + 1.0, hz), JADE)
            for f in range(4):
                part(f"Temple{name}SerpentFeather{'N' if side < 0 else 'S'}{f}", (0.3, 1.8, 0.5), (hx + sx * 0.8 + jitter(0.3), OUT_GROUND + 3.0, hz + (f - 1.5) * 0.5), FEATHER if f % 2 else FEATHER_RED, rot=(0, 0, sx * -30), CanCollide=False, CanQuery=False, CastShadow=False)
            ball(f"Temple{name}SerpentEye{'N' if side < 0 else 'S'}", 0.3, (hx - sx * 0.9, OUT_GROUND + 2.0, hz + side * 0.9), ("Neon", (1.0, 0.3, 0.2)), CanCollide=False, CanQuery=False, CastShadow=False)
        # santuário no topo: altar de sacrifício (laje), pilares e teto de pedra, braseiros
        part(f"Temple{name}TopFloor", (8, 0.4, 8), (x0, top_y + 0.2, z0), ("Cobblestone", (0.62, 0.62, 0.58)))
        part(f"Temple{name}Altar", (3.2, 1.2, 1.8), (x0, top_y + 1.0, z0), ("Slate", (0.36, 0.34, 0.36)))
        part(f"Temple{name}AltarStain", (2.4, 0.06, 1.2), (x0, top_y + 1.63, z0), ("SmoothPlastic", (0.45, 0.10, 0.10)), CanCollide=False, CanQuery=False, CastShadow=False)
        for cx_, cz_ in ((-2.8, -2.8), (2.8, -2.8), (-2.8, 2.8), (2.8, 2.8)):
            part(f"Temple{name}Pillar{cx_:+.0f}{cz_:+.0f}", (1.0, 5, 1.0), (x0 + cx_, top_y + 2.9, z0 + cz_), STONE_DARK)
        part(f"Temple{name}Roof", (8.4, 0.8, 8.4), (x0, top_y + 5.8, z0), STONE)
        part(f"Temple{name}RoofCrest", (8.8, 1.2, 1.2), (x0, top_y + 6.8, z0), STONE_DARK)
        for g in range(4):
            part(f"Temple{name}RoofGlyph{g}", (1.4, 0.9, 0.15), (x0 - 3 + g * 2, top_y + 6.8, z0 - sx * 0.7), GLYPH[g % 3], CanCollide=False, CanQuery=False, CastShadow=False)
        for side in (-1, 1):
            bowl = cylinder(f"Temple{name}Brazier{'N' if side < 0 else 'S'}", 0.9, 0.8, (x0 - sx * 3.2, top_y + 0.8, z0 + side * 3.2), IRON)
            fire(bowl, (1.0, 0.5, 0.15), 1.4, 22)
            light(bowl, (1.0, 0.6, 0.3), 1.8, 26)
        # a mata tomou a pirâmide: musgo nos degraus, raízes por cima, samambaias na base
        for i in range(8):
            t = rng.randrange(0, 4)
            w = tiers[t][0]
            side = rng.choice((-1, 1))
            yy_ = OUT_GROUND + sum(hh for _, hh in tiers[: t + 1])
            part(f"Temple{name}Moss{i}", (rng.uniform(2, 5), 0.2, rng.uniform(1.5, 3)), (x0 + jitter(w / 2 - 2), yy_ + 0.35, z0 + side * (w / 2 - 1.2)), MOSS, rot=(0, rng.uniform(0, 360), 0), CanCollide=False, CanQuery=False, CastShadow=False)
        for i in range(3):
            a = math.radians(rng.uniform(20, 160) + (180 if sx > 0 else 0))
            p0 = (x0 + sx * 3, top_y - 4 - i * 3, z0 + math.sin(a) * 6)
            p1 = (x0 + sx * (15 + 4 + i * 3), OUT_GROUND + 0.4, z0 + math.sin(a) * (14 + i * 3))
            beam(f"Temple{name}Root{i}", p0, p1, 0.5, BARK_GREY, CanCollide=False)
        for i in range(4):
            fern(x0 + sx * (17 + jitter(3)), z0 + (i - 1.5) * 8 + jitter(2), rng.uniform(0.9, 1.3))

    temple(-1, "W")
    temple(1, "E")
    # ruínas tomadas pela mata (muro caído com glifos, cabeça de serpente tombada, coluna quebrada)
    for sx, name in ((-1, "W"), (1, "E")):
        x, z = CX + sx * 40, 358
        if free(x, z, 6):
            for r in range(3):
                ln = 10 - r * 2.5
                part(f"Ruin{name}Wall{r}", (ln, 1.5, 1.6), (x + sx * (10 - ln) / 2, OUT_GROUND + 0.75 + r * 1.5, z), STONE if r % 2 else STONE_DARK, rot=(0, sx * 30, 0))
            part(f"Ruin{name}Glyph", (3, 0.9, 1.7), (x - sx * 1.5, OUT_GROUND + 2.3, z), GLYPH[1], rot=(0, sx * 30, 0))
            part(f"Ruin{name}Moss", (4, 0.2, 2), (x, OUT_GROUND + 4.6, z), MOSS, rot=(0, sx * 30, 0), CanCollide=False, CanQuery=False, CastShadow=False)
            ball(f"Ruin{name}SerpentHead", 1.6, (x + sx * 7, OUT_GROUND + 1.2, z + 5), JADE, Orientation=[40, sx * 60, 20])
            cylinder(f"Ruin{name}Column", 1.1, 4.5, (x - sx * 7, OUT_GROUND + 2.25, z + 4), STONE_DARK)
            part(f"Ruin{name}ColumnTop", (2.6, 1.6, 2.6), (x - sx * 7 + 3, OUT_GROUND + 0.8, z + 8), STONE_DARK, rot=(0, 25, 35))
            fern(x + jitter(3), z + 6 + jitter(2), 0.9)
    # vaga-lumes de noite (partículas suaves) sobre a mata
    glow = part("GardenFireflies", (130, 1, 70), (CX, OUT_GROUND + 4, 336), SAND, Transparency=1, CanCollide=False, CanQuery=False, CastShadow=False)
    emitter(glow, "Fireflies", (1.0, 0.95, 0.5), 0.25, 0.1, 6, (4, 7), (0.4, 1.2), 180, {"LightEmission": 1})
