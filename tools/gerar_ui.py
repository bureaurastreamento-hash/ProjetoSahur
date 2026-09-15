#!/usr/bin/env python3
"""
Gera as telas do jogo em src/ui/ (HUD, CharacterSelect, ProfileGui, HelpGui, ShopGui) com uma
linguagem visual única e minimalista: painéis escuros translúcidos, borda fina, sem enfeite.
Uso: python3 tools/gerar_ui.py
Os controllers ligam os elementos PELO NOME — se renomear algo aqui, ajuste o controller.
"""

import json
from pathlib import Path

UI = Path(__file__).resolve().parent.parent / "src" / "ui"

# ---- tokens -----------------------------------------------------------------
BG = [0.05, 0.05, 0.06]          # painéis
BG_T = 0.25                      # transparência dos painéis
CARD = [0.10, 0.10, 0.12]        # cartões/slots
LINE = [1, 1, 1]                 # borda (com transparência)
LINE_T = 0.86
TEXT = [0.96, 0.96, 0.97]
MUTED = [0.62, 0.62, 0.68]
ACCENT = [0.35, 0.75, 1.0]       # energia / seleção
HEALTH = [0.90, 0.27, 0.27]
GOLD = [1.0, 0.80, 0.30]
GREEN = [0.35, 0.80, 0.50]
FONT = "GothamMedium"
FONT_B = "GothamBold"


def ud(sx, ox, sy, oy):
    return {"UDim2": [[sx, ox], [sy, oy]]}


def col(c):
    return {"Color3": c}


def node(name, cls, props=None, children=None):
    p = {"Name": name}
    p.update(props or {})
    n = {"name": name, "className": cls, "properties": p}
    if children:
        n["children"] = children
    return n


def corner(r=6):
    return node("UICorner", "UICorner", {"CornerRadius": {"UDim": [0, r]}})


def stroke(t=LINE_T, thick=1, color=LINE):
    return node("UIStroke", "UIStroke", {"Thickness": thick, "Color": col(color), "Transparency": t,
                                          "ApplyStrokeMode": "Border"})


def padding(px=12, py=None):
    py = px if py is None else py
    return node("UIPadding", "UIPadding", {"PaddingLeft": {"UDim": [0, px]}, "PaddingRight": {"UDim": [0, px]},
                                            "PaddingTop": {"UDim": [0, py]}, "PaddingBottom": {"UDim": [0, py]}})


def listlayout(direction="Vertical", pad=6, halign="Left", valign="Top", sort="LayoutOrder"):
    return node("UIListLayout", "UIListLayout", {"FillDirection": direction, "Padding": {"UDim": [0, pad]},
                                                  "HorizontalAlignment": halign, "VerticalAlignment": valign,
                                                  "SortOrder": sort})


def frame(name, size, pos, anchor=(0, 0), bg=BG, t=BG_T, children=None, visible=True, extra=None):
    props = {"Size": size, "Position": pos, "AnchorPoint": {"Vector2": list(anchor)}, "BackgroundColor3": col(bg),
             "BackgroundTransparency": t, "BorderSizePixel": 0, "Visible": visible}
    props.update(extra or {})
    return node(name, "Frame", props, children)


def label(name, text, size, pos, anchor=(0, 0), font=FONT, ts=14, color=TEXT, xalign="Left", yalign="Center",
          extra=None, children=None, rich=False):
    props = {"Size": size, "Position": pos, "AnchorPoint": {"Vector2": list(anchor)}, "BackgroundTransparency": 1,
             "Text": text, "Font": font, "TextSize": ts, "TextColor3": col(color), "TextXAlignment": xalign,
             "TextYAlignment": yalign, "BorderSizePixel": 0, "RichText": rich}
    props.update(extra or {})
    return node(name, "TextLabel", props, children)


def button(name, text, size, pos, anchor=(0, 0), bg=CARD, t=0.0, font=FONT_B, ts=14, color=TEXT, children=None,
           extra=None):
    props = {"Size": size, "Position": pos, "AnchorPoint": {"Vector2": list(anchor)}, "BackgroundColor3": col(bg),
             "BackgroundTransparency": t, "Text": text, "Font": font, "TextSize": ts, "TextColor3": col(color),
             "AutoButtonColor": True, "BorderSizePixel": 0}
    props.update(extra or {})
    ch = [corner(), stroke()] + (children or [])
    return node(name, "TextButton", props, ch)


def screen(name, children, order=1, enabled=True, ignore_inset=True):
    return {"className": "ScreenGui", "properties": {"ResetOnSpawn": False, "IgnoreGuiInset": ignore_inset,
                                                      "ZIndexBehavior": "Sibling", "DisplayOrder": order,
                                                      "Enabled": enabled},
            "children": children}


