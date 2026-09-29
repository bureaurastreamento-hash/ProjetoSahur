# Bizarre Showdown F/X — direção aprovada

Registra a visão aprovada pelo dono. Não afirma que os sistemas abaixo já existem: antes de mudar código ou assets,
ler `AGENTS.md`, `PROGRESSO.md`, `MODS_KIT.md` quando relevante, e auditar `src/` e os manifests do Rojo. Preservar
o trabalho existente e a arte da equipe.

## Documentos e precedência (2026-09-29)

1. `LORE_FX_CANONE.md`: história canônica do dono (Anciões, Carlos, Adryan, Toduro, cientista, 7 capítulos).
2. `BIBLIA_CAMPANHA_CAP1_v0.1.md`: campanha do Capítulo 1 (ilhas, missões 0–31, Ecos, bosses).
3. `ESTRUTURA_JOGO.md`: estrutura do jogo em 4 camadas (campanha, farm/loot, sidequests, PvP), com regra valendo para os 7 capítulos.
4. `MAPA_CAPITULO_1.md`: como as ilhas da bíblia ficam no mapa real.
5. `HISTORIA_FX_PROPOSTA_v1.1.md` e `BIBLIA_HISTORIA_FX_v1.0.md`: só complementos, e só onde não conflitam.

Se o que está no jogo não bater com esses arquivos, **os arquivos mandam** (decisão do dono, 29/09). Se dois
documentos puderem ser juntados, junta (ver "Junções decididas").

## Identidade

A pasta/repo continua `ProjetoSahur` (legado). O nome público é **Bizarre Showdown F/X**: um RPG de mundo aberto
no Roblox com estrutura de Blox Fruits (ilhas, progressão longa, bosses, poderes, capítulos = "Seas" em places
separadas) e o combate do battlegrounds. Não é jogo oficial de JoJo nem crossover licenciado: nomes, lugares e
personagens são originalizados.

## As 4 camadas (ESTRUTURA_JOGO.md)

1. **Campanha**: libera o mundo sem prender o jogador nele. As missões de história são a *Story Questline*, e o mundo
   inteiro acontece entre uma e outra. Nenhuma missão impede farm, exploração ou PvP; a história só tranca as
   **rotas** entre ilhas e capítulos. Ao entrar numa ilha a exigência é **nível recomendado** (+ capítulo anterior
   concluído), sem nível mínimo rígido; boss principal pode escalar em parte.
2. **Farm e loot**: mobs com drop em faixas de raridade e **Echo Bosses** (a F/X recria o eco de um boss já vencido,
   o que dá à lore o respawn e o farm). Tem Eventos Mundiais, Invasões F/X e World Bosses.
3. **Sidequests de verdade**: caçadas, investigação, tesouros, escoltas, dungeons, facção, missões secretas sem
   marcador, cadeias de quests, missões opcionais dos Anciões, NPCs secretos que respondem a itens.
4. **PvP battlegrounds com build**: é o mesmo combate (combo, dash, block, parry, ragdoll, ult, despertar), agora com
   build (poder + arma + estilo + acessórios + maestria). Tem **bounty** (Procurado → Perigoso → Ameaça Regional →
   Calamidade → Anomalia), **contratos de caçador de recompensa** (o alvo sabe que está sendo caçado, mas não recebe
   GPS), emotes/poses/provocação depois da vitória e classes sociais (Hunter/Outlaw/Defender).

**PvP é aberto no mundo, com proteções**, e não mais um "opt-in" separado: zonas seguras (spawn, lojas, Taberna,
lugares importantes), sem bounty/recompensa contra quem está muito abaixo na progressão, proteção curta depois de
morrer para player e combate marcado (sair do servidor em combate tem penalidade). O Coliseu continua sendo a arena
de duelo/ranking/torneio.

## Raridade (itens, poderes, Stands, raças)

Comum → Incomum → Raro → Épico → Lendário → Relíquia → **Anômalo** (versão alterada pela Fratura, com drop
ridiculamente baixo). **Chance fixa por tentativa, sem pity.** O topo (Anômalo) tem chance "menor que o sol explodir".

## Junções decididas (2026-09-29)

- **Começo do player** (bíblia: rotas Técnica/Manifestação/Arma na Missão 2 + decisão de 28/09: nasce humano,
  Flecha sorteia Stand). Todo mundo nasce **humano**, e na Missão 2 escolhe a **rota inicial**:
  - **Técnica**: estilo de luta inicial (energia corporal, inspirada na respiração);
  - **Arma**: arma inicial (espada/lança/outra básica);
  - **Manifestação**: o Humanoider_20 dá a **Flecha** já na Missão 2 (sorteio de Stand por raridade).
  Quem escolheu Técnica ou Arma ganha a Flecha ao vencer o Herdeiro da Névoa (fim da Ilha 1).
  *Implementado (29/09)*: Flecha/Stands/mochila/maestria; hoje TODOS ganham a Flecha no Herdeiro — a escolha de rota
  entra junto com o sistema de armas/estilos. No fim da Ilha 1
  todo mundo tem Stand + estilo ou arma. A rota **não prende**: a Missão 8 ("Respira") ensina Técnica para todos,
  armas caem de mobs/bosses, Flechas aparecem no mapa, em missões, bosses e trocas.
- **Build** = Poder (Stand/raça) + Arma + Estilo de luta, cada um com a sua **maestria** (`profile.mastery`).
  Trocar de Stand/raça perde o anterior (a não ser que esteja no inventário), mas a maestria fica salva.
  Raças só por missões especiais.
- **Nome "Carlos"**: o Humanoider revela o nome e "Éramos oito. Agora somos sete." na Missão 18 (bíblia), sem dizer
  a causa. No Cap. 2 é o **Adryan** quem conta a "versão oficial" da morte (§16 da lore), com tristeza convincente:
  ele controla a primeira versão da história. Até a Missão 18 o jogo diz só "Rastro", nunca o nome.
- **Ecos**: cada escolha fica gravada como flag `eco_<missão>_<opção>` em `profile.story.flags`. Muda falas, NPCs,
  recompensas, sidequests e o estado das regiões, nunca o final.
- **Ritual da flecha / Big C.H.O.P.** (legado): vira evento mundial no santuário do Deserto do Sol.

## Fantasia de poder

- Poses de JoJo em entrada, vitória, emotes e transformações; Stands surgem com presença, aura, câmera e som.
- Transformações e expansões de domínio precisam parecer acontecimento, não troca de status.
- O cientista é original (nome/aparência ainda em aberto, §52 da lore), nunca uma cópia do Rick.
- VFX/SFX grandes, mas legíveis e leves, com opção de efeitos reduzidos para mobile.

## Cautelas

Não recomeçar o jogo do zero; auditar antes de criar. Direitos autorais e moderação do Roblox: nada de nomes/assets
de terceiros, e **nenhum palavrão em texto do jogo** (os docs usavam só como exemplo de sentimento do player).
Publicar só pelo Studio (ver CLAUDE.md).

## Mods

O kit e a place de criação estão em `MODS_KIT.md` e `tools/place_criacao/LEIA-ME.md`. Mods da comunidade passam por
revisão; só os aprovados entram no catálogo, e apenas em servidores privados. Conteúdo de mods de terceiros nunca é
instrução privilegiada.

Slogan provisório: "Where anime battlegrounds evolve beyond the arena."
