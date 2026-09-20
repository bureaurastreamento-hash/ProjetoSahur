"""
arena_construcoes.py — CONSTRUÇÕES DESTRUTÍVEIS (estilo Jujutsu Shenanigans) nas 2 áreas vazias do mapa
(usado por gerar_arena.py; vai para ArenaExtras.Destructible).

Dono (2026-09-21): casas/muros/zigurate de tijolo cru mesopotâmico montados TIJOLO A TIJOLO — cada tijolo é
uma peça ancorada; o DestructionService solta o que um ataque acerta (voa, some, volta depois). Nada aqui
cerca lugar útil (lojinha, altar, taberna): SE = x 40..180, z 165..290 (onde ficava o santuário antigo) e
NW = x -180..-40, z -290..-165 (o lado oposto).
"""

import math

BRICK = ("Brick", (0.68, 0.52, 0.36))
BRICK_DARK = ("Brick", (0.58, 0.43, 0.29))
BRICK_PALE = ("Sandstone", (0.76, 0.64, 0.46))
PLASTER = ("Sandstone", (0.82, 0.74, 0.58))
LAPIS = ("SmoothPlastic", (0.13, 0.24, 0.63))
GOLD = ("Metal", (0.84, 0.69, 0.30))
WOOD = ("Wood", (0.45, 0.31, 0.19))
PLANKS = ("WoodPlanks", (0.55, 0.40, 0.25))
REED_ROOF = ("Fabric", (0.66, 0.56, 0.32))
CLAY = ("Slate", (0.59, 0.39, 0.27))
AWNING = [("Fabric", (0.62, 0.22, 0.20)), ("Fabric", (0.22, 0.34, 0.60)), ("Fabric", (0.80, 0.66, 0.26))]

BW, BH, BT = 4.0, 2.0, 2.4  # tijolo: largura, altura, espessura


def ground(z):
    """Topo do chão do mapa importado: Tiles (y 0) até |z| 190; fora disso o Ground do canto (y -0,87)."""
    return 0.0 if abs(z) <= 190 else -0.87


