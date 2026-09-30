# Costa Dourada — integração aditiva

Campanha inicial preparada: missões 21–25, Regente Dourado e Eco da Ilha 5, conforme a bíblia. Mapa não montado/publicado. Não usar build Rojo/API para publicar.

Criar/integrar por trabalho de mapa um Model `FXCostaDourada`, com atributos `FXRadiusX`/`FXRadiusZ` finitos e positivos. Centro em `CostaCentro`. Usar as mesmas regras de limites, marcadores ancorados e raycast de `CIDADE_AMBAR_INTEGRACAO.md`; agora compartilhadas por `CampaignMapRegistration`. Área fora dos limites das ilhas existentes. Nenhuma coordenada falsa entra no catálogo.

| Marcadores | Função |
| --- | --- |
| `CostaCentro`, `CostaSpawn`, `CostaCheckpoint` | Limites, chegada e interação para salvar checkpoint |
| `CostaToAmbar` | Portal de retorno, destino disponível obrigatório |
| `CostaHumanoider` | Guia; identificar C-8 depois de examiná-lo; comentário do Eco |
| `CostaLote1`, `CostaLote2` | Objetos de realidades anteriores/desconhecidas, M21 |
| `CostaOrganizacao` | Registros do tráfico, M22 |
| `CostaContato`, `CostaFavor` | Conversar, buscar entrega e retornar; libera acesso social |
| `CostaGuardPad1`, `CostaGuardPad2`, `CostaGuardPad3` | Guardas PvE para caminho de força |
| `CostaPassagem1`, `CostaPassagem2` | Caminho furtivo, em ordem |
| `CostaAcessoForca`, `CostaAcessoFurtivo`, `CostaAcessoSocial` | Entradas correspondentes à escolha M23 |
| `CostaRegistro1`, `CostaRegistro2` | Comparar registros de horários das rupturas, M24 |
| `CostaC8` | Carregamento C-8, M25 |
| `CostaBossSpawn` | Regente Dourado provisório |

Todos são obrigatórios para registrar a região. O chão é conferido na chegada, chefe, três pads de guardas e checkpoint. Chegada fica com zona segura PvP de raio 25; afastar chefe/guardas dela e posicionar o caminho furtivo fora do alcance dos guardas (SeekRadius 35). As rotas estão codificadas; detecção furtiva, portas/animações e infiltração física completa ainda precisam de implementação/validação.

Ida: BasePart `AmbarToCosta`, na Cidade Âmbar, com flag `costa_dourada_unlocked`. A flag vem do Eco da cidade. Ela não teleporta para destino indisponível. Voltar não salva spawn; `CostaCheckpoint` é quem salva. O `AmbarToCosta` pode ser integrado depois no mapa de Âmbar; não é exigido para registrar essa cidade.

Regente usa Kira provisoriamente; múltiplos artefatos de mundos diferentes ainda não têm kit próprio. Guardas: 180 HP, 22 XP base e 2 moedas base; chefe: 750 HP, 160 XP base, 10 moedas base, Flecha 5% por tentativa. Valores iniciais, multiplicadores/contribuição normais e respawn de Echo Boss existentes.

M24 compara **registros** dos horários, sem alterar o ciclo dia/noite. Rupturas físicas programadas e sua aparência continuam pendentes. M25 só apresenta a identificação de Carlos após obter C-8 e falar com Humanoider; não explica origem/causa da circulação dos objetos.

Os três Ecos gravam estado narrativo por jogador e mudam a resposta do guia; não destroem globalmente um mapa usado por outros jogadores. Comerciantes/NPCs específicos, alterações visuais pessoais e catálogo do mercado ainda estão pendentes. Todos liberam `fortaleza_mare_unlocked`, aguardando a próxima ilha real: **Fortaleza Maré**, não Fortaleza Aurora.
