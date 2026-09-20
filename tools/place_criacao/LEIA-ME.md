# Templates do kit de mods (place de criação da comunidade)

Cada mod é uma pasta `ServerStorage.Mods.<Id>` (só letras minúsculas, números e `_`). Dentro dela, ModuleScripts
de DADOS (nunca Script/LocalScript) e pastas de assets. Copie a pasta `Mods/exemplo_mod` como ponto de partida.

| Arquivo | Obrigatório | Para que serve |
|---|---|---|
| `ModConfig.luau` | sim | ficha do mod: Id, Name, Author, Version, Kind, Desc (+ Rules para Kind `rules`) |
| `CharacterDef.luau` | Kind `character` | personagem: habilidades 1/2/3 + ult (G), cor, tagline |
| `Cosmetics.luau` | Kind `cosmetic` | capas/auras (por cor e estilo) e emotes |
| `VFX.luau` | Kind `vfx` | efeitos compostos por código (VFXLibrary): meshes/texturas por id + camadas |
| `Animations/<CharacterId>/<AbilityId>` (Animation) | opcional | animações do personagem (id publicado pelo GRUPO) |
| `Sounds/<Id>/<Nome>` (Sound) | opcional | sons (id PÚBLICO ou do grupo) |
| `VFX/<Id>/<Nome>` (Model/Part/Attachment) | opcional | efeitos montados no Studio |
| `Map` (Model) | Kind `map` | props/áreas colocados no mapa (≤ 400 peças) |

No Studio do JOGO (equipe): toda pasta `ServerStorage.Mods.<Id>` com `ModConfig` válido aparece no painel
Config → Mods como **[TESTE]** sem precisar entrar no catálogo — liga, testa, e se passar na lista de
exigências (MODS_KIT.md) entra em `ModsConfig.Catalog`.

Os arquivos `.luau` aqui são o CÓDIGO-FONTE dos ModuleScripts: no Studio, crie um ModuleScript com o mesmo
nome (sem `.luau`) e cole o conteúdo. `tools/place_criacao/montar_mod.luau` (MCP) monta a pasta do exemplo.
