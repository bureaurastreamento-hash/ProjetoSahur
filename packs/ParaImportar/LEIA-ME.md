# ParaImportar — tudo que precisa ir para o GRUPO (place 126518739287432)

Uma pasta só, separada por TIPO. Prefixo do arquivo = pack de origem: `JJS_` = OfficialJJS, `SBG_` = ShadowBattlegroundsfull
(packs Rova licenciados, liberados pelo dono em 2026-09-15). Nada daqui é lido pelo Rojo; o que entra no jogo é o ID
publicado (animação/áudio) ou a instância inserida no Studio (VFX/modelos) e depois referenciada em `src/assets/*.model.json`.

## Animacoes/ — KeyframeSequences (.rbxm) → precisam virar ANIMAÇÃO publicada pelo grupo
Como (no Studio, com o place do grupo aberto):
1. Explorer → botão direito em ServerStorage → **Insert from File** → escolha o .rbxm (ou `AnimPreview_todas.rbxm`, que tem todas com preview clicável).
2. Botão direito no KeyframeSequence → **Save to Roblox** → em Creator escolha o **grupo** → Submit. Copie o id.
3. Mande o id no formato `Pasta/Nome = id` (ex.: `Shared/Dash = 123`) que eu colo em `src/assets/Animations.model.json`.
Rig do jogo: R6. KeyframeSequence feito em R15 não mexe o boneco (o `[AnimCheck]` avisa).

| Arquivo | Origem | Sugestão de uso |
|---|---|---|
| `AnimPreview_todas.rbxm` | — | ver no preview |
| `JJS_Melee1.rbxm` | OfficialJJS | M1 alternativo |
| `JJS_Melee1_3.rbxm` | OfficialJJS | M1 alternativo |
| `JJS_todo mvp.rbxm` | OfficialJJS | ver no preview |
| `SBG_Automatic Save.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_Blue.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_Charge Punch.rbxm` | ShadowBattlegroundsfull | Brawler/ShoulderBash |
| `SBG_KeyframeSequence.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_RUCam.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_Red explode.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_Red projectile.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_Saitama Awak Camera.rbxm` | ShadowBattlegroundsfull | câmera do despertar |
| `SBG_Skillisisi.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_Untitled.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_VFX testing.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_VICTIM.rbxm` | ShadowBattlegroundsfull | Shared/Hit (vítima) |
| `SBG_Vergil practice.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_beatdown.rbxm` | ShadowBattlegroundsfull | finisher/agarrão |
| `SBG_explode.rbxm` | ShadowBattlegroundsfull | ult |
| `SBG_explode_2.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_finisher camera.rbxm` | ShadowBattlegroundsfull | câmera do finisher |
| `SBG_finisher.rbxm` | ShadowBattlegroundsfull | Finisher |
| `SBG_fire.rbxm` | ShadowBattlegroundsfull | habilidade |
| `SBG_fire_2.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_full.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_katana women stuf4.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_rah cam remade.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_red orij.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_ru.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_run.rbxm` | ShadowBattlegroundsfull | Shared/Run alternativo |
| `SBG_teleport.rbxm` | ShadowBattlegroundsfull | Swift/Blink |
| `SBG_thinbgs.rbxm` | ShadowBattlegroundsfull | ver no preview |
| `SBG_victim.rbxm` | ShadowBattlegroundsfull | Shared/Hit (vítima) |

## Audios/ — .mp3 → precisam virar ÁUDIO publicado pelo grupo
Creator Hub → Development Items → Audio → Upload Asset → Creator = **grupo** → selecione todos (bulk). Aguarde a moderação.
Mande `Nome = id` (ex.: `BatidaChao = 123`). Encaixe proposto: ver PROGRESSO.md / conversa de 2026-09-16 (Awekining → Shared/Awakening,
BatidaChao → GroundSlam_Hit/Bombo_Hit/Slam_Hit, Tremor → Quake/Shockwave/WallSplat, Grito → Roar/Rampage, Monstro* → Boss). Variações 2/3 viram alternativas sorteadas.

