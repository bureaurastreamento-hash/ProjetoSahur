# Plano de migração — Battlegrounds para RPG open-world F/X

Status: proposta técnica, sem mudanças destrutivas autorizadas.

## Princípios

1. Preservar combate, save, UI e modos funcionais.
2. Construir o RPG ao lado do battlegrounds até o vertical slice ser melhor que o loop antigo.
3. Toda progressão e recompensa continua autoritativa no servidor.
4. Conteúdo narrativo é dirigido por configuração, não espalhado em Services.
5. PvP aberto no mundo com proteções (zonas seguras, proteção de nível/respawn, combat log), Coliseu para ranking; a campanha dá propósito e o mundo (farm, sidequests, PvP, eventos) dá replay — ver `ESTRUTURA_JOGO.md`.
6. Cada universo inspirado recebe identidade visual, nomes e personagens originais.

## Arquitetura alvo

- `WorldConfig`: universos, regiões/ilhas, faixa de nível, checkpoints, conexões e bosses.
- `StoryConfig`: sete capítulos, atos, pré-requisitos, flags, diálogos, rastros e recompensas.
- `WorldService`: entrada em região, checkpoint, respawn seguro e descoberta.
- `StoryService`: estado narrativo, escolhas/flags e integração com quests/cutscenes.
- `EnemyConfig` + evolução de `BotService`: famílias de inimigos, nível, loot e escalonamento.
- `Power/Loadout`: separa identidade do avatar do kit de combate, preservando `AbilityService`.
- Expansão compatível do perfil: `world`, `story`, `inventory`, `powers`; migração tolerante e rollback por versão.

## Fases

### Fase 0 — congelar e proteger

- Fazer backup verificável do place e registrar baseline de testes.
- Não renomear IDs persistidos nem remover sistemas.
- Marcar a quest antiga como `legacy`, mantendo-a selecionável durante desenvolvimento.

### Fase 1 — vertical slice do Capítulo 1

- Uma ilha/região inicial original inspirada na energia de uma primeira era de JoJo, sem copiar mapa ou personagens.
- Tutorial integrado à história com Humanoider_20.
- Movimento, combate, defesa/parry, poder inicial, quest, inimigo comum, elite e boss.
- Um Rastro de Carlos opcional e um sinal discreto de Adryan.
- Checkpoint, recompensa, save e portal bloqueado para a próxima região.
- Arena PvP acessível por portal/menu, usando os sistemas existentes.

Critério de saída: jogador novo completa sozinho do spawn ao boss, reconecta sem perder progresso e pode voltar à arena sem quebrar o save.

### Fase 2 — fundação escalável

- Quest graph e diálogos/cutscenes por dados.
- Regiões múltiplas no Capítulo 1, correspondendo a eras/temporadas reinterpretadas.
- Inventário, drops, equipamentos e progressão de poder definidos com economia própria.
- Ferramentas de spawn/validação de NPCs e regiões.

### Fase 3 — capítulos 2 e 3

- Cap. 2 Adryan: quests agradáveis e recompensas excelentes; variáveis ocultas alimentam sua evolução.
- Cap. 3 ToduroDemais: quests duras treinam atributos e domínio do player; sua aparência suspeita é intencional.
- Telemetria de dificuldade e economia antes de produzir os demais mundos.

### Fase 4 — capítulos 4 a 6

- Lry, Approx e Fred; cada universo introduz uma variação sistêmica, não apenas outro cenário.
- Distribuir Rastros de Carlos e montar a investigação sem revelar cedo demais o assassino.
- Encontro Fred vs. Toduro e resgate de Approx pelo Cientista da Fratura.

### Fase 5 — Capítulo 7 e endgame

- Universo de Origem, Ravy, Ponto Zero, Apex de Adryan e sacrifício de Toduro.
- Endgame reutiliza bosses, exploração, arena, torneio, clãs e eventos.

## Primeira implementação recomendada

Antes de editar gameplay, produzir um documento de design do vertical slice com: mapa da região, duração alvo, sequência de quests, inimigos, boss, recompensas, poder inicial, telas afetadas e migração do perfil. Depois implementar nesta ordem: configs → save → WorldService → StoryService → conteúdo mínimo → UI → testes no Studio.

## Fora de escopo por enquanto

Apagar a arena antiga, converter todos os personagens, refazer todas as UIs, produzir sete mundos de uma vez, rebalancear monetização ou publicar. Essas decisões só vêm após o vertical slice.
