# Checklist de publicação — Sahur

Marque cada item antes de publicar. Itens com **[Studio]** são feitos no Roblox Studio /
Creator Dashboard, não no repositório.

## 1. Assets de arte/animação (nomes exatos, em `ReplicatedStorage.Assets`)

Preencher os ids no repositório (`src/assets/Animations.model.json`, `Sounds.model.json`)
ou colocar os VFX direto no Studio dentro das pastas. Sem id = o jogo ignora e avisa
uma vez no Output.

- [ ] Animations.Shared: `M1_1` `M1_2` `M1_3` `M1_4` `Block` (loop) `Parry` `Hit`
- [ ] Animations.Brawler: `ShoulderBash` `GroundSlam` `Rampage`
- [ ] Animations.Swift: `Blink` `SweepKick` `Tempest`
- [ ] VFX.Shared: `Hit` `Block` `Parry` (hoje: partículas mínimas; substituir pelo mesmo nome)
- [ ] VFX.Brawler / VFX.Swift: `<AbilityId>` e `<AbilityId>_Hit` (hoje: `Shared.Placeholder`)
- [ ] Sounds.Shared: `Punch_Whoosh` `Punch_Hit` `Block` `Parry` `Death`
- [ ] Sounds.Match: `RoundStart` `Victory` `Defeat`
- [ ] Sounds.Brawler / Sounds.Swift: `<AbilityId>`, `<AbilityId>_Hit`
- [ ] Mapa(s) reais em `ServerStorage.Maps` (Model + Folder `Spawns` com ≥ 8 Parts);
      remover `Arena_Teste` de `src/maps/` quando houver mapa real
- [ ] Posição do `Workspace.Lobby.LobbySpawn` ajustada ao lobby do mapa

## 2. Performance (alvo: Ryzen 5 5500 / GTX 1650 4 GB, 60 fps com 8 jogadores)

Limites já no código: 12 VFX simultâneos, 30 partículas por emissão, 16 sons simultâneos,
1 Highlight por personagem (limite do engine: 31), barras sobre a cabeça só até 80 studs,
checagem anti-exploit a cada 0,5 s, HUD atualiza timer/cooldown a 10 Hz.

- [ ] **[Studio]** Lighting: `Technology = ShadowMap` (Future é caro na 1650), `GlobalShadows`
      ligado só se o mapa precisar; `ShadowSoftness` ≤ 0.2; no máximo 2–3 luzes com `Shadows`
- [ ] **[Studio]** Partes decorativas do mapa com `CastShadow = false` (grades, detalhes, spawns)
- [ ] **[Studio]** Texturas ≤ 1024 px; `MeshPart.RenderFidelity = Automatic`; sem `Glass`/`ForceField`
      em áreas grandes
- [ ] **[Studio]** `Workspace.StreamingEnabled` se o mapa passar de ~10 k instâncias
- [ ] VFX da arte: cada emissor com atributo `EmitCount` ≤ 30, `Lifetime` ≤ 1 s, sem `Rate` contínuo
- [ ] Teste com 8 jogadores no Team Test olhando **View → Stats → Render** (< 16 ms) e
      **MicroProfiler** (server Heartbeat < 5 ms)

## 3. Testes de combate com jogadores reais

- [ ] 2 jogadores: socos, combo (8/8/8/15), block (dano ×0.3), parry (janela 0,2 s, stun 1 s)
- [ ] Brawler: ShoulderBash acerta durante o dash; GroundSlam (30 energia); Rampage (100)
- [ ] Swift: Blink não atravessa parede; SweepKick stuna 0,8 s; Tempest 5 ticks
- [ ] 4–8 jogadores na fila: round inicia com todos, spawns distintos, placar/killfeed corretos,
      último vivo vence, empate no tempo limite
- [ ] Jogador entra no meio do round: fica no lobby, vê estado atual, entra na próxima
- [ ] `MatchConfig.AllowLobbyCombat = false` e confirmar que ninguém bate no lobby

## 4. Reconexão / perda de conexão

- [ ] Jogador sai durante o round → é eliminado, round continua/termina corretamente
- [ ] Jogador sai durante Selecting → fila atualiza; se cair abaixo do mínimo volta a Waiting
- [ ] Reentrar após sair no meio do round: moedas/stats salvos no `leave`
- [ ] Servidor fechando (`BindToClose`): saves concluem (ver Output "salvo (close)")
- [ ] `DataConfig.SimulateFailure = true`: entra com perfil temporário, aviso na HUD, nada salvo;
      voltar para `false` depois
- [ ] Desligar internet com Play aberto: autosave falha com warn, jogo continua

## 5. Revisão final de segurança (AntiExploitService + AUDITORIA_REMOTES.md)

- [ ] Reler `AUDITORIA_REMOTES.md`; todo remote novo desde então tem throttle + validação
- [ ] AntiExploit: testar speed hack simulado (Command Bar do cliente:
      `game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 100`) → após ~1,5 s o servidor
      loga rubber-band e devolve o personagem
- [ ] AntiExploit: dash/blink/spawn do round NÃO geram falsos positivos (Output sem warns)
- [ ] Nenhum `RemoteEvent` fora de `RemoteEvents.luau`; nenhum `OnServerEvent` sem checar tipos
- [ ] `Log.Verbose` fica automático (só Studio); nenhum `print` de debug fora de `Log.debug`

## 6. Página do jogo no Roblox **[Studio / Creator Dashboard]**

- [ ] Ícone 512×512 e thumbnails 1920×1080 (mín. 1, ideal 3: combate, personagens, mapa)
- [ ] Nome e descrição (modos: FFA agora; 1v1/2v2 em breve; controles: Mouse1 soco, F block,
      Q/E/R habilidades)
- [ ] Gênero: Fighting; Dispositivos: PC (+ console/mobile só depois de testar input)
- [ ] Máximo de jogadores por servidor: 8 (= `MatchConfig.Modes.FFA.MaxPlayers`)
- [ ] Game Settings → Security: **Enable Studio Access to API Services** ligado (DataStore)
- [ ] Game Settings → Avatar: **R6**
- [ ] Permissões: quem pode editar (Team Create), Private Servers on/off
- [ ] Publicar como **privado** primeiro, testar com a equipe, depois público

## 7. Repositório

- [ ] `PROGRESSO.md` reflete o estado real (feito / em andamento / próximos)
- [ ] `tools/analisar.sh` sem erros
- [ ] `git status` limpo e commit com a versão publicada
