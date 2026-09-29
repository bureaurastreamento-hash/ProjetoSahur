# Projeto: Bizarre Showdown (repo legado ProjetoSahur) — Battlegrounds Roblox

Direção aprovada: ler `BIZARRE_DIRECAO.md` antes de planejar novos sistemas; para mods/place de criação, ler `MODS_KIT.md` e `tools/place_criacao/LEIA-ME.md`. `PROGRESSO.md` e o código atual prevalecem para estado de implementação. Não refazer sistemas existentes por causa da mudança de nome/visão.

## ⚠️ NUNCA PUBLICAR O PLACE A PARTIR DOS ARQUIVOS (incidente 2026-09-28)
O projeto Rojo é ADITIVO: Taberna, Hall, Lojinha, santuário, `ServerStorage.CharacterModels`/`Mods`, iluminação,
terreno etc. existem SÓ no place (montados via MCP/Studio), não em `src/`. Um `rojo build` publicado pela Open Cloud
(Place Publishing API) SUBSTITUI o place inteiro por esse build incompleto e apaga o mapa — foi o que aconteceu
na versão 422 (28/09, 21:49 UTC). Publicar só pelo Studio (File > Publish) com o Rojo sincronizado, e só com o dono.
Nunca usar `ROBLOX_API_KEY` para publicar place; nunca rodar `rojo build` como fonte de publicação.

## Regra: edição manual do dono x Rojo (2026-09-28)
O Rojo só sobrescreve o que vem de `src/` e `tools/studio/` (scripts, UI em StarterGui, `Workspace.Sahur.*`,
`ServerStorage.Maps/ArenaReserva/FerramentasStudio`). Tudo fora disso (`Workspace.Taberna`, `cav`, Lojinha, ilhota Kame,
peças soltas no Workspace, Terrain) é do place e o Rojo NÃO mexe. Quando o dono quiser editar à mão algo gerado
(ex.: uma ilha em `Workspace.Sahur`): "entregar" a pasta ANTES — com o Rojo DESCONECTADO, tirar o arquivo de `src/`
(a instância fica no place e passa a ser dele) e mover para fora de `Workspace.Sahur`. Nunca rodar
`MontarMundo` de novo sem perguntar (apaga edições manuais no terreno). Iluminação: o `EnvironmentService` aplica
a do código no Play; mudança manual no Lighting tem que ir para o CONFIG dele.

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

## ONDE PARAMOS (2026-09-29) — ler PROGRESSO "RETOMAR AQUI (2026-09-29)"
- Docs do dono: `BIBLIA_CAMPANHA_CAP1_v0.1.md` (campanha Cap. 1) + `ESTRUTURA_JOGO.md` (4 camadas, bounty, raridade).
  **Jogo diverge dos arquivos → muda o jogo; o que der para juntar, junta** (junções em `BIZARRE_DIRECAO.md`).
- Ilhas: `ilha_tutorial` = Porto da Névoa, `ilha_pilares` = Deserto do Sol, `ilha_sol_partido` = Rota do Eclipse (ids
  mantidos). `StoryConfig` rev 2 (atos com `Mission`/`Arrive`/`UnlockFlag`/`Guide`); mudou ordem de ato → subir
  `Revision` + migração no `StoryService`. Nunca mostrar o nome "Carlos" antes da Missão 18. Nada de palavrão em texto do jogo.
- Falta testar no Play (lista no PROGRESSO) e o dono publicar pelo Studio.

## ONDE PARAMOS (fim de 2026-09-28) — ler PROGRESSO "RETOMAR AQUI (fim da sessão 2026-09-28, noite)"
- História CANÔNICA = `LORE_FX_CANONE.md` (doc do dono). Não decidir sozinho o que está em §52 dele.
- Próximo: (1) chão das ilhas com PEÇAS simples bem feitas, não Terrain realista; (2) Stands/raças do zero (nasce
  humano, Flecha no fim do tutorial, raridade sem pity, troca perde o anterior mas guarda maestria, inventário);
  (3) HUD estilo Blox Fruits + menus na tela; depois conteúdo, places por capítulo, Server Authority.
