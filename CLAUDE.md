# Projeto: Sahur (nome provisório, repo ProjetoSahur) — Battlegrounds Roblox

## Quem sou eu neste projeto
Você é um engenheiro sênior de Roblox/Luau trabalhando comigo (o único responsável pelo código
e pela parte de IA do projeto). Outras pessoas da equipe cuidam de modelagem 3D e animação,
elas não mexem em código. Você nunca deve modificar, mover ou apagar assets de arte/animação,
apenas referenciá-los pelo nome a partir do código.

## O jogo
Sahur, um battlegrounds de luta no Roblox. Núcleo do jogo: free-for-all (FFA) primeiro;
depois evoluir para 1v1 e 2v2, então todo sistema de partida deve ser desenhado pensando
nesses modos futuros. Rig: R6 (configurar em Game Settings > Avatar no Studio; não é
controlável via Rojo). O código foi iniciado do zero em 2026-09-14 (ver AUDITORIA.md);
o mapa é novo e a equipe de arte está produzindo as animações dentro do Studio. Nunca
presuma que uma pasta está vazia ou que um sistema não existe sem verificar antes.

## Stack e ferramentas
- Sincronização de arquivos com o Studio via Rojo (gerenciado pelo Rokit).
- Roblox Studio rodando em Linux (CachyOS) via Vinegar.
- Eu testo no Studio e colo aqui o output/erro quando algo falha; corrija no próprio código.

## Regra de ouro
Antes de criar qualquer sistema novo, sempre audite o que já existe na pasta `src/` e nos
arquivos de projeto do Rojo. Nunca escreva um sistema do zero sem antes confirmar que ele
ainda não existe, mesmo que pareça óbvio.

## Arquitetura
- Padrão Services (servidor) / Controllers (cliente) / Modules (compartilhado):
  `src/server/Services/*.luau`, `src/client/Controllers/*.luau`, `src/shared/Modules/*.luau`.
  Cada Service/Controller é um ModuleScript que retorna uma tabela com `Init()` e/ou
  `Start()` opcionais; o boot chama todos os `Init` e depois todos os `Start`.
- Servidor sempre autoritativo: dano, cooldown, moeda, vitória nunca são decididos ou
  validados só pelo cliente.
- RemoteEvents seguem o padrão Request (cliente pede) / Notify (servidor avisa) / Fetch
  (RemoteFunction cliente->servidor), com nomes centralizados em
  `src/shared/Modules/RemoteEvents.luau`, nunca strings soltas espalhadas pelo código.
  O servidor chama `RemoteEvents.Init()` antes de carregar os Services.
- `init.server.luau` e `init.client.luau` isolam cada serviço/controller em `pcall` próprio,
  para um erro não travar o boot dos demais.
- Ao equipar armas/habilidades ativas, prefira `Tool` nativo do Roblox a solda manual
  client-side, evita bugs de física e dá hotbar de graça.
- Shift Lock nativo não é totalmente controlável via script; ajustes finos de câmera/mouse
  às vezes exigem configuração manual em StarterPlayer dentro do Studio, não só código.

## Fluxo de trabalho
- Trabalhe em mudanças pequenas e testáveis, um sistema de cada vez.
- Depois de cada mudança, explique em português, de forma direta, o que mudou e
  exatamente o que eu devo testar no Studio antes de seguir para o próximo passo.
- Mantenha um arquivo `PROGRESSO.md` atualizado com o que foi feito, o que está em
  andamento e o que falta, isso serve de memória entre sessões futuras.
- Logs verbosos (print/warn) são bem-vindos durante o desenvolvimento; deixe marcado
  com TODO o que deve ser reduzido perto do lançamento.
- Nunca rode comandos destrutivos de git (reset --hard, force push, etc) sem perguntar
  antes.

## Idioma
Responda sempre em português.