"""
arena_santuario.py — SANTUÁRIO DO BOSS DENTRO DA MURALHA SUL + JARDIM DA CACHOEIRA (usado por gerar_arena.py).

Dono (2026-09-21): o altar/spawn do boss ficam DENTRO da muralha; de fora só se vê a cachoeira caindo da
rocha, com floresta/vegetação mesopotâmica em volta. O altar antigo (pedra escura, runas vermelhas, ossos)
saiu. A muralha é aberta por tools/escavar_muralha.luau (rochas de x 30..166 / z 380..470 sobem até o
fundo ficar em y 34); aqui a CÂMARA fecha esse vão por dentro (casca de rocha) e o resto da região
(x 0..30 e 166..210) é tapado com blocos de rocha.

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
    # FORA: cachoeira caindo da rocha + lago + jardim mesopotâmico (só isso fica visível)
    # =========================================================================================
    VEIL_W = DOOR_HALF * 2 + 6  # 34
    POOL_Z = FACE_Z - 12
    TOP_Y = CAVE_TOP + 52  # nascente lá em cima na rocha
    # fio d'água descendo pela rocha até a boca (acima da abertura) e véu na frente do túnel
    part("CascadeUpper", (VEIL_W * 0.55, TOP_Y - DOOR_H, 1.2), (CX, (TOP_Y + DOOR_H) / 2, FACE_Z - 0.9), WATER_FF, CanCollide=False, CanQuery=False, Transparency=0.12, CastShadow=False)
    part("CascadeVeil", (VEIL_W, DOOR_H + 3, 1.2), (CX, OUT_GROUND + (DOOR_H + 3) / 2, FACE_Z - 2.2), WATER_FF, CanCollide=False, CanQuery=False, Transparency=0.05, CastShadow=False)
    part("CascadeVeilWhite", (VEIL_W + 2, DOOR_H + 3, 0.6), (CX, OUT_GROUND + (DOOR_H + 3) / 2, FACE_Z - 3.1), WATER_WHITE, CanCollide=False, CanQuery=False, Transparency=0.45, CastShadow=False)
    ledge = part("CascadeLedge", (VEIL_W + 6, 1.5, 4), (CX, TOP_Y + 0.5, FACE_Z - 1.5), ROCK_DARK)
    # lago raso (atravessável) + borda de seixos + pedras
    part("CascadePool", (VEIL_W + 26, 0.5, 24), (CX, OUT_GROUND + 0.25, POOL_Z), WATER, Transparency=0.35, Reflectance=0.3, CanCollide=False, CanQuery=False, CastShadow=False)
    part("CascadePoolBed", (VEIL_W + 30, 0.35, 28), (CX, OUT_GROUND + 0.05, POOL_Z), ("Pebble", (0.42, 0.40, 0.36)), CanCollide=False, CastShadow=False)
    for i in range(14):
        a = rng.uniform(0, math.pi)
        r = rng.uniform(VEIL_W / 2 + 9, VEIL_W / 2 + 15)
        s = rng.uniform(1.2, 3.2)
        ball(f"CascadeRock{i}", s / 2, (CX + math.cos(a) * r, OUT_GROUND + s * 0.25, POOL_Z - math.sin(a) * r * 0.5 + 4), ROCK_DARK if i % 2 else ("Slate", (0.45, 0.44, 0.42)))
    mist = part("CascadeMist", (VEIL_W, 0.2, 4), (CX, OUT_GROUND + 1, FACE_Z - 3), WATER, Transparency=1, CanCollide=False, CanQuery=False, CastShadow=False)
    emitter(mist, "Mist", (0.9, 0.96, 1.0), 3, 8, 16, (1.5, 2.5), (2, 5), 60, {"LightEmission": 0.2})
    emitter(mist, "Drops", (0.9, 0.96, 1.0), 0.3, 0.0, 40, (0.5, 0.9), (8, 14), 70, {"Acceleration": {"Vector3": [0, -40, 0]}})
    fall = part("CascadeFall", (VEIL_W, 0.2, 1), (CX, TOP_Y - 1, FACE_Z - 1.2), WATER, Transparency=1, CanCollide=False, CanQuery=False, CastShadow=False)
    emitter(fall, "Fall", (0.9, 0.96, 1.0), 0.8, 0.3, 40, (2.0, 2.6), (0, 1), 4, {"Acceleration": {"Vector3": [0, -28, 0]}, "EmissionDirection": "Bottom"})
    mist.setdefault("children", []).append({"name": "Cachoeira", "className": "Sound", "properties": {
        "SoundId": "rbxassetid://9120386436", "Looped": True, "Volume": 0.6, "RollOffMaxDistance": 100, "RollOffMinDistance": 14, "Playing": True}})
    light(mist, (0.6, 0.8, 1.0), 0.8, 30)
    # riacho saindo do lago pelo jardim (para o norte), com pedrinhas
    for i in range(6):
        z = POOL_Z - 14 - i * 9
        x = CX + math.sin(i * 0.9) * 6
        part(f"StreamSeg{i}", (7 - i * 0.4, 0.3, 10), (x, OUT_GROUND + 0.18, z), WATER, rot=(0, math.cos(i * 0.9) * 20, 0), Transparency=0.4, Reflectance=0.2, CanCollide=False, CanQuery=False, CastShadow=False)
        part(f"StreamBed{i}", (9 - i * 0.4, 0.2, 11), (x, OUT_GROUND + 0.04, z), ("Pebble", (0.42, 0.40, 0.36)), rot=(0, math.cos(i * 0.9) * 20, 0), CanCollide=False, CastShadow=False)

    # JARDIM: chão de vegetação, palmeiras, cedros, tamargueiras, papiro, flores, ruínas de tijolo
    GX0, GX1, GZ0, GZ1 = 24, 176, 298, FACE_Z - 4
    cylinder("GardenFloorA", 44, 0.2, (CX - 38, OUT_GROUND + 0.1, 340), GARDEN, CastShadow=False)
    cylinder("GardenFloorB", 44, 0.2, (CX + 38, OUT_GROUND + 0.1, 340), GARDEN, CastShadow=False)
    cylinder("GardenFloorC", 34, 0.2, (CX, OUT_GROUND + 0.12, 312), GARDEN, CastShadow=False)
    # caminho de lajes da praça até o lago
    for i in range(9):
        z = 296 + i * 7
        part(f"GardenSlab{i}", (rng.uniform(3, 4.5), 0.3, rng.uniform(2.6, 3.6)), (CX + jitter(2.5), OUT_GROUND + 0.22, z), SAND_DARK, rot=(0, rng.uniform(-25, 25), 0), CastShadow=False)

    def palm(x, z, h):
        segs = 6
        lx, lz = rng.uniform(-1, 1), rng.uniform(-1, 1)
        top = None
        for i in range(segs):
            y0 = OUT_GROUND + i * h / segs
            k = ((i + 1) / segs) ** 2 * 2.5
            px, pz = x + lx * k, z + lz * k
            cylinder(f"PalmTrunk{x:.0f}_{z:.0f}_{i}", 0.75 - i * 0.05, h / segs + 0.3, (px, y0 + h / segs / 2, pz), TRUNK)
            top = (px, y0 + h / segs, pz)
        for i in range(8):
            a = i * 45 + rng.uniform(-10, 10)
            ar = math.radians(a)
            part(f"PalmLeaf{x:.0f}_{z:.0f}_{i}", (1.6, 0.15, 7), (top[0] + math.cos(ar) * 3.0, top[1] + 0.6, top[2] + math.sin(ar) * 3.0), PALM_LEAF, rot=(0, -a + 90, -28), CanCollide=False, CanQuery=False)
        ball(f"PalmDates{x:.0f}_{z:.0f}", 0.6, (top[0] + 0.5, top[1] - 0.6, top[2] + 0.3), ("Fabric", (0.55, 0.30, 0.12)), CanCollide=False)

    def cedar(x, z, h):
        cylinder(f"CedarTrunk{x:.0f}_{z:.0f}", 0.9, h * 0.45, (x, OUT_GROUND + h * 0.225, z), TRUNK)
        tiers = 4
        for i in range(tiers):
            r = 5.5 - i * 1.1
            yy = OUT_GROUND + h * 0.35 + i * (h * 0.65 / tiers)
            cylinder(f"CedarTier{x:.0f}_{z:.0f}_{i}", r, 1.4, (x, yy, z), CEDAR if i % 2 else CEDAR2, CanCollide=False)
            cylinder(f"CedarTierB{x:.0f}_{z:.0f}_{i}", r * 0.75, 1.2, (x + jitter(0.6), yy + 1.2, z + jitter(0.6)), CEDAR2 if i % 2 else CEDAR, CanCollide=False)
        ball(f"CedarTop{x:.0f}_{z:.0f}", 1.6, (x, OUT_GROUND + h, z), CEDAR, CanCollide=False)

    def tamarisk(x, z):
        cylinder(f"TamTrunk{x:.0f}_{z:.0f}", 0.4, 2.2, (x, OUT_GROUND + 1.1, z), TRUNK)
        for i in range(4):
            ball(f"TamBush{x:.0f}_{z:.0f}_{i}", rng.uniform(1.6, 2.6), (x + jitter(1.8), OUT_GROUND + 3 + jitter(0.8), z + jitter(1.8)), TAMARISK, CanCollide=False)

    def papyrus(x, z):
        for i in range(4):
            hh = rng.uniform(3, 5)
            px, pz = x + jitter(0.9), z + jitter(0.9)
            cylinder(f"Papyrus{x:.0f}_{z:.0f}_{i}", 0.1, hh, (px, OUT_GROUND + hh / 2, pz), REED, CanCollide=False, CanQuery=False, CastShadow=False)
            ball(f"PapyrusTop{x:.0f}_{z:.0f}_{i}", 0.5, (px, OUT_GROUND + hh + 0.2, pz), ("Grass", (0.45, 0.60, 0.25)), CanCollide=False, CanQuery=False, CastShadow=False)

    # (a arte tem um pinheiro em (110, 337): nada nasce a menos de 14 studs dele)
    ART_TREE = (110, 337)

    def free(x, z, r=8):
        if math.hypot(x - ART_TREE[0], z - ART_TREE[1]) < 14:
            return False
        if abs(x - CX) < 6 and z > 300:  # caminho + riacho
            return False
        if abs(x - CX) < VEIL_W / 2 + 14 and z > POOL_Z - 16:  # lago
            return False
        return True

    palms = [(CX - 26, 372), (CX + 26, 372), (CX - 42, 362), (CX + 44, 360), (CX - 58, 372), (CX + 60, 370), (CX - 30, 322), (CX + 34, 318), (CX - 66, 340), (CX + 68, 336)]
    for x, z in palms:
        if free(x, z):
            palm(x, z, rng.uniform(14, 21))
    cedars = [(CX - 50, 348), (CX + 52, 346), (CX - 70, 318), (CX + 72, 314), (CX - 20, 304), (CX + 22, 302), (CX - 60, 300), (CX + 62, 298)]
    for x, z in cedars:
        if free(x, z):
            cedar(x, z, rng.uniform(16, 24))
    for i in range(14):
        x, z = rng.uniform(GX0 + 6, GX1 - 6), rng.uniform(GZ0 + 4, GZ1 - 6)
        if free(x, z):
            tamarisk(x, z)
    for i in range(16):
        a = rng.uniform(0.1, math.pi - 0.1)
        r = rng.uniform(VEIL_W / 2 + 12, VEIL_W / 2 + 18)
        papyrus(CX + math.cos(a) * r, POOL_Z + 6 - math.sin(a) * r * 0.55)
    for i in range(6):
        papyrus(CX + (-9 if i % 2 else 9) + jitter(2), POOL_Z - 16 - i * 9)
    for i in range(40):
        x, z = rng.uniform(GX0, GX1), rng.uniform(GZ0, GZ1)
        if free(x, z):
            ball(f"GardenFlower{i}", rng.uniform(0.35, 0.6), (x, OUT_GROUND + 0.45, z), FLOWER[i % 3], CanCollide=False, CanQuery=False, CastShadow=False)
    for i in range(18):
        x, z = rng.uniform(GX0, GX1), rng.uniform(GZ0, GZ1)
        if free(x, z):
            part(f"GardenMoss{i}", (rng.uniform(2, 5), 0.15, rng.uniform(2, 5)), (x, OUT_GROUND + 0.16, z), MOSS, rot=(0, rng.uniform(0, 360), 0), CanCollide=False, CanQuery=False, CastShadow=False)
    # ruínas de tijolo cru com azulejos de lápis (sobras de um templo antigo) e um pedestal com braseiro de cada lado
    for sx, name in ((-1, "W"), (1, "E")):
        x = CX + sx * 44
        z = 330
        for r in range(4):
            ln = 12 - r * 1.5
            part(f"GardenRuin{name}{r}", (ln, 1.6, 2.2), (x + sx * (12 - ln) / 2, OUT_GROUND + 0.8 + r * 1.6, z), BRICK, rot=(0, sx * 25, 0))
        part(f"GardenRuinTile{name}", (6, 0.8, 2.3), (x - sx * 2, OUT_GROUND + 3.9, z), LAPIS, rot=(0, sx * 25, 0))
        cylinder(f"GardenRuinCol{name}", 1.2, 7, (x - sx * 9, OUT_GROUND + 3.5, z + 6), SAND)
        part(f"GardenRuinCap{name}", (3.2, 0.8, 3.2), (x - sx * 9, OUT_GROUND + 7.4, z + 6), SAND_DARK)
        # pedestal-zigurate com braseiro na beira do lago
        px, pz = CX + sx * (VEIL_W / 2 + 20), POOL_Z + 2
        yy = OUT_GROUND
        for t, w in enumerate((8, 6, 4)):
            part(f"GardenPedestal{name}{t}", (w, 1.4, w), (px, yy + 0.7, pz), SAND if t % 2 == 0 else SAND_DARK)
            yy += 1.4
        bowl = cylinder(f"GardenBrazier{name}", 1.5, 1.0, (px, yy + 0.5, pz), IRON)
        fire(bowl, (1.0, 0.5, 0.15), 1.6, 26)
        light(bowl, (1.0, 0.6, 0.3), 2.0, 30)
    # vaga-lumes de noite (partículas suaves) sobre o jardim
    glow = part("GardenFireflies", (120, 1, 60), (CX, OUT_GROUND + 4, 336), SAND, Transparency=1, CanCollide=False, CanQuery=False, CastShadow=False)
    emitter(glow, "Fireflies", (1.0, 0.95, 0.5), 0.25, 0.1, 5, (4, 7), (0.4, 1.2), 180, {"LightEmission": 1})
