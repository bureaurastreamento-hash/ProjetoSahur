#!/usr/bin/env python3
"""
Gera src/ui/MobileGui.model.json: botões de toque (soco, block, dash Q, E/R/T).
Uso: python3 tools/gerar_mobilegui.py
MobileController só mostra em dispositivos com toque e sem teclado.
"""

import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "src" / "ui" / "MobileGui.model.json"


def udim2(sx, ox, sy, oy):
    return {"UDim2": [[sx, ox], [sy, oy]]}


def button(name, text, size, pos, color, text_size=18):
    return {"name": name, "className": "TextButton", "properties": {
        "Name": name, "Size": udim2(0, size, 0, size), "Position": pos, "AnchorPoint": {"Vector2": [1, 1]},
        "BackgroundColor3": {"Color3": color}, "BackgroundTransparency": 0.35, "Text": text, "TextSize": text_size,
        "Font": "GothamBold", "TextColor3": {"Color3": [1, 1, 1]}, "AutoButtonColor": True, "BorderSizePixel": 0,
    }, "children": [
        {"name": "UICorner", "className": "UICorner", "properties": {"CornerRadius": {"UDim": [1, 0]}}},
        {"name": "UIStroke", "className": "UIStroke", "properties": {"Thickness": 2, "Color": {"Color3": [1, 1, 1]}, "Transparency": 0.6}},
    ]}


root = {"name": "Root", "className": "Frame", "properties": {
    "Name": "Root", "Size": udim2(1, 0, 1, 0), "BackgroundTransparency": 1, "Visible": False,
}, "children": [
    # soco grande no canto inferior direito; block à esquerda dele; dash + E/R/T em arco acima
    button("Attack", "SOCO", 96, udim2(1, -24, 1, -24), [0.85, 0.3, 0.25], 20),
    button("Block", "BLOCK", 72, udim2(1, -136, 1, -24), [0.3, 0.55, 0.9], 15),
    button("Dash", "DASH", 56, udim2(1, -236, 1, -30), [0.2, 0.5, 0.45], 14),
    button("Slot1", "E", 56, udim2(1, -206, 1, -104), [0.25, 0.25, 0.32]),
    button("Slot2", "R", 56, udim2(1, -140, 1, -150), [0.25, 0.25, 0.32]),
    button("Slot3", "T", 62, udim2(1, -60, 1, -160), [0.6, 0.45, 0.15]),
    button("Awaken", "G", 48, udim2(1, -128, 1, -236), [0.75, 0.6, 0.2], 16),
    # correr (toggle) no canto inferior esquerdo, acima do joystick
    button("Sprint", "CORRER", 64, udim2(0, 150, 1, -140), [0.3, 0.3, 0.38], 13),
]}

gui = {"className": "ScreenGui", "properties": {"ResetOnSpawn": False, "DisplayOrder": 2, "IgnoreGuiInset": True},
       "children": [root]}
OUT.write_text(json.dumps(gui, indent=1) + "\n")
print(OUT)