| Arquivo | Uso proposto |
|---|---|
| `AuraCarregando.mp3` | Shared/UltReady / Awakening_Charge |
| `AuraCarregando2.mp3` | Shared/UltReady / Awakening_Charge |
| `AuraCarregando3.mp3` | Shared/UltReady / Awakening_Charge |
| `AuraExplodindo.mp3` | Shared/Awakening_Burst |
| `AuraExplodindo2.mp3` | Shared/Awakening_Burst |
| `AuraExplodindo3.mp3` | Shared/Awakening_Burst |
| `AuraFinalizada.mp3` | Shared/Awakening_End |
| `AuraFinalizada2.mp3` | Shared/Awakening_End |
| `AuraFinalizada3.mp3` | Shared/Awakening_End |
| `Awekining.mp3` | Shared/Awakening |
| `Awekining2.mp3` | Shared/Awakening |
| `BatidaChao.mp3` | GroundSlam_Hit, Bombo_Hit, Boss/Slam_Hit |
| `BatidaChao2.mp3` | GroundSlam_Hit, Bombo_Hit, Boss/Slam_Hit |
| `Grito.mp3` | Boss/Roar, Brawler/Rampage |
| `Grito2.mp3` | Boss/Roar, Brawler/Rampage |
| `MonstroGrito.mp3` | Boss/Roar (fúria) |
| `MonstroGrunhido.mp3` | Boss/Charge |
| `Tremor.mp3` | Guardian/Quake, Boss/Shockwave, WallSplat |
| `Tremor2.mp3` | Guardian/Quake, Boss/Shockwave, WallSplat |
| `Tremor3.mp3` | Guardian/Quake, Boss/Shockwave, WallSplat |

## VFX/ — efeitos (.rbxm com Attachments/ParticleEmitters/meshes) → NÃO precisam de upload
São instâncias: Insert from File no Studio já funciona. Texturas/meshes dentro deles apontam para ids públicos ou do pack (se alguma
não carregar, é asset privado de outra conta). O jogo usa só os caminhos listados em `Assets.VFXPack` (Assets.luau); `lune run
tools/podar_vfx.luau` regenera `src/assets/VFX/Packs` a partir DESTA pasta. Para escolher efeitos: F7 no Studio (dev) abre o VfxPreview.

