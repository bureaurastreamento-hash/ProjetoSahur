# Mapa do Capítulo 1 — Primeira Fratura (arquipélago das eras)

Fonte da campanha: `BIBLIA_CAMPANHA_CAP1_v0.1.md`. O Capítulo 1 é um arquipélago de ilhas, e cada uma é uma era
(Parte) do universo inspirado em JoJo, **originalizada**: nada de copiar personagens, locais, símbolos ou histórias da obra.

## Ilhas da bíblia × mapa real (2026-09-29)

Os ids internos continuam os antigos para não quebrar saves/Rojo; o nome na tela é o da bíblia.

| # | Ilha (bíblia) | Parte | Id da região | Onde está no mapa | Missões | Chefe |
|---|---|---|---|---|---|---|
| 1 | **Porto da Névoa** | 1 | `ilha_tutorial` | antiga Ilha do Alvorecer (150, -40): vila vitoriana, porto, Taberna, ruínas góticas | 0–5 + final | Herdeiro da Névoa (ruínas) |
| 2 | **Deserto do Sol** | 2 | `ilha_pilares` | antiga Ilha dos Pilares (910, -500): ruínas astecas, escavação, santuário na montanha da cachoeira (= "A Câmara"), **Coliseu** | 6–10 | Sacerdote do Sol Negro (Câmara) |
| 3 | **Rota do Eclipse** | 3 | `ilha_sol_partido` | antiga Sol Partido (1700, -130): trecho do deserto egípcio, cânion, oásis, templo. Vai crescer como **cadeia de ilhotas** (porto, vilas, cidade, mansão) | 11–15 | O Observador (topo do templo) |
| 4 | **Cidade Âmbar** | 4 | a criar | cidade "normal", mistério, rotinas de NPC (Parque B da `ArenaReserva`) | 16–20 | O Homem Sem Sombra |
| 5 | **Costa Dourada** | 5 | a criar | costa mediterrânea, mercado negro de objetos de outras realidades | 21–25 | Regente Dourado |
| 6 | **Fortaleza Maré** | 6 | a criar | prisão sobre zona instável, loops no tempo | 26–31 | Avatar da Fratura (final do capítulo) |
| — | Ilhota Kame | — | — | (-450, 560), easter egg do dono | — | — |

Rota: Porto da Névoa → (vencer o Herdeiro) → Deserto do Sol → (vencer o Sacerdote) → Rota do Eclipse. A volta é
sempre livre. Portais em `WorldPortalService`, com as flags gravadas por `StoryConfig` (`UnlockFlag`). A bíblia libera o
**barco** depois da Ilha 1: os portais são provisórios até existir navegação.

**Por que o Deserto do Sol fica na ilha dos Pilares**: o conteúdo de lá já é da Parte 2 (santuário antigo = "A Câmara",
pilares/estátuas = "Homens de Pedra", Coliseu). Na leva do chão de peças, o bioma dela vira **deserto árido com
ruínas astecas** e um oásis em volta da cachoeira, diferente do deserto claro e egípcio da Rota do Eclipse.

## Implementado (atos em `StoryConfig`, 2026-09-29)

- **Porto da Névoa**: Humanoider_20 (missões 0–1), 3 Vagantes da Fratura + parry (3), Rastro "o objeto impossível" nas
  ruínas (5), Herdeiro da Névoa (final). Falta: Missão 0 "Acorde" (praia, 3 objetos, estrutura enterrada),
  Missão 2 (vila + escolha de rota), primeiro Eco (3), Portador da Máscara (4), escolha final (prisioneiros × arquivos).
- **Deserto do Sol**: chegada (6), 4 Homens de Pedra na escavação a leste (7), Mestre da Respiração + discípulo, 2
  parries (8), símbolo na Câmara (9), Sacerdote do Sol Negro (10). Falta: Eco final (selar/destruir/transferir),
  alternância de épocas na luta do boss.
- **Rota do Eclipse**: chegada (11), 5 Caçadores de Recompensa + 2 parries (12), Rastro "o homem que não existe" no
  altar do templo (14), O Observador (15). Falta: Missão 13 (O Viajante), porto/vilas/cidade, mansão.

## Layout físico (2026-09-28 — arena DESMONTADA, dono autorizou)

A arena fechada não existe mais: as peças dela foram distribuídas pelas ilhas. Chão = Terrain
(`tools/studio/MontarMundo.luau`, mar de água de verdade), que vai ser trocado por **peças simples bem feitas**
(próxima leva). Centros/raios em `WorldConfig.Islands`.

| Ilha | Peças reaproveitadas da arena |
|---|---|
| Porto da Névoa | Taberna + Hall + `cav` (no lugar), montanha de pedra da Taberna (`PecasArena.RochaTaberna`), Parque Vitoriano, 4 árvores, Lojinha, placares, bonecos de treino, spawns, pedras/árvores e estátua do dono |
| Deserto do Sol | jardim + templos da serpente + cachoeira + santuário (dentro de uma montanha de Terrain), vila mesopotâmica NW (ruínas/escavação), piso central + 16 pilares da arena (`Coliseu.rbxm`), 4 árvores |
| Rota do Eclipse | vila mesopotâmica SE (zigurate + mercado = bazar) |
| Ilha 4 | Parque B (`ServerStorage.ArenaReserva`) |

Reserva: muralhas, cercas, estradas, piso restante e Parque B → `ServerStorage.ArenaReserva` (nada apagado).
Original: `backups/Arena_original_2026-09-28.rbxm`; `tools/desmontar_arena.luau` refaz a divisão a partir dele.

## Regra por ilha (ESTRUTURA_JOGO.md)

Cada ilha precisa diferir em silhueta, paleta, verticalidade, densidade urbana, tipo de travessia e atividade
principal. Além das missões de história, a região completa tem como meta: 10–15 sidequests, ~6 tipos de mob,
2 minibosses farmáveis (+ Echo Boss), 1 boss secreto, 1 dungeon, 3 armas raras, 2 acessórios, 1 técnica, 3 rastros
opcionais, tesouros, NPCs secretos, zona PvP, contratos e eventos F/X. Voltar a uma ilha antiga continua valendo
a pena por bosses, segredos, PvP e Rastros.
