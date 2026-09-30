#!/usr/bin/env bash
# capturar_mapa.sh <place.rbxl> [aplicar] [com-remocoes]
# Traz para os arquivos o que o dono (ou a equipe de arte) construiu/moveu/apagou no Studio, para o Rojo não desfazer
# ao reconectar. Fonte = cópia salva pelo Studio (File > Save to File). Captura TUDO que é do place (tools/mapa.project.json):
#   Workspace.Sahur (src/workspace) + o resto do Workspace (src/place/workspace: Taberna, cav, Lojinha, Kame...),
#   ServerStorage.Maps/ArenaReserva (src/maps, src/reserva) + o resto do ServerStorage (src/place/serverstorage:
#   EventMaps, BossModel, Mods, backups), Lighting (src/place/lighting) e TextChatService (src/place/textchat).
# Fica de fora: Terrain (o Rojo não guarda), código/UI (NUNCA lidos do place: lá está a versão velha).
# Sem "aplicar": só simula e mostra o resumo. Com "aplicar": grava em src/.
# REMOÇÕES: arquivo que existe em src/ mas não no place (ex.: modelo gerado que ainda não sincronizou) é MANTIDO,
# a não ser com "com-remocoes" (use só quando o dono apagou algo no Studio de propósito).
# Depois da captura, não rodar os geradores antigos do chão/ilhas (ver SINCRONIZACAO_MANUAL.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLACE="${1:?uso: tools/capturar_mapa.sh <place.rbxl> [aplicar] [com-remocoes]}"
PLACE="$(realpath "$PLACE")"
MODE="${2:-}"
REMOVE="${3:-}"
ROJO="$HOME/.rokit/bin/rojo"
PASTAS=(src/workspace src/maps src/reserva src/place)
[ -f "$PLACE" ] || { echo "Arquivo não encontrado: $PLACE"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp "$ROOT/rokit.toml" "$ROOT/tools/mapa.project.json" "$TMP/"
for p in "${PASTAS[@]}"; do
	mkdir -p "$TMP/$(dirname "$p")"
	cp -r "$ROOT/$p" "$TMP/$p"
done

echo "== Lendo $PLACE =="
(cd "$TMP" && echo Y | "$ROJO" syncback --input "$PLACE" mapa.project.json 2>&1 | grep -E "Would write|Finished|ERROR" || true)

# ignoreUnknownInstances em todo nó dos .model.json (peça criada no Studio e ainda não capturada nunca é apagada
# pelo Rojo); resumo por arquivo; remoções só com "com-remocoes" (senão o arquivo original volta).
python3 - "$ROOT" "$TMP" "$REMOVE" "${PASTAS[@]}" <<'EOF'
import json, sys, shutil, pathlib
root, tmp, remove = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3] == "com-remocoes"
pastas = sys.argv[4:]
def count(n):
    return 1 + sum(count(c) for c in n.get("children", []))
def mark(n):
    n["ignoreUnknownInstances"] = True
    for c in n.get("children", []):
        mark(c)
mudou = 0
for pasta in pastas:
    novos = {p.relative_to(tmp): p for p in (tmp / pasta).rglob("*") if p.is_file()}
    velhos = {p.relative_to(root): p for p in (root / pasta).rglob("*") if p.is_file()}
    for rel in sorted(set(novos) | set(velhos)):
        n, v = novos.get(rel), velhos.get(rel)
        if n and n.name.endswith(".model.json"):
            m = json.loads(n.read_text())
            mark(m)
            n.write_text(json.dumps(m, ensure_ascii=False, indent=1) + "\n")
            if v and v.read_bytes() == n.read_bytes():
                continue
            antes = count(json.loads(v.read_text())) if v else 0
            print(f"  {rel}: {antes} -> {count(m)} instâncias" + ("  (NOVO)" if not v else ""))
            mudou += 1
        elif n:
            if v and v.read_bytes() == n.read_bytes():
                continue
            print(f"  {rel}: " + ("NOVO" if not v else "alterado"))
            mudou += 1
        elif remove:
            print(f"  {rel}: REMOVIDO (não existe mais no place)")
            mudou += 1
        else:
            (tmp / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(v, tmp / rel)
            print(f"  {rel}: não está no place — MANTIDO (use 'com-remocoes' se foi apagado de propósito)")
# pastas (diretórios) também preservam o que for criado no Studio
for pasta in pastas:
    for d in (tmp / pasta).rglob("*"):
        if d.is_dir():
            meta = d / "init.meta.json"
            m = json.loads(meta.read_text()) if meta.exists() else {}
            if m.get("ignoreUnknownInstances") is not True:
                m["ignoreUnknownInstances"] = True
                meta.write_text(json.dumps(m, ensure_ascii=False, indent=2) + "\n")
print(f"{mudou} arquivo(s) mudariam.")
EOF

if [ "$MODE" != "aplicar" ]; then
	echo "Só simulação. Para gravar em src/: tools/capturar_mapa.sh \"$PLACE\" aplicar"
	exit 0
fi
for p in "${PASTAS[@]}"; do
	rm -rf "$ROOT/$p"
	cp -r "$TMP/$p" "$ROOT/$p"
done
echo "Gravado em src/. Conferir 'git diff --stat' antes de reconectar o Rojo."
