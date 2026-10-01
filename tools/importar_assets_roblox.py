"""Importa SOMENTE assets selecionados CC0; não contém API de publicação de places.

Credencial lida do arquivo privado do dono, nunca salva/impressa. Inventário
retomável registra operação antes de aguardar, evitando uploads duplicados.
"""
import argparse
import hashlib
import json
import mimetypes
from pathlib import Path
import time
import uuid
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / "ASSETS_ROBLOX_IMPORTADOS.json"
API = "https://apis.roblox.com/assets/v1/"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--key-file", required=True)
    parser.add_argument("--group", required=True)
    parser.add_argument("--limit", type=int, default=1)
    parser.add_argument("--only", action="append", help="Restringe às entradas já selecionadas no inventário (repetível)")
    parser.add_argument("--refresh", action="store_true", help="Atualiza moderação das operações já registradas, sem reenviar assets")
    args = parser.parse_args()
    key = Path(args.key_file).read_text().strip()
    if "\n" in key or not key: raise ValueError("Arquivo de credencial inválido")
    selected = json.loads((ROOT / "ASSETS_CC0_VALIDACAO.json").read_text())["selected"]
    # GLBs convertidos de OBJs verificados e músicas verificadas entram na lista separada.
    extra = ROOT / "ASSETS_CC0_EXTRAS.json"
    if extra.exists(): selected += [v["path"] for v in json.loads(extra.read_text())["files"]]
    if args.only:
        if set(args.only) - set(selected): raise ValueError("Asset não está na seleção licenciada")
        selected = args.only
    state = json.loads(STATE.read_text()) if STATE.exists() else {"groupId": args.group, "files": {}}
    if state["groupId"] != args.group: raise ValueError("Grupo diferente do inventário")
    def save(): STATE.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n")
    def call(endpoint, data=None, content_type=None):
        headers = {"x-api-key": key}
        if content_type: headers["Content-Type"] = content_type
        request = urllib.request.Request(API + endpoint, data=data, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=45) as response: return json.load(response)
        except urllib.error.HTTPError as error:
            # Não inclui headers/credencial nem corpo arbitrário da resposta.
            raise RuntimeError(f"Assets API recusou: HTTP {error.code}") from None
    if args.refresh:
        for record in state["files"].values():
            operation = call(record["operation"])
            if operation.get("done") and operation.get("response"):
                record["moderation"] = operation["response"].get("moderationResult", {})
        save()
        print("Moderação atualizada; nenhum upload realizado.")
        return
    uploaded = 0
    for name in dict.fromkeys(selected):
        path = (ROOT / name).resolve()
        if not path.is_relative_to(ROOT / "asset_library"): raise ValueError("Fora da biblioteca")
        suffix = path.suffix.lower()
        kind = "Image" if suffix in {".png", ".jpg", ".jpeg"} else "Audio" if suffix in {".ogg", ".mp3", ".wav"} else "Model" if suffix == ".glb" else None
        if not kind: continue
        record = state["files"].get(name)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if record and record["sha256"] != digest: raise ValueError("Conteúdo mudou após upload")
        if record and record.get("assetId"): continue
        if uploaded >= args.limit: break
        if not record:
            content = path.read_bytes()
            if len(content) > 20_000_000: raise ValueError("Asset acima de 20 MB")
            boundary = "Bizarre" + uuid.uuid4().hex
            metadata = {"assetType": kind, "displayName": "FX_CC0_" + path.stem[:40],
                        "description": "CC0; origem e licença no inventário Bizarre Showdown F/X.",
                        "creationContext": {"creator": {"groupId": args.group}, "expectedPrice": 0}}
            mime = "model/gltf-binary" if kind == "Model" else mimetypes.guess_type(path.name)[0]
            filename = path.name.replace('"', "")
            body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n' + json.dumps(metadata) +
                    f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{filename}"\r\nContent-Type: {mime}\r\n\r\n').encode() + content + f"\r\n--{boundary}--\r\n".encode()
            operation = call("assets", body, "multipart/form-data; boundary=" + boundary)
            record = {"sha256": digest, "type": kind, "operation": operation["path"]}
            state["files"][name] = record; save()
        for _ in range(30):
            operation = call(record["operation"])
            if operation.get("done"):
                if operation.get("error"): raise RuntimeError("Operação recusada: " + str(operation["error"]))
                result = operation["response"]
                record["assetId"] = result["assetId"]
                record["moderation"] = result.get("moderationResult", {})
                save(); print(name, record["assetId"], record["moderation"], flush=True)
                break
            time.sleep(2)
        else: print("Ainda processando:", name, flush=True)
        uploaded += 1

if __name__ == "__main__": main()