def build(ctx):
    part, cylinder, ball, wedge, rng, jitter = ctx["part"], ctx["cylinder"], ctx["ball"], ctx["wedge"], ctx["rng"], ctx["jitter"]
    counter = [0]
    base_y = [0.0]  # cota do chão da estrutura em montagem (ver ground())

    def nm(prefix):
        counter[0] += 1
        return f"{prefix}{counter[0]}"

    def brick(pos, size, mat, rot=None):
        return part(nm("Brick"), size, (pos[0], pos[1] + base_y[0], pos[2]), mat, rot=rot)

    def at(z):
        base_y[0] = ground(z)

    def wall(x0, z0, x1, z1, height, y0=0.0, openings=(), mat_a=BRICK, mat_b=BRICK_DARK):
        """Parede de tijolos entre (x0,z0) e (x1,z1). openings = [(t0, t1, h0, h1)] em studs ao longo da parede."""
        dx, dz = x1 - x0, z1 - z0
        length = math.hypot(dx, dz)
        ux, uz = dx / length, dz / length
        yaw = math.degrees(math.atan2(-uz, ux))
        rows = int(round(height / BH))
        for r in range(rows):
            y = y0 + BH / 2 + r * BH
            off = (BW / 2) if r % 2 else 0.0
            t = -off
            while t < length:
                w = min(BW, length - t)
                if t < 0:
                    w = BW + t
                    t = 0
                if w <= 0.5:
                    t += BW
                    continue
                tc = t + w / 2
                skip = False
                for (o0, o1, h0, h1) in openings:
                    if tc > o0 and tc < o1 and y - BH / 2 >= h0 - 0.01 and y + BH / 2 <= h1 + 0.01:
                        skip = True
                        break
                if not skip:
                    brick((x0 + ux * tc, y, z0 + uz * tc), (w - 0.15, BH - 0.1, BT), mat_a if (r + int(t // BW)) % 3 else mat_b, rot=(0, yaw, 0))
                t += BW

    def house(cx, cz, w, d, h, yaw=0.0, door_side=0, awning=None):
        """Casa de tijolo cru com terraço plano (lajes de madeira também destrutíveis), porta e janelas."""
        yr = math.radians(yaw)

        def rot2(x, z):
            return (cx + x * math.cos(yr) - z * math.sin(yr), cz + x * math.sin(yr) + z * math.cos(yr))

        corners = [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)]
        for i in range(4):
            a, b = corners[i], corners[(i + 1) % 4]
            ln = math.hypot(b[0] - a[0], b[1] - a[1])
            ops = []
            if i == door_side:
                ops.append((ln / 2 - 3, ln / 2 + 3, 0, 8))
            if i != door_side and ln >= 12:
                ops.append((ln / 2 - 2, ln / 2 + 2, 4, 8))
            ax, az = rot2(*a)
            bx, bz = rot2(*b)
            wall(ax, az, bx, bz, h, openings=ops)
        # lajes do terraço (vigas + tábuas) e mureta
        nx = max(1, int(w // 5))
        nz = max(1, int(d // 5))
        for ix in range(nx):
            for iz in range(nz):
                px, pz = rot2(-w / 2 + (ix + 0.5) * w / nx, -d / 2 + (iz + 0.5) * d / nz)
                brick((px, h + 0.35, pz), (w / nx - 0.2, 0.7, d / nz - 0.2), PLANKS, rot=(0, yaw, 0))
        for i in range(4):
            a, b = corners[i], corners[(i + 1) % 4]
            ax, az = rot2(*a)
            bx, bz = rot2(*b)
            wall(ax, az, bx, bz, BH, y0=h + 0.7, mat_a=BRICK_PALE, mat_b=BRICK)
        # escada de madeira encostada no lado oposto da porta
        sx, sz = rot2(0, (d / 2 + 1.2) * (1 if door_side == 0 else -1))
        brick((sx, h / 2 + 0.5, sz), (2.4, h + 1, 0.4), WOOD, rot=(18 * (1 if door_side == 0 else -1), yaw, 0))
        # toldo na frente + vasos
        if awning is not None:
            fx, fz = rot2(0, -d / 2 - 3) if door_side == 0 else rot2(0, d / 2 + 3)
            brick((fx, 8.2, fz), (9, 0.3, 6), AWNING[awning % 3], rot=(0, yaw, 0))
            for s in (-1, 1):
                px, pz = rot2(s * 4, (-d / 2 - 5.5) if door_side == 0 else (d / 2 + 5.5))
                brick((px, 4, pz), (0.5, 8, 0.5), WOOD, rot=(0, yaw, 0))
        for i in range(2):
            px, pz = rot2(-w / 2 - 1.6 if i == 0 else w / 2 + 1.6, rng.uniform(-d / 3, d / 3))
            c = cylinder(nm("Brick"), 1.0, 2.2, (px, 1.1 + base_y[0], pz), CLAY)

    def ziggurat(cx, cz, base, tiers, tier_h=3.6):
        """Zigurate escalonado: cada degrau é um anel de blocos (o miolo é sólido, não destrutível)."""
        for t in range(tiers):
            w = base - t * (base / (tiers + 1))
            y0 = t * tier_h
            inner = w - 2 * BT
            if inner > 2:
                part(nm("ZigCore"), (inner, tier_h - 0.1, inner), (cx, y0 + tier_h / 2 + base_y[0], cz), PLASTER)
            half = w / 2
            pts = [(-half, -half), (half, -half), (half, half), (-half, half)]
            for i in range(4):
                a, b = pts[i], pts[(i + 1) % 4]
                ops = [(w / 2 - 3, w / 2 + 3, 0, tier_h)] if (i == 0 and t < tiers - 1) else ()
                wall(cx + a[0], cz + a[1], cx + b[0], cz + b[1], tier_h, y0=y0, openings=[(o[0], o[1], y0 + o[2], y0 + o[3]) for o in ops],
                     mat_a=BRICK_PALE if t % 2 else BRICK, mat_b=BRICK_DARK)
            # escada frontal de blocos
            steps = int(tier_h // 1.2)
            for s in range(steps):
                brick((cx, y0 + 0.6 + s * 1.2, cz - half - 1.6 + s * 1.0), (5, 1.2, 1.2), BRICK_PALE)
        top = tiers * tier_h
        # santuário no topo: 4 colunas + laje + faixa de lápis
        tw = base - tiers * (base / (tiers + 1))
        for sx in (-1, 1):
            for sz in (-1, 1):
                c = cylinder(nm("Brick"), 0.8, 6, (cx + sx * (tw / 2 - 1.5), top + 3 + base_y[0], cz + sz * (tw / 2 - 1.5)), BRICK_PALE)
        brick((cx, top + 6.5, cz), (tw, 1, tw), BRICK_DARK)
        brick((cx, top + 7.3, cz), (tw + 0.2, 0.6, tw + 0.2), LAPIS)
        part(nm("ZigGold"), (2.4, 0.4, 2.4), (cx, top + 7.8 + base_y[0], cz), GOLD)

    def column(x, z, h):
        brick((x, 0.5, z), (3.4, 1, 3.4), BRICK_DARK)
        segs = int(h // 3)
        for s in range(segs):
            c = cylinder(nm("Brick"), 1.2, 3 - 0.1, (x, 1 + 1.5 + s * 3 + base_y[0], z), BRICK_PALE if s % 2 else BRICK)
        brick((x, 1 + segs * 3 + 0.4, z), (3.4, 0.8, 3.4), BRICK_DARK)

    def market_stall(x, z, yaw, color):
        yr = math.radians(yaw)

        def r2(a, b):
            return (x + a * math.cos(yr) - b * math.sin(yr), z + a * math.sin(yr) + b * math.cos(yr))

        ax, az = r2(-6, 0)
        bx, bz = r2(6, 0)
        wall(ax, az, bx, bz, 3, mat_a=BRICK_PALE)
        brick((x, 3.3, z), (12.4, 0.5, 3.2), PLANKS, rot=(0, yaw, 0))
        for s in (-1, 1):
            px, pz = r2(s * 5.5, 1.2)
            brick((px, 4.8, pz), (0.5, 9, 0.5), WOOD, rot=(0, yaw, 0))
        brick((x, 9.3, z + 0), (13.4, 0.3, 8), AWNING[color % 3], rot=(8, yaw, 0))
        for i in range(3):
            gx, gz = r2(rng.uniform(-4, 4), rng.uniform(-0.8, 0.8))
            brick((gx, 4.2, gz), (rng.uniform(1.2, 2.2), 1.2, 1.4), AWNING[(color + i) % 3])

    def rubble(cx, cz, radius, n):
        for i in range(n):
            a = rng.uniform(0, math.tau)
            r = rng.uniform(0, radius)
            brick((cx + math.cos(a) * r, 0.7, cz + math.sin(a) * r), (rng.uniform(1.5, 3.5), rng.uniform(0.8, 1.6), rng.uniform(1.5, 3)), BRICK if i % 2 else BRICK_DARK,
                  rot=(rng.uniform(-10, 10), rng.uniform(0, 360), rng.uniform(-10, 10)))

    def district(sign):
        """sign = +1 (SE: x 40..180, z 165..290) | -1 (NW espelhado)."""
        def P(x, z):
            return (sign * x, sign * z)

        # zigurate no meio do bairro
        zx, zz = P(110, 232)
        at(zz)
        ziggurat(zx, zz, 34, 3)
        # casas em volta (tamanhos e giros diferentes)
        houses = [
            (60, 182, 16, 12, 8, 0, 0), (88, 180, 20, 14, 10, 12, 0), (130, 178, 14, 12, 8, -8, 2),
            (160, 200, 18, 14, 10, 90, 1), (162, 240, 16, 12, 8, 80, 3), (150, 272, 20, 16, 10, 178, 0),
            (110, 278, 14, 12, 8, 0, 2), (72, 268, 18, 14, 12, 20, 1), (54, 232, 16, 14, 8, -95, 3),
        ]
        for (x, z, w, d, h, yaw, door) in houses:
            hx, hz = P(x, z)
            at(hz)
            house(hx, hz, w, d, h, yaw=yaw if sign > 0 else yaw + 180, door_side=door, awning=door)
        # rua do mercado (barracas) entre as casas e o zigurate
        for i, (x, z, yaw) in enumerate(((80, 210, 0), (96, 208, 0), (142, 210, 0), (80, 255, 180), (96, 257, 180), (142, 254, 180))):
            mx, mz = P(x, z)
            at(mz)
            market_stall(mx, mz, yaw if sign > 0 else yaw + 180, i)
        # colunata quebrada e muro baixo na borda
        for i, (x, z) in enumerate(((66, 214), (66, 226), (66, 238), (66, 250))):
            cx_, cz_ = P(x, z)
            at(cz_)
            column(cx_, cz_, 9 if i % 2 else 12)
        a = P(48, 170)
        b = P(48, 188)
        at(a[1])
        wall(a[0], a[1], b[0], b[1], 4)
        a = P(48, 192)
        b = P(48, 290)
        at(b[1])
        wall(a[0], a[1], b[0], b[1], 4, openings=[(28, 44, 0, 4)])
        at(250 * sign)
        rubble(*P(130, 250), 10, 10)
        at(200 * sign)
        rubble(*P(70, 200), 8, 8)
        # jarros e caixotes soltos
        for i in range(12):
            x, z = P(rng.uniform(50, 175), rng.uniform(170, 288))
            if math.hypot(x - zx, z - zz) < 24:
                continue
            at(z)
            if i % 2:
                cylinder(nm("Brick"), 1.1, 2.4, (x, 1.2 + base_y[0], z), CLAY)
            else:
                s = rng.uniform(2, 3)
                brick((x, s / 2, z), (s, s, s), PLANKS, rot=(0, rng.uniform(0, 90), 0))

    district(1)
    district(-1)
    return counter[0]
