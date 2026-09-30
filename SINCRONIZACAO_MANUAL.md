# Edição manual no Studio (dono/equipe de arte) → arquivos do Rojo (IA)

O que o **Rojo ao vivo** (`default.project.json`, `rojo serve`) gerencia — sempre dos arquivos, Studio segue o git:
- Código/UI: `src/server`, `src/client`, `src/shared`, `src/ui`...
- `Workspace.Sahur` → `src/workspace` (chão das ilhas, relevo, Vila Nova, Campos, arena...)
- `ServerStorage.Maps/ArenaReserva` → `src/maps`, `src/reserva`
- `Lighting` (Sky, Atmosphere, Bloom, Color) → `src/place/lighting`; `TextChatService` → `src/place/textchat`

O que é só **backup/histórico no git** (capturado do `.rbxl`, o Rojo ao vivo NÃO empurra para o Studio):
- o resto do Workspace (Taberna, Móveis, Lojinha, `cav`, Kame, árvores/pedras soltas, Barriers, Banheiro...) → `src/place/workspace`
- o resto do ServerStorage (EventMaps/Cânion, BossModel, Mods, backups de mapa) → `src/place/serverstorage`

> Por quê (30/09): com `"$path"` em Workspace/ServerStorage no `default.project.json` (serviço com `$path` + filhos
> explícitos), o plugin do Rojo **duplicou** os 23 modelos desses serviços ao conectar, e a duplicata foi publicada.
> Nunca pôr `$path` nesses dois serviços do projeto ao vivo. Restaurar um deles do backup = Insert from File do `.rbxm`
> de `src/place/...` (ou a IA pelo MCP), nunca pelo Rojo ao vivo.

**Fora de tudo (só no place):** o Terrain (mar) e `ServerStorage.Backup_Terreno_2026-09-29` — o Rojo não guarda Terrain.
Guardar `.rbxl` de backup continua sendo a proteção deles.

Edição no Studio de algo que o Rojo ao vivo gerencia (`Workspace.Sahur`, Lighting...) **volta ao que está nos arquivos
se alguém reconectar o Rojo sem capturar antes.** Vale para o dono e para a equipe de arte.

## Parte do dono (ou de quem editar no Studio)

1. Abrir o place, **desconectar o Rojo**.
2. Construir/mover/apagar à vontade, com o Play parado.
3. File > Save to File → `backups/place-<o-que-fez>-AAAAMMDD.rbxl`.
4. Avisar a IA: "pronto, está em backups/...rbxl". **Não reconectar o Rojo antes da IA terminar.**

## Parte da IA

1. `tools/capturar_mapa.sh backups/<arquivo>.rbxl` → confere o resumo.
   - Arquivo que existe em `src/` mas não no place é **MANTIDO** (ex.: modelo recém-gerado que ainda não sincronizou).
     Só remove com `... aplicar com-remocoes`, quando o dono apagou algo de propósito.
   - O `.rbxl` precisa ser **mais novo que a última sincronização do Rojo**; senão a captura desfaz mudanças feitas nos
     arquivos (ex.: posição de marcador ajustada pelo código). Na dúvida, pedir um `.rbxl` novo.
2. `tools/capturar_mapa.sh backups/<arquivo>.rbxl aplicar` → `git diff --stat`, `tools/analisar.sh`, commit.
3. Avisar que pode reconectar. Na confirmação do plugin a lista deve vir vazia ou quase; remoção de peça = não aceitar.

Como funciona: `rojo syncback` com `tools/mapa.project.json` (só mapa/place; `syncbackRules` ignora Terrain, Camera,
coisas de runtime e `FerramentasStudio`). Todo nó recebe `ignoreUnknownInstances` (inclusive pastas via
`init.meta.json`), então coisa criada no Studio e ainda não capturada nunca é apagada pelo Rojo — para APAGAR algo do
mapa, apague no Studio e capture (ou a IA apaga pelo MCP).

## Regras

- **O Studio é a fonte do mapa**: não rodar `gerar_chao_ilhas.py`, `gerar_ilha_*_fx.py`, `gerar_arena.py`, `MontarMundo`.
  `tools/gerar_expansao_ilha1.py` (Vila Nova + Campos) só enquanto ninguém editou esses dois modelos à mão.
- Enquanto alguém edita no Studio, a IA não mexe em `src/workspace`, `src/maps`, `src/reserva`, `src/place`.
- Runtime NÃO é mapa: `Workspace.EventosMundo` (mercador, mural, obeliscos...) e `ServerStorage.IlhaSecreta_Kame` só
  existem no Play (WorldEventsService) — nunca copiar de uma sessão de Play para o place.
- Publicação só pelo Studio sincronizado, com o dono. Nunca `rojo build`/API como fonte de publicação (incidente v422).
