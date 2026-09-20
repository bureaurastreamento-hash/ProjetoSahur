# PESQUISA B1 — Kits novos por personagem (para o dono APROVAR antes de codar)

Data: 2026-09-24. Pedido do dono (23/09): **1/2/3/4 = 4 ataques (sem ult), R = 1 passiva/suporte com cooldown,
G = ult que TROCA os 4 ataques por outros 4 até acabar**, tirar o que não faz sentido, e o **Stand aparecer na
animação da ult**. Tudo abaixo foi pensado para rodar com o que o `AbilityService` JÁ executa; onde precisa de coisa
nova, está marcado **[NOVO]** (no máximo 2 por personagem, e vários se repetem entre personagens).

## 0. O que já existe (não precisa criar)

Tipos de efeito prontos no servidor: `Dash` (investida com hit, `HealPerHit`), `Grab` (finais `Slam`, `Throw`,
`Chokeslam`, `Spin`), `FlyGrab` (voo + agarrar + mergulho), `Teleport`, `AreaDamage` (`Radius`, `Delay`, `Offset`,
`StunSeconds`), `MultiHitArea` (`Hits`/`Interval`), `Projectile`, `Heal`, `Shield` (reduz dano recebido),
`DamageBuff`, `TimeDome` (bolha que deixa todo mundo lento, o dono mais rápido, com cinemática).
Extras já prontos: knockback com ragdoll, stun, i-frames, super armor, cutscene do despertar por personagem
(`AwakeningDefs`: nome da ult, tema, cor), animações procedurais (`ProcAnimDefs`) para TODAS as habilidades atuais.

Tipos novos propostos (somando todos os personagens, só **4**):
- **[NOVO] `Buff`** — generaliza o `DamageBuff`: `{ Damage?, Speed?, Duration }` (+ velocidade, não só dano). Trivial.
- **[NOVO] `Mark`** — marca a vítima; depois de `Delay` s (ou no próximo M1 do dono) ela explode em área. (Kira)
- **[NOVO] `Homing`** — projétil que persegue o alvo mais perto por `Duration` s e explode. (Kira, Rick)
- **[NOVO] `Rewind`** — guarda a vida/posição do dono e, `Delay` s depois, volta para lá. (Kira desperto, Rick)
Tudo o mais é combinação de tipos existentes com números e VFX diferentes.

Legenda das animações: **PROC** = eu faço no `ProcAnimDefs` (como hoje); **PACK** = existe candidato em
`packs/ParaImportar/Animacoes` (nome entre parênteses); **ARTE** = a equipe de animação precisa fazer (pose do Stand
ou golpe muito específico). Tudo que for PROC pode ser substituído pela arte depois sem mexer em código.

Regra de números: vida 100, M1 6–10, combo de 4 ≈ 32. Ataque normal 12–24 de dano; desperto ×1,3–1,6.

---

## 1. JOTARO — Star Platinum (inicial, punhos)
Identidade: **soco, agarrão e pressão de perto**. Tira: `Rampage` (ult genérica de área).

| Slot | Nome | Tipo | Números | Animação |
|---|---|---|---|---|
| 1 | **Rajada ORA** | `MultiHitArea` com `Offset` 4 (cone à frente) | 6 hits × 4 = 24, 0,12 s, empurrão no último | PACK (`SBG_beatdown` / `JJS_Melee1`) |
| 2 | **Arremesso** (mantém) | `Grab` `Throw` | 16, cd 8 | PROC (já existe) |
| 3 | **Soco Estrela** | `Dash` com hit | 18 + ragdoll curto, alcance 14, cd 9 | PACK (`SBG_Charge Punch`) |
| 4 | **Pancada no Chão** (mantém) | `AreaDamage` | 20, raio 12, cd 10 | PROC (já existe) |
| R | **Postura do Stand** | `Shield` 0,5 por 4 s + `Buff` velocidade 1,15 | cd 20 — "aguenta e avança" | PROC (pose de guarda) |

