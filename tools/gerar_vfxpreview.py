#!/usr/bin/env python3
"""Gera src/ui/VfxPreviewGui.model.json: lista pesquisável dos VFX dos packs (menu Dev > Preview VFX)."""
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "src" / "ui" / "VfxPreviewGui.model.json"
BG = [0.078, 0.078, 0.110]; BG2 = [0.13, 0.13, 0.17]; ACCENT = [0.35, 0.65, 1.0]; WHITE = [1, 1, 1]; GREY = [0.75, 0.75, 0.78]


def udim2(sx, ox, sy, oy):
    return {"UDim2": [[sx, ox], [sy, oy]]}


def node(name, cls, props=None, children=None):
    p = {"Name": name}; p.update(props or {})
    return {"name": name, "className": cls, "properties": p, "children": children or []}


def corner(r=6):
    return node("UICorner", "UICorner", {"CornerRadius": {"UDim": [0, r]}})


panel = node("Panel", "Frame", {
    "Size": udim2(0, 360, 0, 560), "Position": udim2(1, -16, 0.5, 0), "AnchorPoint": {"Vector2": [1, 0.5]},
    "BackgroundColor3": {"Color3": BG}, "BackgroundTransparency": 0.08, "Visible": False, "Active": True, "BorderSizePixel": 0,
}, [
    corner(8),
    node("Title", "TextLabel", {"Size": udim2(1, -60, 0, 28), "Position": udim2(0, 12, 0, 6), "BackgroundTransparency": 1,
                                "Text": "PREVIEW DE VFX", "TextSize": 16, "Font": "GothamBold", "TextColor3": {"Color3": ACCENT}, "TextXAlignment": "Left"}),
    node("Close", "TextButton", {"Size": udim2(0, 26, 0, 26), "Position": udim2(1, -38, 0, 8), "BackgroundColor3": {"Color3": BG2},
                                 "Text": "X", "TextSize": 12, "Font": "GothamBold", "TextColor3": {"Color3": WHITE}, "BorderSizePixel": 0}, [corner()]),
    node("Search", "TextBox", {"Size": udim2(1, -24, 0, 28), "Position": udim2(0, 12, 0, 40), "BackgroundColor3": {"Color3": BG2},
                               "Text": "", "PlaceholderText": "filtrar (ex.: hit, slam, aura, Gojo)", "PlaceholderColor3": {"Color3": [0.5, 0.5, 0.55]},
                               "TextSize": 13, "Font": "Gotham", "TextColor3": {"Color3": WHITE}, "ClearTextOnFocus": False, "BorderSizePixel": 0}, [corner()]),
    node("Hint", "TextLabel", {"Size": udim2(1, -24, 0, 30), "Position": udim2(0, 12, 0, 72), "BackgroundTransparency": 1,
                               "Text": "clique = toca em você · Shift = toca 12 studs à frente\ncaminho vai para o log do menu Dev e para o Output", "TextSize": 11,
                               "Font": "Gotham", "TextColor3": {"Color3": GREY}, "TextXAlignment": "Left", "TextYAlignment": "Top"}),
    node("Count", "TextLabel", {"Size": udim2(1, -24, 0, 16), "Position": udim2(0, 12, 0, 104), "BackgroundTransparency": 1,
                                "Text": "", "TextSize": 11, "Font": "GothamBold", "TextColor3": {"Color3": GREY}, "TextXAlignment": "Left"}),
    node("List", "ScrollingFrame", {"Size": udim2(1, -24, 1, -134), "Position": udim2(0, 12, 0, 122), "BackgroundColor3": {"Color3": BG2},
                                    "BackgroundTransparency": 0.5, "ScrollBarThickness": 4, "AutomaticCanvasSize": "Y", "CanvasSize": udim2(0, 0, 0, 0),
                                    "BorderSizePixel": 0}, [
        corner(),
        node("UIListLayout", "UIListLayout", {"Padding": {"UDim": [0, 2]}, "SortOrder": "LayoutOrder"}),
        node("UIPadding", "UIPadding", {"PaddingLeft": {"UDim": [0, 4]}, "PaddingRight": {"UDim": [0, 4]}, "PaddingTop": {"UDim": [0, 4]}}),
        node("Template", "TextButton", {"Size": udim2(1, -8, 0, 22), "BackgroundColor3": {"Color3": BG}, "Text": "x", "TextSize": 11,
                                        "Font": "Code", "TextColor3": {"Color3": WHITE}, "TextXAlignment": "Left", "TextTruncate": "AtEnd",
                                        "Visible": False, "AutoButtonColor": True, "BorderSizePixel": 0}, [corner(4)]),
    ]),
])
gui = {"className": "ScreenGui", "properties": {"ResetOnSpawn": False, "DisplayOrder": 11, "IgnoreGuiInset": False}, "children": [panel]}
OUT.write_text(json.dumps(gui, indent=1) + "\n"); print(OUT)
