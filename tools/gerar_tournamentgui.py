#!/usr/bin/env python3
"""
Gera src/ui/TournamentGui.model.json (StarterGui.TournamentGui): barra do torneio "Último de pé" (D3).
Uso: python3 tools/gerar_tournamentgui.py — ligada por nome no TournamentController; estilo do WarGui.
"""

import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "src" / "ui" / "TournamentGui.model.json"

GOLD = [1.0, 0.8, 0.3]
WHITE = [1, 1, 1]
GREY = [0.75, 0.75, 0.78]


def node(name, cls, props, children=None):
    p = {"Name": name}
    p.update(props)
    return {"name": name, "className": cls, "properties": p, "children": children or []}


def ud(sx, ox, sy, oy):
    return {"UDim2": [[sx, ox], [sy, oy]]}


def lbl(name, size, pos, text_size, color, align="Left", font="GothamBold", anchor=(0, 0)):
    return node(name, "TextLabel", {
        "Size": size, "Position": pos, "AnchorPoint": {"Vector2": list(anchor)}, "BackgroundTransparency": 1,
        "Text": "", "Font": font, "TextSize": text_size, "TextColor3": {"Color3": color}, "TextXAlignment": align,
        "TextYAlignment": "Center", "BorderSizePixel": 0, "TextTruncate": "AtEnd",
    })


# Barra centro-alto, abaixo do TopBar do HUD (mesma faixa do placar da guerra de clã)
bar = node("Bar", "Frame", {
    "Size": ud(0, 380, 0, 62), "Position": ud(0.5, 0, 0, 92), "AnchorPoint": {"Vector2": [0.5, 0]},
    "BackgroundColor3": {"Color3": [0, 0, 0]}, "BackgroundTransparency": 0.28, "BorderSizePixel": 0, "Visible": False,
}, [
    node("UICorner", "UICorner", {"CornerRadius": {"UDim": [0, 0]}}),
    node("UIStroke", "UIStroke", {"Thickness": 1, "Color": {"Color3": WHITE}, "Transparency": 0.84, "ApplyStrokeMode": "Border"}),
    lbl("Title", ud(0, 220, 0, 20), ud(0, 12, 0, 6), 13, GOLD),
    lbl("Sub", ud(0, 250, 0, 18), ud(0, 12, 0, 28), 11, GREY, font="Gotham"),
    lbl("Timer", ud(0, 70, 0, 26), ud(1, -12, 0, 6), 18, WHITE, align="Right", anchor=(1, 0)),
    lbl("Alive", ud(0, 120, 0, 18), ud(1, -12, 0, 30), 11, GREY, align="Right", font="Gotham", anchor=(1, 0)),
    node("Join", "TextButton", {
        "Size": ud(0, 110, 0, 26), "Position": ud(1, -12, 0, 30), "AnchorPoint": {"Vector2": [1, 0]},
        "BackgroundColor3": {"Color3": [0.25, 0.55, 0.35]}, "Text": "ENTRAR", "Font": "GothamBold", "TextSize": 12,
        "TextColor3": {"Color3": WHITE}, "AutoButtonColor": True, "BorderSizePixel": 0, "Visible": False,
    }, [node("UICorner", "UICorner", {"CornerRadius": {"UDim": [0, 0]}})]),
])

gui = {"className": "ScreenGui", "properties": {"ResetOnSpawn": False, "IgnoreGuiInset": True, "ZIndexBehavior": "Sibling", "DisplayOrder": 4, "Enabled": True},
       "children": [bar]}
OUT.write_text(json.dumps(gui, indent=1) + "\n")
print(OUT)
