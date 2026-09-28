# Auditoria para migração ao RPG F/X

Data: 2026-09-28. Escopo: repositório, configuração Rojo, documentação, código em `src/`, ferramentas e estado do Git. Esta etapa não altera gameplay nem assets.

## Resumo executivo

O projeto não deve ser refeito. Ele já possui uma base extensa e reaproveitável: combate servidor-autoritativo, personagens e habilidades, bosses, progressão, persistência, quests, NPCs, economia, conquistas, clãs, duelos, torneio, guerra, cosméticos, mods, anti-exploit, UI e ferramentas de mapa. A migração para RPG open-world deve preservar esse núcleo e trocar gradualmente o loop principal de “arena livre” por exploração, regiões, missões e capítulos.

O maior risco não é técnico, mas de continuidade: a história atual em `QuestConfig.luau` é um arco curto de battlegrounds no mapa Sahur e contradiz a nova saga F/X. Ela deve permanecer funcional até o primeiro vertical slice do RPG substituí-la por configuração versionada.

## Estado observado

- Branch `main`; há alterações locais do usuário em `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `PROGRESSO.md`, além de `BIZARRE_DIRECAO.md` e `CentralProjectMarker.luau` ainda não rastreados. Foram preservadas.
- Rojo 7.7.0, projeto aditivo com `$ignoreUnknownInstances`; o place publicado e arte manual no Studio não são apagados pela sincronização.
- Aproximadamente 38,5 mil linhas Luau próprias/de dependências; 43 Services, 26 Controllers e 39 módulos compartilhados, além de UIs, VFX, sons, mapas e ferramentas.
- Perfil persistente schema 4: moedas, pontos de evento, personagens, estatísticas, nível/XP, conquistas, quests, cosméticos, emotes, maestria, rating, clã, configurações e versão vista.
- Rede centralizada em `RemoteEvents.luau`, com validação e rate limiting; dano, cooldown, progresso e recompensas permanecem no servidor.
- `tools/analisar.sh` conclui. Há dois avisos Luau já existentes (variáveis locais não usadas) e avisos de migração de fonte ao ler modelos binários; nenhum erro de tipo foi reportado.

## O que pode ser preservado

| Base existente | Uso no RPG F/X |
|---|---|
| Combat/Ability/Health/Ragdoll/Counter | Combate principal contra mobs, elites, bosses e PvP opt-in |
| CharacterDefs/AwakeningDefs | Poderes equipáveis e kits; separar futuramente “poder do player” de “personagem completo” |
| DataService/ProgressionService | Save, nível, XP, maestria e migrações de schema |
| QuestService/QuestController | Fluxo de aceitar, acompanhar, entregar e salvar quests; generalizar de uma linha para arcos/regiões |
| Boss/Bot/Traitor Services | IA de inimigos, minibosses e encontros narrativos |
| Duel/Tournament/War | Atividades opcionais, sem comandar o loop principal |
| Shop/Vendor/Trade/Cosmetics/Achievements | Metajogo e recompensas, depois de rebalanceamento |
| Mods | Servidores privados; manter isolado da progressão pública |
| FX/Assets/UI/controllers | Feedback audiovisual e HUD; adaptar para exploração e diálogo |
| Arena/Environment/destruction tools | Protótipos de região, cenários destrutíveis e ferramentas internas |

## Lacunas para um open-world

Ainda não existe uma abstração formal de universo/região, streaming/teleporte entre regiões, spawn por checkpoint, catálogo de NPCs inimigos por nível, inventário/equipamentos, árvore de progressão do player, quest graph com pré-requisitos, diálogo/cutscene orientado por dados, rastros colecionáveis de Carlos nem save de estado por capítulo/universo. Também falta definir como os kits atuais viram poderes do RPG sem obrigar o jogador a trocar de personagem.

## Dívidas e riscos

1. `BIZARRE_DIRECAO.md` ainda descrevia battlegrounds como núcleo e Rick como convidado; a direção nova passa a prevalecer.
2. `QuestConfig.luau` usa nomes/avatares da equipe e uma traição antiga localizada. Não deve ser apagado antes do substituto jogável.
3. O conteúdo inspirado em animes precisa de direção original: nomes, visual, diálogos, símbolos, áudio e assets não podem copiar obras existentes.
4. O mapa real contém conteúdo manual no Studio e cópias locais; qualquer alteração de mapa exige backup e teste no Studio.
5. Sistemas de PvP/economia foram balanceados para sessões curtas; números não devem migrar automaticamente para PvE persistente.

## Conclusão

O caminho seguro é um vertical slice do Capítulo 1 em uma única região: exploração curta, NPC de Humanoider_20, cadeia de quests, inimigos, miniboss/boss, um Rastro de Carlos, checkpoint e retorno opcional à arena. Só após validar esse recorte se expande para novas ilhas e universos.
