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

## Estado do design (2026-09-17) — polimento em levas (ver PROGRESSO.md "RETOMAR AQUI")
- Boss = **Big C.H.O.P.** (id `BigChop`; nunca ragdolla; Devorar cura). Levas 1–6 feitas: combate (hit de chegada
  do dash/Piscar, Domínio do Tempo do Swift, congelamento só do Guardian, noite rara 28/4 min), **animações
  PROCEDURAIS** (`RigPose` + `ProcAnimDefs` + `ProcAnimController` via gancho `FX.ProcAnim`; mandam sobre as
  dos packs — `team = true` devolve à equipe), sons com ids públicos, trailer com avatares reais e ações de fundo,
  bonecos de treino com física/ragdoll/leash. Falta: lista de ajustes do dono (VFX F7, poses, trailer) e **Leva 8**
  (idle que respira/andar/variações por personagem — nada repetido entre personagens).
- Cutscene da ULT: `CutsceneController` (cinema, pós-processo, nome da ult, temas por personagem em
  `AwakeningDefs`, sons em camadas `Shared/Awakening_*`).
- Screenshots do Studio funcionam (KWin + spectacle; scripts no scratchpad) — usar para conferir visual.

## Estado do design (2026-09-16, noite) — decisões novas
- Foco do jogo = anime **JoJo**. Bosses feitos por **PEÇAS do Roblox** (`BossRigs.luau`, estilo JJS), nunca mesh
  externo; 1º boss = Big C.H.O.P. Ritual da **flecha**: quem acha a flecha vira o boss à noite no altar
  (`RitualService` → `BossFormService`). Ciclo dia/noite no `EnvironmentService` (dev congela pelo painel).
- VFX são **compostos por código** (`VFXLibrary.luau` + `FX.PlayComposed`, meshes/texturas por ID); packs
  antigos entram como camada `pack`. Preview no F7 (`Lib/…`). Nada de VFX pesado no Workspace.
- `Arena_Antiga` (ServerStorage.Maps, `WarOnly`) é o mapa da guerra de clã; interior gerado por
  `tools/montar_arena_antiga.luau` (roda no Studio via MCP).
- Trailer por script: DEV → TRAILER (`TrailerService`/`TrailerController`); inventário em `TRAILER_ASSETS.md`.

## Estado do design (2026-09-15, noite) — decisões fechadas com o dono
- Controles: Mouse1 soco (segurar = combo de 4; subindo = uppercut, caindo = downslam), F block
  (só frontal; parry = crítico), Q dash universal (WASD relativo à câmera, cooldowns lateral ×
  frente/trás separados, não sai em stun), 1/2/3/4 habilidades, G = ultimate + Awakening, B roda de
  emotes, K cosméticos, L loja, V personagens, P perfil, Tab placar, J duelo.
- Preso no combo não se age; dash/ataque bloqueiam habilidade; ragdoll de combate + ragdoll cancel (Q).
- Moeda = PONTOS ganhos jogando (kills/duelo/boss/missões); cosméticos só pela ROLETA (pontos ou
  Robux) ou "escolher" com Robux; nada cosmético dá buff. Devs (AdminConfig) têm todos os passes.
- Menus = dropdown discreto abaixo do topbar, à esquerda, cores do TopbarPlus. Sem "AI slop".
- Ver PROGRESSO.md "Retomar aqui" para o que falta testar; PESQUISA_BATTLEGROUNDS.md para as refs.

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
- O place OFICIAL é o 85844807133499 (jogo de GRUPO, creator 9835819, Team Create; confirmado pelo dono em
  2026-09-16 — o id 126518739287432 anotado antes estava errado). Conferir `game.PlaceId` via MCP antes de mexer.
  O `default.project.json` DEVE continuar 100% aditivo (`$ignoreUnknownInstances` em tudo).
- Jogo de grupo: animações/sons só carregam se publicados com o GRUPO como criador. Rig R6
  (Game Settings > Avatar); o `AnimationCheckService` imprime `[AnimCheck]` no Studio (rig/acesso) e o
  `HealthService` avisa se o jogador nasceu R15.
- Lixo dos packs (Workspace.Textures, ServerStorage.Import = 120k instâncias, 3,7 GB de RAM) foi apagado
  em 2026-09-16 via MCP. NUNCA inserir packs inteiros no place; extrair só o necessário para `packs/ParaImportar`.
- MCP do Roblox Studio disponível (`mcp__roblox-studio__*`): `run_code` inspeciona/edita o DataModel de edição;
  `run_script_in_play_mode` roda no servidor do Play e devolve os logs (usar `print`, o `return` se perde).
  Não encadear duas sessões de play seguidas (derrubou o Studio). Apagar coisas do place = pedir antes.

## Assets externos e UI
- `AssetsPacks/` (ignorado no git) tem packs; ler com `python3 tools/rbx_tree.py arquivo` e
  extrair com `~/.rokit/bin/lune run tools/extrair_pack.luau <kfs|sons|listar|vfx|import> arquivo`.
  Decisão do dono (2026-09-15): os packs `[Rova Assets]*.rbxl` são licenciados e PODEM ser usados.
  Limites técnicos: Animation/Sound de lá são só ponteiros de outra conta (animação não toca;
  som só se for público) — animações vêm dos KeyframeSequences em `packs/ParaImportar/Animacoes` (fora do
  Rojo; o dono usa Insert from File no Studio, Save to Roblox e cola o id em `src/assets/Animations.model.json`);
  sons passam pelo comando dev "Testar sons dos packs" antes de entrar em `Sounds.model.json`.
  VFX/meshes extraídos ficam completos em `packs/ParaImportar/VFX/<Prefixo>_<Nome>.rbxm` (fora do Rojo, ~95k instâncias);
  `tools/podar_vfx.luau` gera em `Assets.VFX.Packs.<Pack>` SÓ os caminhos citados em `Assets.luau`.
  Nunca colocar packs inteiros dentro de `src/` (foi isso que derrubou o FPS em 2026-09-15).
- Animações: ids da equipe em `src/assets/Animations.model.json` (sem placeholders da Roblox; id vazio =
  não toca). Para escolher animações dos packs: `lune run tools/juntar_animacoes.luau` gera
  `packs/ParaImportar/Animacoes/AnimPreview_todas.rbxm` (preview clicável num place em branco → Save to Roblox no grupo).
  **Tudo que precisa ir para o grupo (animações, áudios, VFX, modelos) está em `packs/ParaImportar/` — ver `LEIA-ME.md` lá.**
  Idle/Walk/Run são tocadas pelo `MovementController` (não pelo Animate padrão).
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