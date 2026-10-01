# PROGRESSO — Sahur

Memória entre sessões. Atualizar depois de cada mudança.

## Revisão do lobby de pré-lançamento — 01/10, noite (Claude; Play via MCP como jogador)

- Tela de título: escondia nada → agora esconde HUD/topbar/hotbar enquanto aberta (volta ao ir para o lobby); câmera
  em vai-e-vem POR FORA do Coliseu, lado norte (montanha ao fundo) — por dentro passava no meio das colunas.
- Lobby: hotbar padrão do Roblox (Tools) escondida enquanto preso (ficava por cima dos slots 1–4/R/G); faixa do lobby
  mais larga (texto numa linha). Painel APOIAR/SOBRE conferido em print.
- Studio-only: atributo `IntroDebug` = "lobby" | "panel" abre lobby/painel sem clique (teste automático pelo MCP).
- Dica da missão "Rumo à Cidade Âmbar" atualizada (portal âmbar ao lado do Pescador da Rota).
- **Developer Products de doação CRIADOS** (dono liberou `developer-products` na chave) por `tools/criar_doacoes.py`:
  Apoiar 10/50/100/500/1000 = 3715867985 / 3715867991 / 3715867993 / 3715868000 / 3715868004 (à venda, preço = valor),
  gravados em `LaunchConfig.Donations` e sincronizados no Studio. Falta só o dono PUBLICAR pelo Studio.

## Cidade Âmbar (Ilha 4) — mapa montado — 01/10, noite (Claude; Studio conectado via Rojo/MCP)

- `tools/gerar_cidade_ambar.py` → `src/workspace/FXCidadeAmbar.model.json` (Workspace.Sahur.FXCidadeAmbar, 653 peças,
  só SmoothPlastic/Neon). Ilha própria a LESTE da Rota do Eclipse, centro (2330, −120), `FXRadiusX/Z` 230/200; chão
  com topo/praia/areia molhada/rampas no esquema do `gerar_chao_ilhas.py` (que continua proibido de rodar). Cais + píer
  a oeste (chegada, marco do checkpoint, portais `AmbarToSolPartido` e `AmbarToCosta`), avenida L–O + rua N–S, praça
  com fonte (= `AmbarCentro`), ~25 casas, café, feira, Posto da Guarda (quadro de pistas), escola, parque de outono,
  Casa Vazia oca (ruptura neon dentro) e pátio do chefe no leste. Todos os 17 marcadores do contrato; portal de ida
  `SolPartidoToAmbar` na pasta `PortalRota` (1695, 8, −152), ao lado do portal para o Deserto. Rodar o gerador de
  novo SOBRESCREVE edição manual dentro desse Model.
- `CidadeAmbarService`: NPCs R6 parados em `AmbarHumanoider` (avatar do guia), `AmbarMorador1/2`, `AmbarTestemunha`
  (dentro do mapa; o prompt continua no marcador). `StoryNavigation`: GPS dos objetivos `fx_ambar_*`.
- `VillagerService`: pontos `VilaWaypoint` agrupados pelo Model de cada mapa (antes misturava tudo → morador andaria
  pelo mar); `VillagerCount` no Model (Âmbar = 9, padrão 12).
- Testes `cidade_ambar` e `factions_hunts` quebravam desde o pré-lançamento (`PreLaunch = true` manda para o lobby /
  esconde facção) → desligam o `PreLaunch` no setup. 13 suítes OK; análise estática limpa.
- Play (MCP, servidor): região disponível, chegada (2170, 0.35, −120), 4 NPCs, 17 prompts, portal de ida com prompt,
  O Homem Sem Sombra no pátio, 9 moradores na cidade + 12 na Vila Nova, `IslandAt` = cidade_ambar. Prints do visual OK.
- **Falta o dono**: ver/andar na cidade (DEV → teleporte ou flag `cidade_ambar_unlocked`), aprovar o visual, publicar
  pelo Studio. Ainda pendente do contrato: kit próprio do chefe (ocultação/memória/duplicação), rotinas por horário,
  escola/esgoto/segredos, encenação das tarefas.

## Pré-lançamento + montanhas low-poly — 01/10, tarde (Claude; Studio conectado via Rojo/MCP)

**Pedido do dono:** jogo publicado NÃO jogável até o lançamento: entra → "Play intro" (trailer) → lobby de testes
(testar coisas, ver features, DOAR Robux). Deixar claro que as imagens são feitas com IA por enquanto e que a ideia é
original. Decisões (dono): lobby = **Coliseu do Deserto**; intro **ao vivo só no cliente**; doações **10/50/100/500/1000**
com placar e tag de Apoiador. WAREA ignorado.
- `LaunchConfig` (shared): `PreLaunch = true`, lobby, kits de teste, doações (productId 0 = "em breve" — **o dono cria
  os 5 Developer Products no Creator Hub do GRUPO e cola os ids**), textos de transparência e "o que vem aí".
  `LaunchConfig.Locked(player)` = pré-lançamento e não dev (ou dev com DEV → Teste → "Ver como jogador (lobby)").
- `LaunchService`: atributo `PreLaunchLocked`; spawn no Coliseu (`WorldService` só na sessão, checkpoint salvo
  intacto); fora do raio 112 ou caiu → volta ao centro; sem menu de facção (`FactionService.Refresh`, senão sem dano);
  Eco pendente não abre; 4 bonecos "Treino" (bots passivos, sem XP/loot); kit de teste só na sessão com todas as teclas
  (`LobbyTest` pula a maestria no `AbilityService`). Doação: `ShopService.processReceipt` → `DonationHook` →
  `RecordDonation` (DataStore `Donations_v1` com PurchaseIds = idempotente, OrderedDataStore `DonationsTop_v1`),
  atributos `Supporter`/`Donated`. Remotes `RequestLaunch`/`NotifyLaunch`/`FetchLaunch`.
- `IntroController`: tela de título (órbita no Coliseu, PLAY INTRO / IR PARA O LOBBY, aviso de IA embaixo); intro de
  ~33 s ao vivo (`TrailerController.Dispatch` com `hideHumanoids`: Porto → 4 lugares → Coliseu "THE ARROW CHOOSES." →
  santuário à noite → logo); faixa do lobby + painel APOIAR/SOBRE (testar Stand, doar, placar, o que vem aí, sobre,
  ver a intro de novo); esconde FXStoryGui/FXChoiceGui/GoalsGui/HuntGui/FactionGui/QuestGui enquanto preso.
- Testado no Play (MCP): trava/destrava, spawn e volta ao Coliseu, 4 bonecos, gancho de doação; cliente sobe sem erro.
  **Falta o dono ver a tela de título/intro/painel** (não tirei print: o dono estava em outro jogo).
- Lançou → `LaunchConfig.PreLaunch = false`.
- **Montanhas** (dono: "estranhas, muitas partes, feia, exagerada → simples mas bonita"): `tools/studio/
  MontarRelevoLowPoly.luau` (ModuleScript em ServerStorage.FerramentasStudio) gera uma casca LOW-POLY (triângulos de 2
  WedgeParts, SmoothPlastic, faixas pé/rocha/topo com sombreado por face) que embrulha o núcleo: contorno radial justo
  (0 cantos do núcleo furando), pé recua para não tocar Coliseu/templos/tijolos/parque, faces que encostariam em algo
  são puladas, zonas abertas (porta da Taberna/`cav`, cachoeira). Gerado no Studio em `Workspace.Sahur.RelevoLowPoly`
  (~200 peças cada, antes 209/295 lascas); o `Relevo` antigo está só ESCONDIDO na tela de edição. **Falta o dono
  aprovar visualmente**.
- **Dono reprovou ("ficou ruim") → tiradas as DUAS capas** (lascas de 30/09 e a low-poly): `src/workspace/Relevo.rbxm`
  apagado (Rojo removeu `Workspace.Sahur.Relevo`) e `RelevoLowPoly` apagado no Studio. Montanhas = só os núcleos
  originais de blocos (MontanhaSantuario em ChaoIlhas, RochaTaberna em PecasArena). O dono vai refazer depois, à mão.
  Não rodar `montar_relevo.luau` nem `MontarRelevoLowPoly` de novo sem ele pedir.
- Bateria offline: 11 suítes de `tests/` passaram; análise estática limpa. MCP: a ponte 44755 tinha morrido (meu
  servidor ficou em modo proxy) → subi um `rbx-studio-mcp --stdio` primário em segundo plano.

## Auditoria da publicada e conciliação com Claude — 01/10 (Codex)

- Conferida diretamente no Studio a publicada **85844807133499, versão 489**: trailer V3 e modelos CC0 presentes,
  mas MusicController, Assets.Sounds.Music, NpcAppearance, HudLayout, facções, caçadas, portos e puzzles ausentes.
  BotService da publicada não usava NpcAppearance. Isto explica música ausente e inimigos com skins antigas.
- A leva RPG estava somente em `codex/hud-pve-portos-cc0`; o checkout principal usado pelo Claude permanecia
  na base `edb70e0`. Conciliados os 102 arquivos da leva no checkout principal, preservando sete arquivos de
  trailer/DEV do Claude, seu PROGRESSO, CLAUDE.md e capas. Mudanças do trailer também incorporadas nesta branch.
- Rojo agora serve o **checkout principal conciliado** em `127.0.0.1:34872`. Nova leitura no Studio confirmou todos
  os dez grupos de sistemas presentes, BotService usando NpcAppearance, três músicas e trailer V3 preservado.
- Play da combinação confirmado: NPCs gerados com camisa, calça e acessório próprios; trilha Village carregada,
  tocando (`IsLoaded=true`, `IsPlaying=true`, 90 s, volume 0,1925). Análise estática passou.
- Publicada ainda é v489: somente o dono publica pelo Studio.
  Não foi usada API de publicação nem build Rojo para substituir a place.

## Backup e envio ao GitHub — 30/09, 23:55 (Codex)

- A pedido do dono, todas as mudanças desta leva foram registradas no commit `653ab99` e enviadas a
  `origin/codex/hud-pve-portos-cc0`. O checkout anterior estava em detached HEAD; a branch preserva o trabalho.
- Place completa salva pelo **Studio → Arquivo → Baixar uma cópia** em
  `backups/place-hud-portos-2026-10-01.rbxl` (2.239.299 bytes, 26.781 instâncias). Backup local ignorado pelo git,
  conforme política do projeto. Não é `rojo build`, não substitui a place e não foi publicado.
- Arquivo lido/verificado: Terrain, Taberna/cav, embarcação importada e serviços novos presentes; nenhum dos
  três scripts temporários de verificação. SHA-256:
  `739ab309cb13d9515f413a92e9abeda9f2ad827dd8210328d90e6be9ffd470a9`.
- Studio em Edit, Rojo conectado. O dono publicará a sessão atual pelo Studio. Publicação não executada pela IA.

## HUD, música, importação CC0, portos e ciclo de NPCs — 30/09 (Codex; Studio conectado)

**Estado atual:** Rojo servindo `127.0.0.1:34872`, conectado à place **85844807133499** pelo Studio do dono.
Esta entrada supersede os estados “Studio fechado / assets ainda sem importação” da leva abaixo. Sem publicação,
sem `rojo build`, sem alterações no manifest aditivo ou nos modelos/terreno de arte da equipe. Adições de mapa
são de runtime. Não salvar o Play como snapshot de construção.

- **HUD:** moedas, nível, XP, vida e despertar maiores e legíveis; botões amarelos Mochila/Perfil/Objetivos/Menu
  sempre visíveis, slots de habilidades maiores e requisitos de maestria escritos. Menu de facção acompanha a
  apresentação. O indicador azul é **despertar**, não uma energia nova. Arte de ícones dos kits ainda pendente.
- **Primeiros passos:** painel da missão mostra dica mesmo quando há objetivos, requisito de nível e recompensa;
  orientação com direção/distância para o próximo objetivo obrigatório ou farm necessário. Espera de chefe mostra
  contagem de respawn. Puzzles opcionais não recebem GPS. Não remove os requisitos de nível da campanha.
- **NPCs:** roupa/cabelo/acessórios de catálogo oficial gratuito Roblox, validados por tipo/criador/preço; cinto/
  bolsa próprios. Moradores também ganharam cabelo/roupa. Skins dos Anciões e assets da equipe preservados.
  Treinos pretos desligados (`DummyService.Enabled=false`); pads técnicos específicos invisíveis/sem colisão.
- **Retorno e regeneração:** inimigo comum sai do raio de 100 studs e volta **andando**, com pathfinding, sem
  teleporte ou cura instantânea. Após 15 s sem hit, cura 2% da vida máxima/s; chefe aguarda 30 s e cura 0,35%/s.
  Big C.H.O.P. usa retorno a 180 studs e a mesma política lenta de cura. Vida só fica cheia após regenerar.
  NPC contra NPC continua bloqueado no servidor; aliados de combate ainda não implementados.
- **Respawn:** mobs 20 s, overrides limitados a 10–30 s; Capataz/Máscara 10 min; Herdeiro/Sol Negro/Sol/Âmbar/
  Colapso 15 min; Costa/Avatar 30 min. Big C.H.O.P. 30 min, mantendo condição noturna existente.
  Sem acelerar os eventos raros Mercador/Esferas/Obeliscos, que têm regras separadas.
- **Forja e segredos:** quatro armas adicionais (Sabre Portuário, Espada Caramujo, Lâmina das Marés e Espada do
  Sol Selado), seis receitas no total; quantidades/fontes no menu Objetivos. Fibra rara em farm forte; Núcleo Marinho
  pelo puzzle das três lentes (Lua → Sol → Névoa), Selo Solar pela Câmara existente. Sequência e recompensa por
  jogador, distância/vida/perfil persistente validados, recompensa única, recuperação de saves antigos da Câmara.
  Modelos das armas são provisórios; não representam quatro kits definitivos de combate.
- **Áudio/VFX:** três músicas CC0 (vila/mar/chefe), crossfade/volume configurável; passos, cliques e transformação
  do navio centralizados em FX. Poeira/esteira/Strength/brasa e 12 sprites CC0 por nome, respeitando tetos do FX.
  Os **14 sons usados** (3 músicas + 11 SFX) carregaram no cliente real. `footstep_carpet_000` foi rejeitado pela
  moderação e removido das referências; não tocar nem reutilizar seu ID.
- **Importação concluída da seleção:** 56 uploads de assets no grupo **9835819**, **55 Approved / 1 Rejected**,
  registrados em `ASSETS_ROBLOX_IMPORTADOS.json`. Inclui 18 mapas PBR de 6 materiais, 12 sprites, 12 SFX (11 usados),
  7 modelos Nature/Furniture, 3 músicas, 3 embarcações e 1 paleta. Dez modelos persistentes em EnvironmentModels.
  Importação remove scripts/PackageLinks; somente dados/imagens/áudios/malhas selecionados, sem instalar plugins/
  scripts de packs. Biblioteca completa e packs extras baixados não foram todos importados.
- **Cenário e portos:** materiais PBR configurados; água com ondas/cor/reflexo; flora, pedras, móveis e acabamentos
  com meshes reais. Três extensões portuárias de 168×80 studs, 49 blocos físicos de chão só onde não havia terra,
  construções novas detalhadas sem mover/substituir as da equipe. Detalhes locais têm teto e opção de desligar.
  Expansão integral das ilhas continua pendente; portos não equivalem a novas ilhas completas.
- **Strength:** três portos com capitão orangotango próprio/provisório; remo gratuito, lancha 60 moedas, cruzeiro
  350 moedas. Aluguel/posse/entrada/campanha/moedas/colisão autoritativos; W/S aceleram, A/D viram, R libera,
  T desembarca perto de porto liberado. Cruzeiro tem seis assentos de passageiro; viajar sentado. Um navio por dono,
  limpeza após 180 s vazio, reembarque perto do mesmo porto sem nova cobrança. Módulo e preços ajustáveis.
- **Verificação local:** **107 testes passaram**, análise estática sem TypeError, diff e manifest aditivo conferidos.
  Testes novos cobrem políticas/inputs/puzzle/recompensa única/rota obrigatória sem revelar segredo. Avisos antigos
  Font=100 permanecem. **Seis verificações no Studio passaram:** retorno caminhando, regen de mob e chefe,
  bloqueio NPC contra NPC, 49 blocos de chão/sem dummies, aluguel inválido recusado e cruzeiro com cobrança
  única/controle real cliente → servidor/desembarque sem arrastar casco. 14 sons usados carregados.
  Instrumentação temporária de Studio usa perfil simulado para aluguel, sem gastar dinheiro
  nem dar itens/reputação ao dono. Play encerrado e os três scripts temporários removidos em Edit pelo MCP.

### O que ainda falta e ordem de continuação

1. **Mapa físico Cidade Âmbar / Costa Dourada / Fortaleza Maré:** serviços recusam mapas ausentes/incompletos;
   campanha hoje para na chegada à Cidade no place atual. Código até o final do Capítulo 1 não basta para jogar
   essas regiões. Integrar modelos/marcadores/chão pelo contrato dos documentos, sem substituir place por build.
2. Arte definitiva de capitão/armas/chefes, ícones dos kits, mecanismos próprios dos bosses e fases do Avatar/Toduro.
   Casas/props novos não substituem a necessidade de acabamento das construções da equipe.
3. Testar facções/honra/bounty/contratos com **dois clientes**, passageiros de outro jogador, reembarque, colisão,
   mobile/gamepad/FPS, campanha desde perfil novo e save/reconexão reais. Respawns de 10–30 minutos foram
   conferidos por política/testes locais, não por esperar cada ciclo inteiro no Studio.
4. Expandir ilhas completas e variedade de exploração/sidequests/dungeons após integração física. Cap.2 não iniciado.
5. Dono revisar no Play e publicar **pelo Studio** quando aprovar. Não foi publicado nesta sessão.

### Teste rápido do dono

- Play: HUD legível, menu/facção, Música em Configurações, mochila/objetivos e direção da missão inicial.
- Campos: inimigos sem skins dos Anciões, sem pads/treinos pretos; puxar longe e ver retorno caminhando;
  bater, parar 15 s e conferir cura gradual. Boss cura menos após 30 s. Não brigam entre si.
- Porto da Névoa: remo gratuito ou cruzeiro 350; W/S/A/D; retornar ao porto e T para desembarcar; R para liberar.
  Conferir flores/móveis/texturas/água e ligar/desligar Detalhes do cenário.
- Ferreiro/lentes/Câmara: materiais/receitas/dicas; recompensa de puzzle não repete ao reconectar.

## NPCs, facções, caçadas, objetivos e cenário — 30/09 (Codex; Studio fechado)

- **NPCs:** `BotService` parou de sortear os avatares da equipe/Anciões, inclusive quando recebe UserId legado.
  `NpcAppearance` cria variações R6 de pele/roupa, cinto e bolsa sem assets externos. Roupa não colide. Anciões de
  quest e arte da equipe não foram alterados. Bots e chefes por peças só escolhem jogadores; `NpcCombatRules` e
  `ResolveNpcHit` bloqueiam dano/empurrão entre NPCs no servidor. NPC aliado de combate continua para depois.
  Proteção de aggro agora consulta checkpoints atuais, incluindo registros posteriores de Cidade/Costa/Fortaleza.
- **Facções:** menu inicial persistente Fora da Lei/Governo; perfil pendente protegido de dano até escolher.
  Fora da Lei ganha bounty; Governo ganha honra contra Fora da Lei. Crédito/gap/cooldown/contexto existentes
  continuam. Novos campos `faction`/`honor` são aditivos ao perfil v5, sem wipe/novo DataStore. Bounty antiga é
  preservada. Perfil e toasts mostram reputação adequada; estatísticas ganharam rolagem/texto quebrado.
- **Contratos de caçador:** menu Caçadas; alvo Fora da Lei no servidor, bounty ≥50 mil, nível próximo, aviso sem
  GPS. Dez minutos, um contrato por caçador/até três por alvo; recusa morto/combate/arena/ID inválido/cooldown.
  Vitória validada pelo sinal interno de reputação paga 20 moedas + 80 XP base uma vez; cancelamento/saída/
  expiração não pagam. Contratos são de sessão; reputação/cooldown persistentes continuam protegendo reconexão.
- **Retenção concreta:** menu Objetivos mostra XP/nível, próxima habilidade real do Stand, forja com materiais e
  fontes/quantidades, próximo título e exploração opcional. Sem duplicar recompensas ou forçar campanha/diárias.
  Pesquisa e aplicação de loops do Blox Fruits descritas, com fontes/limites, em `RETENCAO_E_ASSETS.md`.
- **Cenário:** `EnvironmentService` existente preservado, inclusive dia/noite e API DEV. Auxiliar
  `EnvironmentMaterials` aplica materiais nativos nos cenários procedurais conhecidos, conservando física; água
  ganha cor/reflexo/transparência/ondas em runtime, sem editar volume de Terrain. PBR só liga após configurar IDs.
  Cliente acrescenta capim, peitoris/vasos, sacaria, travessas/aros; teto 420 peças, reserva para construções,
  todas sem colisão, opção Configurações → Detalhes do cenário. Moradores da vila: 7 → 12. Sem mudar arquivos de
  mapa/arte/place nem manifest Rojo. A aparência/colisão/FPS ainda exigem inspeção no Play.
- **Assets externos:** 12 packs CC0 oficiais na biblioteca local `asset_library/` (fora do Rojo/Git), hashes/origem/
  licenças no inventário versionado. 2.583 imagens, 230 áudios decodificados inteiros e 469 OBJ verificados;
  4.694 hashes conferidos, zero erro. Seleção de 56 arquivos para importação, incluindo seis PBR 1K. Areia clara
  Ground093A substitui material marrom descartado após revisão visual. Nenhum script/plugin/place externo instalado.
  Imagens/sons ainda precisam de IDs/acesso ao universo; modelos, importação no Studio. Arquivos baixados não
  foram declarados já presentes no jogo. Detalhes e procedimento em `RETENCAO_E_ASSETS.md`.
- **Testes antigos reparados:** preparação real de progressão, sinal de atributo no player simulado, nível suficiente
  nos testes de sequência e representação atual da espada (cabo/lâmina/solda). Requisitos do jogo não foram removidos.
  Suíte passou com 100 testes (86 anteriores + 14 de facções/contratos/NPCs/objetivos/nível); análise estática, diff e
  auditoria aditiva passaram. Avisos antigos Font=100 permanecem. Sem validação de Studio/DataStore real/publicação.
- **Próximo teste do dono:** facção/retorno com save confirmado; dois clientes para honra/bounty/caçada e cooldown;
  NPCs genéricos sem briga entre si/boss; Objetivos/Mochila/Perfil em tela baixa; cenário e toggle/FPS. Checklist
  detalhado em `RETENCAO_E_ASSETS.md`. Continuam pendentes mapas físicos Cidade/Costa/Fortaleza, encenação/cenas,
  kits finais de chefes/Toduro, mais sidequests/dungeons e importação/validação visual dos assets. Cap.2 não iniciado.

## Retomada e auditoria dos testes — 30/09 (Codex)

- Conferidas no código as correções recentes de primeiro spawn aguardando perfil, `ForceCharacter` sem respawn antes do primeiro corpo e proteção de aggro perto dos checkpoints/por 6 s após nascer. Manifest continua sem `$path` em Workspace/ServerStorage; auditoria aditiva passou.
- `tools/analisar.sh` passou (avisos antigos Font=100 continuam). Persistência (10), sidequests (7), Fortaleza (10) e bounty (10) passaram: 37 testes dessas quatro suítes.
- A suíte completa **não está verde após a leva recente**: gameplay/builds chamam a progressão real sem inicializar seu remote; story_expansion encontra player simulado sem `GetAttributeChangedSignal`; Cidade/Costa testam derrota de chefe com perfil nível 1, agora abaixo dos mínimos 24/28. Corrigir preparação dos testes e repetir todas as suítes antes de reutilizar o registro histórico de 86 testes aprovados. Não desativar requisitos do jogo para satisfazer testes antigos.
- Logs locais mais recentes encontrados são de Studio encerrado em 30/09 às 18:27 UTC; não demonstram o teste atual do dono. Verificação ao vivo depende de conexão disponível ao Studio ou Output da sessão atual. Sem alteração de gameplay, mapa, arte ou publicação nesta auditoria.
- Prioridade do teste do dono: spawn/câmera/HP parado; NPCs passivos e revide; drops/mochila/forja; eventos pelo DEV; cursor/shift lock e painéis. Depois: campanha e PvP com dois clientes. Pendências de conteúdo seguem contratos de caçador, kits finais dos chefes e integração física Cidade/Costa/Fortaleza.

## Trailer v3 — 2026-10-01 (Claude; FALTA o dono rodar no Play e gravar) — ler `TRAILER_V3.md`
- Trailer refeito do zero: 16:9 (~115 s) e 9:16 (~60 s), textos em inglês, sem música, contagem 3-2-1, ambiente
  controlado (mobs/jogadores/HUD/nomes/mouse somem), grade de cor por plano, câmera em trilho/órbita/acompanhando,
  quadro de impacto, Parada do Tempo com congelamento da imagem, portal com visitante que acena, Flecha + roleta até
  ANOMALOUS, JoJo poses (`Trailer/Pose_*` no ProcAnimDefs), "ゴゴゴ", To Be Continued, logo. Folha de tempos no log.
- DEV → Teste: TRAILER 16:9 / TRAILER 9:16 / cenas avulsas (+ "Cenas em 9:16"). Comandos `Trailer`, `TrailerV`,
  `TrailerScene {scene, v}`. Sets ajustáveis por `Workspace.TrailerMarks.<Nome>`.
- Corrigido: o trailer antigo apontava para a praça da arena desmontada e o `cleanup` chamava `BotService.Clear()`
  (apagava os inimigos do mapa junto); agora só remove o próprio elenco e devolve o comportamento dos outros bots.
- Análise estática limpa; NADA testado no Studio (estava fechado). Primeiro Play: ver "Pontos de atenção" no doc.
- **1º teste do dono (01/10) → corrigido** (ver TRAILER_V3 "Correções"): loop do zumbido da Flecha, som de Dash nos
  cortes, abertura da praia sem ragdoll, enquadramento automático (`frame`) nos dois formatos, `KnockbackScale` 0.35
  no elenco. Falta o dono rodar de novo.

## Correções 30/09 noite (Claude) — primeiro teste do dono no jogo publicado
Dono: "quando entro no jogo eu spawno invisível, tomando uns danos aleatórios". Reproduzido no Play (MCP):
- **Nascia 2 vezes**: `CharacterService` montava o personagem antes do perfil carregar (no Porto, perto da Taberna) e o
  `StandService.applyPower` → `AbilityService.ForceCharacter` recriava ~1 s depois no checkpoint salvo. No servidor real a
  câmera do cliente ficava no primeiro corpo (destruído) = invisível. **Fix**: 1º spawn espera `DataService.GetProfile`
  (até 15 s); `ForceCharacter` sem personagem só troca o kit (o 1º spawn já nasce com ele). Testado: 1 spawn só.
- **Dano**: checkpoint "oasis" (ilha 3, 1710,-130) tem Caçadores de Recompensa tier 4 AGRESSIVOS a 6 studs. **Fix**:
  `BotService.protectedFromAggro` — inimigo não escolhe como alvo jogador a < 45 studs (XZ) de checkpoint/Pescador
  (`WorldConfig.Regions`) nem nos 6 s após nascer; revide contra quem bate continua. Testado: 20 s, 100 HP.
- **Rojo duplicou o place**: com `"$path"` em Workspace/ServerStorage (+ filhos explícitos) no `default.project.json`, o
  plugin (7.3.1; CLI 7.7.0) criou uma 2ª cópia de 18 modelos do Workspace (Taberna, Moveis taverna, LojinhaDecor, Lojinha,
  cav, CasasKame, House Trink, LocalInicial, humanoider_20, Arvore1-3, Pedra1-3, Barriers, Banheiro,
  SpawnLocation_IlhotaKame) e 5 do ServerStorage (EventMaps, BossModel, Mods, Backup_Mapa_2026-09-28,
  Backup_AltarGruta_antigo) — cópias idênticas (conferido). Publicado assim. **Fix**: `$path` removido desses 2 serviços
  (src/place/workspace|serverstorage = só backup via captura). Lighting/TextChat com `$path` sozinho NÃO duplicaram.
  2ª cópia APAGADA no Studio pelo MCP (30/09, com OK do dono); falta publicar.
- **Cursor**: sem contorno; triângulo de cantos arredondados (raio 3) e V com traços em pílula (UICorner). **UI**: todos os
  UICorner 0 → 6 px (283 em `src/ui`, controllers, geradores `tools/gerar_*.py`, TopbarPlus fixado em 6); painel do
  Mercador/Ferreiro ganhou cantos.
- Falta o dono: testar o cursor/cantos no cliente; publicar pelo Studio depois de apagar as duplicatas.

## "Prender o jogador" — leva de 30/09 (Claude; FALTA o dono testar no Play)
Pedido do dono: eventos por tempo de servidor e ilhas secretas, vila maior, NPCs iniciais fracos/passivos, grind.
- **Inimigos por nível** (`EnemyConfig`, tiers 1–5): tier 1–2 = HUMANOS passivos (só lutam se apanharem), sem ult/
  habilidade/revide; tier 3 reativo (território) com bloqueio e habilidades; tier 4+ agressivo, Stand e ult.
  `BotService`: comportamento `reactive` + travas por bot (CanAwaken/CanCounter/UsePassive/TerritoryRadius).
  Todas as ilhas convertidas (Ilha 1 = tiers 1–3, Deserto 3–4, Rota 4–5, ilhas 4–6 = 5).
- **Missões com nível mínimo e recompensa** (`StoryConfig`: `MinLevel`/`XP`/`Coins`/`Key`): Máscara nv 5, Herdeiro
  nv 8, Deserto 9–14, Rota 15–20... Abaixo do nível o objetivo não conta e a dica manda treinar; ao subir, aviso
  "Você está pronto". O Ancião só aparece em diálogo nos atos `Key`; o resto chega como aviso discreto.
- **Materiais e drops** (`MaterialConfig`, item `mat:<id>`, aba Materiais na mochila; `ProgressionConfig.Npcs[].Drops`).
- **Armas** (`BuildConfig.Weapons`: espada de treino, Lâmina da Névoa, **Katana da Fratura**); arma extra = item
  `arma:<id>` (Usar = equipar; a anterior volta para a mochila). Forja no **Ferreiro** da vila.
- **Eventos do mundo** (`WorldEventsService`/`WorldEventsConfig`, relógio = tempo de servidor de pé):
  Mercador Errante (6 h, depois a cada 3 h; Aço Estelar 25%); Esferas Estreladas (2 h, 7 pelas ilhas) → **Ilhota do
  Mestre (Kame) como ilha fantasma** 30 min (começa ESCONDIDA); Obeliscos do Sol (4 h, só à noite, os 4 juntos) →
  **Cânion Fantasma** 30 min com portal no Deserto, Espectros tier 4 e baú; **Mural de Rumores** na praça com dicas e
  contagens. Anúncios na tela. DEV → Mapa → EVENTOS DO MUNDO (pular +1 h, forçar cada um).
- **Ilha 1 maior** (`tools/gerar_expansao_ilha1.py` → `FXVilaNova` e `FXCamposNevoa`): Vila Nova (praça do mercado,
  10 casas, postes, bancos; 7 moradores andando — `VillagerService`, não são lutadores) e Campos da Névoa (ilhota de
  farm com ponte em z -60; Clareira/Bosque/Acampamento bem separados + Capataz miniboss). Inimigos por marcador
  `MobPad` com atributos (`MobPadService`). Vagantes do treino espalhados.
- **Cursor próprio** (`CursorController`): triângulo branco (mouse solto) / seta V vazada (shift lock).
- Verificado por Claude (30/09): servidor no Play sem erro do jogo (62 services); inimigos com tier/HP certos; mural,
  ferreiro, 4 obeliscos, mercador, Cânion (6 espectros), 7 esferas, Kame aparece/some; screenshots da Vila Nova e dos
  Campos OK. Corrigida corrida Kame/Cânion reabrindo enquanto sumiam. Cliente (cursor, painel da forja/mercador,
  toasts) NÃO verificado — só o dono no Play.
- **Tudo do place no Rojo** (`src/place/*`, ver SINCRONIZACAO_MANUAL.md); captura mantém arquivos ausentes no place.

### TESTE DO DONO (30/09)
1. Vagantes (treino e Campos) não atacam sozinhos; bater → revidam sem ult. Capataz reage perto do acampamento.
2. Missão da Máscara antes do nível 5 → aviso "Nível 5 necessário…"; subir → "Você está pronto".
3. Ponte até os Campos; inimigos soltam material (toast e aba Materiais da mochila).
4. DEV → Mapa → EVENTOS DO MUNDO: Mercador agora (comprar), Espalhar esferas (pegar), Ilha Kame, Cânion (portal no
   Deserto, baú, voltar), Pular +1 h. Mural na praça da Vila Nova.
5. Ferreiro (Vila, x 100 z 160): painel de forja; Lâmina da Névoa com 15 Névoa + 2 Couro + 120 moedas (nível 5).
6. Cursor: triângulo (mouse solto) / seta V (shift lock).
7. Visual: Vila Nova, Campos, montanha/rocha novas; moradores andando; nada invadindo a Taberna/caverna.
- DEPOIS do feedback: chefes com mecânica própria, mais sidequests por ilha, contratos de caçador (lista do Codex).

## Mapa: captura + relevo + praias + sobreposições — 2026-09-30 (Claude, feito NO STUDIO via MCP; falta capturar)
- Fluxo novo de edição manual: `SINCRONIZACAO_MANUAL.md` + `tools/capturar_mapa.sh` (`rojo syncback` só do mapa).
  1ª captura feita (commit "Mapa: captura da construção do dono"): RochaTaberna, Molhada52, `Arena_Antiga` agora no Rojo.
- **Vão embaixo das praias** (`tools/fechar_vao_praias.luau`): chão das ilhas descia só até -8 e as rampas até -6.5, com a
  areia do mar em -12 → dava para nadar por baixo da ilha. 545 peças desceram até -13 e 436 rampas ganharam um "Pe*".
  Conferido: 0 vãos em 2880 pontos das 4 ilhas.
- **Relevo** (`tools/montar_relevo.luau` → `Workspace.Sahur.Relevo`): MontanhaSantuario (Sandstone) e RochaTaberna
  (Slate, igual à `cav`) revestidas por fora — talude do chão até 25–30% da altura (areia/grama por cima), lascas em
  estratos, ombro arredondado, topo com pedras/picos/grama. Núcleo original só mudou de cor. Porta da Taberna e
  cachoeira/santuário em zonas livres; lasca que encostaria em qualquer coisa é pulada. Rodar de novo refaz do zero.
  Atenção: os taludes (~50°) são andáveis — dá para subir um pouco nas duas.
- **Sobreposições** (`tools/corrigir_sobreposicao.luau`): 1386 faces coplanares recuadas 0.04 (peça menor), a maioria
  tijolos destrutíveis/pilares/props. Restam 24 pares só em `Arvore1-3`/`Pedra2-3` (possível arte, não mexi).
- PRÓXIMO: dono salva `backups/place-relevo-30-09.rbxl` → `tools/capturar_mapa.sh ... aplicar` → commit do mapa →
  dono reconecta o Rojo (proposta do plugin deve vir sem remoções).

## PONTO DE RETOMADA — bounty persistente / mapa adiado — 2026-09-30

**Na `main`, sem Studio e sem publicação. O dono adiou sua construção manual para o final e autorizou continuar o código. A próxima leva recomendada é contratos de caçador; a campanha do Capítulo 1 permanece preparada até Fortaleza, sem iniciar Capítulo 2 automaticamente.** Quando o dono avisar que modificou o mapa, capturar e conciliar o snapshot antes de reconectar Rojo, conforme `SINCRONIZACAO_MANUAL.md`.

### Implementado nesta leva

- `BountyConfig`/`BountyService`: vitórias válidas em PvP de mundo aberto dão **5.000 bounty**, sem multiplicador de passe. Exigem crédito de morte autoritativo, perfis carregados e diferença absoluta de até 10 níveis. Títulos: Procurado (50 mil), Perigoso (250 mil), Ameaça Regional (1 milhão), Calamidade (5 milhões), Anomalia (10 milhões). Valores iniciais ajustáveis, não balanceamento final.
- Contexto de mundo aberto é capturado **antes de `FighterDied`** limpar dados da arena. Duelo, guerra, partida e torneio não geram bounty; zonas seguras também são excluídas. O evento anterior de crédito continua com seus três primeiros argumentos; quarto argumento interno identifica o contexto.
- Mesmos alvos não rendem de novo durante 300 segundos. Histórico por UserId é salvo junto da bounty, protegendo reconexões/troca de servidor quando o save foi confirmado. Lista limitada a 256 alvos ativos; cheia recusa novos pagamentos, sem expulsar cooldown vigente. Não protege contra coalizões com muitas contas distintas. Falha de save/sessão privada mantém as limitações normais de persistência.
- Perfil v5 ganha campo aditivo `bounty`, migrado/validado sem trocar DataStore/schema ou apagar progresso. Sem perda de bounty na morte: essa regra não está definida nos documentos. Derrotar alvo com bounty dá bônus de 1 moeda por 50 mil de bounty, teto de 20 base, além da recompensa PvP existente; multiplicadores normais de moeda continuam. Sem contratos pagos nesta fase.
- Perfil mostra bounty/título na lista de estatísticas; HUD avisa ganho/bônus pelo canal existente. Atributos `Bounty`/`BountyTitle` expõem estado público, mas recompensa lê o perfil servidor, nunca esses atributos. Ranking global, nameplates e efeitos próprios ainda pendentes.
- **Verificação:** 86 testes locais (76 anteriores + 10 bounty), análise estática, diff e auditoria aditiva do Rojo passaram. Avisos Font=100 antigos permanecem. Física/UI/replicação e DataStore real não verificados sem Studio. Não publicou, abriu Studio, alterou mapa/arte/manifest nem fez commit.

