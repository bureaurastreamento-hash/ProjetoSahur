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

`bounty.luau` verifica títulos/limiares, crédito/contexto, níveis pelo perfil, cooldown migrado após reconexão, rejeição de valores inválidos, limites, bônus único e replicação de atributos. Usa serviços reais de bounty/PvP com morte e persistência simuladas; não verifica o ciclo de morte completo do Studio nem save de produção.
