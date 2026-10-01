# Verificação local sem Studio

Execute na raiz do projeto:

```sh
lune run tests/profile_store.luau
lune run tests/gameplay.luau
lune run tests/builds.luau
lune run tests/story_expansion.luau
lune run tests/sidequests.luau
lune run tests/cidade_ambar.luau
lune run tests/costa_dourada.luau
lune run tests/fortaleza_mare.luau
lune run tests/bounty.luau
lune run tests/factions_hunts.luau
lune run tests/npc_relics_navigation.luau
bash tools/analisar.sh
```

`profile_store.luau` executa o módulo real de persistência com um DataStore em memória, callbacks repetidos e falhas antes/depois de gravações. Verifica sessões concorrentes, snapshots, conservação de itens/moedas e recuperação de decisões de troca após interrupções.

`gameplay.luau` carrega módulos reais por `runtime.luau`, que substitui somente serviços Roblox e dependências necessárias. Verifica migração/tutorial, escolhas, consumo de itens, PvP, XP/loot, contribuição ao chefe, probabilidades e callback real de recibos. O teste de recibo imprime intencionalmente um aviso de falha de save.

`builds.luau` verifica as três rotas da Missão 2, Flecha única, recuperação de perfis antigos, escolha/evolução da Missão 8, bônus autoritativos, maestrias separadas e ciclo do Tool com instâncias simuladas.

`story_expansion.luau` verifica a migração dos 20 atos rev3 e de rev2, Eco do Deserto, rota liberada somente após escolher, puzzle por jogador com distância/vida, reconexão, Eco opcional de saves antigos e sequência Viajante → Rastro → Observador.

`sidequests.luau` verifica acesso pelas escolhas dos Ecos, investigação/entrega, recompensa única, reconexão, independência entre jogadores, conservação do ato da campanha e apresentação pessoal de NPC/prompts pelo controller real com instâncias simuladas.

`cidade_ambar.luau` verifica migração rev4, chegada, objetivos distintos, revelação somente após fotografia/confronto, portas de interação, padrão investigativo, acusação errada recuperável, contribuição ao chefe e três caminhos do Eco. Também executa `BindMap` com mapa/raycast simulados para recusar mapa incompleto, sobreposição, raios inválidos e chão ausente, e conferir registro/remoção de região/checkpoint/zona segura sem alterar outras ilhas. Confere também fallback de spawn para mapa indisponível sem apagar o checkpoint persistido.

`costa_dourada.luau` verifica migração dos 30 atos rev5, lotes distintos, força com kills PvE, furtividade em ordem, acesso social por favor, reconexão/persistência dos caminhos, registros, C-8, boss por contribuição e os três Ecos. Executa o registro real com mapa/raycast simulados para rejeitar chão ausente nos guardas e evitar duplicação de região/prompts/bots.

`fortaleza_mare.luau` verifica migração rev6, escolha/abertura tardia de alas, loops/Rastro, colapso com chefes distintos, ordem Toduro/Adryan, participação/vida/âncoras antes da derrota, segredos para dispositivo, três métodos e execução/epílogo, reconexão e interação inválida. Também registra/remove mapa simulado sem duplicar os três bots.

Esses testes não executam física, replicação, interface, DataStore da Roblox ou compras reais. Não substituem testes com dois clientes e validação visual no Studio. Não usam credenciais nem modificam dados de produção.

`factions_hunts.luau` verifica escolha de facção/estado do menu, conservação de progresso, honra contra Fora da Lei,
deduplicação, aceitação e pagamento real de contratos por sinal de reputação, ausência de GPS, cancelamento/saída/
expiração, limites/validação de vida/números, bloqueio servidor de NPC contra NPC, aparência genérica e metas reais
de forja/maestria/títulos. Confere também que o requisito de nível da campanha permanece e dispara aviso ao subir.

O adaptador inicializa a progressão ao preparar campanha e simula sinais de atributos como o boot real. Testes de
sequência avançada usam nível suficiente; não removem requisitos do código para avançar artificialmente.

`bounty.luau` verifica títulos/limiares, crédito/contexto, níveis pelo perfil, cooldown migrado após reconexão, rejeição de valores inválidos, limites, bônus único e replicação de atributos. Usa serviços reais de bounty/PvP com morte e persistência simuladas; não verifica o ciclo de morte completo do Studio nem save de produção.

`npc_relics_navigation.luau` verifica tempos de respawn/regen por tipo de NPC, rejeição de entradas inválidas
no navio, sequência das lentes, recompensa única/reconexão/independência entre jogadores, distância/vida/fallback,
marcador forjado e orientação da campanha sem revelar segredos opcionais. A expansão da campanha também cobre o
Selo Solar único e a recuperação de saves que já resolveram a Câmara.

Verificação no Studio: em Edit, executar `tools/studio/preparar_verificacao.luau` pelo MCP; depois iniciar Play.
Os módulos de aluguel usam perfil simulado (1.000 moedas), mantendo o perfil do dono. O cliente controla o
assento de teste pelo remote real. Os scripts temporários ficam fora da árvore de código do Rojo e DEVEM ser
removidos em Edit após Stop: `ServerScriptService.VerificacaoStudioTemporaria`,
`ServerScriptService.VerificacaoServicosIsolados`, `StarterPlayerScripts.VerificacaoClienteTemporaria`.
O harness oculta o menu de facção para a captura sem escolher/salvar facção. Desloca o personagem para testar
embarque/desembarque e repõe sua posição; não concede moedas, itens ou reputação ao perfil real.
