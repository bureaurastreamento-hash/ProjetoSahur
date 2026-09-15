# Pesquisa: mecânicas dos battlegrounds de referência (2026-09-15)

Referências: **The Strongest Battlegrounds (TSB)**, **Jujutsu Shenanigans (JJS)**, **Heroes Battlegrounds (HB)**.
Fontes são wikis de fãs (Fandom, games.gg, namu, sites .wiki) — números variam entre fontes; tratar como
ordem de grandeza e afinar no teste. Cada seção termina com "**Sahur hoje**" (o que já temos) e
"**Fazer**" (o que implementar).

## 1. Controles (padrão dos 3 jogos)
- Mouse1 = M1 (segurar = combo automático) · F = block · Q = dash (direção do WASD; Q ragdollado =
  ragdoll cancel) · Espaço+M1 = uppercut · pular + M1 = **downslam** · G = ultimate/awakening ·
  B = emote · 1-4 = habilidades (TSB/JJS) · Shift = corrida/shift lock.
- **Sahur hoje** (2026-09-15 noite): Mouse1 (segurar = combo) ✓, F ✓, **Q = dash universal ✓ (Q caído =
  ragdoll cancel ✓)**, E/R/T habilidades, Shift shift lock, corrida automática, sem uppercut/downslam,
  sem G, sem emote.
- **Fazer**: downslam (pulo + M1) e uppercut (espaço durante M1) como variações do 4º golpe; **G para
  ativar a ult** (em vez de ela ser o slot 4 — ver §5); B = emotes (equipe faz animações).

## 2. M1 e combo
- TSB: 4 golpes = 3% / 3% / 4% / 4-5% da vida; o 4º **ragdolla** (lança e derruba). Depois do combo,
  "downtime" ~2 s (JJS). Segurar M1 repete sozinho.
- JJS: M1 startup 0,16-0,23 s; hitbox 8×8×8 studs, ativa ~16 ms; acerto dá **0,75 s de stun** na vítima
  e **puxa o atacante ~1 stud** para ela; M1 bloqueado tem o dobro de endlag (punição para quem bate no
  block). Combo padrão: 3 M1 + downslam.
- Uppercut (M1 no ar / espaço): levanta o alvo (segue combo aéreo). Downslam (pulo + M1): **ignora
  block**, prende no chão; não pode duas vezes na mesma janela de ragdoll. "True downslam" = do stun do
  3º M1, sem chance de ragdoll cancel.
- Wall combo (TSB): 4º M1 perto de parede + dash para frente = 12% de dano com cinemática.
- **Sahur hoje**: 4 golpes 8/8/8/15 de 100 HP (= 39%, muito alto), ComboEnd 0,9 s, hitstun 0,35 s,
  finisher com knockback, sem puxão, sem downslam/uppercut, sem endlag maior no block.
- **Fazer**: dano do combo para ~3/3/4/5 (15% total) com M1 mais rápido (0,3 s); hitstun 0,6-0,75 s;
  puxão de 1 stud no acerto; 4º golpe → **ragdoll** curto (1,2 s) em vez de só knockback; endlag ×2 quando
  o M1 é bloqueado; downslam (ignora block) e uppercut; wall splat.

## 3. Block, perfect block, guard break
- Block (F): reduz quase todo o dano; só cobre **180° à frente** (ataque por trás entra); anda devagar;
  não ataca/dasha bloqueando. Lockout: ~0,2 s depois de um M1 não dá para bloquear.
- Perfect block/parry (TSB ~0,2 s de janela): o próximo M1 vira **crítico (3× dano)** com som e flash
  vermelho; dois críticos em ~4 s sem outro golpe no meio = **Black Flash (6×)**. Em JJS, Black Flash é
  2,5× e só alguns personagens têm.
- Block breakers: certos golpes (downslam, alguns skills) **atordoam quem bloqueia**.
- **Sahur hoje**: block 70% de redução em qualquer ângulo, parry 0,2 s que atordoa o atacante 1 s,
  guarda de 60 que quebra (guard break 1,6 s de stun). Não há crítico nem black flash.
- **Fazer**: block só frontal (dot ≥ 0 com a direção do atacante); redução para ~90% e guarda menor;
  lockout de 0,2 s após M1; parry vira **crítico no próximo M1 (3×)** em vez de stun (opcional manter
  stun curto); Black Flash 6× como recompensa de 2 parries seguidos; golpes "block breaker" por flag na
  habilidade (`BreaksBlock = true`).

## 4. Dash, ragdoll e ragdoll cancel
- Dash Q na direção do WASD. Cooldowns (TSB): **lateral ~2 s, frontal ~5 s** (outras fontes: ~1 s);
  frontal serve para fechar distância e continuar combo; dash tem i-frames curtos em alguns jogos.
- Dash **funciona durante stun** (JJS) — é a principal ferramenta defensiva.
- **Ragdoll cancel**: Q (+ M1 segurado na direção do inimigo em JJS) enquanto ragdollado → levanta na
  hora com 0,5 s de i-frames; **cooldown de 15 s (JJS) / 30 s (TSB)**. Sem ele, combos longos entram
  inteiros. Bait: fazer o adversário gastar o cancel e então usar o combo de verdade.