**G — STAR PLATINUM: THE WORLD** (20 s). Cutscene: Star Platinum aparece atrás dele (B4), grito "ORA".
Kit desperto:
| Slot | Nome | Tipo | Números |
|---|---|---|---|
| 1 | **ORA ORA ORA** | `MultiHitArea` cone | 12 hits × 4 = 48, 0,08 s, ragdoll no fim |
| 2 | **Parada do Tempo** | `TimeDome` `SlowMultiplier = 0`, raio 18, 2,5 s (curta; sem cinemática) | cd 15 |
| 3 | **Soco Estrela Máximo** | `Dash` | 28, alcance 20, ragdoll 2 s |
| 4 | **Impacto Estelar** | `AreaDamage` raio 16, `Delay` 0,5 | 34, ragdoll 2 s (o "golpe final" que era o Rampage) |
Animações da forma: 1 e 3 PACK (mesmos, mais rápidos); 2 e 4 ARTE (pose icônica com o Stand) — PROC provisório.

---

## 2. BRUNO GOLLINI (id `Swift`) — o Domínio do Tempo (dono: cúpula MHA)
Identidade: **velocidade, tempo, pisca**. Mantém o Piscar no Q (`DashOverride`). Tira: nada — hoje ele só tem 2
slots; completa para 4.

| Slot | Nome | Tipo | Números | Animação |
|---|---|---|---|---|
| 1 | **Rasteira** (mantém) | `AreaDamage` raio 8 + stun 0,8 | 12, cd 8 | PROC (já existe) |
| 2 | **Lâmina de Vento** | `Projectile` rápido | 14, veloc. 120, alcance 60, cd 6 | PACK (`SBG_Red projectile`) |
| 3 | **Corte Cruzado** | `Teleport` 10 atrás do alvo + `AreaDamage` raio 6 (dois passos na mesma habilidade — já dá com `Delay`/`Offset`) | 16, cd 10 | PACK (`SBG_teleport` + `JJS_Melee1_3`) |
| 4 | **Tempestade** | `MultiHitArea` raio 9 | 4 hits × 5 = 20, 0,2 s, cd 14 | PACK (`Swift/Tempest` já publicado: 125017727896276) |
| R | **Aceleração** | `Buff` velocidade 1,3 por 5 s + cooldown do Piscar −50 % | cd 18 | PROC |

**G — DOMÍNIO DO TEMPO** (mantém o `TimeDome` 14 s com cinemática — é a ult que o dono aprovou; ela é a
"cutscene" e o efeito). Sem Stand (não é JoJo); em vez disso o **relógio/aura** dele. Kit desperto (dentro da cúpula):
| Slot | Nome | Tipo | Números |
|---|---|---|---|
| 1 | **Mil Cortes** | `MultiHitArea` raio 8 | 8 × 4 = 32, 0,1 s |
| 2 | **Lâminas Gêmeas** | `Projectile` ×2 (`Count = 2`, pequeno ajuste no tipo) | 2 × 14 |
| 3 | **Corte Fantasma** | `Teleport` + `AreaDamage` raio 8 + stun 1 s | 24 |
| 4 | **Quebra do Tempo** | `AreaDamage` raio 14, `Delay` 0,6, ragdoll 2 s | 34 (estoura a cúpula, como hoje `BreakMultiplier`) |

---

## 3. DIO — The World (VIP)
Identidade: **tempo parado, facas, rolo compressor, vampiro**. Tira: `ShieldBash`/`Fortify`/`Quake` (kit de tanque
genérico — nada disso é o Dio).

| Slot | Nome | Tipo | Números | Animação |
|---|---|---|---|---|
| 1 | **Rajada MUDA** | `MultiHitArea` cone `Offset` 4 | 6 × 4 = 24, 0,12 s | PACK (`SBG_beatdown`) |
| 2 | **Facas** | `Projectile` ×3 em leque (`Count = 3`, `Spread = 12°`) | 3 × 8, cd 7 | PACK (`SBG_Red projectile`) |
| 3 | **Golpe Vampírico** | `Dash` com `HealPerHit` 12 | 16 + cura, cd 10 | PACK (`SBG_Charge Punch`) |
| 4 | **Joelhada Real** | `Grab` `Chokeslam` (mantém a mecânica do Esmagar, novo nome/VFX) | 14 + área 10, cd 9 | PROC (já existe) |
| R | **Sangue Frio** | `Heal` 20 + `Shield` 0,6 por 3 s | cd 22 | PROC |

