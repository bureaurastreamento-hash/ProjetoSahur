> Registro da auditoria anterior às correções. Para o estado atual, consulte a seção “Correções da auditoria” de PROGRESSO.md. Linhas e achados abaixo descrevem o momento da análise. Nesta conversa o dono autorizou publicação por API; ela não ocorreu porque a leitura do place completo retornou 403.

# Auditoria e próximos passos — Bizarre Showdown F/X

Análise de 29/09/2026, sobre o checkout no commit `976ac86`. Este relatório registra achados e recomendações; não implementa correções nem muda a direção aprovada.

## Escopo e limites

- Inventário de todos os Services, Controllers e Modules próprios: 52 serviços, 31 controllers e 41 módulos, totalizando 40.874 linhas nesses três diretórios. Inspeção das integrações críticas, configs, boot, manifest Rojo, ferramentas e catálogos de assets.
- Direção conferida em `BIZARRE_DIRECAO.md`, estrutura do jogo, mapa, campanha e trechos pertinentes do cânone. Histórico confrontado com código, especialmente as últimas entregas de 29/09.
- `bash tools/analisar.sh` executado sobre todo `src/`: falhou com **dois erros de tipo distintos**, repetidos nas dependências, e dois avisos de variáveis não utilizadas.
- Não houve teste jogável nesta auditoria, inspeção visual do place nem medição de FPS/rede. O log local mais recente consultado não forneceu evidência de um Play atual completo. A consulta de conexões por `ss` foi impedida pelo sandbox; conexão Rojo não confirmada.
- Assets existentes somente no Studio, permissões efetivas dos áudios/animações e configuração publicada não foram certificados. Não foi feito build para publicação, publicação ou alteração de arte.
- Não é uma certificação de ausência de bugs ou auditoria linha a linha de todos os efeitos/terceiros.

## Diagnóstico

Existe uma base substancial de combate e infraestrutura. A migração para RPG já trouxe mundo, campanha, Stands e inventário, mas suas integrações ainda deixam falhas na entrada do jogador e no ciclo de recompensa. Recomendo fechar uma primeira ilha consistente e repetível antes de multiplicar regiões.

| Área | Evidência no código | Situação |
|---|---|---|
| Combate | Combat/Ability/Movement/Health/Ragdoll/Counter, bots usando os mesmos sistemas | Base existente; preservar e testar com dois clientes e latência |
| Arquitetura | Init/Start, isolamento por pcall, remotes centralizados, configs compartilhadas | Boa base; boot conta módulos carregados, não certifica que todos os Init/Start funcionaram |
| Mundo | WorldConfig/WorldService, portais, Pescador, três serviços de ilha | Três ilhas de campanha; Cidade Âmbar e posteriores ainda não implementadas como regiões |
| História F/X | StoryConfig rev3, 20 atos incluindo escolhas e espera pela Ilha 4 | Ilha 1 com conteúdo substancial, mas entrada e objetivo de combate têm bugs; Ilhas 2–3 parciais |
| História antiga | QuestService/QuestConfig/TraitorService continuam no boot | Conflito narrativo e dois fluxos de objetivos simultâneos |
| Build | StandService, quatro Stands na Flecha, inventário, maestria | Armas/estilos/acessórios e efeitos de raça ainda não compõem a build aprovada |
| Farm | Bots renascem; boss legado tem BossLootService | Falta integrar XP/moedas/drop aos mobs e chefes da campanha; respawn de bot não equivale a Echo Boss completo |
| PvP social | Mapa livre, duelos, rating, clãs, guerras, torneio | Faltam zonas seguras do RPG, proteção pós-morte PvP, elegibilidade por progressão e bounty/contratos |
| Interface | HUD lateral, mochila, história, controles mobile e gamepad | Implementado; novos painéis têm dimensões fixas e exigem validação em telas pequenas |
| Operação | Administração, denúncias, configurações, mods privados | Reaproveitar; revisão humana dos ModuleScripts dos mods continua necessária |
| Assets | 63 entradas de animação, 27 com ID vazio; 96 sons, nenhum ID vazio | IDs vazios não provam ausência de animação: há fallback procedural. Áudio com ID não prova acesso/tocabilidade |
| Monetização | ShopService e catálogo | IDs de produtos/passes estão zerados; tratamento de recibos precisa correção antes de ativar |

## Achados prioritários

### 1. Missão dos Vagantes escuta o evento errado — bloqueio de campanha

`src/shared/Modules/StoryConfig.luau:93` pede `kills` para “Derrote 3 Vagantes”. Os Vagantes nascem com `StoryKillKind = "fx_tutorial_enemy"` em `TutorialIslandService.luau:163`, e `StoryService.luau:307` repassa esse identificador sem convertê-lo. O contador `kills` vem das mortes de jogadores em `ProgressionService.luau:189`.

