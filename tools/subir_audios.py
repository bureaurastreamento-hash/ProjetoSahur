#!/usr/bin/env python3
"""
Sobe os .mp3 de audios/ para a Roblox (grupo do jogo) pela Open Cloud Assets API e grava os ids em
audios/ids.json. Depois, com --aplicar, escreve os ids em src/assets/Sounds.model.json conforme MAPA.

Precisa de uma API key do grupo (create.roblox.com > Open Cloud > API Keys) com a permissão
"assets: read/write" e o grupo como dono. Exportar antes: ROBLOX_API_KEY=xxxx

Uso:
  python3 tools/subir_audios.py            # sobe o que ainda não tem id (idempotente: pula os já subidos)
  python3 tools/subir_audios.py --aplicar  # só grava os ids já subidos no Sounds.model.json
  python3 tools/subir_audios.py --listar   # mostra o MAPA e o que falta subir

Áudio novo na Roblox passa por moderação: o id sai na hora, mas pode levar minutos para tocar.
"""

import json
import os
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AUDIOS = ROOT / "audios"
IDS = AUDIOS / "ids.json"
SOUNDS = ROOT / "src" / "assets" / "Sounds.model.json"
GROUP_ID = 9835819  # grupo dono do jogo (CLAUDE.md)

# arquivo em audios/ -> caminho do som em Sounds.model.json (Pasta/Nome). Volume opcional.
# Quem não está aqui é subido mesmo assim (fica em ids.json para usar depois).
MAPA = {
    "Soco.mp3": ("Shared/Punch_Whoosh", 0.5),
    "Hit.mp3": ("Shared/Punch_Hit", 0.6),
    "Hit 2.mp3": ("Shared/Hit_Stun", 0.8),
    "Soco forte.mp3": ("Shared/Finisher_Whoosh", 0.7),
    "pancada.mp3": ("Shared/Finisher_Hit", 0.8),
    "Soco critico.mp3": ("Shared/Crit", 1.0),
    "soco critico 2.mp3": ("Shared/BlackFlash", 1.0),
    "defender dano critico.mp3": ("Shared/Parry", 0.7),
    "Impacto metalico.mp3": ("Shared/Block", 0.5),
    "Impacto metalico2.mp3": ("Shared/GuardBreak", 0.6),
    "Dash.mp3": ("Shared/Dash", 0.5),
    "dash 2.mp3": ("Shared/RagdollCancel", 0.5),
    "Pedras.mp3": ("Shared/WallSplat", 0.8),
    "Pedras2.mp3": ("Shared/WallSplat2", 0.8),
    "CarregandoUlt.mp3": ("Shared/Awakening_Charge", 0.6),
    "carregando poder.mp3": ("Shared/Awakening_Riser", 0.8),
    "Energia.mp3": ("Shared/Awakening_Pulse", 0.7),
    "Aura explodindo.mp3": ("Shared/Awakening_Impact", 1.0),
    "Aura.mp3": ("Shared/Awakening_Burst", 0.9),
    "Terminando o poder.mp3": ("Shared/Awakening_End", 0.8),
    "Parando o tempo.mp3": ("Swift/TimeDome", 0.9),
    "barulho dentro do dominio.mp3": ("Swift/TimeDome_Loop", 0.35),
    "Parando o tempo2.mp3": ("Swift/TimeDome_Break", 1.0),
    "Dando Teleporte.mp3": ("Swift/Blink", 0.5),
    "Socos super rapidos.mp3": ("Swift/Tempest", 0.6),
    "sequencia rapida de socos.mp3": ("Brawler/Rampage", 0.6),
    "Carregando ataque rapido.mp3": ("Brawler/ShoulderBash", 0.6),
    "Impacto de energia.mp3": ("Brawler/ShoulderBash_Hit", 0.7),
    "Terra tremendo.mp3": ("Brawler/GroundSlam", 0.7),
    "onda de choque.mp3": ("Brawler/GroundSlam_Hit", 0.8),
    "Laser.mp3": ("Mystic/ArcaneBolt", 0.5),
    "hit de energia.mp3": ("Mystic/ArcaneBolt_Hit", 0.6),
    "Energia2.mp3": ("Mystic/Mend", 0.5),
    "Ataque chegando.mp3": ("Mystic/Meteor", 0.7),
    "Explosão.mp3": ("Mystic/Meteor_Hit", 0.9),
    "batida de espada.mp3": ("Guardian/ShieldBash", 0.6),
    "batendo com espada.mp3": ("Guardian/ShieldBash_Hit", 0.7),
    "carregando poder2.mp3": ("Guardian/Fortify", 0.6),
    "coisas tremendo.mp3": ("Guardian/Quake", 0.7),
    "onda de choque 2.mp3": ("Guardian/Quake_Hit", 0.8),
    "explosao de longe.mp3": ("Boss/Slam_Hit", 0.8),
    "Trovão2.mp3": ("Boss/Roar", 0.8),
    "vento 2.mp3": ("Boss/Leap", 0.6),
    "Explosão distorcida.mp3": ("Shared/Transform_Burst", 1.0),
    "Tensão.mp3": ("Shared/Transform", 0.8),
    "barulho do vazio 2.mp3": ("BigChop/Devour", 0.7),
    "EmoteLevelUp.mp3": ("Shared/UltReady", 0.6),
    "EmoteRisadas.mp3": ("Emotes/taunt", 0.6),
    "EmoteFogosDeArtificios.mp3": ("Emotes/scene_power", 0.7),
    "EmoteSaxofoneTriste.mp3": ("Emotes/bow", 0.6),
    "EmoteBell.mp3": ("Emotes/sit", 0.5),
}


