# Cidade Âmbar — contrato de integração do mapa

Código preparado em 2026-09-30, na `main`. **Mapa montado em 2026-10-01** por `tools/gerar_cidade_ambar.py` (`src/workspace/FXCidadeAmbar.model.json`); conteúdo ainda não publicado. Fonte dos eventos: `BIBLIA_CAMPANHA_CAP1_v0.1.md`, missões 16–20, boss e Eco da Ilha 4.

`CidadeAmbarService` aguarda um **Model `FXCidadeAmbar`** dentro do Workspace (pode ficar em `Sahur`). Não clona/move `ParqueB_reserva`, nem altera arte. O mapa deve ter atributos numéricos finitos e positivos `FXRadiusX` e `FXRadiusZ`; `AmbarCentro.Position` define o centro da elipse em XZ. A área precisa ficar fora dos retângulos de limites das ilhas existentes. Todos os marcadores abaixo são BaseParts ancorados dentro dessa elipse, com nomes únicos.

| Marcador | Uso |
| --- | --- |
| `AmbarCentro` | Centro dos limites da região |
| `AmbarSpawn` | Chegada e posição salva do checkpoint |
| `AmbarCheckpoint` | Interação explícita para salvar a chegada |
| `AmbarToSolPartido` | Portal de retorno à Rota do Eclipse |
| `AmbarHumanoider` | Guia e confronto após obter fotografia |
| `AmbarMorador1`, `AmbarMorador2` | Conhecer dois moradores diferentes, Missão 16 |
| `AmbarTarefa` | Tarefa simples inicial, Missão 16 |
| `AmbarDesaparecimento1`, `AmbarDesaparecimento2` | Investigar dois locais distintos, Missão 17 |
| `AmbarFotografia` | Examinar foto com rosto danificado, Missão 18 |
| `AmbarCena1`, `AmbarCena2` | Analisar duas cenas distintas, Missão 19 |
| `AmbarTestemunha` | Depoimento, Missão 19 |
| `AmbarPadrao` | Conectar pistas após as cenas e o depoimento |
| `AmbarContrapista` | Investigação adicional após acusação errada |
| `AmbarCasa` | Pequena ruptura controlada, Missão 20 |
| `AmbarBossSpawn` | Ponto do chefe provisório |

O portal de ida é uma BasePart chamada `SolPartidoToAmbar`, na Rota do Eclipse. A ida exige `cidade_ambar_unlocked`, obtida ao vencer O Observador. Retorno é livre. Viajar não salva o spawn; `AmbarCheckpoint` salva, por interação validada no servidor.

Chegada e ponto do chefe precisam ter chão colidível, com normal Y >= 0,7, localizado pelo raycast de 14 studs a partir de 2 studs acima do marcador. O teste ignora todos os marcadores e aceita somente chão do próprio mapa ou Terrain. Posicionar chegada, checkpoint e portal em local seguro, com espaço para R6; deixar o chefe afastado dessa área. A zona segura de PvP tem raio de 25 studs em torno da chegada. Isso não substitui validação física e visual no Studio.

Um checkpoint salvo na cidade é preservado quando o mapa não está disponível: a sessão usa temporariamente a chegada padrão. Registro/remoção do mapa atualiza os atributos de spawn, sem teleportar jogadores à força.

A região começa indisponível e sem coordenadas de spawn. Só é registrada depois dessas verificações. Se o Model sair do Workspace, a região/checkpoint/zona segura e prompts gerados são removidos, bots ativos dessa cidade são removidos e respawns pendentes não recriam o chefe em mapa ausente. Preparar atributos e marcadores antes de inserir o mapa; `BindMap` pode ser chamado no servidor para uma nova verificação após correções.

As interações iniciais concretizam os eventos da bíblia com prompts e contadores pessoais; não representam o arco urbano completo. Faltam rotinas de moradores, quests por horário, tarefas encenadas, pistas visuais, área urbana, escola/esgoto/segredos e reações pessoais aos desaparecimentos. O chefe usa **Swift provisoriamente**; ocultação, memória e duplicação espacial próprias ainda não foram implementadas. XP 140 base, moedas 9 base e Flecha 5% por tentativa são números iniciais para balanceamento, com contribuição/loot do sistema existente.

Não usar `rojo build`/API para publicar. O projeto permanece aditivo; publicação só pelo Studio sincronizado e com o dono, conforme `AGENTS.md`.
