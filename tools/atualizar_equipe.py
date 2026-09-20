#!/usr/bin/env python3
"""
atualizar_equipe.py — puxa os membros do grupo FX_Bacons (9835819) da API pública da Roblox e regrava
src/shared/Modules/TeamConfig.luau (NPCs de quest = um por membro; mural dos desenvolvedores na Taberna).
Uso: python3 tools/atualizar_equipe.py   (precisa de internet; roda fora do Studio)
O que está em `EXTRA` (função no time, spot do NPC, frase) é mantido por userId — só o cargo/nome atualiza.
"""
import json
import re
import urllib.request
from pathlib import Path

GROUP = 9835819
OUT = Path(__file__).resolve().parent.parent / "src" / "shared" / "Modules" / "TeamConfig.luau"


def get(url):
    with urllib.request.urlopen(url, timeout=20) as r:
        return json.load(r)


info = get(f"https://groups.roblox.com/v1/groups/{GROUP}")
roles = get(f"https://groups.roblox.com/v1/groups/{GROUP}/roles")["roles"]
members = {}
for role in sorted(roles, key=lambda r: r["rank"]):
    if role["rank"] == 0:
        continue
    data = get(f"https://groups.roblox.com/v1/groups/{GROUP}/roles/{role['id']}/users?limit=100").get("data", [])
    for u in data:
        cur = members.get(u["userId"])
        if not cur or role["rank"] > cur["rank"]:
            members[u["userId"]] = {"userId": u["userId"], "username": u["username"], "displayName": u["displayName"],
                                    "role": role["name"], "rank": role["rank"]}

# extras mantidos do arquivo atual (por userId)
extra = {}
if OUT.exists():
    cur = OUT.read_text()
    for m in re.finditer(r"\{ UserId = (\d+),(.*?)\},\n", cur, re.S):
        extra[int(m.group(1))] = m.group(2)

lines = [
    "--!strict",
    "--[[",
    "\tTeamConfig — a EQUIPE (grupo FX_Bacons %d) para os NPCs de quest e o mural dos desenvolvedores." % GROUP,
    "\tGerado por tools/atualizar_equipe.py (API pública da Roblox); Function/Spot/Quote são editados à mão aqui",
    "\te preservados por UserId quando o script roda de novo. Ordem = cargo (dono primeiro) e depois nome.",
    "]]",
    "",
    "local TeamConfig = {}",
    "",
    "TeamConfig.GroupId = %d" % GROUP,
    "TeamConfig.GroupName = %s" % json.dumps(info["name"], ensure_ascii=False),
    'TeamConfig.Thanks = "Obrigado a cada um que colocou a mão nesse jogo. Sem vocês o Sahur não existiria."',
    "",
    "export type Member = { UserId: number, Username: string, DisplayName: string, Role: string, Rank: number, Function: string, Quote: string }",
    "",
    "TeamConfig.Members = {",
]
for m in sorted(members.values(), key=lambda m: (-m["rank"], m["displayName"].lower())):
    ex = extra.get(m["userId"])
    if ex:
        fn = re.search(r'Function = ("[^"]*")', ex)
        qt = re.search(r'Quote = ("[^"]*")', ex)
        fn = fn.group(1) if fn else '"desenvolvedor"'
        qt = qt.group(1) if qt else '""'
    else:
        fn, qt = '"desenvolvedor"', '""'
    lines.append('\t{ UserId = %d, Username = %s, DisplayName = %s, Role = %s, Rank = %d, Function = %s, Quote = %s },' % (
        m["userId"], json.dumps(m["username"]), json.dumps(m["displayName"], ensure_ascii=False), json.dumps(m["role"], ensure_ascii=False), m["rank"], fn, qt))
lines += ["} :: { Member }", "", "function TeamConfig.ByUserId(userId: number): Member?",
          "\tfor _, m in TeamConfig.Members do", "\t\tif m.UserId == userId then", "\t\t\treturn m", "\t\tend", "\tend", "\treturn nil", "end", "",
          "return TeamConfig", ""]
OUT.write_text("\n".join(lines))
print(OUT, len(members), "membros")