def panel(name, w, h, title, children, hidden=True):
    """Painel central padrão (aberto pelo TopbarPlus): título em caixa alta + conteúdo."""
    return frame(name, ud(0, w, 0, h), ud(0.5, 0, 0.5, 0), anchor=(0.5, 0.5), visible=not hidden, children=[
        corner(8), stroke(), padding(16),
        label("Title", title.upper(), ud(1, 0, 0, 22), ud(0, 0, 0, 0), font=FONT_B, ts=16, color=MUTED),
    ] + children)


def write(fname, data):
    (UI / fname).write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n")
    print(UI / fname)


# =============================================================================
# HUD
# =============================================================================
SLOT = 64
SLOT_KEYS = ["E", "R", "T"]  # habilidades; o Q é o dash universal (frame "Dash", igual mas fixo)


def slot(i, name=None, key=None, ult=None):
    key = key or SLOT_KEYS[i - 1]
    ult = (i == 3) if ult is None else ult
    return frame(name or f"Slot{i}", ud(0, SLOT, 0, SLOT), ud(0, 0, 0, 0), bg=CARD, t=0.15, extra={"LayoutOrder": i,
                 "ClipsDescendants": True}, children=[
        corner(6), stroke(0.8 if not ult else 0.5, 1, LINE if not ult else GOLD),
        label("Key", key, ud(0, 24, 0, 20), ud(0, 6, 0, 4), font=FONT_B, ts=16, color=TEXT if not ult else GOLD),
        label("Cost", "", ud(0, 40, 0, 14), ud(1, -5, 0, 6), anchor=(1, 0), font=FONT_B, ts=10, color=GOLD,
              xalign="Right"),
        label("Name", "", ud(1, -8, 0, 26), ud(0.5, 0, 1, -4), anchor=(0.5, 1), ts=10, color=MUTED, xalign="Center",
              yalign="Bottom", extra={"TextWrapped": True}),
        frame("Cooldown", ud(1, 0, 0, 0), ud(0, 0, 1, 0), anchor=(0, 1), bg=[0, 0, 0], t=0.4, extra={"ZIndex": 2}),
        label("CooldownText", "", ud(1, 0, 1, 0), ud(0, 0, 0, 0), font=FONT_B, ts=20, xalign="Center",
              extra={"ZIndex": 3, "TextStrokeTransparency": 0.5}),
    ])


