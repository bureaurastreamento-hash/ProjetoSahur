# PROGRESSO — Sahur

Memória entre sessões. Atualizar depois de cada mudança.

## Feito
- 2026-09-14 — Auditoria inicial (`AUDITORIA.md`): repo era template puro do `rojo init`.
- 2026-09-14 — Estrutura base: `src/server/Services`, `src/client/Controllers`, `src/shared/Modules`.
- 2026-09-14 — Boot server/client com `pcall` por módulo, fases `Init` → `Start`.
- 2026-09-14 — `src/shared/Modules/RemoteEvents.luau` centralizando Remotes (Request/Notify/Fetch).
- 2026-09-14 — `default.project.json`: `$ignoreUnknownInstances` nas pastas sincronizadas.
- 2026-09-14 — `tools/inspecionar_studio.luau` (script somente-leitura para listar o lugar).
- 2026-09-14 — Removido `src/shared/Hello.luau` (placeholder morto do template).

- 2026-09-14 — Núcleo de combate (desarmado, R6, servidor autoritativo):
  `CombatConfig.luau` (números/anim ids), `HealthService` (vida/dano/cura/morte/respawn,
  crédito de kill), `CombatService` (hitbox server-side à frente do HRP, combo M1 de 4,
  cooldown, block com redução de dano, parry em janela de 0.2s que stuna o atacante,
  rate-limit), `CombatController` (Mouse1 ataque, F block, Highlights de feedback,
  animações condicionais a ids em CombatConfig). Aguardando teste em servidor local.

- 2026-09-14 — Sistema de habilidades: `CharacterDefs.luau` (2 personagens: Brawler e
  Swift, 3 habilidades cada, energia 0..100, ult custa 100), `AbilityService` (valida
  cooldown/energia/stun/busy no servidor, efeitos Dash/Teleport/AreaDamage/MultiHitArea/
  DamageBuff, atributos `CharacterId`/`Energy` no Player), `AbilityController` (Q/E/R,
  T cicla personagem [debug], dash local, anim/VFX por nome, painel de debug de cooldown).
  `Hitbox.luau` compartilhado; `Assets.luau` localiza anim/VFX por nome em
  `ReplicatedStorage.Assets`. `CombatService` agora expõe `ResolveHit`/`Stun`/`IsStunned`
  e aplica buff de dano + ganho de energia.
- 2026-09-14 — `ReplicatedStorage.Assets` agora é criado pelo Rojo a partir de `src/assets/`:
  `Animations.model.json` (13 Animations com id vazio, preencher quando publicadas),
  `VFX/{Shared,Brawler,Swift}` com `ignoreUnknownInstances` (arte monta VFX no Studio),
  `VFX/Shared/Placeholder` (efeito genérico de fallback). `Assets.luau` ignora Animation
  sem id e cai no Placeholder quando falta VFX.
- 2026-09-14 — `tools/analisar.sh`: análise estática com luau-lsp (Rokit). Código passa limpo.

- 2026-09-14 — Loop de partida: `MatchConfig.luau` (modos FFA/Duel/Teams, tempos, flag
  `AllowLobbyCombat`), `ArenaService` (rotação de mapas em `ServerStorage.Maps`, clona em
  `Workspace.CurrentMap`, spawns da pasta `Spawns`), `LobbyService` (fila, atributos
  InQueue/CanFight/InMatch), `MatchService` (Waiting → Selecting → InProgress → Ending;
  vitória por último time vivo ou kills no tempo limite; reset via LoadCharacter),
  `LobbyController` (faixa de estado, painel de seleção de personagem, botão de fila).
  Contrato entre serviços é só por atributos do Player (`CanFight`, `InMatch`, `TeamId`);
  CombatService/AbilityService não conhecem rounds. `HealthService.Died` (BindableEvent).
  Mapa placeholder `src/maps/Arena_Teste.model.json` (piso, paredes, 8 spawns) e
  `Workspace.Lobby.LobbySpawn` no project.json. Tecla T de debug removida.

- 2026-09-14 — DIAGNÓSTICO: nenhum script nunca rodou no Studio porque o Rojo não tinha
  aplicado a árvore (project.json propunha apagar o mapa do Workspace; diálogo não aceito).
  `default.project.json` agora é 100% aditivo (`$ignoreUnknownInstances` em tudo, sem
  Baseplate/Lighting). `rojo serve` reiniciado. Descoberto que o Output do Studio fica em
  `~/.var/app/org.vinegarhq.Vinegar/data/vinegar/appdata/Roblox/logs/*.log` (FLog::Output).
