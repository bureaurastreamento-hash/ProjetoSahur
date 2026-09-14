#!/usr/bin/env bash
# Análise estática (sintaxe + tipos Roblox) de src/ com luau-lsp. Não precisa do Studio.
set -e
cd "$(dirname "$0")/.."
TMP="${TMPDIR:-/tmp}/sahur-analyze"
mkdir -p "$TMP"
[ -f "$TMP/globalTypes.d.luau" ] || curl -sL -o "$TMP/globalTypes.d.luau" \
  https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
rojo sourcemap default.project.json -o "$TMP/sourcemap.json"
luau-lsp analyze --definitions="$TMP/globalTypes.d.luau" --sourcemap="$TMP/sourcemap.json" --no-strict-dm-types src