hud = screen("HUD", [
    # Estado/timer do round (só fora do mapa livre; HUDController esconde no FreeRoam)
    frame("TopBar", ud(0, 320, 0, 34), ud(0.5, 0, 0, 10), anchor=(0.5, 0), children=[
        corner(6), stroke(),
        label("State", "", ud(0.7, 0, 1, 0), ud(0, 12, 0, 0), font=FONT_B, ts=14),
        label("Timer", "", ud(0.3, -12, 1, 0), ud(1, -12, 0, 0), anchor=(1, 0), font=FONT_B, ts=16, xalign="Right"),
    ]),
    # Moedas no canto superior direito
    label("Coins", "", ud(0, 200, 0, 24), ud(1, -16, 0, 12), anchor=(1, 0), font=FONT_B, ts=15, color=GOLD,
          xalign="Right", extra={"TextStrokeTransparency": 0.7}),
    # Killfeed abaixo das moedas
    frame("KillFeed", ud(0, 300, 0, 140), ud(1, -16, 0, 44), anchor=(1, 0), t=1, children=[
        listlayout("Vertical", 2, "Right"),
        label("Template", "", ud(1, 0, 0, 18), ud(0, 0, 0, 0), ts=12, color=MUTED, xalign="Right",
              extra={"Visible": False, "TextStrokeTransparency": 0.7}),
    ]),
    # Vida/energia + nome do personagem, embaixo no centro
    frame("Vitals", ud(0, 400, 0, 56), ud(0.5, 0, 1, -112), anchor=(0.5, 1), t=1, children=[
        label("CharacterName", "", ud(0.6, 0, 0, 16), ud(0, 0, 0, 0), font=FONT_B, ts=12, color=MUTED),
        frame("Health", ud(1, 0, 0, 14), ud(0, 0, 0, 20), bg=[0, 0, 0], t=0.45, children=[
            corner(3),
            frame("Fill", ud(1, 0, 1, 0), ud(0, 0, 0, 0), bg=HEALTH, t=0, children=[corner(3)]),
            label("Text", "", ud(1, -6, 1, 0), ud(0, 0, 0, 0), font=FONT_B, ts=11, xalign="Right",
                  extra={"TextStrokeTransparency": 0.6, "ZIndex": 2}),
        ]),
        frame("Energy", ud(1, 0, 0, 6), ud(0, 0, 0, 40), bg=[0, 0, 0], t=0.45, children=[
            corner(3),
            frame("Fill", ud(1, 0, 1, 0), ud(0, 0, 0, 0), bg=ACCENT, t=0, children=[corner(3)]),
            label("Text", "", ud(0, 60, 0, 12), ud(1, 0, 1, 2), anchor=(1, 0), font=FONT_B, ts=10, color=MUTED,
                  xalign="Right"),
        ]),
    ]),
    # Habilidades
    frame("Abilities", ud(0, SLOT * 4 + 8 * 3, 0, SLOT), ud(0.5, 0, 1, -32), anchor=(0.5, 1), t=1, children=[
        listlayout("Horizontal", 8, "Center", "Center"),
        slot(0, name="Dash", key="Q", ult=False), slot(1), slot(2), slot(3),
    ]),
    # Placar (Tab)
    frame("Scoreboard", ud(0, 240, 0, 260), ud(1, -16, 0.5, 0), anchor=(1, 0.5), visible=False, children=[
        corner(8), stroke(), padding(14, 12),
        label("Title", "PLACAR", ud(1, 0, 0, 20), ud(0, 0, 0, 0), font=FONT_B, ts=14, color=MUTED),
        frame("List", ud(1, 0, 1, -28), ud(0, 0, 0, 28), t=1, children=[
            listlayout("Vertical", 4),
            label("Template", "", ud(1, 0, 0, 20), ud(0, 0, 0, 0), ts=14, extra={"Visible": False}),
        ]),
    ]),
    # Avisos grandes no centro-alto e contador de combo perto do centro
    label("Banner", "", ud(0, 700, 0, 40), ud(0.5, 0, 0.22, 0), anchor=(0.5, 0.5), font=FONT_B, ts=26,
          xalign="Center", extra={"Visible": False, "TextStrokeTransparency": 0.5}),
    label("Combo", "", ud(0, 80, 0, 30), ud(0.5, 120, 0.5, -40), anchor=(0.5, 0.5), font=FONT_B, ts=22,
          color=GOLD, xalign="Center", extra={"TextStrokeTransparency": 0.5}),
])
write("HUD.model.json", hud)

# =============================================================================
# Seleção de personagem (cartões)
# =============================================================================
CARD_W, CARD_H = 168, 300
PURPLE = [0.70, 0.45, 1.0]
card = button("Template", "", ud(0, CARD_W, 0, CARD_H), ud(0, 0, 0, 0), bg=CARD, t=0.05, extra={"Visible": False,
              "ClipsDescendants": True}, children=[
    # faixa de cor do personagem no topo + retrato (imagem ou inicial)
    frame("Band", ud(1, 0, 0, 4), ud(0, 0, 0, 0), bg=ACCENT, t=0),
    frame("PortraitBox", ud(1, 0, 0, 120), ud(0, 0, 0, 4), bg=[0.08, 0.08, 0.10], t=0, children=[
        node("Portrait", "ImageLabel", {"Size": ud(1, 0, 1, 0), "Position": ud(0, 0, 0, 0), "BackgroundTransparency": 1,
                                        "Image": "", "ScaleType": "Crop", "BorderSizePixel": 0}),
        label("Initial", "", ud(1, 0, 1, 0), ud(0, 0, 0, 0), font=FONT_B, ts=56, color=ACCENT, xalign="Center",
              extra={"TextTransparency": 0.15}),
        node("Glow", "UIGradient", {"Rotation": 90, "Transparency": {"NumberSequence": {"keypoints": [{"time": 0, "value": 0.6, "envelope": 0},
                                                                          {"time": 1, "value": 0, "envelope": 0}]}}}),
    ]),
    # selo: GRÁTIS / 250 MOEDAS / VIP / EM BREVE
    label("Badge", "", ud(0, 0, 0, 18), ud(1, -8, 0, 10), anchor=(1, 0), font=FONT_B, ts=10, color=TEXT,
          xalign="Center", extra={"AutomaticSize": "X", "BackgroundTransparency": 0.15,
                                  "BackgroundColor3": col([0.1, 0.1, 0.12]), "ZIndex": 2},
          children=[corner(4), padding(6, 0)]),
    label("Name", "", ud(1, -20, 0, 22), ud(0, 10, 0, 130), font=FONT_B, ts=16),
    label("Tagline", "", ud(1, -20, 0, 14), ud(0, 10, 0, 150), ts=11, color=MUTED),
    label("Abilities", "", ud(1, -20, 0, 78), ud(0, 10, 0, 170), ts=11, color=MUTED, yalign="Top",
          extra={"TextWrapped": True, "LineHeight": 1.2}),
    # ação embaixo (USAR / SELECIONADO / COMPRAR / VIP / EM BREVE)
    label("Status", "", ud(1, -20, 0, 28), ud(0.5, 0, 1, -10), anchor=(0.5, 1), font=FONT_B, ts=12, color=TEXT,
          xalign="Center", extra={"BackgroundTransparency": 0.85, "BackgroundColor3": col([1, 1, 1])},
          children=[corner(5)]),
])
select = screen("CharacterSelect", [
    panel("Panel", 5 * (CARD_W + 10) + 32 - 10, CARD_H + 100, "Personagens", [
        label("Coins", "", ud(0, 200, 0, 22), ud(1, 0, 0, 0), anchor=(1, 0), font=FONT_B, ts=14, color=GOLD,
              xalign="Right"),
        label("Hint", "", ud(1, 0, 0, 18), ud(0, 0, 0, 26), ts=12, color=MUTED),
        frame("List", ud(1, 0, 0, CARD_H), ud(0, 0, 0, 52), t=1, children=[
            listlayout("Horizontal", 10, "Left"), card,
        ]),
        button("QueueButton", "Entrar na fila", ud(0, 160, 0, 30), ud(0.5, 0, 1, 0), anchor=(0.5, 1), bg=GREEN,
               extra={"Visible": False}),
    ]),
], order=3)
write("CharacterSelect.model.json", select)

