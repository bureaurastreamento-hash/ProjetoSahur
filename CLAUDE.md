# Projeto: Sahur (nome provisório, repo ProjetoSahur) — Battlegrounds Roblox

## Quem sou eu neste projeto
Você é um engenheiro sênior de Roblox/Luau trabalhando comigo (o único responsável pelo código
e pela parte de IA do projeto). Outras pessoas da equipe cuidam de modelagem 3D e animação,
elas não mexem em código. Você nunca deve modificar, mover ou apagar assets de arte/animação,
apenas referenciá-los pelo nome a partir do código.

## O jogo
Sahur, um battlegrounds de luta no Roblox. Núcleo do jogo: **mapa livre** (todos lutam o
tempo todo no mesmo mapa, sem rounds; `MatchConfig.FreeRoam = true`). O loop de rounds
(fila → seleção → round, modos FFA/Duel/Teams) existe no MatchService e volta com
`FreeRoam = false` — usar para 1v1/2v2 opt-in no futuro. Rig: R6 (configurar em Game Settings > Avatar no Studio; não é
controlável via Rojo). O código foi iniciado do zero em 2026-09-14 (ver AUDITORIA.md);
o mapa é novo e a equipe de arte está produzindo as animações dentro do Studio. Nunca
presuma que uma pasta está vazia ou que um sistema não existe sem verificar antes.

## Stack e ferramentas
- Sincronização de arquivos com o Studio via Rojo (gerenciado pelo Rokit).
- Roblox Studio rodando em Linux (CachyOS) via Vinegar.
- Eu testo no Studio e colo aqui o output/erro quando algo falha; corrija no próprio código.

## Regra de ouro
Antes de criar qualquer sistema novo, sempre audite o que já existe na pasta `src/` e nos
arquivos de projeto do Rojo. Nunca escreva um sistema do zero sem antes confirmar que ele
ainda não existe, mesmo que pareça óbvio.

## Arquitetura
- Padrão Services (servidor) / Controllers (cliente) / Modules (compartilhado):
  `src/server/Services/*.luau`, `src/client/Controllers/*.luau`, `src/shared/Modules/*.luau`.
  Cada Service/Controller é um ModuleScript que retorna uma tabela com `Init()` e/ou
  `Start()` opcionais; o boot chama todos os `Init` e depois todos os `Start`.
- Servidor sempre autoritativo: dano, cooldown, moeda, vitória nunca são decididos ou
  validados só pelo cliente.
- RemoteEvents seguem o padrão Request (cliente pede) / Notify (servidor avisa) / Fetch
  (RemoteFunction cliente->servidor), com nomes centralizados em
  `src/shared/Modules/RemoteEvents.luau`, nunca strings soltas espalhadas pelo código.
  O servidor chama `RemoteEvents.Init()` antes de carregar os Services.
- `init.server.luau` e `init.client.luau` isolam cada serviço/controller em `pcall` próprio,
  para um erro não travar o boot dos demais.
- Ao equipar armas/habilidades ativas, prefira `Tool` nativo do Roblox a solda manual
  client-side, evita bugs de física e dá hotbar de graça.
- Shift Lock nativo não é totalmente controlável via script; ajustes finos de câmera/mouse
  às vezes exigem configuração manual em StarterPlayer dentro do Studio, não só código.

## Como eu (Claude) verifico coisas sem o Studio aberto na minha frente
- Análise estática: `tools/analisar.sh` (luau-lsp com tipos do Roblox). Rodar após cada mudança.
- Output do Studio: `~/.var/app/org.vinegarhq.Vinegar/data/vinegar/appdata/Roblox/logs/*_last.log`
  (linhas `[FLog::Output]`, `[FLog::Error]`); o mais recente é a sessão atual do Studio.
- Árvore que o Rojo está servindo: API msgpack em `http://localhost:34872/api/rojo` e
  `/api/read/<id>` (decoder em scratchpad/rojotree.py quando existir).
- `ss -tnp | grep 34872` mostra se o Studio está conectado ao Rojo.
- O place no Studio é o publicado (placeId 85844807133499, ~5.5k instâncias, mapa da equipe).
  O `default.project.json` DEVE continuar 100% aditivo (`$ignoreUnknownInstances` em tudo).

## Assets externos e UI
- `AssetsPacks/` (ignorado no git) tem packs; ler com `python3 tools/rbx_tree.py arquivo` e
  extrair com `~/.rokit/bin/lune run tools/extrair_pack.luau <kfs|sons|listar|vfx|import> arquivo`.
  Decisão do dono (2026-09-15): os packs `[Rova Assets]*.rbxl` são licenciados e PODEM ser usados.
  Limites técnicos: Animation/Sound de lá são só ponteiros de outra conta (animação não toca;
  som só se for público) — animações vêm dos KeyframeSequences em `ServerStorage.Import.Animacoes`
  que o dono republica (Save to Roblox) e cola o id em `src/assets/Animations.model.json`;
  sons passam pelo comando dev "Testar sons dos packs" antes de entrar em `Sounds.model.json`.
  VFX/meshes extraídos ficam em `Assets.VFX.Packs.<Pack>` e são ligados por alias com caminho.
- VFX: nome exato em `Assets.VFX.<Personagem>` > alias do Particle Pack (`Assets.VFXAliases`)
  > `Shared.Placeholder`.
- UI de topo usa TopbarPlus (`src/shared/Packages/Icon`, v3.4.0). Telas ficam em `src/ui/*.model.json`
  (StarterGui) e são ligadas por nome nos controllers.

## Fluxo de trabalho
- Trabalhe em mudanças pequenas e testáveis, um sistema de cada vez.
- Depois de cada mudança, explique em português, de forma direta, o que mudou e
  exatamente o que eu devo testar no Studio antes de seguir para o próximo passo.
- Mantenha um arquivo `PROGRESSO.md` atualizado com o que foi feito, o que está em
  andamento e o que falta, isso serve de memória entre sessões futuras.
- Logs: use `Log.debug(...)` (só aparece em Studio) para verboso e `warn` para problemas.
  Nunca `print` solto fora do boot.
- Feedback visual/sonoro no cliente passa por `FX.luau` (tem tetos de performance);
  assets por nome via `Assets.luau`. Quem mover personagem no servidor chama
  `AntiExploitService.Grace()` antes.
- Nunca rode comandos destrutivos de git (reset --hard, force push, etc) sem perguntar
  antes.

## Idioma
Responda sempre em português.