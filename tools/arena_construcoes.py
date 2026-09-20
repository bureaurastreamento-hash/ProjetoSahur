"""
arena_construcoes.py — CONSTRUÇÕES DESTRUTÍVEIS (estilo Jujutsu Shenanigans) nas 2 áreas vazias do mapa
(usado por gerar_arena.py; vai para ArenaExtras.Destructible).

Dono (2026-09-21): casas/muros/zigurate de tijolo cru mesopotâmico montados TIJOLO A TIJOLO — cada tijolo é
uma peça ancorada; o DestructionService solta o que um ataque acerta (voa, some, volta depois). Nada aqui
cerca lugar útil (lojinha, altar, taberna): SE = x 40..180, z 165..290 (onde ficava o santuário antigo) e
NW = x -180..-40, z -290..-165 (o lado oposto).

v2 (dono, 2026-09-21 → feito 2026-09-22): construções MAIORES e "enteráveis" — tijolo 6×3×3 (mesmo volume
de peças, dobro de tamanho), casas de 2 andares (pé-direito 11) com interior (laje do 1º andar em chunks
destrutíveis, escada interna, mesa/vasos), portas 6×9 e janelas largas, escada externa até o terraço, pátios
murados, mercado coberto e o zigurate com CÂMARA interna e RAMPA até o topo (luta em altura).
Desabamento (tijolo sem apoio cai) e golpe pesado (2× tijolos) ficam no DestructionService.
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

BW, BH, BT = 6.0, 3.0, 3.0  # tijolo: largura, altura, espessura (v2: dobro do volume)


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

    def house(cx, cz, w, d, h, yaw=0.0, door_side=0, awning=None, floors=2):
        """Casa de tijolo cru com `floors` andares (pé-direito h cada), interior (laje em chunks, escada interna,
        mesa, vasos), porta 6×9, janelas largas, terraço com mureta e escada externa. Tudo destrutível."""
        yr = math.radians(yaw)

        def rot2(x, z):
            return (cx + x * math.cos(yr) - z * math.sin(yr), cz + x * math.sin(yr) + z * math.cos(yr))

        total_h = h * floors
        corners = [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)]
        for i in range(4):
            a, b = corners[i], corners[(i + 1) % 4]
            ln = math.hypot(b[0] - a[0], b[1] - a[1])
            ops = []
            if i == door_side:
                ops.append((ln / 2 - 3, ln / 2 + 3, 0, 9))  # porta 6×9
            for f in range(floors):
                y0 = f * h
                if (i != door_side or f > 0) and ln >= 14:
                    ops.append((ln / 2 - 3.5, ln / 2 + 3.5, y0 + 3, y0 + 9))  # janela larga 7×6
                if ln >= 24:
                    ops.append((4, 9, y0 + 3, y0 + 9))
                    ops.append((ln - 9, ln - 4, y0 + 3, y0 + 9))
            ax, az = rot2(*a)
            bx, bz = rot2(*b)
            wall(ax, az, bx, bz, total_h, openings=ops)
        # lajes de cada andar (chunks de tábua também destrutíveis) — com vão para a escada interna
        nx = max(2, int(w // 8))
        nz = max(2, int(d // 7))
        for f in range(1, floors + 1):
            fy = f * h
            for ix in range(nx):
                for iz in range(nz):
                    if f < floors and ix == nx - 1 and iz == nz - 1:
                        continue  # vão da escada interna
                    px, pz = rot2(-w / 2 + (ix + 0.5) * w / nx, -d / 2 + (iz + 0.5) * d / nz)
                    brick((px, fy + 0.35, pz), (w / nx - 0.2, 0.7, d / nz - 0.2), PLANKS, rot=(0, yaw, 0))
            if f < floors:
                # escada interna: rampa de tábuas subindo até o vão (canto +x,+z)
                sx0, sz0 = rot2(w / 2 - w / nx / 2, d / 2 - d / nz - 4)
                brick((sx0, fy / 2 + (f - 1) * h + 0.2, sz0), (2.6, 0.5, math.hypot(h, 8) + 0.5), WOOD, rot=(math.degrees(math.atan2(h, 8)), yaw, 0))
        # mureta do terraço + escada externa encostada no lado oposto da porta
        for i in range(4):
            a, b = corners[i], corners[(i + 1) % 4]
            ax, az = rot2(*a)
            bx, bz = rot2(*b)
            wall(ax, az, bx, bz, BH, y0=total_h + 0.7, mat_a=BRICK_PALE, mat_b=BRICK)
        back = (1 if door_side == 0 else -1)
        steps = int(total_h // 1.5)
        for k in range(steps):
            px, pz = rot2(-w / 2 + 2, back * (d / 2 + 1.6 + (steps - 1 - k) * 0.9))
            brick((px, 0.75 + k * 1.5, pz), (3.6, 1.5, 1.6), WOOD if k % 2 else PLANKS, rot=(0, yaw, 0))
        # interior: mesa + bancos no térreo, jarros; toldo e vasos na frente
        tx, tz = rot2(-w / 4, 0)
        brick((tx, 2.6, tz), (5, 0.5, 2.6), PLANKS, rot=(0, yaw, 0))
        for s_ in (-1, 1):
            lx, lz = rot2(-w / 4 + s_ * 2, 0)
            brick((lx, 1.25, lz), (0.6, 2.5, 0.6), WOOD, rot=(0, yaw, 0))
        for i in range(2):
            px, pz = rot2(w / 4 + jitter(1.5), -d / 4 + i * d / 2)
            cylinder(nm("Brick"), 1.0, 2.2, (px, 1.1 + base_y[0], pz), CLAY)
        if awning is not None:
            fx, fz = rot2(0, -d / 2 - 3) if door_side == 0 else rot2(0, d / 2 + 3)
            brick((fx, 9.4, fz), (10, 0.3, 6), AWNING[awning % 3], rot=(0, yaw, 0))
            for s_ in (-1, 1):
                px, pz = rot2(s_ * 4.5, (-d / 2 - 5.5) if door_side == 0 else (d / 2 + 5.5))
                brick((px, 4.6, pz), (0.5, 9.2, 0.5), WOOD, rot=(0, yaw, 0))
        for i in range(2):
            px, pz = rot2(-w / 2 - 1.8 if i == 0 else w / 2 + 1.8, rng.uniform(-d / 3, d / 3))
            cylinder(nm("Brick"), 1.0, 2.2, (px, 1.1 + base_y[0], pz), CLAY)

    def courtyard(cx, cz, w, d, yaw=0.0, gate_side=0):
        """Pátio murado (muro de 2 fiadas com portão) em volta de uma casa."""
        yr = math.radians(yaw)

        def rot2(x, z):
            return (cx + x * math.cos(yr) - z * math.sin(yr), cz + x * math.sin(yr) + z * math.cos(yr))

        corners = [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)]
        for i in range(4):
            a, b = corners[i], corners[(i + 1) % 4]
            ln = math.hypot(b[0] - a[0], b[1] - a[1])
            ops = [(ln / 2 - 4, ln / 2 + 4, 0, 6)] if i == gate_side else []
            ax, az = rot2(*a)
            bx, bz = rot2(*b)
            wall(ax, az, bx, bz, BH * 2, openings=ops, mat_a=BRICK_PALE, mat_b=BRICK)
        for (x, z) in corners:  # pilaretes nos cantos
            px, pz = rot2(x, z)
            brick((px, BH + 0.6, pz), (BT + 0.6, BH * 2 + 1.2, BT + 0.6), BRICK_DARK, rot=(0, yaw, 0))

    def covered_market(cx, cz, w, d, yaw=0.0):
        """Mercado coberto: colunas de tijolo + telhado de junco em duas águas (destrutível em chunks)."""
        yr = math.radians(yaw)

        def rot2(x, z):
            return (cx + x * math.cos(yr) - z * math.sin(yr), cz + x * math.sin(yr) + z * math.cos(yr))

        ncol = max(2, int(w // 12) + 1)
        for i in range(ncol):
            for sz in (-1, 1):
                px, pz = rot2(-w / 2 + i * w / (ncol - 1), sz * d / 2)
                column(px, pz, 12)
        # cumeeira + duas águas em chunks
        rx, rz = rot2(0, 0)
        brick((rx, 13.6, rz), (w + 2, 0.8, 1.2), WOOD, rot=(0, yaw, 0))
        nx = max(2, int(w // 6))
        for sz in (-1, 1):
            for ix in range(nx):
                px, pz = rot2(-w / 2 + (ix + 0.5) * w / nx, sz * d / 4)
                brick((px, 13.2 - 0.9, pz), (w / nx - 0.2, 0.4, d / 2 + 1.5), REED_ROOF, rot=(sz * -22, yaw, 0))

    def ziggurat(cx, cz, base, tiers, tier_h=5.0):
        """Zigurate escalonado com CÂMARA interna no 1º degrau (pilares, portas nas 4 faces) e RAMPA de tábuas
        subindo em volta até o santuário no topo (área de luta em altura). Degraus de cima têm miolo sólido."""
        for t in range(tiers):
            w = base - t * (base / (tiers + 1))
            y0 = t * tier_h
            inner = w - 2 * BT
            if t == 0:
                # câmara: piso de lápis, 4 pilares, laje do teto em chunks (destrutível)
                part(nm("ZigCore"), (inner, 0.4, inner), (cx, y0 + 0.2 + base_y[0], cz), LAPIS)
                for sx in (-1, 1):
                    for sz in (-1, 1):
                        brick((cx + sx * inner / 4, y0 + tier_h / 2, cz + sz * inner / 4), (2.2, tier_h - 0.2, 2.2), BRICK_DARK)
                n = max(2, int(inner // 6))
                for ix in range(n):
                    for iz in range(n):
                        brick((cx - inner / 2 + (ix + 0.5) * inner / n, y0 + tier_h - 0.4, cz - inner / 2 + (iz + 0.5) * inner / n), (inner / n - 0.2, 0.8, inner / n - 0.2), PLANKS)
            elif inner > 2:
                part(nm("ZigCore"), (inner, tier_h - 0.1, inner), (cx, y0 + tier_h / 2 + base_y[0], cz), PLASTER)
            half = w / 2
            pts = [(-half, -half), (half, -half), (half, half), (-half, half)]
            for i in range(4):
                a, b = pts[i], pts[(i + 1) % 4]
                ops = [(w / 2 - 3, w / 2 + 3, 0, min(tier_h, 9))] if t == 0 else ()
                wall(cx + a[0], cz + a[1], cx + b[0], cz + b[1], tier_h, y0=y0, openings=[(o[0], o[1], y0 + o[2], y0 + o[3]) for o in ops],
                     mat_a=BRICK_PALE if t % 2 else BRICK, mat_b=BRICK_DARK)
        top = tiers * tier_h
        # rampa de tábuas: um lance por degrau, cada um numa face (sobe em espiral)
        for t in range(tiers):
            w = base - t * (base / (tiers + 1))
            half = w / 2
            y0 = t * tier_h
            face = t % 4
            ln = math.hypot(tier_h, half * 1.6)
            ang = math.degrees(math.atan2(tier_h, half * 1.6))
            if face == 0:
                pos, rot = (cx - half * 0.2, y0 + tier_h / 2, cz - half - 1.8), (0, 0, ang)
            elif face == 1:
                pos, rot = (cx + half + 1.8, y0 + tier_h / 2, cz - half * 0.2), (-ang, 0, 0)
            elif face == 2:
                pos, rot = (cx + half * 0.2, y0 + tier_h / 2, cz + half + 1.8), (0, 0, -ang)
            else:
                pos, rot = (cx - half - 1.8, y0 + tier_h / 2, cz + half * 0.2), (ang, 0, 0)
            segs = max(2, int(ln // 6))
            for k in range(segs):
                f = (k + 0.5) / segs - 0.5
                dx = f * ln * math.cos(math.radians(ang))
                dy = f * tier_h
                if face in (0, 2):
                    p_ = (pos[0] + dx * (1 if face == 0 else -1), pos[1] + dy, pos[2])
                else:
                    p_ = (pos[0], pos[1] + dy, pos[2] + dx * (1 if face == 1 else -1))
                brick(p_, (ln / segs + 0.3, 0.5, 3.4) if face in (0, 2) else (3.4, 0.5, ln / segs + 0.3), PLANKS, rot=rot)
        # santuário no topo: 4 colunas + laje + faixa de lápis (arena em altura)
        tw = base - tiers * (base / (tiers + 1))
        for sx in (-1, 1):
            for sz in (-1, 1):
                c = cylinder(nm("Brick"), 0.9, 7, (cx + sx * (tw / 2 - 1.5), top + 3.5 + base_y[0], cz + sz * (tw / 2 - 1.5)), BRICK_PALE)
        brick((cx, top + 7.5, cz), (tw, 1, tw), BRICK_DARK)
        brick((cx, top + 8.3, cz), (tw + 0.2, 0.6, tw + 0.2), LAPIS)
        part(nm("ZigGold"), (2.4, 0.4, 2.4), (cx, top + 8.8 + base_y[0], cz), GOLD)

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

        # zigurate no meio do bairro (maior, com câmara e rampa)
        zx, zz = P(110, 232)
        at(zz)
        ziggurat(zx, zz, 44, 3)
        # casas em volta (2 andares; tamanhos e giros diferentes), duas com pátio murado
        houses = [
            (60, 182, 20, 14, 11, 0, 0, None), (92, 180, 26, 16, 11, 10, 0, None), (140, 178, 18, 14, 11, -8, 2, None),
            (162, 214, 22, 16, 11, 90, 1, (34, 30)), (150, 274, 26, 18, 11, 178, 0, None),
            (110, 280, 18, 14, 11, 0, 2, None), (70, 266, 24, 16, 11, 20, 1, (38, 30)),
        ]
        for (x, z, w, d, h, yaw, door, yard) in houses:
            hx, hz = P(x, z)
            at(hz)
            yw = yaw if sign > 0 else yaw + 180
            house(hx, hz, w, d, h, yaw=yw, door_side=door, awning=door)
            if yard:
                courtyard(hx, hz, yard[0], yard[1], yaw=yw, gate_side=door)
        # rua do mercado: barracas + um mercado COBERTO ao norte do zigurate
        for i, (x, z, yaw) in enumerate(((80, 208, 0), (142, 208, 0), (80, 257, 180), (142, 257, 180))):
            mx, mz = P(x, z)
            at(mz)
            market_stall(mx, mz, yaw if sign > 0 else yaw + 180, i)
        mx, mz = P(110, 200)
        at(mz)
        covered_market(mx, mz, 30, 14, yaw=0)
        for i, (x, z, yaw) in enumerate(((100, 200, 0), (120, 200, 0))):
            sx_, sz_ = P(x, z)
            at(sz_)
            market_stall(sx_, sz_, yaw if sign > 0 else yaw + 180, i + 1)
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