# =============================================================================
# Perfil
# =============================================================================
mission_row = label("Template", "", ud(1, 0, 0, 40), ud(0, 0, 0, 0), font=FONT_B, ts=13, yalign="Top",
                    extra={"Visible": False, "TextWrapped": True}, children=[
    label("Progress", "", ud(1, 0, 0, 14), ud(0, 0, 0, 18), ts=11, color=MUTED),
    frame("Bar", ud(1, 0, 0, 3), ud(0, 0, 1, -2), anchor=(0, 1), bg=[0, 0, 0], t=0.5, children=[
        frame("Fill", ud(0, 0, 1, 0), ud(0, 0, 0, 0), bg=GREEN, t=0),
    ]),
])
profile = screen("ProfileGui", [
    panel("Panel", 560, 400, "Perfil", [
        label("Coins", "", ud(0, 200, 0, 22), ud(1, 0, 0, 0), anchor=(1, 0), font=FONT_B, ts=14, color=GOLD,
              xalign="Right"),
        label("Warning", "", ud(1, 0, 0, 16), ud(0, 0, 0, 24), ts=11, color=HEALTH),
        # coluna esquerda: nível, stats, personagens, top global
        label("Level", "", ud(0.48, 0, 0, 18), ud(0, 0, 0, 44), font=FONT_B, ts=14),
        frame("XPBar", ud(0.48, 0, 0, 4), ud(0, 0, 0, 66), bg=[0, 0, 0], t=0.5, children=[
            frame("Fill", ud(0, 0, 1, 0), ud(0, 0, 0, 0), bg=ACCENT, t=0),
        ]),
        frame("Stats", ud(0.48, 0, 0, 130), ud(0, 0, 0, 80), t=1, children=[
            listlayout("Vertical", 2),
            label("Template", "", ud(1, 0, 0, 18), ud(0, 0, 0, 0), ts=13, extra={"Visible": False}),
        ]),
        label("Characters", "", ud(0.48, 0, 0, 34), ud(0, 0, 0, 214), ts=12, color=MUTED, yalign="Top",
              extra={"TextWrapped": True}),
        label("TopTitle", "TOP GLOBAL (KILLS)", ud(0.48, 0, 0, 16), ud(0, 0, 0, 252), font=FONT_B, ts=11,
              color=MUTED),
        label("Top", "", ud(0.48, 0, 0, 100), ud(0, 0, 0, 270), font="Code", ts=12, yalign="Top"),
        # coluna direita: missões
        label("MissionsTitle", "MISSÕES DE HOJE", ud(0.48, 0, 0, 16), ud(1, 0, 0, 44), anchor=(1, 0), font=FONT_B,
              ts=11, color=MUTED),
        frame("Missions", ud(0.48, 0, 1, -70), ud(1, 0, 0, 64), anchor=(1, 0), t=1, children=[
            listlayout("Vertical", 8), mission_row,
        ]),
    ]),
], order=3)
write("ProfileGui.model.json", profile)

