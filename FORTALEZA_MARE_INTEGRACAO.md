# Fortaleza Maré — integração aditiva / fim do Capítulo 1

Base de campanha preparada conforme a bíblia, missões 26–31. Mapa não montado/publicado; combate/cenas provisórios. Não usar build/API para publicar.

Model `FXFortalezaMare` em `Workspace.Sahur`, com atributos finitos positivos `FXRadiusX`/`FXRadiusZ` e centro em `MareCentro`. Mesmas regras de limites/marcadores/chão do registrador compartilhado e dos contratos de Cidade/Costa. Todos os marcadores devem ter nomes únicos, ser BaseParts ancorados dentro da área; não copiar prompts/bots gerados durante Play para o mapa de edição.

| Marcadores | Uso |
| --- | --- |
| `MareCentro`, `MareSpawn`, `MareCheckpoint`, `MareToCosta` | Limites, chegada, salvar checkpoint e retorno |
| `MarePrisao`, `MareHumanoider` | Situação dos prisioneiros e guia |
| `MareAlaCivil`, `MareAlaRisco` | Abertura da ala escolhida; outra pode abrir depois |
| `MareLoop1`, `MareLoop2` | Examinar duas anomalias distintas, M28 |
| `MareRastro` | Equipamento/registro na sala ausente das plantas, M29 |
| `MarePrepararDispositivo` | Segredo opcional: preparar dispositivo com três Rastros |
| `MareFragmento1`, `MareFragmento2`, `MareComunicador` | Fragmentos de outras ilhas e ajuda dos Anciões, M30 |
| `MareColapsoPad1`, `MareColapsoPad2` | Duas versões alteradas distintas de chefes |
| `MareToduro`, `MareAdryan` | Avaliação de Toduro, recepção e resposta a Adryan |
| `MareFratura`, `MareBossSpawn` | Próxima realidade e Avatar provisório |
| `MareAncora1`, `MareAncora2`, `MareAncora3` | Três interações durante combate com Avatar vivo |
| `MareSeguro1`, `MareSeguro2` | Ações do método de Humanoider |
| `MareInterno1`, `MareInterno2`, `MareInterno3` | Ações internas do método de Toduro |
| `MareAtivarDispositivo` | Ação do método alternativo |
| `MareEstabilizar` | Confirmação após ações do método escolhido |
| `MareEncerramento`, `MareTerminal` | Despedida/oferta de Adryan e última cena do terminal |

Ida: `CostaToMare` na Costa, exige `fortaleza_mare_unlocked`. Retorno: `MareToCosta`, destino Costa disponível. Não há portal/teleporte para Capítulo 2: o place/mundo seguinte não está implementado. `cap2_unlocked` é uma flag de conclusão, não um destino inventado.

Região começa indisponível, sem checkpoint/coordenadas. Registrar exige todos os marcadores e chão na chegada, Avatar, dois pads do colapso e checkpoint. Zona segura de PvP raio 25 na chegada; afastar inimigos. Remover Model desfaz registro, prompts e bots/respawns associados.

Âncoras precisam ficar alcançáveis na arena do Avatar: servidor exige contribuição recente mínima de 5% do HP, até 30 segundos e distância até 150 studs, conforme `ProgressionConfig.PveCredit`, além de proximidade ao marcador. Repetir uma âncora não conta. Derrotar Avatar antes das três não conclui o objetivo de derrota; aguardar respawn do Eco e terminar âncoras antes de derrotá-lo de novo. O progresso de âncoras já ativadas é pessoal/persistente. Encenação e indicação visual dessa recuperação ainda precisam de acabamento.

Rastros exigidos pelo dispositivo: `carlos_era01`, `carlos_eclipse01`, `carlos_mare01`. O alternativo grava `fx_assinatura_protagonista`; Humanoider e Toduro não gravam essa assinatura. Todos exigem suas ações e confirmação, estabilizando a passagem. Depois vêm despedida, terminal e flags `cap1_completed`/`cap2_unlocked`; perfil permanece no Capítulo 1 aguardando integração do próximo place.

Limites desta leva: alas são estado/diálogo por jogador, sem abrir portas globais ou inventar número/identidade de mortos. Loops e colapso são investigação/combate/diálogo iniciais; animações de repetição, fragmentos visuais das seis eras e crises nas seis regiões ainda faltam. Anciões e encerramento são diálogos, sem rigs/câmeras/cutscene pronta. Método de Toduro ainda é sequência de três ações, sem simulação do perigo/quase morte e dificuldade final da bíblia.

Avatar usa Jotaro provisoriamente (1000 HP, DamageMult 1,7, 200 XP base, 12 moedas base, Flecha 5%); as **quatro fases**, habilidades dos chefes anteriores e alternância entre regiões **não estão implementadas**. Colapso usa Jotaro/Swift provisórios (450 HP, 100 XP base, 6 moedas base, Flecha 5%), com contribuição e identificação distinta por pad. Valores iniciais para balanceamento.