- O dono ainda precisa PUBLICAR pelo Studio o que foi feito em 28/09.

## ONDE PARAMOS (2026-09-28, noite) — ARQUIPÉLAGO (ler PROGRESSO "ARQUIPÉLAGO" + MAPA_CAPITULO_1 "Layout do mundo")
- A arena fechada foi DESMONTADA em ilhas por Parte de JoJo (Alvorecer P1, Pilares P2 + Coliseu, Sol Partido P3, ilhota
  Kame). Chão = Terrain gerado por `tools/studio/MontarMundo.luau` (ModuleScript sincronizado; o terreno NÃO está no git).
  `Workspace.Sahur.Arena` não existe mais; peças em `PecasArena`/`Coliseu`/`ServerStorage.ArenaReserva`.
- Próximas levas combinadas com o dono: conteúdo das Partes 3–6 → depois **Server Authority** (dono aceitou refazer
  dash/corrida no esquema de simulação prevista + compensação de lag; `Workspace.AuthorityMode` só pelo painel).

## ONDE PARAMOS (2026-09-25, noite) — ler PROGRESSO.md "RETOMAR AQUI" → "ONDE PARAMOS"
- **Leva autônoma de 25/09 (dono fora do PC, autorizou)**: B5 Stand animado; C0 história com arco do adryan (10 capítulos,
  migração por Id, NPCs sempre R6); D1 anti-2v1 (`CounterService`, barra Revide + E, funciona no ragdoll); D2 variações
  de golpe (`Ability.Variants`, `pickVariant`); D3 torneio "Último de pé" (`TournamentService`, DEV → MAPA → TORNEIO);
  D4 log de atualização (`UpdateLogConfig`/`UpdateLogService`, Config → Novidades, DEV "PUBLICAR novidades").
  Servidor testado via MCP; VISUAL/cliente ainda sem o dono ver. **Mapa do dono**: ele edita a Taberna/entorno à mão no
  Studio — ao voltar, sincronizar (`sincronizar_arena.luau`, `comparar_extras.py`, backup JSONL) ANTES de Play/regenerar;
  `montar_taberna.luau` está travado. **Hall de entrada da Taberna FEITO** (`tools/montar_hall.luau` + `SaloonDoorService`,
  portas de saloon testadas no Play; 50 móveis da pilha reaproveitados; ver PROGRESSO). Se o Studio abrir com o Hall
  faltando (crash antes de salvar), rodar `montar_hall.luau` via MCP de novo. **Móveis "fantasmas"/deformados que não
  dão para clicar = MeshPart com `MeshSize = 0` (vieram do `restaurar_workspace`)** → `tools/consertar_meshparts.luau`
  via MCP (resolvido em 21/09; sempre rodar depois de restaurar de backup JSONL). PRÓXIMO: C2 place de criação → C3 mural
  → C4 textos/quotes → C5 salvar place; testes com player e artes = "amanhã" (dono).
