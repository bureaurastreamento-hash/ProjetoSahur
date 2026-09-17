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
BG = [0.0, 0.0, 0.0]             # painéis: mesmo preto translúcido do TopbarPlus (discreto)
BG_T = 0.28                      # transparência dos painéis (TopbarPlus usa 0.5; 0.28 = texto legível sobre o mapa)
CARD = [0.08, 0.08, 0.09]        # cartões/slots
LINE = [1, 1, 1]                 # borda (com transparência)
LINE_T = 0.84
TEXT = [0.96, 0.96, 0.97]
MUTED = [0.62, 0.62, 0.68]
ACCENT = [0.35, 0.75, 1.0]       # energia / seleção
HEALTH = [0.90, 0.27, 0.27]
GOLD = [1.0, 0.80, 0.30]
GREEN = [0.35, 0.80, 0.50]
GOLD_BG = [0.45, 0.35, 0.10]      # botões da roleta
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


def textbox(name, placeholder, size, pos, anchor=(0, 0), ts=14, extra=None):
    props = {"Size": size, "Position": pos, "AnchorPoint": {"Vector2": list(anchor)}, "BackgroundColor3": col(CARD),
             "BackgroundTransparency": 0.0, "Text": "", "PlaceholderText": placeholder, "PlaceholderColor3": col(MUTED),
             "Font": FONT, "TextSize": ts, "TextColor3": col(TEXT), "ClearTextOnFocus": False, "BorderSizePixel": 0,
             "TextXAlignment": "Left"}
    props.update(extra or {})
    return node(name, "TextBox", props, [corner(), stroke(), padding(8, 0)])


def scroll(name, size, pos, children=None, extra=None, horizontal=False):
    axis = "X" if horizontal else "Y"
    props = {"Size": size, "Position": pos, "BackgroundTransparency": 1, "BorderSizePixel": 0, "ScrollBarThickness": 4,
             "ScrollBarImageTransparency": 0.6, "CanvasSize": {"UDim2": [[0, 0], [0, 0]]}, "AutomaticCanvasSize": axis,
             "ScrollingDirection": axis}
    props.update(extra or {})
    return node(name, "ScrollingFrame", props, children)


def screen(name, children, order=1, enabled=True, ignore_inset=True):
    return {"className": "ScreenGui", "properties": {"ResetOnSpawn": False, "IgnoreGuiInset": ignore_inset,
                                                      "ZIndexBehavior": "Sibling", "DisplayOrder": order,
                                                      "Enabled": enabled},
            "children": children}


PANEL_PAD = 18
PANEL_TITLE_H = 26  # altura do título; o conteúdo começa em y = PANEL_TITLE_H + 8


def sizecap(w, h):
    """Teto de tamanho (UISizeConstraint): o painel pede (w, h) mas encolhe se a tela for menor."""
    return node("UISizeConstraint", "UISizeConstraint", {"MaxSize": {"Vector2": [w, h]}, "MinSize": {"Vector2": [0, 0]}})


def panel(name, w, h, title, children, hidden=True, full_width=False):
    """Painel padrão (aberto pelo TopbarPlus): título + conteúdo.
    Abre como um DROPDOWN logo abaixo do topbar, à esquerda, com a mesma cor dos ícones (jogo
    competitivo: o centro da tela nunca é coberto). Tamanho = (w, h) no máximo; em telas menores
    encolhe até caber (largura = tela − 24, altura = tela − 202) e recorta o que estourar
    (ClipsDescendants): listas devem ser ScrollingFrames com altura relativa."""
    # altura máxima = tela − topbar (52) − faixa da HUD embaixo (~150): o painel nunca cobre a barra/slots
    size = ud(1, -24, 1, -(52 + 150)) if full_width else ud(0, w, 1, -(52 + 150))
    return frame(name, size, ud(0, 12, 0, 52), anchor=(0, 0), visible=not hidden, children=[
        corner(10), stroke(), padding(PANEL_PAD), sizecap(w, h),
        label("Title", title, ud(1, 0, 0, PANEL_TITLE_H), ud(0, 0, 0, 0), font=FONT_B, ts=20, color=TEXT),
    ] + children, extra={"ClipsDescendants": True})