- Ragdoll: estado derrubado por ~1,5-2 s; permite follow-ups; downslam não repete no mesmo ragdoll.
- **Sahur hoje** (FEITO 2026-09-15 noite, falta testar): dash universal no Q (CombatConfig.Dash: lateral/trás
  2 s, frontal 4,5 s, sem dano, sai durante hitstun, não em stun duro); ragdoll de combate (4º M1 1,6 s,
  finisher 2,2 s, GroundSlam/Bombo/Meteoro, Slam/Shockwave/Charge do boss) com ragdoll cancel (Q, 20 s,
  0,5 s de i-frames; levantar sozinho dá 0,2 s).
- **Era**: separar **dash universal** (Q, WASD, cooldown lateral 2 s / frontal 4-5 s, sem dano) das
  habilidades (E/R/T + G); ragdoll de combate (4º M1, downslam, alguns skills) com ragdoll cancel
  (Q, 15-30 s cd, 0,5 s i-frames); dash usável durante hitstun.

## 5. Ultimate / Awakening (a "carga da ult")
- Barra enche com **golpes dados, dano recebido e parries** (TSB: ~1,2% por soco, 3,5% por parry, ~29
  ações; JJS: dá e recebe dano). G ativa quando cheia.
- TSB: **Awakening** troca os 4 golpes por 4 mais fortes por ~15-30 s, com buff de velocidade/dano e
  dano passivo ao ativar; **Burst** = 50% da barra por 5-15 s de +40% dano e super armor. HB igual
  (Ultimate Mode muda HUD e moveset).
- **Sahur hoje** (após 2026-09-15): sem energia para habilidades; barra "ULT" enche +6/+4 por golpe
  dado/recebido; slot T custa a barra cheia (é um golpe único).
- **Fazer** (decisão do dono: "ult carrega durante a batalha"): virar **modo** — G com barra cheia ativa
  o Awakening por 20 s (aura VFX, +30% dano, +10% velocidade, Q/E/R/T trocam por versões fortes onde
  existir; onde não existir, só o buff). Parry dá +10 de carga. Barra some fora de combate devagar
  (opcional).

## 6. Vida, regen, stun, invencibilidade
- Vida 100 em todos (dano em %). Regen fora de combate lenta. Stun bloqueia tudo; "slowdown" limita.
- Invencibilidade completa em agarrões e ults; semi-invencibilidade em alguns skills (dano forte passa).
- **Sahur hoje**: 100 HP, regen 3/s após 6 s, stun, sem i-frames.
- **Fazer**: i-frames no ragdoll cancel e no início de ults; "super armor" (não toma hitstun) no Burst.

## 7. Modos, servidor, progressão
- Mapa livre com ~20 jogadores; **duelos 1v1/2v2** por menu (melhor de 3 rounds, mapa aleatório,
  ranking); **ranked** com elegibilidade; **kill streak** (10 kills = aura amarela + anúncio; a cada 5
  depois); leaderboard mensal com títulos; emotes (loja); gamepasses típicos: **VIP, Private Server+
  (sem cooldown, dummies, paredes de treino), Early Access (personagens em teste), emotes**.
- HB: **mastery** por personagem (usar = ganha; desbloqueia versão "mastered"), bosses em horário fixo
  com recompensa por dano (**quem mais bateu tem mais chance do drop raro**), enrage com contorno
  vermelho quando levam combo (empurra todos, +dano, +velocidade, cura o último dano, resiste a stun).
- **Sahur hoje**: mapa livre ✓, duelo 1v1/2v2 ✓ (round único), placar/leaderboard ✓, XP/nível/missões,
  loja (ids pendentes) com VIP/Todos os personagens/Moedas x2, Early Access = personagem Sahur.
- **Fazer**: kill streak com aura + anúncio; duelo melhor de 3; gamepass "Servidor privado+" (sem cd,
  dummies); mastery por personagem (substitui parte do XP genérico) — opcional; emotes.

## 8. Boss (referência HB/TSB)
- Spawn por timer/altar, avisos de wind-up claros, **enrage** (contorno vermelho: +dano, +velocidade,
  cura o último dano, menos stun) quando os jogadores estendem combo nele; empurrão em área ao enraivecer;
  recompensa dividida por dano com bônus para o top.
- **Sahur hoje**: altar, 6 golpes com telegraph, alvo por agressão, fase 2, recompensa por dano ✓.
- **Fazer**: enrage reativo (levou N golpes em 3 s → Roar + contorno vermelho + cura parcial), resistência
  a hitstun (boss nunca entra em hitstun), horário fixo além do altar, drop raro (emote/título) para o top.

## 9. IA de NPC/dummies
- Dummies de treino estáticos (private server+). Bosses são a única IA: máquina de estados
  (perseguir → escolher golpe por distância/cooldown → wind-up com telegraph → golpe → recuperação), reagem
  a combo com enrage, priorizam quem bate. Não há bots de PvP nos três jogos.
- **Sahur hoje**: bonecos estáticos ✓; boss com estados ✓.

## 10. Ordem sugerida para a próxima sessão
1. §4 dash universal (Q) + ragdoll de combate + ragdoll cancel (muda a base do combate; fazer primeiro).
2. §2 M1 (dano %, hitstun 0,7, puxão, endlag no block, downslam/uppercut).
3. §3 block frontal + crítico do parry (+ Black Flash).
4. §5 Awakening por G (modo de 20 s) no lugar do slot T.
5. §7 kill streak + duelo melhor de 3; §8 enrage do boss.

Fontes: games.gg (guias TSB combate/block, JJS iniciante, HB iniciante), the-strongest-battlegrounds.wiki
(basics, ultimate), fandom TSB/JJS/HB (resumos de busca), heroesbattlegroundswiki.wiki (bosses),
jujutsushenanigans.org.
