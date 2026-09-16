#!/usr/bin/env python3
"""
Gera src/ui/MobileGui.model.json: botões de toque no padrão dos battlegrounds (TSB/JJS):
SOCO grande no canto, BLOCK ao lado, DASH acima, golpes 1-4 em arco, ULT, EMOTE, LOCK (shift lock)
e CORRER. Uso: python3 tools/gerar_mobilegui.py
MobileController só mostra em dispositivos com toque e sem teclado; aplica tamanho/opacidade/canhoto
(Controls.Settings) e espelha as posições (atributos BaseX/BaseY/Side de cada botão).
"""

import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "src" / "ui" / "MobileGui.model.json"


def udim2(sx, ox, sy, oy):
    return {"UDim2": [[sx, ox], [sy, oy]]}


def button(name, text, size, x, y, color, text_size=16, side="right"):
    """x/y = distância (px) da borda (direita ou esquerda conforme `side`) e do fundo."""
    anchor = [1, 1] if side == "right" else [0, 1]
    pos = udim2(1, -x, 1, -y) if side == "right" else udim2(0, x, 1, -y)
    return {"name": name, "className": "TextButton", "properties": {
        "Name": name, "Size": udim2(0, size, 0, size), "Position": pos, "AnchorPoint": {"Vector2": anchor},
        "BackgroundColor3": {"Color3": color}, "BackgroundTransparency": 0.35, "Text": text, "TextSize": text_size,
        "Font": "GothamBold", "TextColor3": {"Color3": [1, 1, 1]}, "AutoButtonColor": True, "BorderSizePixel": 0,
    }, "attributes": {"BaseX": x, "BaseY": y, "Side": side}, "children": [
        {"name": "UICorner", "className": "UICorner", "properties": {"CornerRadius": {"UDim": [1, 0]}}},
        {"name": "UIStroke", "className": "UIStroke", "properties": {"Thickness": 2, "Color": {"Color3": [1, 1, 1]}, "Transparency": 0.6}},
    ]}


SKILL = [0.25, 0.25, 0.32]
root = {"name": "Root", "className": "Frame", "properties": {
    "Name": "Root", "Size": udim2(1, 0, 1, 0), "BackgroundTransparency": 1, "Visible": False,
}, "children": [
    {"name": "UIScale", "className": "UIScale", "properties": {"Scale": 1}},
    # grupo da direita (polegar direito): soco, block, dash, golpes em arco, ult, emote, lock
    button("Attack", "SOCO", 92, 20, 20, [0.85, 0.3, 0.25], 20),
    button("Block", "BLOCK", 66, 124, 20, [0.3, 0.55, 0.9], 14),
    button("Dash", "DASH", 60, 122, 98, [0.2, 0.5, 0.45], 14),
    button("Awaken", "ULT", 56, 30, 124, [0.75, 0.6, 0.2], 14),
    button("Slot1", "1", 52, 204, 20, SKILL),
    button("Slot2", "2", 52, 214, 84, SKILL),
    button("Slot3", "3", 52, 196, 148, SKILL),
    button("Slot4", "4", 52, 128, 172, SKILL),
    button("Emote", "EMOTE", 44, 28, 194, [0.45, 0.3, 0.6], 11),
    button("Lock", "LOCK", 44, 80, 232, [0.3, 0.3, 0.38], 11),
    # grupo da esquerda (acima do joystick): correr
    button("Sprint", "CORRER", 56, 150, 150, [0.3, 0.3, 0.38], 12, side="left"),
]}

gui = {"className": "ScreenGui", "properties": {"ResetOnSpawn": False, "DisplayOrder": 2, "IgnoreGuiInset": True},
       "children": [root]}
OUT.write_text(json.dumps(gui, indent=1) + "\n")
print(OUT)