Consequência deduzida do fluxo: derrotar os mobs indicados não completa esse objetivo; matar jogadores na mesma ilha pode completá-lo. Corrigir o vínculo específico da missão, preservando a distinção entre PvE e PvP.

### 2. Perfil novo pula a Missão 0 — bug de revisão

`DataConfig.luau:104` cria `story.rev = 2, act = 1`, enquanto `StoryConfig.Revision = 3`. A migração em `StoryService.luau:49` converte ato 1 antigo em ato 2 novo. Assim, um perfil realmente novo entra em “Você não deveria estar inteiro”, pulando “Acorde”.

Corrigir a revisão de perfis novos separadamente da migração de perfis existentes. Testar entrada sem save, reconexão e saves rev2. Não fazer novo wipe.

### 3. Troca de Stand pela mochila contorna a trava de combate

`StandService.UseItem/ArrowChoice → SetStand → applyPower` chama `AbilityService.ForceCharacter` (`StandService.luau:50`). Essa função, em `AbilityService.luau:1589`, é explicitamente para mods/dev, não checa combate e respawna. A seleção normal verifica `InMatch`, forma e dez segundos fora de combate (`AbilityService.luau:1611`).

Um disco de outro Stand pode, pelo fluxo atual, ser consumido para trocar e renascer durante uma luta. Reutilizar as regras da troca normal e validar antes de consumir o item. Testar também durante duelo, agarrão e forma de boss.

### 4. Persistência e trocas ainda não resistem a falhas parciais

- `DataService.luau:343`: `UpdateAsync` ignora o valor anterior e grava o perfil da sessão; não há posse de sessão entre servidores. Uma gravação atrasada de sessão anterior pode sobrescrever progresso mais recente.
- `snapshot` referencia o perfil mutável, e o sucesso limpa `dirty` sem versão da alteração. Revisar alterações durante uma gravação e saída durante autosave; chamadas concorrentes de save retornam `false`.
- `TradeService.luau:239`: as duas gravações são disparadas separadamente, e a troca retorna sucesso sem aguardar confirmação persistida. Se apenas um lado salvar e o processo morrer antes de recuperar, os saves podem divergir e perder/duplicar valor.

Antes de valorizar itens raros: implementar controle de sessão, revisão de gravações e transação de troca identificável/recuperável. Apenas aguardar dois saves não resolve a atomicidade entre perfis. Testar falha de um lado e encerramento/reconexão em ambiente separado dos dados reais.

### 5. História antiga continua revelando Adryan cedo demais

`QuestConfig.luau` contém o arco antigo “O traidor”; `QuestService.Start` cria seus NPCs, e `TraitorService.Init` liga a invocação à aceitação da missão final. Não há desativação desse arco na campanha F/X.

Isso conflita com a construção de confiança do Capítulo 2 e a revelação posterior do cânone. Converter as atividades úteis em sidequests compatíveis, preservando recompensas já concedidas e sem apagar assets. Evitar dois Humanoiders/objetivos concorrentes para o iniciante.

### 6. Ciclo de farm da campanha incompleto

`ProgressionService.luau:197` concede somente maestria por morte de bot. Os serviços das três ilhas não conectam essas mortes a XP, moeda ou tabelas de loot. `StoryService.finishAct` entrega itens configurados, atualmente a Flecha do Eco final, sem recompensa geral de XP da campanha.

XP já existe por outros caminhos, como PvP, conquistas, missões antigas e boss legado. Portanto, o problema é a ligação do PvE novo à economia existente. Reaproveitar ProgressionService/DataService e o que servir de BossLootService; não criar um segundo sistema de moedas ou inventário.

### 7. PvP aberto ainda não tem as proteções aprovadas

Todas as regiões cadastradas têm `Pvp = true`. `HealthService` usa `CanFight`, times, i-frames e trava de agarrão; não resolve zonas seguras locais ou diferença de progressão. `MatchService` recompensa kills no mapa livre sem filtro de nível ou repetição de vítima. O marcador `LastCombatTime` existe, mas não constitui sozinho penalidade por abandono de combate.

Implementar primeiro zonas seguras e proteção de retorno; depois elegibilidade de recompensa e abuso por vítimas repetidas; só então bounty/contratos e combat logging. Manter o PvP aberto aprovado e distinguir dano PvP de PvE ao aplicar proteções.

### 8. Catálogo não entrega as sete raridades anunciadas

`StandConfig.Stands` tem apenas Comum, Incomum, Raro e Lendário. `Roll` rebaixa uma faixa vazia até encontrar conteúdo. As probabilidades efetivas atuais são: Bruno/Swift 55%, Jotaro 26%, Kira 17% e Dio 2%. Não há resultado Épico, Relíquia ou Anômalo na Flecha atual.

Manter chance fixa sem pity, conforme aprovado; apresentar somente o que é obtível e adicionar conteúdo das outras faixas quando estiver pronto. Há também sorteio de raça no nascimento apesar da direção mais recente dizer humano inicial/raças por missão: reconciliar essa regra, sem inventar uma terceira direção.

