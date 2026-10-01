#!/usr/bin/env python3
"""Downloads oficiais autorizados; extrai apenas dados, nunca scripts/plugins/place files."""
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import stat
import urllib.request
from urllib.parse import urlparse
import zipfile

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "asset_library"
ALLOWED = {".png", ".jpg", ".jpeg", ".wav", ".ogg", ".obj", ".mtl", ".glb", ".fbx", ".txt"}
HOSTS = {"kenney.nl", "ambientcg.com", "acg-download.struffelproductions.com"}
LIMIT = 150 * 1024 * 1024

def fetch(url):
    if urlparse(url).scheme != "https" or urlparse(url).hostname not in HOSTS:
        raise ValueError("URL fora dos provedores oficiais")
    request = urllib.request.Request(url, headers={"User-Agent": "BizarreShowdown-AssetReview/1.0"})
    with urllib.request.urlopen(request, timeout=45) as response:
        if urlparse(response.url).hostname not in HOSTS:
            raise ValueError("Redirecionamento não autorizado")
        data = response.read(LIMIT + 1)
    if len(data) > LIMIT:
        raise ValueError("Download excedeu limite")
    return data

def extract(pack, data):
    folder = DEST / pack
    entries, skipped = [], []
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        if len(archive.infolist()) > 6000 or sum(i.file_size for i in archive.infolist()) > 400 * 1024 * 1024:
            raise ValueError("Arquivo excedeu limite descompactado")
        for info in archive.infolist():
            path = PurePosixPath(info.filename)
            if path.is_absolute() or ".." in path.parts or "\\" in info.filename or stat.S_ISLNK(info.external_attr >> 16):
                raise ValueError("Caminho inseguro no ZIP")
            if info.is_dir():
                continue
            if path.suffix.lower() not in ALLOWED:
                skipped.append(info.filename)
                continue
            if info.file_size > 32 * 1024 * 1024:
                raise ValueError("Asset individual excedeu limite")
            payload = archive.read(info)  # também valida CRC
            output = folder.joinpath(*path.parts)
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(payload)
            entries.append({"path": str(output.relative_to(ROOT)), "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()})
    return entries, skipped

def main():
    manifest = {"license": "CC0-1.0", "packs": [], "failures": []}
    jobs = [("kenney_" + slug, "https://kenney.nl/assets/" + slug, "https://kenney.nl/support", None)
            for slug in ["particle-pack", "impact-sounds", "interface-sounds", "nature-kit", "furniture-kit"]]
    jobs += [("ambientcg_" + name, "https://ambientcg.com/a/" + name, "https://docs.ambientcg.com/license/",
              "https://ambientcg.com/get?file=" + name + "_1K-JPG.zip")
             for name in ["Grass001", "Ground037", "Ground093A", "WoodFloor007", "Bricks001", "Rock030"]]
    for name, source, license_url, download in jobs:
        try:
            if download is None:
                page = fetch(source).decode("utf-8")
                urls = re.findall(r"href=['\"]([^'\"]+\.zip)['\"]", page)
                if not urls:
                    raise ValueError("Link oficial de download ausente")
                download = urls[-1]
            data = fetch(download)
            files, skipped = extract(name, data)
            manifest["packs"].append({"name": name, "source": source, "license_url": license_url,
                "download": download, "archive_sha256": hashlib.sha256(data).hexdigest(), "files": files, "skipped": skipped})
            print(name, len(files), "arquivos de dados,", len(data), "bytes", flush=True)
        except Exception as error:
            manifest["failures"].append({"name": name, "error": str(error)})
            print(name, "FALHOU:", error, flush=True)
        (ROOT / "ASSETS_CC0_MANIFEST.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")

if __name__ == "__main__":
    main()
