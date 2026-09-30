#!/usr/bin/env python3
"""Auditoria de leitura: contratos aditivos e propriedades de mapa controladas pelos arquivos."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def audit():
    project = json.loads((ROOT / "default.project.json").read_text())
    problems = []
    paths = []
    def walk_project(node, trail):
        if node.get("$ignoreUnknownInstances") is not True:
            problems.append(trail)
        if "$path" in node:
            paths.append({"instance": trail, "source": node["$path"]})
        for name, child in node.items():
            if not name.startswith("$") and isinstance(child, dict):
                walk_project(child, trail + "/" + name)
    walk_project(project["tree"], "game")
    maps = []
    for path in sorted((ROOT / "src/workspace").iterdir()):
        if path.name.endswith(".model.json"):
            model = json.loads(path.read_text())
            count, props = 0, set()
            def walk_model(node):
                nonlocal count
                count += 1
                props.update(node.get("properties", {}))
                for child in node.get("children", []):
                    walk_model(child)
            walk_model(model)
            maps.append({"source": str(path.relative_to(ROOT)), "instances": count,
                         "root_preserves_extras": model.get("ignoreUnknownInstances") is True,
                         "properties_controlled": sorted(props),
                         "top_level_children": [n.get("name", "?") for n in model.get("children", [])]})
        elif path.suffix in (".rbxm", ".rbxmx"):
            maps.append({"source": str(path.relative_to(ROOT)), "binary_model": True,
                         "note": "Instâncias/propriedades internas exigem inspeção do modelo; não são livres só por ser binário."})
    return {"additive_manifest": not problems, "manifest_nodes_without_preservation": problems,
            "mapped_paths": paths, "managed_maps": maps,
            "note": "Preservar instâncias extras não preserva alterações em propriedades já controladas pelo Rojo. Não exporta nem sincroniza o Studio."}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Salvar relatório JSON no caminho informado")
    args = parser.parse_args()
    result = audit()
    if args.output:
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print("Manifest aditivo: " + ("OK" if result["additive_manifest"] else "FALHA"))
    for entry in result["managed_maps"]:
        print(entry["source"] + " — " + (str(entry["instances"]) + " instâncias" if "instances" in entry else "modelo binário"))
    print(result["note"])
    raise SystemExit(0 if result["additive_manifest"] else 1)