### Próximas levas, nesta ordem

1. Contratos de caçador: auditar serviços/UI existentes; alvo avisado, sem GPS; regras de aceitação, validade, crédito e recompensa servidor, respeitando PvP/cooldown.
2. Kits definitivos dos chefes e fases reais do Avatar; concluir mecânica de Toduro. Usar assets existentes por referência, sem modificar arte da equipe.
3. Ampliar farm/sidequests e consequências pessoais dos Ecos; classes sociais Hunter/Outlaw/Defender, eventos/invasões e apresentação das referências ainda pendentes.
4. Construção manual do dono e conciliação dos arquivos com snapshot completo, antes de reconectar Rojo. Integração física de Cidade/Costa/Fortaleza e expansão do Eclipse, cenas/rotinas/NPCs ainda necessárias.
5. Validação no Studio: toda campanha, sistemas econômicos, PvP/contratos, UI e dois clientes; depois publicação pelo dono no Studio. Capítulo 2 depende de mundo/place e conteúdo canônico próprios.

### Testar bounty depois, sem exigir Studio agora

- Dois jogadores fora de zonas seguras, proteção de respawn expirada, níveis próximos: vitória dá 5.000 bounty, perfil/toast e título nos limiares. Repetir antes de 5 minutos não paga; reconectar após save confirmado mantém bloqueio.
- Gap acima de 10 níveis em ambos os sentidos, suicídio, NPC, zonas seguras e arenas/torneio não dão bounty. Bônus só contra alvo realmente procurado; título/coins/bounty persistem juntos e não reduzem bounty do derrotado.
- Servidor privado/falha de load mantém aviso e progresso só de sessão. Conferir rolagem da estatística nova no perfil desktop/mobile/gamepad.

## PONTO DE PARADA — Fortaleza Maré / entrega para construção manual — 2026-09-30

**Registro histórico, supersedido pelo ponto de retomada acima: após esta leva o dono decidiu adiar a construção manual e continuar o código. A campanha permanece até o encerramento do Capítulo 1; não avançar automaticamente para Capítulo 2.** A captura/salvamento/sincronização reversível futura já está autorizada nesta conversa. Nenhuma captura do novo mapa foi feita nesta sessão, pois ele ainda será construído.

### Implementado nesta leva (ainda não publicado)

- **Fortaleza / M26–29:** chegada real, prisão, Eco civil/alto risco, abrir ala escolhida primeiro e outra depois com flag de atraso, duas anomalias distintas de repetição e último Rastro com registro parcial fiel à bíblia. Resultado principal comum; atrasos/informação são flags/falas pessoais, sem inventar sobreviventes específicos ou destruir/abrir arte global.
- **M30:** dois fragmentos investigados, duas versões alteradas de chefes com contribuição/identidade distinta (farm do mesmo pad não conta como dois), pedido de ajuda/comunicação com Approx/Lry/Fred/Ravy, avaliação de Toduro e recepção de Adryan com resposta do jogador. Cenas iniciais por diálogos, não cutscenes completas.
- **M31:** examinar ruptura, Avatar provisório e três âncoras distintas. Âncoras exigem participação recente real e Avatar vivo; matar antes de ativar três não conclui derrota para campanha. Pode completar após respawn de Eco, preservando âncoras já feitas. Loot continua por contribuição independentemente do objetivo de campanha.
- **Escolha e execução finais:** Humanoider exige dois mecanismos; Toduro, três pontos internos; alternativo exige preparar dispositivo após Rastros das Ilhas 1/3/6, ativá-lo e registra assinatura do protagonista na F/X. Todos precisam confirmar estabilização, liberam a mesma passagem e seguem para despedida/oferta de Adryan e terminal “C-8 // RASTRO RECUPERADO / 1 DE ?”. Terminal marca `cap1_completed` e `cap2_unlocked`; sem revelar traidor/causa/origem verdadeira e sem teleportar para place inexistente.
- **Migração rev7:** mantém os 39 atos rev6 e seus contadores/itens/flags; anexa Fortaleza após a antiga espera. Saves rev6 além do limite retornam à chegada 39, sem wipe de inventário/flags. DataStore/schema permanecem. Perfil ao fim fica em `cap2_aguarda` do Capítulo 1, aguardando próximo mundo real.
- **Mapa seguro:** `FortalezaMareService` reutiliza registrador aditivo validado; exige mapa `FXFortalezaMare`, limites separados, todos os marcadores e chão dos pontos de combate/checkpoint. Região indisponível até validar; três bots provisórios só depois. Portal ida/volta validado; mapa removido desfaz registro/bots. Contrato em `FORTALEZA_MARE_INTEGRACAO.md`.
- **Rojo / entrega:** manifest auditado aditivo; nenhuma alteração de `default.project.json`, mapa/arte/Terrain/`.rbxl`. README antigo que mandava abrir build incompleto substituído pelo fluxo com place existente. `tools/auditar_rojo.py` lista caminhos, mapas/propriedades controladas e confirma manifest; não exporta Studio. Tutorial e ordem de captura/reconciliação em `SINCRONIZACAO_MANUAL.md`.
- **Verificação:** 76 testes locais passaram (66 anteriores + 10 Fortaleza), análise estática e `git diff --check` passaram; auditoria Rojo OK. Avisos antigos Font=100 continuam. Sem abrir Studio, publicar, fazer commit/reset ou exigir teste do dono nesta sessão.

### Falta — ordem de retomada

1. **Mapa do dono:** backup completo atual antes de construir; Rojo desconectado durante alterações conhecidas; cópia completa após construir. Ao avisar, ler snapshot/estado de edição, comparar/exportar alterações para arquivos, preservar Terrain/iluminação/arte e referências, conferir diff antes de reconectar. Não presumir que Rojo trouxe mudanças manuais para a pasta.
2. **Validação jogável:** boot/Output, colisão/R6/chegadas, portais/checkpoints, toda campanha, builds/itens/trocas/recibos, PvP e UI desktop/mobile/gamepad; dois clientes para escolhas e contribuição. Sem essa etapa a base ainda não é certificada jogável.
3. **Completar mapas/cenas:** Cidade/Costa/Fortaleza físicas, expansão do Eclipse, NPCs/rotinas/horários, tarefas encenadas, pistas, portas/alas pessoais, consequências visuais dos Ecos, loops temporais, fragmentos/colapso nas seis ilhas e presença/cutscenes dos Anciões.
4. **Kits finais:** Homem Sem Sombra, Regente com artefatos de múltiplos mundos, versões alteradas e Avatar com quatro fases/alternância de regiões. Combate atual reutiliza kits provisórios. Método de Toduro ainda não simula dificuldade/quase morte; é sequência inicial de interações.
5. **Camadas do RPG e referências:** catálogo maior de sidequests/dungeons/escoltas/tesouros, bounty/contratos/classes sociais/eventos/invasões; acabamento de HUD/mobile/mapas; eventual desenho da loja permanente compatível com regras aprovadas e IDs reais do dono. Não foram concluídos nesta leva.
6. **Capítulo 2:** somente após conciliar o mapa/validar o Capítulo 1; planejar place separado, transição/persistência e campanha canônica de Adryan. Não há destino real nem troca automática de capítulo/place atualmente.

### Testes específicos da Fortaleza para quando o mapa existir

- Escolher cada ala; abrir selecionada, depois outra; reconectar sem repetir progresso. Conferir flags/falas pessoais e que não abre a ala de outro jogador globalmente.
- Loops/Rastro distintos, colapso com dois pads; repetir um chefe não substitui o segundo. Toduro deve vir antes de Adryan, e nenhuma fala pode revelar causa/traidor.
- Âncoras: espectador, longe, morto e Avatar morto não contam; contribuição recente + três marcadores distintos + derrota concluem. Matar cedo deve permitir recuperação no Eco seguinte.
- Três métodos finais e reconexão no meio. Alternativo bloqueado sem Rastros/dispositivo; métodos não aceitam ações uns dos outros. Terminal conclui uma vez; nenhuma tentativa de teleporte para Capítulo 2.

## Referências visuais + Costa Dourada — 2026-09-30 (Codex, main; ainda não publicado)

- **Referências auditadas:** TXT e nove imagens lidos. Inspiração adaptada ao tema F/X, sem copiar assets/mapas/símbolos. Dez nomes de arquivo normalizados para ASCII/`_`, bytes preservados; índice com nomes originais e SHA-256. Aplicação por exemplo, limites e pendências em `REFERENCIAS_VISUAIS.md`.
- **UI:** 278 UICorners dos modelos `src/ui` agora têm raio zero; construtores de menus e geradores correspondentes mantêm essa regra. TopbarPlus configurado nos containers do jogo, sem editar pacote/CoreGui. Menu lateral recolhível com lista rolável; mochila Tudo/Flechas/Discos/Raças/Build + busca literal, layout compacto para baixa altura. Uso de itens mantém os Requests/validação existentes. Diálogo responsivo com texto rolável, foto quadrada, identidade do NPC sem “DEV” e duração por extensão da fala. Objetivos de campanha/sidequests roláveis, com altura limitada pela tela.
- **Costa Dourada:** chegada, Missões 21–25, Regente e Eco preparados. Lotes distintos → organização → escolha e execução da infiltração → registros → C-8/fala do Humanoider → chefe → Eco. Força exige três guardas PvE + entrada principal; furtividade exige duas passagens em ordem + entrada furtiva; social exige conversar, buscar entrega e retornar ao contato antes de escolher + entrada autorizada. Flags persistem e moradores/contato reconhecem o caminho por fala. Nenhum caminho exige outro caminho ou kill PvP.
- **Eco e cânone:** destruir mercado / facção menos agressiva / monitorar gravam estado pessoal e resposta do guia, liberando a mesma rota. Nome correto da próxima ilha conferido/corrigido para **Fortaleza Maré**. C-8 identifica material de Carlos sem explicar causa/origem. Horários são descobertos por registros; rupturas físicas programadas não foram implementadas.
- **Migração:** rev6 anexa atos após os 30 da rev5, mantém índices/contadores/itens/flags. `rumo_costa_dourada` agora espera chegada real; perfil antigo além do limite rev5 volta apenas à chegada. As migrações anteriores continuam e os saves existentes não são apagados; sem novo DataStore/schema.
- **Mapa/combate:** catálogo da Costa indisponível/sem coordenadas até validar mapa real. Validação existente da Cidade foi extraída para `CampaignMapRegistration`, reutilizada e retestada. Exige limites separados, marcadores e chão em chegada/chefe/guardas/checkpoint; desfaz região e bots ao remover mapa. Portal recusa destino ausente. Kits provisórios Swift (guardas) e Kira (Regente), sem fingir que artefatos de múltiplos mundos estão prontos. Contrato em `COSTA_DOURADA_INTEGRACAO.md`; nenhuma arte da equipe/mapa/`.rbxl`/manifest editado.
- **Verificação:** 66 testes locais (56 anteriores + 10 Costa), análise estática e `git diff --check` passaram. JSONs de UI e SHA-256 das referências conferidos. Avisos antigos Font=100 continuam; aparência/física/replicação não verificadas sem Studio. Nenhuma publicação.

### Testar depois, sem exigir Studio agora

1. Desktop/mobile em paisagem/retrato: painéis retos, menu recolhe/rola, abas e busca da mochila, cabeçalho compacto, usar/guardar Flecha sem perder eventos. Conferir controles/gamepad e legibilidade.
2. Diálogo longo (Carlos/C-8), rolagem, fechar por toque/tecla e duração; HUD de objetivos com várias tarefas/sidequests sem cortar texto.
3. Integrar Costa pelo contrato: ida/volta, checkpoint, chão R6 e segurança da chegada; ilha incompleta deve permanecer indisponível. Revalidar Âmbar após extração do registrador comum.
4. Três soluções de infiltração com saves/jogadores distintos; acesso errado, morto ou distante não conta. Reconectar entre favor/entrega, entre passagens e antes de atravessar o acesso.
5. Comparar registros, obter C-8, falar com Humanoider; chefe com contribuidores/espectador, loot/respawn/Eco; cada decisão mantém rota principal e comentário próprio.

### Próxima continuidade

- Fortaleza Maré / missões 26–31 e encerramento do Capítulo 1, após conferir objetivos/áreas existentes.
- Mapas físicos da Cidade/Costa, kits próprios dos chefes, rotinas/horários, comerciantes, consequências visuais dos Ecos e conteúdo completo das tarefas permanecem pendentes.
- Referências de porto/água/construção orientam modelagem futura. Seleção de classes sociais e loja de Flechas específicas/permanentes não foram adicionadas por uma imagem de inspiração: precisam de regras compatíveis com a direção aprovada e, para compras reais, IDs do dono.

## Leva de Cidade Âmbar — 2026-09-30 (Codex, main; ainda não publicado)

- **Campanha preparada:** chegada à Cidade Âmbar, Missões 16–20, O Homem Sem Sombra, Eco da cidade e espera pela Costa Dourada. Segue a bíblia: conhecer moradores/tarefa simples → desaparecimentos → fotografia/confronto → investigação/suspeito → ruptura controlada na casa → chefe → autoridades/Humanoider/interrogatório pessoal. Os três caminhos registram a informação principal sobre “um homem que conhecia as linhas”, sem revelar nome/causa/traidor, e liberam a flag da próxima rota.
- **Revelação:** foto não identifica o rosto e não nomeia Carlos. Somente levar a foto ao Humanoider durante a Missão 18 grava `carlos_nome_revelado` e apresenta “Carlos. Ele era um de nós. ... Éramos oito. Agora somos sete.”; não informa a causa. O diálogo do ato seguinte não atropela essa fala.
- **Investigação recuperável:** moradores/cenas distintos contam uma vez por ato. Padrão exige cenas + depoimento. Acusação sem vínculo adiciona uma contrapista obrigatória, sem avançar/travar/perder o save; após reinvestigar, pode escolher novamente, inclusive após outra acusação errada. Flags, contadores e pistas vistas persistem no perfil existente. Interações validam vida, distância, região, ato e rota no servidor.
- **Migração rev5:** os 22 atos rev4 mantêm índices/identidade/contadores/flags/inventário; `rumo_cidade_ambar` passa a esperar chegada real. Atos novos são anexados. Save antigo além do último ato rev4 volta apenas à chegada, com contadores inválidos daquele limite limpos; itens, escolhas, Rastros e rotas permanecem. Sem novo DataStore/schema/wipe.
- **Integração aditiva:** `CidadeAmbarConfig`/`CidadeAmbarService` aguardam mapa real `FXCidadeAmbar`, limites explícitos, marcadores ancorados e chão na chegada/boss. Região começa indisponível e sem checkpoint. Só após validar registra limites/checkpoint/zona segura e prompts, sem mover/clonar arte. Portal de ida aguarda região disponível; todos os portais agora também validam distância/vida. Remover o mapa desfaz o registro e impede respawn em mapa ausente. Checkpoint salvo de região conhecida indisponível usa chegada padrão só na sessão, sem apagar a escolha; registro/remoção do mapa atualiza atributos para o próximo respawn. Contrato completo em `CIDADE_AMBAR_INTEGRACAO.md`.
- **Chefe/loot:** no mapa válido, chefe usa Swift provisoriamente; bot autoritativo e respawn como Eco existentes, crédito por contribuição, XP 140 base, 9 moedas base e Flecha 5% por tentativa. Kit próprio de ocultação/memória/duplicação espacial continua pendente; valores iniciais para balanceamento.
- **Verificação:** 56 testes locais passaram (46 anteriores + 10 Cidade Âmbar), análise estática e `git diff --check` passaram. Teste de mapa usa raycast/instâncias simulados; física, interface e replicação não foram verificadas. Avisos Font=100 antigos permanecem. Sem abrir Studio, publicação ou edição de assets/`.rbxl`/manifest Rojo.

### Validação jogável para depois

1. Integrar mapa pelo contrato, conferir chão/espaço R6/limites/retorno/chegada segura e checkpoint. Sem mapa completo, ida deve permanecer indisponível; regiões anteriores continuam funcionando.
2. Missões 16–18: repetir o mesmo morador/local não conta duas vezes; conversar com Humanoider antes da foto não revela nome. Foto + confronto revelam nome uma vez, sem causa; reconectar entre as duas interações.
3. Missão 19: cenas + testemunha liberam padrão; escolher errado exige contrapista; reconectar, reinvestigar e escolher novamente sem travar. Jogadores diferentes mantêm contadores próprios.
4. Casa → chefe com dois contribuidores → Eco; três decisões liberam informação/flag da Costa. Conferir loot e respawn de Eco; remover mapa em sessão de desenvolvimento deve desativar chegada e bots.
5. Conferir HUD, diálogos e prompts mobile; ajustar posicionamento da fotografia, pistas, moradores e do chefe no mapa real.

### Próximas levas

- Costa Dourada / missões 21–25, depois Fortaleza Maré / missões 26–31 e final do Capítulo 1: auditar cânone/código antes de expandir.
- Completar física/arte e conteúdo urbano da Cidade Âmbar, rotinas/horários, encenação das tarefas e kit específico do chefe; expansão física do Eclipse, sidequests e consequências visuais completas dos Ecos continuam pendentes.

## Leva de consequências dos Ecos e investigações — 2026-09-30 (Codex, main; ainda não publicado)

O dono autorizou continuar sem Studio e deixar sua validação jogável para depois. Essa validação não bloqueia o trabalho local; os limites abaixo permanecem registrados.

- **Investigações opcionais:** `SidequestConfig`/`SidequestService` concretizam investigação e retorno aos Anciões previstos em `ESTRUTURA_JOGO.md`, usando resultados já definidos na bíblia, sem nova subtrama/revelação. “Revisar os arquivos preservados” fica disponível somente para quem recuperou arquivos no Eco da capela (inclusive passagem); investigar em `RachaduraCapela` e entregar ao Humanoider rende 25 XP base + 3 moedas. “Examinar a anomalia remanescente” exige transferência no Eco do Deserto; investigar em `CamaraMarker` e entregar no Porto rende 35 XP base + 4 moedas. Números iniciais para balanceamento posterior, com multiplicadores normais de XP/moeda do jogo.
- **Progresso:** flags `side_<id>_inspected` / `side_<id>_done` no save existente da campanha; nenhum novo DataStore, schema ou índice de ato. Investigação e entrega conferem escolha, região, distância e vida no servidor. Recompensa é única e permanece junto de `done` no mesmo perfil; reconectar não permite repetir. Campanha/farm/PvP continuam independentes dessas atividades.
- **Diálogos e HUD:** Humanoider comenta sobreviventes e resultado da capela conforme as flags reais. HUD da campanha lista somente investigações liberadas e ainda não concluídas, indicando entrega após investigar. Diálogos/toasts usam o canal já existente; quests legadas do traidor continuam desativadas.
- **Apresentação pessoal:** `EcoController` oculta localmente o rig provisório do sobrevivente ferido quando ele foi deixado na fenda, inclusive na reconexão. Apenas rigs gerados pelo código e marcados `FXStorySurvivor` são afetados. Prompts opcionais aparecem somente quando a atividade está liberada; entrega aparece quando há investigação pronta. Servidor continua validando independentemente da visibilidade cliente. Atualização visual acontece quando flags relevantes mudam ou instâncias chegam, sem varrer o mapa a cada atualização de XP.
- **Verificação:** 46 testes locais passaram (10 persistência, 13 gameplay, 8 builds, 8 expansão, 7 sidequests); análise estática e `git diff --check` passaram. Avisos antigos de Font=100 em assets binários permanecem. Sem publicação e sem alteração de mapa/arte/animações/`.rbxl`/manifest Rojo.

### Validação jogável para depois (sem exigir teste agora)

1. Eco da fenda: dois clientes com decisões diferentes; só quem deixou o ferido deixa de vê-lo. Reconectar e conferir nome/rig ocultos apenas nessa perspectiva.
2. Capela: prisioneiros não libera arquivos; arquivos/passagem liberam. Investigar na rachadura, voltar ao Humanoider e entregar uma vez; reconectar e repetir sem ganhar novamente.
3. Deserto: selar/destruir não libera anomalia; transferir libera. Investigar na Câmara e entregar no Porto; vida/distância/região erradas não avançam. Conferir duas investigações prontas juntas.
4. HUD e prompts no mobile: textos opcionais e diálogos legíveis, atividades concluídas somem, campanha mantém seu ato. Em servidores privados, progresso permanece só na sessão, conforme DataService existente.

### Próxima continuidade

- Expandir Cidade Âmbar / missões 16–20 com os objetivos da bíblia e migração de campanha, após auditar os marcadores/áreas existentes. Permanecem a expansão física do Eclipse e as ilhas 5–6.
- Esta leva cobre duas investigações iniciais e uma consequência visual pessoal; não fecha o catálogo de sidequests, NPCs posteriores, relocação dos resgatados, visual das ruínas/energia do Deserto ou as atividades completas de cada ilha.

## Leva de campanha: Deserto e Viajante — 2026-09-30 (Codex, main; ainda não publicado)

- **Eco do Deserto:** vencer o Sacerdote passa para “A entidade desperta”; escolhas selar / destruir a Câmara / transferir energia seguem a bíblia. Para perfis novos, a rota do Eclipse libera após resolver o Eco. Flags e falas registram preservação, perda de ruínas ou anomalia menor; o resultado principal continua ameaça resolvida. Não foi aplicada destruição global do mapa compartilhado.
- **Puzzle opcional:** três mecanismos provisórios criados em runtime junto de `CamaraMarker`; a leitura da Câmara indica a sequência II → I → III. Sequência correta grava `camara_transferencia_preparada`, habilitando transferir. Erro reinicia apenas a tentativa; progresso é pessoal, persistido em flags e recuperável na reconexão. Distância, região e vida são validadas no servidor.
- **Missão 13:** O Viajante é criado como NPC R6 provisório perto de `SolPartidoSpawn`; falar com ele demonstra o transporte de seres vivos entre realidades, sem revelar Carlos nem detalhes não definidos do mundo de origem. A missão antecede o Rastro da Missão 14; conversa não avança de longe, morto ou antes do ato correto. Saves antigos que passaram por esse ponto podem conversar e registrar a visita sem retroceder.
- **Migração:** campanha rev4; ato antigo >=16 ganha +1 pelo Eco e >=18 ganha mais +1 pelo Viajante. Os 20 atos da rev3 preservam identidade e contadores; inventário, Rastros, flags, rotas e maestrias permanecem. Rev2 continua pela migração já existente antes desta. Rotas já abertas não são removidas; Eco faltante pode ser escolhido examinando a Câmara, sem alterar o ato atual. DataStore/schema continuam v5, sem wipe.
- **Verificação:** 39 testes locais passaram (10 persistência, 13 gameplay, 8 builds, 8 expansão); análise estática e `git diff --check` passaram. Permanecem os avisos antigos de migração Font=100 nos assets binários. Nenhuma publicação, edição de assets da equipe, mapa versionado, `.rbxl` ou manifest Rojo.

### Testar esta leva no Studio quando disponível

1. Novo progresso no Deserto: vencer Sacerdote com dois participantes; conferir Eco, opções selar/destruir e rota bloqueada antes/aberta depois. Reconectar com escolha pendente.
2. Câmara: examinar para ler II → I → III, errar e reiniciar, acertar; conferir transferir habilitado apenas para quem resolveu. Reconectar no meio/fim do puzzle e conferir que outro cliente não recebe suas flags.
3. Eclipse: completar Caçados, conversar com Viajante perto da chegada, seguir para Rastro e Observador. Tentar interação fora de alcance/morto. Conferir posicionamento do rig, prompts, textos e mobile.
4. Save rev3 nas Missões 10, 11, 12, 14 e 15: manter a mesma missão e contadores após carga; preservar rotas abertas. Voltar à Câmara para Eco faltante e ao Viajante para visita opcional sem retroceder nem repetir recompensas.

### Pendências que esta leva não encerra

- Consequências visuais por jogador dos Ecos, sidequests completas e puzzle/arte definitiva da Câmara.
- Alternância de épocas na luta do Sacerdote, tutorial avançado de Manifestação e expansão física da Rota do Eclipse (porto/vilas/cidade/mansão). O mapa atual continua sendo o trecho de deserto/templo, não a rota inteira da bíblia.
- Ilhas 4–6, missões 16–31, bounty/contratos, novos kits/raridades de Stand e validação jogável/performance.

## Leva de builds iniciais — 2026-09-30 (Codex, main; ainda não publicado)

- **Missão 2:** visitar a Taberna abre a escolha Técnica / Manifestação / Arma. Objetivos e escolha são validados no servidor; escolha repetida não concede recompensa. Nenhum ato foi inserido/reordenado: revisão da campanha permanece 3.
- **Rotas:** Técnica aprende Técnica corporal; Arma recebe Espada de treino como Tool nativo, restaurado no respawn; Manifestação ganha uma Flecha na Missão 2. Técnica/Arma recebem sua Flecha no Eco final da Ilha 1; Manifestação recebe Técnica básica nesse final. Loot de Flecha continua independente. Perfis que já passaram pela Missão 2 recebem a escolha ao pedir estado/reconectar, sem voltar atos ou duplicar a Flecha já entregue pela capela.
- **Combate:** espada equipada multiplica M1 por 1,15; Técnica básica por 1,10 e reduz dano recebido em 5%; evolução por 1,20 e reduz em 10%. Espada substitui o bônus ofensivo da Técnica, sem somá-los. Habilidades de Stand mantêm seu dano ofensivo original; proteção da Técnica também vale contra NPCs. Valores provisórios para balanceamento jogável. Tool usa a trava existente de troca fora de combate.
- **Maestria:** cada acerto real de M1 não bloqueado soma 1 XP somente à arma equipada ou ao estilo desarmado, em `weapon:espada_inicial` / `style:tecnica_corporal`; maestrias dos Stands permanecem nas chaves anteriores. Mochila mostra arma, estilo, tier e níveis próprios. Equipar ou golpear vazio não dá XP.
- **Missão 8:** conversar com o mestre e aparar dois golpes abre aprender/recusar. Aprender evolui a rota Técnica para tier 2; outras rotas aprendem tier 1. Recusar continua a campanha e permite aprender ao voltar fisicamente ao mestre; perfis antigos que já concluíram “Respira” também podem aprender nessa visita, sem repetir a missão. Distância e vida são conferidas no servidor.
- **Persistência:** campo `build` carregado com valores padrão/IDs validados no mesmo DataStore v5, sem wipe. Nenhum mapa, asset de arte/animação, arquivo `.rbxl` ou manifest Rojo foi editado. Espada tem representação provisória de madeira criada em runtime e reutiliza os golpes/animações atuais; integração com modelo e animações de arma da equipe fica pendente.
- **Verificação:** 31 testes locais passaram (10 persistência, 13 gameplay, 8 builds); análise estática sem erros de tipo/sintaxe ou avisos de variável sem uso; `git diff --check` passou. Avisos antigos de Font=100 em assets binários permanecem. Studio fechado: hotbar, física, input com Stand e apresentação ainda não validados. Não houve publicação.

### Testar esta leva no Studio quando disponível

1. Perfil novo, cada rota em dados de teste: a escolha só abre após visitar a Taberna; conferir Flecha cedo/tarde e exatamente uma recompensa de campanha. Reconectar antes/depois da escolha.
2. Arma: equipar pela hotbar fora de combate, acertar/errar/bater em block; conferir bônus e maestria somente em acerto real. Guardar, morrer e reconectar; conferir uma espada e maestria preservada. Testar clique/toque e teclas 1–4 com Stand para conferir convivência com a hotbar nativa.
3. Missão 8: mestre + dois parries, aprender com as três rotas (tier 2 só Técnica); recusar, continuar e voltar ao mestre. Conferir resistência contra mob/player e maestria na mochila.
4. Perfil anterior a esta leva: permanecer no mesmo ato, escolher rota, preservar itens/Stand/XP e a Flecha já paga. Conferir dois clientes, mobile, troca persistente e reconexão em experiência de teste.

### Próximas levas/fases (ordem de continuidade)

1. **Fechar Deserto e Eclipse:** Eco após o Sacerdote (selar / destruir / transferir com pré-requisito previsto na bíblia), Missão 13 “O Viajante” e conclusão da Rota do Eclipse. Inserir atos somente com migração explícita dos índices antigos; manter Carlos sem nome até Missão 18.
2. **Consequências e atividades opcionais:** ligar os Ecos já gravados a falas/recompensas/sidequests descritas no cânone; armas/estilos de outras rotas por fontes aprovadas e loot. Auditar NPCs/puzzles existentes antes de criar novos.
3. **Ilhas 4–6:** Cidade Âmbar, Costa Dourada e Fortaleza Maré, missões 16–31 e final do Capítulo 1, seguindo a bíblia. Implementar serviços/objetivos/portais sobre os marcadores existentes; criação e validação da arte continuam com a equipe.
4. **PvP e catálogo:** bounty, contratos e classes sociais sobre as proteções implementadas; preencher raridades de Stand quando kits originais estiverem definidos e assets disponíveis, sem renomear/inventar conteúdo canônico.
5. **Validação e lançamento:** medir rede/FPS/mobile, balancear builds/economia, validar DataStore real e dois clientes. Publicar pelo Studio com place completo e dono, conforme AGENTS.md atual; nenhuma publicação por API nesta leva.

## Correções da auditoria — 2026-09-29 (Codex, main; ainda não publicado)

Esta seção descreve o checkout atual e prevalece sobre os registros históricos abaixo. História, textos das missões e assets da equipe foram preservados. Não declarar Ilha 1, builds ou Capítulo 1 completos.

- **Entrada e campanha:** perfil novo usa a revisão atual e começa na Missão 0; perfis antigos mantêm migração. Vagantes contam `fx_tutorial_enemy`, nunca kills PvP; o contador antigo incorreto é descartado apenas nesse ato. Eco pendente reaparece ao cliente pedir o estado. Arco legado de quests/traidor desativado por `QuestConfig.Enabled=false`, preservando definições e dados antigos; diálogos da campanha continuam ativos.
- **Troca de Stand:** disco, Flecha e essência verificam combate, morte, duelo/partida, torneio, forma temporária e estados de controle antes de consumir itens. Maestria permanece no perfil. Novos perfis nascem com raça humana. Sorteio de Stand mantém chances fixas e a distribuição anterior; mochila exibe as chances efetivas (Swift 55%, Jotaro 26%, Kira 17%, Dio 2%). Faixas sem conteúdo não foram preenchidas artificialmente.
- **Dados:** mesmo DataStore/schema v5; posse de sessão com lease de 180s, snapshots independentes, revisão de alterações e renovação no autosave. Sessão concorrente não abre perfil padrão gravável. Servidores privados continuam sem persistência. `ProfileStore` é módulo puro em `src/server/Modules`.
- **Trocas:** journal `PlayerData_trades_v1` (prefixo real vem de DataConfig.StoreName), preparação de ambos os perfis e decisão persistida; recuperação por commit/abort na reentrada. Resultado incerto congela acesso e pede reconexão; não retorna sucesso antes da decisão. Inventário/cosméticos são alterados em cópias. Bloqueados aceite sobre troca existente e comandos durante execução.
- **Recibos:** PurchaseId persistido junto da recompensa; retry após save falho não repete concessão. Reset administrativo preserva recibos. Produtos continuam com IDs zerados; nenhuma monetização foi ativada.
- **PvE:** mobs da campanha dão XP/moedas/maestria; chefes podem dar Flecha com chance fixa de 3% ou 5%, conforme ProgressionConfig. Chefes dão crédito de campanha/loot aos participantes próximos com pelo menos 5% de dano e golpe nos últimos 30s, não só ao último golpe. Respawns de chefes recebem prefixo “Eco:”. Inimigos da campanha voltam à origem ao passar 100 studs ou nadar, recuperando vida e limpando crédito. Números iniciais, ainda sujeitos a teste jogável/balanceamento.
- **PvP:** zonas locais no Porto, Taberna, chegadas e Lojinha; proteção de retorno de 10s; sem recompensa por vítima mais de 10 níveis abaixo ou pela mesma vítima em 300s. Duelos/guerras compartilhados mantêm dano. Sair durante os 20s de combate PvP custa 10% das moedas, teto 50; shutdown não aplica essa penalidade. HUD avisa proteção, zona e custo de abandono. A proteção PvP não desliga PvE.
- **UI e análise:** mochila/Ecos/sorteio adaptam largura à viewport; Eco tem rolagem. Correções de tipos e remoção de duas variáveis locais sem uso. Arte, animações, mapas e `default.project.json` não foram alterados.

### Verificação e limites

- 23 testes locais passaram: 10 de persistência e 13 de gameplay, usando módulos reais com serviços Roblox simulados. Incluem falhas de gravação, respostas perdidas, recuperação de troca, recibo repetido, tutorial, Eco, bloqueio de item, regras PvP, recompensa PvE, contribuição real e distribuição da Flecha.
- Análise estática final concluída com código de saída 0, sem erros de tipo/sintaxe nem avisos de variável não usada. O Rojo ainda emite avisos preexistentes de migração Font=100 em assets binários; esses assets foram preservados. `git diff --check` passou.
- Comandos: `lune run tests/profile_store.luau`, `lune run tests/gameplay.luau`, `bash tools/analisar.sh`. Detalhes em `tests/README.md`.
- Studio fechado: não houve validação visual/física, teste de dois clientes ou DataStore real. Revalidar essas correções em ambiente de teste antes do rollout. A posse de sessão só protege servidores que executam o código novo; planejar encerramento dos servidores antigos no rollout, sem presumir que respeitam o lease.
- **Publicação por API não realizada:** o dono autorizou esse caminho nesta conversa, mas a tentativa de obter o place completo `85844807133499` pela Asset Delivery API retornou HTTP 403. É necessária uma credencial com leitura autorizada do place atual, ou uma exportação completa e atual confirmada pelo dono. As cópias locais antigas não provam o estado atual. Não publicar `rojo build`: ele substituiria o mapa incompleto, repetindo o incidente da versão 422. Nenhum upload foi feito.

### Testar no Studio quando disponível

1. Perfil novo: Missão 0; três Vagantes + parry; matar jogador não avança. Reconectar em Eco pendente e conferir recompensa única.
2. Tentar disco/Flecha/essência em combate, morto, agarrado e em duelo; recusar sem consumo. Fora de combate, equipar e conferir maestria.
3. Dois clientes: troca com item/moeda, reconexão e falha injetada em dados de teste; conferir ambos os lados. Servidor privado não salva nem aceita compras/trocas persistentes.
4. Mob e chefe com dois participantes e um espectador: XP/loot/crédito só para elegíveis; afastar inimigo e levá-lo ao mar, conferir retorno e crédito zerado.
5. Conferir limites reais das zonas seguras, retorno após morte, recompensas repetidas e aviso/penalidade ao desconectar durante PvP; duelo permanece funcional.
6. Emulador mobile: mochila, chances da Flecha, escolha de Stand e todas as opções dos Ecos acessíveis; textos e avisos legíveis.

### Continuidade de conteúdo (ainda não implementada nesta correção)

- Escolha das rotas da Missão 2 com arma e estilo funcionais e maestrias separadas; efeito real da Técnica ensinada na Missão 8.
- Sidequests novas compatíveis com o cânone, consequências regionais dos Ecos, Eco final do Deserto, Missão 13/conclusão da Rota do Eclipse e expansão posterior às ilhas 4–6.
- Novos Stands das faixas vazias, bounty/contratos e medição de performance. Não preencher essas pendências com história inventada ou assets da equipe modificados.

## Auditoria de próximos passos — 2026-09-29 (Codex)

- Relatório: `AUDITORIA_PROXIMOS_PASSOS_2026-09-29.md`. Somente análise e documentação; nenhum gameplay, asset ou place foi alterado/publicado.
- Conferidos inventário do projeto e fluxos críticos. `tools/analisar.sh` falhou com dois erros distintos: `StandConfig:92` (ItemInfo) e `DataService:501` (number/nil), além de dois avisos de variável não usada.
- Achados por leitura do código, ainda sem reprodução jogável nesta auditoria: perfil novo `story.rev=2` migra e pula a Missão 0; missão dos Vagantes pede `kills`, mas os bots emitem `fx_tutorial_enemy`; usar disco chama troca forçada sem trava de combate; arco legado do traidor continua ativo e conflita com o cânone F/X.
- Saves/trocas precisam proteção contra gravações concorrentes/parciais. Mobs da campanha dão maestria, mas falta integrar XP/moeda/loot. PvP aberto ainda carece das proteções aprovadas. Catálogo da Flecha só possui quatro das sete faixas de raridade.
- Recomendação: corrigir entrada/tutorial e dados, fechar o ciclo repetível da Ilha 1 e proteções, então expandir conteúdo. Ordem detalhada e testes no relatório; recomendação não substitui decisões do dono.
- As seções anteriores que declaram “Ilha 1 completa” ou “análise limpa” são histórico, não validação do checkout atual. Visual, dois clientes, persistência com falhas e mobile continuam pendentes nesta auditoria.

## Direção atual — 2026-09-28

