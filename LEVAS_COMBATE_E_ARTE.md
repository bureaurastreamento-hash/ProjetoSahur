# Levas de combate e arte — 01/10/2026

Prioridade pedida pelo dono: animações/fluidez, VFX/SFX/modelos de combate; depois construções/mapa.
Referência de direção: BIZARRE_DIRECAO.md. Arte da equipe preservada; mudanças de código só a referenciam.

## Estado conferido

- Pré-lançamento ligado em LaunchConfig; campanha completa não está aberta ao público.
- Cidade Âmbar existe nos arquivos; Costa Dourada/Fortaleza Maré ainda precisam de integração física.
- ProcAnimController/ProcAnimDefs já animam locomoção e ações R6. Muitos clipes procedurais têm prioridade
  sobre os IDs existentes: importar outra Animation sem revisar essa resolução pode não mudar a aparência.
- Assets.VFXPack já seleciona efeitos licenciados de JJS/SBG; FX controla emissão, composição e tetos.
- Biblioteca local: 67 arquivos de VFX, 33 de animações (inclui preview), seis modelos de packs.
- Há IDs de animação preenchidos e vazios, e reutilização de clipes entre habilidades. Não implica falha de
  carregamento: é preciso conferir o clipe realmente tocado, rig e permissões no cliente.
- Studio conferido pela ponte local: place 85844807133499, versão 505, modo edição.
- Duas pastas EnvironmentModels homônimas encontradas no Studio; investigar depois do backup, sem apagar.

## Leva 1 — base de combate completa

1. Locomoção: idle, andar/correr, iniciar/parar, strafe, pulo/queda/pouso e dash nas direções.
   Corrigir saltos de fase e transições; respeitar IDs e trabalho da equipe.
2. Socos M1 1–4, uppercut/downslam, block/parry/guardbreak, reação de hit/ragdoll/levantada.
   Conferir antecipação, contato, recuperação e vínculo com o timing autoritativo do servidor.
3. VFX compartilhados: rajadas em fases, trails de movimento, cortes, impactos, poeira e ondas de choque.
   Auditar EmitDelay/EmitDuration dos packs e execução real; não colocar todos os efeitos simultaneamente.
4. SFX: distinguir movimento, contato, defesa e impacto pesado; selecionar variações e ajustar volumes,
   alcance e fades. Preservar a preferência existente do dono por fade, sem abafar o início do impacto.
5. Modelos: selecionar meshes/trails/armas adequados dos packs licenciados e CC0; inserir como assets
   novos por nome. Não mover/substituir rigs, modelos ou animações da equipe.

Entrega: comparação visual no lobby/treino com jogador e NPC, seguida de dois clientes e efeitos reduzidos.
Primeira entrega implementada: continuidade de fase/Walk–Run, strafe/recuo, swing espelhado,
impacto em fases, EmitDelay/Duration e fades curtos para combate. Menu de admin mundo/lobby também
corrigido e validado no cliente real. Seleção/importação e acabamento completo dos clipes ainda pendentes.

## Leva 2 — identidade dos kits e chefes

- Um kit completo por vez: habilidades, despertar, poses, projéteis/meshes, trilhas e sons coerentes.
- Reações da vítima, câmera discreta e telegraphs legíveis, mantendo alcance/dano/cooldown no servidor.
- Chefes com silhueta, animação e fases próprias; evitar usar o mesmo slam/roar para todos.
- Animações novas em R6; seleção e publicação autorizada de assets no grupo, validação de acesso no jogo.
  Modelos animados externos não são automaticamente compatíveis com o rig R6.

Entrega: cada kit funciona inteiro, com efeitos reduzidos e vários jogadores, antes de ampliar o catálogo.

## Leva 3 — construções e mapa

- Acabamento por região: materiais, escala, interiores, vegetação, água, iluminação e áudio ambiente.
- Preservar montanhas/construções manuais do dono; não reexecutar geradores antigos.
- Revisar Cidade Âmbar e integrar Costa/Fortaleza conforme contratos de campanha.
- Conferir chão, colisão, portos, caminhos, prompts, rotas e FPS; detalhe bonito não substitui região jogável.

