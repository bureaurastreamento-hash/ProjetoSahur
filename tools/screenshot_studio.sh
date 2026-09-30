#!/bin/bash
# screenshot_studio.sh <saida.png> — foca a janela do Studio (Vinegar: "Wine Desktop") via script do KWin, tira a foto da
# janela ativa (spectacle) e recorta a viewport padrão (layout do dono: viewport em x 286..1574, y 170..640).
# Posicionar a câmera antes pelo MCP: CurrentCamera.CFrame = CFrame.lookAt(de, para); CurrentCamera.Focus = CFrame.new(para)
set -e
OUT="${1:?uso: tools/screenshot_studio.sh saida.png}"
JS="$(mktemp --suffix=.js)"
cat > "$JS" <<'JSEOF'
for (const w of workspace.windowList()) { const c = w.caption || ""; if (c.indexOf("Wine Desktop") >= 0 || c.indexOf("Roblox Studio") >= 0) { workspace.activeWindow = w; } }
JSEOF
id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$JS" "focarstudio$RANDOM")
qdbus6 org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run >/dev/null 2>&1 || true
sleep 1.2
spectacle -b -n -a -o "$OUT" >/dev/null 2>&1
rm -f "$JS"
python3 -c "from PIL import Image; Image.open('$OUT').crop((286,170,1574,640)).save('$OUT')" 2>/dev/null || true