- O projeto migra incrementalmente de Bizarre Showdown/battlegrounds para **F/X**, RPG open-world por regiões e sete capítulos. Combate e sistemas funcionais serão preservados; PvP vira atividade opt-in.
- Auditoria registrada em `AUDITORIA_RPG_2026-09-28.md`; plano em `PLANO_MIGRACAO_RPG.md`; cânone em `BIBLIA_HISTORIA_FX_v1.0.md`.
- Nenhum gameplay ou asset foi alterado nesta etapa. Próximo passo recomendado: documento de design e implementação do vertical slice do Capítulo 1.
- Fundação implementada: `WorldConfig`/`WorldService` (região, checkpoint, descoberta e respawn) e `StoryConfig`/`StoryService` (sete capítulos, atos, flags e Rastros de Carlos). Perfil ganhou `world` e `story` com migração tolerante no DataStore v4; quests antigas continuam intactas durante a transição.
- `StoryConfig` já contém o primeiro recorte orientado por dados do Capítulo 1: chegada, tutorial de combate, primeiro Rastro de Carlos e guardião da região. Ainda não foi ligado automaticamente às kills para impedir que jogadores avancem a campanha nova dentro da arena legada antes de existir o mapa/NPC correto.
- Mapa: `tools/gerar_ilha_tutorial_fx.py` produz `FXTutorialIsland.model.json` com mar, ilha aberta em camadas, porto, vila, campo de treino, bosque, ruínas, Rastro de Carlos, boss spot e portais. O mapa battlegrounds atual foi preservado como **Ilha da Convergência** e ligado à **Ilha do Alvorecer** pelo `WorldPortalService`.
- `TutorialIslandService` popula a ilha no servidor: Humanoider_20 como guia conversável, três Vagantes da Fratura com a IA/combate reais, Guardião Fraturado mais forte e primeiro Rastro de Carlos persistente.
- Loop F/X ligado: conversar inicia a campanha; kills dos Vagantes + parry avançam o tutorial; o Rastro abre o ato do Guardião; derrotá-lo libera a rota `ilha_sol_partido_unlocked`. `StoryController` exibe capítulo, ato, objetivos e avisos.
- Segunda ilha gerada por `tools/gerar_ilha_sol_partido_fx.py`: mesa desértica, cânion, oásis, trilha e templo solar vertical. O portal só atravessa após o Guardião da primeira ilha.
- Ilha do Sol Partido populada: cinco Saqueadores Solares, objetivo de parry, altar no topo e Sentinela Solar. Chegar pela primeira vez avança o ato; vencer a Sentinela libera a futura rota do Mar de Cinzas.
- Release F/X 2.0 preparado para publicação por Open Cloud: duas ilhas, arena legada como Ilha da Convergência, campanha/HUD/save/checkpoints/portais e changelog 2.0.
- Direção das seis ilhas do Capítulo 1 registrada em `MAPA_CAPITULO_1.md`; cada era deve variar geografia, paleta, verticalidade e loop, mantendo identidade original.

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

## LISTA DO DONO (2026-09-17, depois de testar) — em levas
Pedidos, na ordem que ele escolheu: **1) menus** → 2) conquistas → 3) menu DEV + denúncias.
- **Parte 1 (correções) — FEITA**: soco para BAIXO livre (qualquer soco no ar caindo vira Downslam,
  Up = −55 joga o alvo para baixo, ragdoll 1,6 s; saiu o FollowUpWindow); cutscene do despertar com a
  direção do personagem CONGELADA (`baseCF`) + shift lock solta o boneco/mouse durante a cena (era o
  giro rápido da tela); câmera da cutscene escala com o tamanho do rig (`rigScale`, Big C.H.O.P. cabe
  na tela); HUD mostra a ULTIMATE no slot numérico dela — apagada com "(desperto)" fora do modo,
  dourada durante — e o G virou "Despertar" (o aviso do despertar diz a tecla).
- **Parte 2 (menus) — FEITA, falta o dono testar**: topbar com 4 botões e DROPDOWN embaixo
  (`TopbarController`): Jogar (Personagens V, Duelo J, Clã C, Placar Tab), Loja (Loja L, Cosméticos K),
  Perfil (Perfil P), Config (Controles + Dev para quem é desenvolvedor). `TopbarController.AddToSettings`
  pendura ícones no dropdown de Config (usa `joinDropdown`: `setDropdown` DESTRÓI os itens que já estão
  lá). As teclas continuam abrindo os painéis direto.
- **Parte 3 (conquistas) — FEITA, falta o dono testar**: missões diárias SAÍRAM.
  - `AchievementsConfig.luau`: 23 conquistas — 16 permanentes (kills/duelos/boss/tempo/nível/maestria/
    coleção) + a final **ZEROU O SAHUR** (conta as outras permanentes) + 6 do **Passe 1 — Despertar**
    (`Seasons`, começa 17/09/2026, dura 60 dias). Recompensa = pontos, XP, cosmético, emote ou personagem.
  - Itens LIMITADOS: `CosmeticsConfig` com `Season`/`Limited` (s1_skin_arrow, s1_cape_arrow,
    s1_aura_arrow, s1_emote_arrow) — fora da roleta; acabou o passe ninguém mais ganha, só DEV
    (`AdminService.GrantItem {id}`). Passe novo = nova entrada em `Seasons` + conquistas `Season = "<id>"`.
  - `AchievementService.luau` (servidor): contadores que só sobem no perfil (permanentes + do passe, que
    zeram quando o passe muda), paga uma vez cada conquista, `FetchAchievements`/`NotifyAchievement`.
    `ProgressionService` virou só XP/nível/maestria e empurra os contadores para cá.
  - Perfil salvo: **schema 2** (`profile.achievements = { counters, done, season }`); perfil antigo
    aproveita kills/nível das estatísticas. O campo `missions` fica no save sem uso.
  - UI: `AchievementsGui` (lista com barra, recompensa e "Passe X — N dia(s)") + `AchievementsController`,
    no dropdown **Perfil**; a coluna direita do painel Perfil virou "CONQUISTAS" (as 4 mais perto de fechar).
  - DEV: `CompleteMissions` virou `CompleteAchievements` (empurra tudo para a meta) e entrou `GrantItem`.
  - Testado via MCP: 23 conquistas, passe com 60 dias, kills_10 pagou, conquista de passe entregou a aura
    limitada, DEV entregou a skin limitada, painel abre com a lista certa.
- **Parte 4 — MENU DEV de verdade + DENÚNCIAS — A FAZER (próximo passo desta lista)**:
  - **Denúncia (novo sistema)**: jogador denuncia outro com MOTIVO PREDEFINIDO (hack/exploit, ofensa,
    nome impróprio, bug abuse, outro) + TEXTO LIVRE; guardar em DataStore por UserId denunciado
    (`ReportService` + `ReportConfig`), com data, quem denunciou, servidor (JobId) e o motivo. Entrada
    pela UI: botão no placar (Tab) ou no perfil do jogador.
  - **Menu DEV**: teleportar para a arena (Arena_Gerada/Arena_Antiga), ENTRAR no servidor de um jogador
    (`TeleportService:TeleportToPlaceInstance` com o JobId — precisa de uma lista de jogadores online,
    que hoje só existe por servidor; ver se vale um MemoryStore/DataStore com quem está onde),
    ASSISTIR um jogador (câmera espectadora presa nele, sem sair do servidor), ver as DENÚNCIAS de um
    jogador e DAR ITENS (o `AdminService.GrantItem {id}` já existe; falta a tela com busca de item).
  - Já pronto para isso: `AdminService` com comandos por alvo, `DevGui` gerado por `tools/gerar_devgui.py`,
    `AchievementService.GrantReward` (cosmético/emote/personagem).
- **Pergunta respondida ao dono**: id de animação da equipe substitui a procedural só se o clipe estiver
  marcado `team = true` em `ProcAnimDefs` (hoje a procedural manda mesmo com id, decisão dele de 17/09).

## RETOMAR AQUI (fim da sessão 2026-09-29) — ler isto primeiro
**Estado**: tudo commitado e no GitHub. O dono vai PUBLICAR pelo Studio (nunca por API). Feito hoje, em ordem
(detalhes nas seções abaixo): bíblia do Cap. 1 + estrutura do jogo sincronizadas (ilhas Porto da Névoa / Deserto do
Sol / Rota do Eclipse); chão das ilhas de PEÇAS LISAS (SmoothPlastic, sem material realista); Stands/raças/mochila +
WIPE (schema 5); Pescador salva o spawn; HUD estilo Blox Fruits (menu lateral, status embaixo à esquerda, topbar só
Config); gráfico menos claro; Ilha 1 completa com os Ecos (StoryConfig rev 3).

**O dono ainda não viu em jogo** (pedir o retorno dele primeiro): cores do chão/rampas; mochila + sorteio da Flecha +
cadeados "M<n>"; menu lateral (cada botão abre o painel certo) e layout no celular; Pescador; iluminação nova (ajuste
fino = só `ExposureCompensation`); Missão 0 (distorção), telas dos Ecos, se a fenda estreita e a rachadura da capela
são achaveis.

**Próximas levas sugeridas** (dono escolhe): (1) Rota do Eclipse completa (porto, vilas, mansão, Missão 13 "O Viajante");
(2) Ilhas 4–6 (Cidade Âmbar, Costa Dourada, Fortaleza Maré; Missões 16–31, Avatar da Fratura); (3) efeitos das raças,
Flechas no mapa/drop de chefe, Echo Bosses, bounty/zonas seguras (ESTRUTURA_JOGO.md); (4) armas/estilos → escolha de
rota da Missão 2; depois places por capítulo e Server Authority.
**Ferramentas úteis**: erros do CLIENTE só aparecem no log do Studio (`[Client] FALHA em ...`; script em
scratchpad/clientlog.sh da sessão — refazer: awk no `*_last.log` mais novo filtrando pelo ts); NPC gerado → posicionar
pela raiz; `.model.json` de UI: nome também em `properties.Name`.

## 2026-09-29 (noite, 5) — ILHA 1 COMPLETA + ECOS (conteúdo, leva 4)
- `StoryConfig` **rev 3** (migração 1→2, 2→4, 3→8, 4→9, ≥5 → +6): Missões 0 "Acorde", 2 "Porto da Névoa", 3 com a fenda
  instável, 4 "A Máscara", **Eco 1** (sobreviventes) e **Eco final da Ilha 1** (capela). Flecha + portal só DEPOIS do Eco.
- Motor novo: `Choice` (Eco na tela, `RequestStoryChoice` → `StoryService.Choose`: grava flags `eco_*` e `<choice>_<opção>`),
  opção com `RequiresFlag` (pista achada explorando: `fenda_saida`, `passagem_capela` via `StoryService.SetFlag`),
  objetivo `reach_<lugar>` (`StoryConfig.Places`, conferido a cada 0,5 s), `Intro/IntroNpc/GuideNpc` (o "???" antes do
  nome do Humanoider). Eco pendente reabre ao conversar com o Humanoider ou ao entrar no jogo.
- Mapa (`gerar_ilha_tutorial_fx.py`, pasta Historia): destroços/bolsa/estrutura na praia, fenda com cacos + 2
  sobreviventes + fenda estreita escondida, altar da máscara + Portador da Máscara (bot), rachadura na capela.
- Cliente: tela de escolha (opção trancada = "???") e distorção da Missão 0 (`StoryController`).
- Testado no Play (servidor, fluxo inteiro + opção trancada recusada + migração) e log do cliente limpo. **Falta o dono
  jogar**: textos, posição dos objetos, a tela de escolha, a distorção.

## 2026-09-29 (noite, 4) — GRÁFICO menos claro (dono: "tá muito claro a tela")
- `EnvironmentService` CONFIG do dia: Brightness 4→2.6, ExposureCompensation +0.1→−0.3, Ambient/OutdoorAmbient mais
  escuros e frios, EnvironmentDiffuse/Specular 0.55/0.6→0.35/0.35, ShadowSoftness 1→0.35 (sombra de anime), Atmosphere
  Haze 0.6→0.15 (horizonte não lava), Bloom curto (limiar 2.2), ColorCorrection contraste 0.14/brilho −0.03, SunRays leve
  (zera à noite). Base: docs Roblox (superexposto = exposição/brilho/difuso altos) + refs de estilo cartoon/anime.
  Testado no Play (valores aplicados). **Falta o dono olhar** — se ainda claro/escuro, mexer só em ExposureCompensation.

## 2026-09-29 (noite, 3) — HUD ESTILO BLOX FRUITS + MENU LATERAL (leva 3)
- **Topbar**: só o Config (Configurações, Controles, Novidades, **Denunciar**, Dev/Mods). Personagens/Jogar/Loja/Perfil
  continuam existindo (teclas V/J/C/Tab/L/K/P e painéis), mas escondidos (`setEnabled(false)`).
- **Menu lateral** (`MenuController`, esquerda no meio): Mochila (M), Loja (L), Visual (K), Perfil (P), Conquistas,
  Duelo (J), Clã (C), Placar (Tab) → `InventoryController.Toggle` / `TopbarController.Toggle(nome)`.
- **Status no canto inferior esquerdo** (`HUD.Vitals`): selo de NÍVEL, vida, energia/ult, barra de XP; pontos logo acima.
  Missão da história segue no canto superior esquerdo; habilidades embaixo no centro. Toque: status sobe (abaixo da
  missão) e o menu lateral encolhe (o canto inferior esquerdo é do analógico).
- Conferido pelo LOG DO CLIENTE (`scratchpad/clientlog.sh <ts>` no log do Studio): pegou um bug (cópia do nó Energy no
  `HUD.model.json` herdou `properties.Name = "Energy"` → HUDController.Init quebrava); consertado, cliente sobe limpo.
  **Nesses .model.json o nome vem de `properties.Name` também — ao copiar nó, trocar os dois.**
- **Falta o dono ver**: layout, clique em cada botão do menu lateral abre/fecha o painel certo, celular.

## 2026-09-29 (noite, 2) — PESCADOR salva o spawn (pedido do dono)
- `FisherService`: um **Pescador** por ilha (`WorldConfig.Regions[*].Fisher`), perto da chegada e visível (nome
  "Pescador · salvar spawn", camisa azul, vara). Conversar = `WorldService.SetCheckpoint` naquela ilha + fala dele.
- **Portal não salva mais o spawn** (só leva; `WorldService.Discover` marca a região e o AntiExploit ganha `Grace`).
- Conserto: NPCs gerados por `CreateHumanoidModelFromDescription` ficavam 1.5–1.7 enterrados com `PivotTo` (o pivô não é
  a raiz) → Humanoider_20, Mestre e Pescadores agora posicionados pela RAIZ, sobre o topo do marcador. Testado no Play.

## 2026-09-29 (noite) — STANDS, RAÇAS, MOCHILA E WIPE (leva 2)
- **WIPE**: `DataConfig.SchemaVersion` 4 → **5** = DataStore novo `PlayerData_v5` (todo mundo do zero; o `_v4` ficou
  intacto). Perfil ganhou `power` (Stand ativo), `race`, `inventory` e `born`.
- `StandConfig` (compartilhado): 7 raridades (Comum 55% … Anômalo 0,05%), **chance fixa, sem pity**; Stands = kits
  atuais (Bruno comum, Jotaro incomum, Kira raro, Dio lendário; Rick continua drop do boss); teclas liberadas por
  **maestria do Stand** (1→M1, 2→M2, R→M3, 3→M4, 4→M6, G→M8); raças (Humano; Vampiro e Homem de Pedra por missão, efeitos
  ainda não); itens `flecha`, `stand:<id>` (Disco de Stand), `raca:<id>` (Essência); nascer "abençoado" 0,2%/0,1%.
- Kit **Humano** (M1/dash/block, sem ult) é o padrão (`CharacterDefs.DefaultCharacter`). Os 4 kits viraram
  `Access = "stand"`: `DataService.HasCharacter` só aceita o Stand ATIVO (dev e mod "todos" usam qualquer um).
  `GrantCharacter` de Stand (conquista, loot, admin) = **disco na mochila**. VIP não dá mais o Dio; passe "todos" saiu.
- `StandService`: Flecha sem Stand = equipa; com Stand = disco já vai para a mochila e o jogador escolhe "usar (perde o
  atual)" ou "guardar"; repetido = disco direto. Disco/Essência: usar troca (o atual é perdido). Maestria fica salva.
- Maestria agora sobe também matando NPC (12) e chefe da campanha (80). `AbilityService` recusa tecla trancada
  (`mastery:N`) e o Humano no G (`no_awaken`); HUD mostra "M4" no slot trancado e esconde o G do Humano.
- **Mochila** (`InventoryController`, tecla **M** + botão na tela): Stand/raridade/maestria/próxima tecla, raça, itens com
  "Usar"; pop-up do sorteio. **Troca** aceita itens da mochila (1 unidade por entrada). Humanoider dá a **Flecha** ao
  vencer o Herdeiro da Névoa (`Reward` no ato). DEV: "Dar todos" = discos + 5 Flechas; "Tirar todos" = humano e mochila
  vazia; toggle "sem cooldown" ignora as travas de maestria.
- Testado via MCP (servidor): tudo acima. **Falta o dono ver**: mochila, pop-up, cadeados no HUD, trocar Flecha entre 2
  clientes. **Ainda não feito**: rota inicial Técnica/Arma (espera o sistema de armas/estilos), efeitos das raças,
  Flechas no mapa/drop de chefe.

## 2026-09-29 (tarde) — CHÃO DAS ILHAS DE PEÇAS (leva 1 aprovada pelo dono)
- `tools/gerar_chao_ilhas.py` → `src/workspace/ChaoIlhas.model.json` (`Workspace.Sahur.ChaoIlhas`, 1206 peças, no git).
  Camadas por LINHA numa grade fixa de Z (20 studs): **topo** y -0.15 (d ≤ 0.90 da elipse), **praia** -0.9 (≤ 1.0),
  **areia molhada** -1.7 (≤ 1.06) e **rampas** WedgePart de -1.7 a -6.5 em todo o contorno. Degraus de ~0.8 (sobe
  andando). Lóbulos: Deserto do Sol no Coliseu e na vila mesopotâmica. Sobreposições no nível do topo: oásis (jardim/
  cachoeira) e areia do Coliseu. Recortes mais baixos: Taberna (-0.95), riacho/lago/laje do jardim (-1.1).
- **Material: tudo SmoothPlastic, só cor** (dono: nada do material realista do Roblox; chão simples, fácil de texturizar
  e modelar depois). Biomas por cor: Porto da Névoa grama; **Deserto do Sol = areia avermelhada** + oásis verde; montanha do santuário em 4 degraus
  de arenito (oeste e norte; leste é paredão por causa da escavação); Rota do Eclipse areia clara + 3 dunas em degraus.
- `MontarMundo.luau` agora só faz o MAR (Terrain de água). Terreno antigo: `ServerStorage.Backup_Terreno_2026-09-29`
  (restaurar: `Terrain:PasteRegion(backup, Vector3int16.new(-200, -12, -250), true)`).
- Testado via MCP: nada do mapa ficou sem chão (exceto o cais, que é sobre a água, e o que está nos recortes); zero
  z-fighting entre peças do chão; personagem em pé em 14 pontos (porto, vila, ruínas, Taberna, Deserto, Coliseu,
  escavação, oásis, topo/degrau da montanha, Rota, duna, Kame); NPC **sai do mar nadando** e sobe até o topo em 4 costas.
- **Falta o dono VER** (não tirei screenshot: a janela ativa era outro jogo seu) — cores, praia, montanha, rampas.
  Editar o chão à mão = "entregar" a pasta antes (regra do CLAUDE.md), senão o Rojo sobrescreve.

## RETOMAR AQUI (2026-09-29) — bíblia do Cap. 1 + estrutura do jogo sincronizadas
**Docs novos do dono**: `BIBLIA_CAMPANHA_CAP1_v0.1.md` (campanha do Cap. 1, missões 0–31, Ecos) e `ESTRUTURA_JOGO.md`
(4 camadas: campanha / farm-loot / sidequests / PvP com bounty). Renomeados (o nome antigo tinha quebra de linha) e
**sem palavrões** (eram só exemplo; também tirados da `LORE_FX_CANONE.md`). Regra do dono: **o que está no jogo e não bate
com os arquivos muda para bater; o que der para juntar, junta.** Junções registradas em `BIZARRE_DIRECAO.md`
(rota inicial Técnica/Arma/Manifestação + Flecha; raridade em 7 faixas sem pity; PvP aberto com proteções; Humanoider
revela o nome de Carlos na Missão 18 e Adryan conta a "versão oficial" no Cap. 2; Ecos = flags `eco_*`).

**Feito (29/09, código — análise estática limpa)**:
- Ilhas renomeadas (ids mantidos): `ilha_tutorial` = **Porto da Névoa**, `ilha_pilares` = **Deserto do Sol**,
  `ilha_sol_partido` = **Rota do Eclipse**, `arena_pvp` = Coliseu do Deserto. Tabela em `MAPA_CAPITULO_1.md`.
- `StoryConfig` **revisão 2**: 14 atos do Cap. 1 com o número da missão da bíblia (`Mission`), `Region`, `Arrive`,
  `UnlockFlag`, `Guide` (fala do Humanoider_20 ao entrar no ato, em qualquer ilha) e `Traces` com texto por rastro.
  `StoryService` virou 100% dirigido por dados + **migração** (`profile.story.rev`; perfis sem rev passam de ato ≥5
  para "Calor" com a rota da Ilha 2 aberta). Contadores genéricos (kills/parries) só valem **na ilha do ato**, pela
  posição real (`StoryService.RegionOf`). O nome "Carlos" não aparece antes da Missão 18 ("Rastro encontrado").
- Porto da Névoa: Guardião Fraturado → **Herdeiro da Névoa** (kit Dio); falas da bíblia; rastro "o objeto impossível".
- **Deserto do Sol** (novo `DesertoDoSolService`, marcadores na pasta `Historia` do `FXPilaresIsland`, gerados por
  `tools/gerar_ilha_pilares_fx.py` com alturas medidas por raycast): 4 Homens de Pedra (escavação a leste, 1070,-490),
  Mestre da Respiração + discípulo (720,-470), símbolo na Câmara (santuário, 884,-575), **Sacerdote do Sol Negro** (900,-600).
- **Rota do Eclipse** (`SolPartidoService` → `RotaEclipseService`): Caçadores de Recompensa, rastro "o homem que não
  existe" no altar, **O Observador** (kit Jotaro).
- Portais: Porto → Deserto só depois do Herdeiro (`ilha_pilares_unlocked`); Deserto → Rota só depois do Sacerdote
  (`ilha_sol_partido_unlocked`). Voltar é livre. **O Coliseu agora fica atrás do tutorial.**
- Log de novidades **2.1** ("Capítulo 1: Primeira Fratura"), `UpdateLogConfig.Current = "2.1"` (o DEV publica).

**Servidor testado via MCP no Play (29/09)**: boot OK (50 services); todos os bots/NPCs novos nascem no chão; os 14 atos
avançam em ordem, com as flags e os portais certos; migração rev1→rev2 OK. **Falta o dono ver o VISUAL** (falas, HUD, lutas)
pela lista abaixo. Obs.: o teste zerou o `story` do perfil do dono no Studio (estava no ato 2).

### Como testar (29/09)
1. Conversar com o Humanoider_20 → fala nova; HUD "Prove que consegue sobreviver".
2. 3 Vagantes + 1 parry → rastro nas ruínas (toast "Rastro encontrado · O objeto impossível") → Herdeiro da Névoa.
3. Portal NE antes do Herdeiro = "rota selada"; depois atravessa → ato "Os Homens de Pedra" + fala do Humanoider.
4. Escavação a leste (4 Homens de Pedra) → Mestre (conversar) + 2 parries no discípulo → símbolo na Câmara →
   Sacerdote no santuário → portal da praça abre para a Rota do Eclipse.
5. Rota: 5 Caçadores + 2 parries → altar do templo (registro) → O Observador → "Rumo à Cidade Âmbar".
6. Perfil antigo (quem já estava no Sol Partido) deve cair em "Calor" com o portal da Ilha 2 aberto.

**PRÓXIMAS LEVAS** (ordem de 28/09 mantida, com a bíblia por cima):
1. Chão das ilhas de **peças** (Deserto do Sol vira deserto árido com ruínas astecas + oásis na cachoeira).
2. **Stands/raças/rota inicial** (ver junções em `BIZARRE_DIRECAO.md`) + inventário + raridade 7 faixas.
3. HUD estilo Blox Fruits + menus na tela.
4. Missões que faltam do Cap. 1 (0 "Acorde", 2 vila + escolha de rota, 4 Portador da Máscara, Ecos com escolha na tela,
   13, 16–31), Echo Bosses, bounty/zonas seguras/combat log, eventos F/X. Depois places por capítulo e Server Authority.

## RETOMAR AQUI (fim da sessão 2026-09-28, noite) — ler isto primeiro
**Direção**: Bizarre Showdown F/X = RPG open world (estrutura Blox Fruits) com o combate do Battlegrounds. História
CANÔNICA = `LORE_FX_CANONE.md` (doc do dono; `HISTORIA_FX_PROPOSTA_v1.1.md` só complementa). Mapa = `MAPA_CAPITULO_1.md`.

**Feito hoje (28/09)**:
1. Incidente do ChatGPT (publicou `rojo build` por API e apagou o mapa): dono restaurou a v421; regra "nunca publicar
   por API" no CLAUDE/AGENTS; lixo do Codex removido.
2. Iluminação cartoon (valores do dono) → depois menos saturada (0.15), céu padrão da Roblox + nuvens volumétricas.
3. **Arquipélago do Capítulo 1**: arena fechada desmontada; Ilha 1 Alvorecer (Parte 1, com a Taberna), Ilha 2 Pilares
   (Parte 2: selva asteca, santuário na montanha da cachoeira, Coliseu PvP), Ilha 3 Sol Partido (Parte 3), ilhota
   Kame (easter egg). Terreno por `tools/studio/MontarMundo.luau`. Testado no Play via MCP.
4. Lore canônica do dono salva; proposta de história do Claude registrada como complemento.
5. Nome público decidido: **"Bizarre Showdown F/X"** (o dono troca no dashboard; a chave da API não tem `universe:write`).

**⚠️ PENDENTE DO DONO**: **publicar pelo Studio** (File > Publish). Terreno, ilhota, iluminação e o código de hoje só
estão no Team Create. Trocar o nome no dashboard.

**PRÓXIMAS LEVAS (ordem combinada)** — decisões do dono já tomadas:
1. **Terreno de PEÇAS, não Terrain realista** (dono: "players gostam de simplicidade com coisas bem feitas"): refazer o
   chão das ilhas com Parts/models simples e quadrados (bem feitos, leves, fáceis de texturizar e modelar), no lugar do
   Terrain do `MontarMundo` (a água do mar pode continuar a decidir). Manter os mesmos centros/raios (`WorldConfig.Islands`).
2. **Stands e raças** (tudo do ZERO: wipe de todos os perfis, ninguém comprou VIP; passe VIP do Dio sai):
   - Todo mundo nasce **HUMANO**; existem outras **raças**. No começo, sorteio de stand/raça de "padrão": quase sempre
     comum; só com sorte absurda o player vem "abençoado". Os melhores/mais raros têm chance "menor que o sol explodir".
   - Fim do tutorial: Humanoider_20 dá uma **Flecha** → sorteio de Stand por **raridade** (todos os kits atuais entram).
   - **Chance fixa por uso, SEM pity/acúmulo.** Flechas: achadas no mapa, trocas, missões, bosses. **Raças: só missões
     especiais.** Tudo **guardável no inventário** (flechas, stands, raças).
   - Trocar de stand/raça = **perde o anterior** (precisa achar de novo ou ter no inventário e usar), mas a
     **maestria/progresso de cada stand/raça fica salva**. Habilidades liberam por **maestria** (usar `profile.mastery`).
3. **HUD estilo Blox Fruits** (vida, energia, cooldowns na tela) e **menus na tela**; o dropdown do topbar fica só para
   menus "sérios" (Denúncia, Config...).
4. Conteúdo: Sol Partido (Parte 3: porto, mansão do vilão), ilhas das Partes 4–6 (Parque B na reserva para a Parte 4).
   **Missões com mais de um final** (caminhos diferentes, mesmo final da história).
5. **Cada capítulo = outra place** (como os Seas do Blox Fruits) — planejar a divisão quando o Cap. 1 fechar.
6. Locomoção entre ilhas/cidades grandes que não seja só barco (propostas: trem, cavalo, portais do cientista).
7. **Server Authority** (dono aceitou refazer dash/corrida em simulação prevista + compensação de lag).
Pontas soltas técnicas: flecha do ritual só nasce perto da origem (`RitualService` SpawnRadius); boss à solta pode ir
para o mar; `StoryConfig` ainda tem os atos antigos do ChatGPT (reescrever com o cânone).

## ⚠️ INCIDENTE 2026-09-28 — place oficial sobrescrito (ler antes de tudo)
- O ChatGPT/Codex publicou um `rojo build` puro pela Open Cloud → **versão 422** do place 85844807133499
  (21:49 UTC = 18:49 BRT) só tem o que está em `src/`: sumiram Taberna, Hall, Lojinha, santuário/altar,
  `ServerStorage.CharacterModels`/`Mods`/backups, iluminação e tudo montado via MCP.
- **RESTAURADO pelo dono** (versão 421 de 23/09 09:42 → virou a 424; Taberna/Hall/Lojinha de volta, conferido via MCP).
- Conserto usado = restaurar a versão anterior (Creator Dashboard → experiência → Places → place → Version History →
  versão de 28/09 antes de 18:49 BRT → Restore). Fechar o Studio ANTES (Team Create está com a versão ruim aberta).
  Depois: abrir o Studio, conectar o Rojo (traz o código F/X do commit 0920a7f + correção do mar) e publicar pelo Studio.
- Código F/X (World/Story/TutorialIsland/SolPartido/WorldPortal) testado via MCP no Play: boot OK (49 services), bots das
  ilhas nascem; sem erro novo. Mar da ilha tutorial encolhido para não passar por baixo da arena (x ≥ 300).
- `src/shared/CentralProjectMarker.luau` (lixo do Codex) apagado.

## 2026-09-28 (noite, 3) — cores menos saturadas, céu cartoon, novas direções do dono
- `EnvironmentService`: ColorCorrection 0.5 → 0.15 (dono: "saturado demais"), Atmosphere leve azulada, skybox PADRÃO da
  Roblox (`rbxasset://textures/sky/sky512_*.tex`; o antigo 6412503613 ficou nos atributos do Sky), sol/lua maiores,
  nuvens volumétricas (`Terrain.Clouds`, cor segue o dia/noite). Testado no Play.
- **Proposta de história** em `HISTORIA_FX_PROPOSTA_v1.1.md` (Tear das Linhas, F/X = Fio/Fratura/Cruzamento, cientista
  com a Agulha de Fratura, player "Desfiado", motivo do Adryan, Carlos Arquivista) — AGUARDA o dono aprovar.
- **Direções novas do dono (a fazer, em levas)**:
  1. **Stands**: nasce HUMANO (sem Stand; só M1/dash/block). No fim do tutorial o Humanoider_20 entrega uma **Flecha** →
     sorteio de Stand por **raridade**. Habilidades do Stand liberam por **maestria** (reusar `profile.mastery`).
  2. **HUD de verdade estilo Blox Fruits**: vida, energia, cooldowns, tudo na tela. **Menus na tela**; o dropdown do
     topbar fica só para menus "sérios" (Denúncia, Config...).
  3. **Locomoção** entre ilhas/cidades grandes que não seja só barco (proposta: trem nas pontes, cavalo, Costuras).
  4. Depois: Server Authority (já combinado).
- Ajustes manuais do dono no Studio: ver "Regra: edição manual x Rojo" no CLAUDE.md.

## 2026-09-28 (noite) — ARQUIPÉLAGO: arena desmontada em ilhas por Parte de JoJo (dono autorizou tudo)
Ver `MAPA_CAPITULO_1.md` "Layout do mundo". Resumo:
- `tools/desmontar_arena.luau` (Lune) dividiu o `Arena.rbxm` (apagado; original em `backups/`) em `Coliseu.rbxm`,
  `PecasArena.rbxm` (montanha da Taberna recolorida p/ rocha, Parque Vitoriano, árvores) e `src/reserva/ArenaReserva.rbxm`
  (→ `ServerStorage.ArenaReserva`). `gerar_arena.py` translada os extras por grupo (santuário/jardim → Ilha 2, vilas
  mesopotâmicas → Ilhas 2/3, placares/bonecos/spawns → Ilha 1). Geradores novos/refeitos: `gerar_ilha_tutorial_fx.py`
  (vila vitoriana), `gerar_ilha_pilares_fx.py` (coliseu + chegada), `gerar_ilha_sol_partido_fx.py` (movida).
- **Terreno** (`tools/studio/MontarMundo.luau`, ModuleScript em `ServerStorage.FerramentasStudio`): mar de água de verdade até
  o horizonte, ilhas com praia, montanha do santuário (cachoeira ~92 studs), escavações (Taberna, santuário, riacho).
  Rodar: `require(game.ServerStorage.FerramentasStudio.MontarMundo:Clone())`. ATENÇÃO: o terreno suave desenha o chão
  ~2 studs acima da ocupação — o script compensa (`SOLID_OFFSET`).
- Via MCP (só no place): Lojinha +50 z; ilhota Kame (CasasKame/House Trink/LocalInicial; SpawnLocation desligado);
  pedras/árvores do dono perto do farol; estátua `humanoider_20` no porto (ancorada, estava tombando); muro longo do `cav`
  encurtado. Backup de tudo em `ServerStorage.Backup_Mapa_2026-09-28`.
- Código: `WorldConfig` (ilha_pilares, `Islands`, `IslandAt`), portais novos, `QuestConfig.Spots` nas ilhas,
  `DestructionService` acha árvores em todo o `Sahur`, tutorial usa `VagantePad`/`GuardiaoSpawn` (não colidir com
  `DummyPad`/`BossSpawn`). Testado no Play via MCP: 49 services, bots/NPCs nas ilhas, chão em todos os checkpoints.
- **Falta**: o dono PUBLICAR pelo Studio; Sol Partido ainda vazio (conteúdo da Parte 3); Partes 4–6; flecha só nasce perto
  da origem (RitualService `SpawnRadius`); boss à solta pode andar para o mar; barco/viagem sem portal.

## 2026-09-28 (noite) — iluminação cartoon + decisões do dono
- **Nome público decidido: "Bizarre Showdown F/X"** (a chave da API não tem `universe:write`; o dono troca no dashboard).
- **Iluminação "cartoon e animada"** (pedido do dono, ref. TikTok): `EnvironmentService` CONFIG do dia = Ambient 124,155,184;
  Brightness 4; OutdoorAmbient 157,178,255; ShadowSoftness 1; Bloom Size 56; ColorCorrection Contrast/Saturation 0.5,
  Tint 243,234,255. `LightingStyle = Realistic` gravado no place via MCP (script não escreve). Testado no Play.
- **Server Authority (`Workspace.AuthorityMode = Server`) NÃO ligado**: só dá para setar no painel do Studio, e o dash/corrida
  são `LinearVelocity`/`AssemblyLinearVelocity` no cliente (`MovementController`) — com autoridade do servidor isso é
  desfeito. Precisa de leva própria: mover dash/corrida para simulação prevista (`RunService:BindToSimulation` + InputActions)
  e testar knockback/ragdoll/agarrão antes de ligar.

## RETOMAR AQUI (última sessão: 2026-09-25 noite — B5, C0, D1–D4 + HALL da Taberna FEITOS; Studio travou no fim (Hall pode não ter salvo: rerodar montar_hall); próximo = C2 → C5, depois testes do dono)