- A1–A6 da lista do dono FEITOS (DEV com ON/OFF, cenas predefinidas, agarrão trava, boss/traidor à solta, trailer
  com órbita de grupo, NPC nunca deita "duro", **traidor = bot especial OP** via `BotService.Spawn` com
  `Attributes`/`Tuning`, atributo `DamageMult`) + intocável no agarrão/ult. Nada disso foi testado pelo dono ainda.
  **B1 aprovado + B2/B3 FEITOS (24/09, sem teste)**: esquema `Abilities`(4)/`Passive`(R, slot 5)/`Ultimate`/
  `AwakenedAbilities`(4) em `CharacterDefs`; tipos novos `Buff`/`Mark`/`Homing`/`Rewind`, `Then` encadeado; kits de
  `PESQUISA_KITS.md`. B4 = `StandSilhouette` (silhueta de luz, sem modelo). **25/09: kits testados via MCP com bots
  (servidor OK; rajada com Offset + empurrão só no último golpe). PRÓXIMO: dono testa o VISUAL (lista no PROGRESSO) → C/D.**
  Botão direito da câmera travado no Studio (volta após todo Play nesta place): tentar toggle `CameraType`
  `Scriptable → Fixed` via MCP; investigação em aberto (ver PROGRESSO "Pedidos do dono 25/09").
  **B5 FEITO (25/09, sem o dono ver em jogo)**: `StandSilhouette` = rig procedural (FK R6 sobre clipes `Stand/Idle|
  Enter|Punch|Exit` do `ProcAnimDefs`, `ProcAnimDefs.Sample`), segue suavizado, `PUNCH_ANCHOR` à frente na rajada;
  `AwakeningDefs.Stand` = tabela `StandStyle` (proporção por personagem). Skin por personagem já existe
  (setting `CharacterModel` + `ServerStorage.CharacterModels.<Id>`), falta a arte entregar os modelos.
  Regras: `CharacterDefs.GetAbility(id, slot, awakened)`; nunca usar `EnergyCost`/`AwakenedEffect` (só no DashOverride).
  Ideias novas anotadas em "D": anti-2v1 (tecla E), variações de golpe (JJS), evento "último de pé", log de
  atualização no jogo. Nunca escrever "Discord" em texto do jogo.

## Estado 2026-09-23 (tarde) — núcleo do combate aceita BOTS; trailer v2 real
- **`Combatant.Fighter` = Player | Model de bot**: Health/Ragdoll/Combat/Movement/AbilityService recebem Fighter.
  Regras: estado por Instance; `Combatant.CharacterOf/Of/PlayerOf/Notify`; FireClient/AntiExploit/DataStore/crédito
  SÓ para Player. Ao escrever código novo nesses services, nunca assuma `player.Character`/`Players:GetPlayerFromCharacter`.
- **`BotService`**: bots com o combate REAL (M1, dash, block, habilidades, despertar + ult). Padrão do dono: só
  revidam quando apanham. DEV: Mapa → BOTS. **`TrailerService` v2**: cenas com bots (`TrailerScene <cena> [id] [me]`).
- Dono testou (noite): ver PROGRESSO "SEQUÊNCIA NOVA" — A1..A6 correções (DEV toggles, cenas predefinidas, agarrão
  trava NPC, boss/traidor à solta, trailer menos caótico, traidor = bot OP) → B redesign das habilidades (1–4 ataques,
  R passiva, G ult troca os 4, Stands na ult; PESQUISA aprovada pelo dono antes de codar) → C backlog antigo.

## Estado 2026-09-23 — bloco E fechado (ver PROGRESSO.md "RETOMAR AQUI")
- **Capítulo final**: traidor = adryan_keep (`QuestConfig.Traitor`, `TraitorService` = NPC hostil R6 com o avatar
  no santuário; `DeliverNpcUserId` = entrega com o Humanoider_20). DEV: `SetQuestChapter`, `SummonTraitor`.
- **Mods de asset prontos**: `ModRegistry` (compartilhado) injeta `CharacterDef`/`Cosmetics`/`VFX` de
  `ReplicatedStorage.ModsActive.<Id>` (clonado de `ServerStorage.Mods.<Id>` pelo `ModService`); no Studio toda pasta
  de `ServerStorage.Mods` com `ModConfig` vira mod `[TESTE]` no painel. Templates: `tools/place_criacao/`.
  Nunca chamar `setDropdown` de novo no TopbarPlus (destrói os ícones) — usar `joinDropdown`/`leave`.
- PRÓXIMA: lista de testes do dono; place de criação (item 2) e mural de votação (item 3) do PROGRESSO.

## Estado 2026-09-22 — blocos B–F feitos SEM o dono ver (ver PROGRESSO.md "RETOMAR AQUI")
- **PRÓXIMA SESSÃO**: (1) lista de testes do dono → corrigir; (2) PLACE DE CRIAÇÃO separada para a comunidade
  (quase sem scripts do jogo — só templates do kit); (3) MURAL DE VOTAÇÃO de mods (OrderedDataStore, voto grátis
  1/jogador/ciclo; vencedor da semana/mês entra no jogo com crédito) — detalhes no PROGRESSO.
