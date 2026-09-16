# Trailer — tudo que toca, plano a plano (2026-09-16)

Legenda: **ANIM** = `Assets.Animations.<Pasta>.<Nome>` (id atual ou VAZIO = não toca) ·
**VFX** = composição `VFXLibrary` (`Lib/Pasta/Nome`, ver no F7) · **SFX** = `Assets.Sounds.<Pasta>.<Nome>` ·
"(fallback)" = o nome próprio não existe e caiu num genérico → é onde mais aparece "reaproveitado".
Tempos = segundos desde o início do trailer (aprox.).

## Plano 1 — voo sobre o mapa (0–8 s)
- Cartela SAHUR / battlegrounds. Sem animação/som (só ambiente). **Sem música de fundo** (não existe ainda).
- Atores parados: **ANIM Shared/Idle** (119477589200226) — os atores NÃO rodam o MovementController, então
  na prática ficam na pose padrão do Roblox (sem Idle). → Fazer o trailer tocar Idle nos atores.

## Plano 2 — combo A → B (8–15 s)
Cada soco i = 1..4:
- ANIM **Shared/M1_1..M1_4** (ids do amigo, 0,17–0,30 s) — curtas demais para 0,42 s entre socos.
- VFX **Lib/Shared/Swing_1..4** (rastro do braço, novo).
- SFX **Shared/Punch_Whoosh** (4059009185) nos 1–3; no 4º **Shared/Finisher_Whoosh** (9114362943) + VFX **Lib/Shared/Finisher**.
- Acerto (0,15 s depois): VFX **Lib/Shared/Hit** (1–3) / **Lib/Shared/FinisherHit** (4º); SFX **Shared/Punch_Hit**
  (8595975878) / **Shared/Finisher_Hit** (9118609396); ANIM na vítima **Shared/Hit = VAZIO** (a vítima não reage!).
- 4º: vítima é empurrada por velocidade (sem ragdoll visual, sem VFX **Lib/Shared/Ragdoll** — só toca se o
  RagdollService fizer, e o ator não passa por ele).
Depois: parry de B → ANIM **Shared/Parry = VAZIO**, VFX **Lib/Shared/Parry**, SFX **Shared/Parry** (81202220081219).
B soca A: crítico → VFX **Lib/Shared/Crit**, SFX **Shared/Crit = não existe → (fallback) Finisher_Hit**;
Black Flash → VFX **Lib/Shared/BlackFlash** (+ pack RoughImpact), SFX **Shared/BlackFlash = não existe → (fallback) Finisher_Hit**,
ANIM vítima Shared/Hit = VAZIO.

## Plano 3 — habilidades (15–23 s)
- D Guardian **Quake**: ANIM **Guardian/Quake = VAZIO**; VFX **Lib/Guardian/Quake** (+ `_Hit` 0,5 s depois =
  Lib/Shared/FinisherHit); SFX **Guardian/Quake** (94833998861837, sorteia com Quake2 = 114477616922523 — que é o
  mesmo som do WallSplat!) e **Guardian/Quake_Hit** (7093763783 — mesmo do Roar_Hit/Shockwave_Hit).
- B Swift **Tempest**: ANIM **Swift/Tempest** (125017727896276, 4,17 s — longa, o plano corta antes); VFX
  **Lib/Swift/Tempest** (2,6 s); SFX **Swift/Tempest** (8120249833 — mesmo do Sahur/Ritmo).
- C Mystic **Meteor**: ANIM **Mystic/Meteor = VAZIO**; VFX aviso **Lib/Mystic/Meteor** no ponto, 1,5 s depois
  **Lib/Mystic/Meteor_Hit** (+ pack FinalImpact2); SFX **Mystic/Meteor** (966888080) e **Meteor_Hit** (3059775624);
  A leva "finisher" → VFX FinisherHit + SFX Finisher_Hit.
- A Brawler **Rampage** (ult): ANIM **Brawler/Rampage** (120293502970268, 4,23 s — longa); VFX **Lib/Brawler/Rampage**
  + `_Hit` (= FinisherHit); SFX **Brawler/Rampage** (108179413286388 / Rampage2 106127557057356 — este é o mesmo do
  Sahur/Toque) **+ Shared/Awakening_Burst por cima** (regra "ultimate toca o estouro").

## Plano 4 — DESPERTAR (23–31 s) — `CutsceneController.PlayAwakening` no ator A
- t0: SFX **Shared/Awakening** (78882004651878; fixo, sem sorteio) e **Shared/Awakening_Charge = VAZIO** (a carga
  longa fica MUDA por 5 s — é o buraco mais sentido). ANIM **Brawler/Awakening = não existe** (toca por cima se
  a equipe fizer). Poses procedurais R6 (código) + VFX **Lib/Shared/Awakening_Charge** (5,2 s) + contorno/aura.