**G — THE WORLD** (20 s). Cutscene: The World atrás dele, "ZA WARUDO", tela dessatura (já existe tema `stone`,
trocar para tema novo `time`). Kit desperto:
| Slot | Nome | Tipo | Números |
|---|---|---|---|
| 1 | **MUDA MUDA MUDA** | `MultiHitArea` cone | 12 × 4 = 48, 0,08 s |
| 2 | **Parada do Tempo** | `TimeDome` `SlowMultiplier = 0`, raio 22, **5 s** (mais longa que a do Jotaro; sem cinemática) | cd 15, 1× por despertar |
| 3 | **Chuva de Facas** | `Projectile` ×6 (`Count = 6`) | 6 × 8 |
| 4 | **ROLO COMPRESSOR** | `AreaDamage` `Offset` 10, raio 12, `Delay` 0,9 + VFX de um rolo caindo (peça/modelo) | 40, ragdoll 2,5 s |

---

## 4. YOSHIKAGE KIRA — Killer Queen (distância/controle)
Identidade: **bombas, marcar e detonar, Sheer Heart Attack, Bites the Dust**. Tira: `ArcaneBolt`/`Mend`/`Meteor`
(mago genérico).

| Slot | Nome | Tipo | Números | Animação |
|---|---|---|---|---|
| 1 | **Toque da Bomba** | **[NOVO] `Mark`**: hit curto à frente (raio 4) marca; o **próximo M1** no marcado explode (raio 6) | toque 8 + explosão 16, cd 8 | PROC (toque) + PACK (`SBG_explode`) |
| 2 | **Moeda Bomba** | `Projectile` lento com área ao explodir (`Radius` 6) | 18, cd 9 | PACK (`SBG_Red explode`) |
| 3 | **Sheer Heart Attack** | **[NOVO] `Homing`**: mini-tanque no chão persegue o mais perto por 6 s e explode (raio 7) | 22 + ragdoll, cd 16 | PROC (invocar) + VFX peça |
| 4 | **Detonação em Cadeia** | `AreaDamage` raio 12, `Delay` 0,5 (ar ao redor "vira bomba") | 20, cd 12 | PACK (`SBG_explode_2`) |
| R | **Mãos Limpas** | `Teleport` 12 para trás + i-frames 0,5 + `Heal` 10 | cd 18 (fuga) | PACK (`SBG_teleport`) |

**G — KILLER QUEEN** (20 s). Cutscene: Killer Queen atrás, pose do polegar, tema `arcane`→`bomb`. Kit desperto:
| Slot | Nome | Tipo | Números |
|---|---|---|---|
| 1 | **Primeira Bomba** | `Mark` em área (raio 8, marca todos) + detona sozinha em 1,5 s | 26 |
| 2 | **Chuva de Moedas** | `Projectile` ×4 em leque com área | 4 × 12 |
| 3 | **Sheer Heart Attack ×2** | `Homing` ×2, 8 s | 2 × 22 |
| 4 | **BITES THE DUST** | **[NOVO] `Rewind`**: marca o instante; 4 s depois o Kira volta com a vida/posição daquele instante e explode em área (raio 14) | 38 — a "escapada + revanche" |

---

## 5. RICK → RICK PRIME (exclusivo do boss)
Identidade: **portal gun, ciência, voo do Prime**. Hoje só tem a ult `PrimeDive` (`FlyGrab`); completa o kit.

