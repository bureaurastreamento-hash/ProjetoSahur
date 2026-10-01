#!/usr/bin/env python3
"""Valida hashes/dados baixados e prepara seleção pequena para importar no Studio."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "asset_library" / "para_importar"

def main():
    manifest = json.loads((ROOT / "ASSETS_CC0_MANIFEST.json").read_text())
    report = {"images": 0, "audio": 0, "obj": 0, "hashes": 0, "errors": [], "selected": []}
    for pack in manifest["packs"]:
        for entry in pack["files"]:
            path = ROOT / entry["path"]
            try:
                if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
                    raise ValueError("Hash divergente")
                report["hashes"] += 1
                suffix = path.suffix.lower()
                if suffix in {".png", ".jpg", ".jpeg"}:
                    with Image.open(path) as image:
                        image.verify()
                    report["images"] += 1
                elif suffix in {".wav", ".ogg"}:
                    # Decodifica áudio inteiro sem tocar; não roda nenhum arquivo do pack.
                    subprocess.run(["ffmpeg", "-v", "error", "-nostdin", "-i", str(path), "-f", "null", "-"],
                                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=15)
                    report["audio"] += 1
                elif suffix == ".obj":
                    vertices, triangles = 0, 0
                    for line in path.read_text().splitlines():
                        if line.startswith("v "):
                            values = list(map(float, line.split()[1:4]))
                            if len(values) != 3 or any(abs(v) > 1e6 for v in values):
                                raise ValueError("Vértice inválido")
                            vertices += 1
                        elif line.startswith("f "):
                            indices = [int(x.split("/")[0]) for x in line.split()[1:]]
                            if len(indices) < 3 or any(i == 0 or abs(i) > vertices for i in indices):
                                raise ValueError("Face inválida")
                            triangles += len(indices) - 2
                    if not vertices or not triangles:
                        raise ValueError("Malha vazia")
                    report["obj"] += 1
            except Exception as error:
                report["errors"].append({"path": str(path.relative_to(ROOT)), "error": str(error)})
    tiles = []
    for slug, label in [("Grass001", "Grama"), ("Ground037", "Terra"), ("Ground093A", "Areia"),
                        ("WoodFloor007", "Madeira"), ("Bricks001", "Tijolos"), ("Rock030", "Rocha")]:
        folder = ROOT / "asset_library" / ("ambientcg_" + slug)
        for channel in ["Color", "NormalGL", "Roughness"]:
            path = folder / (slug + "_1K-JPG_" + channel + ".jpg")
            destination = DEST / "materiais" / slug / path.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, destination)
            report["selected"].append(str(destination.relative_to(ROOT)))
        path = folder / (slug + "_1K-JPG_Color.jpg")
        with Image.open(path) as image:
            tiles.append((label, image.convert("RGB").resize((320, 320))))
    # Móveis e flora pequenos, em OBJ com seus MTL/atlas locais, para inspeção no importador.
    for pack, names in [("kenney_nature-kit", ["tree_small", "rock_smallA", "grass", "flower_redA"]),
                        ("kenney_furniture-kit", ["chair", "table", "bookcaseClosed", "barrel"] )]:
        for name in names:
            source = ROOT / "asset_library" / pack / "Models" / "OBJ format"
            path = source / (name + ".obj")
            if not path.exists():
                continue
            destination = DEST / "modelos" / pack
            destination.mkdir(parents=True, exist_ok=True)
            for extension in [".obj", ".mtl"]:
                file = source / (name + extension)
                if file.exists():
                    shutil.copyfile(file, destination / file.name)
                    report["selected"].append(str((destination / file.name).relative_to(ROOT)))
            for atlas in source.rglob("*.png"):
                target = destination / atlas.relative_to(source)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(atlas, target)
    for pack in ["kenney_impact-sounds", "kenney_interface-sounds"]:
        source = ROOT / "asset_library" / pack
        paths = sorted(source.rglob("*.ogg"))[:6]
        for path in paths:
            destination = DEST / "sons" / pack / path.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, destination)
            report["selected"].append(str(destination.relative_to(ROOT)))
    source = ROOT / "asset_library" / "kenney_particle-pack" / "PNG (Transparent)"
    if not source.exists():
        source = ROOT / "asset_library" / "kenney_particle-pack" / "PNG (Transparent background)"
    for path in sorted(source.glob("*.png"))[:12]:
        destination = DEST / "particulas" / path.name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, destination)
        report["selected"].append(str(destination.relative_to(ROOT)))
    canvas = Image.new("RGB", (1000, 770), (15, 22, 31))
    draw = ImageDraw.Draw(canvas)
    draw.text((20, 14), "Materiais CC0 para Bizarre Showdown F/X - ambientCG (1K)", fill="white")
    for i, (label, tile) in enumerate(tiles):
        x, y = 10 + i % 3 * 330, 50 + i // 3 * 360
        canvas.paste(tile, (x, y)); draw.text((x, y + 330), label, fill="white")
    preview = DEST / "previa_materiais.jpg"
    canvas.save(preview, quality=90)
    report["preview"] = str(preview.relative_to(ROOT))
    (ROOT / "ASSETS_CC0_VALIDACAO.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps({key: value for key, value in report.items() if key not in {"selected", "errors"}}, ensure_ascii=False))
    print("Erros:", len(report["errors"]), "Seleção:", len(report["selected"]))
    if report["errors"]:
        raise SystemExit(1)

if __name__ == "__main__":
    main()
