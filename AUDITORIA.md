# AUDITORIA — ProjetoSahur

Data: 2026-09-14
Escopo: repositório `/home/trinck/ProjetoSahur` (branch `main`, único commit `827de6f "estado inicial"`).
Nenhum arquivo do projeto foi criado, editado ou apagado nesta etapa, exceto este relatório.

---

## 1. Mapeamento Rojo (`default.project.json`)

Existe um único arquivo de projeto. Ele mapeia:

| Instância no Studio                                  | Origem em disco       | Observação                                   |
|------------------------------------------------------|-----------------------|----------------------------------------------|
| `ReplicatedStorage.Shared`                           | `src/shared/`         | Módulos compartilhados                       |
| `ServerScriptService.Server`                         | `src/server/`         | `init.server.luau` vira o próprio `Server`   |
| `StarterPlayer.StarterPlayerScripts.Client`          | `src/client/`         | `init.client.luau` vira o próprio `Client`   |
| `Workspace.Baseplate`                                | (inline no JSON)      | Part 512×20×512, ancorado, travado, Y = -10  |
| `Workspace` (`FilteringEnabled = true`)              | (propriedade)         |                                              |
| `Lighting`                                           | (propriedades)        | Ambient preto, Brightness 2, Voxel           |
| `SoundService` (`RespectFilteringEnabled = true`)    | (propriedade)         |                                              |

Pontos relevantes do mapeamento:
- **Não há** mapeamento para `StarterGui`, `StarterPack`, `StarterPlayer.StarterCharacterScripts`, `ServerStorage`, `Players`, `Teams` nem `ReplicatedFirst`. Qualquer coisa colocada nesses serviços dentro do Studio **não é gerenciada pelo Rojo** e não aparece no repositório.
- O projeto **não** usa `$ignoreUnknownInstances`, então em `rojo serve` as instâncias criadas manualmente no Studio dentro de `ReplicatedStorage.Shared`, `ServerScriptService.Server` e `StarterPlayerScripts.Client` podem ser sobrescritas/removidas pela sincronização.
- Toolchain: `rokit.toml` fixa `rojo = 7.7.0`. Nenhuma outra ferramenta (Wally, Selene, StyLua, Luau LSP) está declarada.
- `rojo serve` está em execução no momento (PID 306849).

## 2. Inventário de `src/`

Árvore completa:

```
src/
├── client/init.client.luau
├── server/init.server.luau
└── shared/Hello.luau
```

| Arquivo                        | Conteúdo                                          | Estado                         |
|--------------------------------|---------------------------------------------------|--------------------------------|
| `src/server/init.server.luau`  | `print("Hello world, from server!")`              | Funcional; placeholder do Rojo |
| `src/client/init.client.luau`  | `print("Hello world, from client!")`              | Funcional; placeholder do Rojo |
| `src/shared/Hello.luau`        | Retorna função que faz `print("Hello, world!")`   | Funcional; placeholder, **nunca é requerido** por ninguém (código morto) |

Conclusão: **não existe nenhum sistema de jogo no repositório.** Os três arquivos são exatamente os gerados por `rojo init`. Não há:
- Services / Controllers / Modules.
- Módulo central de nomes de Remotes.
- Boot com `pcall` por serviço.
- Sistema de combate, dano, cooldown, moedas, partidas, times, HUD, dados persistentes.
- `PROGRESSO.md` (o CLAUDE.md pede que ele exista; ainda não foi criado).

## 3. Estrutura do lugar no Roblox (ReplicatedStorage, Workspace, StarterGui, StarterPlayer)

**Não foi possível inspecionar.** Motivos:
- Não existe nenhum `.rbxl`/`.rbxlx`/`.rbxm` no repositório nem em `/home/trinck` (busca até 4 níveis). O `.gitignore` ignora `/ProjetoSahur.rbxlx`, mas o arquivo nunca foi gerado/salvo em disco nesse caminho.
- O Rojo é unidirecional (disco → Studio) nesta configuração; a partir do terminal não há como ler o DataModel aberto no Studio.

Portanto, **qualquer asset da equipe de arte/animação (modelos de personagem, animações, sons, UIs) que exista dentro do Studio é invisível para este repositório**. Para a auditoria ficar completa, é necessário uma das opções abaixo (apenas para leitura, sem alterar nada):
- Salvar o lugar como `ProjetoSahur.rbxlx` (XML) na raiz do projeto, ou
- Colar aqui a saída de um script de listagem rodado na barra de comando do Studio (posso fornecer um script somente-leitura quando você autorizar).

## 4. RemoteEvents / RemoteFunctions

**Nenhum** definido em código. `src/` não cria, referencia ou nomeia nenhum Remote. Se existirem Remotes criados manualmente no Studio, eles não estão refletidos aqui (ver seção 3).

## 5. Inconsistências, código morto e duplicações

1. **Código morto:** `src/shared/Hello.luau` não é requerido por nenhum script.
2. **Divergência entre CLAUDE.md e repositório:**
   - CLAUDE.md afirma que "o projeto já tem trabalho anterior feito (código e/ou assets)". No repositório **não há** trabalho anterior de código; se existe, está apenas dentro do Studio (não versionado) ou em outro repositório.
   - CLAUDE.md pede `PROGRESSO.md`; ele não existe.
   - CLAUDE.md descreve uma "estrutura de pastas combinada no início do projeto" (Services/Controllers/Modules); essa estrutura não existe ainda em `src/`.
3. **Cobertura do Rojo incompleta para o tipo de jogo:** sem mapeamento de `StarterGui`, `ServerStorage`, `StarterCharacterScripts` e `ReplicatedFirst`, partes essenciais de um battlegrounds (HUD, assets server-side, scripts de personagem) ficariam fora do controle de versão se forem criadas no Studio.
4. **Risco de sobrescrita:** sem `$ignoreUnknownInstances`, instâncias manuais dentro das pastas sincronizadas podem ser apagadas pelo `rojo serve`.
5. **Sem duplicações** encontradas (não há sistemas para duplicar).
6. **Sem ferramentas de qualidade** (linter/formatter/LSP) no `rokit.toml`.

## 6. Resumo

O repositório está no estado de template zerado do `rojo init` 7.7.0. Do ponto de vista de código, o projeto começa do zero. A única incógnita real é o conteúdo do lugar aberto no Roblox Studio (assets de arte/animação e possíveis scripts/remotes não versionados), que precisa ser inspecionado por outro meio antes de qualquer decisão sobre "preservar vs. reconstruir".
