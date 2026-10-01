#!/usr/bin/env python3
"""Cria os 5 Developer Products de doação do pré-lançamento (Open Cloud) e grava os ids em LaunchConfig.Donations.

Precisa de ROBLOX_API_KEY (chave do GRUPO) com o sistema `developer-products` (developer-product:read e :write) no
universo do jogo. Idempotente: produto com o mesmo nome já existente é reaproveitado, não duplicado.
Uso: python3 tools/criar_doacoes.py [--dry]
"""
import json, os, re, sys, urllib.request, uuid
from pathlib import Path

UNIVERSE = 10766480907  # place oficial 85844807133499
BASE = f"https://apis.roblox.com/developer-products/v2/universes/{UNIVERSE}/developer-products"
CONFIG = Path(__file__).resolve().parent.parent / "src/shared/Modules/LaunchConfig.luau"
VALORES = (10, 50, 100, 500, 1000)
KEY = os.environ.get("ROBLOX_API_KEY", "")
DRY = "--dry" in sys.argv


def req(method, url, body=None, ctype=None):
    r = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": KEY})
    if ctype:
        r.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace")


def multipart(fields):
    b = uuid.uuid4().hex
    parts = [f'--{b}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n' for k, v in fields.items()]
    return ("".join(parts) + f"--{b}--\r\n").encode(), f"multipart/form-data; boundary={b}"


def existentes():
    out, token = {}, ""
    while True:
        st, data = req("GET", f"{BASE}/creator?pageSize=50" + (f"&pageToken={token}" if token else ""))
        if st != 200:
            sys.exit(f"Listar falhou ({st}): {data}\n→ a chave precisa do escopo developer-product:read no universo {UNIVERSE}")
        for p in data.get("developerProducts", []):
            out[p.get("name")] = p.get("productId")
        token = data.get("nextPageToken") or ""
        if not token:
            return out


if not KEY:
    sys.exit("ROBLOX_API_KEY ausente")
ja = existentes()
ids = {}
for v in VALORES:
    nome = f"Apoiar {v}"
    if ja.get(nome):
        ids[v] = int(ja[nome]); print(f"{nome}: já existe ({ids[v]})"); continue
    if DRY:
        print(f"{nome}: seria criado"); continue
    body, ctype = multipart({"name": nome, "description": f"Doação de {v} Robux para o desenvolvimento do Bizarre Showdown F/X. "
                             "Dá a tag de Apoiador (só visual, sem vantagem).", "price": str(v), "isForSale": "true"})
    st, data = req("POST", BASE, body, ctype)
    if st not in (200, 201) or not isinstance(data, dict) or not data.get("productId"):
        sys.exit(f"Criar {nome} falhou ({st}): {data}")
    ids[v] = int(data["productId"]); print(f"{nome}: criado ({ids[v]})")

if not DRY and len(ids) == len(VALORES):
    src = CONFIG.read_text()
    for v, pid in ids.items():
        src, n = re.subn(rf'(\{{ key = "donate_{v}", amount = {v}, productId = )\d+( \}})', rf"\g<1>{pid}\g<2>", src)
        assert n == 1, f"linha donate_{v} não encontrada no LaunchConfig"
    CONFIG.write_text(src)
    print("LaunchConfig.Donations atualizado")
