#!/usr/bin/env bash
# capturar_mapa.sh <place.rbxl> [aplicar]
# Traz para os arquivos o que o dono construiu/moveu/apagou à mão no Studio, para o Rojo não desfazer ao reconectar.
# Fonte = cópia salva pelo Studio (File > Save to File). Captura SÓ o mapa gerenciado pelo Rojo:
# Workspace.Sahur (src/workspace), ServerStorage.Maps (src/maps) e ServerStorage.ArenaReserva (src/reserva).
# Código/UI NUNCA são lidos do place (o place tem a versão velha do código).
# Sem "aplicar": gera numa pasta temporária e mostra o resumo. Com "aplicar": copia para src/.
# Depois da captura, os geradores (gerar_chao_ilhas.py, gerar_ilha_*_fx.py, gerar_arena.py) NÃO podem ser rodados
# de novo: sobrescreveriam o que o dono fez. Ver SINCRONIZACAO_MANUAL.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLACE="${1:?uso: tools/capturar_mapa.sh <place.rbxl> [aplicar]}"
PLACE="$(realpath "$PLACE")"
MODE="${2:-}"
ROJO="$HOME/.rokit/bin/rojo"
[ -f "$PLACE" ] || { echo "Arquivo não encontrado: $PLACE"; exit 1; }
if pgrep -x rojo >/dev/null; then
	echo "AVISO: 'rojo serve' está rodando. Desconecte o plugin no Studio antes de reconectar com os arquivos novos."
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/src"
cp "$ROOT/rokit.toml" "$TMP/"
cp "$ROOT/tools/mapa.project.json" "$TMP/"
cp -r "$ROOT/src/workspace" "$ROOT/src/maps" "$ROOT/src/reserva" "$TMP/src/"

echo "== Lendo $PLACE =="
(cd "$TMP" && echo Y | "$ROJO" syncback --input "$PLACE" mapa.project.json 2>&1 | grep -v '^Writing' || true)

# Syncback tira o ignoreUnknownInstances; recoloca em todo nó (peça criada no Studio e ainda não capturada
# nunca é apagada pelo Rojo) e confere a contagem de instâncias por arquivo.
python3 - "$ROOT" "$TMP" <<'EOF'
import json, sys, pathlib
root, tmp = map(pathlib.Path, sys.argv[1:3])
def count(n):
    return 1 + sum(count(c) for c in n.get("children", []))
def mark(n):
    n["ignoreUnknownInstances"] = True
    for c in n.get("children", []):
        mark(c)
for pasta in ("workspace", "maps", "reserva"):
    novos = {p.name: p for p in (tmp / "src" / pasta).iterdir()}
    velhos = {p.name: p for p in (root / "src" / pasta).iterdir()}
    for nome in sorted(set(novos) | set(velhos)):
        n, v = novos.get(nome), velhos.get(nome)
        rot = f"src/{pasta}/{nome}"
        if n and n.name.endswith(".model.json"):
            m = json.loads(n.read_text())
            mark(m)
            n.write_text(json.dumps(m, ensure_ascii=False, indent=1) + "\n")
            antes = count(json.loads(v.read_text())) if v else 0
            print(f"  {rot}: {antes} -> {count(m)} instâncias" + ("  (NOVO)" if not v else ""))
        elif n:
            print(f"  {rot}: " + ("NOVO" if not v else ("igual" if n.read_bytes() == v.read_bytes() else "alterado")))
        else:
            print(f"  {rot}: REMOVIDO (não existe mais no place)")
EOF

if [ "$MODE" != "aplicar" ]; then
	echo "Só simulação. Para gravar em src/: tools/capturar_mapa.sh \"$PLACE\" aplicar"
	exit 0
fi
for pasta in workspace maps reserva; do
	rm -rf "$ROOT/src/$pasta"
	cp -r "$TMP/src/$pasta" "$ROOT/src/$pasta"
done
echo "Gravado em src/. Conferir com 'git diff --stat src/workspace src/maps src/reserva' antes de reconectar o Rojo."
