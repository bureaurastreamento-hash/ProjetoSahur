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

## Retomar aqui (última sessão: 2026-09-15, noite — fim; tudo commitado e enviado)

### Estado do boss com modelo 3D (última coisa feita)
- `ServerStorage.BossModel` (asset 138493793469412, 71 MeshParts em 6 grupos Tronco/Cabeça/BracoDir/
  BracoEsq/PernaDir/PernaEsq). O dono rodou na Command Bar
  `require(game.ReplicatedStorage.Shared.Modules.BossRig:Clone()).Studio(true)` → **27 Motor6D**
  (Neck, Right/Left Shoulder, Right/Left Hip, RootJoint + 21 internas), 44 detalhes soldados, welds
  manuais (que cruzavam membros) removidos. Ele precisava dar **Save to Roblox** — conferir na próxima
  sessão se o rig persistiu (rodar a linha de novo: deve dar "27 Motor6D, 0 soldadas").
- Runtime: `BossService.rigFromModel` clona e chama `BossRig.Assemble` (achatado, 16 studs).
- **Pendente testar**: `BossConfig.FaceOffset = 90` (andava de lado; se ainda de lado usar -90, de
  costas 180). Cache do `require` na Command Bar: usar `:Clone()` para pegar o código novo.
- Animações do boss: a equipe faz no Animation Editor em cima do `BossModel`, publica no grupo e cola
  em `Animations.model.json` → `Boss` (Swipe, Slam, Shockwave, Leap, Charge, Roar). Idle/Walk do boss
  ainda não são tocados (ligar quando existirem).

### Bugs relatados e corrigidos hoje (retestar)
- Dash "voando infinito" (LinearVelocity antigo nunca destruído) → corrigido; levar golpe/knockback
  cancela o dash; barreira baixa não lança para cima (raio no joelho + teto vertical 6).
- Boneco atacante caía no void → corrigido (PivotTo pelo pivô).
- Uppercut no 1º soco → só no 4º (troca com o empurrão); downslam como continuação.
- Anti-exploit disparando com knockback do boss → tolerância maior + avisos/kick.

### Bugs que o dono anotou no 3º teste e AINDA NÃO mandou ("depois a gente volta nisso")
- Pedir a lista + Output na próxima sessão antes de seguir.

### Próxima sessão — ordem
1. Conferir rig do boss salvo + FaceOffset; encaixar animações que a equipe mandar (Boss e Emotes,
   Dash/Downslam/Uppercut/Parry/Hit do Shared).
2. Bugs do 3º teste (pedir).
3. Roteiros de teste pendentes abaixo (leva 2, leva 3, fases 4 e 5) — nada disso foi validado ainda.
4. Depois: placar global de rating, mais agarrões (perguntar quais), Idle/Walk do boss, e o plano de
   **guerra de clã/dominação** (ver "Planos futuros").


### Boss com modelo 3D — 3ª versão (`src/shared/Modules/BossRig.luau`)
- Output do dono mostrou: 71 MeshParts em 6 grupos (Tronco, Cabeça, BracoDir, BracoEsq, PernaDir,
  PernaEsq), 21 Motor6D SÓ dentro de cada grupo (RigEdit), NENHUMA junta entre tronco e membros,
  44 partes sem junta, hubs ancorados. `BossRig.Assemble` resolve: acha o hub de cada grupo, cria
  Motor6D tronco→membros (Neck/Right Shoulder/…), solda soltas no mesmo grupo, HRP+RootJoint+Humanoid
  R15, HipHeight. Runtime usa num clone achatado; `tools/montar_rig_boss.luau` (Command Bar, modo
  Edit) aplica no `ServerStorage.BossModel` para animar no Animation Editor.

### Boss com modelo 3D (NÃO testado)
- `BossService.rigFromModel`: monta rig por cima de um Model sem Humanoid — HRP invisível que colide
  (45% da largura, 60% da altura), Humanoid R6 com HipHeight calculado, Head/Torso invisíveis, todas as
  partes do modelo viram filhas DIRETAS (hitbox conta só filhos diretos), soldadas ao HRP, sem colisão e
  sem massa. Escala automática para `BossConfig.ModelHeight` (16 studs). `FaceOffset` gira a frente.
- Onde o modelo é procurado: `ServerStorage.BossModel` → `ReplicatedStorage.Assets.BossModel` →
  `Workspace` (qualquer profundidade; é movido para ServerStorage ao iniciar) → `InsertService:LoadAsset
  (138493793469412)` (só funciona se o asset for do grupo/dono ou público). Fallback: rig R6 antigo.
- Dono: renomear o Model inserido para **BossModel** (de preferência em ServerStorage) e salvar o place.
- 2ª versão (`rigFromModel` robusto): aceita Model aninhado (`BossModel.Model.tripo_part_*`), Motor6D
  do RigEdit dentro das partes, com/sem Humanoid/HRP. Achata as partes (hitbox), preserva Motor6D,
  **solda micro-detalhes sem junta na parte com junta mais próxima**, cria HRP + `RootJoint` na raiz
  da árvore de juntas, Humanoid R15 com HipHeight = pé do HRP → pé do modelo. `tools/inspecionar_boss.luau`
  (colar na Command Bar) imprime a estrutura para eu conferir.

### Fase 5 (NÃO testada)
- **Uppercut/downslam só como 4º golpe** do combo (no lugar do finisher com empurrão; cliente e
  servidor conferem `combo == 4`); depois do uppercut, o downslam sai como continuação por 1,6 s
  (`Uppercut.FollowUpWindow`). Pedido do dono: "todo soco especial deve ser no último soco".