### 9. Dois erros distintos na análise estática

- `src/shared/Modules/StandConfig.luau:92`: retorno da Flecha incompatível com `ItemInfo?` na inferência atual.
- `src/server/Services/DataService.luau:501`: atribuição que pode produzir `nil` em inventário tipado com valores `number`.
- Avisos menores: `lastServerState` não usado em DevController:103 e `a` não usado em TrailerService:235.

Não confundir erro estático com crash observado. Corrigir e repetir `tools/analisar.sh`; a anotação histórica “análise limpa” não descreve esta execução.

### 10. Recibos sem deduplicação — corrigir antes da monetização

`ShopService.luau:157` concede a recompensa antes do save e não registra `PurchaseId` processado. Se o save falhar, retorna `NotProcessedYet` após a concessão em memória; uma repetição pode conceder novamente. Os IDs atuais estão zerados: é uma pendência de ativação, não uma compra real observada.

## Próximas levas recomendadas

| Ordem | Entrega pequena e verificável | Critério de conclusão |
|---|---|---|
| 1 | Corrigir entrada, contador dos Vagantes e erros estáticos | Perfil novo começa na Missão 0; 3 Vagantes + parry avançam; kills PvP não substituem o objetivo; análise passa |
| 2 | Fechar troca de Stand e robustecer saves/trocas | Item não é consumido em troca proibida; desconexão/falha de save não duplica ou perde itens; perfil temporário/privado continua sem persistência |
| 3 | Harmonizar narrativa ativa e entrada das builds | Sidequests antigas deixam de antecipar a trama; uma arma e um estilo iniciais permitem concluir a rota da Missão 2, com maestrias separadas |
| 4 | Completar o ciclo repetível do Porto da Névoa | Mobs dão XP/moeda/loot; uma fonte renovável de Flecha; um Echo Boss com crédito de participação; um segredo/sidequest e consequência visível de Eco |
| 5 | Proteções de PvP e revisão de recompensa | Spawn/loja/Taberna protegidos; proteção pós-morte; sem ganho por farm de iniciantes/vítima repetida; depois bounty/contrato |
| 6 | Fechar conteúdo já aberto | Eco final do Deserto; Técnica com efeito real; Missão 13 e conclusão jogável da Rota do Eclipse |
| 7 | Produzir Ilha 4, depois 5 e 6 | Cada ilha tem campanha + atividade repetível + recompensa + segredo, testados antes de iniciar a seguinte |
| 8 | Preparar expansão e lançamento | Performance medida, mobile/gamepad, recibos, identidade pública, places por capítulo e estudo isolado da migração de movimento |

UI, performance e colaboração com a arte acompanham cada leva; não devem esperar a última etapa. O plano acima é recomendação desta auditoria, não uma alteração automática da ordem aprovada pelo dono.

Para conteúdo novo, preservar IDs internos dos kits e usar nomes públicos originais conforme `BIZARRE_DIRECAO.md`; há nomes literais Jotaro, Dio, Yoshikage Kira e Rick em `CharacterDefs.DisplayName`. Mudanças de arte pertencem à equipe.

Não começar agora uma reescrita do combate, todos os sete capítulos, novos sistemas sociais ou grande expansão de catálogo. O combate e os serviços sociais já representam investimento reutilizável. A migração de movimento precisa de investigação própria antes de comprometer a base funcional.

## Roteiro de validação no Studio

1. Em ambiente de teste com perfil novo, percorrer praia → Humanoider → Taberna → 3 Vagantes + parry → fenda/Eco → Máscara → Rastro → Herdeiro → Eco → Flecha → portal. Não usar avanço por comando administrativo como substituto da interação real.
2. Com outro jogador, demonstrar que matar player não conta como Vagante; testar block, parry, dash, agarrão e dano replicado.
3. Tentar consumir disco em combate/duelo/forma de boss. Após correção, pedido deve ser recusado sem consumir; fora de combate, troca deve manter a maestria anterior salva.
4. Reconectar durante um Eco pendente e após receber Flecha. Conferir escolhas persistidas, recompensa única e checkpoint do Pescador.
5. Testar salvamento/trocas com falhas controladas em dados de teste; verificar ambos os inventários após reentrada. Servidor privado continua sem salvar.
6. Usar Device Emulator para mochila de 440×470 e Eco de 520 px, que atualmente têm tamanho fixo; conferir texto, botões, analógico e gamepad.
7. Medir custo de bots, destruição, ults simultâneas e replicação. A IA atual mantém alvo válido sem um limite explícito de retorno ao ponto de origem: testar perseguição para o mar e retorno antes de espalhar mais bosses.

Publicação, quando chegar a etapa, exclusivamente pelo Studio com o dono e o Rojo sincronizado. O manifest continua aditivo; o repositório não representa sozinho o place completo.
