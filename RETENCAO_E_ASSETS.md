# RPG vivo, facções e assets — 30/09/2026

## Por que jogadores voltam

O Blox Fruits anuncia treino até ficar forte, especialização em espada/poder, inimigos, chefes, navegação e
segredos. Sua descrição oficial também informa aparições de frutas a cada hora e reposição de estoque a cada
quatro horas: há objetivos pessoais e acontecimentos do mundo ao mesmo tempo.
Fonte: [descrição oficial](https://www.roblox.com/games/2753915549/Blox-Fruits).

Minha leitura de design é que esses sistemas oferecem metas em escalas diferentes: vencer agora, liberar uma
habilidade nesta sessão e montar uma build ao longo de várias sessões. Essa é uma hipótese de aplicação ao nosso
jogo, não uma medição de retenção do Blox Fruits. Pesquisa sobre motivação em jogos associa persistência a
competência, autonomia e conexão social; destaca controles acessíveis, feedback consistente, escolha de objetivos
e interação cooperativa. Fonte: [síntese dos pesquisadores sobre PENS](https://selfdeterminationtheory.org/player-experience-of-needs-satisfaction-pens/).
Não foram copiados questionários ou conteúdo proprietário dessa pesquisa.

## Aplicação concreta nesta leva

| Motivo para continuar | O que está no código | Limite atual |
| --- | --- | --- |
| Saber o próximo passo | HUD maior, dica/recompensa/nível da missão, direção/distância obrigatória, Objetivos com XP/maestria/receitas/título | Interface não concede recompensas; segredos opcionais sem GPS |
| Build desejada | Seis receitas de forja, objetivos com fontes/quantidades, quatro armas adicionais | Modelos/kit das armas ainda provisórios |
| Explorar | Rastros, investigações, esferas, Kame, Cânion e Mural de Rumores existentes | Mapas físicos posteriores e mais atividades ainda faltam |
| Status e rivalidade | Escolha inicial Fora da Lei/Governo; bounty/honra separadas, títulos e contratos avisados | Escolha persistente; troca de facção não foi implementada |
| Mundo com presença | 12 moradores com cabelo/roupa, PBR, flora/móveis reais, três distritos portuários, trilhas de vila/mar/chefe | Detalhes em cenários conhecidos; limites de peças; ilhas completas ainda precisam de construção |
| Superar inimigos | NPCs só escolhem jogadores; dano/empurrão de NPC contra NPC bloqueados, inclusive chefes por peças | Aliados de combate ficam para uma implementação futura |

Não foram alterados os eventos raros já aprovados pelo dono: Mercador às 6 h, esferas às 2 h e obeliscos às 4 h
de servidor. O mural mantém as dicas. Essas esperas são para eventos especiais; XP, materiais, forja, campanha,
investigações, duelo e caçadas permanecem atividades paralelas. Não há perda por deixar de entrar diariamente.
Raridades continuam com chance fixa por tentativa, sem pity, conforme a direção aprovada.

## Facções e caçadas

- Fora da Lei ganha 5.000 bounty por vitória válida em PvP de mundo aberto.
- Governo ganha 5.000 honra contra Fora da Lei em vitória válida; não ganha honra contra Governo.
- Crédito de morte servidor, gap máximo de 10 níveis, exclusão de arenas/zonas seguras e cooldown persistente de
  cinco minutos por alvo permanecem. Sem multiplicador de reputação por passe. Bounty anterior não é apagada ao
  escolher Governo; permanece no save, mas Governo progride em honra.
- Menu inicial aguarda perfil e protege de dano até escolher. Facção e honra são campos aditivos do perfil v5;
  não houve mudança de DataStore/schema/wipe. Salvamento segue autosave/saída existentes; fallback de sessão
  mantém o comportamento/aviso do DataService.
- Menu Caçadas lista somente Fora da Lei presentes com pelo menos 50 mil bounty e nível próximo ao caçador.
  Não replica posição/região. Contrato dura dez minutos, até três caçadores por alvo, sem aceitar morto/em combate/
  arena. Alvo é avisado ao aceitar/encerrar. Recompensa inicial: 20 moedas + 80 XP base, com multiplicadores normais.
  Só paga ao receber o sinal interno de reputação creditada. Não paga duas vezes, em arena, sem crédito ou dentro
  do cooldown; cancelar, sair ou expirar remove contrato. Contrato é de sessão; reputação/cooldown continuam salvos.

## Assets livres baixados e verificados

`asset_library/` é biblioteca local, ignorada pelo Git e fora do Rojo. O inventário versionado
`ASSETS_CC0_MANIFEST.json` registra URL de origem/licença, URL de download, tamanho e SHA-256 de cada arquivo.
`ASSETS_CC0_VALIDACAO.json` registra validação e a seleção em `asset_library/para_importar/`.

| Fonte | Conteúdo | Licença verificada |
| --- | --- | --- |
| [Kenney Particle Pack](https://kenney.nl/assets/particle-pack) | Sprites transparentes de partículas | CC0 |
| [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Impactos/foley | CC0 |
| [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | Sons curtos de interface | CC0 |
| [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) | Flora, pedras e props | CC0 |
| [Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit) | Móveis e detalhes de interiores | CC0 |
| [ambientCG](https://docs.ambientcg.com/license/) | Materiais PBR 1K | CC0 |

Materiais selecionados: Grass001, Ground037, Ground093A (areia clara), WoodFloor007, Bricks001 e Rock030.
Ground048 foi descartado para praia após inspeção visual: é terra marrom, preservada apenas na biblioteca.
Dois links iniciais inexistentes foram substituídos; falhas/resoluções constam no inventário.

Download com HTTPS/provedores oficiais, limites de tamanho/expansão, CRC, rejeição de caminhos relativos perigosos
e links simbólicos. Apenas formatos de dados foram extraídos; nenhuma place, plugin, Lua, executável ou script do
pack foi instalado/executado. As imagens foram decodificadas/verificadas; os 230 áudios foram decodificados inteiros
com FFmpeg sem tocar; 469 malhas OBJ foram verificadas por vértices/índices. Isso verifica integridade/formato,
não é certificação de importação, de moderação da Roblox ou de compatibilidade de todos os FBX/GLB do pack.

### Seleção importada e testada no Studio

Rojo conectado à place existente em `127.0.0.1:34872`. Uploads feitos pela **Assets API**, no grupo dono
9835819, mantendo a place: nenhuma chamada à API de publicação de place. O registro
`ASSETS_ROBLOX_IMPORTADOS.json` guarda digest/operação/ID/moderação para retomada sem duplicar uploads.

Dos 56 assets enviados, 55 estão aprovados: 18 mapas PBR (Color/Normal/Roughness de seis materiais),
12 sprites, 11 SFX, sete modelos Nature/Furniture, três trilhas, três barcos e uma paleta. O SFX
`footstep_carpet_000` foi rejeitado e retirado do manifest de sons usados. São dez modelos persistentes,
importados do grupo pelo Studio; scripts e PackageLinks são removidos, exportam-se somente estruturas de dados.
Não confundir a seleção integrada com a biblioteca inteira ou com todos os modelos dos packs.

Materiais ligados em `EnvironmentConfig`; sons por nome em `Assets.Sounds`; partículas em `Assets.VFX.CC0`;
props em `Assets.EnvironmentModels`, referenciados por controllers/services. As três trilhas e os onze SFX usados
carregaram no cliente real. Texturas/malhas foram inspecionadas no Play. Modelos GLB perderam fatores de cor ao
converter: cores dos móveis/flora foram recuperadas dos dados fonte e os barcos usam paleta com UV preservada.

Novas fontes CC0: [Kenney Watercraft](https://kenney.nl/assets/watercraft-kit),
[Home Town — Juhani Junkala](https://opengameart.org/content/jrpg-pack-2-towns),
[Boss Battle — Juhani Junkala](https://opengameart.org/content/boss-battle-music),
[Deep Sea — Umplix](https://opengameart.org/content/deep-sea). Kenney Pirate/Emotes também foram baixados como
biblioteca, mas não estão integrados: Pirate não traz as armas esperadas e Emotes contém balões de conversa.

### Portos e Strength

A [referência oficial de Forever/Strength](https://jojo-portal.com/en/anime/sc/character/22/) descreve o Stand
manifestado como grande navio cargueiro a partir de uma embarcação menor. O dono pediu cruzeiro controlável:
a implementação usa transatlântico CC0, capitão orangotango modelado com peças próprias e partículas de
transformação. Não foi baixado modelo/animação proprietário de JoJo. A arte do capitão é provisória.

Três portos nas ilhas disponíveis, com remo gratuito/lancha 60/cruzeiro 350 em moeda do jogo. Servidor valida
distância, vida, perfil, rota liberada, vaga, saldo, posse e comandos finitos; cliente só envia aceleração/direção.
W/S/A/D controlam; R libera; T desembarca perto de porto acessível. Passageiros têm seis assentos no cruzeiro;
não foi garantido caminhar livremente pelo convés durante movimento. Aluguel vazio expira em 180 segundos.

Distritos portuários de 168×80 aumentam as margens com chão físico onde faltava terra, casas novas/móveis/flora/
PBR e não alteram o Terrain ou movem modelos da equipe. Isso não conclui o aumento integral das ilhas.
Cidade/Costa/Fortaleza ainda não têm os mapas físicos necessários para seguir a campanha no place atual.

### Metas de várias sessões, sem cobrança diária

O loop proposto é: entender a missão → aprender o combate/maestria → obter material e abrir uma receita →
viajar e descobrir uma pista → resolver um segredo e fabricar a arma desejada. Núcleo Marinho e Selo Solar
são recompensas únicas de puzzles por jogador; a fibra rara conserva chance fixa por tentativa. A próxima build
aparece em Objetivos. Bounty/honra e caçadas oferecem outra meta para quem prefere PvP. Música, detalhes e
viagens dão presença ao mundo, mas não comprovam retenção por si só: é preciso observar testes com iniciantes.

Chefes reaparecem após 10/15/30 minutos conforme a classe; mobs após 20 s (overrides 10–30).
Há farm/forja/puzzles paralelos durante a espera; eventos especiais existentes mantêm seus horários próprios.
NPCs retornam andando ao sair do limite, não teleportam nem recuperam vida instantaneamente. Após 15 s sem
hit, mobs curam 2%/s; chefes após 30 s, 0,35%/s. Training dummies desligados e pads técnicos escondidos.

## Teste do dono no Studio conectado

1. Perfil sem facção: escolher cada lado em perfis distintos; sem dano enquanto menu aberto; reconectar com save
   confirmado e conferir facção/honra/bounty/itens/campanha. Governo não ganha bounty nova.
2. Dois clientes: Fora da Lei vs Governo, níveis próximos, fora das zonas seguras; reputação/toast/perfil, repetição
   antes de cinco minutos, duelo e gap acima de dez. Atributos cliente não autorizam recompensa.
3. Alvo Fora da Lei com 50 mil bounty: aceitar pelo menu Caçadas, aviso no alvo, sem marcador de localização,
   vitória válida paga uma vez; cancelar, sair, expirar e vitória em duelo não pagam contrato.
4. NPCs comuns com roupa genérica; Anciões preservados. NPCs e chefes não perseguem nem danificam outros NPCs,
   inclusive com golpes de área; continuam enfrentando jogadores conforme seus tiers.
5. Menu Objetivos: quantidades da forja atualizam ao obter/gastar material; guardar/equipar arma já possuída remove
   sua meta; maestria e títulos correspondem ao perfil. Testar toque, tela baixa e navegação por controle.
6. Materiais/água e detalhes da Vila/Campos: colisão original, janelas/portas livres, sem duplicatas; Configurações →
   Detalhes do cenário desliga/recria flora/props. Conferir FPS/mobile com os seis PBR importados e detalhes ligados/desligados.
7. Porto: alugar/dirigir/voltar/desembarcar/liberar; dois clientes para passageiros e posse do leme.
8. Lentes/Câmara: sequência correta, recompensa única ao repetir/reconectar, materiais e requisitos da forja.

Verificação atual: 107 testes locais passaram e análise estática sem erro de tipo. No Studio foram testados
retorno caminhando, regeneração lenta, bloqueio NPC contra NPC, chão dos três distritos, rejeição de aluguel
inválido e controle cliente → remote → servidor do cruzeiro. Dados do aluguel são simulados para não gastar
moedas do dono. Timers completos de 10–30 min, mobile, dois clientes e campanha desde perfil novo ainda pendentes.