- **Boss por horário** (`BossConfig.AutoSpawnMinutes = 12`): aviso 30 s antes (banner "chega ao
  Santuário") e invoca sozinho se o altar estiver pronto e houver alguém.
- **Rating (Elo) de duelo 1v1** (`profile.rating`, começa 1000, K = 24): status no fim do duelo
  ("Rating: 1012 (+12)") e no Perfil.
- **Títulos** (tag antes do nome, `NameTag`): Veterano (nível 10), Elite (25), Lenda (40), Mestre
  (maestria 10 em algum personagem); VIP tem prioridade. Recalcula ao subir nível/maestria/entrar.

### Roteiro de teste da fase 5
1. Socar 1–3 vezes pulando: sempre M1; no 4º pulando/subindo: uppercut; no ar depois, socar caindo:
   downslam. Pular e socar no 1º golpe NÃO faz uppercut.
2. Esperar ~12 min: banner do boss + spawn sozinho (ou baixar `AutoSpawnMinutes` para testar).
3. Duelo 1v1: no fim aparece "Rating: … (+/−)"; Perfil mostra rating.
4. Dev: AddXP até nível 10 → nome vira "[Veterano] Nick" ao respawnar (DisplayName) e na barra.


- **Wall splat** (`CombatConfig.WallSplat`): golpe que derruba (4º M1, finisher, agarrão, habilidade com
  Ragdoll) com parede a até 12 studs na direção do empurrão → +6 de dano, ragdoll +0,8 s, kind
  `wallsplat` (número "PAREDE", tremor forte, VFX `Shared/WallSplat`).
- **Versões despertas**: `AbilityDef.AwakenedEffect` — durante o Awakening a habilidade usa esse efeito
  (GroundSlam, SweepKick, ArcaneBolt, Fortify, Bombo têm; as outras só ganham o buff).
- **Maestria por personagem** (`profile.mastery[characterId]`, `ProgressionConfig.Mastery`): kill +25,
  duelo +30, boss +40; nível a cada 150 XP (máx 10); cartão do personagem mostra "Maestria N · XP";
  banner "MAESTRIA N" ao subir (`NotifyProgression "mastery_up"`).
- **Passe "Servidor privado+"** (`ShopConfig` `private_plus`, id 0): dentro de um servidor privado liga
  `DevNoCooldown` no dono do passe (sem cooldowns; bonecos já existem).
- **Drop raro do boss**: top de dano tem 35% (`BossConfig.TopDropChance`) de ganhar um giro grátis da
  roleta (`CosmeticsService.FreeRoll`); banner do boss mostra "DROP RARO: item".
- Bugs que o dono viu no 3º teste ficaram para a próxima sessão ("depois a gente volta nisso").

### Roteiro de teste da fase 4
1. Combo de 4 com o alvo de costas para uma parede: "PAREDE 6" + cai mais tempo.
2. G (despertar) e usar 1 (GroundSlam/Bombo/SweepKick/ArcaneBolt): área/dano maiores.
3. Matar alguém: cartão do personagem (V) mostra a maestria subindo; a cada 150 XP banner.
4. Boss derrotado sendo o top: às vezes "DROP RARO".

### Leva 3 (NÃO testada) — pedidos do dono depois do 2º teste
- **Boneco atacante caía no void**: `PivotTo` usava a posição do HRP e não do pivô do Model → afundava a
  cada golpe. Agora gira em torno do próprio pivô.
- **Santuário do boss** (`tools/gerar_arena.py` → `ArenaExtras`): ao sul (z≈150–240): caminho de lajes
  desde a praça, disco de pedra escura, anel de 10 pilares com braseiros (fogo + luz), runas neon no
  chão, 2 estátuas quebradas, altar com 4 tochas ao norte do disco (z=165), boss nasce no centro
  (z=195). Continua "por código"; a arte pode substituir mantendo os nomes BossAltar/BossSpawn/BossArena.
- **PONTOS no lugar de moedas** (só o nome/UI; o campo do perfil continua `coins`). **Roleta** de
  cosméticos: `RequestCosmetic("roll")` = 100 pontos → item aleatório (skin/capa/aura/emote) ponderado
  por `Weight`, sem repetir; VIP fora da roleta. Robux: produtos `roll_1`/`roll_5`/`pick`
  (`ShopConfig.Products`, ids 0 = em breve; `ShopService.CosmeticHook` → `CosmeticsService.OnProduct`).
  Painel K: GIRAR + giros Robux + lista (equipar o que tem / "escolher com Robux" o que não tem).
  Roda B: botão GIRAR à direita. Emote padrão de todos: `wave`.
- **Devs têm todos os passes** (`ShopService.refreshOwnership`: IsDeveloper → todos os perks).
- **Anti-exploit com avisos**: 1ª flag banner amarelo "Vá com calma...", 2ª vermelho sério, 3ª kick
  (devs nunca são kickados). `NotifyWarning`. Dev menu: "Zerar anti-exploit".
- **Menus** viraram dropdown abaixo do topbar (x=12, y=52), preto 50% como os ícones do TopbarPlus.
- **Dev menu** (`tools/gerar_devgui.py`): Voar (toggle `DevFly`; Espaço sobe/Ctrl desce; anti-exploit
  ignora), ULT + despertar, Ragdoll 2 s, Zerar anti-exploit, kill streak, Dar/Zerar cosméticos,
  Invocar/Remover boss; "Zerar CDs" também zera o dash. **Personagem de admin `Overlord`**
  (`Access = "admin"`: só devs veem o cartão; golpes absurdos para testar).
- **Console (amigo no Xbox/PlayStation)**: ver instrução no fim desta seção.

### Roteiro de teste da leva 3
1. Boneco atacante fica no lugar enquanto soca.
2. Ir ao sul da praça pelo caminho de lajes: santuário com braseiros acesos; E no altar invoca.
3. K → GIRAR com 100+ pontos: banner "ROLETA: X", item entra na lista e (capa/aura) aparece no boneco.
   Sem pontos: "Pontos insuficientes para girar". Clicar num item que não tem: abre prompt "em breve".
4. Você (dev) vê VIP/Guardian liberados e o cartão "Overlord".
5. Dev: Voar, ULT + despertar, Ragdoll, Invocar boss. Spam de dash sem cooldown: banner amarelo do
   anti-exploit (não kicka dev).
6. Menus abrem abaixo do topbar sem cobrir o centro.

### Para o amigo de console jogar
No Studio: **Game Settings → Basic Info → Playable Devices** marcar **Console** (e Computer/Phone/Tablet)
e publicar (File → Publish to Roblox no place OFICIAL do grupo). Depois, no **Creator Dashboard** (jogo do
GRUPO) → Experiência → **Access**: "Public" (ou, se quiser fechado, adicionar o amigo ao GRUPO e usar
acesso restrito a membros; "Friends only" não existe para jogos de grupo). Console exige gamepad
completo (já temos: R1 soco, L1 block, X dash, Y/B/R2 habilidades, L2 ultimate, D-pad cima emotes) e
que o jogo não dependa de teclado. Ele acha o jogo pela busca/perfil do grupo.

### Leva 2 (NÃO testada) — pedidos do dono depois do 1º teste
- **AntiExploit** mais tolerante (2,2× WalkSpeed + 10 studs, 4 strikes; ignora caído/PlatformStand;
  knockback dá 2 s extras de graça). Era o boss empurrando que disparava o rubber-band.
- **Dash**: 2 cooldowns separados (`ForwardBackCooldown` 4 s, `SideCooldown` 2 s); direção pelo WASD
  relativo à CÂMERA e o boneco fica de frente para a câmera durante o dash (A/D = strafe lateral, S =
  de costas — nada de "virar e ir para frente"); SteerRate 14. HUD: 2 slots ("Dash ↑↓" e "Dash ←→").
  **Não sai em stun nenhum** (preso no combo só sai quando o atacante para) e durante o dash
  (`DashingUntil`) não dá para socar/usar habilidade.
- **Teclas**: habilidades em **1/2/3/4**, **G = ULTIMATE** (dispara a ult do personagem + Awakening
  20 s), F block, Q dash, **B = roda de emotes**, **K = cosméticos**, **L = loja** (era B), V/P/Tab/J iguais.
- **Agarrões** (`Effect.Type = "Grab"`): Brawler `Agarrão` e Guardian `Golpe de Escudo` agora agarram:
  investida curta → prende o 1º alvo por `Carry` s (vítima em stun duro, segue o atacante no cliente
  dela: `AbilityController.startGrabbed`; atacante com **super armor**: sem hitstun/ragdoll) → golpe
  final com dano/knockback. Animação opcional `<Char>.<Ability>_Carry`.
- **Bonecos de treino** por pad (ordem alfabética): `DummyPad0` parado, `DummyPad1` **bloqueia sempre**
  (atributo Blocking; −90%), `DummyPad2` **ataca** (combo de 4 no ritmo do M1 em quem chega a 7 studs;
  `CombatService.NpcPunch`). Servem para testar block/parry/hitstun/ragdoll.
- **Painéis** (Perfil/Loja/Controles/Cosméticos/Personagens) encostados à ESQUERDA (centro livre).
- **Cosméticos** (`CosmeticsConfig` + `CosmeticsService` + `CosmeticsController` + `CosmeticsGui`):
  skins (placeholder = cor do corpo até a arte chegar), capas (Part soldada ao Torso), auras
  (`FX.SetAura "Cosmetic"`), tudo por moedas ou VIP; salvo no perfil (`cosmetics`, `emotes`).
  Só visual. **Roda de emotes (B)**: 8 posições; "cenas" = emote + aura/VFX por 5 s (sem buff).
  Animações em `Animations.Emotes.<id>` (ids vazios = a equipe faz).
- **Rojo crash** ao rodar `podar_vfx`: era o script apagando a pasta observada; agora só sobrescreve /
  apaga arquivo a arquivo.
- **Fica com a arte/dono**: modelo do boss (é R6 escalado por código, `BossService.buildBoss`) e o
  altar ambientado (`tools/gerar_arena.py` gera um pedestal simples ao sul da praça) — precisam de meshes
  da equipe; eu só referencio por nome.

### Roteiro de teste da leva 2
1. Boss empurrando/ragdoll: NÃO deve mais aparecer `[AntiExploit] ... rubber-band`.
2. Sem shift lock, câmera olhando para um lado: D+Q = dash lateral de verdade (boneco continua de
   frente para a câmera), S+Q = de costas. Slots "Dash ↑↓" e "Dash ←→" contam separados.
3. Apanhar do boneco atacante (DummyPad2): durante o combo, Q/F/habilidade NÃO saem; quando ele para
   (após o 4º), F/Q funcionam. Bloquear na frente do boneco atacante: parry → crítico.
4. Boneco bloqueador (DummyPad1): soco dá ~0; downslam (socar caindo) = "GUARDA QUEBRADA".
5. Brawler 1 (Agarrão) no boneco/jogador: prende, carrega 0,8 s (quem é carregado não age) e esmaga.
   Enquanto carrega, tomar soco não interrompe.
6. G com carga cheia: ult sai na hora + despertar; 1/2/3 = habilidades.
7. K: comprar capa/aura/skin (aparece no boneco; outro cliente vê); B: roda, clicar emote (sem
   animação ainda; cena mostra aura 5 s).

### Onde paramos
- **Feito nesta sessão (NÃO testado no Studio)** — PESQUISA_BATTLEGROUNDS §10 item 1:
  - **Dash universal no Q** (todo personagem; gamepad X; botão DASH no mobile). `CombatConfig.Dash`:
    sem dano, segue o WASD, lateral/trás 2 s, frontal 4,5 s (um timer só). Sai durante hitstun de soco;
    não sai em stun duro (parry/guard break/habilidade: `CombatService.IsHardStunned`).
    Fluxo: `RequestDash(dir)` → `MovementService` valida → `NotifyDash` (todos) → `MovementController`
    move o dono (LinearVelocity dirigível, código que era do AbilityController) + rastro/anim/som
    (`Shared.Dash` / `Shared.DashBack` — DashBack tem id da equipe; Dash está vazio).
    Cooldown: `NotifyDashCooldown(kind, readyAt, total)` → slot "Dash" (Q) no HUD.
  - **Habilidades viraram 3 slots E/R/T** (gamepad Y/B/R2). Saíram os dashes de personagem que só
    andavam: `Mystic.ArcaneStep`, `Sahur.DrumStep`. Ficaram os que dão dano (Brawler ShoulderBash E,
    Guardian ShieldBash E) e o Blink do Swift (E). Ult continua sendo o slot com EnergyCost 100 (T).
  - **Ragdoll de combate** (`RagdollService` + `RagdollRig` compartilhado, reversível: Motor6D
    desligados + BallSocket, HRP sem colisão, PlatformStand). Quem derruba: `Knockback.Ragdoll` (s):
    4º M1 1,6 s · finisher 2,2 s · GroundSlam/Bombo 1,5 s · Meteoro 2 s · boss Slam 1,5 / Charge 1,8 /
    Shockwave 2 s. Caído: sem M1/block/habilidade; leva follow-ups; perde o block.
    Morte usa o mesmo `RagdollRig.Apply` (permanente). Atributo `Ragdolled` no Player + `NotifyRagdoll`.
  - **Ragdoll cancel**: Q caído → levanta na hora + 0,5 s de i-frames (`IFramesUntil` no personagem,
    `HealthService.ApplyDamage` respeita) + sai em dash; cooldown 20 s (`CombatConfig.CombatRagdoll`).
    Levantar sozinho dá 0,2 s de i-frames. HUD: slot Q vira "Levantar" com o cooldown do cancel;
    banner "CAÍDO — Q para levantar".
  - UI regerada (`tools/gerar_ui.py`, `tools/gerar_mobilegui.py`): HUD com frame `Abilities.Dash` +
    Slot1..3; Controles atualizados; MobileGui com botão DASH. `podar_vfx` rodado (Shared/Dash e
    Shared/RagdollCancel reaproveitam efeitos já podados). Sons `Shared.Dash`/`RagdollCancel` reaproveitam
    os ids que eram do ArcaneStep/DrumStep.
- **Também nesta sessão (NÃO testado)** — §10 itens 2, 3 e 4:
  - **M1 em %** (`CombatConfig.Attacks.M1.ComboDamage = {3,3,4,5}`), cooldown 0,3, downtime 1,2 s após o
    4º; **hitstun 0,7 s** (só sai por Q ou parry); **puxão** de 1 stud no acerto (cliente); M1 no block
    = endlag ×2. **Uppercut** = socar subindo logo após pular (alvo e atacante sobem); **Downslam** =
    socar caindo (ignora block → guard break, ragdoll 1,2 s, não repete em quem já está caído).
    Servidor confere subindo/caindo pela velocidade Y do HRP (`AirRisingSpeed`).
  - **Block só frontal** (`Block.FrontDot`; golpe por trás entra cheio), −90%, guarda 30, lockout 0,2 s
    depois de socar. **Parry** agora atordoa só 0,4 s e arma o **CRÍTICO** (próximo M1 ×3 em 4 s;
    contorno vermelho); crítico + novo parry+crítico em 4 s = **BLACK FLASH** ×6. `HitOptions` no
    `ResolveHit` (IsM1/BreaksBlock/RagdollOnce); ele agora retorna o `kind`.
  - **Awakening (G)**: carga cheia → `RequestAwaken` → 20 s com +30% dano, +10% velocidade, 0,6 s de
    i-frames, aura (`Shared/Awakening`, contorno dourado), barra vira contagem "DESPERTO"; **T (ultimate)
    só funciona no modo** (slot mostra "G" trancado) e não gasta carga. Parry dá +10 de carga.
    Brawler `Rampage` virou golpe em área (30 de dano, ragdoll) porque o buff já é do modo.
    `CombatService.RestoreWalkSpeed` é público (MovementService/AbilityService usam).
- **Também nesta sessão (NÃO testado)** — §10 item 5:
  - **Kill streak** (`MatchConfig.KillStreak`, atributo `KillStreak` no Player, zera ao morrer): marcos
    3/5/10 e a cada 5 → `NotifyStreak "milestone"` (banner para todos, +10 moedas); ≥ 10 → aura dourada
    (`FX.SetAura`, por atributo replicado); matar quem tinha ≥ 5 → "shutdown" (+2 moedas × streak).
  - **Duelo melhor de 3** (`DuelConfig.RoundsToWin = 2`, `MaxRounds = 3`, `BetweenRounds = 3`): cada
    round = contagem → luta → `round_end` (placar); quem morre renasce no mapa com CanFight=false e
    volta à arena no round seguinte; série fecha em 2 vitórias (ou 3 rounds, mais vitórias ganha).
    DuelController mostra "Round N — Preparar…", placar entre rounds e no fim.
  - **Enrage do boss** (`BossConfig.Enrage`): 6 golpes em 3 s → ruge (Roar), cura 50% do dano da janela,
    +30% dano/velocidade por 8 s, contorno vermelho + banner (`NotifyBoss "enrage"`); recarga 25 s.
- **Anterior, também não testado**: sem energia nas habilidades (só cooldown), barra "ULT %".

### Roteiro de teste (Studio, 2 clientes ou boneco de treino)
1. Q parado/andando: dash na direção do WASD, rastro, slot Q com cooldown (2 s lado, 4,5 s frente).
2. Levar soco e apertar Q no meio do hitstun: deve sair. Ser parryado/guard break e apertar Q: não sai.
3. Combo de 4 no boneco/jogador: no 4º o alvo cai (ragdoll ~1,6 s) e levanta sozinho sem travar
   (se ficar deitado/tremendo, avisar: é o `ChangeState(GettingUp)` do cliente).
4. Caído, apertar Q: levanta na hora, pisca branco, sai em dash; slot Q mostra 20 s de "Levantar".
5. Morrer caído e morrer em pé: ragdoll de morte e respawn normais.
6. E/R/T = habilidades (cartão de personagem mostra E/R/T); GroundSlam/Meteoro derrubam.
7. Boss: Slam/Charge/Shockwave derrubam; Q levanta.
8. Combo no boneco: números 3/3/4/5; atacante desliza 1 stud a cada acerto; após o 4º, 1,2 s sem socar.
9. Pular e socar subindo: uppercut (os dois sobem); socar caindo: downslam (alvo cai; contra block
   = "GUARDA QUEBRADA"). Se o uppercut nunca sair, me diga (janela de "subindo" pode estar curta).
10. Block de costas para o atacante: dano cheio. Parry (F no último instante): contorno vermelho em
    você → próximo soco "CRÍTICO"; repetir parry+crítico em 4 s → "BLACK FLASH".
11. Carga cheia → G: banner "DESPERTAR", aura, barra dourada contando 20 s, T destrava; antes disso T
    mostra "G" e não sai.
12. Kill streak (2 clientes): 3 kills seguidas → banner para todos; morrer zera. (10 = aura.)
13. Duelo 1v1: morrer no round 1 → renasce no mapa, 3 s depois volta à arena para o round 2; placar
    "1 x 0"; série acaba em 2 vitórias.
14. Boss: bater 6+ vezes em 3 s → "ENRAIVECEU", rugido, contorno vermelho, cura visível na barra.

### Próximo passo
- §10 está TODO implementado + leva 2 do dono; agora é testar (roteiros acima) e balancear.
- Converter mais habilidades em agarrão se o dono quiser (só as corpo a corpo); versões "despertas".
- Depois: wall splat (4º M1 perto de parede + dash), versões "despertas" das habilidades, mastery por
  personagem, gamepass "Servidor privado+", emotes (B), drop raro do boss para o top de dano.
- Pendências do dono: apagar `Workspace.TopbarPlus` (Example); ids dos produtos/passes no
  `ShopConfig`; retratos em `CharacterDefs.<Id>.Image`; animações `Shared.Dash`, `Shared.Downslam`,
  `Shared.Uppercut`, `<Char>.Awakening` (opcional), Boss.Slam/Charge/Shockwave/Leap e Sahur.*;
  sons `Shared.Crit/BlackFlash/Awakening` (caem no Finisher_Hit/nada); passada de sons/VFX olhando junto.

## Histórico (2026-09-15, manhã/tarde — balanço antes de limpar o contexto)

### Estado geral
- Place OFICIAL: **126518739287432** (jogo de GRUPO). O antigo 85844807133499 ficou para trás. O Rojo é
  aditivo e serve para o place aberto no Studio; conectar só no oficial.
- Tudo commitado e enviado (`git push` feito por mim em 2026-09-15).
- Sistemas existentes (todos em `src/`): combate M1/block/parry, 4 personagens (Brawler, Swift, Mystic,
  Guardian) com Q/E/R, mapa livre (MainMap do pack Shadow + `ArenaExtras`), DataStore (moedas,
  personagens, stats), bonecos de treino, placar global, menu Dev, mobile, topbar (TopbarPlus),
  duelo 1v1 (desafio) e 2v2 (salas), altar do boss, progressão (XP/nível, diária, missões), corrida
  (Shift), shift lock próprio (Ctrl), animações da equipe por nome, diagnóstico de animações.

### O que foi TESTADO e está OK (Output de 2026-09-15 10:42)
- Boot: 17 services / 10 controllers sem erro. DataStore carregando e salvando (605 moedas).
- Progressão: recompensa diária caiu no login (+25). AnimCheck: **todas as 15 animações da equipe
  são R6 e o grupo tem acesso** (Idle/Walk/Run/M1/Blue/Charge Punch/Dash/Vergil/Beatdown/Taunt).
- Sons dos packs: `TestSounds` → **1477/1477 OK** (pode-se escolher sons dos packs por id).
- Brawler ShoulderBash/GroundSlam executam (dano nos bonecos OK), cooldown/energia negam certo.

### Sessão 2026-09-15 (tarde) — leva de correções pedida pelo dono (FALTA TESTAR tudo)
- **Rig R6 forçado** (`CharacterService`): TESTADO OK — animações tocam no jogador.
- **Dash direcional e dirigível**: cliente manda a direção do WASD no `RequestAbility(slot, dir)`;
  servidor valida (`sanitizeDirection`) e usa na hitbox (`Hitbox.InDirection`) e no teleporte do
  Swift. Durante o dash o `LinearVelocity` (modo Plane) segue o WASD frame a frame.
- **Mystic ganhou dash** (`ArcaneStep`, Q); Projétil Arcano foi para E, Restaurar R, Meteoro T.
  Agora existem **4 slots** (Q/E/R/T; gamepad X/Y/B/R2). HUD/Mobile/Help atualizados.
- **Corrida automática** ao andar para a frente (W ou analógico; `FORWARD_DOT = 0.6`); lados/trás
  só anda. Mobile: botão CORRER força. **Shift = shift lock**; Ctrl livre.
- **Recompensa diária removida** (ProgressionService/ProgressionConfig); missões e nível ficam.
- **UI refeita, minimalista** por `tools/gerar_ui.py` (HUD, CharacterSelect com cartões, Perfil,
  Controles, **Loja**). Rodar o script depois de editar; controllers ligam pelo nome.
- **Loja** (`ShopConfig` + `ShopService` + `ShopController` + `ShopGui`, ícone "Loja"/B):
  moedas por Developer Product (3 pacotes) e 3 Game Passes (Moedas x2, Todos os personagens, VIP).
  Ids = 0 → "EM BREVE". O dono cria no Creator Dashboard (grupo) e cola em `ShopConfig.luau`.
  Perks por atributo: `CoinMultiplier` (DataService.RewardCoins), `XpMultiplier`, `NameTag`.
- Topbar: HUD e topbar aprovados pelo dono. "Personagens" virou DROPDOWN (sub-ícone por personagem,
  usar/comprar; `refreshCharacterIcons`); CharacterSelect.Panel ficou de reserva. `reportForeignTopbar`
  avisa no Output o caminho de outro `Icon`/"Example" do place (o dono apaga).
- Dash: direção travada no início, correção máxima `DASH_STEER_RATE` (2,2 rad/s); lateral dura 65%
  (`DASH_SIDE_SCALE`). Dev icon agora fecha junto com os outros (autoDeselect padrão).
- "Example" do topbar: é o `READ_ME` (Script RunContext Client) dentro da pasta TopbarPlus do place —
  o dono apaga a pasta TopbarPlus alheia inteira (a nossa é ReplicatedStorage.Shared.Packages.Icon).
- Dash em parede/personagem: raycast (cabeça/tronco/pés) encerra o LinearVelocity antes do obstáculo;
  FallingDown/Ragdoll desligados no cliente. Hitbox só conta partes diretas do personagem (acessório
  gigante não aumenta hitbox). FALTA TESTAR.

### Fase 1 — sensação de combate (2026-09-15, FALTA TESTAR)
- `CombatConfig.HitStun` (0,35 s, WalkSpeed 6): levar soco/habilidade interrompe combo e freia.
- Guarda (`Block.GuardMax` 60, regen 20/s após 1 s): cada golpe bloqueado gasta o dano bruto; zerou =
  **guard break** (`kind = "guardbreak"`: dano cheio, block cai, stun 1,6 s, VFX Dizzy + HeavyHit).
- **Finisher**: 4º golpe em alvo com ≤30% de vida (`Finisher.LowHealth`) → `kind = "finisher"`,
  knockback 75, hitstop 0,14 s, shake forte, VFX Todo/HeavyHit.
- **Ragdoll na morte** (`HealthService.ragdoll`): Motor6D → BallSocket, PlatformStand, empurrado
  para longe do último atacante via NotifyKnockback; VFX RagdollWind.
- `restoreWalkSpeed` centraliza block > hitstun > corrida > normal (DevSpeed manda).
- Sons: `Sounds.model.json` preenchido com 41 sons dos packs escolhidos por nome (ver PackSounds).
  Trocar = editar o SoundId lá. Novos: GuardBreak, Finisher_Hit, Mystic/ArcaneStep(_Hit).
- VFX novos em `Assets.VFXPack`: Shared/FinisherHit, GuardBreak, Stun (Dizzy, segue), Ragdoll (segue),
  Mystic/ArcaneStep(_Hit). `tools/podar_vfx.luau` rodado (288 instâncias).

### Rodada de polimento 2026-09-15 (FALTA TESTAR)
- Decisão do dono: **chega de sistemas novos**; polir. Só mais um personagem: **Sahur** (acesso
  antecipado, `Access = "early"`, só devs usam) e **Guardian virou VIP** (`Access = "vip"`: passe VIP
  ou "Todos os personagens"). `CharacterDefs.AccessOf`, `DataService.HasCharacter` decide.
- Dropdown Personagens: rótulos "· VIP" (clique abre a Loja) / "· em breve"; `RequestProfile` novo
  (o 1º NotifyProfile saía antes do boot do cliente → "pede pra comprar mas já tenho").
- Dropdown fecha com os outros menus: `Utility.joinFeature` desliga autoDeselect do pai; religado.
- Dash: `DASH_STEER_RATE` 5.0 (curva, não inverte), folga 3,5; ao parar em obstáculo zera a
  velocidade horizontal (era isso que jogava para o lado contrário).
- Sons: 18 ids eram uploads recentes/privados (User is not authorized) → trocados por ids antigos
  públicos. Regra: preferir ids < 10 bilhões do catálogo; TestSounds (PreloadAsync) NÃO detecta.
- "Example": é `Workspace.TopbarPlus` (pasta inteira, com READ_ME) — o dono apaga.
- Boss: dono acha "incompletinho"; aguardando lista do que falta (visual do rig, mais golpes, barra).

### Rodada 2 de polimento (2026-09-15, FALTA TESTAR)
- Dash (`CharacterDefs.DashTuning`): frente/trás ×1,4, lateral ×1,0, correção 8 rad/s; parede/jogador
  só zera o empurrão naquele frame — a duração continua contando (sem dash grátis); ao terminar,
  velocidade cai para WalkSpeed (sem momento residual → AntiExploit parou de rubber-bandar).
  `AntiExploit.Grace` nunca encurta uma graça maior.
- Segurar Mouse1 = combo de 4 automático (cliente repete no ritmo do Cooldown; servidor impõe
  ComboEndCooldown).
- Seleção de personagem voltou a ser painel (cartões estilizados: faixa de cor, retrato/inicial,
  selo GRÁTIS/MOEDAS/VIP/ACESSO ANTECIPADO, tagline, habilidades, botão USAR/COMPRAR/ABRIR LOJA).
  `CharacterDefs.<Id>.Image` = rbxassetid do retrato (o dono cria). Dropdown removido.
- Boss: 6 golpes (Swipe, Slam, **Shockwave** anel 18, **Leap** pulo em área, **Roar** atordoa 1,2 s
  na fase 2 e na virada, Charge fase 2), escolha ponderada (`Weight`), alvo por agressão
  (`BossConfig.AI`: quem mais bateu, perto, sem bloquear; reavalia a cada 5 s), fase 2 com
  cooldown ×0,7, dano ×1,2 e combo Swipe. Animações Boss.Slam/Charge/Shockwave/Leap vazias (equipe).

### BUGS / PENDÊNCIAS ABERTAS (ordem de prioridade)
1. **Animações não aparecem no jogador** (boss/bonecos OK). Causa confirmada em 2026-09-15 11:00: o
   jogador nasce **R15** mesmo com Game Settings em R6 e sem StarterCharacter. Solução aplicada
   (FALTA TESTAR): `CharacterService` desliga `Players.CharacterAutoLoads` e monta o personagem R6
   no servidor com `CreateHumanoidModelFromDescription(avatar do jogador, R6)`; todos os
   `player:LoadCharacter()` viraram `CharacterService.Load(player)`; respawn automático após
   `CombatConfig.RespawnTime`. Esperado no Output: `[CharacterService] rig R6 forçado...` e SEM o
   aviso `[HealthService] rig do jogador é R15`. Histórico do problema:
   Todas carregam (AnimCheck OK) mas o personagem não mexe.
   O log de 10:42 dizia `[HealthService] rig do jogo é R15`; o dono garante que o Game Settings está
   em R6 e que NÃO há StarterCharacter/StarterHumanoid. PRÓXIMO PASSO: dar Play e ler a linha
   `[HealthService] rig do jogador é ...` (aviso reescrito em 1381d25). Se ainda for R15: o Game
   Settings pode não ter sido salvo/publicado, ou o place tem outro script que troca o personagem
   (ver item 2). Se for R6 e mesmo assim não tocar: investigar prioridade (MovementController toca
   Idle/Walk/Run em `Movement`; M1 em `Action` via FX.PlayAnimation) e se o `Animate` padrão foi
   substituído por algo do place.
2. **Scripts estranhos do place** (vieram com o mapa do pack, não são nossos, apagar no Studio):
   `Workspace."Animation Maker"` (erra `attempt to index nil with 'findFirstChild'` ao sair; mexe em
   animação do jogador), o **"♡ Example"** no topbar (segundo TopbarPlus, script de exemplo — achar
   com Find All "Example"/"Icon" fora das nossas pastas), plugin "Ro-Defender" (inofensivo).
   Também `Workspace.Textures.*` (asset 18221073047 inserido pelo dono) gera dezenas de erros de
   textura "not approved" no log — decidir se fica.
3. **Topbar "fora do padrão do Roblox"** segundo o dono (no place-cópia estava certo). Print mostra
   nossos 6 ícones + "Example". Hipótese principal: o Example (2º TopbarPlus) bagunça o layout.
   Se após removê-lo continuar diferente, pedir print do "certo" para comparar (pode ser
   `StarterGui.ScreenOrientation`/`IgnoreGuiInset`/tema do TopbarPlus).
4. **Shift lock no Ctrl**: 1ª versão (rebind do MouseLockController) falhou porque o PlayerModule
   desse place não é o padrão. 2ª versão (nossa, `MovementController` + `EnableMouseLockOption=false`
   no project.json) AINDA NÃO FOI TESTADA pelo dono.
5. **Não testado ainda** (precisa de gente ou de tempo): duelo 1v1 (2 clientes), 2v2 (4 clientes),
   boss completo (anel, fases, recompensa, XP), missões concluindo, subir de nível, corrida (Shift),
   Swift/Mystic/Guardian com as anims novas, mobile (botão CORRER).
6. **Sem animação ainda** (AnimationId vazio = não toca nada): Shared Block/Parry/Hit, Swift
   Blink/SweepKick, Mystic ArcaneBolt/Mend/Meteor, Guardian Fortify/Quake, Boss Slam/Charge.
   Escolher no preview (`packs/Import/AnimPreview.rbxm`) e publicar no GRUPO.
7. **Sons**: todos os `Sounds.model.json` continuam com id vazio. Os 1477 dos packs estão OK;
   preciso que o dono escolha (ou eu escolho por nome: Misc/Swing/Fist*, Misc/Block/Block*,
   Misc/Items/Parry, Misc/Dash, Impact/Players/Death…). `PackSounds.luau` tem a lista.
8. **Mapeamento das anims** foi decisão minha (ver item 9 abaixo); o dono pode querer trocar
   (ex.: Charge Punch no 4º soco, Blue no Rampage). `Shared/DashBack` está sem uso.
9. Mystic não tem mobilidade no Q (ArcaneBolt); o dono disse "Q = dash/teleporte de cada
   personagem" — confirmar se quer trocar o Q do Mystic.
10. `Studio access to APIs` está ligado no place oficial (DataStore OK). O LeaderboardService
    ainda avisa no boot antes de conseguir — normal.
11. Avisos DeprecatedApi `LoadCharacter` (6 lugares) — cosmético.

### Feito nesta sessão (2026-09-15), em ordem
1. **2v2 por salas** (`DuelService`: create_room/join_room/switch_team/leave_room/list_rooms;
   `DuelGui` abas 1v1/2v2; `DuelConfig.TeamSize=2`). Auto-inicia com 4.
2. **Progressão**: `ProgressionConfig`/`ProgressionService`; perfil ganhou xp/level/daily/missions
   (migração tolerante). XP kill 20, duelo 60/20, boss bolo 300; nível `100+40·n`, máx 50, paga
   moedas; diária 25+10/dia (máx 7); 3 missões/dia por jogador, recompensa automática.
   ProfileGui 620 px (nível/XP à esquerda, missões à direita). `NotifyProgression` → banners.
   Menu dev: "Somar XP", "Missões OK".
3. **Boss com feedback por nome**: `NotifyBoss("attack", {model,name,phase,position,radius})`;
   `Animations.Boss.{Swipe,Slam,Charge,Roar}`, `VFXPack Boss/*`, `Sounds.Boss.*`. Boss e bonecos
   ganharam `Animator` (antes nenhuma animação tocava em NPC).
4. **Movimento**: `MovementService`/`MovementController`. Correr = Shift (WalkSpeed 24, não com
   block; ao soltar o block volta a correr). Dash genérico foi criado e depois REMOVIDO a pedido
   (Q é o dash/teleporte do personagem). Shift lock próprio no Ctrl. Mobile: botão CORRER.
5. **Animações**: `MovementController` toca Idle/Walk/Run por conta própria (prioridade Movement,
   por cima do Animate padrão). `AnimationCheckService` (só Studio) imprime `[AnimCheck]` por id
   (rig/acesso). Ids da equipe encaixados e TODAS as placeholders da Roblox removidas.
6. **Ferramentas**: `tools/juntar_animacoes.luau` → `packs/Import/AnimPreview.rbxm` (32
   KeyframeSequences + preview clicável num place em branco). Fluxo: Insert from File → Play →
   clicar → Save to Roblox com o GRUPO como criador → id.
7. `default.project.json`: `StarterPlayer.EnableMouseLockOption=false`.

### Mapeamento atual das animações (Animations.model.json)
Melee1 → M1_1..3 | Blue (agarra e taca) → M1_4 | Charge Punch → Brawler/GroundSlam + Boss/Swipe |
Vergil practice → Swift/Tempest | Beatdown → Brawler/Rampage | Desafiando → Boss/Roar |
Dash frontal → Brawler/ShoulderBash + Guardian/ShieldBash | Parado/Andando/Correndo → Shared
Idle/Walk/Run | Dash pra trás → Shared/DashBack (sem uso).

### Próximo passo de código (depois dos testes acima)
Encaixar sons por nome a partir dos packs; anims restantes quando vierem ids; balancear
`ProgressionConfig`/`BossConfig`/`DuelConfig`; loja/cosméticos; lançamento (item 9).

## Em andamento
- 2026-09-15 — **Movimento** (correr/dash) + animações de movimento da equipe. FALTA TESTAR: Shift
  corre (anim Run), Ctrl dá dash (anim Dash + rastro), dash negado bloqueando/atordoado, recarga.
- 2026-09-15 — **Progressão** (item 6): ver "Retomar aqui" (XP/nível, diária, missões). FALTA TESTAR.
  Balancear valores em `ProgressionConfig.luau`. Ideia seguinte: títulos/cores de nome por nível.
- 2026-09-15 — Boss com evento `attack` (anim/VFX/som por nome) + Animator nos NPCs. FALTA TESTAR.
- 2026-09-15 — **Altar do boss** (item 8): ver "Retomar aqui". Testar: E no altar, anel vermelho,
  dano com block (70% a menos), fase 2, morte → banner com moedas, altar recarrega 45 s, boss some se
  ninguém ficar na arena por 30 s. Ajustes finos em `BossConfig.luau`.
- 2026-09-15 — **Duelo 1v1 opt-in** (item 5): `DuelService` + `DuelController` + `DuelGui` + `DuelConfig`.
  Ícone "Duelo" (J) lista jogadores → desafiar → alvo aceita (Y) / recusa (N) → cópia de
  `ServerStorage.Maps.Arena_Gerada` em `Workspace.Duels` (céu, 4000/1500/4000, até 8 slots) →
  contagem 3 s → morte/queda/tempo (120 s = empate) → `RecordMatchResult` (+50/+10 moedas) → volta.
  HealthService: sem fogo amigo quando `TeamId` igual. FALTA TESTAR com 2 clientes.
- 2026-09-15 — **2v2 por salas** (item 5b): `create_room`/`join_room`/`switch_team`/`leave_room`/
  `list_rooms` no `RequestDuel`; `NotifyDuel("rooms")` para todos a cada mudança. Sala some quando
  esvazia; dono sai → passa para o próximo. FALTA TESTAR com 4 clientes.
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

## Planos futuros (pedidos do dono, ainda não começados)
- **Guerra de clã/máfia** (2026-09-15): modo em mapa próprio de DOMINAÇÃO (ainda pequeno): um grupo
  contra o outro, pontos de controle a capturar/segurar, placar por clã. Precisa de: sistema de clãs
  (criar/entrar/sair, tag no nome, cofre de pontos), fila/portal para o mapa de dominação, zonas de
  captura (Parts nomeadas + progresso), rodada com tempo e vencedor, recompensas (pontos/roleta).
  Reaproveita: MatchService (modo Teams com FreeRoam=false), DuelService (arenas separadas),
  TeamId/CanFight, ArenaService. Desenvolver depois do polimento do combate.

## Próximos passos (ordem sugerida)
1. ~~Game feel, parte 2~~ (feito).
2. **Mapa**: quando a equipe de arte trouxer meshes, trocar props do `gerar_arena.py` por
   modelos deles (manter nomes/zonas e a pasta `Spawns`).
3. ~~Mobile~~ (feito; falta testar no Device Emulator e ajustar tamanho/posição).
4. ~~4º personagem~~ (Guardian feito); balancear preços/dano com dados de teste.
5. **Modos Duel (1v1) e Teams (2v2)** como opt-in dentro do mapa livre: portal/painel de
   desafio, arena separada (`ServerStorage.Maps.Arena_Gerada` ou `ArenaMap` do pack em
   `ServerStorage.Import`), `FreeRoam` continua para os demais. ← 1v1 e 2v2 FEITOS (testar)
6. **Progressão**: ~~tela de perfil~~, ~~XP/nível, diária, missões~~ (feito 2026-09-15; testar/
   balancear); loja simples/cosméticos e gamepass/Robux só depois de validar a economia.
7. ~~Lobby vivo~~ (dummies + placar feitos); falta: leaderboard também na tela de perfil.
8. ~~Altar para invocar o boss~~ (feito 2026-09-15; falta testar/balancear e animações). Era: altar no mapa (usar meshes de `ServerStorage.Import` ou
   `Arena_Gerada`), interação (ProximityPrompt) que junta jogadores/moedas e invoca um boss NPC
   (rig R6 como os dummies, tag `Combatant`, `Hitbox` já aceita NPC) com IA simples (persegue,
   golpes de área, fases por vida), recompensa em moedas para quem participou; placar próprio.
9. **Lançamento**: `AllowLobbyCombat = false`, `Log.Verbose` automático, publicar privado,
   rodar `CHECKLIST_PUBLICACAO.md` completo.