### ONDE PARAMOS (ler primeiro)
**21/09 (sessão seguinte) — BUG DO HALL RESOLVIDO ("textura gigante atravessando a caverna, não dá para clicar")**: os 50
móveis restaurados do backup JSONL vieram com `MeshSize = 0` (MeshPart recriada por `Instance.new` + `MeshId` não
carrega a geometria) → colisão certa, render deformado/fora do lugar. Diagnóstico por bissecção com screenshots
(scratchpad `shot.sh` = KWin ativa a janela "Wine Desktop" + `spectacle -f`; `diff.py` compara pixels). Conserto:
`tools/consertar_meshparts.luau` via MCP (CreateMeshPartAsync + ApplyMesh; 134 MeshParts, 0 falhas) — **o dono
precisa SALVAR o place**. Regra nova: toda vez que algo entrar pelo `restaurar_workspace.luau`, rodar o
`consertar_meshparts` em seguida. Pendente de olhar: "riscos" brancos diagonais nas tochas clonadas do Hall (partículas?).
**25/09 (noite, dono de volta) — HALL DE ENTRADA da Taberna FEITO**: `tools/montar_hall.luau` (roda via MCP; idempotente;
DEVOLVE os móveis à pilha antes de recriar — nunca apagar `Taberna.Hall` à mão sem tirar `Hall.Moveis` de dentro) monta
`Workspace.Taberna.Hall` na sala do `cav` a oeste do salão (x 274..325, z 78..110): piso/tapete/vigas, batentes + placa
"TABERNA" + lanternas, PORTAS DE SALOON (`Entrada.PortaSaloon`, asas `AsaSul`/`AsaNorte` + `Gatilho`), tochas, e os 50
móveis da pilha `Moveis taverna` reaproveitados (nada apagado). `SaloonDoorService` (Rojo) abre/fecha as asas (testado
no Play: abre para o lado oposto de quem vem, balança ao fechar) e põe prompt "Trancada" na porta dos fundos (norte).
Incidente: um rerun apagou os 50 móveis junto com o Hall antigo → restaurados do backup `workspace_dono_2026-09-25b.jsonl`
via rbxm temporário no Rojo (`restaurar_workspace.luau` aceita nome da pasta no 3º arg). O dono SALVA o place.
Para o dono conferir amanhã: orientação dos móveis (frente/costas), a "haste" fina vista perto do tapete (luminária?),
tochas, e ajustar o que quiser no próprio Studio (não rodar o montar_hall de novo depois de editar à mão).
**D3 FEITO (25/09, sem teste)** — TORNEIO "ÚLTIMO DE PÉ" por cima do mapa livre: `TournamentConfig` (solo/duo/clan,
inscrição 90 s, contagem 10 s, máx. 10 min = empate; prêmio padrão 1500 pontos + 300 evento + 800 XP + cosmético
opcional), `TournamentService` (idle→signup→countdown→running→fim; atributos `Tournament`/`TournamentTeam` no Player;
morte por qualquer causa/sair do servidor = eliminado; companheiro não machuca companheiro — `HealthService.IsInvulnerable`;
`profile.stats.tournamentWins` + contador `tournament_wins`), `TournamentController` + `TournamentGui` (barra centro-alto
com ENTRAR/SAIR, timer, vivos; banner de início/vencedor; toast por eliminação), DEV → MAPA → "TORNEIO" (Abrir SOLO/
DUPLAS/CLÃS com prêmio na caixa "pontos, evento, xp, cosmético"; Fechar e INICIAR; Cancelar). Bots não participam.
FUTURO anotado: morte súbita (área encolhe), prêmio em Robux. TESTAR (2 clientes): DEV abre SOLO → os dois ENTRAR →
INICIAR → contagem → um mata o outro → banner "ÚLTIMO DE PÉ: <nome>" + prêmio no vencedor; DUPLAS com 2 = cancela
(1 time só); CLÃS sem clã = recusa; Cancelar no meio limpa a barra.
**D2 FEITO (25/09, servidor testado via MCP)** — VARIAÇÕES DE GOLPE por contexto: `Ability.Variants = { OnDowned | Chain |
Falling | Air | Sprint = Effect }` (Chain = Effect ou `{ [IdAnterior] = Effect, ["*"] = Effect }`, janela 2 s); o
`AbilityService.pickVariant` escolhe nessa prioridade (caído na frente ≤ 9 studs → emendado → caindo → no ar → correndo),
mesmo Id/cooldown; fase `variant` no cliente = etiqueta (AÉREO/MERGULHO/EM CORRIDA/NO CHÃO/COMBO) + VFX
`<Id>_<Variante>` se a arte fizer. Variantes nos kits: Jotaro Soco Estrela (Sprint, Chain após Arremesso) e Pancada
(Falling = meteoro, OnDowned = esmaga); Dio Facas (Air = 5 em leque, Chain após MUDA) e Golpe Vampírico (OnDowned = cura
dobrada); Kira Moeda Bomba (Air ×3) e Detonação (Chain após Toque); Bruno Rasteira (Sprint = deslizante) e Lâmina (Air ×2);
Rick Bomba de Neutrinos (Falling = embaixo de si, Sprint = mais longe). TESTAR: sentir cada variação e ver a etiqueta;
ajustar números; pedir à arte VFX "<Id>_<Variante>" onde valer a pena.
**D1 FEITO (25/09, SEM teste no Studio)** — ANTI 2v1 "Revide": `CounterService` (novo) escuta `HealthService.Damaged`;
2+ lutadores distintos acertando o mesmo alvo em 6 s = "desvantagem" → barra carrega 2,5×dano (cheia em 100). Atributos
replicados `CounterCharge`/`CounterReadyAt`; HUD = barra vermelha fina sob a da ult (só aparece com carga; cheia pulsa
"REVIDE — E"); celular = botão REVIDE (só visível cheia); `Controls.Counter` = E / L3. `RequestCounter` → servidor
valida (cheia, vivo, sem stun DURO/ragdoll/agarrão/cutscene/Domínio; hitstun de soco NÃO impede — é a fuga), tira o
hitstun, i-frames + super armor 0,6 s, `NotifyAbility("Shared","Counter")` (clipe `Shared/Counter` = giro 360° com
braços abertos; VFX `Shared/Counter` = estalo + onda vermelha), 0,18 s depois acerta TODOS a 12 studs quebrando block
(25 de dano + knockback/ragdoll 1,5 s); 20 s de recarga. E com ProximityPrompt na tela NÃO dispara (prompt vem primeiro).
Bots revidam também (`BotService.think`). Config: `CombatConfig.Counter`. TESTAR: DEV → BOTS 2 agressivos batendo em
você → barra aparece e enche → E → todos voam; conferir que E perto do vendedor/altar/NPC continua abrindo o prompt;
bot cercado por 2 jogadores revida; a barra some ~6 s depois de ficar 1v1.
**D4 FEITO (25/09, sem teste)** — LOG DE ATUALIZAÇÃO: `UpdateLogConfig` (versões 1.0/1.1 de exemplo, `Current`),
`UpdateLogService` (versão publicada em DataStore `UpdateLog_v1` + MessagingService `SahurUpdateLog`; ao carregar o
perfil, se publicada ≠ `profile.lastUpdateSeen` (schema 4) manda `NotifyUpdateLog`; `RequestUpdateSeen` grava;
`FetchUpdateLog` lista), `UpdateLogController` + `UpdateLogGui` (tela "Novidades" centrada, tween curto, sem som,
botão "versões anteriores"), item **Config → Novidades** na topbar, botão DEV (aba ADM) "PUBLICAR novidades" (pede 2º
clique). TESTAR: (1) DEV → PUBLICAR novidades → a tela abre para todos online (~2 s); fechar e reentrar = não abre de
novo (em Studio/servidor privado o perfil não salva, então pode reabrir — esperado); (2) Config → Novidades reabre e
"versões anteriores" alterna 1.1/1.0; (3) subir `Current` para "1.2" com uma entrada nova e publicar de novo.
**C0 FEITO (25/09, sem teste)** — história com arco do adryan: 10 capítulos (`cap2b` "Um favor para o adryan" — ele paga
demais para você manter o mapa ocupado longe da cachoeira; `cap4b` "Pegadas na lama" com o Toduro; falas de LRY/Ravy/
approx_verde/RIP_ACE plantando a desconfiança; final referencia o favor). Progresso migra por Id (`migrateChapter`
no ProfileLoaded: capítulo atual = 1º não entregue); NPC com vários capítulos responde certo. NPCs dos devs agora
SEMPRE R6 pela HumanoidDescription do membro (roupa clássica + acessórios rígidos; escalas zeradas) e marcador "!"
a 2,4 studs da cabeça, AlwaysOnTop. TESTAR: falar com cada NPC na ordem (Taberna → Praça → Cachoeira → Lojinha →
Cachoeira → Praça → Zigurate → Mercado → Santuário → Cachoeira), roupas/posição/"!" de cada um; DEV `SetQuestChapter`.
**25/09 (dono fora do PC, editando o mapa em levas)**: o dono editou a TABERNA e o entorno à mão no Studio. Salvo:
(1) 6 rochas da muralha leste (`Sahur.Arena.Walls.Rocks`) redimensionadas → gravadas no `Arena.rbxm` via
`sincronizar_arena.luau`; (2) `ArenaExtras` conferido com `tools/comparar_extras.py` (novo): nada criado/apagado,
só desvios de ±0,1 stud em tijolos/plantas geradas (física do modo Run) — NÃO gravar no JSON gerado; (3) tudo fora de
`Workspace.Sahur` (Taberna, Moveis taverna, cav, Lojinha, casas, árvores; 1469 instâncias) tem BACKUP em
`backups/workspace_dono_2026-09-25.{jsonl,rbxm}` (`tools/restaurar_workspace.luau`; 36 uniões viram placeholder);
(4) `tools/montar_taberna.luau` TRAVADO (`_G.RECRIAR_TABERNA`) para nunca apagar a edição dele. O dono vai
continuar editando: AO VOLTAR, repetir (1)–(3) antes de qualquer Play/regeneração (dump da Arena pelo trecho do
`sincronizar_arena.luau`; dump do Workspace pelo trecho JSONL — ambos rodam pelo MCP e caem em arquivo).
Feito hoje (23/09): bloco E fechado (traidor + mods de asset), REFATORAÇÃO do combate para lutadores não-Player
(`Combatant.Fighter`), `BotService` (bots com combate real), `TrailerService` v2 (cenas), e as correções A1–A5 da
lista do dono (DEV com ON/OFF, cenas predefinidas, agarrão trava quem está preso, boss/traidor à solta, trailer com
órbita de grupo + bug do "deitado duro"). **Intocável** no agarrão/ult (pedido do dono). O dono ainda NÃO testou
A1–A5 nem o "intocável".
**24/09: A6 FEITO** — traidor v2 = BOT ESPECIAL (`TraitorService` só monta o bot via `BotService.Spawn` e cuida de
fase 2/ult/abandono/crédito): kit completo do `QuestConfig.Traitor.CharacterId` (Dio) com M1, dash, block, 1–3,
despertar + ULT; vida ×4 (400), dano ×1,5 (atributo `DamageMult` no Model, lido no `CombatService.ResolveHit`),
walk 26 (> sprint), ult cheia na entrada e a cada 40 s, fase 2 = walk 30 e dano ×1,8; `SpawnOptions.Attributes`/
`Tuning` e `BotService.Remove` novos. Testado via MCP (Play): despertou, usou Quake/ShieldBash, ragdollou o
jogador, crédito e limpeza OK. Conta como bot no DEV (BOTS → limpar também some com ele).
**B1 ENTREGUE (24/09)**: `PESQUISA_KITS.md` — kits 4+R+4 para Jotaro/Bruno/Dio/Kira/Rick (+Sahur/Overlord), só 4 tipos
novos no total (`Buff`, `Mark`, `Homing`, `Rewind`), animações PROC/PACK/ARTE marcadas, 4 perguntas no fim para o
dono. **DECISÕES DO DONO (24/09, no chat)**: kits da pesquisa APROVADOS como estão; Parada do Tempo no Dio (5 s) E no
Jotaro (2,5 s), só despertos; Stands = NUNCA modelo, só aura/silhueta de luz atrás do jogador (na cutscene e nas
rajadas ORA/MUDA); roster = Jotaro, Bruno, Dio, Kira, Rick (Sahur sai da seleção, Overlord só admin); kit desperto
entra PRONTO e os normais voltam com o cooldown que tinham; duração/buffs da ult POR PERSONAGEM
(`Ultimate.Duration/DamageMultiplier/SpeedMultiplier`); variantes D2 só preparadas no esquema (`Variants`).
**B2+B3 FEITOS (24/09, SEM teste no Studio — estava fechado)**: `CharacterDefs` novo (`Abilities` 4 / `Passive` R /
`Ultimate` / `AwakenedAbilities` 4; `GetAbility(id, slot, awakened)`, slot 5 = R, `FindAbility` acha despertos,
R, Piscar, "Ultimate" e "<Id>_Then"); `AbilityService`: R, kit desperto por Id, `Ultimate.Effect` sozinho no fim da
cutscene (Bruno = cúpula), `Then` encadeado, tipos novos `Buff` (DamageBuff = alias, Speed, DashCooldownMult), `Mark`
(detona no M1 do dono ou sozinho), `Homing` (bomba que persegue), `Rewind` (Bites the Dust), `Projectile`
Count/Spread/Interval/AreaRadius, `Heal.Cleanse`, `Teleport.Backward`, `TimeDome.NoBreak` (Parada do Tempo =
SlowMultiplier 0,02); HUD com 5 slots (1–4 + R; desperto pinta os 4 com a cor do personagem; cooldown por Id), G =
nome da ult do `AwakeningDefs`; tecla R / D-pad ← / botão R no celular; bots usam R e o kit desperto; trailer
`abilities` mostra 1–4+R e `ult` os 4 despertos; `ModRegistry` valida o esquema novo e migra o antigo (EnergyCost
100 → 1º golpe desperto); aliases de VFX (`VFXLibrary`) e clipes (`ProcAnimDefs`) para todos os ids novos;
`Animations.model.json` copia os ids publicados equivalentes (Swift/Ultimate, Jotaro/StarImpact, Dio/RoyalKnee…).
**B4 FEITO (24/09, sem teste)**: `StandSilhouette` (Shared/Modules, só cliente) = silhueta R6 de peças neon
translúcidas com a cor do personagem flutuando atrás do ombro; `AwakeningDefs.Stand = true` (Jotaro/Dio/Kira);
aparece do estouro da cutscene até 1,5 s depois dela e, nas rajadas (MultiHitArea com Offset = ORA/MUDA), com os
braços socando pelo tempo da rajada.
**25/09 — TESTE VIA MCP DOS KITS (bots, servidor)**: Jotaro/Bruno/Dio/Kira/Rick usaram 1–4, R, despertar (cutscene
7 s + duração por personagem) e os 4 despertos SEM erro de servidor. Corrigido: (1) `MultiHitArea` ignorava o `Offset`
(ORA/MUDA acertava só em volta do corpo — alvo a 8 studs não levava nada); (2) rajada empurrava no 1º tick e acertava
2 de 12 → agora hitstun segura o alvo e o empurrão/ragdoll fica só no ÚLTIMO golpe (6/6 e 12/12 no teste).
Falta o dono ver VISUAL/HUD/silhueta (lista abaixo). Bug do mouse no Studio RESOLVIDO: era `Workspace.Camera`
com `CameraType = Scriptable` deixado pelo Play (não Wine/plugin) — se o botão direito travar de novo, Command Bar:
`workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed`. O erro `cloud_122070500639295.Script:3596 Out of local
registers` é de um plugin instalado, não do jogo.
**Pedidos do dono (25/09, fim da sessão) — fazer ANTES de C/D:**
- **B5 — Stand "bem feito"**: só aura/contorno parado ficou estranho. O rig da silhueta (`StandSilhouette`, peças R6
  neon) precisa de ANIMAÇÃO de verdade: pose idle flutuando com respiração/braços cruzados, entrada (surge de trás do
  ombro com escala/fade), rajada com os braços socando alternados em ritmo (ORA/MUDA) + tronco inclinado, saída
  (dissolve). Usar `RigPose`/`ProcAnimDefs` (animação procedural, como o resto) — clipes `Stand_Idle`, `Stand_Punch`,
  `Stand_Enter/Exit` — e o Stand deve SEGUIR o jogador com suavização (não colado ao HRP). Por personagem: cor +
  proporção (Star Platinum musculoso, The World, Killer Queen). Sem modelo externo (decisão mantida).
- **Skin de cada personagem** ("virar o personagem"): JÁ previsto — setting `CharacterModel` faz nascer com o rig da
  arte em `ServerStorage.CharacterModels.<Id>` (`CharacterService`, linha ~101). Falta a arte entregar os modelos
  (Jotaro/Bruno/Dio/Kira/Rick) e o dono testar o toggle; anotar como item de teste.
- **Bug do mouse no Studio VOLTOU** (25/09, com a `Workspace.Camera` já em `Fixed`): a hipótese "Camera Scriptable" não
  explica sozinha — o que destravou da 1ª vez pode ter sido o TOGGLE `Scriptable → Fixed` (reinicializa o controle da
  câmera). Sempre acontece nesta place depois de um Play. Próximos passos: (1) repetir o toggle via MCP e ver se
  destrava; (2) se sim, procurar no cliente quem mexe em `workspace.CurrentCamera` sem restaurar ao parar o Play
  (`CutsceneController`, `TrailerController`, seleção de personagem, `CharacterSelect`); (3) se não, testar com os
  plugins desligados (RigEdit/Moon Animator/Kojo) e por fim sessão X11.
**B5 FEITO (sessão seguinte, testado só a geometria via MCP em modo edição)**: `StandSilhouette` virou rig PROCEDURAL —
cinemática direta R6 (mesmas convenções do `RigPose`) em cima dos clipes novos `Stand/Idle` (flutua respirando,
braços cruzados, pernas soltas), `Stand/Enter` (surge encolhido de trás do ombro: escala Back.Out + fade),
`Stand/Punch` (2 socos por volta, velocidade casada com o `Interval` da rajada, tronco inclinado e girando, pernas
para trás) e `Stand/Exit` (dissolve subindo) em `ProcAnimDefs` (+ `ProcAnimDefs.Sample(clip, t)` exportado). Segue
o jogador com suavização (posição 9/s, rotação 6/s) e inclina na direção do movimento. Na RAJADA a âncora muda para
o LADO DIREITO um pouco à frente (`PUNCH_ANCHOR`), senão o Stand socava as costas do jogador. Proporção por
personagem em `AwakeningDefs.Stand` (agora tabela `StandStyle`: Scale/Torso/Arms/Legs/Head/Ears/Anchor): Star
Platinum parrudo (1.35, tronco 1.25, braços 1.3), The World alto (1.4, pernas 1.1), Killer Queen esguio com orelhas.
Screenshots no Studio (dummy R6 + `run_code`) conferiram cabeça/tronco/braços/pernas e a saída. FALTA o dono ver em
jogo (cutscene + rajada com o personagem andando).
PRÓXIMO PASSO = **dono testa o visual no Studio** (lista abaixo; item 8 = Stand animado) → C/D.

**TESTES DO REDESIGN (dono, com o Studio aberto)**
1. Jotaro: 1 Rajada ORA (cone à frente), 2 Arremesso, 3 Soco Estrela (dash com hit), 4 Pancada; R = Postura
   (escudo + veloc.). G com a barra cheia → cutscene → slots viram ORA ORA ORA / Parada do Tempo / Soco Máximo /
   Impacto; 2 congela quem está perto por 2,5 s (1× por despertar).
2. Bruno: Q Piscar; 3 Corte Cruzado = pisca e corta; R Aceleração (Piscar recarrega 2× mais rápido). G → a cúpula
   do tempo abre SOZINHA no fim da cutscene (14 s) e os 4 viram Mil Cortes / Lâminas Gêmeas / Corte Fantasma /
   Quebra do Tempo.
3. Dio: 2 Facas ×3 em leque; 3 Golpe Vampírico cura; 4 Joelhada; R Sangue Frio. Desperto: 2 Parada do Tempo 5 s,
   3 Chuva de Facas ×6, 4 ROLO COMPRESSOR (área à frente com atraso).
4. Kira: 1 Toque da Bomba marca (VFX na vítima) → seu próximo M1 nela explode (ou sozinho em 4 s); 3 Sheer Heart
   Attack (peça no chão persegue e explode); R Mãos Limpas (pisca para trás + cura). Desperto: 4 BITES THE DUST =
   4 s depois você volta para onde estava com a vida de antes e explode.
5. Rick: 1 laser, 2 portal, 3 drone (persegue + stun), 4 bomba; R Kit Médico tira stun/ragdoll. Desperto: 3 =
   Mergulho Prime (a ult antiga).
6. HUD: 5 slots (R no 5º), cooldowns certos ao despertar/voltar; celular tem botão R; cartão da seleção mostra
   1–4, R e G. Bots (DEV → BOTS) usam R e despertam; trailer `abilities`/`ult`.
7. Mods: o mod [TESTE] antigo (EnergyCost 100) ainda carrega (ult vira 1º golpe desperto).
8. Stand ANIMADO (Jotaro/Dio/Kira): entra de trás do ombro no estouro da cutscene, flutua respirando de braços
   cruzados e SEGUE o jogador (andar/dash: deve ficar levemente atrasado, sem tremer); nas rajadas ORA/MUDA vai para
   o lado direito à frente e soca no ritmo dos hits; some dissolvendo. Ajustes: proporção/cor em
   `AwakeningDefs.Stand`, âncoras `DEFAULT_ANCHOR`/`PUNCH_ANCHOR`, poses em `ProcAnimDefs` "Stand/*".
Dono avisou (24/09): vai editar o mapa (Taberna/construções) no Studio; ao voltar, SINCRONIZAR antes de qualquer
Play/fechar (`tools/sincronizar_arena.luau` para peças da arena; Taberna = ler pelo MCP e gravar em
`tools/montar_taberna.luau`). Bug do botão direito da câmera no Studio (edição) = ambiente Wine/XWayland,
RESOLVIDO 25/09: era a `Workspace.Camera` em `Scriptable` deixada pelo Play — ver bloco "TESTE VIA MCP". Novas anotações do dono (noite): anti-2v1 na tecla E, variações de
golpe estilo Jujutsu Shenanigans, evento de admin "último de pé", log de atualização no jogo — ver "D" abaixo.

**D — Ideias novas do dono (2026-09-23 noite) — anotadas, ordenar junto com B**
D1. ANTI 2v1 (tecla E): quando 2+ jogadores batem no mesmo alvo, o alvo sozinho carrega uma barra própria; cheia,
    E (se a tecla estiver livre) dispara um contra-ataque que acerta TODOS os agressores de uma vez (+ variações).
    Servidor: contador de agressores distintos numa janela (ex.: 6 s) por vítima; barra = dano recebido enquanto
    em desvantagem; HUD com a barra; ataque em área/varredura 360° com knockback; anim/VFX próprios.
D2. VARIAÇÕES DE GOLPE (estilo "Jujutsu Shenanigans"): a maioria dos ataques muda conforme o contexto — emendado
    com outro ataque (combo de habilidades), no pulo (aéreo), caindo de altura (mergulho), correndo, contra alvo
    caído/ragdoll, etc. Entra no esquema do redesign B2 (cada Ability com `Variants = { Air, Falling, Sprint,
    Chain = <AbilityId>, OnDowned }`), servidor decide a variante pelo estado (airState, velocidade, último golpe).
D3. EVENTO DE ADMIN "ÚLTIMO DE PÉ": o admin abre um torneio de eliminação — todos lutam (1v1 / grupos / clãs),
    quem morre sai (fica de espectador/lobby), até sobrar o último jogador/grupo/clã; prêmio especial (pontos/
    cosmético agora; Robux/payout futuramente). Reaproveita MatchService (rounds) + EventService + arena; painel
    DEV: abrir/fechar inscrição, iniciar, modo (solo/duo/clã), prêmio.
D4. LOG DE ATUALIZAÇÃO no jogo: mensagem/animação de "novidades" a cada atualização grande — o dev prepara o texto
    (versão + lista) num config (`UpdateLogConfig`), escolhe QUANDO ativar (DEV "Publicar novidades"), e cada
    jogador vê uma vez (flag no perfil por versão) uma tela animada; botão "Novidades" no menu para rever.


### SEQUÊNCIA NOVA (dono, 2026-09-23 noite — depois de testar bots/trailer) — seguir NESTA ORDEM
Relato do dono: botões do DEV sem feedback de ativo/inativo; traidor fraco (sem ult, não comba) — tem que ser mais
OP que o Big C.H.O.P.; boss e traidor presos na cachoeira (voltam quando não há player, não perseguem para fora);
bots e traidor batem enquanto estão presos no agarrão; "CENA" digitada na aba Adm é ruim → predefinições;
trailer caótico (muita gente no início, saem do quadro, golpes derrubam sem ragdoll e o boneco "buga duro");
REDESIGN das habilidades: 1/2/3/4 = 4 ataques sem ult, R = 1 passiva/suporte, G = ult troca os 4 por outros 4 até
acabar; tirar ults/animações/ataques sem sentido; pesquisar kits coerentes por personagem; STANDS dos personagens
de JoJo aparecem na animação da ult.

**A — Correções do que foi entregue (curtas, uma por commit)** — A1..A5 FEITOS em 23/09 (commits bcc2c8a, fd8a5ea,
cd0af36, f8d5f7a, b00ca5c + 810695d "intocável"); A6 FEITO em 24/09. Falta o dono testar tudo.
A1. DEV: todo botão de toggle mostra ON/OFF (cor + contorno) pelo `GetState`; botões de ação dão "flash" ao
    clicar; bots/traidor/trailer com estado (ex.: "TRAILER rodando", "N bots"). Hoje só God/Energia/Cooldown/Voar.
A2. DEV: "CENA" vira PREDEFINIÇÕES (aba Teste → TRAILER): botões Combo · Parry · Dash · Habilidades (por
    personagem) · Ult (por personagem) · Boss · Briga · Completo, + toggle "comigo na cena". Some a caixa de texto.
A3. AGARRÃO: quem está preso (bot, traidor, boss, jogador) NÃO age até soltar — `Stun("grabbed")` também para NPC
    (atributo `Grabbed` no Model; `NpcPunch`/IA do traidor/boss respeitam), e bot cancela o soco em curso ao ser
    agarrado. Conferir também o block/parry durante o agarrão.
A4. BOSS e TRAIDOR à solta: perseguem pelo mapa inteiro (raio 300 como o `Roam`), sem voltar ao centro enquanto
    houver alvo; só somem/voltam após X s sem ninguém. `Traitor.ArenaRadius`/`BossConfig.ArenaRadius` viram só o
    raio inicial. Boss automático continua nascendo no santuário mas sai atrás de quem bater nele.
A5. TRAILER: `brawl` com 3–4 bots (não 6) e câmera que enquadra o grupo (orbit do centro dos bots, ou "follow" do
    ator principal); palco longe de obstáculos; cenas mais curtas; investigar "derrubado sem ragdoll fica travado"
    (ComboLift/Knockback sem Ragdoll em bot → checar PlatformStand/estado do Humanoid) e corrigir no núcleo.
A6. TRAIDOR v2 = BOT ESPECIAL: `TraitorService` passa a usar `BotService.Spawn` (aggressive, sem respawn) com
    vida ×4, dano ×1,5, velocidade +, kit completo + ULT (usa o kit do personagem escolhido para ele; após o
    redesign B, kit próprio), aura/luz vermelha, crédito de `traitor_kill` igual. Mais OP que o Big C.H.O.P.

**B — REDESIGN das habilidades (grande; pesquisa → aprovação do dono → implementação)**
B1. PESQUISA (entregar lista para o dono aprovar antes de codar): para Jotaro, Bruno Gollini (Swift), Dio, Kira,
    Rick (+ Sahur/Overlord se ficarem): 4 ataques normais, 1 passiva/suporte (R), ult (nome, Stand que aparece,
    o que muda) e os 4 ataques da forma desperta — tudo reproduzível com os tipos de efeito que existem
    (Dash/Grab/Teleport/AreaDamage/MultiHitArea/Projectile/DamageBuff/Heal/Shield/FlyGrab/TimeDome) ou com no
    máximo 1–2 tipos novos por personagem; animações: quais dos packs servem, quais a arte precisa fazer.
B2. Esquema: `CharacterDefs` → `Abilities` (4, sem ult), `Passive` (R: efeito de suporte com cooldown),
    `Ultimate` (G: nome + Stand + duração) e `AwakenedAbilities` (4; substituem 1–4 enquanto desperto).
    Remover kits/ults/animações sem sentido; migrar mods/exemplo_mod e o kit (MODS_KIT/templates).
B3. Servidor: `AbilityService` (troca de kit ao despertar e volta ao fim; R com cooldown próprio; ult não ocupa
    slot), HUD (5 slots: 1–4 + R; visual de troca na ult), `AbilityController` (tecla R, Controls), IA dos bots
    (usa R e o kit desperto), trailer (cena `abilities` mostra 1–4 + R; `ult` mostra o kit desperto).
B4. STANDS: modelo do Stand (arte ou peças) aparece atrás do personagem só na animação da ult (cutscene +
    golpes despertos); `AwakeningDefs` por personagem; VFX/sons.

**C0 — HISTÓRIA e NPCs (dono, 2026-09-23 noite — anotado, fazer depois de A)**
- História "ruinzinha e incompleta" (tester: "por que o adryan é traidor se nem tivemos missão/contexto com ele
  antes?"). AUMENTAR: mais capítulos/contexto com o adryan antes da traição (pistas em capítulos anteriores, falas
  dos outros devs desconfiando, um capítulo com ele "ajudando" que depois se revela armadilha), textos/recompensas.
- NPCs dos devs "bugados": roupas do avatar não aparecem em alguns (CreateHumanoidModelFromUserId sem os
  acessórios/roupas carregados? conferir Shirt/Pants/Accessory vs. rig R6/R15), marcador "!" longe da cabeça em
  alguns (Adornee/StudsOffset por altura do rig), posições estranhas (talvez falta de âncora/colisão; hoje ancorado
  e CanCollide=false). CORRIGIR UM POR UM, com perguntas individuais ao dono sobre cada NPC (lugar, pose, fala).

- (dono, 2026-09-23) Painel Mods SEM tutorial de criação: entra junto com a place de criação (C2) — aba "Criar
  mod" no painel com passo a passo, link da place e da comunidade do grupo. NUNCA escrever "Discord" em texto do
  jogo (Roblox bloqueia/modera) — usar "comunidade do grupo"/"link na página do jogo". Já trocado no painel.

**C — Backlog anterior (continua valendo, depois de A e B)**
C1. Lista de testes do dono (blocos A–F de 21/22-09 + capítulo final + mods de asset + bots/trailer).
C2. Place de criação da comunidade (item 2 abaixo). C3. Mural de votação de mods (item 3). C4. Textos/recompensas
das quests, `Function`/`Quote` do TeamConfig. C5. Salvar o place (AltarGruta backup, exemplo_mod).

### PRÓXIMA SESSÃO — por onde começar (lista antiga; a ordem nova está acima)
0. **Bots + trailer v2 (2026-09-23 tarde)**: o dono já testou → ver "SEQUÊNCIA NOVA" acima.
1. **O dono testa TUDO** e traz a lista do que mudar/adicionar/corrigir/tirar. Corrigir isso primeiro.
   O que está sem teste dele (listas "FALTA o dono testar" nas seções abaixo): BLOCO A combate (2026-09-21),
   muralha/destruição/roster (2026-09-21), os blocos de 2026-09-22 (F boss x3 à solta, D menu DEV em abas,
   B jardim v2, C construções v2, E quests + mods, input buffer do M1) e o de 2026-09-23 (capítulo final com o
   TRAIDOR, NPCs no chão, loaders de mods de asset + mod de exemplo `[TESTE]` no painel Config → Mods).

### Sessão 2026-09-23 (tarde) — COMBATE PARA BOTS (refatoração do núcleo) + BotService + TRAILER v2 real
Pedido do dono: refazer o trailer (o antigo era encenado: NPCs parados + eventos falsos) e poder DEMONSTRAR
ataques/ults "em medida de testes". Decisão do dono: **refatorar o núcleo** para bots com habilidades REAIS
(em vez de autopilot no cliente); bots por padrão **só revidam quando apanham**.
- **`Combatant.luau`** (shared): `Fighter = Player | Model de bot` (atributo `Bot`, `BotUserId` negativo, `Npc`).
  `Of(character)`, `CharacterOf`, `PlayerOf`, `IsPresent`, `UserId`, `ByUserId`, `Notify` (FireClient só p/ Player),
  `All()` (jogadores + bots).
- **Refatoração** (`HealthService`, `RagdollService`, `CombatService`, `MovementService`, `AbilityService`, +`RateLimiter`):
  estado por `Instance` (Player ou Model), `player.Character` → `Combatant.CharacterOf`, `GetPlayerFromCharacter` →
  `Combatant.Of`, FireClient/AntiExploit/Progression/DataStore só quando há Player. Novidades: `HealthService.SetupBot`,
  `HealthService.FighterDied` (qualquer lutador; `Died` continua só p/ jogador e killer bot = nil), `RagdollService`
  unificado (RagdollModel/IsModelRagdolled redirecionam para o lutador), `MovementService.Dash/Sprint/ServerDash`
  (bot: LinearVelocity no servidor — mesma receita do cliente), `CombatService.Attack/Block` (mesmo caminho do clique/F),
  `CombatService.NpcHitHook`, `AbilityService.Awaken/SetEnergy/GetEnergy/IsBusy`; investida/agarrão/voo do Rick de bot
  movidos pelo servidor; TimeDome/despertar consideram bots. Cliente: `MovementController`/`CombatController` leem
  `CharacterId`/`AwakenedUntil` do Model quando é bot. Regressão do jogador testada via MCP (M1, hab., dash 27 studs).
- **`BotService`**: bot = rig R6 com avatar da equipe (roda `TeamConfig`), tag `Bot`+`Combatant`, grupo de colisão
  `Players`, direto no Workspace (ProcAnim anima). IA (0,1 s): `passive` (padrão: revida contra quem bateu por 12 s),
  `aggressive` (caça o mais perto em 70 studs — jogadores, bots e boss/traidor), `idle`. Faz: combo M1, dash (12–40
  studs), block quando o alvo ataca, habilidades 1–3 prontas no alcance, despertar com carga cheia + ULT perto,
  ragdoll cancel, respawn no ponto de origem. `Spawn(opts{CharacterId,Name,UserId,CFrame,Behavior,Respawn,Team})`,
  `Clear`, `SetBehavior`, `Fill` (ult carregada), `Provoke`, `List/Count`. Times: `TeamId` (sem fogo amigo).
  Boss e traidor caçam/batem em bots (`Combatant.All`); loot do boss só para Players.
- **DEV** (Mapa → BOTS): caixa `BotCharacter` + "Bot: só revida" / "Bot: agressivo" / "Bot: parado", "Encher ult dos
  bots", "Todos: só revidam/agressivos/parados", "Remover bots". Bots nascem 12 studs à sua frente, lado a lado.
- **TRAILER v2** (`TrailerService` reescrito): cenas com bots reais, cada uma rodável sozinha —
  `brawl` (6 bots em 2 times na praça), `combo`, `parry` (block coreografado antes do golpe → parry → crítico → 2º
  parry → BLACK FLASH), `dash` (hit de chegada, distância = alcance real), `abilities [id]` (1..3 com cartela do nome),
  `ult [id]` (Fill → Awaken → câmera orbita/corta no estouro → ult), `boss` (BossService.Summon real + 3 bots), `all`
  (~95 s, cartela final + fade). "me" no argumento = você fica na cena. DEV: Teste → "TRAILER (~95 s)" e "CENA"
  (texto na caixa Mensagem da aba Adm, ex.: `ult Kira`, `combo me`). Câmera/cartelas: `TrailerController` (igual).
- Testes MCP: cada cena rodou com logs reais (parry/crit/blackflash, dash hit 4, Meteor 58,5, boss 1500→1476 com
  bots ragdollados). Cliente sem erro.
- **FALTA o dono testar (visual!)**: Config → Dev → Mapa → criar 2 bots agressivos e ver a luta (animações, VFX,
  dash, ult com cutscene vista de fora); bater num bot passivo e ver ele revidar; Teste → TRAILER e gravar; cada
  CENA; verificar câmera/cartelas e se algum golpe ficou feio (ajustar tempos em `TrailerService.scenes`).

### Sessão 2026-09-23 — BLOCO E fechado: capítulo FINAL (traidor) + loaders de mods de asset
Decisões do dono (2026-09-23): traidor = **adryan_keep**; luta = chefe no SANTUÁRIO (NPC hostil com o avatar
dele); outros jogadores podem ajudar (crédito para quem deu dano e está no capítulo final).
- **`QuestConfig`**: `Traitor` (UserId, vida ×3, WalkSpeed 20/24 na fase 2, ArenaRadius 45 em `BossArena`,
  AbandonSeconds 60, Punch 6, Dash, Burst raio 10/dano 14/knockback+ragdoll, Regen) e capítulo `final` DESTRANCADO:
  aceita com o adryan_keep na cachoeira (`NpcUserId`), objetivo `traitor_kill`, entrega com o Humanoider_20 na
  Taberna (**`DeliverNpcUserId`**, campo novo), recompensa 1000 EP + 1000 pts + 1500 XP. Fala do cap. 7 aponta
  para a cachoeira. Textos PROVISÓRIOS.
- **`TraitorService`** (novo): rig R6 com o avatar real (GetHumanoidDescriptionFromUserId), física/ragdoll como o
  boneco (atributo Npc, tag Combatant), Highlight vermelho + luz, direto no Workspace (ProcAnim anima). IA 0,1 s:
  alvo mais perto na arena, MoveTo, combo de 4 socos (`CombatService.NpcPunch`), dash em arco quando longe,
  rajada com anel de aviso; fase 2 na metade da vida; some sem crédito após 60 s sem ninguém; morte → ragdoll,
  fade, `traitor_kill` para quem deu dano e está no `final`. Um por servidor; `Summon/Kill/Despawn/IsActive`.
  Toasts via `NotifyQuest "toast"` (evento novo no QuestController).
- **`QuestService`**: `OnTalk(fn)` (accept/progress/done), `IsActiveOn`, `SetChapter` (DEV), `delivererOf`
  (chip/toast apontam para quem recebe a entrega), entrega com NPC diferente; o traidor responde "vai contar
  para o Humanoider_20" e nunca entrega. **NPCs apoiados pela parte MAIS BAIXA do rig** (R6 afundava 3,5 studs
  porque HipHeight = 0; RIP_ACE R15 escalado flutuava 3,2) — os 7 ficaram a 0,05 do chão; **1 NPC por membro**
  (cap. 4 e final usam o mesmo adryan_keep; antes nasciam 2); LRY no tapete da Lojinha (VendedorSpot −6/+6,
  olhando para onde o vendedor olha; antes ficava em cima de um vaso e depois no toldo).
- **DEV** (aba Mapa → HISTÓRIA / TRAIDOR): `SetQuestChapter {n}` (por alvo; 8 = final, 9 = zerada),
  `SummonTraitor`, `KillTraitor`, `DespawnTraitor`.