def write(fname, data):
    (UI / fname).write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n")
    print(UI / fname)


# =============================================================================
# HUD
# =============================================================================
SLOT = 64
SLOT_KEYS = ["1", "2", "3", "4"]  # habilidades; Q = dash universal (frames Dash/DashSide); G = ultimate (frame Ult)


def slot(i, name=None, key=None, ult=False):
    key = key or SLOT_KEYS[i - 1]
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
    # Pontos no canto superior direito
    label("Coins", "", ud(0, 200, 0, 24), ud(1, -16, 0, 12), anchor=(1, 0), font=FONT_B, ts=15, color=GOLD,
          xalign="Right", extra={"TextStrokeTransparency": 0.7}),
    # Killfeed abaixo das pontos
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
    frame("Abilities", ud(0, SLOT * 7 + 8 * 6, 0, SLOT), ud(0.5, 0, 1, -32), anchor=(0.5, 1), t=1, children=[
        listlayout("Horizontal", 8, "Center", "Center"),
        slot(-1, name="Dash", key="Q"), slot(0, name="DashSide", key="Q"),
        slot(1), slot(2), slot(3), slot(4), slot(5, name="Ult", key="G", ult=True),
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
    label("Banner", "", ud(0, 760, 0, 64), ud(0.5, 0, 0.22, 0), anchor=(0.5, 0.5), font=FONT_B, ts=24,
          xalign="Center", extra={"Visible": False, "TextStrokeTransparency": 0.5, "TextWrapped": True}),
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
    # selo: GRÁTIS / 250 PONTOS / VIP / EM BREVE
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
N_CARDS = 6  # CharacterDefs.Order (Overlord só aparece para devs, mas o painel comporta todos)
select = screen("CharacterSelect", [
    panel("Panel", N_CARDS * (CARD_W + 10) - 10 + 2 * PANEL_PAD, CARD_H + 100, "Personagens", [
        label("Coins", "", ud(0, 200, 0, PANEL_TITLE_H), ud(1, 0, 0, 0), anchor=(1, 0), font=FONT_B, ts=14, color=GOLD,
              xalign="Right"),
        label("Hint", "", ud(1, 0, 0, 18), ud(0, 0, 0, PANEL_TITLE_H + 2), ts=12, color=MUTED),
        scroll("List", ud(1, 0, 0, CARD_H + 10), ud(0, 0, 0, PANEL_TITLE_H + 28), horizontal=True, children=[
            listlayout("Horizontal", 10, "Left"), card,
        ]),
        button("QueueButton", "Entrar na fila", ud(0, 160, 0, 30), ud(0.5, 0, 1, 0), anchor=(0.5, 1), bg=GREEN,
               extra={"Visible": False}),
    ], full_width=True),
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
COL = 0.47  # largura de cada coluna do perfil (sobra 6% de vão no meio)
Y0 = PANEL_TITLE_H + 26  # abaixo do título + linha de aviso
profile = screen("ProfileGui", [
    panel("Panel", 580, 450, "Perfil", [
        label("Coins", "", ud(0, 220, 0, PANEL_TITLE_H), ud(1, 0, 0, 0), anchor=(1, 0), font=FONT_B, ts=14, color=GOLD,
              xalign="Right"),
        label("Warning", "", ud(1, 0, 0, 16), ud(0, 0, 0, PANEL_TITLE_H + 4), ts=11, color=HEALTH),
        # coluna esquerda: nível, stats, personagens, top global
        label("Level", "", ud(COL, 0, 0, 18), ud(0, 0, 0, Y0), font=FONT_B, ts=14),
        frame("XPBar", ud(COL, 0, 0, 4), ud(0, 0, 0, Y0 + 22), bg=[1, 1, 1], t=0.88, children=[
            corner(2), frame("Fill", ud(0, 0, 1, 0), ud(0, 0, 0, 0), bg=ACCENT, t=0, children=[corner(2)]),
        ]),
        frame("Stats", ud(COL, 0, 0, 122), ud(0, 0, 0, Y0 + 36), t=1, children=[
            listlayout("Vertical", 2),
            label("Template", "", ud(1, 0, 0, 18), ud(0, 0, 0, 0), ts=13, extra={"Visible": False}),
        ]),
        label("Characters", "", ud(COL, 0, 0, 32), ud(0, 0, 0, Y0 + 162), ts=11, color=MUTED, yalign="Top",
              extra={"TextWrapped": True}),
        label("TopTitle", "TOP GLOBAL — KILLS", ud(COL, 0, 0, 14), ud(0, 0, 0, Y0 + 200), font=FONT_B, ts=11,
              color=MUTED),
        label("Top", "", ud(COL, 0, 0, 62), ud(0, 0, 0, Y0 + 216), font="Code", ts=12, yalign="Top"),
        label("TopRatingTitle", "TOP GLOBAL — RATING 1v1", ud(COL, 0, 0, 14), ud(0, 0, 0, Y0 + 284), font=FONT_B,
              ts=11, color=MUTED),
        label("TopRating", "", ud(COL, 0, 0, 62), ud(0, 0, 0, Y0 + 300), font="Code", ts=12, yalign="Top"),
        # coluna direita: missões (rola se precisar)
        label("MissionsTitle", "MISSÕES DE HOJE", ud(COL, 0, 0, 14), ud(1, 0, 0, Y0), anchor=(1, 0), font=FONT_B,
              ts=11, color=MUTED),
        scroll("Missions", ud(COL, 0, 1, -(Y0 + 20)), ud(1, 0, 0, Y0 + 20), extra={"AnchorPoint": {"Vector2": [1, 0]}},
               children=[listlayout("Vertical", 8), mission_row]),
    ]),
], order=3)
write("ProfileGui.model.json", profile)


# =============================================================================
# Clã (C) — ClanController
# =============================================================================
member_row = button("Template", "", ud(1, -6, 0, 30), ud(0, 0, 0, 0), ts=13, extra={"Visible": False, "TextXAlignment": "Left"},
                    children=[padding(10, 0),
                              label("Role", "", ud(0, 90, 1, 0), ud(1, 0, 0, 0), anchor=(1, 0), ts=11, color=MUTED, xalign="Right")])
clan = screen("ClanGui", [
    panel("Panel", 420, 440, "Clã", [
        # --- sem clã: fundar ---
        frame("Create", ud(1, 0, 1, -(PANEL_TITLE_H + 10)), ud(0, 0, 0, PANEL_TITLE_H + 10), t=1, children=[
            label("Hint", "Funde um clã ou aceite um convite de um líder/oficial.", ud(1, 0, 0, 34), ud(0, 0, 0, 0),
                  ts=12, color=MUTED, yalign="Top", extra={"TextWrapped": True}),
            textbox("Name", "Nome do clã (3–20)", ud(1, 0, 0, 32), ud(0, 0, 0, 44)),
            textbox("Tag", "TAG (2–4 letras/números)", ud(0.5, -5, 0, 32), ud(0, 0, 0, 84)),
            button("Submit", "FUNDAR — 500 pts", ud(0.5, -5, 0, 32), ud(1, 0, 0, 84), anchor=(1, 0), bg=GOLD_BG, ts=13),
            label("Invite", "", ud(1, 0, 0, 40), ud(0, 0, 0, 140), font=FONT_B, ts=13, color=GOLD, yalign="Top",
                  extra={"TextWrapped": True}),
            button("Accept", "ACEITAR (Y)", ud(0.5, -5, 0, 30), ud(0, 0, 0, 186), bg=[0.16, 0.38, 0.24], ts=13,
                   extra={"Visible": False}),
            button("Decline", "RECUSAR (N)", ud(0.5, -5, 0, 30), ud(1, 0, 0, 186), anchor=(1, 0), ts=13,
                   extra={"Visible": False}),
        ]),
        # --- com clã ---
        frame("Info", ud(1, 0, 1, -(PANEL_TITLE_H + 10)), ud(0, 0, 0, PANEL_TITLE_H + 10), t=1, visible=False, children=[
            label("Header", "", ud(1, -120, 0, 22), ud(0, 0, 0, 0), font=FONT_B, ts=16, color=GOLD),
            button("War", "GUERRA", ud(0, 110, 0, 24), ud(1, 0, 0, 0), anchor=(1, 0), bg=[0.4, 0.14, 0.14], ts=12),
            label("Sub", "", ud(1, 0, 0, 18), ud(0, 0, 0, 24), ts=12, color=MUTED),
            button("TabMembers", "MEMBROS", ud(0.5, -5, 0, 26), ud(0, 0, 0, 50), ts=12),
            button("TabInvite", "CONVIDAR", ud(0.5, -5, 0, 26), ud(1, 0, 0, 50), anchor=(1, 0), ts=12),
            scroll("List", ud(1, 0, 1, -196), ud(0, 0, 0, 84), children=[listlayout("Vertical", 4), member_row]),
            label("Selected", "", ud(1, 0, 0, 16), ud(0, 0, 1, -106), anchor=(0, 1), ts=11, color=MUTED),
            button("Promote", "PROMOVER", ud(0.33, -6, 0, 28), ud(0, 0, 1, -72), anchor=(0, 1), ts=12),
            button("Demote", "REBAIXAR", ud(0.33, -6, 0, 28), ud(0.5, 0, 1, -72), anchor=(0.5, 1), ts=12),
            button("Kick", "EXPULSAR", ud(0.33, -6, 0, 28), ud(1, 0, 1, -72), anchor=(1, 1), bg=[0.4, 0.14, 0.14], ts=12),
            textbox("Amount", "pontos", ud(0.3, -6, 0, 28), ud(0, 0, 1, -36), anchor=(0, 1), ts=13),
            button("Deposit", "DEPOSITAR", ud(0.3, -6, 0, 28), ud(0.35, 0, 1, -36), anchor=(0, 1), bg=GOLD_BG, ts=12),
            button("Leave", "SAIR", ud(0.3, -6, 0, 28), ud(1, 0, 1, -36), anchor=(1, 1), ts=12),
            button("Disband", "DISSOLVER", ud(0.3, -6, 0, 28), ud(1, 0, 1, -36), anchor=(1, 1), bg=[0.4, 0.14, 0.14], ts=12,
                   extra={"Visible": False}),
        ]),
        label("Status", "", ud(1, 0, 0, 16), ud(0, 0, 1, 0), anchor=(0, 1), ts=11, color=MUTED),
    ]),
], order=3)
write("ClanGui.model.json", clan)


# =============================================================================
# Guerra de clã (WarController): placar no topo durante a dominação
# =============================================================================
def zone_chip(name, x):
    return frame(name, ud(0, 34, 0, 26), ud(0.5, x, 1, -6), anchor=(0.5, 1), bg=[0.7, 0.7, 0.75], t=0.2, children=[
        corner(6),
        label("Letter", name, ud(1, 0, 1, 0), ud(0, 0, 0, 0), font=FONT_B, ts=14, xalign="Center", color=[0.05, 0.05, 0.06]),
        frame("Progress", ud(0, 0, 0, 3), ud(0, 0, 1, 0), anchor=(0, 1), bg=[1, 1, 1], t=0),
    ])
wargui = screen("WarGui", [
    frame("Bar", ud(0, 440, 0, 78), ud(0.5, 0, 0, 8), anchor=(0.5, 0), visible=False, children=[
        corner(8), stroke(),
        label("TeamA", "", ud(0, 150, 0, 22), ud(0, 12, 0, 6), font=FONT_B, ts=14, color=[0.45, 0.6, 1.0]),
        label("ScoreA", "0", ud(0, 60, 0, 30), ud(0.5, -40, 0, 2), anchor=(1, 0), font=FONT_B, ts=24, xalign="Right"),
        label("Timer", "5:00", ud(0, 70, 0, 30), ud(0.5, 0, 0, 2), anchor=(0.5, 0), font=FONT_B, ts=16, xalign="Center", color=MUTED),
        label("ScoreB", "0", ud(0, 60, 0, 30), ud(0.5, 40, 0, 2), anchor=(0, 0), font=FONT_B, ts=24),
        label("TeamB", "", ud(0, 150, 0, 22), ud(1, -12, 0, 6), anchor=(1, 0), font=FONT_B, ts=14, color=[1.0, 0.45, 0.45], xalign="Right"),
        zone_chip("A", -44), zone_chip("B", 0), zone_chip("C", 44),
    ]),
    label("Banner", "", ud(0, 520, 0, 44), ud(0.5, 0, 0, 96), anchor=(0.5, 0), font=FONT_B, ts=20, xalign="Center",
          color=GOLD, extra={"TextStrokeTransparency": 0.5, "Visible": False}),
], order=4)
write("WarGui.model.json", wargui)

# =============================================================================
# Controles
# =============================================================================
HELP = "\n".join([
    "SOCO — botão esquerdo (combo de 4: 3/3/4/5%; o 4º derruba) · segurar = automático",
    "4º GOLPE: no chão empurra · pular e socar subindo = UPPERCUT (levanta o alvo com você) · socar caindo = DOWNSLAM (ignora block, esmaga)",
    "BLOQUEAR — segurar F (−90%, só pela frente; guarda quebra) · PARRY — F até 0,2 s antes do golpe",
    "PARRY → próximo soco é CRÍTICO (×3); dois seguidos = BLACK FLASH (×6)",
    "CORRER — automático ao andar para a frente (W)",
    "SHIFT LOCK — Shift",
    "DASH — Q + WASD (A/D lateral 2 s · W/S frente/trás 4 s, recargas separadas; não sai apanhando)",
    "CAIU (ragdoll: 4º golpe, finisher, golpes pesados) — Q levanta na hora (20 s de recarga)",
    "HABILIDADES — 1 / 2 / 3 / 4 por cooldown (direção pelo WASD) · agarrões: Brawler ARREMESSA (mire com a câmera), Guardian ESMAGA (área), Overlord GIRA (acerta quem chega perto)",
    "G = ULTIMATE com a carga cheia: golpe final + DESPERTAR (20 s: +30% dano, +10% vel.)",
    "CARGA — dar golpe +6, receber +4, parry +10",
    "VIDA — regenera após 6 s sem dano",
    "PERSONAGENS — V · LOJA — L · COSMÉTICOS — K · EMOTES/CENAS — B (roda) · PERFIL — P · PLACAR — Tab · DUELO — J · CLÃ — C",
    "BOSS — segure E no altar; anel vermelho = saia da área · GUERRA DE CLÃ — Clã (C) > GUERRA: dominação A/B/C, 2 clãs, 5 min",
    "CONTROLE: B soco (segurar = combo) · X block · Y dash/levantar · LB LT RT RB = 1 2 3 4 · D-pad ↑ ultimate · D-pad ↓ emotes · R3 shift lock · Back placar · D-pad → menus do topo · A pulo",
    "CELULAR: botões na tela (SOCO segurar = combo, BLOCK, DASH, 1-4, ULT, EMOTE, LOCK, CORRER); joystick = direção do dash",
])
setting_row = button("Template", "", ud(1, 0, 0, 26), ud(0, 0, 0, 0), bg=CARD, t=0.2, ts=12, extra={"Visible": False, "TextXAlignment": "Left"},
                     children=[padding(10, 0),
                               label("Value", "", ud(0, 90, 1, 0), ud(1, 0, 0, 0), anchor=(1, 0), font=FONT_B, ts=12, color=ACCENT, xalign="Right")])
SETTINGS_H = 7 * 26 + 6 * 4 + 22  # 7 linhas + título
helpgui = screen("HelpGui", [
    panel("Panel", 640, 620, "Controles", [
        scroll("Body", ud(1, 0, 1, -(PANEL_TITLE_H + 8 + SETTINGS_H + 12)), ud(0, 0, 0, PANEL_TITLE_H + 8), children=[
            label("Text", HELP, ud(1, -8, 0, 0), ud(0, 0, 0, 0), ts=13, yalign="Top",
                  extra={"TextWrapped": True, "LineHeight": 1.35, "AutomaticSize": "Y"}),
        ]),
        label("SettingsTitle", "CONFIGURAÇÕES  ·  clique para mudar (salva no perfil)", ud(1, 0, 0, 16), ud(0, 0, 1, -SETTINGS_H),
              anchor=(0, 1), font=FONT_B, ts=11, color=MUTED),
        frame("Settings", ud(1, 0, 0, SETTINGS_H - 22), ud(0, 0, 1, 0), anchor=(0, 1), t=1,
              children=[listlayout("Vertical", 4), setting_row]),
    ]),
], order=3)
write("HelpGui.model.json", helpgui)

# =============================================================================
# Loja (pontos por Developer Product, Game Passes, personagens por pontos)
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
SY = PANEL_TITLE_H + 12
shop = screen("ShopGui", [
    panel("Panel", 640, 520, "Loja", [
        label("Coins", "", ud(0, 200, 0, PANEL_TITLE_H), ud(1, 0, 0, 0), anchor=(1, 0), font=FONT_B, ts=14, color=GOLD,
              xalign="Right"),
        label("ProductsTitle", "ROLETA DE COSMÉTICOS  ·  ROBUX", ud(1, 0, 0, 16), ud(0, 0, 0, SY), font=FONT_B, ts=11, color=MUTED),
        frame("Products", ud(1, 0, 0, PH), ud(0, 0, 0, SY + 20), t=1, children=[
            listlayout("Horizontal", 10), product_card,
        ]),
        label("PassesTitle", "PASSES", ud(1, 0, 0, 16), ud(0, 0, 0, SY + 20 + PH + 16), font=FONT_B, ts=11, color=MUTED),
        scroll("Passes", ud(1, 0, 1, -(SY + 20 + PH + 36 + 24)), ud(0, 0, 0, SY + 20 + PH + 36), children=[
            listlayout("Vertical", 6), pass_row,
        ]),
        label("Hint", "Personagens são comprados com pontos na tela Personagens (V).", ud(1, 0, 0, 16),
              ud(0, 0, 1, 0), anchor=(0, 1), ts=11, color=MUTED),
    ]),
], order=3)
write("ShopGui.model.json", shop)

# =============================================================================
# Cosméticos (skins, capas, auras, emotes): lista por categoria, comprar/equipar
# =============================================================================
cos_row = button("Template", "", ud(1, 0, 0, 40), ud(0, 0, 0, 0), bg=CARD, t=0.1, extra={"Visible": False}, children=[
    padding(10, 4),
    frame("Swatch", ud(0, 18, 0, 18), ud(0, 0, 0.5, 0), anchor=(0, 0.5), bg=ACCENT, t=0, children=[corner(9)]),
    label("Name", "", ud(0.6, -30, 1, 0), ud(0, 28, 0, 0), font=FONT_B, ts=13),
    label("State", "", ud(0.4, 0, 1, 0), ud(1, 0, 0, 0), anchor=(1, 0), font=FONT_B, ts=12, color=GREEN,
          xalign="Right"),
])
tab_w = 100
cosmetics = screen("CosmeticsGui", [
    panel("Panel", 460, 500, "Cosméticos", [
        label("Coins", "", ud(0, 160, 0, PANEL_TITLE_H), ud(1, 0, 0, 0), anchor=(1, 0), font=FONT_B, ts=14, color=GOLD,
              xalign="Right"),
        frame("Tabs", ud(1, 0, 0, 28), ud(0, 0, 0, PANEL_TITLE_H + 12), t=1, children=[
            listlayout("Horizontal", 6),
            button("TabSkin", "SKINS", ud(0, tab_w, 1, 0), ud(0, 0, 0, 0), ts=12, extra={"LayoutOrder": 1}),
            button("TabCape", "CAPAS", ud(0, tab_w, 1, 0), ud(0, 0, 0, 0), ts=12, extra={"LayoutOrder": 2}),
            button("TabAura", "AURAS", ud(0, tab_w, 1, 0), ud(0, 0, 0, 0), ts=12, extra={"LayoutOrder": 3}),
            button("TabEmote", "EMOTES", ud(0, tab_w, 1, 0), ud(0, 0, 0, 0), ts=12, extra={"LayoutOrder": 4}),
        ]),
        button("Roll", "GIRAR", ud(0.5, -4, 0, 30), ud(0, 0, 0, PANEL_TITLE_H + 48), bg=GOLD_BG, ts=13),
        button("Roll1", "1 giro · Robux", ud(0.25, -4, 0, 30), ud(0.5, 4, 0, PANEL_TITLE_H + 48), ts=11),
        button("Roll5", "5 giros · Robux", ud(0.25, -4, 0, 30), ud(0.75, 4, 0, PANEL_TITLE_H + 48), ts=11),
        label("Hint", "Roleta da sorte: pontos (ganhos jogando) ou Robux. Só visual: nada dá vantagem.", ud(1, 0, 0, 16),
              ud(0, 0, 0, PANEL_TITLE_H + 84), ts=11, color=MUTED),
        scroll("List", ud(1, 0, 1, -(PANEL_TITLE_H + 108)), ud(0, 0, 0, PANEL_TITLE_H + 108),
               children=[listlayout("Vertical", 6), cos_row]),
    ]),
], order=3)
write("CosmeticsGui.model.json", cosmetics)

# =============================================================================
# Roda de emotes (B): 8 botões em círculo no centro-baixo, aparece enquanto aberta
# =============================================================================
import math as _m
wheel_children = [
    frame("Center", ud(0, 70, 0, 70), ud(0.5, 0, 0.5, 0), anchor=(0.5, 0.5), bg=BG, t=0.2, children=[
        corner(35), stroke(),
        label("Label", "EMOTES", ud(1, 0, 1, 0), ud(0, 0, 0, 0), font=FONT_B, ts=11, color=MUTED, xalign="Center"),
    ]),
    # roleta da sorte à direita da roda
    button("Roll", "GIRAR", ud(0, 84, 0, 56), ud(0.5, 215, 0.5, 0), anchor=(0.5, 0.5), bg=GOLD_BG, ts=12,
           extra={"TextWrapped": True}),
]
for i in range(8):
    a = -_m.pi / 2 + i * (2 * _m.pi / 8)
    x, y = round(_m.cos(a) * 120), round(_m.sin(a) * 120)
    wheel_children.append(button(f"Slot{i + 1}", "", ud(0, 92, 0, 40), ud(0.5, x, 0.5, y), anchor=(0.5, 0.5),
                                 bg=CARD, t=0.1, ts=12))
emotes = screen("EmoteGui", [
    frame("Wheel", ud(0, 520, 0, 300), ud(0.5, 0, 0.5, 40), anchor=(0.5, 0.5), t=1, visible=False,
          children=wheel_children),
], order=4)
write("EmoteGui.model.json", emotes)

# =============================================================================
# Duelo (J) — DuelController. Nomes fixos: Tab1v1/Tab2v2/Hint/List/Status/Leave/Cancel/CreateRoom/
# SwitchTeam/LeaveRoom; Invite (Text/Accept/Decline) e DuelStatus fora do painel.
# =============================================================================
duel_row = button("Template", "", ud(1, -6, 0, 32), ud(0, 0, 0, 0), ts=13, extra={"Visible": False, "TextXAlignment": "Left"},
                  children=[padding(10, 0),
                            label("Action", "DESAFIAR", ud(0, 90, 1, 0), ud(1, 0, 0, 0), anchor=(1, 0), font=FONT_B, ts=11,
                                  color=GREEN, xalign="Right")])
DY = PANEL_TITLE_H + 10
duel = screen("DuelGui", [
    panel("Panel", 380, 420, "Duelo", [
        button("Tab1v1", "1v1", ud(0.5, -5, 0, 26), ud(0, 0, 0, DY), ts=12),
        button("Tab2v2", "2v2", ud(0.5, -5, 0, 26), ud(1, 0, 0, DY), anchor=(1, 0), ts=12),
        label("Hint", "", ud(1, 0, 0, 32), ud(0, 0, 0, DY + 32), ts=12, color=MUTED, yalign="Top",
              extra={"TextWrapped": True}),
        scroll("List", ud(1, 0, 1, -(DY + 70 + 104)), ud(0, 0, 0, DY + 70),
               children=[listlayout("Vertical", 4, sort="Name"), duel_row]),
        label("Status", "", ud(1, 0, 0, 34), ud(0, 0, 1, -68), anchor=(0, 1), ts=12, color=GOLD, yalign="Top",
              extra={"TextWrapped": True}),
        button("CreateRoom", "Criar sala 2v2", ud(1, 0, 0, 28), ud(0, 0, 1, -32), anchor=(0, 1), bg=[0.16, 0.38, 0.24],
               ts=12, extra={"Visible": False}),
        button("SwitchTeam", "Trocar de time", ud(0.5, -5, 0, 28), ud(0, 0, 1, -32), anchor=(0, 1), ts=12,
               extra={"Visible": False}),
        button("LeaveRoom", "Sair da sala", ud(0.5, -5, 0, 28), ud(1, 0, 1, -32), anchor=(1, 1), bg=[0.4, 0.14, 0.14],
               ts=12, extra={"Visible": False}),
        button("Leave", "Desistir do duelo", ud(1, 0, 0, 28), ud(0, 0, 1, 0), anchor=(0, 1), bg=[0.4, 0.14, 0.14], ts=12,
               extra={"Visible": False}),
        button("Cancel", "Cancelar desafio", ud(1, 0, 0, 28), ud(0, 0, 1, 0), anchor=(0, 1), ts=12,
               extra={"Visible": False}),
    ]),
    # convite recebido: cartão no topo central
    frame("Invite", ud(0, 360, 0, 96), ud(0.5, 0, 0, 70), anchor=(0.5, 0), t=0.15, visible=False, children=[
        corner(10), stroke(), padding(12),
        label("Text", "", ud(1, 0, 0, 36), ud(0, 0, 0, 0), font=FONT_B, ts=14, xalign="Center", extra={"TextWrapped": True}),
        button("Accept", "ACEITAR (Y)", ud(0.5, -5, 0, 30), ud(0, 0, 1, 0), anchor=(0, 1), bg=[0.16, 0.38, 0.24], ts=12),
        button("Decline", "RECUSAR (N)", ud(0.5, -5, 0, 30), ud(1, 0, 1, 0), anchor=(1, 1), bg=[0.4, 0.14, 0.14], ts=12),
    ]),
    label("DuelStatus", "", ud(0, 520, 0, 40), ud(0.5, 0, 0, 110), anchor=(0.5, 0), font=FONT_B, ts=24, xalign="Center",
          extra={"TextStrokeTransparency": 0.5, "Visible": False, "TextWrapped": True}),
], order=3)
write("DuelGui.model.json", duel)
