# Kit de MODS do Sahur — como a comunidade cria e como a equipe aprova

Decisão do dono (2026-09-22): mods são feitos pela comunidade numa **place de criação** (kit oficial), enviados
pelo **Discord** com a ficha, analisados pela equipe contra a **lista de exigências** abaixo e, se aprovados,
sobem para o jogo e ficam disponíveis **só em servidores privados** — o dono do servidor escolhe quais liga.
Em servidor privado **NADA salva** (pontos, itens, quests, personagens). Créditos ao autor aparecem no painel.

## 1. O que um mod pode ser (`Kind` em `ModsConfig.luau`)
| Kind | O que traz | Estado |
|---|---|---|
| `rules` | só números/flags (vida, dano, cooldown, gravidade, velocidade, hora, personagens liberados, só socos, boss periódico, cenário fixo) | **pronto** (ModService aplica) |
| `character` | personagem novo: `CharacterDef` (moveset/ult/efeitos) + animações/sons/VFX por pasta | **pronto** (ModRegistry) |
| `cosmetic` | capas/auras por cor+estilo e emotes (`Cosmetics`) | **pronto** (ModRegistry) |
| `vfx` / `sfx` | efeitos compostos (`VFX` ModuleScript no formato da `VFXLibrary`) e sons (pasta `Sounds`) | **pronto** (ModRegistry) |
| `map` | props/áreas (`Map` Model → `Workspace.ModMaps.<Id>`) — nunca substitui o mapa inteiro | **pronto** (ModService) |

Como funciona por dentro (2026-09-23): ao ligar, o `ModService` clona `ServerStorage.Mods.<Id>` para
`ReplicatedStorage.ModsActive.<Id>`; o `ModRegistry` (compartilhado, roda no servidor e em cada cliente) injeta
`CharacterDef` em `CharacterDefs`, `Cosmetics` em `CosmeticsConfig` (tudo `Free`), `VFX` na `VFXLibrary` (só chaves
novas) e, no servidor, copia as pastas `Animations/Sounds/VFX` para `ReplicatedStorage.Assets`. Personagem de mod:
todo mundo da sala ganha; ao desligar, quem estava com ele volta ao padrão e tudo é retirado. Tetos aplicados no
carregamento: dano ≤ 120 por golpe, multiplicador ≤ 3×, cura ≤ 400. Um mod pode trazer mais de uma coisa (o
`exemplo_mod` traz personagem + capa/aura + emote + efeito).

## 2. Estrutura que o criador entrega (na place de criação)
```
ServerStorage
└── Mods
    └── <IdDoMod>            (só letras minúsculas, números e _ — ex.: meteoros_do_ravy)
        ├── ModConfig        (ModuleScript) → { Id, Name, Author, AuthorUserId, Version, Kind, Desc, Rules?, Exclusive? }
        ├── CharacterDef     (ModuleScript) → CharacterDef (Id NOVO, Abilities 1..3 + ult com EnergyCost 100)
        ├── Cosmetics        (ModuleScript) → { Items = { {Id, Name, Category cape|aura, Color, Style?} }, Emotes = { {Id, Name, Kind} } }
        ├── VFX              (ModuleScript) → { Meshes?, Textures?, Effects = { ["<CharacterId>/<AbilityId>"] = { lifetime, layers } } }
        ├── Animations       (Folder) <CharacterId>/<AbilityId> (Animation; id publicado pelo GRUPO) · Emotes/<EmoteId>
        ├── Sounds           (Folder) <CharacterId ou Id>/<Nome> (Sound; ids PÚBLICOS ou do grupo)
        ├── VFX              (Folder, opcional) <CharacterId>/<AbilityId> (Model/Part montado no Studio)
        └── Map              (Model, só Kind = map)
```
Templates comentados de cada ModuleScript: `tools/place_criacao/Mods/exemplo_mod/` (ver o `LEIA-ME.md` de lá).
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

## 4. Como a equipe testa e sobe um mod
1. Inserir a pasta `ServerStorage.Mods.<Id>` no place oficial (Insert from File / MCP) — assets de animação/som
   publicados pelo GRUPO.
2. **No Studio** ela já aparece no painel Config → Mods como `[TESTE]` (o `ModService` lê o `ModConfig` de toda
   pasta de `ServerStorage.Mods` que não está no catálogo — só no Studio). Ligar, jogar, conferir a lista acima.
3. Aprovado: adicionar a entrada em `src/shared/Modules/ModsConfig.luau` (`Catalog`), com `Approved = data`.
4. Rodar `tools/analisar.sh`, testar num servidor privado de verdade, commitar; o dono salva/publica o place.
5. Anunciar no Discord com créditos ao autor. Ao enviar, o autor autoriza o uso do mod no jogo (mural de votação).

## 5. Painel no jogo
- **Config → Mods**: aparece para todo mundo em servidor privado (só o dono liga/desliga) e sempre para devs.
- Chip "MODS ATIVOS: nome (autor)" no HUD de todo mundo da sala.
- Servidor público: devs veem o catálogo mas o servidor recusa ligar ("só em servidor privado / Studio").