- **Quests** (`QuestConfig`/`QuestService`/`QuestController`): história em capítulos, NPC = membro do grupo
  (`TeamConfig`, gerado por `tools/atualizar_equipe.py`), murais na Taberna (`QuestBoards`; `TeamBoardService`
  = mural dos devs). **Mods** (`ModsConfig`/`ModService`/`ModsController`, `MODS_KIT.md`): só servidor privado/
  Studio; dono do privado ou dev liga; **servidor privado NUNCA salva** (`DataService.sessionOnly`).
- Boss x3 da flecha nasce no centro e anda livre (`BossConfig.Roam`); menu DEV em abas (`gerar_devgui.py`);
  jardim v2 amazônia/asteca + som `72131057531506`; construções v2 (tijolo 6×3×3, 2 andares, zigurate com
  câmara/rampa) + desabamento + golpe pesado ×2; M1 com input buffer.

## Estado 2026-09-21 — ver PROGRESSO.md "RETOMAR AQUI" (FALTA o dono testar)
- **Santuário do boss DENTRO da muralha sul** (`tools/arena_santuario.py` via `gerar_arena.py` → ArenaExtras;
  muralha aberta por `tools/escavar_muralha.luau` no `Arena.rbxm`). Fora só a cachoeira + jardim mesopotâmico.
  Altar antigo saiu; `AltarGruta` velho está em `ServerStorage.Backup_AltarGruta_antigo`.
- **Cenário destrutível estilo JJS**: `ArenaExtras.Destructible` (tijolo a tijolo, `tools/arena_construcoes.py`)
  + árvores da arte tombam — `DestructionService` via `Hitbox.DestructibleHook` (toda consulta de ataque).
- **Roster**: Brawler/Mystic/Guardian SAÍRAM → Jotaro (inicial), Kira, Dio (VIP) herdaram os kits; Bruno=Swift,
  Rick=drop. Perfis antigos migram por `DataService.RENAMED_CHARACTERS`.
- `FX.PlayAnimation(..., fitSeconds)` casa a animação com a duração real da ação; `Shared/Parried`,
  `CritPunch`, `CritHit` novos.
- **Dono moveu peça do `Workspace.Sahur.Arena` no Studio?** → `tools/sincronizar_arena.luau` grava no rbxm.
- **Bloco A (combate) feito 2026-09-21**: parry só antecipado, block segura agarrão, ação individual soco/dash
  (`IsAttacking`, `DashKind`+`SidePunchWindow`), grupos de colisão `Players`/`Dashing`, TimeSlow trava tudo,
  M1 não entra em deitado, teleporte com raycast/chão, coroa do streak, highlight de clã. Falta o dono testar.
- Ainda planejado: blocos B–F do PROGRESSO (cachoeira v2, construções maiores, menu DEV, mods/quests, boss x3).

## Estado do design (2026-09-20) — lojas divididas (ver PROGRESSO.md "RETOMAR AQUI")
- **Loja (L)** = só Robux. **Vendedor** (E no NPC da Lojinha, `VendorGui`) = tudo por PONTOS e por PONTOS DE
  EVENTO (`profile.eventPoints`, schema 3; `Price`/`EventPrice` em `CosmeticsConfig`; `VendorConfig.Catalog`)
  + TROCAS entre jogadores (`TradeService`/`TradeController`/`TradeConfig`; os dois no vendedor; pronto →
  confirmar). Economia e carga da ult ficaram mais duras a pedido do dono. Falta o dono testar (2 clientes).
- **Clã com patentes** (`ClanConfig.Ranks`: total depositado → vagas, saque líder/oficial c/ teto diário, bônus
  XP/pontos, cosméticos `Access = "clan"`; membro nunca saca). **Loot do boss por ranking** (`BossConfig.Loot`,
  `BossLootService`: top 3 raro, 4º–5º bom, resto básico). **Taberna** = `Workspace.Taberna` montada por
  `tools/montar_taberna.luau` via MCP (não passa pelo Rojo; o dono salva o place). Postes da flecha saíram.