- t = 5,0 s (BurstAt): VFX **Lib/Shared/Awakening_Burst** + aura **Lib/Shared/Awakening** (20 s, segue) ; SFX
  **Shared/Awakening_Burst** (83993296222949, fixo). Flash + shake.
- t = 5,45 s: pose de guarda (código). Fim em 7 s. (No trailer o "fim do modo" — Awakening_End — não toca.)

## Plano 5 — anoitece, santuário (31–37 s)
- Só ambiente: tochas (partículas), runa. Ator E parado com a flecha (RitualService.BuildArrow). Sem som.

## Plano 6 — transformação vista de fora (37–41 s)
- `NotifyBoss "transforming"`: aura (FX.SetAura) + VFX **Lib/Shared/Transform** (2,8 s). **Sem som nenhum**
  (não existe `Transform`/`Transform_Burst`). Sem animação no ator (fica parado).
- 2,6 s: ator some, rig **NotoriousBIG** aparece no lugar (sem VFX de "estouro" próprio) + VFX
  **Lib/NotoriousBIG/FleshWave** (para fingir o estouro) — SFX **NotoriousBIG/FleshWave = não existe** (mudo).
- `NotifyBoss "summoned"` → barra de boss (escondida no trailer) + SFX UI **Match/RoundStart** (3084314259) + shake.

## Plano 7 — B.I.G. em ação (41–50 s)
- Anda até 12 studs (Humanoid:MoveTo): animação procedural do rig (barris pisando).
- Soco: `NotifyAttack M1 1` → RigAnimController.Pulse (mordida) + ANIM Shared/M1_1 (não mexe o rig, ok) +
  VFX **Lib/Shared/Swing_1** + SFX **Shared/Punch_Whoosh**; acerto em A: VFX Hit + SFX Punch_Hit.
- **Crush**: `NotifyAbility NotoriousBIG/Crush start` → Pulse 2 + ANIM **NotoriousBIG/Crush = não existe** + VFX
  **Lib/NotoriousBIG/Crush** + SFX **NotoriousBIG/Crush = não existe** (mudo); 0,6 s: `_Hit` VFX (FinisherHit) +
  SFX Crush_Hit = não existe; A e D levam "finisher" (VFX/SFX Finisher_Hit) e voam.
- **Frenzy** (ult): VFX **Lib/NotoriousBIG/Frenzy** (2,2 s) + SFX Frenzy = não existe **+ Shared/Awakening_Burst** (regra da ult — soa deslocado aqui).
- `despawned` → nada visual.

## Plano 8 — Arena_Antiga (50–57 s)
- Só cenário (tochas com partículas). Sem som.

## Plano 9 — fechamento (57–63 s)
- Cartela SAHUR / em breve + fade. Sem som.

---

## Resumo do que está "reaproveitado" ou faltando (prioridade para o trailer)
**Sons que não existem (mudo ou fallback):**
1. `Shared/Awakening_Charge` (5 s de carga em silêncio) — o mais importante.
2. `Shared/Transform` + `Shared/Transform_Burst` (transformação no boss) — não existem nem no código; vou criar.
3. `NotoriousBIG/Crush`, `Crush_Hit`, `FleshWave`, `Frenzy`, `Devour`, `Devour_Hit` — boss mudo.
4. `Shared/Crit` e `Shared/BlackFlash` (hoje caem no Finisher_Hit).
5. `Shared/Hit_Stun` vazio; música/ambiente do trailer.
**Sons repetidos entre golpes diferentes:** Quake2 = WallSplat; Quake_Hit = Roar_Hit = Shockwave_Hit; Tempest =
Ritmo; Rampage2 = Toque; Slam_Hit = GroundSlam_Hit = Bombo_Hit; ShoulderBash = RagdollCancel; Leap = Finisher_Whoosh.
**Animações vazias que aparecem no trailer:** `Shared/Hit` (vítima não reage — muito visível), `Shared/Parry`,
`Guardian/Quake`, `Mystic/Meteor`, idle dos atores; `Brawler/Awakening` e as do B.I.G. não existem (o rig é por código).
**Animações longas demais para o corte:** Tempest 4,2 s, Rampage 4,2 s; M1 curtas (0,17 s) para 0,42 s de cadência.
**Timing no roteiro:** cadência dos socos (0,42 s) vs animação; Meteor aviso 1,5 s; Crush `_Hit` a 0,6 s; ult toca
Awakening_Burst por cima (regra geral, não do trailer).
