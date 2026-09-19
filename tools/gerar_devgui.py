#!/usr/bin/env python3
"""
Gera src/ui/DevGui.model.json (StarterGui.DevGui): menu de desenvolvedor.
Uso: python3 tools/gerar_devgui.py
Ligado por nome em DevController; o servidor (AdminService) é a autoridade.

Layout: painel 620x640 com seções. Botões "toggle" mostram ON/OFF pelo estado que o
servidor devolve (GetState). Nomes dos botões = nome do comando no AdminService.
"""

import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "src" / "ui" / "DevGui.model.json"

BG = [0.078, 0.078, 0.110]
BG2 = [0.13, 0.13, 0.17]
ACCENT = [0.35, 0.65, 1.0]
WHITE = [1, 1, 1]
GREY = [0.75, 0.75, 0.78]
RED = [0.75, 0.25, 0.25]
GREEN = [0.25, 0.55, 0.35]

W, H = 620, 1100
PAD = 12
COL_W = (W - PAD * 2 - 8 * 3) // 4  # 4 colunas


def udim2(sx, ox, sy, oy):
    return {"UDim2": [[sx, ox], [sy, oy]]}


def node(name, cls, props=None, children=None):
    p = {"Name": name}
    p.update(props or {})
    return {"name": name, "className": cls, "properties": p, "children": children or []}


def corner(r=6):
    return node("UICorner", "UICorner", {"CornerRadius": {"UDim": [0, r]}})


def label(name, text, size, pos, text_size=13, color=WHITE, font="Gotham", align="Left"):
    return node(name, "TextLabel", {
        "Size": size, "Position": pos, "BackgroundTransparency": 1, "Text": text, "TextSize": text_size,
        "Font": font, "TextColor3": {"Color3": color}, "TextXAlignment": align, "TextTruncate": "AtEnd",
    })


def button(name, text, size, pos, color=BG2, text_size=12, visible=True):
    return node(name, "TextButton", {
        "Size": size, "Position": pos, "BackgroundColor3": {"Color3": color}, "Text": text, "TextSize": text_size,
        "Font": "GothamBold", "TextColor3": {"Color3": WHITE}, "AutoButtonColor": True, "BorderSizePixel": 0,
        "Visible": visible,
    }, [corner()])


def textbox(name, placeholder, size, pos, text=""):
    return node(name, "TextBox", {
        "Size": size, "Position": pos, "BackgroundColor3": {"Color3": BG2}, "Text": text,
        "PlaceholderText": placeholder, "PlaceholderColor3": {"Color3": [0.5, 0.5, 0.55]}, "TextSize": 13,
        "Font": "Gotham", "TextColor3": {"Color3": WHITE}, "ClearTextOnFocus": False, "BorderSizePixel": 0,
    }, [corner()])


def section(name, text, y):
    return label(name, text, udim2(1, -PAD * 2, 0, 16), udim2(0, PAD, 0, y), 11, ACCENT, "GothamBold")


def col_x(c):
    return PAD + c * (COL_W + 8)


children = [
    corner(8),
    label("Title", "DEV", udim2(0, 60, 0, 28), udim2(0, PAD, 0, 6), 20, ACCENT, "GothamBold"),
    label("Subtitle", "só nicks em AdminConfig · servidor valida e loga tudo", udim2(1, -150, 0, 28), udim2(0, 60, 0, 6), 11, GREY),
    button("Close", "X", udim2(0, 26, 0, 26), udim2(1, -PAD - 26, 0, 8)),
]
y = 40

# ---- Alvo ------------------------------------------------------------------
children.append(section("TargetSection", "ALVO", y)); y += 18
children.append(node("Targets", "ScrollingFrame", {
    "Size": udim2(1, -PAD * 2, 0, 32), "Position": udim2(0, PAD, 0, y), "BackgroundColor3": {"Color3": BG2},
    "BackgroundTransparency": 0.5, "ScrollingDirection": "X", "AutomaticCanvasSize": "X",
    "CanvasSize": udim2(0, 0, 0, 0), "ScrollBarThickness": 3, "BorderSizePixel": 0,
}, [
    corner(),
    node("UIListLayout", "UIListLayout", {"FillDirection": "Horizontal", "Padding": {"UDim": [0, 4]},
                                          "SortOrder": "LayoutOrder", "VerticalAlignment": "Center"}),
    node("UIPadding", "UIPadding", {"PaddingLeft": {"UDim": [0, 4]}}),
    button("Template", "Jogador", udim2(0, 110, 0, 24), udim2(0, 0, 0, 0), visible=False),
]))
y += 36
children.append(label("State", "—", udim2(1, -PAD * 2, 0, 30), udim2(0, PAD, 0, y), 11, GREY))
y += 32

