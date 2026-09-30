# Contexto para retomar (ChatGPT/Codex) — 30/09/2026, noite

Cole isto no início da conversa. Leia `AGENTS.md` (regras), depois `PROGRESSO.md` (seções do topo: "Correções 30/09
noite" e "Prender o jogador") e `SINCRONIZACAO_MANUAL.md`. Código atual > docs antigos. Responder sempre em português.

## Estado
- Repo `ProjetoSahur` (jogo "Bizarre Showdown", battlegrounds JoJo no Roblox, R6). Luau strict; Services (servidor) /
  Controllers (cliente) / Modules; remotes em `src/shared/Modules/RemoteEvents.luau`. Validar com `tools/analisar.sh`.
- Place oficial 85844807133499 (grupo, Team Create). **Publicar só pelo Studio, com o dono.** Nunca `rojo build`/API
  (incidente v422 apagou o mapa).
- Último trabalho (Claude, 30/09):
  1. Leva "prender o jogador": inimigos por nível (`EnemyConfig`, tiers 1–5; iniciais humanos passivos sem ult/Stand),
     missões com `MinLevel`/XP/moedas (`StoryConfig`), materiais/drops/forja/armas (`MaterialConfig`, `BuildConfig.Weapons`),
     eventos por tempo de servidor (`WorldEventsService`: Mercador 6 h, Esferas → Ilhota Kame fantasma, Obeliscos →
     Cânion fantasma, Ferreiro, Mural), Vila Nova + Campos da Névoa (`tools/gerar_expansao_ilha1.py`, `MobPadService`,
     `VillagerService`). Cursor próprio (`CursorController`).
  2. Correções depois do 1º teste publicado (ver PROGRESSO "Correções 30/09 noite"):
     - "nasço invisível tomando dano": spawn duplo (antes do perfil + recriado no checkpoint) e Caçadores agressivos
       em cima do checkpoint da ilha 3. Corrigido em `CharacterService`, `AbilityService.ForceCharacter`, `BotService`
       (zona segura 45 studs de checkpoint/Pescador + 6 s de carência).
     - O Rojo DUPLICOU 23 modelos do place (Taberna, Kame, EventMaps...) por causa de `$path` em Workspace/ServerStorage
       no `default.project.json` → removido. `src/place/workspace|serverstorage` agora é só backup via captura.
     - Cursor sem contorno e arredondado; toda a UI com UICorner 6 px (antes 0).

## Regras que já custaram caro
- Nunca pôr `"$path"` em Workspace/ServerStorage do `default.project.json` (duplica o place). O projeto é ADITIVO
  (`$ignoreUnknownInstances` em tudo).
- Dono edita mapa no Studio com Rojo DESCONECTADO → salva `.rbxl` → IA roda `tools/capturar_mapa.sh <rbxl> [aplicar]`
  ANTES de reconectar. Não rodar `gerar_chao_ilhas.py`, `gerar_ilha_*_fx.py`, `gerar_arena.py`, `MontarMundo`.
- Nunca mexer/mover/apagar assets de arte/animação. Apagar coisa do place = perguntar antes.
- Chão das ilhas = peças lisas (SmoothPlastic, só cor). NPC gerado: posicionar pela raiz (`root.CFrame`), não `PivotTo`.
- Texto do jogo: sem palavrão, nunca "Discord", nunca o nome "Carlos" antes da Missão 18.
- `print` solto só no boot; usar `Log.debug`/`warn`. Servidor autoritativo sempre.
- Novo `StoryConfig` com ordem de atos mudada → subir `Revision` + migração no `StoryService`.

## Pendente / próximo
- Duplicatas já apagadas no Studio (30/09, via MCP; falta o dono publicar). Dono: testar cursor/cantos/spawn e publicar pelo Studio.
- Lista "TESTE DO DONO" no PROGRESSO (NPCs passivos, trava de nível, Campos/drops, eventos pelo DEV, Ferreiro, visual).
- Depois do feedback: chefes com mecânicas próprias, mais sidequests por ilha, contratos de caçador.