- **Loaders de mods de asset** (`ModRegistry.luau` novo, compartilhado): `ModService` clona `ServerStorage.Mods.<Id>`
  para `ReplicatedStorage.ModsActive.<Id>` (Map → `Workspace.ModMaps.<Id>`); o registry injeta `CharacterDef` em
  `CharacterDefs` (+Order), `Cosmetics` em `CosmeticsConfig` (Free, sem preço), `VFX` na `VFXLibrary` (só chaves
  novas), e no servidor copia `Animations/Sounds/VFX` para `ReplicatedStorage.Assets`; tetos do kit no load. Personagem
  de mod = todo mundo ganha (`GrantCharacter`; quem entra depois também); desligar = `AbilityService.ForceCharacter`
  (novo) devolve ao padrão + `RevokeCharacter` + tudo retirado. Cliente: `ModsController` inicia o registry; dropdown
  de personagens (Topbar, `joinDropdown`/`leave` — `setDropdown` de novo DESTRÓI os ícones) e cartões do HUD
  reagem a `ModRegistry.Changed`. **Mods de TESTE no Studio**: toda pasta `ServerStorage.Mods.<Id>` com `ModConfig`
  válido aparece no painel como `[TESTE]` sem entrar no catálogo (`payload.extra`).
- **Kit**: `tools/place_criacao/` (LEIA-ME + `Mods/exemplo_mod/` com ModConfig/CharacterDef/Cosmetics/VFX comentados);
  `ServerStorage.Mods.exemplo_mod` montado no place via MCP (personagem "Exemplo" + capa/aura esmeralda + emote +
  efeito `Exemplo/Onda`). `MODS_KIT.md` atualizado (estrutura, fluxo de teste no Studio).
- Testes MCP: capítulo 8 → falar com adryan_keep invoca o traidor no BossSpawn (300 HP), ele persegue/bate (jogador
  100→67, 2 ragdolls), morte → crédito → Humanoider_20 entrega → capítulo 9; liga/desliga do exemplo_mod 2× sem erro
  no cliente, personagem forçado usa `Exemplo.Onda`, tudo volta ao desligar.
- **FALTA o dono testar**: capítulo final de verdade (SetQuestChapter 8 → E no adryan_keep na cachoeira → entrar
  no santuário e lutar: socos/dash/rajada, fase 2, ragdoll ao morrer → E no Humanoider_20), visual do traidor (avatar,
  aura), NPCs nos pés (Praça/zigurate/Lojinha), painel Config → Mods → ligar "Exemplo [TESTE]" → V mostra o
  personagem Exemplo → habilidades 1/2/G e o efeito → K mostra capa/aura esmeralda → desligar volta ao Jotaro.
- Pendências que ficaram: textos/recompensas dos capítulos (dono), `Function`/`Quote` do `TeamConfig`, place de
  criação da comunidade (item 2) e mural de votação (item 3) — planos abaixo.
2. **PLACE DE CRIAÇÃO/TESTE para a comunidade** (pedido do dono, 2026-09-22): uma place SEPARADA, liberada para a
   comunidade criar mods/VFX/skins/etc., com QUASE NENHUM script do jogo (nada que possam copiar e reaproveitar).
   Plano: place em branco do grupo com (a) rig R6 de referência + boneco de treino simples, (b) a estrutura
   `ServerStorage.Mods.<Id>` com os ModuleScripts-template (`ModConfig`, `CharacterDef`, `Cosmetics`) vazios e
   comentados, (c) um preview mínimo de VFX/animação (script pequeno e isolado, sem VFXLibrary/FX do jogo),
   (d) o `MODS_KIT.md` como texto dentro da place, (e) NENHUM Service/Controller/Config do jogo. Montar via
   MCP numa place nova (não é este repo; só as ferramentas/templates podem ficar em `tools/place_criacao/`).
3. **MURAL DE VOTAÇÃO de mods** (ideia do dono, 2026-09-22 — é permitido pela Roblox: asset publicado pelo grupo,
   voto GRÁTIS 1 por jogador por ciclo, sem sorteio/Robux no voto, conteúdo dentro das regras; pagar criador só
   por payout do grupo). Plano: `ModVoteService` com `OrderedDataStore` (chave por ciclo semana/mês), candidatos =
   fila de mods enviados/aprovados-para-votação (`ModsConfig.Candidates` ou lista no DataStore editada pelo DEV),
   1 voto por jogador por ciclo (perfil ou DataStore), aba "VOTAÇÃO" no painel Mods com ranking "mais hypados" +
   "vencedor da semana/mês"; o vencedor a equipe sobe para o jogo de verdade (skin/emote/mod, qualquer coisa da
   comunidade) com crédito. Kit deve dizer que ao enviar o autor autoriza o uso no jogo.
4. ~~Pendências do E~~ FEITAS em 2026-09-23 (ver seção abaixo). Restam textos/recompensas dos capítulos (dono).
5. O dono precisa SALVAR o place (backup do AltarGruta em ServerStorage + `ServerStorage.Mods.exemplo_mod` + sync
   do Rojo).

### Sessão 2026-09-22 — BLOCO E FEITO (v1): QUESTS (história em capítulos) + MODS de servidor privado
Decisões do dono (2026-09-22): formato A (linha de capítulos; final = lutar contra um dev TRAIDOR, a escolher);
quests/mini-games envolvem o battlegrounds; NPCs = membros do grupo FX_Bacons; mural das quests na Taberna +
mural SÓ dos devs com agradecimento; mods: comunidade cria numa place de criação (kit), manda pelo Discord,
equipe confere lista exigente e sobe; só o dono do servidor privado escolhe; em servidor privado NADA salva;
painel MODS em Config só em servidor privado e sempre para ADMs.
- **`TeamConfig.luau`** (gerado por `tools/atualizar_equipe.py` da API pública do grupo 9835819): 7 membros —
  Humanoider_20 e ToduroDemais (Owner), adryan_keep, LRY, Ravy (Admin), approx_verde, RIP_ACE (Membro).
  `Function`/`Quote` editáveis à mão (preservados por UserId ao regerar).
- **`QuestConfig.luau`**: 7 capítulos (1 por membro) + `final` trancado ("O traidor"). Objetivos por contador:
  kills, parries (NOVO no CombatService), bricks (NOVO no DestructionService), streak (máx., atributo KillStreak),
  duel_wins, boss_kills, visit_<Spot>. Spots: Taberna, Praça, Lojinha (ao lado do vendedor), Cachoeira,
  ZigurateSE (topo), MercadoNW, Santuário. Recompensas: pontos de evento + pontos + XP (+ emote no cap. 7).
  **Textos, metas, recompensas e posições são PROVISÓRIOS** (o dono ajusta).
- **`QuestService`**: NPC com o AVATAR real do membro (`CreateHumanoidModelFromUserId`, fallback R6), ancorado,
  prompt E "Falar", marcador "!"; fluxo aceitar → contar → entregar (só o NPC do capítulo atual; os outros
  apontam o certo); `profile.quests` (chapter/active/counters/done; migração sem trocar schema);
  `AchievementService.OnProgress` (gancho novo) alimenta; visita por raio a cada 2 s; `QuestService.Talk`
  (DEV/testes). Mural das quests: `Workspace.QuestBoards.QuestBoard` (parede SUL da Taberna, z 28.7) — conteúdo
  por jogador via SurfaceGui no PlayerGui (QuestController).
- **`TeamBoardService`**: mural dos devs (`QuestBoards.TeamBoard`, parede LESTE da Taberna x 380.1 / z 114, 16×13,
  entre o pilar z 124 e a tocha z 104): headshots + nome + cargo + função + frase + AGRADECIMENTO ESPECIAL.
- **`QuestController`**: chip do capítulo (canto direito), diálogo com foto do dev, toasts de objetivo, mural.
- **MODS**: `ModsConfig.Catalog` (12 mods `rules` aprovados: vida ×2/×0,5, dano ×2, sem cooldown, só socos,
  gravidade da Lua, acelerado, noite/meio-dia eterno, todos personagens, boss a cada 10 min, cenário fixo;
  `Exclusive` por grupo). `ModService`: só liga em servidor PRIVADO ou Studio; edita = dono do privado ou dev;
  vê = todos no privado + devs sempre; aplica via atributos já lidos (DevDamageMult, DevNoCooldown, NoAbilities
  NOVO no AbilityService, ModSpeedMult NOVO no CombatService), Workspace.Gravity, SetClockOverride, MaxHealth/
  JumpPower, BossService.Summon periódico, `DestructionService.Enabled` NOVO. `ModsController`: ícone "Mods" no
  dropdown Config + painel (catálogo, autor/versão, toggle) + chip "MODS ATIVOS: nome (autor)".
  **`DataService`: em servidor privado o perfil carrega mas `sessionOnly = true` → NADA salva.**
- **`MODS_KIT.md`**: estrutura da pasta `ServerStorage.Mods.<Id>`, ficha do Discord, LISTA DE EXIGÊNCIAS (10 itens),
  como a equipe sobe um mod, painel. Loaders de `character/cosmetic/vfx/map` = estrutura pronta, código em breve.
- Testes MCP: boot 38 services; 7 NPCs nos spots com prompt; murais montados sem bater em móveis; mods ligam/
  desligam (gravidade 60, hora 22→13 pelo exclusivo, destruição off) e voltam; fluxo de quest em Play com o
  dono: aceitar → kills 5/parries 3 → entregar → capítulo 2, +150 pts +100 EP +100 XP.
- **FALTA o dono testar**: falar com o Humanoider_20 na Taberna (E), ver chip/diálogo/mural, parryar 3× e
  matar 5 (2 clientes), entregar; visual dos NPCs (avatar real carrega no Studio?), posição de cada NPC (RIP_ACE
  ficou em y 4,6 no santuário — conferir se flutua), mural dos devs na parede leste; painel Config → Mods no
  Studio (é dev): ligar "Gravidade da Lua" e "Só na mão"; num SERVIDOR PRIVADO de verdade: painel para todos,
  só o dono liga, e nada salva ao sair.

### Sessão 2026-09-22 — BLOCO C FEITO: construções JJS MAIORES e enteráveis + desabamento + golpe pesado
- `tools/arena_construcoes.py` v2: tijolo **6×3×3** (dobro do volume); **casas de 2 andares** (pé-direito 11,
  porta 6×9, janelas largas 7×6 em cada andar, laje do 1º andar em chunks de tábua destrutíveis com vão, escada
  interna de tábuas, mesa + bancos + jarros no térreo, terraço com mureta e escada externa de degraus); **2 pátios
  murados** por bairro (`courtyard`: muro de 2 fiadas com portão e pilaretes); **mercado coberto** (`covered_market`:
  colunas + cumeeira + telhado de junco em chunks) com 2 barracas dentro + 4 barracas soltas; **zigurate 44 studs**
  com **câmara interna** no 1º degrau (piso de lápis, 4 pilares, portas nas 4 faces, teto em chunks) e **rampa de
  tábuas em espiral** (um lance por degrau) até o santuário no topo (arena em altura). 7 casas por bairro (eram 9).
  Total **2760 destrutíveis** (v1: 2414) com o dobro de tamanho.
- `DestructionService`: **golpe pesado** = `MaxPerHit × HeavyMultiplier (2)` quando o atacante tem
  `HeavyHitUntil` (CombatService põe no 4º M1, 0,5 s) ou `AwakenedUntil` (despertar) no futuro;
  **desabamento** (`collapseAbove`, `CollapseMaxPerHit` 10, `CollapseDelay` 0,25 s): tijolo logo acima dos removidos
  que ficou SEM apoio embaixo cai também (só 1 nível; nada de dominó). `RestoreAll` continua repondo tudo.
- Teste MCP (run_server, Hitbox.AroundPoint com boneco): golpe normal raio 5 → 6 tijolos + 1 desabou; pesado
  raio 9 → 18; somem em 4,5 s; RestoreAll → 0 soltos.
- **FALTA o dono testar**: entrar numa casa pela porta, subir a escada interna até o 1º andar e a externa até o
  terraço (degraus de 1,5 — subida por pulo/escada), entrar na câmara do zigurate e subir a rampa até o topo,
  socar parede (6–10 tijolos) × 4º M1/ult (o dobro), ver o desabamento, FPS com 2760 peças + jardim.

### Sessão 2026-09-22 — BLOCO B FEITO: cachoeira + jardim v2 "Amazônia antiga + templos astecas" (só via MCP)
- `tools/arena_santuario.py` (parte FORA reescrita; câmara interna igual): **cachoeira em 3 patamares** de rocha
  molhada (Reflectance) saindo da muralha (y 86/68/50), lençol Glass quase opaco + espuma ForceField + cordões
  Neon em cada queda, bacia por patamar, spray por patamar, queda final até o lago (véu da entrada continua
  atravessável), lago maior, névoa/gotas mais fortes, **arco-íris** (7 arcos Neon transparentes) na névoa.
  **SOM trocado**: `72131057531506` (waterfall3_looped do pack JJS; carregou no Studio, loop de 2 s) no lugar do
  `9120386436` (0,4 s = BUZINA em loop).
- **Mata**: 10 sumaúmas (tronco cinza 26–34, raízes tabulares em wedge, copa em guarda-chuva, bromélias no
  tronco), 9 árvores médias, 22 cipós entre copas (`beam()` = cilindro entre 2 pontos, com barriga) + 8 pendurados,
  samambaias gigantes (folhas radiais), bananeiras com heliconias, troncos caídos com musgo, musgo/flores,
  **nevoeiro baixo** (`JungleFog`), vaga-lumes.
- **Templos astecas**: pirâmide de 5 degraus (30→7) em CX ± 50 / z 316 (`TempleW*`/`TempleE*`), cornijas, glifos
  coloridos na face da clareira, **escadaria** de 16 degraus descendo para o meio com corrimões e **cabeças de
  serpente emplumada** (jade, olho neon, penas), santuário no topo (altar com mancha, 4 pilares, teto com crista e
  glifos, 2 braseiros), musgo nos degraus, raízes por cima, samambaias na base. **Ruínas** tomadas pela mata em
  CX ± 40 / z 358 (muro com glifo, cabeça de serpente tombada, coluna quebrada).
- `free()` agora exclui pirâmide + escadaria (dxr −40..16 × z ±16); conferido via MCP: **0 colisões com o pinheiro
  da arte** (110, 337); templo leste começou em z 335 e batia — movido para 316. 1238 peças fixas no jardim
  (antes 1433 com a v1... a v2 tem menos por causa da exclusão maior).
- NÃO feito (opcional do plano): dar o mesmo tom (glifos/serpentes) à câmara interna. Screenshot não foi
  possível (o dono estava jogando outra coisa em tela cheia — a captura pegava o jogo dele).
- **FALTA o dono ver**: cachoeira opaca/em patamares, som (sem buzina), arco-íris discreto, mata fechada com
  cipós, subir a escadaria dos templos (16 degraus de 0,3–0,4 de altura: dá para subir andando?), altar no topo
  como ponto de luta em altura, FPS na região (~1240 peças + partículas). Se algo sobrepor a arte:
  `tools/achar_sobreposicao.luau`.

### Sessão 2026-09-22 — BLOCO D FEITO: menu DEV em abas ADM / MAPA / TESTE (boot testado via MCP)
- `tools/gerar_devgui.py` reescrito: cabeçalho + ALVO (caixa `PlayerSearch` filtra a lista por nick/display;
  1 resultado = seleciona sozinho) + estado + 3 abas (`TabAdm/TabMapa/TabTeste` → `PageAdm/PageMapa/PageTeste`)
  + RESULTADO. Painel 620×768. Nomes dos botões = comando do AdminService (nada mudou no protocolo).
  ADM: ir até/trazer/assistir/arena, mensagem ao alvo/servidor/global, entrar no servidor, kick, zerar dados, ban
  (dias) / desbanir, denúncias (alvo / por nick), DAR: pontos, pontos de evento, XP, conquistas, **item por id**
  (`GrantItem`, caixa `ItemId` — botão novo para um comando que já existia), todos cosméticos, personagens.
  MAPA: boss (invocar no santuário / **x3 À SOLTA** / **matar com loot** / remover / virar / encerrar / inspecionar),
  flecha (dar / **tirar e devolver ao mapa** / sortear), hora (congelar / dia / noite / automático), **restaurar
  cenário destrutível**, evento, bonecos, placar, info, listar, estado. TESTE: god/energia ∞/sem CD/voar, curar,
  ULT, zerar CDs, flags, respawn, ragdoll, anti-exploit, matar, energia/vida/speed/dano/streak, zerar cosméticos,
  F7, sons dos packs, trailer.
- `DevController`: `get` recursivo, abas, busca, `CONFIRM` (Kill, Kick, Ban, ResetData, ResetCosmetics, RevokeAll,
  KillBoss, DespawnBoss, EndEvent, EndBossForm, AnnounceGlobal) = 1º clique vira "Confirmar? (…)" por 3 s, 2º envia.
- `AdminService` globais novos: `SummonBossStrong` (BossService.SummonStrong x StrongPower), `KillBoss`
  (`BossService.Kill()` novo: vida 0 → derrota normal com loot), `RestoreDestructibles` (DestructionService.RestoreAll
  + Count), `TakeArrow` (RitualService.GiveArrow(nil)).
- **FALTA o dono testar**: F8 → abas, digitar parte de um nick na busca, botão vermelho pedindo 2º clique, "Invocar
  x3 À SOLTA" na aba MAPA, "Restaurar cenário" depois de quebrar casas, "Dar item" com um id de cosmético.
- Ainda NÃO feito do plano D: ban temporário já existia (dias); "entrar no servidor de um jogador" já existia.
  Denúncias em DataStore já existiam (`ReportService`). Nada ficou de fora.

### Sessão 2026-09-22 — BLOCO F FEITO: boss x3 da flecha nasce no CENTRO e anda LIVRE (testado via MCP)
- `BossConfig.Roam` (Radius 300, StepMin/Max 30/60, IdleSeconds 6, MinDistFromPlayers 15, AbandonSeconds 180).
- `BossService.summon`: `power > 1` (F no altar com a flecha / `SummonStrong`) → `roamSpawnPosition()` = média
  dos `SpawnLocation`/`Spawn*` do Workspace, raycast ao chão, afastado ≥ 15 studs de todo jogador (anel de
  candidatos); sem spawns/chão cai no santuário. Boss automático (power 1) e admin `Summon` seguem no santuário.
- `Fight.roam`: na IA o centro é a posição ATUAL do boss e o raio é `Roam.Radius` (pickTarget recebe o raio);
  sem alvo ele VAGA (`roamStep`: passo aleatório com chão, desnível < 20) e só some após `Roam.AbandonSeconds`
  sem ninguém no alcance. Boss preso (santuário) continua igual (`ArenaRadius`, volta ao centro, 30 s).
- `NotifyBoss summoned` leva `roam`/`power` (também para quem entra depois). `BossController`: banner
  "BOSS x3 À SOLTA! … sigam o marcador" + `BossRoamMarker` (BillboardGui AlwaysOnTop no HRP do boss com nome
  e distância em m, some na derrota/despawn).
- Teste MCP (run_server): nasceu em (106, 0, 82) ≈ média dos 13 spawns; vida 4500; vagou 20–48 studs por ciclo.
- **FALTA o dono testar**: F no altar com a flecha à noite → boss aparece no meio do mapa, persegue pelo mapa
  todo (sem voltar), marcador vermelho com distância visível através das paredes; boss automático continua
  nascendo dentro da muralha.

### Sessão 2026-09-21 (2) — leva "muralha + destruição + animações + roster" + BLOCO A de combate

### Sessão 2026-09-21 — FEITO no código (testado via MCP só no servidor; FALTA o dono testar jogando)
Pedido do dono: santuário do boss DENTRO da muralha (fora só a cachoeira com floresta mesopotâmica; altar
antigo fora), animação de parry e crítico, tirar personagens antigos, casar duração de ataque × animação,
construções destrutíveis estilo JJS nas 2 áreas vazias (+ árvores), e salvar as peças que ele moveu perto da
Taberna.
1. **Peças movidas perto da Taberna SALVAS no `Arena.rbxm`** (chão `Outter` leste alargado 65→168 e as 2 rochas
   da muralha leste encurtadas/subidas para abrir a caverna). Ferramenta nova: `tools/sincronizar_arena.luau`
   (lune) — cola o dump do Studio (trecho no cabeçalho do arquivo), lista as diferenças e com `aplicar` grava.
   **Usar sempre que o dono mover algo do `Workspace.Sahur.Arena` no Studio** (senão o Rojo desfaz).
2. **Muralha escavada**: `tools/escavar_muralha.luau` (lune, idempotente) sobe 8 rochas da muralha sul
   (x 30..166 / z 380..470) até o fundo ficar em y 34 — mesma técnica que o dono usou para a caverna.
3. **Santuário dentro da muralha** (`tools/arena_santuario.py`, chamado pelo `gerar_arena.py` → ArenaExtras):
   câmara x 34..162 / z 388..462, pé-direito 30, casca de rocha fechando o vão + tapa-buracos (x 0..30 e 166..210);
   túnel de 28 studs atrás do véu da cachoeira; piso em tabuleiro de arenito + tapete de lápis-lazúli; ALTAR =
   zigurate de 5 degraus com pedestal (`BossAltar`, prompts E/F do RitualService), placa `BossAltarRune` e
   `BossCrack0..7` (acendem no ritual); disco solar alado e faixas de lápis no fundo, tabuletas cuneiformes,
   2 lamassu (touros alados) flanqueando, 6 colunas com capitel de palmeira, braseiros, lamparinas penduradas,
   tanques laterais com lótus, urnas, poeira dourada. `BossSpawn` (98, 1.5, 418) e `BossArena` (98, 1.5, 422)
   no centro da câmara. O santuário ANTIGO (disco escuro, runas vermelhas, ossos, arco) saiu do gerador (o Rojo
   já apagou do place). `Workspace.AltarGruta` foi para `ServerStorage.Backup_AltarGruta_antigo` (não apaguei;
   o dono decide). **O dono precisa SALVAR o place** (o backup e o sync são edições do place).
4. **Jardim da cachoeira** (fora, x 24..176 / z 298..376): cascata caindo da rocha (fio d'água + véu sobre a
   entrada + lago raso + névoa/gotas + som), riacho saindo do lago, palmeiras (tâmaras), cedros em camadas,
   tamargueiras, papiro, flores, musgo, lajes até a praça, ruínas de tijolo com azulejo de lápis, 2 pedestais-
   zigurate com braseiro, vaga-lumes. (O pinheiro da arte em (110, 337) foi respeitado.)
5. **Construções DESTRUTÍVEIS estilo JJS** (`tools/arena_construcoes.py` → `ArenaExtras.Destructible`, 2416
   peças): em cada área (SE x 40..180 / z 165..290 e NW espelhada) um zigurate de 3 degraus, 9 casas de tijolo
   cru (terraço com lajes de madeira, mureta, porta, janelas, escada, toldo, vasos), 6 barracas de mercado,
   colunata, muro baixo, entulho, jarros e caixotes — tudo TIJOLO A TIJOLO (4×2×2,4). `ZigCore`/`ZigGold` são
   fixos. O chão dessas áreas está em y −0,87 fora dos `Tiles` (|z| > 190): `ground(z)` no gerador.
6. **DestructionService** (servidor) + **DestructionController** (cliente) + gancho `Hitbox.DestructibleHook`:
   TODA consulta de ataque da Hitbox (soco, habilidade, boss) que cobre uma peça com a tag `Destructible` solta
   a peça: desancora, voa para longe de quem bateu (grupo de colisão `Debris`: entulho não bate em entulho/
   agarrado; bate em jogador como no JJS), some em 4,5 s e VOLTA em 50 s (fade). Tetos: 22 tijolos por golpe,
   60 soltos ao mesmo tempo. **Árvores da arte** (`Arena.Trees.*.Oak/Pine`, `Corners.*.Trees`, 20 no total)
   TOMBAM para o lado oposto ao atacante (rotação por CFrame em volta do pé; os meshes vêm com `CanQuery =
   false`, o serviço liga) e voltam em 50 s. Efeitos `Shared/BrickBreak` e `Shared/TreeFall` (VFXLibrary) +
   `NotifyDestruction`. `DestructionService.RestoreAll()` repõe tudo (pode virar comando DEV).
   Testado via MCP (run_server): 10 tijolos soltos num golpe, sumiram em 5 s; carvalho tombou; altar com prompts.
7. **Animações de PARRY e CRÍTICO** (ProcAnimDefs): `Shared/Parried` (quem levou o parry cambaleia com o braço
   jogado para fora — tocada no atacante em todo cliente + hitstop), `Shared/CritPunch` (golpe crítico armado
   pelo parry: braço atrás da cabeça e direto com o corpo inteiro; o atacante local toca no clique enquanto
   `crit_ready`, os outros pelo 4º arg novo do `NotifyAttack`), `Shared/CritHit` (vítima: cabeça chicoteia,
   tronco gira). `Shared/Parry` (quem parryou) já existia.
8. **Duração casada** (`FX.PlayAnimation(..., fitSeconds)`): animação da equipe tem a velocidade ajustada
   (`Length / fitSeconds`, entre `FX.FitSpeedMin` 0,7× e `FitSpeedMax` 4×; espera o Length carregar) e a
   procedural escala o tempo (`ProcAnimController.Play(..., fitSeconds)`). Quem passa: socos (HitDelay +
   Cooldown = 0,45 s), habilidades (`AbilityController.actionSeconds`: Dash/Grab = CastTime + Duration;
   AreaDamage = max(CastTime, Delay) + 0,25; MultiHit = Hits × Interval; resto = CastTime; FlyGrab não),
   `_Carry` (tempo real do Carry), TimeDome (Cinematic.Total), Awakening da equipe (Cutscene), emotes de cena
   (Duration). Ex.: `Swift/TimeDome` 3,78 s → 3,8 s; `Shared/Uppercut` 1,83 s → 0,5 s (3,7×; se ficar
   rápido demais, baixar `FitSpeedMax` ou desligar `team = true` desse clipe).
9. **Personagens antigos SAÍRAM** (Brawler/Mystic/Guardian → **Jotaro/Kira/Dio** herdam os kits, provisórios):
   rename global de ids em `src/` (CharacterDefs, ProcAnimDefs, VFXLibrary, Assets, AwakeningDefs, Trailer,
   pastas `Assets/VFX|Animations|Sounds`), `DefaultCharacter = "Jotaro"` (grátis), Bruno/Swift 100 pts,
   Kira 250 pts, Dio = VIP (como era o Guardian). `Order = Jotaro, Swift, Dio, Kira, Rick, Sahur, Overlord`.
   Perfis antigos: `DataService.RENAMED_CHARACTERS` migra `unlockedCharacters` e `mastery` em todo carregamento
   (schema continua 3). Ult names: STAR PLATINUM (tema rock), THE WORLD (stone), KILLER QUEEN (arcane).
- **FALTA o dono testar**: entrar na câmara pela cachoeira (E/F no altar com a flecha à noite), boss automático
  nascendo lá dentro (cabe? `ArenaRadius` 55 × câmara 128×74), socar casas/árvores nas 2 áreas (FPS com 2416
  peças; tranco do entulho em jogador), parry → ver `Parried` no outro e `CritPunch`/`CritHit` no golpe seguinte,
  velocidade das animações da equipe casadas (Uppercut), personagens novos na seleção (V) e perfil antigo
  migrado. Se algo do jardim/câmara sobrepor a arte: `tools/achar_sobreposicao.luau`.
- **Ainda planejado**: boss x3 da flecha nascendo no centro e andando livre (item abaixo); lajes `BossPathSlab`
  do place sumiram com o sync — o caminho até a cachoeira agora são as `GardenSlab` do gerador.

## Sessão anterior (2026-09-20 — tudo commitado e no GitHub)

### BLOCO A (combate) — FEITO no código em 2026-09-21 (boot testado via MCP; FALTA o dono jogar)
1. Parry só com block ANTERIOR ao golpe: `HitOptions.AttackStartedAt` (= pedido − HitDelay) e
   `Block.ParryWindow` 0,25 s ANTES + `ParryLateTolerance` 0,05 s depois. Block apertado no meio do M1 = só bloqueia.
2. Agarrão não pega quem BLOQUEIA de frente (`CombatService.IsBlockingAgainst`; o block gasta guarda como um
   golpe bloqueado). A ult do Rick (FlyGrab) continua pegando.
3. Piscar do Bruno com 2 cooldowns: lateral `SideCooldown` 2,5 s × frente/trás `Cooldown` 5 s (`doDashOverride`).
4. Endlag do 4º M1: `ComboEndCooldown` 1,6 s + `ComboEndSlow` (0,9 s a WalkSpeed 7).
5. Ult mais lenta: `Energy.GainOnHitDealt/Taken` 2/1, `ChargeOnParry` 4.
6. Domínio do Tempo: quem está lento NÃO dá dash, soco nem habilidade (`CombatConfig.TimeSlowBlocksActions`,
   `CombatService.IsTimeSlowed`; cliente espelha no soco).
7. M1 não entra em quem está DEITADO (`NoM1OnRagdolled` → "immune"); downslam/habilidades continuam.
8. Dash não empurra pelo corpo: grupos de colisão `Players` (todo personagem, CharacterService) e `Dashing`
   (durante o dash; MovementService) não colidem; `Grabbed`×`Players` também não. Hit de chegada do dash
   frontal agora DERRUBA (Ragdoll 1,0, Speed 70) em vez de jogar longe sem ragdoll.
9. Parry vira o jogo: `ParryStun` 0,8 s (sem soco/habilidade/dash para quem levou) + crítico armado.
10. Combo: `PullStuds` 2,2, `HitStun` 0,8 s, 3º golpe LEVANTA (`ComboLift`: Up 14, sem ragdoll), 4º ragdoll.
11. Boss morto congela (ancorado, sem colisão, fade) — NPC (`BossService.endFight`) e forma de jogador
    (`HealthService.ragdoll` com `BossRig`).
12. Ação individual: soco em curso (`CombatService.IsAttacking` = HitDelay+Cooldown) bloqueia dash e habilidade;
    dash bloqueia soco EXCETO nos últimos `Dash.SidePunchWindow` 0,12 s do dash LATERAL (atributo `DashKind`;
    cliente espelha por `MovementController.DashState`).
13. Trocar personagem: quem DÁ dano também conta como "em combate" (`HealthService.MarkInCombat`,
    atributo `LastCombatTime`; `SecondsSinceDamaged` usa o maior).
14. Teleporte (Piscar/Warp/Effect Teleport): raycast do cenário (peito e pés) para antes do obstáculo (só
    atravessa personagens/NPCs/flecha), e o destino precisa de chão — recua 85/70/55/40 % pelo caminho; sem
    chão = não teleporta. Nunca cai no void.
15. Kill streak: a partir de `MatchConfig.KillStreak.AuraFrom` (10) = contorno + manto DOURADOS (cliente) +
    COROA de ouro na cabeça (servidor, `MatchService.buildCrown`); some ao morrer.
16. Clã: aliados com o mesmo `ClanTag` têm Highlight AlwaysOnTop (verde) — `Controls.Settings.ClanHighlight`
    (padrão ligado) em Configurações.
- **FALTA o dono testar (2 clientes)**: parry só antecipando; block segurando agarrão; Bruno com 2 cooldowns
  no Q; lentidão depois do 4º soco; cúpula travando o inimigo; soco em deitado não entra; dash não empurra
  (e o hit de chegada derruba); dash bloqueado no meio do soco e soco só no fim do dash lateral; troca de
  personagem negada após atacar; Piscar contra parede/borda; 10 kills = coroa; membro de clã visível.

### PLANOS (2026-09-21, pedido do dono: "planeja, sem ação ainda") — NOVA LISTA, em ordem sugerida
(Studio reaberto + Rojo reconectado em 2026-09-21: conferido via MCP que NADA da leva foi desfeito.)

**A. Lista de COMBATE do dono (bugs + ajustes de feeling; cada item = 1 mudança testável)**
1. Parry só na janela certa: hoje dá para parryar no MEIO do M1 do inimigo (rever `CombatService.ResolveHit`:
   parry deve exigir block iniciado ANTES do wind-up do golpe, `ParryWindow` contado do início do block; golpe
   já em execução não deve ser parryável depois do HitDelay).
2. Block não segura habilidades de AGARRÃO: defendendo, o inimigo ainda agarra (decidir: agarrão quebra block
   — como JJS — ou block nega o grab. Dono: "consegue usar habilidades em mim, as de grab" = tratar como bug:
   `AbilityService` Grab deve respeitar `CombatService.IsBlocking` frontal, ou ao menos aplicar guard damage).
3. Bruno Gollini (Swift) tem só 1 dash: o `DashOverride` (Piscar) não divide lateral × frente/trás como o dash
   universal (`MovementService`: cooldowns separados). Aplicar a mesma divisão ao Blink.
4. Socos OP em combo: sem delay real depois do 4º M1 (`ComboEndCooldown` precisa ser sentido — hoje o cliente
   desconta HitDelay e a previsão deixa emendar). Rever `nextAttackAt` e travar input local até acabar.
5. Ult carrega rápido demais (mesmo depois de 4/2): baixar `CharacterDefs.Energy.GainOnHitDealt/Taken` ou
   trocar para carga por TEMPO em combate + dano (ex.: 2/1 + 1/s lutando).
6. Dentro da Cúpula do Tempo do Bruno: quem está lento AINDA dá dash (na velocidade normal) e ataca. Aplicar
   `TimeSlow` no `MovementService` (dash speed/cooldown ×) e no `CombatService.onRequestAttack` (bloquear ou
   escalar `nextAttackAt` — hoje só escala o cooldown, o soco sai).
7. Dá para bater em quem está DEITADO/ragdoll: `ResolveHit` ignorar (ou dar dano reduzido sem knockback) alvo
   com `Ragdolled = true`, exceto finisher/agarrão especial (decidir com o dono).
8. Dash frontal jogou o alvo longe SEM ragdoll: provável colisão (o dash empurra o corpo fisicamente). Dash
   universal não deve empurrar (grupo de colisão temporário `Dashing` sem colidir com jogadores) — dano/
   knockback só pelo `Effect.Dash` de habilidade.
9. Parry deve dar VANTAGEM: quem levou parry fica X ms sem atacar/usar habilidade (`ParryStun` já existe —
   conferir se vale para habilidades também: `AbilityService` deve checar `IsStunned` no request) + o parryador
   ganha janela de crítico (já tem).
10. Combos difíceis de montar: reformular o M1 para favorecer sequência — hitstun maior que o intervalo entre
    socos (vítima não sai do 1º ao 3º), 3º golpe puxa/levanta, 4º ragdoll; dash lateral perto do FIM permite 1
    soco que emenda no M1 (até 3 vezes) para o combo de ragdoll (regra do dono, item 12).
11. Boss morto = ragdoll "sensível" que interage com o cenário e sai voando: ao morrer, congelar o rig do boss
    (ancorar as peças / `RagdollService` sem colisão com cenário / massa alta) ou sumir em fade.
12. AÇÃO INDIVIDUAL: no meio do soco não dá dash, no meio do dash não dá soco — EXCETO no fim do dash LATERAL,
    onde sai 1 soco (`CombatService`: lock `actionUntil` compartilhado entre soco/dash/habilidade; cliente
    espelha). Combo continua com M1 até 3 vezes → ragdoll.
13. Trocar personagem: hoje quem ATACA ainda troca (só quem apanha é travado). `SwapOutOfCombatSeconds` deve
    contar dano DADO também (`CharacterService`: marcar `lastCombatAt` no atacante em `ResolveHit`).
14. Teleporte (Piscar do Bruno, Warp do Overlord, qualquer `Teleport`) atravessa PAREDE e cai no void: fazer
    raycast do ponto de origem ao destino (só atravessa PERSONAGEM: filtro por `Players`/Combatant) e parar
    antes do primeiro obstáculo; garantir chão (raycast para baixo) antes de mover.
15. Kill streak não funciona: a partir de 10 kills o jogador fica DOURADO (contorno/aura) com COROA na cabeça
    (`ProgressionService`/`HealthService` streak → atributo `KillStreak`; `FX.SetOutline` dourado + acessório
    coroa por código; some ao morrer).
16. Clã: membros veem os outros membros do mesmo clã ATRAVÉS das coisas (Highlight `AlwaysOnTop` na cor do clã),
    com opção para desligar em Configurações (`Controls.Settings.ClanHighlight`).

**B. Cachoeira + jardim v2 ("Amazônia antiga + templos astecas")** — `tools/arena_santuario.py`
- Vegetação densa e alta: samambaias gigantes, bananeiras/heliconias (folhas largas), cipós entre árvores,
  árvores com raízes tabulares (sumaúma), bromélias, orquídeas, troncos caídos com musgo, nevoeiro baixo; menos
  "jardim", mais mata fechada em volta do lago com clareira.
- Templos astecas (pirâmides escalonadas de pedra cinza com escadaria central e serpentes-emplumadas nos
  corrimãos, altar de sacrifício no topo, glifos) em volta da cachoeira — 1 grande de cada lado + ruínas
  tomadas pela mata. A câmara interna pode ganhar o mesmo tom (glifos/serpentes) para combinar.
- CACHOEIRA mais "cheia" e OPACA: várias camadas (lençol Glass opaco + espuma branca em Neon/ForceField +
  quedas escalonadas em 2–3 patamares de rocha), spray largo na base, rochas molhadas (Reflectance), arco-íris
  leve, som de verdade. Véu na entrada ainda atravessável.
- **BUG: barulho de BUZINA perto da cachoeira** = o id `9120386436` (chutado) não é cachoeira. Trocar por um id
  público de água/cachoeira testado com o fluxo "Testar sons" (ou subir um do grupo com `tools/subir_audios.py`)
  em `arena_santuario.py` (parte `CascadeMist`, som `Cachoeira`).

