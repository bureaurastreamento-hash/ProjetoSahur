#!/usr/bin/env python3
"""
Gera src/ui/DevGui.model.json (StarterGui.DevGui): menu de desenvolvedor.
Uso: python3 tools/gerar_devgui.py
Ligado por nome em DevController; o servidor (AdminService) é a autoridade.
"""

import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "src" / "ui" / "DevGui.model.json"

BG = [0.078, 0.078, 0.110]
BG2 = [0.13, 0.13, 0.17]
ACCENT = [0.35, 0.65, 1.0]
WHITE = [1, 1, 1]
GREY = [0.75, 0.75, 0.78]
GOLD = [1.0, 0.82, 0.35]
RED = [0.85, 0.3, 0.3]


def udim2(sx, ox, sy, oy):
    return {"UDim2": [[sx, ox], [sy, oy]]}


def node(name, cls, props=None, children=None):
    p = {"Name": name}
    p.update(props or {})
    return {"name": name, "className": cls, "properties": p, "children": children or []}


def corner(r=6):
    return node("UICorner", "UICorner", {"CornerRadius": {"UDim": [0, r]}})


def label(name, text, size, pos, text_size=14, color=WHITE, font="Gotham", align="Left", wrap=False):
    return node(name, "TextLabel", {
        "Size": size, "Position": pos, "BackgroundTransparency": 1, "Text": text, "TextSize": text_size,
        "Font": font, "TextColor3": {"Color3": color}, "TextXAlignment": align, "TextWrapped": wrap,
        "TextYAlignment": "Top" if wrap else "Center",
    })


def button(name, text, size, pos, color=BG2, text_color=WHITE, text_size=13):
    return node(name, "TextButton", {
        "Size": size, "Position": pos, "BackgroundColor3": {"Color3": color}, "Text": text,
        "TextSize": text_size, "Font": "GothamBold", "TextColor3": {"Color3": text_color}, "AutoButtonColor": True,
    }, [corner()])


def textbox(name, placeholder, size, pos, text=""):
    return node(name, "TextBox", {
        "Size": size, "Position": pos, "BackgroundColor3": {"Color3": BG2}, "Text": text,
        "PlaceholderText": placeholder, "PlaceholderColor3": {"Color3": [0.5, 0.5, 0.55]}, "TextSize": 14,
        "Font": "Gotham", "TextColor3": {"Color3": WHITE}, "ClearTextOnFocus": False,
    }, [corner()])


def section(name, text, y):
    return label(name, text, udim2(1, -20, 0, 18), udim2(0, 10, 0, y), 12, ACCENT, "GothamBold")