## Fontes livres conferidas nesta sessão

- Kenney Particle Pack: https://kenney.nl/assets/particle-pack — CC0, sprites de partículas.
- Kenney Impact Sounds: https://kenney.nl/assets/impact-sounds — CC0, impactos/foley.
- Kenney RPG Audio: https://kenney.nl/assets/rpg-audio — CC0, armas/passos/foley.
- Quaternius Modular Weapons: https://quaternius.com/packs/medievalweapons.html — CC0, 24 modelos;
  candidato, ainda não baixado/importado.

Os três packs Kenney estão preparados em asset_library; origem/hash por arquivo em
ASSETS_COMBATE_CC0_MANIFEST.json. Download não equivale a upload aprovado ou integração no Roblox.
Uploads antigos permanecem registrados em ASSETS_ROBLOX_IMPORTADOS.json; evitar duplicá-los.

## Sincronização e teste inicial

Backup manual recebido: backups/place-manual-2026-10-01.rbxl. Captura aplicada sem remoções, preservando
estado do Studio nos arquivos de mapa/place. Rojo aditivo: nunca publicar build/API para substituir a place.
Teste da primeira correção: andar/correr em curva, variar velocidade e entrar/sair do dash repetidamente;
observar se o ciclo das pernas fica contínuo. Conferir ação, block, pulo e ragdoll sem interferência nova.

## Leva 2 implementada — 01/10

Carregamento seletivo, 1–4 habilidades + X/click para Tools, menus secundários pelo topo e TopbarPlus
padrão. Contenção invisível só para o pré-lançamento com leash/bots reativos. Menu de reset completo,
novo modelo da Lâmina da Névoa, quatro cortes/VFX e três sons Kenney CC0 aprovados. Descarte de VFX distantes.

Próxima leva: tratar telegraphs, preparação/impacto/recuperação e mixagem de um kit de Stand por vez;
começar Swift/Jotaro, comparar no Coliseu contra treino. Em seguida avançar os demais kits e a leitura visual
no mapa manual preservado. Animações/modelos da equipe serão referenciados, sem mover/apagar arte.

## Leva 3 implementada — 01/10

Cursores prontos Kenney Cursor Pack CC0 (fonte https://kenney.nl/assets/cursor-pack), importados no grupo.
Interações por clique e mini diálogo para múltiplas ações, mouse liberado nas escolhas. Capitão com rig e
adereços alinhados e busca robusta dos modelos de barco. Ilhas afastadas por translação no runtime,
com portos/checkpoints/Coliseu/zonas seguras alinhados, sem regenerar mapa nem tocar arte salva.
Swift/Jotaro ganham poses próprias para WindBlade/StarFinger, transição da rasteira e fases de VFX.

Depois da validação visual deste conjunto: finalizar antecipação/impacto/SFX dos kits Swift/Jotaro,
seguir os demais Stands, e só então avançar detalhes/construções nas ilhas preservadas. Para animações
publicadas da equipe ou KFS licenciados, manter fluxo de publicação pelo dono/IDs e prioridade por nome.

## Entrega complementar — Leva 4 (01/10)

Corrigidos os bloqueios relatados de interação, barcos/facção e sobreposição de menus.
Portos usam o chão existente; portais recebem arcos/runas e exigem missão mais descoberta ou item,
preservando atalhos antigos. WindBlade/TwinBlades e StarFinger ganham VFX/impactos próprios em fases
e fallback SFX CC0. Detalhes de validação em PROGRESSO.md.

Próxima sequência de combate: terminar as demais habilidades de Swift/Jotaro (despertares/reação da vítima),
depois revisar um kit completo por vez e chefes. Modelos/animações da equipe continuam prioritários.
A revisão visual dos portos e diálogos desta entrega vem antes de expandir construções.