- Progressão/conquistas/itens = **pop-up discreto sem som** (`HUDController.ShowToast`), nunca banner+som.
  Setting `CharacterModel` = nascer com o rig da arte (`ServerStorage.CharacterModels.<Id>`). **Rick** =
  exclusivo do boss (`Access = "drop"`, kit provisório). Roster futuro: Bruno Gollini, Jotaro, Dio, Rick Prime,
  Kira (cada um com moveset/ult/efeitos novos). Z-fighting: `tools/achar_sobreposicao.luau`.
- Regras novas (2026-09-20): toda cena (emote "scene", Carry de agarrão) trava o jogador via
  `CombatService.HoldStill`; poses `Loop` ficam até agir (servidor manda parar); auras = casca ForceField +
  manto de chamas; ult do Rick = `FlyGrab` (voo pela câmera + agarrar + mergulho). Rick=normal, Rick Prime=ult.
- Mapa (place, não Rojo): `Workspace.Taberna`, `LojinhaDecor`, `AltarGruta` montados por `tools/montar_*.luau`
  via MCP. Santuário do boss agora na muralha sul (z 294, altar z 360 dentro da gruta atrás da cachoeira).
  Altar com flecha: E = virar o boss, F = invocar x3. Boss automático 2 h. Bruno Gollini = id "Swift".

## Estado do design (2026-09-17, fim do dia) — lista do dono (ver PROGRESSO.md "RETOMAR AQUI")
- **Feito hoje**: Leva 8 (locomoção PROCEDURAL por personagem: `ProcAnimDefs.Locomotion` + `Styles`/
  `Resolve`, camada de base no `ProcAnimController`, `ProcAnimHold` segura o rig na cutscene) e as
  partes 1–3 da lista do dono: soco para BAIXO livre no ar caindo; cutscene da ult com direção
  congelada + shift lock solto (fim do giro de tela) e câmera que escala com o tamanho do rig (boss);
  ULTIMATE visível no slot numérico ("(desperto)" quando trancada); topbar com 4 botões e DROPDOWN
  (Jogar/Loja/Perfil/Config, Dev dentro de Config); **CONQUISTAS** no lugar das missões
  (`AchievementsConfig`/`AchievementService`, "zerar o jogo", Passe 1 de 60 dias com itens LIMITADOS
  que só DEV entrega depois que o passe acaba; perfil salvo subiu para schema 2).
- **Falta (próximo passo)**: parte 4 da lista — **menu DEV de verdade + sistema de DENÚNCIAS**
  (denunciar com motivo predefinido + texto livre em DataStore; DEV teleporta para a arena, entra no
  servidor de um jogador, assiste alguém, lê denúncias e dá itens). Depois: ajustes que o dono mandar
  ao testar (andar/parar de cada personagem, VFX do F7, poses, trailer, metas do passe) e a Leva 7
  (balanceamento, 2 clientes, acabamento dos menus).

## Estado do design (2026-09-17) — polimento em levas (ver PROGRESSO.md "RETOMAR AQUI")
- Boss = **Big C.H.O.P.** (id `BigChop`; nunca ragdolla; Devorar cura). Levas 1–6 feitas: combate (hit de chegada
  do dash/Piscar, Domínio do Tempo do Swift, congelamento só do Guardian, noite rara 28/4 min), **animações
  PROCEDURAIS** (`RigPose` + `ProcAnimDefs` + `ProcAnimController` via gancho `FX.ProcAnim`; mandam sobre as
  dos packs — `team = true` devolve à equipe), sons com ids públicos, trailer com avatares reais e ações de fundo,
  bonecos de treino com física/ragdoll/leash. **Leva 8 (locomoção por personagem) também está FEITA** —
  ver o bloco de cima; falta a lista de ajustes do dono (VFX F7, poses, trailer, jeito de andar).
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