# ---- Jogador ----------------------------------------------------------------
children.append(section("PlayerSection", "JOGADOR  (toggles mostram o estado do alvo)", y)); y += 18
toggles = [("InfiniteEnergy", "Energia ∞"), ("NoCooldown", "Sem cooldown"), ("God", "Modo deus"), ("ClearFlags", "Limpar flags")]
for i, (cmd, text) in enumerate(toggles):
    children.append(button(cmd, text, udim2(0, COL_W, 0, 28), udim2(0, col_x(i), 0, y)))
y += 34
# linhas: campo + botão Set
rows = [
    ("Coins", "moedas", "SetCoins", "Definir", "AddCoins", "Somar"),
    ("Energy", "energia 0-100", "SetEnergy", "Definir", "ResetCooldowns", "Zerar CDs"),
    ("Health", "vida", "SetHealth", "Definir", "Heal", "Curar"),
    ("Speed", "WalkSpeed (16)", "SetSpeed", "Definir", "Respawn", "Respawn"),
    ("DamageMult", "dano x (1)", "SetDamageMult", "Definir", "Kill", "Matar"),
    ("XP", "XP", "AddXP", "Somar XP", "CompleteAchievements", "Conquistas OK"),
]
for i, (box, ph, cmd1, t1, cmd2, t2) in enumerate(rows):
    yy = y + i * 32
    children.append(textbox(box, ph, udim2(0, COL_W * 2 + 8, 0, 28), udim2(0, col_x(0), 0, yy)))
    children.append(button(cmd1, t1, udim2(0, COL_W, 0, 28), udim2(0, col_x(2), 0, yy)))
    children.append(button(cmd2, t2, udim2(0, COL_W, 0, 28), udim2(0, col_x(3), 0, yy), RED if cmd2 == "Kill" else BG2))
y += 32 * len(rows) + 4

# ---- Personagens --------------------------------------------------------------
children.append(section("CharSection", "PERSONAGENS  (clique = usar · Shift = dar · Ctrl = tirar)", y)); y += 18
children.append(node("Characters", "Frame", {
    "Size": udim2(1, -PAD * 2 - COL_W * 2 - 16, 0, 28), "Position": udim2(0, PAD, 0, y), "BackgroundTransparency": 1,
}, [
    node("UIListLayout", "UIListLayout", {"FillDirection": "Horizontal", "Padding": {"UDim": [0, 4]}, "SortOrder": "LayoutOrder"}),
    button("Template", "Char", udim2(0, 82, 0, 28), udim2(0, 0, 0, 0), visible=False),
]))
children.append(button("GrantAll", "Dar todos", udim2(0, COL_W, 0, 28), udim2(0, col_x(2), 0, y), GREEN))
children.append(button("RevokeAll", "Tirar todos", udim2(0, COL_W, 0, 28), udim2(0, col_x(3), 0, y), RED))
y += 36

# ---- Jogadores / servidor -------------------------------------------------------
children.append(section("ActionSection", "JOGADORES", y)); y += 18
actions = [("Teleport", "Ir até", BG2), ("Bring", "Trazer", BG2), ("Kick", "Kick", RED), ("ResetData", "Zerar dados", RED)]
for i, (cmd, text, color) in enumerate(actions):
    children.append(button(cmd, text, udim2(0, COL_W, 0, 28), udim2(0, col_x(i), 0, y), color))
y += 32
actions2 = [("TeleportArena", "Ir para a arena", BG2), ("Spectate", "Assistir alvo (de novo p/ parar)", BG2)]
for i, (cmd, text, color) in enumerate(actions2):
    children.append(button(cmd, text, udim2(0, COL_W * 2 + 8, 0, 28), udim2(0, col_x(i * 2), 0, y), color))