- 2026-09-14 — HUD: `src/ui/HUD.model.json` e `CharacterSelect.model.json` → `StarterGui`
  (barra de vida/energia, 3 slots com overlay de cooldown, killfeed, placar, banner, topo
  com estado/timer, painel de seleção + fila). `Assets.UI.OverheadHealth` (barra sobre a
  cabeça dos outros). `HUDController` liga tudo ao servidor (NotifyHealth, NotifyMatchState
  com `scores`, NotifyKill, NotifyAbilityDenied, atributos Energy/CharacterId/InMatch/InQueue,
  cooldowns via `AbilityController.CooldownChanged`). `LobbyController` e painel de debug
  removidos. `HealthService` envia NotifyHealth no spawn.

- 2026-09-14 — `DataService` (DataStore `PlayerData_v1`, chave `player_<UserId>`): moedas,
  personagens desbloqueados, stats (wins/losses/kills/deaths/matches). GetAsync com 3
  retries + backoff; falha → perfil temporário `sessionOnly` (joga normal, não salva, HUD
  avisa). UpdateAsync com retry, autosave 90s, save ao sair, BindToClose. `DataConfig`
  (schema, recompensas, `SimulateFailure`). `MatchService` registra resultado e paga
  moedas; `CharacterDefs.UnlockCost` (Swift = 100); `RequestUnlockCharacter`; HUD mostra
  moedas e 🔒 preço nos personagens bloqueados.
- 2026-09-14 — Auditoria de remotes (`AUDITORIA_REMOTES.md`): `RateLimiter` (token bucket)
  em todos os Request*/Fetch*; `FetchServerTime` implementado; seleção checa desbloqueio.

- 2026-09-14 — VALIDADO em Team Test com 2 jogadores: boot, DataStore (load/save/unlock),
  fila → seleção → round → kill → fim → recompensa. Correções pós-teste: dash amostra a
  hitbox durante todo o movimento; fim de round não dá LoadCharacter duplo em quem morreu.

- 2026-09-14 — Polish: `Log.luau` (debug só em Studio; 28 prints convertidos), `FX.luau`
  (Highlight único por personagem, teto de 12 VFX / 30 partículas / 16 sons), engates
  definitivos de animação (prioridade Action, Block em loop), VFX `Shared.Hit/Block/Parry`,
  árvore `Assets.Sounds` (Shared/Match/Brawler/Swift, ids vazios), sons de round/vitória/
  derrota na HUD, input gamepad/touch básico. `AntiExploitService` (velocidade no servidor,
  rubber-band, `Grace()` para dash/blink/spawn). Mapa placeholder sem sombras nas paredes.
  `CHECKLIST_PUBLICACAO.md` criado.

- 2026-09-14 — Núcleo mudou para **MAPA LIVRE** (`MatchConfig.FreeRoam = true`): sem fila/rounds,
  combate sempre ligado, kill dá moedas na hora (`DataService.RecordKill/RecordDeath`), placar
  por `SessionKills`. Loop de rounds preservado para modos futuros.
- 2026-09-14 — Mapa `Workspace.Sahur.Arena` (src/workspace/Arena.model.json): 320×320, praça,
  anel, 8 pilares, 4 plataformas com rampas, coberturas, muros, 12 SpawnLocations.
  `Workspace.Lobby` removido.
- 2026-09-14 — Bugs do teste: regen padrão do Roblox removida (`StarterCharacterScripts.Health`
  vazio) e substituída por regen fora de combate (6 s sem dano, 3 HP/s); block com "intenção"
  (ativa sozinho ao sair do cooldown/stun se F continuar pressionado); seleção de personagem
  movida para uma faixa no topo (não bloqueia mais o shift lock); `StarterGui.ShowDevelopmentGui
  = false` via project.json.
- 2026-09-14 — Game feel: knockback no finisher do combo e no GroundSlam (`NotifyKnockback`),
  números de dano flutuantes, tremor leve de câmera ao apanhar, indicador de combo, banner
  "Você eliminou X". `FX.Push/Shake/DamageNumber`.

