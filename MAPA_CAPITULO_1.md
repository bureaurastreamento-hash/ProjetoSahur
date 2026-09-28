# Mapa do Capítulo 1 — Arquipélago das Eras

O Capítulo 1 não é uma arena ampliada. É um arquipélago de ilhas com identidades, rotas e regras próprias, inspirado na progressão por eras de JoJo sem copiar personagens, locais, símbolos ou histórias da obra.

## Layout do mundo (2026-09-28 — arena DESMONTADA, dono autorizou)

A arena fechada não existe mais: as peças dela foram distribuídas pelas ilhas, cada uma inspirada numa
temporada (Parte) de JoJo. Chão = Terrain (`tools/studio/MontarMundo.luau`, mar de água de verdade).
Centros/raios em `WorldConfig.Islands`. Portais ligados pelo nome (`WorldPortalService`).

| Ilha | Parte | Centro (x, z) | Peças reaproveitadas da arena |
|---|---|---|---|
| 1. Alvorecer (tutorial) | Parte 1 — vila vitoriana, porto, ruínas góticas | (150, -40) | Taberna + Hall + `cav` (no lugar), montanha de pedra da Taberna (`PecasArena.RochaTaberna`), Parque Vitoriano (canto NW da arena), 4 árvores, Lojinha, placares, bonecos de treino, spawns, pedras/árvores e estátua do dono |
| 2. Ilha dos Pilares | Parte 2 — selva asteca, santuário antigo, **Coliseu (PvP)** | (910, -500) | jardim amazônico + templos da serpente + cachoeira + santuário do boss (dentro de uma montanha de Terrain), vila mesopotâmica NW (ruínas), piso central + 16 pilares da arena (`Coliseu.rbxm`), 4 árvores |
| 3. Sol Partido | Parte 3 — deserto egípcio, cânion, oásis, templo | (1700, -130) | vila mesopotâmica SE (zigurate + mercado = bazar) |
| Ilhota Kame | easter egg (Dragon Ball) do dono | (-450, 560) | CasasKame, House Trink, LocalInicial (o SpawnLocation dela está desligado) |
| 4–6 | Partes 4, 5, 6 | a fazer | Parque B (`ServerStorage.ArenaReserva`) reservado para a Parte 4 |

Rota: Alvorecer → (portal NE) → Pilares → (portal, exige Guardião) → Sol Partido. `arena_pvp` (id salvo) = Coliseu.
Reserva: muralhas, cercas, estradas, piso restante, Parque B → `ServerStorage.ArenaReserva` (nada apagado).
Original: `backups/Arena_original_2026-09-28.rbxm`; `tools/desmontar_arena.luau` refaz a divisão a partir dele.

## Ilha 1 — Ilha do Alvorecer

Tutorial costeiro de atmosfera gótica-aventureira: porto ao sul, pequena vila, campo de treino aberto, bosque lateral e ruínas ao norte. Humanoider_20 recebe o player. O primeiro Rastro de Carlos fica nas ruínas e o guardião encerra a ilha. Paleta: verdes profundos, madeira escura, pedra fria e luz ciano da fratura.

## Ilhas posteriores planejadas

1. **Alvorecer** (Parte 1) — vila vitoriana, porto com farol, ruínas góticas; tutorial.
2. **Ilha dos Pilares** (Parte 2) — selva asteca, santuário antigo com a cachoeira, Coliseu PvP.
3. **Sol Partido** (Parte 3) — deserto egípcio com cânions, bazar, oásis e templo solar. Falta: porto/navio, mansão do vilão.
4. **Cidade Mosaico** — cidade costeira colorida, bairros conectados e mistério local; investigação e eventos urbanos.
5. **Costa Dourada** — arquipélago mediterrâneo, canais, falésias e cidade elevada; facções e controle territorial.
6. **Maré de Pedra** — prisão-ilha, pântano e observatório meteorológico; fuga, clima e áreas restritas.

Cada ilha deve diferir em silhueta, paleta, verticalidade, densidade urbana, tipo de travessia e atividade principal. A passagem entre ilhas marca avanço narrativo; retornar continua permitido para bosses, segredos, PvP e Rastros de Carlos.