children.append(button("JoinPlayerServer", "Entrar no servidor (nome na caixa)", udim2(0, COL_W * 2 + 8, 0, 28), udim2(0, col_x(2), 0, y)))
y += 36

# ---- Denúncias ----------------------------------------------------------------
children.append(section("ReportSection", "DENÚNCIAS", y)); y += 18
children.append(button("GetReports", "Ver denúncias do ALVO selecionado", udim2(0, COL_W * 2 + 8, 0, 28), udim2(0, col_x(0), 0, y), GREEN))
children.append(button("GetReportsByName", "Buscar por nome (caixa Message)", udim2(0, COL_W * 2 + 8, 0, 28), udim2(0, col_x(2), 0, y)))
y += 36

children.append(section("AdminSection", "ADMINISTRAÇÃO  (mensagem na caixa; Ban/Enviar usam o alvo)", y)); y += 18
children.append(textbox("Message", "mensagem / motivo do ban / nome para desbanir", udim2(0, COL_W * 3 + 16, 0, 28), udim2(0, col_x(0), 0, y)))
children.append(textbox("BanDays", "dias (0 = perm.)", udim2(0, COL_W, 0, 28), udim2(0, col_x(3), 0, y)))
y += 32
admin = [("AnnounceGlobal", "Mensagem GLOBAL", GREEN), ("AnnounceServer", "Mensagem no servidor", BG2), ("Announce", "Enviar ao alvo", BG2), ("Ban", "BANIR alvo", RED)]
for i, (cmd, text, color) in enumerate(admin):
    children.append(button(cmd, text, udim2(0, COL_W, 0, 28), udim2(0, col_x(i), 0, y), color))
y += 32
children.append(button("Unban", "Desbanir (nome na caixa)", udim2(0, COL_W * 2 + 8, 0, 28), udim2(0, col_x(0), 0, y)))
y += 36

children.append(section("TestSection", "COMBATE / TESTES  (alvo)", y)); y += 18
tests = [("Fly", "Voar", BG2), ("Awaken", "ULT + despertar", GREEN), ("Ragdoll", "Ragdoll 2 s", BG2), ("ClearAntiExploit", "Zerar anti-exploit", BG2)]
for i, (cmd, text, color) in enumerate(tests):
    children.append(button(cmd, text, udim2(0, COL_W, 0, 28), udim2(0, col_x(i), 0, y), color))
y += 32
children.append(textbox("Streak", "kill streak", udim2(0, COL_W, 0, 28), udim2(0, col_x(0), 0, y)))
children.append(button("SetStreak", "Definir streak", udim2(0, COL_W, 0, 28), udim2(0, col_x(1), 0, y)))
children.append(button("GrantCosmetics", "Dar cosméticos", udim2(0, COL_W, 0, 28), udim2(0, col_x(2), 0, y), GREEN))
children.append(button("ResetCosmetics", "Zerar cosméticos", udim2(0, COL_W, 0, 28), udim2(0, col_x(3), 0, y), RED))
y += 36

children.append(section("WorldSection", "MUNDO / SERVIDOR", y)); y += 18
world = [("RespawnDummies", "Recriar bonecos"), ("ToggleDummies", "Bonecos ON/OFF"), ("RefreshLeaderboard", "Atualizar placar"), ("ServerInfo", "Info servidor")]
for i, (cmd, text) in enumerate(world):
    children.append(button(cmd, text, udim2(0, COL_W, 0, 28), udim2(0, col_x(i), 0, y)))