| Arquivo | Origem |
|---|---|
| `JJS_BuilderFX.rbxm` | OfficialJJS |
| `JJS_Charles.rbxm` | OfficialJJS |
| `JJS_Choso.rbxm` | OfficialJJS |
| `JJS_Damage.rbxm` | OfficialJJS |
| `JJS_Effects.rbxm` | OfficialJJS |
| `JJS_Gojo.rbxm` | OfficialJJS |
| `JJS_Goku.rbxm` | OfficialJJS |
| `JJS_Hakari.rbxm` | OfficialJJS |
| `JJS_Hanami.rbxm` | OfficialJJS |
| `JJS_Haruta.rbxm` | OfficialJJS |
| `JJS_Heian.rbxm` | OfficialJJS |
| `JJS_Hiromi.rbxm` | OfficialJJS |
| `JJS_Itadori.rbxm` | OfficialJJS |
| `JJS_Kurourushi.rbxm` | OfficialJJS |
| `JJS_Locust.rbxm` | OfficialJJS |
| `JJS_Mahito.rbxm` | OfficialJJS |
| `JJS_Mechamaru.rbxm` | OfficialJJS |
| `JJS_Megumi.rbxm` | OfficialJJS |
| `JJS_MeiMei.rbxm` | OfficialJJS |
| `JJS_Misc.rbxm` | OfficialJJS |
| `JJS_Nanami.rbxm` | OfficialJJS |
| `JJS_Naoya.rbxm` | OfficialJJS |
| `JJS_Ryu.rbxm` | OfficialJJS |
| `JJS_Todo.rbxm` | OfficialJJS |
| `JJS_Yuki.rbxm` | OfficialJJS |
| `JJS_Yuta.rbxm` | OfficialJJS |
| `SBG_AbyssalStrike.rbxm` | ShadowBattlegroundsfull |
| `SBG_AnotherWave.rbxm` | ShadowBattlegroundsfull |
| `SBG_B.rbxm` | ShadowBattlegroundsfull |
| `SBG_BlackFlash.rbxm` | ShadowBattlegroundsfull |
| `SBG_Brute.rbxm` | ShadowBattlegroundsfull |
| `SBG_Clones.rbxm` | ShadowBattlegroundsfull |
| `SBG_CursedEnergy.rbxm` | ShadowBattlegroundsfull |
| `SBG_DummyR6.rbxm` | ShadowBattlegroundsfull |
| `SBG_FakeDummy.rbxm` | ShadowBattlegroundsfull |
| `SBG_Futile.rbxm` | ShadowBattlegroundsfull |
| `SBG_GRR.rbxm` | ShadowBattlegroundsfull |
| `SBG_Garou.rbxm` | ShadowBattlegroundsfull |
| `SBG_Gojo.rbxm` | ShadowBattlegroundsfull |
| `SBG_GojoRework.rbxm` | ShadowBattlegroundsfull |
| `SBG_Goku.rbxm` | ShadowBattlegroundsfull |
| `SBG_Ichigo.rbxm` | ShadowBattlegroundsfull |
| `SBG_Jason.rbxm` | ShadowBattlegroundsfull |
| `SBG_Jawbreaker.rbxm` | ShadowBattlegroundsfull |
| `SBG_JudgementKick.rbxm` | ShadowBattlegroundsfull |
| `SBG_Kj.rbxm` | ShadowBattlegroundsfull |
| `SBG_Knife.rbxm` | ShadowBattlegroundsfull |
| `SBG_Knockback.rbxm` | ShadowBattlegroundsfull |
| `SBG_LegacyReplication.rbxm` | ShadowBattlegroundsfull |
| `SBG_MeteoricCombination.rbxm` | ShadowBattlegroundsfull |
| `SBG_PerfectBlock.rbxm` | ShadowBattlegroundsfull |
| `SBG_RU.rbxm` | ShadowBattlegroundsfull |
| `SBG_Saitama.rbxm` | ShadowBattlegroundsfull |
| `SBG_Sanda.rbxm` | ShadowBattlegroundsfull |
| `SBG_Scourge.rbxm` | ShadowBattlegroundsfull |
| `SBG_ShadowFist.rbxm` | ShadowBattlegroundsfull |
| `SBG_SlamMeshes.rbxm` | ShadowBattlegroundsfull |
| `SBG_SlaugherDemon.rbxm` | ShadowBattlegroundsfull |
| `SBG_SoulPunisher.rbxm` | ShadowBattlegroundsfull |
| `SBG_Sukuna.rbxm` | ShadowBattlegroundsfull |
| `SBG_SukunaCursedEnergyTrail.rbxm` | ShadowBattlegroundsfull |
| `SBG_TheAbyss.rbxm` | ShadowBattlegroundsfull |
| `SBG_Vergil.rbxm` | ShadowBattlegroundsfull |
| `SBG_Wind1.rbxm` | ShadowBattlegroundsfull |
| `SBG_Yuji.rbxm` | ShadowBattlegroundsfull |
| `SBG_YujiDivine.rbxm` | ShadowBattlegroundsfull |
| `SBG_Yuta.rbxm` | ShadowBattlegroundsfull |

## Modelos/ — mapas, personagens e armas dos packs → Insert from File (sem upload)
| Arquivo | O que é |
|---|---|
| `JJS_Characters.rbxm` | modelos de personagens do JJS (referência/skins) |
| `JJS_Map.rbxm` | mapa do JJS |
| `SBG_ArenaMap.rbxm` | arena do Shadow Battlegrounds (candidata a mapa de duelo/guerra) |
| `SBG_MainMap.rbxm` | mapa principal do SBG |
| `SBG_StudioMap.rbxm` | mapa de estúdio/teste do SBG |
| `SBG_Weapons.rbxm` | armas (Tools) do SBG |

Sons dentro dos packs: são só ponteiros de outra conta; só tocam se o asset for público (comando dev "Testar sons dos packs").