# =============================================================================
# Controles
# =============================================================================
HELP = "\n".join([
    "SOCO — botão esquerdo (combo de 4: 3/3/4/5%; o 4º derruba) · segurar = automático",
    "UPPERCUT — pular e socar subindo (levanta o alvo com você) · DOWNSLAM — socar caindo (ignora block, esmaga)",
    "BLOQUEAR — segurar F (−90%, só pela frente; guarda quebra) · PARRY — F até 0,2 s antes do golpe",
    "PARRY → próximo soco é CRÍTICO (×3); dois seguidos = BLACK FLASH (×6)",
    "CORRER — automático ao andar para a frente (W)",
    "SHIFT LOCK — Shift",
    "DASH — Q (segue o WASD; lados/trás 2 s, frente 4,5 s; sai até durante o hitstun)",
    "CAIU (ragdoll: 4º golpe, finisher, golpes pesados) — Q levanta na hora (20 s de recarga)",
    "HABILIDADES — E · R por cooldown · G = DESPERTAR com a carga cheia (20 s: +30% dano, +10% vel.)",
    "T = ULTIMATE — só durante o Despertar · CARGA — dar golpe +6, receber +4, parry +10",
    "VIDA — regenera após 6 s sem dano",
    "PERSONAGENS — V · LOJA — B · PERFIL — P · PLACAR — Tab · DUELO — J (Y aceita / N recusa)",
    "BOSS — segure E no altar; anel vermelho = saia da área",
    "Gamepad: R1 soco · L1 block · X dash · Y / B / R2 habilidades · L2 despertar",
])
helpgui = screen("HelpGui", [
    panel("Panel", 640, 380, "Controles", [
        label("Body", HELP, ud(1, 0, 1, -30), ud(0, 0, 0, 30), ts=13, yalign="Top",
              extra={"TextWrapped": True, "LineHeight": 1.35}),
    ]),
], order=3)
write("HelpGui.model.json", helpgui)

# =============================================================================
# Loja (moedas por Developer Product, Game Passes, personagens por moedas)
# =============================================================================
PW, PH = 120, 96
product_card = button("Template", "", ud(0, PW, 0, PH), ud(0, 0, 0, 0), bg=CARD, t=0.1, extra={"Visible": False},
                      children=[
    padding(8),
    label("Amount", "", ud(1, 0, 0, 26), ud(0, 0, 0, 0), font=FONT_B, ts=20, color=GOLD),
    label("Name", "", ud(1, 0, 0, 16), ud(0, 0, 0, 28), ts=11, color=MUTED),
    label("Price", "", ud(1, 0, 0, 18), ud(0, 0, 1, 0), anchor=(0, 1), font=FONT_B, ts=13, color=GREEN),
])
pass_row = button("Template", "", ud(1, 0, 0, 52), ud(0, 0, 0, 0), bg=CARD, t=0.1, extra={"Visible": False},
                  children=[
    padding(10, 6),
    label("Name", "", ud(0.7, 0, 0, 20), ud(0, 0, 0, 0), font=FONT_B, ts=14),
    label("Desc", "", ud(0.7, 0, 0, 16), ud(0, 0, 0, 20), ts=11, color=MUTED),
    label("Price", "", ud(0.3, 0, 1, 0), ud(1, 0, 0, 0), anchor=(1, 0), font=FONT_B, ts=13, color=GREEN,
          xalign="Right"),
])
shop = screen("ShopGui", [
    panel("Panel", 640, 420, "Loja", [
        label("Coins", "", ud(0, 200, 0, 22), ud(1, 0, 0, 0), anchor=(1, 0), font=FONT_B, ts=14, color=GOLD,
              xalign="Right"),
        label("ProductsTitle", "MOEDAS", ud(1, 0, 0, 16), ud(0, 0, 0, 34), font=FONT_B, ts=11, color=MUTED),
        frame("Products", ud(1, 0, 0, PH), ud(0, 0, 0, 54), t=1, children=[
            listlayout("Horizontal", 10), product_card,
        ]),
        label("PassesTitle", "PASSES", ud(1, 0, 0, 16), ud(0, 0, 0, 54 + PH + 16), font=FONT_B, ts=11, color=MUTED),
        frame("Passes", ud(1, 0, 1, -(54 + PH + 36 + 20)), ud(0, 0, 0, 54 + PH + 36), t=1, children=[
            listlayout("Vertical", 6), pass_row,
        ]),
        label("Hint", "Personagens são comprados com moedas na tela Personagens (V).", ud(1, 0, 0, 16),
              ud(0, 0, 1, 0), anchor=(0, 1), ts=11, color=MUTED),
    ]),
], order=3)
write("ShopGui.model.json", shop)