**C. Construções JJS MAIORES e "enteráveis"** — `tools/arena_construcoes.py`
- Casas com 2 andares (pé-direito 10–12), interior real (piso, escada interna, mesa/vasos), portas 6×9 e
  janelas largas, telhado acessível por escada externa; pátios murados; um mercado coberto; o zigurate passa a
  ter câmara interna e rampa até o topo (área de luta em altura).
- Tijolos maiores (6×3×3) para manter ~2,5k peças com o dobro de volume; miolo dos andares (lajes) também
  destrutível em chunks; regra opcional de DESABAMENTO: tijolo sem apoio embaixo cai (limitado por golpe).
- Casca "quebra em pedaços grandes" nos ataques pesados (finisher/ult tira 2× mais tijolos: `MaxPerHit` por
  tipo de golpe).

**D. Menu DEV mais prático (ADM primeiro)** — `DevController`/`AdminService`/`gerar_devgui.py`
- Ordem nova: 1) ADM (teleportar até jogador / trazer jogador / entrar no servidor / assistir / kick / ban
  temporário / denúncias / dar item-pontos-personagem) com campo de jogador único no topo (lista clicável);
  2) MAPA (boss: invocar x1/x3, matar; flecha: dar/tirar; dia/noite; restaurar cenário destrutível
  `DestructionService.RestoreAll`); 3) TESTE (vida/energia cheias, god, velocidade, sons dos packs, F7, trailer,
  ResetData). Menos botões por tela, busca por nome, ações perigosas com confirmação de 1 clique.

**E. WORKSHOP DE MODS (servidor privado) + QUESTS** — anotado (dono 2026-09-20/21), design:
- Mods: os jogadores criam (kit oficial: template de mod = pasta com `ModConfig` + assets permitidos: mapa/
  cosméticos/regras de sala/eventos), mandam pela comunidade no DISCORD, a equipe analisa e publica; mods
  aprovados ficam num catálogo `ModsConfig` (nome, autor, versão, ativos por sala) que o DONO do servidor
  privado escolhe ao criar a sala (`PrivateServerId`). Servidor sempre carrega só o que está aprovado no
  código/assets (nada vem do cliente). Créditos ao autor na tela do mod.
- Quests: uma HISTÓRIA a ser seguida (capítulos com objetivos: falar com NPC, achar lugar, vencer X, matar
  boss, ritual) com progresso no perfil (`profile.quests`), NPCs de quest (um por developer, ideia do dono),
  mural na taberna com a etapa atual e recompensas (pontos de evento, cosméticos exclusivos, personagem).

**F. Boss x3 da flecha nasce no CENTRO e anda livre** — plano detalhado logo abaixo (PRÓXIMA TAREFA de 2026-09-20).

### PRÓXIMA TAREFA (pedido do dono ao sair, 2026-09-20) — só PLANEJADA, nada feito no código
**Boss x3 invocado pelo jogador (F no altar com a flecha) deve nascer no MAPA, quase no centro, perto dos
spawns, e ANDAR LIVREMENTE pelo mapa — sem lugar fixo para ficar/voltar.** Hoje `BossService.summon` põe o
boss em `BossSpawn` (santuário, agora na muralha sul) e a IA se prende a `BossArena`/`ArenaRadius` (leash).
Plano:
1. `BossService.summon(player, byName, power)`: se `power > 1` (invocado pela flecha), spawn = centro do
   mapa entre os spawns (média das posições dos `SpawnLocation`/`Spawn*` do Workspace, raycast ao chão,
   afastado ≥ 15 studs de qualquer jogador) em vez de `BossSpawn`. O boss automático de 2 h (power 1)
   continua no santuário.
2. Novo campo `f.roam = true` na `Fight`: na IA (`aiLoop`/`playersNear`/`pickTarget`), sem `roam` mantém
   `BossArena`+`ArenaRadius`; com `roam` o raio de busca é o mapa inteiro (`BossConfig.RoamRadius`, ~300)
   e o centro é a posição ATUAL do boss (nunca volta para um ponto). Sem jogador por perto: vaga
   (MoveTo aleatório a 30–60 studs, a cada ~6 s) em vez de voltar ao spawn. Conferir `lastSeenPlayer`/
   despawn por inatividade (não deixar despawnar só por estar longe da arena).
3. `BossConfig`: `RoamRadius`, `RoamStepMin/Max`, `RoamIdleSeconds`; `Form.*` (jogador-boss) não muda.
4. HUD/`BossController`: aviso "BOSS x3 À SOLTA" + seta/marcador de direção (opcional) porque ele não
   tem lugar fixo.
5. Testar via MCP: `BossService.SummonStrong(p, 3)` em play, conferir posição inicial e que ele persegue
   pelo mapa (bonecos de treino); depois o dono testa.

## Sessão 2026-09-20 (detalhe do que foi feito; FALTA o dono testar)

### Leva 2026-09-20 (2) — lista do dono — FEITO no código (testado via MCP o que dava)
1. **Postes da flecha** (ArrowPad/Spot/Post/Arm/Lantern 0..7) saíram do `gerar_arena.py`/`ArenaExtras`
   (o sync já apagou do place). `RitualService` sem ArrowSpot insiste no sorteio escondido (30 s de retry).
2. **Noite mais clara**: `EnvironmentService.DayNight.Night` = lua cheia (Brightness 0.9, ambient 46/52/78,
   outdoor 70/80/120, exposição -0.05, névoa 0.34). Ajustar ali se ainda estiver escuro/claro demais.
3. **TABERNA NA CAVERNA**: `tools/montar_taberna.luau` (roda via MCP `run_code`; idempotente) montou
   `Workspace.Taberna` (247 peças) dentro do `cav` (sala x 325..381, z 28..129, chão -1, teto 26; alcova
   oeste x 283..325 z 76..112): piso de tábuas, vigas, pilares, 5 mesas redondas c/ banquinhos + lanternas
   penduradas, mesa longa c/ bancos e louça, lareira na parede leste (fogo + luz), 13 tochas, barris,
   tapete, piano, quadros, corvo/rádio no mantel, placa "TABERNA DA CAVERNA" na boca do corredor (z 143).
   Aproveitou o que o dono já tinha: BAR no canto sudoeste (com 6 banquetas), balcão de boticário na
   parede oeste, porta de entrada no norte (x 369, z 130). Clonou peças de `Moveis taverna` (o monte que
   sobrou continua na alcova — o dono decide se apaga/guarda em ServerStorage). **O dono precisa SALVAR o
   place** (Taberna não passa pelo Rojo). Screenshots conferidas via KWin+spectacle (scratchpad `shot.sh`).
4. **Clã com PATENTES** (`ClanConfig.Ranks`): sobe pelo TOTAL depositado (`clan.contributed`; Bando 0,
   Companhia 1500, Guilda 4000, Ordem 9000, Lenda 18000). Cada patente: vagas (10→25), quem SACA (ninguém →
   líder → oficial+) e teto diário de saque (`withdrawDay/withdrawnToday`), bônus de XP (+5..20%) e de
   pontos (+0..15%) para os membros (atributos `ClanRank/ClanXpBonus/ClanCoinBonus`; `DataService.RewardCoins`
   e `ProgressionService.AddXP` leem), cosméticos `cape_clan` (Ordem) / `aura_clan` (Lenda) com `Access =
   "clan"` (só enquanto no clã; não vendem/trocam). **Membro nunca saca; quem depositou não recupera.**
   `RequestClan("withdraw", n)`; botão SACAR e linha "Patente N · perks · próxima" no `ClanGui`.
5. **Pontos ainda mais difíceis**: kill 2, vitória 20, derrota 3, level-up 6+2L, conquistas ×0,5, guerra
   40/10, streak 3.
6. **LOOT DO BOSS por ranking de dano** (`BossConfig.Loot` + `BossLootService`, usado pelo BossService e
   pelo BossFormService): 1º–3º = 90/70/55 pts + chance 55/40/28% de SUPER RARO (personagem exclusivo —
   configurado como **"Sahur"**, o dono confirma —, `aura_boss`, `cape_boss`, `scene_boss`, 40 pts de
   evento); 4º–5º = 35/30 pts + 45/35% de BOM (15 pts de evento, giro grátis, +60 pts); 6º+ = 12 pts.
   Item já possuído sai da mesa; sem nada, `Fallback` em pontos. Tela do boss mostra "Nº em dano" e o drop.
   Testado via MCP: 12 sorteios deram cena/aura do boss e pontos de evento. ATENÇÃO: o teste encheu o
   perfil DEV do dono (nível 20, itens do boss, ~2100 pts) — usar DEV → ResetData se incomodar.
7. **Sobreposição (z-fighting)**: `tools/achar_sobreposicao.luau` (roda via MCP/barra de comando; só lê).
   Acha faces coplanares sobrepostas entre peças ancoradas, lista no Output (pares ENTRE MODELOS primeiro)
   e deixa as peças selecionadas. `FIX = true` recua a peça menor 0,02 stud (Ctrl+Z desfaz). Agrupar NÃO
   resolve. Achados hoje entre modelos: `cav.Part4` × `Arena.Walls.Rocks` (3 faces), peças do kit
   `Moveis taverna` no chão da arena/Taberna.
8. **Pop-ups discretos, sem som**: `HUD.Toasts` + `HUDController.ShowToast(titulo, sub, cor)` (canto direito,
   desliza e some em 3,5 s, máx. 4). Nível, maestria, missão, conquista e item ganho (conquista/boss/troca)
   usam isso; nenhum som. Só a roleta/compra que o jogador pediu continua com som + brilho.
9. **"Ser o personagem escolhido"** (`Controls.Settings.CharacterModel`, painel Configurações): ligado, o
   jogador nasce com o rig da arte em `ServerStorage.CharacterModels.<Id ou CharacterDef.Model>` (R6 com
   Humanoid + HumanoidRootPart; scripts da arte são removidos) em vez da própria skin; sem o modelo, cai
   na skin e avisa no Studio. Mudar a opção = respawn (fora de combate). **A arte precisa colocar os rigs
   em `ServerStorage.CharacterModels`** com o nome do personagem.
10. **Rick** (`CharacterDefs.Characters.Rick`, "Rick Prime"): personagem EXCLUSIVO do boss (`Access =
    "drop"`, só via `BossConfig.Loot`; aparece no dropdown como "drop do boss"; dev tem). Kit PROVISÓRIO =
    habilidades do Mystic até a reformulação.
11. **Loja (L) abrindo/fechando torta**: `closeParents` deselecionava o próprio ícone da Loja ao abrir
    (ela é item direto, não dropdown) → painel sobreposto e "não quer sair". Corrigido; e abrir qualquer
    menu do topo fecha o painel do vendedor (`TopbarController.MenuOpened`).
12. **Auras de verdade** (`FX.SetCosmeticAura`): casca de energia em volta de cada membro (ForceField,
    pulsando) + manto de chamas subindo colado ao torso; as partículas de cada estilo viraram detalhe.
13. **Cenas travam**: `CombatService.HoldStill(player, s, motivo)` (WalkSpeed 0 + sem pulo + Stun) usado
    na cena de emote (servidor, `Duration`) e no atacante durante o Carry de todo agarrão.
14. **Poses em loop** (`Emote.Loop`, hoje só "sit"): ficam até andar/pular/atacar/usar habilidade/dash/
    apanhar/morrer — o SERVIDOR vigia (`CosmeticsService.StopEmote` via `CombatService.ActionHook` +
    Humanoid.Running/Jumping) e manda `NotifyEmote(false)` para todos; o cliente força `Looped = true`.
15. **Ult do Rick = PRIME DIVE** (`Effect.Type = "FlyGrab"`, tecla 1 desperto): voa 7 s na direção da
    câmera (`MovementController.Fly`, anim Rick/PrimeDive 71127142596119 em loop); encostou em alguém →
    agarra, sobe 22 studs em 1,4 s e mergulha a 110 studs/s até o chão (servidor ancora e interpola; anim
    Rick/PrimeDive_Carry 110066675368334), impacto = 45 + área 12 studs/18. Sem alvo = "end". Ajustar
    `RiseTime/DiveSpeed` para casar com a animação. NÃO testado com input real (precisa do dono).
16. **Roster**: `Rick` (normal, drop) → ult RICK PRIME; `Bruno`, `Jotaro`, `Dio`, `Kira` criados como
    `early` (só devs) com kits emprestados (Brawler/Swift/Guardian/Mystic) e nome da ult em
    `AwakeningDefs` (PODER MÁXIMO / STAR PLATINUM / THE WORLD / KILLER QUEEN). Movesets próprios = leva futura.
17. **Lojinha estilizada**: `tools/montar_lojinha.luau` → `Workspace.LojinhaDecor` (127 peças, tudo relativo
    ao `VendedorSpot`): balcão com mercadorias e baú, estante de poções atrás do vendedor, lanterna, toldo
    listrado, placa "LOJINHA", bandeirinhas, postes com lanterna, caixotes, barril, vasos, tapete. Conferido
    por screenshot. O dono SALVA o place.
18. **Altar na muralha atrás da cachoeira**: `gerar_arena.py` moveu o santuário (`SANCT_WORLD` z 231→294,
    `ALTAR_Z = SANCT_Z − 66`, anel de pilares girado para não tapar a entrada): altar em (97.75, 360), arco
    em z 369, muralha sul em z≈376,5. `tools/montar_altar_cachoeira.luau` → `Workspace.AltarGruta` (343
    peças): gruta de rocha colada na muralha (paredes, teto, lintel de arenito com lápis-lazúli e ouro,
    pilastras-zigurate), cachoeira (fio d'água na muralha → lençol no teto → véu ForceField na boca, névoa,
    respingos, lago raso atravessável, som `9120386436` — id chutado, trocar se não tocar), pedestais-
    zigurate com braseiros, urnas, tabuletas cuneiformes, 8 palmeiras, cipós, juncos, musgo, tochas.
    **ATENÇÃO**: as `BossPathSlab0..13` (lajes do caminho, do place) apontam para o altar antigo — o dono
    move. O dono SALVA o place. (Não tirei screenshot final: o dono estava usando o Studio.)
19. **Altar = escolha**: com a flecha, à noite: `E` = virar o boss (como antes) ou `F` = INVOCAR o boss
    **x3** (`BossConfig.StrongPower`: vida, dano e recompensas ×3, chance de item ×2 até 90%). Boss
    automático a cada **2 h** em força normal (`AutoSpawnMinutes = 120`). Flecha mais rara (8–15 min
    depois de sumir; 4–10 min no boot) e nasce longe dos spawns (`MinDistanceFromSpawns = 80`).
20. **Bruno Gollini = Swift** (id interno "Swift" mantido: perfis, pastas de animação/som/VFX); nome de
    tela e ult ("PODER MÁXIMO") trocados. O `Bruno` separado saiu do roster.
21. **Animações**: Shared.Idle = 111178125405490 (respirando; a locomoção procedural cede ao idle da
    equipe), Shared.Pose = 119477589200226, Shared.PoseStill = 131414311175694 (sem respiração — para
    stills/trailer), Shared.Uppercut = 112109080090418 ("ataque 1" — **dono confirma o lugar**). M1_1..4
    já eram os ids da equipe.
- **IDEIAS anotadas (dono, 2026-09-20)**: workshop de servidor privado (mods oficiais/comunidade); quest
  com cada developer; mural na taberna; **clash/mini-game**: socos rápidos dos Stands (Jotaro/Dio) ou
  poderes à distância (kamehameha) um contra o outro = QTE entre os 2 jogadores (teclas no teclado/
  celular/console) decidindo quem vence a troca.
- **Roster decidido pelo dono (2026-09-20)** — 5 personagens novos, cada um precisa de ataques/ult/efeitos
  próprios (leva futura): Bruno Gollini (poder máx.), Jotaro (Stand máx.), Dio (Stand máx.), Rick Prime
  (exclusivo do boss), Yoshikage Kira (Stand máx.). Universos: JoJo, MHA, Rick and Morty.
- **FALTA o dono testar**: toasts (subir de nível/maestria), setting do modelo (precisa de um rig em
  CharacterModels), Rick caindo do boss, vendedor/trocas (item anterior), taberna ao vivo (luz à noite dentro da
  caverna), clã: depositar até subir de patente, sacar como líder/membro, cosmético de clã em K; matar o
  boss com 3+ jogadores e ver os drops.

## Sessão anterior (2026-09-20 — lojas divididas + trocas)

### Leva 2026-09-20 — LOJAS DIVIDIDAS, VENDEDOR, TROCAS, economia mais dura — FEITO no código
Pedido do dono: "loja do topbar = Robux; vendedor = trade entre jogadores + tudo de pontos (cosmético/
customizável) por pontos e por pontos especiais de evento; pontos mais difíceis; ult carrega mais devagar".
- **Loja (L, `ShopGui`)**: só Robux (giros roll_1/roll_5, "pick", passes). Dica nova. O prompt do NPC NÃO
  abre mais ela. `CosmeticsGui` (K) perdeu o botão GIRAR por pontos (ficaram equipar + giros Robux + escolher
  com Robux); a roda de emotes (B) perdeu o botão de roleta.
- **Vendedor (E no NPC, `VendorGui`)** — `VendorController` + `VendorService` + `VendorConfig.Catalog()`:
  aba COMPRAR = roleta (1 giro = `RollCost` 100 pts), personagens (UnlockCost), capas, auras, emotes por
  PONTOS (`Price` em `CosmeticsConfig`) e seção EVENTO por PONTOS DE EVENTO (`EventPrice`: cape_canyon 40,
  aura_canyon 80, scene_canyon 150 — itens novos, desenhados por código). Painel fecha sozinho a
  `VendorConfig.Range` (16) studs do NPC; servidor exige perto (Range+6; dev passa). Só compra com perfil
  salvável (sessionOnly = nega).
  aba TROCAR = lista de jogadores → convite (`TradeController` + `TradeService` + `TradeConfig`).
- **Trocas**: quem propõe precisa estar no vendedor; o outro recebe o cartão `VendorGui.Invite` e precisa
  ir ao vendedor para ACEITAR (30 s). Mesa `VendorGui.Trade`: minha coluna = inventário trocável
  (`TradeConfig.Tradeable`: personagens comprados com pontos, cosméticos/emotes não-grátis/não-VIP;
  Limited PODE circular — `AllowLimited`), clique = oferece/tira; caixas de pontos e pontos de evento; a
  outra coluna mostra a oferta dele. PRONTO nos dois → CONFIRMAR libera após `ConfirmDelay` 2 s; qualquer
  mudança zera os prontos. Executa só se os dois ainda têm tudo e o receptor não tem o item; personagem em
  uso trocado → volta ao Brawler; cosmético equipado trocado → desequipa; SaveNow nos dois. Sair = cancela.
- **Pontos de evento**: `profile.eventPoints` (schema **3**), atributo `EventPoints`,
  `DataService.AddEventPoints`, comando DEV `AddEventPoints` (linha nova no painel DEV), no Perfil
  ("N de evento"). Ninguém dá ainda: os mini eventos do Canion vão dar.
- **Bug corrigido de tabela**: `owns()` dava Weight 0 + Access nil = "todo mundo tem" → itens LIMITADOS do
  passe e aura_ember/aura_shadow eram de graça. Agora só `Free = true` (emote wave) é de todos
  (`CosmeticsConfig.IsFree`).
- **Economia mais dura**: Kill 5→3, Win 50→30, Loss 10→5; level-up 20+5L→10+3L; streak 10→5, shutdown
  2→1/kill; boss pool 300→180, min 20→10, top 50→30, sobreviver como boss 150→90; guerra 80/25→50/15;
  conquistas ×0,6 (`AchievementsConfig.CoinScale`). Preços não mudaram (roleta 100, Swift 100, Mystic 250).
- **Ult mais lenta**: `CharacterDefs.Energy` GainOnHitDealt 6→4, GainOnHitTaken 4→2; parry 10→7.
- Testado: análise limpa; boot servidor/cliente sem erro; via MCP: catálogo (20 itens), AddEventPoints,
  Owns/Grant/Remove, Tradeable, RollWithPoints negando sem pontos, posição do vendedor OK.
- **FALTA o dono testar**: (1) E no vendedor → painel, comprar capa com pontos (dar pontos pelo DEV),
  comprar item de evento (DEV "pontos de evento" → Somar), girar roleta; afastar = fecha. (2) Com 2
  clientes (Test → Local Server, 2 players): propor troca, aceitar longe (deve negar "vá até o vendedor"),
  aceitar perto, oferecer item/pontos, PRONTO nos dois, CONFIRMAR, ver o item mudar de dono e o perfil
  salvar. (3) Sentir se os pontos/ult ficaram lentos demais.

## Sessão anterior (2026-09-19, noite — tudo commitado e no GitHub)
**Onde paramos**: dia inteiro de levas. FEITO e commitado: Parte 4 (denúncias + menu DEV), lajes do altar
(place é dono), topbar novo (5 dropdowns que se fecham, X em todo painel, Configurações separado), HUD do
dash (chips só na recarga), agarrão sem "voar" (grupo de colisão Grabbed), ids de animação/emote da equipe,
teto de empurrão, noite realista, cerca invisível no mapa da guerra, 96 áudios publicados no grupo (51 em
uso), ult do Swift com câmera/efeitos (carga 1,6 s), efeitos dos agarrões, emotes de cena com câmera
orbitando, auras em camadas (skins de cor saíram), vendedor da Lojinha (prompt abre a Loja), Canion como
área de evento (só aparece no evento; 8 EventSpawns). Studio derrubou a sessão às 13:12 por moderação de
um áudio (EmoteFarpando, removido) — resolvido reativando a conta. Chave Open Cloud do grupo em
`~/.config/sahur/roblox_api_key` (var `ROBLOX_API_KEY`).

### PRÓXIMA SESSÃO — (2026-09-19; o item 1 FOI FEITO em 2026-09-20, ver acima)
1. **Dividir as lojas** (FEITO 2026-09-20):
   - **Loja do menu (L, `ShopGui`)** = só itens de ROBUX (giros da roleta, passes, "escolher" cosmético).
   - **Loja do vendedor (E no NPC)** = itens de PONTOS e de **pontos especiais de evento** (moeda nova que
     os mini eventos do Canion vão dar). Precisa: `EventPoints` no perfil (DataConfig, schema novo),
     `PointsShopConfig` (o que vende: cosméticos por pontos? personagens? — PERGUNTAR ao dono a lista),
     painel próprio (`VendorGui` via `gerar_ui.py`) aberto pelo `ShopPrompt` em vez do `OpenShop`,
     `RequestShop` ganha ações de compra por pontos validadas no servidor. Hoje o prompt abre o `ShopGui`.
2. **Posição do vendedor**: `Workspace.Lojinha.VendedorSpot` (part amarela, criada via MCP) — o dono
   arrasta/gira e o vendedor nasce em cima dela olhando para a frente da part. Ele disse que o NPC "ficou
   fora da loja": se ainda estiver errado depois de mover a part, ver `ShopNpcService.placeNpc`.
3. Dono testa tudo da lista de polimento e manda ajustes (sons, ult, agarrões, cenas, auras, PVP).
4. Depois: mini eventos no Canion, publicar KA1/KA2/DAZ1/AAAQ, coisas de Dragon Ball (parkeadas).

### Leva 2026-09-19 (tarde) — lajes + topbar + HUD do dash — FEITA, falta o dono testar
- **BossPathSlab0..13**: saíram do Rojo (`ArenaExtras.model.json`/`gerar_arena.py`), `Props` e `ArenaExtras`
  com `ignoreUnknownInstances`. ATENÇÃO: o sync apagou as 14 do place (Rojo remove o que sai do arquivo);
  recriei via MCP nas posições geradas — **o dono precisa mover de novo para o lugar bonito e SALVAR o
  place**; daí em diante o Rojo não encosta nelas.
- **Topbar (item 2)**: 5 botões — Personagens (V, dropdown com um item por personagem: clique = usar /
  comprar / abre loja se VIP, rótulo "Nome · em uso/250 pts/VIP/em breve"), Jogar (Duelo/Clã/Placar),
  Loja (L, direto), Perfil (Cosméticos/Perfil/Conquistas/Denunciar), Config (Configurações/Controles/Dev).
  Bug de não fechar: TopbarPlus desliga `autoDeselect` de quem tem dropdown (`Utility.joinFeature`);
  `closeOthers` no TopbarController fecha os outros pais e os painéis abertos deles. Configurações agora é
  painel próprio (`SettingsGui`, `SettingsController` lê de lá); `HelpGui` só controles. O painel
  `CharacterSelect` continua existindo (cartões com habilidades/maestria) mas NADA abre ele — se o dono
  não sentir falta, apagar `CharacterSelect` de `gerar_ui.py` + os cartões do HUDController.
- **HUD do dash (item 5)**: os 2 slots saíram da barra (só 1/2/3/4 + Ult); cooldown do dash virou 2 chips
  em `HUD.Vitals.DashChips` (Dash / DashSide, mesmos filhos de um slot), acima da vida à direita.
- Testado: sync ok, boot do cliente sem erro. Falta o dono ver: dropdowns fechando, escolher personagem
  pelo dropdown, chips do dash (tamanho/posição), painel Configurações.
- **Animações da equipe (item 6) — INVENTÁRIO via MCP**: `ServerStorage.RBX_ANIMSAVES`: `R6` = KA1, KA2,
  DAZ1 (+ "sem título"/Automatic Save); `cabecinha` = aura; `Noob` = AAAQ; `BossModel`/`Noob1` = só
  Automatic Save; `emotes pack 1` = vertical, rodaregina, emote67, sentar, sofa. Pedir ao dono o que é cada
  uma (KA1/KA2/DAZ1/AAAQ/aura) e publicar no grupo → ids.

### Agarrões (item 4) — correção 2026-09-19, falta o dono testar com 2 jogadores
- Causa provável do "os dois voam pro void": a vítima soldada (Weld HRP→HRP) continuava COLIDINDO com o
  chão e com o corpo do atacante; peças sobrepostas numa solda rígida viram impulso gigante. `CanCollide`
  não resolve (o Humanoid religa o do Torso). Agora `attachVictim` põe todas as peças da vítima no grupo
  de colisão **`Grabbed`** (não colide com nada) + `Massless`, e devolve no release. Testado via MCP com
  boneco (Brawler/Throw e Guardian/Chokeslam): atacante fica parado, vítima presa/erguida, solta normal.
- Distâncias de arremesso são de design: Brawler Throw (Speed 70, Up 25) jogou o boneco ~44 studs. Se o
  dono ainda achar "longe demais", baixar `Knockback.Speed/Duration` do agarrão em `CharacterDefs`.
- **PVP "não sincronizado" (item 3)**: o M1 já tem previsão no cliente (anima no clique, vítimas do próprio
  cliente validadas numa caixa tolerante no servidor). Sem um caso concreto do dono (qual golpe, o que
  parece atrasado: animação, dano, empurrão, reação da vítima) não dá pra mexer sem chutar. PEDIR exemplo.

### Leva 2026-09-19 (noite) — lista 2 do dono — FEITO (falta ele testar)
- **Ids de animação** (`Animations.model.json`): Brawler/ShoulderBash 71266182110890 (anim tem 3,45 s e o
  agarrão dura ~1,1 s: ou a equipe encurta, ou aumento `Carry`), Shared/Dash 95985041721346 (era vazio),
  Swift/TimeDome 99664142798158 (ult; câmera/efeitos ainda NÃO feitos), Brawler/M1_1..4 (mesmos ids do
  Shared), Guardian/ShieldBash 120293502970268 e Overlord/Clutch 125017727896276 (os "ataque grab"),
  Brawler/GroundSlam 112099038975315 ("soco forte" — CONFIRMAR com o dono se era esse o lugar),
  Emotes/sit 137046777584533 (+ emote "Sentar" em `CosmeticsConfig`; a roda de 8 agora mostra primeiro os
  que o jogador tem). KA1/KA2 (block animado/fixo) continuam em `RBX_ANIMSAVES` sem id publicado.
- **Teto de empurrão**: `CombatConfig.KnockbackMaxTravelDashMultiple = 1.5` × alcance do dash frontal
  (74×0,24×1,4 ≈ 25 studs → máx ~37); `CombatService.Knockback` encurta a Duration. Ajustar o múltiplo.
- **Chips do dash**: só aparecem enquanto recarregam e ficaram com 12 px de altura.
- **Menus**: abrir qualquer painel (tecla ou clique) recolhe os dropdowns; todo painel `panel()` tem X
  (`Close`) ligado ao `deselect` do ícone (`TopbarController.registerItem`). Placar (HUD) não tem X.
- **Altar**: os 4 postes com tocha (`BossAltarPillar/Torch`) saíram (gerador + JSON; o sync apaga do place).
- **Noite realista**: `EnvironmentService.DayNight.Night` agora também interpola ColorShift, Atmosphere
  (densa, azulada), ColorCorrection (frio, dessaturado) e Bloom (luzes brilham). Testado: dia/noite trocam.
- **Mapa da guerra (Arena_Antiga)**: raycast em grade de 2 studs não achou buraco no modelo, mas o mapa
  é aberto em várias direções. Criei via MCP a pasta `Cerca` dentro de `ServerStorage.Maps.Arena_Antiga`
  (5 parts invisíveis: chão a y=156,4 sob todo o mapa + 4 paredes até y=310) — fecha a abertura e nenhuma
  cratera leva ao void. **O dono precisa SALVAR o place.** Se ele quiser fechar a abertura com parede
  visível/bonita, é trabalho de modelagem dele.
- **Áudios** (`audios/`, 96 mp3): `tools/subir_audios.py` sobe pela Open Cloud com a API key do grupo
  (`ROBLOX_API_KEY`, permissão assets read/write) e grava em `audios/ids.json`; `MAPA` no script diz qual
  arquivo vira qual som (`--listar`), `--aplicar` escreve em `Sounds.model.json`. Falta o dono criar a key.

### Leva 2026-09-19 (noite 2) — polimento visual — FEITO no código, NÃO testado (Studio sem sessão)
- **Áudios**: chave Open Cloud do grupo criada pelo dono (`~/.config/sahur/roblox_api_key`, var
  `ROBLOX_API_KEY`; permissões: assets, places, datastores, messaging, luau execution, user restrictions).
  96 mp3 subidos (`audios/ids.json`), 51 ligados em `Sounds.model.json` pelo `MAPA` de
  `tools/subir_audios.py`; 45 guardados para variações. Carregam no Studio (moderação ok).
- **Ult do Swift**: `CutsceneController.PlayUltimate` (câmera de quem usa em espiral baixa→alta durante
  a carga, letterbox, vinheta, flash + nome no estouro, volta suave; NÃO trava o jogador; quem está perto
  vê o tema de raios + flash + nome pequeno). Cúpula cresce durante `Effect.Cinematic.Charge` (1,1 s,
  em `CharacterDefs`) e estoura no tamanho final; `Total` = 2,8 s. Ajustar Charge pela animação.
- **Agarrões**: fase "grab" = estalo (`Shared/GrabCatch`) + hitstop nos dois + poeira arrastada pelo
  tempo do Carry (`Shared/GrabCarry`, emissores seguindo o HRP); fase "hit" por `Effect.Finish`:
  Throw = vento (`GrabThrow`) + rastro na vítima, Chokeslam = rachadura (`GrabSlam`), Spin = redemoinho
  (`GrabSpin`) + rastro. Os socos já tinham hitstop/flash/shake/puxão — não mexi.
- **Emotes de cena**: câmera dá 3/4 de volta lenta (`PlayUltimate` com `Orbit`), efeitos do tema do
  emote (`CosmeticsConfig.Emotes[].Theme`: rock/void/lightning/arcane) e nome da cena no estouro.
- **Cosméticos**: categoria SKIN saiu (pintava o corpo — dono: cosmético não muda a cor do avatar);
  `CosmeticsService` não mexe mais em BodyColors. Auras refeitas em camadas por `Style`
  (`FX.SetCosmeticAura`: wisps/flame/smoke/sparkle/electric + luz). Auras novas: `aura_ember` (conquista
  play_600), `aura_shadow` (zerou), `s1_aura_arrow_gold` (passe completo) no lugar das skins-recompensa.
  Quem já tinha skin no perfil só perde a pintura.
- **ATENÇÃO — Studio sem sessão**: desde ~15:30 todo Play dá `HTTP 403` em sons/animações/meshes/avatar
  (`serverplaceid=0`); o modo edição carrega normal. Nada desta leva foi visto rodando. O dono precisa
  FECHAR E ABRIR o Studio (relogar) antes de testar; eu ainda não medi a duração das animações novas.

### Assets novos — o que já tem código (2026-09-19, testado via MCP)
- **Lojinha**: `ShopNpcService` cria o NPC "Vendedor" (R6 ancorado, sem Combatant = não apanha) na frente
  de `Workspace.Lojinha` (acha pelo NOME; o dono move a construção para onde quiser, o vendedor segue; se
  a arte girar o modelo, "frente" = -Z do pivô). ProximityPrompt "Falar" (E) → `ShopController` abre a Loja
  (sem remote: o cliente escuta `PromptTriggered`). Enquanto a Lojinha ficar na área vazia (1341,167,225)
  o vendedor fica lá também.
- **Canion** = área de evento, FORA do mapa: mora em `ServerStorage.EventMaps.canion` (movido via MCP a
  pedido do dono, 2026-09-19) e o `EventService` clona para o Workspace só durante o evento (mesma posição),
  destruindo ao encerrar. 8 parts verdes `EventSpawns/EventSpawn1..8` dentro do modelo (o dono move; ficam
  invisíveis no jogo). DEV "EVENTO no Canion" / "Encerrar evento" (`Begin/Finish`), `Workspace.EventActive`,
  quem entra/renasce durante o evento vai para lá; encerrar devolve aos SpawnLocations do mapa livre
  (`CharacterService.PickSpawn`). Mini eventos/boss entram em cima disto. Testado: aparece/some, ida/volta.
- **Lojinha no lugar** (dono moveu para ~(163, 5, -258), perto de Corners): Lojinha virou um Model VAZIO
  (só pivô) e a construção inteira é `Banheiro.Union`; o `ShopNpcService` usa a caixa da união dos dois e a
  frente = LookVector do pivô da Lojinha. Vendedor em (151, 3, -267), no chão, de costas para a loja.
- Árvores/pedras 1–3, House Trink, LocalInicial, CasasKame: sem código — posicionamento é do dono.

### AINDA PENDENTE
- PVP "não sincronizado" — dono testa depois das levas e manda caso concreto.
- Publicar KA1/KA2/DAZ1/AAAQ/aura no grupo e encaixar (KA1 = block animado, KA2 = pose fixa de block).
- Ouvir os 51 sons novos e ajustar volumes/trocas; ver as 45 variações guardadas.
- Painel `CharacterSelect` (cartões) órfão — apagar se o dono não sentir falta.

### PEDIDOS NOVOS DO DONO (2026-09-19, manhã) — itens 2, 4 e 5 FEITOS; 1, 3 e 6 pendentes
1. **Assets novos no place** (adicionados pelo dono em áreas vazias da place, esperando sair de lá e
   virar uso real — não foram colocados por mim, então não mexer neles sem entender o pedido primeiro):
   - `Canion`: mapa de EVENTO, grande, pra um boss grande + mini eventos interativos (tipo o `Arena_Antiga`
     mas de evento, não de guerra de clã — provavelmente `WarOnly`-like, fora da rotação normal).
   - `Arvore1`/`Arvore2`/`Arvore3`, `Pedra1`/`Pedra2`/`Pedra3`: props usáveis no mapa atual, mas o dono foi
     claro — **não substituir TODAS as árvores/pedras atuais**, só variar/complementar.
   - `Banheiro` e `Lojinha`: são modelos separados mas a intenção é a MESMA construção (provavelmente
     lojinha com banheiro anexo ou a mesma estrutura reaproveitada). A `Lojinha` vai ter um **NPC vendedor**
     que abre a tela de loja (pontos especiais de missões/gamepasses) via ProximityPrompt — checar se dá pra
     reusar o fluxo do `RequestShop`/ShopGui já existente, só trocando o gatilho (NPC em vez do ícone Loja).
   - `House Trink`, `LocalInicial`, `CasasKame`: temática Dragon Ball, modelador caro, o dono ainda não
     decidiu o uso — não mexer até ele definir (podem virar mapa de evento, lobby alternativo, etc.).
   Nenhum desses tem lugar oficial no Rojo/`ArenaService` ainda — quando o dono definir o uso, criar a
   pasta certa (`ServerStorage.Maps` com `WarOnly`/tag de evento, ou fora da rotação normal).
2. **Reforma do topbar** (bug: dropdown de um menu não fecha quando abre outro — `TopbarPlus`/`Icon`
   provavelmente sem `autoDeselect` entre os 4 grupos, ou o `setOrder`/`bindToggleItem` dos grupos não
   está descadastrando o anterior). Estrutura NOVA pedida pelo dono (substitui a de 2026-09-17):
   - **Personagens**: vira DROPDOWN com os personagens diretamente dentro (não abre mais o painel
     `CharacterSelect` próprio) — repensar `CharacterSelectController`/ícone.
   - **Jogar** (ou outro nome): dropdown com Duelo, Clã, Placar.
   - **Loja**: continua item único (painel `ShopGui`).
   - **Perfil**: dropdown com Cosméticos, Perfil, Conquistas, **Denunciar** (o ícone que acabei de criar
     em `ReportController` já está pendurado em `AddToProfile`, então já nasce no lugar certo).
   - **Config**: Configurações (`HelpGui`/`Controls`), Controles, **DEV** (`AddToSettings`, já correto).
   Trabalho: revisar `TopbarController.luau` (a estrutura de 4 grupos com dropdown já existe, o pedido é
   1) corrigir o bug de não fechar o anterior e 2) mover Personagens para DENTRO de um dropdown com um
   item por personagem em vez de abrir `CharacterSelect.Panel`).