| Slot | Nome | Tipo | Números | Animação |
|---|---|---|---|---|
| 1 | **Pistola Laser** | `Projectile` rápido (raio 2) | 12, cd 4 | PACK (`SBG_Red projectile`) |
| 2 | **Portal** | `Teleport` 22 na direção da mira | cd 8 | PACK (`SBG_teleport`) |
| 3 | **Drone Sentinela** | **`Homing`** (mesmo tipo do Kira): drone voa até o alvo e dá choque + stun 0,8 | 16, cd 12 | PROC + VFX peça |
| 4 | **Bomba de Neutrinos** | `AreaDamage` `Offset` 12, raio 10, `Delay` 0,8 | 24, cd 12 | PACK (`SBG_explode`) |
| R | **Kit Médico** | `Heal` 25 + remove stun/ragdoll | cd 22 | PROC |

**G — RICK PRIME** (20 s). Cutscene: portal verde, ele sai como Prime (já existe tema `void`, cor verde). Kit desperto:
| Slot | Nome | Tipo | Números |
|---|---|---|---|
| 1 | **Laser Prime** | `Projectile` ×3 seguidos (`Count = 3`, `Interval`) | 3 × 12 |
| 2 | **Portal Duplo** | `Teleport` 30 + `AreaDamage` raio 6 ao chegar | 14 |
| 3 | **Mergulho Prime** | `FlyGrab` (a ult atual, vira o slot 3 desperto) | 45 |
| 4 | **Omega Device** | `AreaDamage` raio 20, `Delay` 1,2, ragdoll 3 s (o "apaga tudo") | 44 |

---

## 6. SAHUR (acesso antecipado) e OVERLORD (admin)
- **Sahur**: fica como está (ritmo/tambor) só completando 4 slots: 1 Bombo, 2 Toque (vira **R**), 3 Ritmo (vira o
  slot 4 desperto), + 2 ataques novos simples (`Dash` "Compasso" e `Projectile` "Baqueta"). Baixa prioridade.
- **Overlord**: já tem 4; só ganha um R (`Heal` 100) e o kit desperto = os mesmos 4 com números ×2. Não aparece
  para jogador.

---

## 7. O que muda de esquema (B2/B3 — resumo para você bater o martelo)
- `CharacterDef`: `Abilities` (4, sem `EnergyCost`), `Passive` (R: `AbilityDef` com cooldown próprio, não gasta
  slot), `Ultimate` (`{ Name, Duration, Stand?, Cinematic? }`), `AwakenedAbilities` (4). Os campos
  `AwakenedEffect` de hoje somem (cada golpe desperto é uma habilidade completa, com nome próprio na HUD).
- HUD: 5 slots (1–4 + R); ao despertar os 4 "viram" com animação e ficam com a cor do personagem.
- Bots/traidor/trailer usam R e o kit desperto automaticamente (a IA já lê `def.Abilities`).
- Mods de asset (`ModRegistry`/templates do kit) migram para o esquema novo — vou atualizar `MODS_KIT.md`.
- **Stands (B4)**: precisa de 3 modelos da arte (Star Platinum, The World, Killer Queen) OU eu monto por peças
  (estilo BossRigs) como provisório. O Stand aparece na cutscene e como "sombra" atrás nas rajadas ORA/MUDA.

## 8. Variações de golpe (ideia D2, estilo Jujutsu Shenanigans) — opcional, decidir depois
Cada ataque poderia ter `Variants`: **no ar** (ex.: Rajada ORA no ar = mergulho), **correndo** (Soco Estrela vira
tackle), **alvo caído** (Pancada no Chão vira pisão único forte), **emendado** (Facas logo após Parada do Tempo =
todas acertam). O servidor escolhe pelo estado. Sugestão: fazer primeiro o kit base (acima), depois 1 variante por
personagem como prova de conceito.

## 9. O que preciso de você para começar o B2
1. Aprovar/alterar os nomes e os 4+R+4 de cada personagem (pode riscar/trocar direto neste arquivo).
2. Dizer se a **Parada do Tempo** entra nos dois (Jotaro 2,5 s e Dio 5 s) ou só no Dio.
3. Stands: arte faz os modelos (quais primeiro?) ou eu monto por peças como provisório?
4. Sahur fica no roster ou sai?