y += 32
children.append(button("SummonBoss", "Invocar boss", udim2(0, COL_W, 0, 28), udim2(0, col_x(0), 0, y), GREEN))
children.append(button("DespawnBoss", "Remover boss", udim2(0, COL_W, 0, 28), udim2(0, col_x(1), 0, y), RED))
children.append(button("BringDummy", "Trazer boneco", udim2(0, COL_W, 0, 28), udim2(0, col_x(2), 0, y)))
children.append(button("InspectBoss", "Inspecionar BossModel", udim2(0, COL_W * 2 + 8, 0, 28), udim2(0, col_x(2), 0, y)))
y += 32
children.append(textbox("Time", "hora 0-24", udim2(0, COL_W, 0, 28), udim2(0, col_x(0), 0, y)))
children.append(button("SetTime", "Congelar hora", udim2(0, COL_W, 0, 28), udim2(0, col_x(1), 0, y)))
children.append(button("ListPlayers", "Listar online", udim2(0, COL_W, 0, 28), udim2(0, col_x(2), 0, y)))
children.append(button("GetState", "Atualizar estado", udim2(0, COL_W, 0, 28), udim2(0, col_x(3), 0, y)))
y += 32
children.append(button("SetDay", "DIA", udim2(0, COL_W, 0, 28), udim2(0, col_x(0), 0, y)))
children.append(button("SetNight", "NOITE", udim2(0, COL_W, 0, 28), udim2(0, col_x(1), 0, y), BG2))
children.append(button("TimeAuto", "Ciclo automático", udim2(0, COL_W, 0, 28), udim2(0, col_x(2), 0, y)))
children.append(button("GiveArrow", "Me dar a flecha", udim2(0, COL_W, 0, 28), udim2(0, col_x(3), 0, y), GREEN))
y += 32
children.append(button("RespawnArrow", "Sortear flecha", udim2(0, COL_W, 0, 28), udim2(0, col_x(0), 0, y)))
children.append(button("BecomeBoss", "Virar Big CHOP", udim2(0, COL_W, 0, 28), udim2(0, col_x(1), 0, y), GREEN))
children.append(button("EndBossForm", "Encerrar forma", udim2(0, COL_W, 0, 28), udim2(0, col_x(2), 0, y), RED))
children.append(button("TestSounds", "Testar sons dos packs", udim2(0, COL_W, 0, 28), udim2(0, col_x(3), 0, y)))
y += 32
children.append(button("PreviewVfx", "Preview VFX (F7)", udim2(0, COL_W * 2 + 8, 0, 28), udim2(0, col_x(0), 0, y), GREEN))
children.append(button("Trailer", "TRAILER (~70 s)", udim2(0, COL_W, 0, 28), udim2(0, col_x(2), 0, y), GREEN))
children.append(button("TrailerStop", "Parar trailer", udim2(0, COL_W, 0, 28), udim2(0, col_x(3), 0, y), RED))
y += 32
children.append(button("StartEvent", "EVENTO no Canion (leva todos)", udim2(0, COL_W * 2 + 8, 0, 28), udim2(0, col_x(0), 0, y), GREEN))
children.append(button("EndEvent", "Encerrar evento (volta todos)", udim2(0, COL_W * 2 + 8, 0, 28), udim2(0, col_x(2), 0, y), RED))
y += 36

# ---- Log --------------------------------------------------------------------------
children.append(section("LogSection", "RESULTADO", y)); y += 18
children.append(node("Log", "TextLabel", {
    "Size": udim2(1, -PAD * 2 - 8, 0, H - y - PAD), "Position": udim2(0, PAD, 0, y), "BackgroundColor3": {"Color3": BG2},
    "BackgroundTransparency": 0.5, "Text": "", "TextSize": 11, "Font": "Code", "TextColor3": {"Color3": GREY},
    "TextXAlignment": "Left", "TextYAlignment": "Top", "TextWrapped": True, "BorderSizePixel": 0,
}, [corner(), node("UIPadding", "UIPadding", {"PaddingLeft": {"UDim": [0, 6]}, "PaddingTop": {"UDim": [0, 4]}})]))

# ScrollingFrame: em telas baixas (laptop) o painel rola em vez de sair da tela
panel = node("Panel", "ScrollingFrame", {
    "Size": udim2(0, W, 0.92, 0), "Position": udim2(0.5, 0, 0.5, 0), "AnchorPoint": {"Vector2": [0.5, 0.5]},
    "BackgroundColor3": {"Color3": BG}, "BackgroundTransparency": 0.08, "Visible": False, "Active": True,
    "BorderSizePixel": 0, "CanvasSize": udim2(0, 0, 0, H), "ScrollBarThickness": 6, "ScrollingDirection": "Y",
    "AutomaticCanvasSize": "None",
}, children)

gui = {"className": "ScreenGui", "properties": {"ResetOnSpawn": False, "DisplayOrder": 10, "IgnoreGuiInset": False},
       "children": [panel]}
OUT.write_text(json.dumps(gui, indent=1) + "\n")
print(OUT, "altura usada:", y)