# ---------------------------------------------------------------------------
# Painel principal
# ---------------------------------------------------------------------------
W, H = 520, 470
panel_children = [
    corner(8),
    label("Title", "DEV", udim2(0, 100, 0, 30), udim2(0, 10, 0, 6), 20, ACCENT, "GothamBold"),
    label("Subtitle", "só para nicks em AdminConfig · tudo fica no log do servidor", udim2(1, -130, 0, 30), udim2(0, 70, 0, 6), 11, GREY),
    button("Close", "X", udim2(0, 28, 0, 28), udim2(1, -36, 0, 8), BG2),

    # alvo
    section("TargetSection", "ALVO", 42),
    node("Targets", "ScrollingFrame", {
        "Size": udim2(1, -20, 0, 34), "Position": udim2(0, 10, 0, 62), "BackgroundColor3": {"Color3": BG2},
        "BackgroundTransparency": 0.5, "ScrollingDirection": "X", "AutomaticCanvasSize": "X",
        "CanvasSize": udim2(0, 0, 0, 0), "ScrollBarThickness": 4, "BorderSizePixel": 0,
    }, [
        corner(),
        node("UIListLayout", "UIListLayout", {"FillDirection": "Horizontal", "Padding": {"UDim": [0, 4]},
                                              "SortOrder": "LayoutOrder", "VerticalAlignment": "Center"}),
        node("UIPadding", "UIPadding", {"PaddingLeft": {"UDim": [0, 4]}}),
        button("Template", "Jogador", udim2(0, 110, 0, 26), udim2(0, 0, 0, 0)) | {"properties": {
            "Name": "Template", "Size": udim2(0, 110, 0, 26), "BackgroundColor3": {"Color3": BG2}, "Text": "Jogador",
            "TextSize": 12, "Font": "GothamBold", "TextColor3": {"Color3": WHITE}, "Visible": False,
            "AutoButtonColor": True}},
    ]),

    # moedas / energia
    section("CoinsSection", "MOEDAS E ENERGIA", 104),
    textbox("Amount", "quantidade", udim2(0, 120, 0, 30), udim2(0, 10, 0, 124), "100"),
    button("SetCoins", "Definir moedas", udim2(0, 120, 0, 30), udim2(0, 136, 0, 124)),
    button("AddCoins", "+ moedas", udim2(0, 100, 0, 30), udim2(0, 262, 0, 124)),
    button("SetEnergy", "Energia", udim2(0, 100, 0, 30), udim2(0, 368, 0, 124)),

    # personagens
    section("CharSection", "PERSONAGENS", 164),
    node("Characters", "Frame", {
        "Size": udim2(1, -20, 0, 34), "Position": udim2(0, 10, 0, 184), "BackgroundTransparency": 1,
    }, [
        node("UIListLayout", "UIListLayout", {"FillDirection": "Horizontal", "Padding": {"UDim": [0, 4]},
                                              "SortOrder": "LayoutOrder"}),
        button("Template", "Char", udim2(0, 90, 0, 30), udim2(0, 0, 0, 0)) | {"properties": {
            "Name": "Template", "Size": udim2(0, 90, 0, 30), "BackgroundColor3": {"Color3": BG2}, "Text": "Char",
            "TextSize": 12, "Font": "GothamBold", "TextColor3": {"Color3": WHITE}, "Visible": False,
            "AutoButtonColor": True}},
    ]),
    label("CharHint", "clique = usar · segure Shift = dar · Ctrl = tirar", udim2(1, -20, 0, 16), udim2(0, 10, 0, 220), 11, GREY),

    # ações
    section("ActionSection", "AÇÕES", 244),
]
actions = [
    ("Heal", "Curar"), ("Kill", "Matar"), ("God", "Modo deus"), ("Teleport", "Ir até"),
    ("Bring", "Trazer"), ("Kick", "Kick"), ("ResetData", "Zerar dados"), ("ListPlayers", "Listar"),
]
for i, (cmd, text) in enumerate(actions):
    col, row = i % 4, i // 4
    color = RED if cmd in ("Kick", "ResetData", "Kill") else BG2
    panel_children.append(button(cmd, text, udim2(0, 118, 0, 30), udim2(0, 10 + col * 124, 0, 264 + row * 36), color))

panel_children += [
    section("LogSection", "RESULTADO", 340),
    node("Log", "TextLabel", {
        "Size": udim2(1, -20, 0, 100), "Position": udim2(0, 10, 0, 360), "BackgroundColor3": {"Color3": BG2},
        "BackgroundTransparency": 0.5, "Text": "", "TextSize": 12, "Font": "Code", "TextColor3": {"Color3": GREY},
        "TextXAlignment": "Left", "TextYAlignment": "Top", "TextWrapped": True,
    }, [corner(), node("UIPadding", "UIPadding", {"PaddingLeft": {"UDim": [0, 6]}, "PaddingTop": {"UDim": [0, 4]}})]),
]

panel = node("Panel", "Frame", {
    "Size": udim2(0, W, 0, H), "Position": udim2(0.5, 0, 0.5, 0), "AnchorPoint": {"Vector2": [0.5, 0.5]},
    "BackgroundColor3": {"Color3": BG}, "BackgroundTransparency": 0.1, "Visible": False, "Active": True,
}, panel_children)

gui = {
    "className": "ScreenGui",
    "properties": {"ResetOnSpawn": False, "DisplayOrder": 10, "IgnoreGuiInset": False},
    "children": [panel],
}
OUT.write_text(json.dumps(gui, indent=1) + "\n")
print(OUT)
