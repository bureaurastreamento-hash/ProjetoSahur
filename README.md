# Bizarre Showdown F/X

Projeto Roblox legado `ProjetoSahur`. Direção em `BIZARRE_DIRECAO.md`; estado e pendências em `PROGRESSO.md`.

Este projeto Rojo é **aditivo**: o mapa completo, Terrain e arte também vivem no place existente. Não abrir/publicar um `rojo build` como substituto desse place e não usar a API de publicação, conforme `AGENTS.md` e o incidente da versão 422.

Para sincronizar o código com o place existente, na raiz do projeto:

```sh
rojo serve default.project.json
```

Abrir o place correto no Studio e conectar o plugin Rojo ao servidor exibido. Conferir a proposta de sincronização antes de aceitá-la. Salvar cópia local do place completo antes de alterações importantes.

Antes de construir/modificar manualmente, seguir `SINCRONIZACAO_MANUAL.md`. Objetos extras são preservados pelo manifest aditivo, mas propriedades vinculadas aos arquivos podem ser reaplicadas pelo Rojo. Desconectar o plugin durante as mudanças manuais e preservar um `.rbxl` completo antes de reconectar depois delas.

Auditoria local, sem abrir Studio:

```sh
python3 tools/auditar_rojo.py --output /tmp/sahur-rojo-audit.json
bash tools/analisar.sh
```

Testes e seus limites estão em `tests/README.md`. Contratos dos mapas futuros: `CIDADE_AMBAR_INTEGRACAO.md`, `COSTA_DOURADA_INTEGRACAO.md` e `FORTALEZA_MARE_INTEGRACAO.md`.
