# Kit de MODS do Sahur — como a comunidade cria e como a equipe aprova

Decisão do dono (2026-09-22): mods são feitos pela comunidade numa **place de criação** (kit oficial), enviados
pelo **Discord** com a ficha, analisados pela equipe contra a **lista de exigências** abaixo e, se aprovados,
sobem para o jogo e ficam disponíveis **só em servidores privados** — o dono do servidor escolhe quais liga.
Em servidor privado **NADA salva** (pontos, itens, quests, personagens). Créditos ao autor aparecem no painel.

## 1. O que um mod pode ser (`Kind` em `ModsConfig.luau`)
| Kind | O que traz | Estado |
|---|---|---|
| `rules` | só números/flags (vida, dano, cooldown, gravidade, velocidade, hora, personagens liberados, só socos, boss periódico, cenário fixo) | **pronto** (ModService aplica) |
| `character` | personagem novo: `CharacterDef` (moveset/ult/efeitos) + rig R6 + animações | estrutura pronta; loader em breve |
| `cosmetic` | skins/cosméticos (`CosmeticsConfig` entries + modelos) | estrutura pronta; loader em breve |
| `vfx` / `sfx` | efeitos compostos (`VFXLibrary`) e sons | estrutura pronta; loader em breve |
| `map` | props/áreas (Model) — nunca substitui o mapa inteiro | estrutura pronta; loader em breve |

## 2. Estrutura que o criador entrega (na place de criação)
```
ServerStorage
└── Mods
    └── <IdDoMod>            (só letras minúsculas, números e _ — ex.: meteoros_do_ravy)
        ├── ModConfig        (ModuleScript) → { Id, Name, Author, AuthorUserId, Version, Kind, Desc, Rules?, Exclusive? }
        ├── CharacterDef     (ModuleScript, só Kind = character; mesmo formato de CharacterDefs)
        ├── Cosmetics        (ModuleScript, só Kind = cosmetic)
        ├── VFX              (Folder com os meshes/partículas usados; nomes = os citados no ModuleScript)
        ├── Sounds           (Folder com Sound; ids PÚBLICOS ou subidos pelo GRUPO)
        └── Map              (Model, só Kind = map)
```
Ficha no Discord: nome, autor (nick + id), versão, tipo, descrição em 1 frase, o que muda no jogo, link da place.

## 3. LISTA DE EXIGÊNCIAS (a equipe confere TUDO antes de aprovar)
Reprovado se falhar em qualquer item.
1. **Sem Script/LocalScript**: só ModuleScripts de dados + assets. Nada roda por conta própria. Nada de `require` por id, `HttpService`, `MarketplaceService`, `TeleportService`, `DataStoreService`, `loadstring`.
2. **Sem tocar em economia/progresso**: mod não dá pontos, Robux, itens permanentes nem mexe em DataStore.
3. **Sem burlar o servidor**: dano, cooldown, vida e vitória continuam decididos pelos services do jogo; o mod só entrega NÚMEROS dentro dos limites (dano ≤ 3×, vida ≤ 4×, velocidade ≤ 2×, cooldown ≥ 0).
4. **Assets do GRUPO ou públicos**: animações/sons/meshes precisam carregar num jogo do grupo FX_Bacons (o `AnimationCheckService` e o comando "Testar sons" conferem). Asset privado de outra conta = reprovado.
5. **Performance**: ≤ 400 peças por mod de mapa; ≤ 60 partículas ativas por efeito; sem `while true` implícito (Tween/loops só via services do jogo); texturas ≤ 1024².
6. **Rig R6** para personagens/skins; animações feitas para R6; nada de R15/mesh de fora sem aprovação.
7. **Conteúdo**: nada ofensivo, nada de marcas/personagens com direito autoral copiado 1:1, nada de texto/áudio impróprio (regras da Roblox).
8. **Nomes únicos**: `Id` não pode colidir com nada do catálogo; nomes de VFX/sons prefixados com o Id.
9. **Testado na place de criação** em 2 clientes (o criador manda vídeo ou print).
10. **Créditos**: o autor aceita aparecer no painel; a equipe pode ajustar números para balancear.

## 4. Como a equipe sobe um mod aprovado
1. Inserir a pasta `ServerStorage.Mods.<Id>` no place oficial (via MCP/Studio) — assets de animação/som publicados pelo GRUPO.
2. Adicionar a entrada em `src/shared/Modules/ModsConfig.luau` (`Catalog`), com `Approved = data`.
3. Rodar `tools/analisar.sh`, testar num servidor privado (painel MODS em Config), commitar.
4. Anunciar no Discord com créditos ao autor.

## 5. Painel no jogo
- **Config → Mods**: aparece para todo mundo em servidor privado (só o dono liga/desliga) e sempre para devs.
- Chip "MODS ATIVOS: nome (autor)" no HUD de todo mundo da sala.
- Servidor público: devs veem o catálogo mas o servidor recusa ligar ("só em servidor privado / Studio").