3. **PVP não está sincronizado/suave** — sensação de jogo bugada (o dono não deu exemplo técnico específico
   além do grab). Investigar: replicação de golpes (`NotifyAttack`/`NotifyDamage`), possível falta de
   interpolação/latência no cliente, ordem hit/animação.
4. **Agarrões ("grab") bugando**: "a maioria das vezes" jogam AMBOS os jogadores pro void ou muito longe.
   Suspeito: solda/CFrame do agarrão (`AbilityService` — efeito de agarrão descrito em
   `feedback-dono-fluxo`: "servidor solda a vítima") brigando com física ao soltar, ou posição calculada
   antes do personagem carregar de verdade. Precisa reproduzir e olhar o código de agarrão de cada
   personagem (Brawler arremessa, Guardian esmaga, Overlord gira).
5. **HUD dos dashs**: remover os DOIS ícones de dash (`Dash`/`DashSide`) da barra de baixo (`HUD.Abilities`
   em `gerar_ui.py`/`slot()`), deixando só os slots de ataque (1/2/3/4 + Ult). O cooldown do dash não
   some — muda de lugar: um símbolo de cooldown **acima da vida, à direita** (perto de `Vitals`/`Health`
   no HUD). Mexe em `gerar_ui.py` (layout) e `HUDController.luau` (`updateDashSlot`/`dashSlot`/
   `dashSideSlot` hoje apontam pros frames que vão sumir — trocar destino, não a lógica de cooldown).
6. **Animações novas da equipe**: estão em `ServerStorage.RBX_ANIMSAVES` e em "Emotes Pack 1" dentro do
   place (Studio), NÃO confirmado se já foram publicadas no GRUPO (lembrar: anim só funciona pro jogo de
   grupo se o KeyframeSequence for salvo com o GRUPO como dono — ver regra em CLAUDE.md). Precisa: 1) abrir
   o Studio e inspecionar `ServerStorage.RBX_ANIMSAVES`/pack de emotes via MCP (`run_code`), listar o que
   tem; 2) para cada clipe, `Save to Roblox` com o grupo como criador (fluxo manual do dono, como sempre);
   3) colar os ids nos lugares certos (`Animations.model.json` por personagem, ou `EmoteGui`/emotes se for
   pack de emote).

**Log do dono (2026-09-19, 11:38) conferido**: boot limpo depois da Parte 4 (52 RemoteEvents/3 Functions,
29 services, 21 controllers, 0 erro) — ele ainda não testou denúncia/menu DEV nesse log, só jogou normal.
Único aviso preexistente (não é da Parte 4): `[Assets] não encontrado: ...Animations.Shared.Dash (sem
AnimationId)` — Shared/Dash não tem clipe (só existe Shared/DashBack); pode ficar sem dono se os 2 ícones
de dash saírem da HUD (item 5), mas o efeito/cooldown do dash em si continua existindo.

### O QUE FALTA (ordem combinada com o dono, itens de sessões anteriores)
1. **Dono testar a Parte 4** (abaixo) com 2 clientes antes de seguir.
2. **O dono testar o que foi entregue na sessão de 2026-09-17** e mandar a lista de ajustes: jeito de
   andar/parar de cada personagem (Leva 8), VFX do F7 (`Lib/…`), poses feias (`ProcAnimDefs.luau`),
   ritmo/ângulos do trailer, metas/duração do passe (`AchievementsConfig`: hoje 60 dias e 6 conquistas
   por passe, chutados por mim).
3. **Leva 7 do polimento**: balanceamento, teste com 2 clientes, acabamento dos menus.
4. **Pendências antigas que continuam de pé**: `AwakenedEffect` que faltar, lista final de assets por
   ação para a equipe, ids de animação/som que a equipe ainda vai publicar no grupo, e marcar
   `team = true` nos clipes de `ProcAnimDefs` conforme o dono for aprovando as animações da equipe.

### Parte 4 — sistema de DENÚNCIAS + menu DEV de verdade — FEITO 2026-09-19 (falta testar)
- **Denúncia (qualquer jogador)**: ícone "Denunciar" no dropdown de Perfil (`ReportController.luau`,
  `ReportGui.model.json`) — escolhe um jogador online da lista, um motivo predefinido
  (`ReportConfig.luau`: hack/exploit, tóxico/assédio, nome impróprio, spam, abuso de bug, outro) e
  escreve um texto livre opcional (200 caracteres); `RequestReport` manda pro servidor.
- **`ReportService.luau`** (novo): valida (não dá pra se denunciar, motivo tem que existir, alvo tem
  que estar no servidor), cooldown de 30 s entre denúncias do mesmo jogador + rate limit (5 por 5 min),
  grava no DataStore `Reports_v1` (chave = UserId do denunciado, guarda as últimas 30, mais recente
  primeiro: quem denunciou, motivo, texto, data, jobId do servidor). `ReportService.GetReports(userId)`
  é a função que o menu DEV usa pra ler.
- **Menu DEV** (`AdminService.luau` + `DevController.luau` + `gerar_devgui.py`): seção nova "JOGADORES"
  ganhou **Ir para a arena** (`TeleportArena`: teleporta pra um spawn de `Workspace.CurrentMap.Spawns`
  via `ArenaService.GetSpawnCFrames()`), **Assistir alvo** (`Spectate`: toggle por jogador — câmera do
  dev solta seguindo o HumanoidRootPart do alvo sem controlar o personagem dele; clicar de novo no
  mesmo alvo solta a câmera) e **Entrar no servidor** (`JoinPlayerServer`: nome na caixa "Message",
  usa `TeleportService:GetPlayerPlaceInstanceAsync` + `TeleportToPlaceInstance` — funciona mesmo se o
  jogador estiver em OUTRO servidor, não só neste). Seção nova "DENÚNCIAS": **Ver denúncias do ALVO
  selecionado** (`GetReports`, olha quem está marcado na lista de alvos) e **Buscar por nome**
  (`GetReportsByName`, funciona pra jogador offline — usa `GetUserIdFromNameAsync`); o resultado lista
  as últimas 10 no log do painel (data, motivo, quem denunciou, se foi neste servidor ou outro, texto).
  `GrantItem` (dar cosmético/emote/personagem limitado ou não) já existia no `AdminService`, só não
  tinha botão dedicado — segue disponível via `RequestAdminCommand("GrantItem", {id=...})` se precisar
  de um pelo painel, não adicionei botão porque cada id precisa ser digitado (dono decide se quer isso
  numa caixa de texto extra ou prefere só via GrantAll/personagens).
- **TESTAR** (precisa 2 clientes, um deles com nick em `AdminConfig.Developers`):
  1. Jogador comum abre Perfil > Denunciar, escolhe o outro jogador + motivo, manda texto, confirma que
     a mensagem "denúncia enviada" aparece e que denunciar de novo antes de 30 s é bloqueado.
  2. Dev abre o menu (F8), seleciona o jogador denunciado na lista de ALVO, clica "Ver denúncias do
     ALVO selecionado" — confere se aparece no log.
  3. Dev testa "Buscar por nome" com um nick que NÃO está online (offline lookup).
  4. Dev clica "Ir para a arena" (confere se cai num spawn válido do mapa atual).
  5. Dev seleciona um alvo e clica "Assistir alvo" — câmera deve soltar e seguir o jogador; clicar nele
     de novo deve devolver a câmera pro dev.
  6. "Entrar no servidor" com o nome de alguém rodando em OUTRO servidor Studio/Team Test (se não tiver
     como testar 2 servidores agora, ao menos confirmar que não quebra nada com um nome inválido).
  7. `DataStore Reports_v1`: no Studio precisa de "Enable Studio Access to API Services" ligado, senão
     tanto a denúncia quanto a leitura falham com aviso (mensagem já trata isso).

### Leva 8 — animações "realistas" por personagem — FEITA 2026-09-17
- `ProcAnimDefs.Locomotion` (ligar/desligar tudo em `Enabled`) + seção LOCOMOÇÃO: helper `locomotion(p)` monta
  **Idle/Walk/Run** de cada personagem a partir do jeito dele (ciclo, respiração, inclinação, gingado, balanço
  de braço, abertura de pernas): Brawler pesado de guarda alta, Swift leve e inclinado à frente, Mystic quase
  flutuando com as mãos à frente, Guardian firme com o escudo erguido, Sahur ritmado (compasso no ar), Overlord
  lento e empertigado, mais o `Shared/*` para quem não tem personagem. Idle respira em 4 fases (nada de pose
  congelada) e tem "tempero" (`idleAccent*`) no meio do ciclo.
- `ProcAnimDefs.Styles` + `ProcAnimDefs.Resolve(key, charId)`: quem não tem clipe próprio ganha uma VARIAÇÃO do
  clipe Shared (amplitude, postura, giro de tronco, tempero de braço) — socos, hit, dash, block… ninguém repete
  ninguém. Cache por personagem; `<Char>/<Nome>` explícito sempre vence.
- `ProcAnimController`: agora tem camada de **BASE** (locomoção, escolhida pela velocidade do HumanoidRootPart,
  com o ciclo acelerando junto) por baixo da camada de **AÇÃO** (`overlay`: a ação manda só nas juntas que mexe;
  o resto continua andando). Acompanha todo personagem com Humanoid que aparece no Workspace (jogadores e
  bonecos), desliga o script `Animate` padrão do personagem deste cliente e para as tracks dele.
  Sem locomoção quando: `BossRig` (RigAnimController cuida), ragdoll/pulo/queda/morto (`FREE_STATES`) ou
  atributo **`ProcAnimHold`** (a cutscene do despertar marca isso para posar o rig sem briga).
- `MovementController` não carrega mais Idle/Walk/Run da equipe enquanto `Locomotion.Enabled` (volta sozinho se
  desligar). `FX.ProcAnim.Wants` passou a receber o `character` (resolução por personagem).
- Testado no Studio: 65 clipes carregados, `[ProcAnimController] locomoção ligada`, boneco parado respirando e
  passeio com MoveTo mostrando o ciclo de passos; análise estática 0 erros.
**Regras novas do dono (2026-09-17)**: tempo só para com o Guardian (raio 18); dash frente/Piscar = hit de chegada
(de frente = joga longe); Big C.H.O.P. nunca ragdolla; Swift ult = Domínio do Tempo (30 studs, 14 s, 0,08×, 1×
por despertar, sair = quebra e 3×); noite rara (28/4 min); bonecos "de verdade" (física, ragdoll, leash, DEV
Trazer boneco); animações procedurais mandam sobre as dos packs (`team = true` no clipe devolve à equipe).
**Ferramentas desta sessão**: screenshots do Studio (scratchpad `shot.sh`/`burst.sh`/`slow.sh`: KWin ativa a
janela + spectacle; painéis abrem pelo servidor via `PlayerGui.<Gui>.Panel.Visible` em run_script_in_play_mode);
preview de poses = `run_code` clonando ModuleScripts (require do DataModel de edição fica em cache) + rigs R6
com só o HRP ancorado; log do cliente em `~/.var/app/org.vinegarhq.Vinegar/.../logs/*_last.log` (grep FLog::Error).
**Leva 8 — o que o dono pediu (feito acima; mantido como referência do pedido)**:
- Idle com pose própria que "respira" (peso, balanço sutil) por personagem; andar/correr com jeito próprio
  ("maneiro"), cada personagem seu estilo; VARIAÇÕES de todas as animações por personagem (socos, hit, dash,
  block…): nada repetido entre personagens. Hoje Idle/Walk/Run são as da equipe (Shared) e os clipes de combate
  são compartilhados (`Shared/*`). Caminho: ProcAnimDefs com chaves `<Char>/M1_1` etc. resolvidas antes de
  `Shared/…` (Assets.ResolveFolder já faz isso para animações da equipe; o gancho FX.ProcAnim precisa tentar
  `<Char>/Nome` antes de `Shared/Nome`), + Idle/Walk/Run procedurais por personagem (MovementController toca
  Shared/Idle|Walk|Run via FX.PlayAnimation: basta criar os clipes e o gancho pegar) com camadas de respiração.
- O dono só vai avaliar as animações depois disso ("tem bonecos duros ainda").

## PLANO DE POLIMENTO (dono, 2026-09-17) — levas, uma por vez
Decisões do dono: o tempo NÃO para globalmente (só o Guardian, raio pequeno); todo dash pra FRENTE (e o Piscar
do Swift) dá um HIT ao chegar (dano, não conta combo; bem de frente = empurra longe); Big C.H.O.P. nunca entra em
ragdoll; ult do Swift vira DOMÍNIO DO TEMPO (cúpula: tudo dentro muito lento, Swift um pouco mais rápido; sair
quebra a cúpula e o Swift fica MUITO rápido até acabar); animações faltantes/erradas viram PROCEDURAIS por
código com o tempo exato de cada ação (equipe pode substituir colando id).
- **Leva 1 — combate (pedidos acima)** — FEITA 2026-09-17 (testado via MCP: domínio 1,25 → sair 2,2 → nil; ragdoll
  do boss bloqueado; noite 28/4 min começando 9h; hit de chegada só o dono testa com Q/Piscar): FreezeRadius só Guardian (18 studs, 1,3 s; outros 0); dash frente/Blink
  com hit de chegada (Dash.ArrivalHit: dano 4, "bem de frente" = dot > 0,8 → knockback forte sem ragdoll);
  BigChop imune a ragdoll (HealthService/RagdollService checam `BossRig`); Swift/Tempest → "Domínio do Tempo"
  (`TimeDome` effect: raio 22, 8 s, slow 0,25× de WalkSpeed/anim/cooldown pra quem está dentro, Swift ×1,25;
  sair = cúpula quebra + Swift ×2,2 até o fim; VFX cúpula + relógio; som).
- **Bonecos de treino "de verdade"** (dono, 2026-09-17): rig com física (não ancorado, WalkSpeed 0, servidor
  simula), atributo `Npc`; `CombatService.Knockback` aplica velocidade no NPC e `RagdollService.RagdollModel`
  derruba/levanta; LEASH 20 studs (ou caiu) = volta ao ponto sozinho; DEV **Trazer boneco** move o boneco
  parado (e o ponto dele) para a frente do admin — serve para testar dentro de arena de duelo/guerra.
  Testado via MCP: finisher → ragdoll + 25 studs → levantou → leash trouxe → BringTo a 6 studs.
- **Swift/Domínio**: raio 30, fora da cúpula 3,0×, `OncePerAwakening` (1× por despertar); texto de Controles.
- **Leva 2 — FEITA 2026-09-17**: `RigPose.luau` (originais compartilhados, Target/Lerp/Apply), `ProcAnimDefs.luau`
  (14 clipes: M1_1..4 0,45 s com impacto em 0,15, Uppercut, Downslam, Hit, Parry, Block loop, BlockHit, Grabbed
  loop, Dash, DashBack, RagdollCancel) e `ProcAnimController` (gancho `FX.ProcAnim`: PlayAnimation desvia
  quando existe clipe; `team = true` no clipe deixa o id da equipe mandar). Cutscene usa os mesmos originais.
  Preview de poses: `run_code` com `RigPose.Capture/Apply` em rigs R6 (só HRP ancorado) + screenshot.
  O dono precisa olhar in-game e apontar poses feias (ajustar ângulos em ProcAnimDefs).
- **Leva 2 — ProcAnim base (plano original)** (`src/client/Controllers/ProcAnimController.luau` + `Shared/Modules/ProcAnimDefs.luau`):
  motor de poses em Motor6D (como a cutscene), keyframes por ação com o tempo do CombatConfig: M1_1..4 (0,45 s
  cada, impacto em 0,15), Uppercut, Downslam, Hit (reação), Parry, Block/BlockHit, Grabbed, Dash/DashBack,
  RagdollCancel. Regra: id da equipe preenchido = toca o da equipe; vazio ou marcado `Proc` = procedural.
- **Ajustes do dono (2026-09-17)**: hit de chegada empurra MUITO mais (Speed 120, Up 20, FrontDot 0,7); cúpula
  14 s e lentidão 0,08× (quase parado); uppercut SEM pulo duplo (`AttackerUp = 0`, alvo sobe 46).
- **Leva 3 — FEITA 2026-09-17**: clipes procedurais de TODAS as habilidades (Brawler ShoulderBash/+_Carry/
  GroundSlam/Rampage; Swift Blink/SweepKick/TimeDome; Mystic ArcaneBolt/Mend/Meteor; Guardian ShieldBash/
  +_Carry/Fortify/Quake; Sahur Bombo/Toque/Ritmo; Overlord reaproveita) com duração = CastTime/impacto, e
  `ProcAnimDefs.AwakeningPoses` (charge1..3/burst/stance por personagem: Brawler punhos, Swift corredor,
  Mystic conjurando, Guardian escudo, Sahur tambor) lidas pelo CutsceneController (converte graus→rad).
  Preview: clonar o ModuleScript antes do require no run_code (o require do DataModel de edição fica em cache).
- **Leva 3 — ProcAnim habilidades (plano original)**: todas as habilidades de todos os personagens com CastTime (Blink, SweepKick,
  ArcaneBolt, Mend, Meteor, Fortify, Quake, Bombo, Toque, Ritmo, Domínio, Rampage/GroundSlam/ShoulderBash
  conferidos com o tempo) + poses do despertar por personagem.
- **Leva 4 — FEITA 2026-09-17**: 8 emotes/cenas procedurais (`Emotes/wave|taunt|dance|bow|flex|scene_power|
  scene_dark|scene_storm`), dança = 3 ciclos; andar cancela também o clipe procedural (CosmeticsController).
- **Leva 4 — Emotes/cenas (plano original)**: 8 emotes (wave, taunt, dance, bow, flex, scene_power/dark/storm) procedurais em loop.
- **Leva 5 (sons) — FEITA 2026-09-17** com o que é PÚBLICO (todos os 57 ids do Sounds.model.json carregam +
  12 dos packs JJS): criados `Shared/Hit_Stun|Crit|BlackFlash|Transform|Transform_Burst`, pasta `BigChop/*`
  (Devour/Crush/FleshWave/Frenzy + _Hit + Awakening_Voice); repetidos separados (Quake2, Roar_Hit, Shockwave_Hit,
  Leap, Ritmo, Toque, Bombo_Hit, RagdollCancel); transformação toca Transform/Transform_Burst e a forma não
  toca mais RoundStart; o `Awakening_Burst` genérico saiu de cima das ults; socos/_Hit com variação de tom
  (FX.playClone). Timbres repetem em alguns golpes — lista para a equipe gravar: Crit/BlackFlash próprios,
  kit do Big C.H.O.P., Transform, Ritmo (tambor de verdade), Hit_Stun, música/ambiente. VFX no F7 = com o dono.
- **Leva 5 — Sons por golpe + VFX (plano original)** (lista do TRAILER_ASSETS: separar repetidos, Hit_Stun, Crit, BlackFlash…)
  e revisão das 76 composições no F7 com o dono.
- **Leva 6 — Trailer — FEITA 2026-09-17** (~85 s): roteiro novo com as novidades (Piscar + hit de chegada que
  joga longe, uppercut, Domínio do Tempo real com cúpula, despertar com pedras/nome da ult — corte para dentro
  no estouro, Devorar com cura, Transform com som) + **coisas de fundo**: dupla X/Y brigando o trailer inteiro
  no canto, Z dançando, W provocando que toma o Terremoto e voa (e acena no final), R atravessando a praça
  correndo, F reverenciando o altar e fugindo do boss, dupla G/H na arena. Helpers: sparLoop/emoteLoop/
  dashAcross/launch. `TrailerWatching` (atributo local) faz a cutscene tratar a câmera como "perto".
  Rodado via MCP com 24 capturas: ok. FX.SetAura corrigido (som com o mesmo nome do emissor). Falta: o dono
  gravar e apontar ritmo/ângulos.
- **Leva 6 — Trailer (plano original)** (TRAILER_ASSETS.md).
- **Leva 7 — Balanceamento com gente + o que o dono ainda não testou (2 clientes) + menus feedback.**
- **Leva 8 — Animações "realistas" por personagem** — FEITA (ver RETOMAR AQUI).
- **Trailer (2026-09-17, 2ª passada)**: atores principais/E/F/W com AVATARES REAIS (`CAST` em TrailerService:
  guilacartinhasgames, gaubriel567895, humanoider_20, Ravi132012, skibid, ToduroDemais — todos carregam no
  Studio, sem repetir; fallback boneco colorido); ações de fundo afastadas do foco (dupla a ~60 studs, dançarino
  a 50, corredor de −70 a +70, curioso do altar mais atrás).

## Retomar aqui — HISTÓRICO (sessão 2026-09-16; o atual está no topo)

### PRÓXIMO PASSO (decidido com o dono no fim da sessão): arrumar o TRAILER — sons, animações e timing
Ler **`TRAILER_ASSETS.md`** (inventário plano a plano do que toca no trailer, o que está VAZIO, o que é fallback e
o que é som repetido entre golpes). Ordem combinada:
1. **Sons**: criar as entradas que faltam em `Sounds.model.json` e fazer o código chamar os nomes certos:
   `Shared/Awakening_Charge` (5 s de carga mudos — o pior), `Shared/Transform` + `Shared/Transform_Burst`
   (transformação no B.I.G., hoje sem som nenhum — o `BossController` "transforming"/`BossFormService` precisam
   tocar), `Shared/Crit` e `Shared/BlackFlash` (hoje caem no Finisher_Hit), `BigChop/Devour|Crush|FleshWave|
   Frenzy` (+ `_Hit`), `Shared/Hit_Stun`, música/ambiente do trailer. Separar os repetidos: Quake2=WallSplat,
   Quake_Hit=Roar_Hit=Shockwave_Hit, Tempest=Ritmo, Rampage2=Toque, Slam_Hit=GroundSlam_Hit=Bombo_Hit,
   ShoulderBash=RagdollCancel, Leap=Finisher_Whoosh. O dono manda os ids OU eu proponho candidatos dos packs
   (DEV → "Testar sons dos packs", `PackSounds`). Tirar `Awakening_Burst` de cima das ults onde não cabe e o
   `RoundStart` do "summoned" da forma.
2. **Animações** (pedir à equipe, ids em `Animations.model.json`): `Shared/Hit` (reação da vítima — VAZIO, muito
   visível), `Shared/Parry`, `Guardian/Quake`, `Mystic/Meteor`, `Shared/Grabbed`; Tempest/Rampage (4,2 s) longas
   para o corte — ou encurtar a cadência do trailer. Atores do trailer devem tocar Idle (hoje pose padrão).
3. **Timing do roteiro** (`TrailerService.run()`): cadência dos socos 0,42 s vs anim 0,17 s; aviso do Meteor
   1,5 s; Crush `_Hit` a 0,6 s; ângulos/durações conforme o dono vir o vídeo.
4. Depois do trailer: polimento restante — menus minimalistas, `AwakenedEffect` faltando, lista final de assets
   por ação para a equipe; feedback do dono sobre as 76 composições de VFX no F7 (`Lib/…`).

### 2026-09-16 (noite, depois do trailer) — polimento do jogo (trailer fica para depois, decisão do dono)
- **`AwakenedEffect` completo**: toda habilidade que não é ultimate tem versão desperta em `CharacterDefs`:
  Brawler/ShoulderBash (arremesso mais longo/forte), Swift/Blink (Piscar 18 → 28 studs; suporte no
  `MovementService.doDashOverride` lendo o atributo `AwakenedUntil`), Mystic/Mend (30 → 50), Guardian/ShieldBash
  (ergue 7, área do impacto 13/16), Sahur/Toque (×1,8 por 8 s), B.I.G. Devour/Crush/FleshWave. Testado via MCP:
  despertar → ShieldBash desperto deu 26 (20 × 1,3), Fortify 0,2, Blink 28. `SetForm` zera o despertar (esperado).
- **Flecha RARA e ESCONDIDA** (dono: "está muito fácil"): sem feixe/lanterna apontando. `RitualService`
  agora sorteia um ponto do mapa por raycast do céu (`randomHiddenSpot`: chão plano, longe do altar e dos
  jogadores; `ArrowSpot*` só de reserva) em tempos ALEATÓRIOS (`BossConfig.Ritual`: FirstSpawn 45–150 s no boot,
  SpawnDelay 120–300 s depois de sumir; forma acabou = RespawnDelay + isso). Morreu = flecha fica no chão
  `DropLifetime` = 10 s; ninguém pegou = some (evento "vanished") e volta à fila. Jogador saiu = fila.
  DEV "Sortear flecha" continua imediato (para testar). Testado via MCP: boot sem flecha → sorteio → dar →
  morrer → 10 s → sumiu → próxima em 164 s.
- **Menus (item 6 dos planos)** — vi as telas por screenshot (KWin ativa a janela do Studio + `spectacle`; script em
  scratchpad `shot.sh`/`multishot.sh`; painéis abertos pelo servidor via `PlayerGui.<Gui>.Panel.Visible` num
  `run_script_in_play_mode`). Problemas achados e corrigidos em `tools/gerar_ui.py`: Personagens com 6 cartões
  estourando (agora lista horizontal rolável, painel largura da tela até 1104), Loja com passes por fora do painel
  e texto por cima (passes roláveis), Controles com texto cortado e configurações por cima da HUD (texto rolável,
  configurações fixas embaixo), Perfil com o top de rating fora do painel (relayout), Duelo em JSON à mão fora do
  padrão (agora gerado). `panel()`: altura = min(h, tela − 202) via UISizeConstraint → NUNCA cobre a HUD;
  ClipsDescendants; fundo 0,28 (mais legível); título 20 branco. Missões/Cosméticos/Duelo = ScrollingFrame.
  Dono ainda não viu; ajustar cores/espaços conforme ele pedir.
- **Boss Big C.H.O.P.** (renomeado; id `BigChop`) — leva dos 4 itens:
  1. Kit: **Devorar cura 60 por alvo atingido** (`Dash.HealPerHit`, única fonte de vida da forma; desperto 90) e
     agora aplica o Knockback declarado; Esmagar tem stun 0,6 s (emenda no Devorar); Onda de Carne cd 12;
     Frenesi 8 × 8 a cada 0,22 s. Testado via MCP: Devorar 936 → 999 HP.
  2. Visual do rig (`BossRigs`): CUTELO cravado nas costas (lâmina Metal + fio + furo + cabo Wood + rebite) com
     respingos escuros, costuras (pontos) em dois blobs, baba na boca (3 gotas + fio), PointLight nos olhos.
  3. Poses de habilidade (`RigAnimController.Pose(model, id)`, tabela `POSES`): Devour = agacha/abre a boca/
     crava; Crush = empina 0,45 s e desaba; FleshWave = infla e estoura (patas abrem, cauda chicoteia);
     Frenzy = mordidas a 0,22 s balançando. `AbilityController` chama no "start" (id sem pose = Pulse 2).
  4. Câmera/HUD: ao virar boss a câmera é EMPURRADA para 42 studs (min=max por 0,3 s, depois 18–70);
     barra do boss mostra **tempo restante** (`endsAt` no "summoned", também para quem entra depois);
     banner próprio ("Você é o Big C.H.O.P. — DEVORE para curar…") e para os outros ("derrubem antes do tempo").
  FALTA: sons próprios (junto com o trailer), VFX de transformação melhor, balancear com gente de verdade.
- **Cutscene da ULT refeita (dono: "mais efeito, sons, aura")** — `CutsceneController` reescrito + `AwakeningDefs.luau`:
  1. Mundo reage: barras de cinema, vinheta (5 anéis), HUD/CoreGui escondidos, ColorCorrection (dessatura e
     tinge na cor do personagem na carga; satura/brilha no estouro) + Bloom, flash branco, **nome da ult em
     texto grande** (FÚRIA/TEMPESTADE/METEORO/TERREMOTO/RITMO FINAL/CATACLISMO/FRENESI) com subtítulo.
     **Tempo para**: no estouro o servidor congela todos os outros (`CombatConfig.Awakening.Cutscene.FreezeSeconds`
     1,3 s; `FreezeRadius` 0 = servidor inteiro) via CutsceneUntil + Stun "frozen"; o cliente congela a animação
     de todo mundo (Hitstop) e quem está a 110 studs vê flash na cor, dessaturação, nome pequeno da ult e o som
     "Awakening_Freeze".
  2. Temas por personagem (`THEMES`): rock (pedras levitam/voam) Brawler; lightning (pós-imagens + raios) Swift;
     arcane (anel de runas + 5 esferas convergindo) Mystic; stone (6 pilares sobem e desmoronam) Guardian; drums
     (anéis pulsando no ritmo + som Pulse) Sahur; void (esfera escura que colapsa) Overlord; flesh (bolhas) BigChop.
     Estouro usa a composição da própria ult (`<Char>/<Ult>` do VFXLibrary).
  3. Som em camadas (ids PÚBLICOS dos packs JJS, testados via MCP — 12 de 57 carregam): Awakening (nosso) +
     `Awakening_Charge` loop (966888080, PlaybackSpeed 0,75 → 1,55 tweenado) + `Awakening_Riser` (4299624634,
     4,9 s, alinhado ao estouro) + `Awakening_Pulse` (batidas 1,8/1,25/0,8/0,45/0,2 s antes) + `Awakening_Burst`
     (nosso) + `Awakening_Impact` (9114589190) + `Awakening_Voice` (grito 17309157540; `<Char>/Awakening_Voice`
     tem prioridade) + `Awakening_Freeze` (136494030417281). `FX.PlaySoundAtControl` devolve o Sound.
  4. Modo despertado mais visível: `Shared/AwakenedSwing` (faíscas na cor a cada soco, CombatController) e anel
     de energia no chão soldado ao root (`Shared/Awakening`).
  Testado via MCP com screenshots (Brawler e Guardian). FALTA: ver com 2 clientes (o lado de quem assiste),
  ajustar tempos/intensidade conforme o dono; equipe pode gravar Awakening_Voice por personagem.

### O dono ainda NÃO testou (feito em 2026-09-16, ordem sugerida)
- Trailer (DEV → "TRAILER (~70 s)"; gravar com OBS) → VFX no F7 → ritual da flecha/forma de boss → agarrão
  soldado (2 clientes) → administração (mensagem/ban) → ciclo dia/noite → Arena_Antiga na guerra de clã →
  cutscene da ult 7 s / ult no ar / prioridade (itens 1–3 abaixo).
- Place: `Workspace.Efeitos`/`Auras` foram APAGADOS (viraram IDs em `VFXLibrary`); `ServerStorage.Maps.Arena_Antiga`
  precisa estar SALVO no place (Team Create). Preview do B.I.G. removido.

### Feito nesta sessão — o dono precisa TESTAR no Studio
1. **Cutscene da ult = 7 s** (`CombatConfig.Awakening.Cutscene`: Duration 7.0, BurstAt 5.0). Linha do tempo
   (`CutsceneController`): t0 som `Awakening` + som de carga em loop `Sounds.Shared.Awakening_Charge` (entrada
   criada VAZIA no `Sounds.model.json` — colar id) → poses 1/2/3 em 0/1,6/3,4 s, câmera orbita e fecha no rosto
   → 5,0 s estouro (corte de câmera, flash, `Awakening_Burst`) → pose de guarda, órbita lenta → 6,55 s câmera
   volta → 7,0 s controle de volta. `FX.PlaySoundAtStoppable` devolve função que para o som (fade).
   Testar: G no chão e NO AR; ver se os 3 sons ficam separados; ajustar tempos se quiser.
2. **Ult no ar**: servidor ANCORA o HumanoidRootPart (velocidade zerada) durante a cutscene e solta no fim/morte
   (`AbilityService.onRequestAwaken`); câmera agora é recalculada a cada frame relativa ao root
   (`RenderStepped`), nunca perde o personagem. Testar: pular + G → personagem flutua parado, câmera junto, cai
   quando acaba.
3. **Prioridade/invencibilidade** (`HealthService.IsInvulnerable` centraliza: modo deus, `IFramesUntil`, trava do
   agarrão):
   - Cutscene: já tinha i-frames; agora golpe em alvo invencível vira kind `"immune"` (sem dano, sem hitstun,
     sem empurrão; cliente só dá um brilho cinza). NPC/boss idem (`ResolveNpcHit`). Agarrão não pega quem
     está invencível.
   - Agarrão (Grab: Throw/Chokeslam/Spin): quem agarra tem i-frames da investida até o release (se não pegar
     ninguém, `RagdollService.ClearIFrames`); a vítima presa fica `LockedToUserId` = só o agarrador acerta
     (terceiro não tira ela do agarrão).
   - Combo de M1: ao acertar um M1 (1º–3º), o atacante ganha `comboArmorUntil` (~0,65 s, até o próximo golpe):
     soco SIMPLES de um terceiro dá dano mas NÃO interrompe (sem hitstun). 4º golpe, uppercut/downslam e
     habilidades (têm empurrão) interrompem normal. Vítima em hitstun continua sem dash (já era assim).
   Testar com 2 clientes (Test > Clients and Servers, 3 players) ou bonecos.
4. **Ciclo dia/noite + RITUAL DA FLECHA + Big C.H.O.P. jogável** (dono, 2026-09-16 noite — foco do jogo
   virou JoJo; bosses por PEÇAS do Roblox, estilo JJS, sem mesh externo):
   - `EnvironmentService.DayNight`: dia 10 min / noite 5 min (noite = 18,5→5,5), começa 15,6. `Workspace.IsNight`.
     DEV: **DIA / NOITE / Ciclo automático / Congelar hora**. Iluminação da noite em `DayNight.Night`.
   - `BossRigs.luau` (shared): `BossRigs.Build("BigChop")` monta o boss com Ball/Cylinder/Block (65 peças,
     7 Motor6D: Root, Cone, LimbFL/FR/BL/BR, Tail): cone listrado azul/branco (9 cilindros), massa de carne
     rosa (19 blobs), olhos amarelos de grade, boca com dentes, 4 barris listrados, cauda. Atributos no Model:
     `BossRig`, `HitboxScale` (Hitbox.luau multiplica alcance/raio), `RigScale`. Animação PROCEDURAL no cliente
     (`BossController.animateRigs`: respira, cone balança, barris pisam ao andar, cauda ondula).
     (Preview que ficou no Workspace foi removido; pra ver o modelo: DEV → Virar Big CHOP.)
   - `RitualService` (reescrito): UMA flecha dourada aparece num dos 8 `ArrowSpot*` (pedestal + lanterna).
     Encostar pega (fica nas costas, `Player.HasArrow`, banner pra todo mundo = alvo). Morreu = a flecha cai
     onde caiu. À NOITE o portador segura E no altar (`RitualPrompt`) → `BossFormService.Transform`. Tochas
     acendem à noite; runa/rachaduras acendem quando alguém tem a flecha à noite. Flecha volta 30 s depois
     de a forma acabar. Modelo da equipe: `StandArrow` em ServerStorage/Assets (senão flecha por código).
   - `BossFormService` (novo): 2,5 s parado/invencível (aura + shake) → personagem vira o rig (1500 HP,
     WalkSpeed 15, socos ×2,2, hitbox ×2,2, `CharacterId = BigChop` com kit próprio em CharacterDefs:
     1 Devorar (investida), 2 Esmagar, 3 Onda de Carne, G Frenesi). Barra de boss pra todos. Acaba ao morrer
     (quem bateu divide RewardPool como antes) ou em 240 s (boss ganha 150 moedas). `CharacterService.LoadModel`
     é o caminho genérico de trocar o corpo; `HealthService` lê `MaxHealth`/`WalkSpeed` do Model;
     `AbilityService.SetForm` troca o kit sem respawn. Boss NPC antigo ficou só para admin (SummonBoss).
   - DEV: **Me dar a flecha / Sortear flecha / Virar Big CHOP / Encerrar forma**.
   - Testado via MCP: pegar flecha → noite → transformar → 1500 HP → morrer → recompensa → respawn R6.
   - FALTA (próximos): ataques do rig com pose (cone "morde" no M1), VFX/sons próprios, câmera da forma (zoom
     maior), balancear kit, som/animação de transformação melhor, `ArrowSpot` visíveis de longe (feixe de luz?).
4b. **VFX compostos por código (`VFXLibrary.luau` + `FX.PlayComposed`)** — 2026-09-16 noite. Li via MCP o pack
   novo do dono (`Workspace.Efeitos` "EFEITOS 2" = 142 meshes únicas de choque/vento/impacto/raio; `Auras` =
   126 emissores com texturas/sequências) e guardei os IDs em `VFXLibrary.Meshes` (60) e `.Textures` (43). Os
   efeitos são montados na hora: SpecialMesh (escala tweenada, giro, encosta no chão, olha a câmera) + rajadas
   de partícula + luz + camada `pack` que reaproveita os VFX dos packs antigos. 76 composições: socos
   (`Shared/Swing_1..4`, `Uppercut`, `Downslam`), acertos (`Hit`, `Crit`, `BlackFlash`, `FinisherHit`,
   `WallSplat`, `Block`, `Parry`, `GuardBreak`, `Stun`, `Ragdoll`, `RagdollCancel`, `Dash`), despertar
   (`Awakening_Charge/_Burst/Awakening`, `Transform`), e TODAS as habilidades (Brawler/Swift/Mystic/Guardian/
   Sahur/Overlord/BigChop + Boss). `$primary` = cor do personagem. `FX.SpawnVFX` tenta a composição antes
   dos packs. **Preview F7** lista tudo como `Lib/Pasta/Nome` (Shift = à frente). Testado: 76/76 tocam sem erro,
   holders somem no fim. FALTA: o dono olhar cada um no F7 e apontar o que ajustar (tamanho/cor/mesh errada —
   escolhi as meshes pelo nome/tamanho, sem ver); sons por golpe; animações do rig do boss.
   Depois disso `Workspace.Efeitos`/`Auras` podem sair do place (tudo que precisava virou ID no código).