- 2026-09-14 — Assets externos: `tools/rbx_tree.py` (lê .rbxm/.rbxl binários). `AssetsPacks/`
  avaliado: os dois `.rbxl` "[Rova Assets]" são dumps de outros jogos (não usar: direitos +
  anims/áudio de terceiros não tocam); `Particle Pack.rbxm` (Shiro Dev) sincronizado em
  `Assets.VFX.Packs.ParticlePack` e mapeado por alias (`Assets.VFXAliases`) para as
  habilidades. `FX.SpawnVFX` sanitiza packs (remove BillboardGui/scripts, rajada única).
- 2026-09-14 — TopbarPlus v3.4.0 vendorizado em `src/shared/Packages/Icon` (GitHub oficial).
  `TopbarController`: ícones Personagens (V), Perfil (P), Placar (Tab, substitui PlayerList),
  Controles. Novas telas `ProfileGui` (stats/K-D/moedas/personagens) e `HelpGui`. Painel de
  personagens agora abre pelo topbar; placar escondido por padrão.
- 2026-09-14 — Hitbox só atinge personagens de jogadores ou Models com tag `Combatant`
  (rigs decorativos do Workspace não levam mais dano).

- 2026-09-14 — **Mapa novo (plano, detalhado)**: `tools/gerar_arena.py` gera
  `src/workspace/Arena.model.json` (662 parts, só materiais nativos com paleta própria; nada
  de free model). Praça circular central (3 anéis + medalhão neon, meio-fio, 8 postes com luz,
  bancos, floreiras), 4 caminhos pavimentados e 4 trilhas de terra; zonas: **Ruínas** (N,
  colunas quebradas/caídas, muretas, dais), **Mercado** (S, 6 barracas, poço, caixotes, barris,
  cerca), **Lago** (L, lâmina d'água sem colisão, ilha, passarela, pedras, juncos) e **Bosque**
  (O, ~20 árvores, troncos, cogumelos com luz, pedra rúnica). Muro de pedra baixo com torres
  nos cantos + barreira invisível de 60 studs. Pastas por zona no Explorer; 12 spawns.
  Editar o mapa = editar o script e rodar de novo.
- 2026-09-14 — `EnvironmentService`: iluminação em runtime (fim de tarde, Atmosphere, Bloom,
  ColorCorrection, SunRays), aditivo (só cria efeitos `Sahur*` se não existirem).
  `Lighting.Technology` precisa ser trocado no Studio manualmente.
- 2026-09-14 — **3º personagem: Mystic** (250 moedas). Q `ArcaneBolt` (novo efeito
  `Projectile`: esfera neon simulada no servidor em `Workspace.Projectiles`, raycast por passo,
  acerta o 1º alvo, knockback leve), E `Mend` (novo efeito `Heal`, +30 HP, número verde
  flutuante), R `Meteor` (`AreaDamage` com `Offset`: cai 16 studs à frente 1.2 s depois, raio
  14, 45 de dano, knockback forte; o ponto trava no cast). `Hitbox.AroundPoint`,
  `FX.SpawnVFX(..., at)` posiciona VFX num ponto (NotifyAbility manda `Position`).
  Aliases do Particle Pack, Animations/Sounds `Mystic` (ids vazios), `VFX/Mystic`.
  Painel de seleção alargado para 640 px.

- 2026-09-14 — **VFX próprios** (`tools/gerar_vfx.py` → `src/assets/VFX/<Char>/<Ability>.model.json`,
  16 efeitos, só texturas embutidas do engine + Parts Neon): rajadas, anéis de choque que
  crescem e somem, luzes que apagam, aura de fogo que segue o Brawler na Fúria, anel de aviso
  do Meteoro. `FX.SpawnVFX` entende atributos `OriginRelative`/`Lifetime`/`Follow` (Model),
  `TweenScale`/`TweenTime` (Part), `EmitCount`/`EmitDuration` (emissor), `FadeTime` (luz).
  VFX feito pela arte com o mesmo nome no Studio continua tendo prioridade.
  AssetsPacks: continua só o Particle Pack (os `.rbxl` Rova são dumps de outros jogos, não usar).
- 2026-09-14 — **Menu de desenvolvedor**: `src/server/AdminConfig.luau` (lista de NICKS
  permitidos: guilacartinhasgames, humanoider_20; dono do jogo também passa; sem senha),
  `AdminService` (atributo `IsDeveloper` só para eles → ícone "Dev"/F8 só aparece para eles;
  `FetchAdminLogin()` abre a sessão, `RequestAdminCommand`, `NotifyAdminResult`; comandos SetCoins/
  AddCoins/GrantCharacter/RevokeCharacter/SetCharacter/Heal/Kill/God/Teleport/Bring/Kick/
  ResetData/SetEnergy/ListPlayers, tudo logado com `warn` no servidor), `DevGui`
  (`tools/gerar_devgui.py`) + `DevController` (ícone "Dev" no topbar / F8, só para IsDeveloper).
  `DataService.SetCoins/GrantCharacter/RevokeCharacter/ResetProfile`; atributo `Invulnerable`
  no Player bloqueia dano em `HealthService.ApplyDamage`.
- 2026-09-14 — **Game feel 2**: hitstop (`FX.Hitstop`, 50/90 ms em quem bate e quem apanha),
  rastro no dash/blink (`FX.Trail`, cor por personagem), finisher com som `Finisher_Whoosh`
  (cai no Punch_Whoosh) + VFX `Shared/Finisher`, ult pronta = barra dourada pulsando + flash no
  slot 3 + som `UltReady` + banner.

- 2026-09-15 — Trocar de personagem = **respawn** com o novo (`player:LoadCharacter()`); negado
  se levou dano nos últimos `CharacterDefs.SwapOutOfCombatSeconds` (10 s), banner mostra a
  contagem. `HealthService.SecondsSinceDamaged`.
- 2026-09-15 — Animações placeholder com ids públicos da própria Roblox (as do Animate R6):
  socos = toolslash/toollunge, block/parry = toolnone, hit = fall, habilidades = lunge/slash/
  cheer/point/wave/dance. Trocar pelas da equipe quando publicarem (mesmos nomes).
- 2026-09-15 — **Mobile**: `MobileGui` (`tools/gerar_mobilegui.py`: SOCO, BLOCK segurar, Q/E/R)
  + `MobileController` (só aparece com toque e sem teclado; desliga "toque no mundo = soco").
  `CombatController.Attack/SetBlock`, `AbilityController.Use`.

- 2026-09-15 — Teste em Team Test OK (menu dev, Mystic, hitstop). Animações não apareciam:
  provável rig R15 no place (avisado no boot por `HealthService`). Cada Animation agora tem
  atributo `R15Id` (id Roblox equivalente) e `FX` escolhe pelo `Humanoid.RigType`.
- 2026-09-15 — **Lobby vivo**: `DummyService` (3 bonecos R6 de treino nos `DummyPad*` da praça,
  tag Combatant, regen própria, respawn 4 s, sem crédito de kill) e `LeaderboardService`
  (OrderedDataStore `Leaderboard_Kills_v1`, publica kills totais ao sair/120 s, top 10 num
  SurfaceGui na Part `LeaderboardBoard` ao lado do caminho norte, atualiza a cada 60 s).
- 2026-09-15 — **4º personagem: Guardian** (400 moedas): Q `ShieldBash` (Dash curto com stun 0,6 s —
  Dash agora aceita `StunSeconds`), E `Fortify` (novo efeito `Shield`: recebe 40% do dano por 6 s,
  `AbilityService.GetIncomingMultiplier` aplicado em `CombatService.ResolveHit`), R `Quake`
  (3 ondas de área com knockback). VFX/anims/sons/aliases. Painel de seleção 780 px.

- 2026-09-15 — **Menu Dev completo** (`tools/gerar_devgui.py`, 620x640): alvo (eu / TODOS / cada
  jogador) com linha de estado vinda do servidor (`GetState`); toggles que refletem o estado real:
  **Energia ∞** (`DevInfiniteEnergy`: AbilityService mantém no máximo e não cobra), **Sem cooldown**
  (`DevNoCooldown`: ignora cooldown/busy), **Modo deus**, Limpar flags; campos moedas/energia/
  vida/WalkSpeed/multiplicador de dano (`DevDamageMult` em `ResolveHit`, `DevSpeed` reaplicado no
  respawn); personagens coloridos por posse; Dar/Tirar todos; Ir até/Trazer/Kick/Zerar dados;
  mundo: recriar/ligar bonecos, atualizar placar, hora do dia, listar online, info do servidor.
  Comandos por alvo aceitam `target = "*"`.
- 2026-09-15 — Placar de líderes também na tela de perfil (`NotifyLeaderboard`, ProfileGui 520 px).

- 2026-09-15 — **Packs Rova liberados pelo dono.** Lune instalado (Rokit) + `tools/extrair_pack.luau`.
  Extraído: 35 KeyframeSequences → `src/import/Animacoes/<Pack>/*.rbxm` (ServerStorage.Import;
  republicar no Studio); VFX de todos os personagens → `src/assets/VFX/Packs/OfficialJJS/*.rbxm`
  (26 arquivos) e `Packs/ShadowBattlegroundsfull/*.rbxm` (41); mapas/armas/dummies do pack →
  `src/import/<Pack>/`. 1477 SoundIds em `PackSounds.luau` + botão dev "Testar sons dos packs"
  (PreloadAsync no cliente, imprime `[SoundProbe] OK|FAIL` no Output). `Assets.VFXAliases`
  aceita caminho (`Packs/OfficialJJS/Damage/HitGlow`); `FX.SpawnVFX` converte Folder em Model.
  `tools/listar_sons.py` lê SoundIds direto do binário (Lune não expõe SoundId).

- 2026-09-15 — **Mapa = MainMap do pack Shadow** (`tools/preparar_mapa.luau` → `src/workspace/Arena.rbxm`):
  recentrado (piso 380×580 com topo em y=0), sem placares/GUIs/sons do pack, `CastShadow=false`
  em piso/bordas/cantos. Extras nossos em `Workspace.Sahur.ArenaExtras` (12 spawns, 3 DummyPads,
  LeaderboardBoard) gerados pelo `gerar_arena.py`; o mapa gerado virou reserva em
  `ServerStorage.Maps.Arena_Gerada`. `HealthService` mata quem cair abaixo de y=-80.
  Pós-processamento aliviado (sem SunRays, Bloom menor, sombras mais duras).
- 2026-09-15 — **VFX dos packs ligados por nome** em `Assets.VFXPack` (prioridade máxima; string ou
  `{Path, Follow, Lifetime}`), 23 habilidades/eventos mapeados. **Preview de VFX** (F7 ou botão no
  menu Dev): lista pesquisável de todos os efeitos de `Assets.VFX.Packs`, clique toca em você
  (Shift = 12 studs à frente) e imprime `[VfxPreview] Packs/...` no Output.

## Retomar aqui (última sessão: 2026-09-15)
Estado: tudo commitado localmente até `fa49e7a` (push bloqueado na sessão do Claude; o dono roda
`git push`). Fluxo de teste: Team Test no Studio, dono = `guilacartinhasgames` (dev; menu Dev F8).
Pendências imediatas, em ordem:
1. Rodar **Testar sons dos packs** no menu Dev e me avisar → leio `[SoundProbe]` no log e preencho
   `Sounds.model.json` com os que tocam. (Os erros "Failed to load sound ... not authorized" ao abrir
   o place eram Sounds dentro dos VFX extraídos; removidos com `tools/limpar_sons_packs.luau` e o
   extrator já descarta Sound.)
2. Publicar os KeyframeSequences de `packs/Import/Animacoes/<Pack>/*.rbxm` (Studio: clique direito em
   ServerStorage > Insert from File > Save to Roblox) e me passar os ids → `Animations.model.json`. Prioridade: `Melee1`, `Charge Punch`, `run`, `teleport`,
   `finisher`, `beatdown`.
3. Passar pelo **Preview de VFX (F7)** e apontar trocas → `Assets.VFXPack`.
4. Medir FPS no MainMap; se pesado, cortar `Corners`/`Trees` em `tools/preparar_mapa.luau`.
5. Conferir rig R6 em Game Settings (HealthService avisa no boot se for R15).

## Em andamento
- 2026-09-15 — **Otimização**: o Rojo injetava ~195k instâncias (packs VFX inteiros em ReplicatedStorage
  + KeyframeSequences/mapas em ServerStorage.Import). Packs completos foram para `packs/` (fora do Rojo);
  `tools/podar_vfx.luau` gera `src/assets/VFX/Packs` só com os efeitos usados (268 instâncias).
  `ServerStorage.Import` saiu do project.json — o dono precisa apagar a pasta órfã no Studio uma vez.
  SoundProbe: 1477/1477 OK (mas PreloadAsync deu OK até para os 13 "not authorized"; não é confiável
  para sons privados — validar tocando de fato).
- Ver FPS com o MainMap (2470 parts). Se ainda pesar: reduzir `Corners` (525 parts) / `Trees`.
- Passar pelo Preview de VFX e me dizer trocas ("Meteoro = Sukuna/X").
- Sons dos packs: rodar "Testar sons dos packs" no Studio e me mandar o Output (ou eu leio o log);
  os OK entram em `Sounds.model.json` por nome.
- Animações dos packs: no Studio, `ServerStorage > Import > Animacoes`, clique direito no
  KeyframeSequence > *Save to Roblox* (conta dona do jogo), copiar o id para `Animations.model.json`.
  Úteis para nós: `Charge Punch`, `run`, `finisher`, `beatdown`, `teleport`, `Melee1`.
- Mapear VFX dos packs por nome nas habilidades (preciso da descrição visual de cada um ou de
  você olhar no Studio e me dizer "usa X no Meteoro").
- Validar no Team Test: block/parry, Swift (Blink/SweepKick/Tempest), speed hack simulado
  (AntiExploit), `DataConfig.SimulateFailure = true`.
- Receber ids das animações/sons da equipe e preencher `src/assets/Animations.model.json`
  e `Sounds.model.json`; VFX por nome no Studio (lista em CHECKLIST_PUBLICACAO.md §1).
- Avaliar o mapa novo (`Sahur.Arena`) no Team Test: escala das zonas, se o lago/bosque atrapalham
  o combate, performance (662 parts + ~20 PointLights).
- Testar Mystic: projétil contra parede/jogador, cura, meteoro (o alvo consegue sair?).
- Testar os VFX gerados (escala/duração de cada um).
- Confirmar rig: Game Settings > Avatar > R6 (CLAUDE.md). Se ficar R15, as anims usam o R15Id.
- Testar bonecos de treino, placar (precisa de "Enable Studio Access to API Services") e Guardian.
- Se o ícone Dev não aparecer: conferir que `StarterGui.DevGui` existe no Explorer (Rojo
  conectado e sincronizado) e que o nick está em `AdminConfig.Developers`.
- Testar o topbar (V/P/Tab), a tela de perfil e os VFX do Particle Pack nas habilidades.
- Asset "Textures" (id 18221073047) foi inserido no Studio pelo usuário em local desconhecido;
  decidir se vira VFX nomeado em `Assets.VFX.<Personagem>`.

## Próximos passos (ordem sugerida)
1. ~~Game feel, parte 2~~ (feito).
2. **Mapa**: quando a equipe de arte trouxer meshes, trocar props do `gerar_arena.py` por
   modelos deles (manter nomes/zonas e a pasta `Spawns`).
3. ~~Mobile~~ (feito; falta testar no Device Emulator e ajustar tamanho/posição).
4. ~~4º personagem~~ (Guardian feito); balancear preços/dano com dados de teste.
5. **Modos Duel (1v1) e Teams (2v2)** como opt-in dentro do mapa livre: portal/painel de
   desafio, arena separada (`ServerStorage.Maps.Arena_Gerada` ou `ArenaMap` do pack em
   `ServerStorage.Import`), `FreeRoam` continua para os demais. ← PRÓXIMO
6. **Progressão**: tela de perfil (stats, moedas, personagens), loja simples, gamepass/
   Robux só depois de validar a economia.
7. ~~Lobby vivo~~ (dummies + placar feitos); falta: leaderboard também na tela de perfil.
8. **Altar para invocar o boss**: altar no mapa (usar meshes de `ServerStorage.Import` ou
   `Arena_Gerada`), interação (ProximityPrompt) que junta jogadores/moedas e invoca um boss NPC
   (rig R6 como os dummies, tag `Combatant`, `Hitbox` já aceita NPC) com IA simples (persegue,
   golpes de área, fases por vida), recompensa em moedas para quem participou; placar próprio.
9. **Lançamento**: `AllowLobbyCombat = false`, `Log.Verbose` automático, publicar privado,
   rodar `CHECKLIST_PUBLICACAO.md` completo.
