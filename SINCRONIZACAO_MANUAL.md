# Construção manual do mapa no Studio (dono) → arquivos do Rojo (IA)

Objetivo: o dono move, cria e apaga à vontade no Studio — inclusive coisas que vieram do Rojo (`Workspace.Sahur.*`) —
e depois a IA grava tudo em `src/`, para o Rojo não desfazer nada ao reconectar.

## Parte do dono

1. Abrir o place oficial no Studio. **Desconectar o plugin do Rojo** (ou nem rodar `rojo serve`).
2. File > Save to File → `backups/place-antes-AAAAMMDD.rbxl` (cópia de segurança).
3. Construir/mover/apagar à vontade, com o Play parado (o que muda durante o Play não fica).
   - Coisa nova do mapa: de preferência dentro de `Workspace.Sahur` (em um Model/Folder próprio ou nas ilhas).
     O que ficar fora de `Workspace.Sahur` o Rojo não mexe, mas também não vai para os arquivos.
   - Não copiar bots/prompts que aparecem no Play (são criados pelo código).
4. File > Save to File → `backups/place-depois-AAAAMMDD.rbxl`.
5. Avisar a IA: "pronto, está em backups/place-depois-AAAAMMDD.rbxl". **Não reconectar o Rojo antes da IA terminar.**

## Parte da IA (Claude/Codex)

1. `tools/capturar_mapa.sh backups/place-depois-AAAAMMDD.rbxl` → confere o resumo (instâncias antes → depois,
   arquivos novos/removidos). Se algo sumiu que não devia, perguntar ao dono antes.
2. `tools/capturar_mapa.sh backups/place-depois-AAAAMMDD.rbxl aplicar` → grava em `src/workspace`, `src/maps`,
   `src/reserva`. Conferir `git diff --stat`, conferir marcadores/nomes que o código usa (`*_INTEGRACAO.md`,
   `WorldConfig`), rodar `tools/analisar.sh` e commitar só o mapa ("Mapa: captura da construção do dono AAAA-MM-DD").
3. Avisar o dono que pode reconectar o Rojo. Na tela de confirmação do plugin a lista de mudanças do mapa
   deve vir vazia ou quase; se aparecer remoção de peça, **não aceitar** e trazer para a IA.

Como funciona: `rojo syncback` (Rojo 7.7) com `tools/mapa.project.json`, que só aponta o mapa. Código e UI nunca são
lidos do place (lá está a versão velha do código). Depois da captura todo nó recebe `ignoreUnknownInstances`, então
peça criada no Studio e ainda não capturada nunca é apagada pelo Rojo. Consequência: para APAGAR uma peça do mapa, a
IA apaga no Studio via MCP (ou o dono apaga e a próxima captura registra), não só no arquivo.

## Regras depois da primeira captura

- **O Studio é a fonte do mapa.** Não rodar mais os geradores que reescrevem arquivos do mapa
  (`gerar_chao_ilhas.py`, `gerar_ilha_tutorial_fx.py`, `gerar_ilha_pilares_fx.py`, `gerar_ilha_sol_partido_fx.py`,
  `gerar_arena.py`) nem `MontarMundo`: apagariam o que o dono fez. Mudança do mapa por IA = editar o `.model.json`
  capturado (ou pelo MCP no Studio e capturar de novo).
- Enquanto o dono estiver construindo, a IA não mexe em `src/workspace`, `src/maps` nem `src/reserva`.
- Terrain, iluminação, Taberna/Lojinha e o resto fora de `Workspace.Sahur` continuam só no place.
- Publicação só pelo Studio sincronizado, com o dono. Nunca `rojo build`/API (incidente v422).
