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

W = 620
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


# Painel em ABAS (dono, 2026-09-21: "menu DEV mais prático, ADM primeiro"): ADM / MAPA / TESTE.
# Nomes dos botões continuam = comando do AdminService; o DevController acha por nome (recursivo).
# Ações perigosas (Kill/Kick/Ban/ResetData...) pedem 2º clique no cliente (DevController.CONFIRM).

children = [
    corner(8),
    label("Title", "DEV", udim2(0, 60, 0, 28), udim2(0, PAD, 0, 6), 20, ACCENT, "GothamBold"),
    label("Subtitle", "só nicks em AdminConfig · servidor valida e loga tudo · vermelho = pede 2º clique", udim2(1, -150, 0, 28), udim2(0, 60, 0, 6), 11, GREY),
    button("Close", "X", udim2(0, 26, 0, 26), udim2(1, -PAD - 26, 0, 8)),
]
y = 40

# ---- Alvo (comum às abas): busca + lista clicável -----------------------------------
children.append(section("TargetSection", "ALVO  (clique na lista ou digite parte do nome)", y)); y += 18
children.append(textbox("PlayerSearch", "buscar jogador…", udim2(0, COL_W, 0, 32), udim2(0, PAD, 0, y)))
children.append(node("Targets", "ScrollingFrame", {
    "Size": udim2(1, -PAD * 2 - COL_W - 8, 0, 32), "Position": udim2(0, PAD + COL_W + 8, 0, y), "BackgroundColor3": {"Color3": BG2},
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
y += 34

# ---- Abas -------------------------------------------------------------------------------
TABS = [("Adm", "ADM"), ("Mapa", "MAPA"), ("Teste", "TESTE")]
children.append(node("Tabs", "Frame", {
    "Size": udim2(1, -PAD * 2, 0, 30), "Position": udim2(0, PAD, 0, y), "BackgroundTransparency": 1,
}, [node("UIListLayout", "UIListLayout", {"FillDirection": "Horizontal", "Padding": {"UDim": [0, 6]}, "SortOrder": "LayoutOrder"})]
   + [button("Tab" + key, text, udim2(0, COL_W, 0, 30), udim2(0, 0, 0, 0), ACCENT if i == 0 else BG2, 13) for i, (key, text) in enumerate(TABS)]))
y += 36
PAGE_Y = y


class Page:
    """Uma aba: acumula filhos com y próprio (relativo ao Frame da página)."""

    def __init__(self, key):
        self.key = key
        self.kids = []
        self.y = 0

    def section(self, name, text):
        self.kids.append(section(name, text, self.y)); self.y += 18

    def row(self, items, h=28, gap=4):
        """items = [(nome, texto, cor|None, largura em colunas)] numa linha; None = pula coluna."""
        c = 0
        for it in items:
            if it is None:
                c += 1
                continue
            name, text, color, span = it
            w = COL_W * span + 8 * (span - 1)
            self.kids.append(button(name, text, udim2(0, w, 0, h), udim2(0, col_x(c), 0, self.y), color or BG2))
            c += span
        self.y += h + gap

    def box_row(self, box, ph, buttons, h=28):
        """caixa de texto (2 colunas) + até 2 botões."""
        self.kids.append(textbox(box, ph, udim2(0, COL_W * 2 + 8, 0, h), udim2(0, col_x(0), 0, self.y)))
        for i, (name, text, color) in enumerate(buttons):
            self.kids.append(button(name, text, udim2(0, COL_W, 0, h), udim2(0, col_x(2 + i), 0, self.y), color or BG2))
        self.y += h + 4

    def gap(self, px=6):
        self.y += px

    def frame(self, visible):
        return node("Page" + self.key, "Frame", {
            "Size": udim2(1, -PAD * 2, 0, self.y), "Position": udim2(0, PAD, 0, PAGE_Y), "BackgroundTransparency": 1,
            "Visible": visible,
        }, self.kids)


# ===== ADM =====================================================================================
adm = Page("Adm")
adm.section("PlayersSection", "JOGADOR ALVO")
adm.row([("Teleport", "Ir até o alvo", None, 1), ("Bring", "Trazer o alvo", None, 1), ("Spectate", "Assistir (de novo = parar)", None, 1), ("TeleportArena", "Ir para a arena", None, 1)])
adm.box_row("Message", "mensagem · motivo do kick/ban · nick (entrar no servidor / desbanir / denúncias)", [("Announce", "Enviar ao alvo", None), ("JoinPlayerServer", "Entrar no servidor", None)])
adm.row([("AnnounceServer", "Mensagem no servidor", None, 1), ("AnnounceGlobal", "Mensagem GLOBAL", GREEN, 1), ("Kick", "KICK alvo", RED, 1), ("ResetData", "ZERAR dados do alvo", RED, 1)])
adm.row([("PublishUpdate", "PUBLICAR novidades (UpdateLogConfig.Current, todos os servidores)", GREEN, 2)])
adm.gap()
adm.section("BanSection", "BAN  (motivo na caixa acima)")
adm.kids.append(textbox("BanDays", "dias (0 = permanente)", udim2(0, COL_W, 0, 28), udim2(0, col_x(0), 0, adm.y)))
adm.kids.append(button("Ban", "BANIR alvo", udim2(0, COL_W, 0, 28), udim2(0, col_x(1), 0, adm.y), RED))
adm.kids.append(button("Unban", "Desbanir (nick na caixa)", udim2(0, COL_W * 2 + 8, 0, 28), udim2(0, col_x(2), 0, adm.y)))
adm.y += 32
adm.gap()
adm.section("ReportSection", "DENÚNCIAS")
adm.row([("GetReports", "Ver denúncias do alvo", GREEN, 2), ("GetReportsByName", "Buscar por nick (caixa acima)", None, 2)])
adm.gap()
adm.section("GiveSection", "DAR AO ALVO")
adm.box_row("Coins", "pontos", [("AddCoins", "Somar pontos", GREEN), ("SetCoins", "Definir pontos", None)])
adm.box_row("EventPoints", "pontos de evento", [("AddEventPoints", "Somar evento", GREEN)])
adm.box_row("XP", "XP", [("AddXP", "Somar XP", GREEN), ("CompleteAchievements", "Conquistas OK", None)])
adm.box_row("ItemId", "id do item (cosmético / emote / personagem / limitado do passe)", [("GrantItem", "Dar item", GREEN), ("GrantCosmetics", "Dar TODOS cosméticos", None)])
adm.section("CharSection", "PERSONAGENS  (clique = usar · Shift = dar · Ctrl = tirar)")
adm.kids.append(node("Characters", "Frame", {
    "Size": udim2(1, 0, 0, 28), "Position": udim2(0, 0, 0, adm.y), "BackgroundTransparency": 1,
}, [
    node("UIListLayout", "UIListLayout", {"FillDirection": "Horizontal", "Padding": {"UDim": [0, 4]}, "SortOrder": "LayoutOrder"}),
    button("Template", "Char", udim2(0, 82, 0, 28), udim2(0, 0, 0, 0), visible=False),
]))
adm.y += 32
adm.row([None, None, ("GrantAll", "Dar todos", GREEN, 1), ("RevokeAll", "Tirar todos", RED, 1)])

# ===== MAPA ====================================================================================
mapa = Page("Mapa")
mapa.section("BossSection", "BOSS  (Big C.H.O.P.)")
mapa.row([("SummonBoss", "Invocar (santuário)", GREEN, 1), ("SummonBossStrong", "Invocar x3 À SOLTA", GREEN, 1), ("KillBoss", "Matar boss (com loot)", RED, 1), ("DespawnBoss", "Remover boss", RED, 1)])
mapa.row([("BecomeBoss", "Virar Big CHOP", GREEN, 1), ("EndBossForm", "Encerrar forma", RED, 1), ("InspectBoss", "Inspecionar rig", None, 1)])
mapa.gap()
mapa.section("QuestSection", "HISTÓRIA / TRAIDOR  (capítulo é por ALVO)")
mapa.box_row("QuestChapter", "capítulo (1 = início · 8 = final · 9 = zerada)", [("SetQuestChapter", "Pular p/ capítulo", None), ("SummonTraitor", "Invocar traidor", GREEN)])
mapa.row([("KillTraitor", "Matar traidor", RED, 1), ("DespawnTraitor", "Remover traidor", RED, 1)])
mapa.gap()
mapa.section("BotSection", "BOTS  (combate REAL: M1, dash, habilidades, ult · nascem na sua frente)")
mapa.box_row("BotCharacter", "personagem do bot (vazio = roda a lista: Jotaro, Swift, Dio, Kira...)", [("SpawnBotPassive", "Bot: só revida", GREEN), ("SpawnBotAggressive", "Bot: agressivo", GREEN)])
mapa.row([("SpawnBotIdle", "Bot: parado (alvo)", None, 1), ("BotsFill", "Encher ult dos bots", None, 1), ("BotsPassive", "Todos: só revidam", None, 1), ("BotsAggressive", "Todos: agressivos", None, 1)])
mapa.row([("BotsIdle", "Todos: parados", None, 1), ("ClearBots", "Remover bots", RED, 1)])
mapa.gap()
mapa.section("ArrowSection", "FLECHA")
mapa.row([("GiveArrow", "Me dar a flecha", GREEN, 1), ("TakeArrow", "Tirar / devolver ao mapa", None, 1), ("RespawnArrow", "Sortear flecha", None, 1)])
mapa.gap()
mapa.section("TimeSection", "DIA / NOITE")
mapa.kids.append(textbox("Time", "hora 0-24", udim2(0, COL_W, 0, 28), udim2(0, col_x(0), 0, mapa.y)))
mapa.kids.append(button("SetTime", "Congelar hora", udim2(0, COL_W, 0, 28), udim2(0, col_x(1), 0, mapa.y)))
mapa.kids.append(button("SetDay", "DIA", udim2(0, COL_W, 0, 28), udim2(0, col_x(2), 0, mapa.y)))
mapa.kids.append(button("SetNight", "NOITE", udim2(0, COL_W, 0, 28), udim2(0, col_x(3), 0, mapa.y)))
mapa.y += 32
mapa.row([("TimeAuto", "Ciclo automático", None, 1)])
mapa.gap()
mapa.section("TournamentSection", "TORNEIO ÚLTIMO DE PÉ  (inscrição 90 s · quem morre sai · prêmio na caixa; vazio = padrão)")
mapa.box_row("TournamentPrize", "prêmio: pontos, evento, xp, cosmético (ex.: 1500, 300, 800, cape_gold)", [("TournamentOpen_solo", "Abrir: SOLO", GREEN), ("TournamentOpen_duo", "Abrir: DUPLAS", GREEN)])
mapa.row([("TournamentOpen_clan", "Abrir: CLÃS", GREEN, 1), ("TournamentStart", "Fechar e INICIAR", None, 1), ("TournamentCancel", "Cancelar torneio", RED, 1)])
mapa.gap()
mapa.section("WorldSection", "CENÁRIO / SERVIDOR")
mapa.row([("RestoreDestructibles", "Restaurar cenário destrutível", GREEN, 2), ("StartEvent", "EVENTO no Canion", GREEN, 1), ("EndEvent", "Encerrar evento", RED, 1)])
mapa.row([("RespawnDummies", "Recriar bonecos", None, 1), ("ToggleDummies", "Bonecos ON/OFF", None, 1), ("BringDummy", "Trazer boneco", None, 1), ("RefreshLeaderboard", "Atualizar placar", None, 1)])
mapa.row([("ServerInfo", "Info servidor", None, 1), ("ListPlayers", "Listar online", None, 1), ("GetState", "Atualizar estado", None, 1)])

# ===== TESTE ===================================================================================
teste = Page("Teste")
teste.section("PlayerSection", "ALVO  (toggles mostram o estado)")
teste.row([("God", "Modo deus", None, 1), ("InfiniteEnergy", "Energia ∞", None, 1), ("NoCooldown", "Sem cooldown", None, 1), ("Fly", "Voar", None, 1)])
teste.row([("Heal", "Curar", GREEN, 1), ("Awaken", "ULT + despertar", GREEN, 1), ("ResetCooldowns", "Zerar CDs", None, 1), ("ClearFlags", "Limpar flags", None, 1)])
teste.row([("Respawn", "Respawn", None, 1), ("Ragdoll", "Ragdoll 2 s", None, 1), ("ClearAntiExploit", "Zerar anti-exploit", None, 1), ("Kill", "Matar", RED, 1)])
teste.box_row("Energy", "energia 0-100", [("SetEnergy", "Definir", None)])
teste.box_row("Health", "vida", [("SetHealth", "Definir", None)])
teste.box_row("Speed", "WalkSpeed (16)", [("SetSpeed", "Definir", None)])
teste.box_row("DamageMult", "dano x (1)", [("SetDamageMult", "Definir", None)])
teste.box_row("Streak", "kill streak (10 = coroa)", [("SetStreak", "Definir", None), ("ResetCosmetics", "Zerar cosméticos", RED)])
teste.gap()
teste.section("ToolsSection", "FERRAMENTAS")
teste.row([("PreviewVfx", "Preview VFX (F7)", GREEN, 1), ("TestSounds", "Testar sons dos packs", None, 1)])
teste.gap()
teste.section("TrailerSection", "TRAILER  (cenas com bots reais · grave a tela)")
teste.row([("Trailer", "TRAILER COMPLETO (~95 s)", GREEN, 2), ("TrailerStop", "Parar / desfazer", RED, 1), ("SceneWithMe", "Comigo na cena", None, 1)])
teste.row([("Scene_combo", "Combo", None, 1), ("Scene_parry", "Parry · Black Flash", None, 1), ("Scene_dash", "Dash = hit", None, 1), ("Scene_brawl", "Briga (4 bots)", None, 1)])
teste.row([("Scene_boss", "Boss no santuário", None, 1), ("Scene_abilities", "Habilidades (todos)", None, 1)])
teste.section("SceneAbilSection", "HABILIDADES 1..3 por personagem")
teste.row([("SceneAbil_Jotaro", "Jotaro", None, 1), ("SceneAbil_Swift", "Bruno Gollini", None, 1), ("SceneAbil_Dio", "Dio", None, 1), ("SceneAbil_Kira", "Kira", None, 1)])
teste.row([("SceneAbil_Rick", "Rick", None, 1)])
teste.section("SceneUltSection", "DESPERTAR + ULT por personagem")
teste.row([("SceneUlt_Jotaro", "Jotaro", None, 1), ("SceneUlt_Swift", "Bruno Gollini", None, 1), ("SceneUlt_Dio", "Dio", None, 1), ("SceneUlt_Kira", "Kira", None, 1)])
teste.row([("SceneUlt_Rick", "Rick", None, 1)])

pages = [adm, mapa, teste]
for i, pg in enumerate(pages):
    children.append(pg.frame(i == 0))
y = PAGE_Y + max(pg.y for pg in pages) + 4

# ---- Log --------------------------------------------------------------------------
children.append(section("LogSection", "RESULTADO", y)); y += 18
LOG_H = 110
children.append(node("Log", "TextLabel", {
    "Size": udim2(1, -PAD * 2 - 8, 0, LOG_H), "Position": udim2(0, PAD, 0, y), "BackgroundColor3": {"Color3": BG2},
    "BackgroundTransparency": 0.5, "Text": "", "TextSize": 11, "Font": "Code", "TextColor3": {"Color3": GREY},
    "TextXAlignment": "Left", "TextYAlignment": "Top", "TextWrapped": True, "BorderSizePixel": 0,
}, [corner(), node("UIPadding", "UIPadding", {"PaddingLeft": {"UDim": [0, 6]}, "PaddingTop": {"UDim": [0, 4]}})]))
y += LOG_H + PAD
H = y

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