4c. **Polimento (2026-09-16 noite, depois dos VFX)**:
   - **Agarrão soldado no servidor** (item 5 dos planos): `AbilityService.attachVictim` = `Weld` HRP→HRP com C0
     (offset/lift; Spin gira o C0 a 30 Hz), física da vítima passa ao cliente do atacante, `PlatformStand`;
     solta ANTES do golpe final. Cliente da vítima só toca `Shared/Grabbed` (loop, entrada vazia em
     `Animations.model.json`). Testado com boneco: weld 3 studs, solta, dano entra.
   - `RigAnimController` (novo, saiu do BossController): animação procedural do rig + `Pulse(model, força)` =
     mordida do cone no M1/habilidades (CombatController/AbilityController chamam). Zoom da câmera 18–70 na
     forma de boss (`BossController`).
   - **Menu DEV → Administração** (item 7): caixa de mensagem + dias; **Mensagem GLOBAL** (MessagingService
     `SahurAnnounce`, cai para o servidor se falhar), **no servidor**, **ao alvo**; **BANIR alvo** (DataStore
     `Bans_v1`, kick, checado no PlayerAdded; dias = 0 permanente), **Desbanir** (nome na caixa). Banner na HUD
     (`NotifyAnnouncement`). Painel virou ScrollingFrame (92% da tela, rola). `AbilityService.Use` p/ testes.
   - Aviso: `Boss.Swipe/Idle/Roar` (animações do BossModel antigo) não valem mais — o boss é o rig por peças.
4d. **TRAILER por script** (`TrailerService` + `TrailerController`, DEV → "TRAILER (~70 s)" / "Parar trailer"):
   ambiente controlado (bonecos desligados, jogadores estacionados no céu, hora fixa), 4 atores NPC R6 na
   praça + 1 no santuário; linha do tempo que dispara os MESMOS eventos do jogo (NotifyAttack/Damage/Ability/
   Boss) → animações, VFX, cutscene do despertar e transformação são as reais. Roteiro: voo sobre o mapa →
   combo com finisher → parry/crítico/Black Flash → Quake/Tempest/Meteoro/Fúria → DESPERTAR (câmera orbitando)
   → anoitece, voo até o altar (ator com a flecha) → transformação vista de fora (câmera passa por ele) →
   B.I.G. em ação (soco, Esmagar, Frenesi) → Arena_Antiga (cópia no céu, voo) → cartela final e fade.
   Cliente: HUD/topbar escondidos, barras pretas, cartelas de texto, câmera Scriptable (dolly/órbita/look).
   Testado via MCP: roda 70 s, limpa tudo (atores, cópia da arena, hora automática, bonecos, jogador).
   Gravar com OBS. Ajustes de ritmo/ângulo: editar `run()` em TrailerService (shot = CFrames/órbita).
5. **Arena_Antiga = mapa da guerra de clã**: `tools/montar_arena_antiga.luau` (rodei via MCP) recoloriu os muros
   do dono, gerou interior (piso, plataforma central B com rampas, plataformas A/C, cobertura espelhada,
   colunas quebradas, tochas, bandeiras azul/vermelha), `CapturePoints` A/B/C e `Spawns` (Spawn1 oeste /
   Spawn2 leste), moveu para `ServerStorage.Maps.Arena_Antiga` (atributo `WarOnly` = fora da rotação de
   rounds). `WarConfig.Maps = {Arena_Antiga, Arena_Gerada}` → `WarService.pickMap` sorteia. O place precisa ser
   SALVO (Team Create) para persistir. Para refazer o interior: rodar o script de novo (apaga só o gerado).
   TESTAR: guerra de clã com 2 clãs (ver roteiro da guerra) e conferir se caiu na Arena_Antiga.
6. **Pendências do que o dono puxou para o Workspace** (ver resposta de 2026-09-16 noite): `Workspace.Efeitos.VFX
   PACK` = 2.897 parts / 785 texturas únicas renderizando (mesmo pack que derrubou o FPS antes) — tirar do
   Workspace (ServerStorage) ou apagar (já temos em `packs/ParaImportar`). `EFEITOS 2` (191 meshes de
   choque/tornado/esferas) e `poder` são bons para VFX de habilidade → escolher e eu levo para
   `Assets.VFX`. `Auras` (7 auras de partículas) → candidatas a `Assets.VFX.<Personagem>.Awakening`.
   Árvores/pedras (Arvore1-3, Pedra1-3) → posso espalhar cópias por código (PropService) se o dono quiser.
   `cav` (8 parts Slate em 255,11,88) parece uma caverna/gruta — o dono confirma o uso.
7. Depois (ainda não feito): item 4 (VFX golpe a golpe com o testador F7), item 5 (flipbooks parados — conferir
   `podar_vfx.luau`/`FX.SpawnVFXTemplate` preservam `Flipbook*`), item 7 dos planos (Menu DEV → Administração:
   mensagem global via MessagingService, ban DataStore + kick, kick), item 5 dos planos (agarrão soldado no
   servidor + anim Shared/Grabbed), menus minimalistas, `AwakenedEffect` faltando em vários personagens,
   lista de animações/VFX/sons por ação (o `[Assets] não encontrado` do Output).

### O que foi feito em 2026-09-16 (tarde) — resumo
- MCP do Roblox Studio ligado (ver notas em CLAUDE.md e memória): leio o place, dou Play e leio o Output sozinho.
  Regras: conferir processos/modo antes de Play; nunca encadear sessões; apagar do place só com autorização.
- Altar/santuário do boss na posição do dono (gerador), ClanBoard criado. AnimCheck reconhece o rig do boss
  (Boss.Roar é R6 → precisa ser animado no BossModel).
- Fade de áudio; Swift Q = Piscar; teleport real; hit detection estilo TSB (previsão no clique + hitbox no
  cliente validada por caixa tolerante); sombras; EnvironmentService sem duplicar Bloom/fog zerado.
- Studio: 130k → 9,7k instâncias (packs apagados), plugins limpos, StreamingEnabled off, mapa de dia; 3,7 → 2,4 GB.
  WebView do Studio (Toolbox/Assistant) ainda come ~3 GB: fechar esses painéis.
- Cutscene do Despertar (aprovada, ajustes acima); sons da ult fixos e só ao ativar; assets por personagem
  para tudo (`Assets.ResolveFolder`).

### Onde estamos (resumo em 30 segundos)
- Jogo em mapa livre, 24 services / 15 controllers bootam limpos (Output 2026-09-16 00:10). Studio agora em
  **Team Create** ("Configuring as team test server") no place do grupo.
- Feito em 2026-09-16 e AINDA NÃO TESTADO pelo dono (ordem de teste sugerida abaixo): Idle/Walk do boss,
  placar de rating, agarrões Throw/Chokeslam/Spin, clãs, controles mobile/console + acessibilidade,
  guerra de clã (dominação), placar de clãs, 20 sons do dono, `packs/ParaImportar`.
- Animações do amigo coladas: M1_1..4, Shared/Idle (119477589200226), Brawler/GroundSlam (112109080090418),
  Boss/Idle (107074192710996), Boss/Swipe (71637199637001).

### 2026-09-16 (tarde) — MCP do Roblox Studio ligado
- Agora eu (Claude) dou Play, leio o Output e inspeciono o place sozinho (`run_code` = edição,
  `run_script_in_play_mode` = servidor do Play com os logs em JSON). Ciclo: editar → `tools/analisar.sh`
  → Play via MCP → ler boot. Testado: 24 services / 15 controllers, 0 erros.
- ATENÇÃO: o Studio estava aberto no place ANTIGO (85844807133499). Nele o altar está na posição
  padrão do gerador (altar 0,4.3,165 / spawn 0,1.5,195) — o altar movido só existe no place do grupo.
  Abrir o 126518739287432 para eu ler a posição nova direto do Studio (sem precisar copiar à mão).
- Descoberto via MCP: `Boss.Idle`/`Boss.Swipe` animam as partes `tripo_part_*` do BossModel (72 partes,
  rig custom do `BossRig`) → estão CERTAS; o AnimCheck avisava "rig misturada" errado. Corrigido:
  pasta `Boss` espera o rig do BossModel. `Boss.Roar` (139399523673215) é R6 → NÃO mexe o boss;
  a equipe precisa animar o Roar em cima do BossModel.
- `Shared/Block` e `Shared/Idle` com duração 0 continuam (esperado no place antigo; reconferir no do grupo).

### 2026-09-16 (tarde) — Studio pesado (3,7 GB RAM, VRAM cheia, crash ao abrir) — RESOLVIDO
- Causa: `Workspace.Textures` (21.559 instâncias do Particle Pack: 13.568 Parts, 4.306 Decals, 518 emissores,
  2.743 texturas únicas renderizando) e `ServerStorage.Import` (98.763 instâncias: 76.510 Poses dos
  KeyframeSequences + packs JJS/Shadow inteiros). Apagados via MCP (Ctrl+Z desfaz). 130.540 → 10.216 instâncias.
- A memória só cai depois de SALVAR e REABRIR (o histórico de Desfazer segura as instâncias apagadas).
- Plugins carregados: Rojo, Moon Animator 2, MCP, Ro-Defender. O Ro-Defender é inútil ("0 vírus removidos")
  e roda a cada Play — recomendo desinstalar. Nossos scripts somam só 929 KB.
- Sobrou no place: `Workspace.humanoider_20` (456, rig de animação da equipe?), `ServerStorage.BossModel - save`
  (backup), `RBX_ANIMSAVES` (Moon/Animation Editor), `BestWalkAnimR6`, `C00lkidd M4`, `Barriers` (vazios). Não mexi.

### 2026-09-16 (16:20) — ajustes do dono após ver a cutscene
- Sem som ao ENCHER a carga (HUD só mostra "ULT PRONTA — G"); sons da ult tocam ao ativar (cutscene).
- `Assets.FixedSounds` (Awakening, Awakening_Burst, Awakening_End, UltReady): nunca sorteiam variação `Nome2/3`.
  Socos/ataques continuam sorteando.
- **Assets por personagem para TUDO**: `Assets.ResolveFolder(kind, "Shared", name, character)` — se existir
  `Assets.Animations.<CharacterId>.<Nome>` (ou Sounds) com id, usa; senão Shared. Vale para M1_1..4, Hit,
  Block, Parry, Dash, Idle/Walk/Run (MovementController), sons. Basta a equipe criar a pasta/nome no
  `Animations.model.json` (ex.: Swift/Walk, Swift/M1_1). NPC/boss: atributo CharacterId no Model.
- Pendente do dono (item 7 dos planos): Menu DEV → Administração (mensagem global/servidor/jogador, ban, kick).

### 2026-09-16 (16:00) — Cutscene do DESPERTAR (decisão 1) — dono aprovou ("ficou top")
- Servidor (`AbilityService.onRequestAwaken`): G = cutscene de `CombatConfig.Awakening.Cutscene.Duration` (3,2 s):
  Stun("awakening") + atributo `CutsceneUntil` (WalkSpeed 0 no `restoreWalkSpeed`) + i-frames; no `BurstAt`
  (2,2 s) quem estiver a 12 studs leva 5 de dano + empurrão (`Hitbox.Around`); o modo (buff/kit) começa DEPOIS.
  A ult NÃO dispara mais sozinha: o slot com EnergyCost = Max fica liberado só no modo despertado.
- Cliente: novo `CutsceneController` (câmera Scriptable com órbita → estouro → volta; poses procedurais nas
  Motor6D R6 via C0 (carga 1/2/3 → estouro → guarda); sons Awakening (início) e Awakening_Burst; VFX
  `Shared/Awakening_Charge` (aura) e `Shared/Awakening_Burst` (onda Locust/Slam) novos em `Assets.VFXAliases`;
  contorno; shake). Outros jogadores veem corpo/efeitos, sem câmera. Morte/troca no meio desfaz tudo.
- Ajustar depois de ver: tempos em `CombatConfig.Awakening.Cutscene`, poses/câmera no `CutsceneController`.

### 2026-09-16 (15:30) — auditoria completa + hit detection novo
- Place limpo via MCP (autorizado): scripts alheios em SSS ("Blood after Player Dies", AssistantTestScript do MCP),
  Workspace "C00lkidd M4"/BestWalkAnimR6/Barriers, RS.GuiAnimatorPlugin, Lighting SunRays/DoF, "BossModel - save".
  Ficam: `Workspace.humanoider_20` (rig do amigo animando) e `ServerStorage.RBX_ANIMSAVES`. 9.714 instâncias.
- `StreamingEnabled = false` (mapa de 320 studs; evita pop-in e referências quebradas).
- Plugins: dono desinstalou os 39; Studio reaberto de vez → 2,4 GB (era 3,7). LuaHeap ainda ~550 MB
  (Moon Animator 2 = 11 MB de plugin, Rojo, MCP, Revix AI, GUI Copilot) — Revix/GUI Copilot são candidatos.
- `EnvironmentService`: reaproveita Bloom/Atmosphere do place (não duplica), zera fog, `OptimizeShadows()`
  (parts < 2,5 studs e invisíveis não projetam sombra; só 16 de 478 no mapa atual — ganho pequeno).
- **Hit detection estilo TSB** (feeling do soco): `CombatController.Attack` anima NA HORA do clique (previsão
  com combo/cooldown/stun locais, `pendingAttacks` evita animar 2×) e depois do `HitDelay` roda
  `Hitbox.InFront` NO CLIENTE e manda `RequestAttack(attackId, vítimas)`. `CombatService.resolveVictims`
  aceita só quem está na caixa tolerante (`CombatConfig.HitValidation`: Range×1.7, Width×1.7, Height×1.4)
  e resolve o dano na hora (cooldown descontado do HitDelay). Sem lista (cliente antigo) = hitbox estrita.
  Boot testado via MCP: 0 erros. FALTA o dono sentir em jogo (soco sai no clique? pega em quem anda?).

### PENDÊNCIA — plugins (2026-09-16, 14:45) — RESOLVIDA pelo dono (desinstalou tudo)
O dono clicou "atualizar tudo" e 39 plugins entraram na conta; a Roblox reinstala todos a cada abertura
(52 plugins carregados, LuaHeap 605 MB, Studio em 3 GB e 2 crashes `HangDetected` em Play). Movi as pastas
locais para backup mas voltaram. **Só resolve em Plugins > Manage Plugins > Uninstall**, um a um:
- REMOVER (entraram hoje 11:32): obby creator, Part Terrain Maker, NPC Creator, Infinite Scripter, Grass Fixer,
  FPS Viewport, Lighting Pro, Gui to Lua Converter, Lighting Shading Plugin, Developer Scripts Pack,
  Maor's Gui Animation, Tycoon Creator, FPS Visualizer, Simulator Generator, Future's Lighting,
  RBXMonkey Blender Animations, Tycoon Generator, Grass Brush, Legacy Animation Editor, Rain Plugin,
  Part to Terrain, ParticleEmitter:Emit(n) V2, Grass Decoration, Wall Creator, uiDesign Lite,
  Codes Otaku Cutscene, GUI Creator, Load Catalog Items, Surface Viewer, Edge Smoother,
  Complete Kit for Horror Games, Quick GUI Tools, Stravant Quick Stairs, Infinite Terrain, Prefab Placer,
  DBZ All Forms (624 erros por Play!), Grass Remover, Moon Animator Export Cutscene, Ro-Defender (se voltar).
- MANTER (já estavam antes): Rojo, Moon Animator 2, MCPStudioPlugin (locais), Building Tools F3X, Archimedes,
  Rig Editor, RigEdit Lite, Load Character Lite, VFX Suite, ParticleEmitter Scaler, Reclass, Auto Anchor,
  Add Easy Texture, Multi Tool. Candidatos a remover também (IA, pesados): Revix AI, GUI Copilot.
Depois: fechar e reabrir o Studio e eu meço de novo (meta: < 1,5 GB, LuaHeap < 150 MB).

### Feito 2026-09-16 (tarde) — itens 2, 3 e 4 das decisões
- **Fade de áudio** (`FX.playClone`): Volume 0→alvo em `FX.SoundFadeIn` (0,15 s) e alvo→0 nos últimos
  `FX.SoundFadeOut` (0,3 s), via TweenService; sons curtos (< 0,45 s) e em loop não fazem fade-out.
- **Swift: Q = Piscar** (`CharacterDefs.Swift.DashOverride`): Blink saiu do slot 1 (Rasteira virou 1, Tempestade 2);
  `MovementService` vê `GetDashOverride(CharacterId)` no RequestDash → teleporta; cooldown único de 5 s
  mostrado no slot do Q (HUD esconde o slot lateral e escreve "Piscar"). FX via NotifyAbility "Blink"/Teleported.
- **Teleport real** (`MovementService.Teleport`): atravessa obstáculos, encaixa no chão do destino
  (mantém a altura sobre o chão); usado pelo Q do Swift e por `effects.Teleport` (Overlord/Warp).
  Testado via MCP: 18 studs exatos, atravessou o BossPillar0, Y ajustado ao chão.
- Fade-in testado via MCP (0 → 0,48 em 0,1 s). FALTA: fade-out (ouvir), Swift Q = Piscar em jogo, Warp do Overlord.
  `Shared/Death` carregou com duração 0 (id não carrega). Spawn: servidor viu o boneco parado em (110, 4.55, 0)
  com estado FallingDown por 6 s no play automático — perguntar ao dono se nasce em pé.
- Cuidado com o MCP: `run_script_in_play_mode` encadeado (um atrás do outro) derrubou o Studio; esperar
  a sessão anterior terminar de verdade (get_studio_mode = stop) antes de iniciar outra.

### DECISÕES DE DESIGN do dono (2026-09-16, madrugada) — aplicar na próxima sessão
1. **ULT = cutscene/transformação, não um ataque.** G ativa uma animação/cutscene que TRANSFORMA o
   personagem (despertado) e, transformado, ele mostra ATAQUES DIFERENTES (kit alternativo, não só buff).
   Hoje `RequestAwaken` dispara a última habilidade + buff; precisa virar: cutscene (câmera + animação
   `<Char>/Awakening`) → estado despertado com habilidades `AwakenedEffect`/kit próprio.
   Sons da ult (`Awakening`, `Awakening_Burst`) tocam **quando ATIVA a ult (G)**, não quando a carga
   libera (`UltReady` fica só para "carga cheia", mais discreto ou nenhum).
2. **Áudio com fade-in/fade-out** (principalmente os gritos): `FX.playClone` deve fazer Volume 0→alvo
   em ~0,1–0,2 s e alvo→0 nos últimos ~0,3 s (TweenService) para não ficar seco.
3. **Swift NÃO tem dash**: trocar o dash universal (Q) do Swift pelo **Piscar** (teleport) — é uma troca:
   Q = Blink para o Swift, e o slot 1 dele ganha outra habilidade (ou some). `MovementController.Dash`
   /`MovementService` precisam checar `CharacterId == "Swift"` → teleport.
4. **Teleport de verdade** (Swift/Blink e Overlord/Warp): distância predefinida, atravessa o que estiver
   na frente (sem raycast travando na parede), como um "dash melhor". Hoje `effects.Teleport` faz raycast
   e para antes do obstáculo.
5. **Agarrões**: "não estão segurando de verdade com sincronia" — a vítima não fica colada no atacante
   de forma consistente (posição só no cliente da vítima; outros veem atraso). Fazer: servidor solda a
   vítima (WeldConstraint/Motor6D HRP→HRP com offset, `PlatformStand`) durante o Carry e desfaz no fim;
   animações de quem bate (`<Id>_Carry`) E de quem apanha (`Shared/Grabbed`, novo).
6. **Menus**: sobreposições, erros visuais e falta de espaço; deixar mais minimalista/moderno (ver
   `tools/gerar_ui.py`; conferir Perfil 560×460, Controles 640×560, Clã 420×440, Cosméticos, Loja,
   Personagens — no Device Emulator também).
7. **Menu DEV → submenu Administração**: mensagem global (todos os servidores, MessagingService),
   mensagem só do servidor, mensagem para um jogador; ban (DataStore de banidos + kick no PlayerAdded),
   kick, e o resto de admin (mute? teleport para jogador, dar/tirar pontos já existe).
8. **Depois disso**: escolher VFX, sons e criar animações para CADA ação, cutscene e ataque (lista
   completa dos buracos = linhas "[Assets] não encontrado" do Output: Awakening de todos os personagens
   (anim/VFX/som), Shared Dash/Uppercut/Downslam/Hit/Parry, Swift Blink/SweepKick, Mystic ArcaneBolt/
   Mend/Meteor, Guardian Quake/Fortify/ShieldBash_Carry, Sahur Bombo/Toque/Ritmo, Overlord tudo,
   Emotes, Boss Slam/Charge/Shockwave/Leap/Walk, Sons Brawler Rampage_Hit, Overlord *).

### Bugs/observações do Output de 2026-09-16 00:10–00:19
- `Shared/Block` (113541104537435) e `Shared/Idle` (119477589200226, do amigo) carregaram com **duração 0**
  → não são do grupo (ou R15). O Block é id antigo; o Idle do amigo precisa ser republicado com o grupo
  como criador (ou o amigo exportou em R15). Os M1 do amigo não deram aviso → ok.
- `[LeaderboardService] Part ClanBoard não encontrada` — esperado até regenerar o ArenaExtras (abaixo).
- Guardian Esmagar contra boneco: "hit 3.9 ×2, finisher 18.2" — o chokeslam funcionou (dano+área).
  Overlord Giro: "hit 39, finisher 39" — ok. Falta a sincronia visual (item 5).

### Altar do boss — RESOLVIDO (2026-09-16, tarde)
- Posição do santuário lida via MCP e gravada em `tools/gerar_arena.py` (`SANCT_WORLD = (97.75, 0.6, 231.625)`,
  `SANCT_YAW = 180`); todas as partes `Boss*` são transformadas em bloco. ArenaExtras regenerado, `ClanBoard` criado.
  Para mover de novo: mudar `SANCT_WORLD`/`SANCT_YAW` e rodar o gerador (não mover no Studio).

### Ordem sugerida da próxima sessão
1. Pedir posição do altar → gerador → regenerar ArenaExtras (ClanBoard junto).
2. Itens 2, 3, 4 das decisões (fade de áudio, Swift = Blink no Q, teleport real) — pequenos.
3. Item 5 (agarrão soldado no servidor + animação da vítima).
4. Item 1 (ULT como cutscene/transformação com kit próprio) — maior; combinar com o dono o kit despertado
   de cada personagem antes de codar.
5. Item 7 (admin) e item 6 (menus).
6. Item 8 (assets por ação) — depende da equipe/packs (`packs/ParaImportar/LEIA-ME.md`).
7. Testar o que ficou de 2026-09-16 (roteiros nas seções abaixo).

### Boss — rig CONFIRMADO (2026-09-16)
- `Studio()` no place salvo deu **27 Motor6D, 0 soldadas**, raiz `tripo_part_46`, juntas Neck/Right
  Shoulder/Left Shoulder/Right Hip/Left Hip → rig persistiu. `FaceOffset = 90` confirmado (anda de frente).
- O dono está animando o boss no Animation Editor. Swipe já tem id (112099038975315). Faltam:
  Slam, Charge, Roar, Shockwave, Leap, **Idle, Walk** (novos em `Animations.model.json` → `Boss`).
- **Idle/Walk do boss agora tocam** (`BossController.attachLocomotion`): servidor manda `model` no
  "summoned"; cliente toca Idle (prioridade Idle, loop) e liga/desliga Walk (Movement) pela velocidade
  horizontal do HRP (> 1,5). Id vazio = não toca. NÃO testado ainda (sem ids).

### packs/ParaImportar (2026-09-16)
- Tudo dos packs que precisa ir para o grupo foi movido para UMA pasta: `packs/ParaImportar/{Animacoes,Audios,VFX,Modelos}`,
  arquivos com prefixo do pack (`JJS_`, `SBG_`), + `LEIA-ME.md` com o passo a passo por tipo e a sugestão de uso.
  Tools atualizadas (`juntar_animacoes`, `podar_vfx`, `extrair_pack`, `limpar_sons_packs`). Áudios do dono (20 mp3,
  extensões completadas) estão em `Audios/` aguardando upload no grupo → ids.

### Guerra de clã — DOMINAÇÃO (2026-09-16, NÃO testado)
- `WarConfig`: 2 clãs, cópia da `Arena_Gerada` em (-4000,1500,4000) (região própria, 2 simultâneas),
  pontos A/B/C (pasta `CapturePoints` nova em `gerar_arena.py`: cilindros neon em x=-100/0/100),
  captura = 1 time sozinho por 5 s, 1 ponto/s por ponto dominado, 300 pontos ou 5 min, MinPerSide=1 (subir
  depois dos testes), MaxPerSide=6, respawn no spawn do time (Player.RespawnLocation) com 2 s de proteção.
  Recompensa: 80/25 pontos por jogador, 250/60 no cofre, `clan.wins` +1.
- `WarService`: `RequestWar("queue"|"leave"|"refresh")` (líder/oficial; leva os membros online e livres do
  MESMO servidor); com 2 clãs na fila começa. `NotifyWar`: queue/start/state(1/s)/end/denied.
  Quem sai do servidor conta como fora; time vazio = derrota.
- Cliente: `WarGui` (barra no topo: tags, pontos, timer, chips A/B/C coloridos com barra de captura; banner),
  `WarController`; botão **GUERRA** no ClanGui (vira "NA FILA #n ✕" para sair).
- Teste (2 clientes, cada um num clã diferente; Studio precisa de 2 jogadores em 2 clãs, então: cliente 1
  funda clã X, cliente 2 funda clã Y; cada um clica GUERRA): banner "colocou o clã na fila", ao segundo
  entrar os dois vão para a arena no céu, contagem 5 s, barra no topo; ficar no anel A por 5 s pinta de
  azul/vermelho e o placar sobe 1/s; morrer renasce no lado do time; ao acabar (300 ou 5 min ou um lado
  vazio) banner de vitória, pontos e cofre (Clã > cofre) sobem, volta ao mapa.
- **Placar por clã** (2026-09-16): 3º board no `LeaderboardService` (`clans`, OrderedDataStore
  `Leaderboard_ClanWins_v1`, chave = tag, `ClanService.AddWin` → `PublishClan`), painel `ClanBoard` em
  (0, 5.5, −76) no gerador — **ArenaExtras NÃO foi regenerado** porque o dono moveu o altar no Studio
  (pedir a Position nova do BossAltar/BossSpawn/BossArena, gravar em `gerar_arena.py`, aí regenerar;
  até lá o placar de clãs só publica e avisa "Part ClanBoard não encontrada").
- Sons do dono (20 ids) ligados 2026-09-16 (`Sounds.model.json`): Awakening(+2), UltReady(1–3),
  Awakening_Burst(1–3, toca na ultimate), Awakening_End(1–3, fim do despertar), GroundSlam/Bombo/Slam_Hit(+2),
  Quake/Shockwave/WallSplat(+2), Rampage(+2), Toque, Boss Roar/Charge. `Assets.GetSound` sorteia `Nome`,
  `Nome2`, `Nome3`...
- Faltam: MessagingService para clãs em servidores diferentes, mapa próprio de dominação, fila cross-server.

### Animações do boss não tocaram (2026-09-16) — causa provável
- O log do Studio mostra a sessão de Play no place **85844807133499 (o antigo)**, não no oficial de grupo
  126518739287432. Animações publicadas no grupo carregam com duração 0 fora do place do grupo (sem erro
  no Output). Boss.Idle/Swipe foram encontradas e carregadas — só não mexeram nada.
- `FX.PlayAnimation` agora avisa em Studio: "[FX] animação X carregou com duração 0: id errado ou sem
  permissão". Se aparecer no place certo, o problema é o id/criador da animação; se não aparecer e ainda
  não mexer, é o rig (poses do KeyframeSequence vs nomes das partes).

### Controles mobile/console + acessibilidade (2026-09-16, NÃO testado)
- `Controls.luau` = fonte única dos controles por dispositivo (`ActionOf(input)`, `Label(action, device)`).
  Combat/Movement/Ability/Cosmetics/Topbar não comparam KeyCodes soltos mais.
- Gamepad (layout do Jujutsu Shenanigans): B soco (segurar = combo) · X block · Y dash/levantar ·
  LB/LT/RT/RB = golpes 1–4 · D-pad ↑ ultimate · D-pad ↓ emotes · R3 shift lock · Back placar · D-pad →
  navega os ícones do topo (TopbarPlus `highlightKey`) · A pulo (nativo).
- HUD: rótulo dos slots/dash/ult muda conforme o último input (1-4/Q/G ↔ LB/LT/RT/RB/Y/D↑; toque = vazio).
- Mobile (`tools/gerar_mobilegui.py`, `MobileController`): SOCO segurar = combo, BLOCK, DASH, 1-4 em arco,
  ULT, **EMOTE** (roda), **LOCK** (shift lock; `MovementController.SetShiftLock` agora funciona no toque),
  CORRER. Botões têm atributos BaseX/BaseY/Side para espelhar.
- Acessibilidade (`Controls.Settings`, salvas em `profile.settings` via `RequestSetting` → `SettingsService`;
  cliente `SettingsController`, lista no painel Controles): segurar soco = combo (on/off), block alternar
  em vez de segurar, tremor de tela (`FX.ShakeEnabled`), vibração no controle (`FX.Haptic`, HapticService),
  tamanho/opacidade/canhoto dos botões de toque.
- Limitação: a roda de emotes ainda não é navegável pelo controle (só abre/fecha com D-pad ↓; escolher
  precisa de GuiService.SelectedObject — depois).
- Teste: (1) teclado: nada mudou (M1/F/Q/1-4/G/B/Shift/Tab). (2) Controle no Studio (ou emulador de
  gamepad): B/X/Y/bumpers/gatilhos/D-pad conforme acima; HUD mostra LB/LT/RT/RB; D-pad → seleciona os
  ícones do topo; Back abre o placar. (3) Device Emulator (celular): 11 botões, segurar SOCO faz o combo,
  LOCK gira o boneco com a câmera, EMOTE abre a roda; Controles > configurações: Grande/opacidade/canhoto
  mudam na hora e persistem ao relogar. (4) "Bloquear: alternar" ligado: F/X/BLOCK uma vez liga, outra
  desliga.

### Clãs — fundação da guerra de clã (2026-09-16, NÃO testado)
- `ClanConfig` (500 pts para fundar, 20 membros, tag 2–4 alfanumérica = id único, depósito mín. 10,
  convite expira em 30 s, cargos member/officer/leader).
- `ClanService`: DataStore `Clans_v1` (chave `clan_<TAG>`, toda mutação por UpdateAsync → funciona com
  vários servidores). Ações `RequestClan`: create(nome, tag) · invite(userId, só online no mesmo servidor,
  líder/oficial) · accept/decline · leave (líder não sai) · kick/promote/demote (líder promove
  membro→oficial→líder, passando a liderança) · deposit(pontos → cofre) · disband (líder) · refresh.
  `NotifyClan`: state { clan, role } · invite · denied · info. `profile.clanTag` é só cache: ao entrar,
  o registro é lido e, se o jogador não está mais nele, limpa. API: `GetTag/GetClan/AddToVault`.
- Nome sobre a cabeça: `CharacterService.DisplayNameFor` = "[TAG] [Título] Nick" (atributo `ClanTag`),
  `RefreshDisplayName` aplica sem respawn.
- UI: `ClanGui` (gerar_ui.py; `textbox`/`scroll` novos no gerador), ícone "Clã" (**C**) no topbar,
  `ClanController` (sem clã: fundar/convite Y-N; com clã: abas Membros/Convidar, selecionar membro →
  promover/rebaixar/expulsar, depositar, sair, dissolver com 2 cliques).
- Limitação conhecida: expulsão/dissolução só chega a quem está no MESMO servidor na hora; os outros
  veem ao relogar (MessagingService fica para depois, junto com a guerra).
- Teste (API Services ligado; dev: dar 500+ pontos): C → nome+TAG → FUNDAR → nome vira "[TAG] Nick",
  painel mostra cofre/membros. 2º cliente: aba Convidar → clique → no outro aparece convite (Y aceita)
  → entra como Membro. Líder seleciona o membro → PROMOVER (Oficial) → PROMOVER de novo (vira líder,
  você vira oficial). DEPOSITAR 50 → cofre sobe, pontos descem. SAIR / DISSOLVER (2 cliques).
  Relogar: clã continua. Tag duplicada, nome curto, sem pontos → mensagens vermelhas.
- Próximo (guerra): mapa de dominação, portal/fila por clã, zonas de captura, rodada com tempo, vencedor,
  recompensa no cofre (`AddToVault`) e placar por clã. Reaproveita MatchService (Teams, FreeRoam=false).

### Agarrões variantes (2026-09-16, NÃO testado) — decisão do dono: Throw, Chokeslam, Spin nos 3 que já tinham
- `Effect.Finish` no Grab (`AbilityService.effects.Grab`): `Slam` (antigo) | `Throw` | `Chokeslam` | `Spin`.
  Ids das habilidades NÃO mudaram (animações/VFX continuam por nome: `<Id>`, `<Id>_Carry`, `<Id>_Hit`).
  - Brawler `ShoulderBash` = **Arremesso** (Throw): segura 0,8 s e lança para onde o atacante olha
    (Knockback 70, Up 25, ragdoll 1,8; wall splat conta).
  - Guardian `ShieldBash` = **Esmagar** (Chokeslam): ergue 5 studs (`Lift`) por 0,8 s, esmaga (14 +
    ragdoll) e área de 8 studs (10 de dano + empurrão) onde a vítima cai (`Position` no "hit" → VFX
    `ShieldBash_Hit` no ponto).
  - Overlord `Clutch` = **Giro Devastador** (Spin): vítima orbita 1,25 volta/s por 1,6 s; a cada 0,3 s quem
    está a 9 studs toma 6 + empurrão; solta na TANGENTE (`HitOptions.KnockbackDirection`, novo em
    `CombatService.ResolveHit/Knockback`) com 30 + ragdoll 2,5.
- Cliente (`AbilityController.startGrabbed`) recebe `Lift`/`Spin` no "grab" e posiciona a vítima
  (mesma fórmula do servidor: `aRoot.CFrame * Angles(0, θ, 0) * (0, lift, -offset)`).
- Teste: cada um contra o boneco/2º cliente. Throw: girar a câmera durante o carry muda para onde ele
  voa; perto de parede = "PAREDE". Chokeslam: vítima sobe no ar, cai no chão à frente; 2º boneco ao
  lado toma a área. Spin: vítima gira ao redor (visível nos dois clientes), 2º boneco perto toma ticks;
  ao soltar ela voa na direção do giro (não para trás nem para frente do Overlord).

### Placar global de rating 1v1 (2026-09-16, NÃO testado)
- `LeaderboardService` generalizado em 2 boards: `kills` (OrderedDataStore `Leaderboard_Kills_v1`, Part
  `LeaderboardBoard`) e `rating` (`Leaderboard_Rating_v1`, Part `RatingBoard`, publicado só depois do 1º
  duelo, i.e. rating ≠ 1000). `RatingBoard/Base/Frame` novos no `ArenaExtras` em x=+30 (espelho do de
  kills em x=−30, z=−70) — se ficar em cima de algo do mapa, mudar a posição em `tools/gerar_arena.py`
  (não no Studio: o Rojo sobrescreve).
- `NotifyLeaderboard` agora manda `{ kills = rows, rating = rows }` (rows `{name, value}`); Perfil (P)
  mostra top 5 de cada (labels `Top` e `TopRating`; painel 560×460).
- Teste: dois clientes, duelo 1v1 até o fim → dev "RefreshLeaderboard" → painel de rating e Perfil
  mostram o vencedor (precisa de "Enable Studio Access to API Services").

### Estado do boss com modelo 3D (sessão anterior)
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
1. ~~Conferir rig do boss salvo + FaceOffset~~ (feito 2026-09-16); encaixar animações que a equipe mandar
   (Boss incl. Idle/Walk, Emotes, Dash/Downslam/Uppercut/Parry/Hit do Shared).
2. Bugs do 3º teste (pedir).
3. Roteiros de teste pendentes abaixo (leva 2, leva 3, fases 4 e 5) — nada disso foi validado ainda.
4. Depois: ~~placar global de rating~~ (feito, testar), ~~mais agarrões~~ (Throw/Chokeslam/Spin feitos, testar), ~~Idle/Walk do
   boss~~ (código pronto, faltam ids), e a **guerra de clã/dominação**: clãs + modo dominação feitos 2026-09-16 (testar); falta placar por clã e cross-server.


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

## 2026-09-23 — Preparação da Central IA (sem alteração de gameplay)

- PlaceId `85844807133499` confirmado pelo dono e associado ao `default.project.json` na Central IA.
- Adicionado `src/shared/CentralProjectMarker.luau` para identificar este projeto na futura verificação de alvo. `rojo build` e `rojo sourcemap` passaram; o marcador aparece em `ReplicatedStorage.Shared`.
- A cópia local recente `copia/Copia2.rbxl` foi duplicada no backup privado da Central com hash idêntico. A pasta `copia/` passou a ser ignorada pelo Git, sem mover ou excluir as cópias originais.
- `rojo serve` foi iniciado pela Central em porta local dinâmica. **Pendente:** abrir a cópia no Studio, verificar restauração e alvo ao vivo, conectar o plugin Rojo e testar duas janelas. Escrita direta MCP/Open Cloud e publicação permanecem desligadas para este projeto.