def load_ids():
    return json.loads(IDS.read_text()) if IDS.exists() else {}


def upload(path: Path, key: str) -> int:
    boundary = "----SahurBoundary7d9f"
    request_json = json.dumps({
        "assetType": "Audio",
        "displayName": path.stem[:50],
        "description": "Sahur SFX",
        "creationContext": {"creator": {"groupId": GROUP_ID}},
    })
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n{request_json}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{path.name}\"\r\nContent-Type: audio/mpeg\r\n\r\n"
    ).encode() + path.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request("https://apis.roblox.com/assets/v1/assets", data=body, method="POST", headers={
        "x-api-key": key, "Content-Type": f"multipart/form-data; boundary={boundary}",
    })
    with urllib.request.urlopen(req) as resp:
        op = json.load(resp)
    op_path = op["path"]
    for _ in range(30):
        time.sleep(2)
        req = urllib.request.Request(f"https://apis.roblox.com/assets/v1/{op_path}", headers={"x-api-key": key})
        with urllib.request.urlopen(req) as resp:
            st = json.load(resp)
        if st.get("done"):
            return int(st["response"]["assetId"])
    raise RuntimeError(f"upload de {path.name} não concluiu")


def aplicar(ids: dict):
    tree = json.loads(SOUNDS.read_text())

    def folder(name):
        for c in tree["children"]:
            if c["name"] == name:
                return c
        f = {"name": name, "className": "Folder", "children": []}
        tree["children"].append(f)
        return f

    n = 0
    for fname, (target, volume) in MAPA.items():
        aid = ids.get(fname)
        if not aid:
            continue
        fold, sname = target.split("/")
        f = folder(fold)
        node = next((c for c in f.setdefault("children", []) if c["name"] == sname), None)
        if node is None:
            node = {"name": sname, "className": "Sound", "properties": {"RollOffMaxDistance": 80, "RollOffMinDistance": 10}}
            f["children"].append(node)
        node["properties"]["SoundId"] = f"rbxassetid://{aid}"
        node["properties"]["Volume"] = volume
        n += 1
    SOUNDS.write_text(json.dumps(tree, indent=1, ensure_ascii=False) + "\n")
    print(f"{n} sons gravados em {SOUNDS}")


def main():
    ids = load_ids()
    files = sorted(p for p in AUDIOS.glob("*.mp3"))
    if "--listar" in sys.argv:
        for p in files:
            alvo = MAPA.get(p.name, ("(sem uso ainda)", None))[0]
            print(f"{'OK ' if p.name in ids else '   '} {p.name:45s} -> {alvo}")
        faltam = [f for f in MAPA if not (AUDIOS / f).exists()]
        if faltam:
            print("no MAPA mas sem arquivo:", faltam)
        return
    if "--aplicar" not in sys.argv:
        key = os.environ.get("ROBLOX_API_KEY")
        if not key:
            sys.exit("defina ROBLOX_API_KEY (Open Cloud, permissão assets read/write, grupo como dono)")
        for p in files:
            if p.name in ids:
                continue
            try:
                ids[p.name] = upload(p, key)
                print(f"{p.name} -> {ids[p.name]}")
            except Exception as e:  # segue com os outros; roda de novo para tentar os que falharam
                print(f"FALHOU {p.name}: {e}")
            IDS.write_text(json.dumps(ids, indent=1, ensure_ascii=False) + "\n")
    aplicar(ids)


if __name__ == "__main__":
    main()
