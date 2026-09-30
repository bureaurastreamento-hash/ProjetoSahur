# Referências visuais aprovadas — 2026-09-30

Fonte: `Fotos exemplos a ser usados/ler_para_fazer.txt`. As nove imagens são **inspiração**, para refazer/transformar com o tema F/X; não copiar a interface, personagens, símbolos ou mapas do exemplo. A instrução explícita é tirar bordas arredondadas de menus/UI/GUI.

Os dez arquivos originais (nove imagens + TXT) foram renomeados em ASCII minúsculo, com `_`, mantendo seus bytes. `Fotos exemplos a ser usados/indice_referencias.json` registra nome original, nome atual e SHA-256. A pasta continua no caminho informado pelo dono.

| Exemplo atual | Direção F/X e estado |
| --- | --- |
| `hud.png` | Manter vida, carga do despertar, nível/XP/moeda e habilidades legíveis; usar contraste escuro/ciano/âmbar do projeto. Cantos dos modelos de HUD ficam retos. A carga existente é ULT, não uma barra de stamina inventada. |
| `hud_celular.webp` | Reduzir obstrução e manter controles de toque existentes. Menu agora recolhe, mochila compacta omite cabeçalho grande e objetivos têm rolagem. Posição/escala final ainda precisa de emulador. |
| `hud_e_menu.webp` | Painéis retos e hierarquia clara. Menu F/X abre as telas existentes; configurações/loja também receberam cantos retos, sem alteração de economia. |
| `hud_e_jeito_de_falar_com_npc_s.webp` | Diálogo com identidade do NPC e texto legível. Caixa responsiva, texto com rolagem, foto quadrada, tempo conforme extensão da fala; retirar prefixo “DEV” da conversa. Não impor nível mínimo rígido às missões. |
| `inventario_completo_com_abas_diferentes.webp` | Abas Tudo/Flechas/Discos/Raças/Build e busca textual na mochila existente. Uso mantém RequestUseItem e validação do servidor. Build mostra equipamento/maestrias já existentes. |
| `selecao_de_time_quando_entra_no_jogo.webp` | Referência para cartões de escolha e contraste entre caminhos. A Missão 2 já escolhe Técnica/Manifestação/Arma; não substituir esse início por piratas/marinheiros nem ativar rounds. Seleção futura de classes sociais Hunter/Outlaw/Defender depende do sistema correspondente, ainda pendente. |
| `loja_de_flechas_especificas_robux_permanetes.webp` | Inspiração para catálogo organizado e descrição clara do que a compra concede. Não implementada venda de Stand escolhido/permanente: requer desenho compatível com Flecha aleatória, chances fixas e troca/perda do Stand atual. Produtos reais também dependem dos IDs do dono; a loja existente continua com seu catálogo. |
| `estilo_de_construcao_de_ilha_parts_padrao_bem_feito.webp` | Ilhas com silhueta clara, relevo simples, construções legíveis e trajetos entre pontos. Direção registrada para modelagem/integração, sem modificar arte da equipe ou montar mapa incompleto. |
| `porto_e_agua.webp` | Chegadas reconhecíveis, cais, água e NPC perto do checkpoint. Integração das futuras ilhas exige chão real e pontos seguros; acabamento do porto/água é trabalho de mapa ainda pendente. |

Cantos retos aplicados aos 278 UICorners dos JSONs de `src/ui`, construtores de menus em Controllers e geradores correspondentes. TopbarPlus recebe a regra nos containers do jogo; pacote e CoreGui nativo não foram editados. A máscara circular da cutscene continua sendo um efeito, não um menu.

Quando houver Studio: conferir desktop, mobile em paisagem/retrato e gamepad; testar menu, abas/busca, Flecha, escolha usar/guardar, rolagem de diálogos longos e objetivos com sidequests. Os testes locais validam campanha/dados; não certificam a aparência ou a área de toque.
