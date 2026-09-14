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

## Em andamento
- Validar no Team Test: block/parry, Swift (Blink/SweepKick/Tempest), speed hack simulado
  (AntiExploit), `DataConfig.SimulateFailure = true`.
- Receber ids das animações/sons da equipe e preencher `src/assets/Animations.model.json`
  e `Sounds.model.json`; VFX por nome no Studio (lista em CHECKLIST_PUBLICACAO.md §1).
- Levantamento do mapa/lobby reais no Studio (posição do `Lobby.LobbySpawn`, mapa em
  `ServerStorage.Maps`).

## Próximos passos (ordem sugerida)
1. **Sensação de combate (game feel)**: knockback no finisher e no GroundSlam (servidor manda
   impulso, cliente aplica; `AntiExploit.Grace`), hitstop curto, tremor de câmera leve,
   dano flutuante (números) sobre a vítima, indicador de combo na HUD.
2. **Espectador**: eliminado assiste a câmera de quem ainda luta até o fim do round
   (troca com Mouse1/setas), em vez de esperar no lobby.
3. **Mobile**: botões na tela para block e Q/E/R (hoje toque = soco); testar no
   Device Emulator.
4. **Mais personagens** (escalar `CharacterDefs`): 3º e 4º estilos com novos tipos de efeito
   (projétil, contra-ataque, cura), preços de desbloqueio balanceados.
5. **Modos Duel (1v1) e Teams (2v2)**: seleção de modo na fila (ou rotação), cor de time na
   HUD/overhead, sem dano entre aliados (`TeamId` já existe no MatchService).
6. **Progressão**: tela de perfil (stats, moedas, personagens), loja simples, gamepass/
   Robux só depois de validar a economia.
7. **Lobby vivo**: dummies R6 para treinar (Hitbox já aceita NPC), placar de líderes
   (OrderedDataStore de vitórias).
8. **Lançamento**: `AllowLobbyCombat = false`, `Log.Verbose` automático, publicar privado,
   rodar `CHECKLIST_PUBLICACAO.md` completo.
