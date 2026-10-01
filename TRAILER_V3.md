# Trailer v3 — Bizarre Showdown F/X (2026-10-01)

Pedido do dono: trailer **épico e sério**, textos em **inglês**, **sem música** (entra na edição), até 120 s,
contagem de **3 s** antes de começar, **portal** com alguém que aparece, acena e volta, **JoJo poses**, tudo
sincronizado, versão **16:9 (YouTube)** e **9:16 (TikTok/Shorts)**.

Código: `TrailerService` (servidor: elenco, combate real, roteiro com tempo absoluto) + `TrailerController`
(cliente: câmera, cor, cartelas, efeitos de cena) + poses `Trailer/*` em `ProcAnimDefs`.
O inventário antigo `TRAILER_ASSETS.md` é do trailer v1 (16/09) e não vale mais.

## Como gravar
1. Studio → Play (Rojo conectado). Abrir o painel DEV → aba **Teste** → **TRAILER 16:9** ou **TRAILER 9:16**.
2. Tela preta com "PREPARING" pequeno no canto (o elenco nasce nos sets, até ~25 s) → **3, 2, 1** no canto → começa.
   Comece a gravar (OBS) na tela preta; corte o começo na edição.
3. **16:9**: grave a tela inteira; as barras de cinema (2.39:1) já vêm na imagem.
   **9:16**: o jogo desenha uma COLUNA 9:16 no meio e o resto fica preto → no OBS recorte só a coluna (ou crop
   na edição). Quanto maior a resolução do monitor, melhor a coluna (1440p dá 810×1440).
4. O log do servidor (Output) imprime a **folha de tempos** (`[Trailer] 00:12.0 ...`) com cada corte e texto.
5. **Parar / desfazer** devolve tudo (bots do mapa, jogadores, hora do dia, HUD).
6. **Cena avulsa** (botões da seção CENA AVULSA; "Cenas em 9:16" liga o enquadramento vertical) para regravar
   só um trecho.

## Ambiente controlado (tudo em runtime, nada é salvo no place)
- Inimigos/bots do mapa param (`idle`) e somem só na tela (`TrailerHidden`); bonecos de treino desligam.
- Jogadores estacionados no alto e invisíveis; HUD, topbar, nomes, barras de vida, plaquinhas e mouse somem.
- Hora do dia e cor (grade) por plano; luz própria (ColorCorrection/Bloom/DOF) que some no fim.
- Os sets estão em `MARKS` no `TrailerService`. **Ajustar sem código**: crie `Workspace.TrailerMarks` com uma
  Part chamada `Porto`, `Praia`, `Estrutura`, `Vila`, `Coliseu`, `Templo`, `Campos`, `Boss` ou `Portal` no lugar
  certo (o chão é achado por raycast embaixo dela).

## Roteiro 16:9 (~115 s) — folha de tempos
| Tempo | Cena | O que acontece | Texto |
|---|---|---|---|
| 0:00–0:08 | Abertura | preto → o Porto da Névoa vem do mar, névoa | "EVERY ERA BROKE AT ONCE." · PORT OF MIST |
| 0:08–0:15 | Praia | sobrevivente anda pelos destroços até a estrutura (plano de lado) → por cima do ombro, toca (flash 0:13.6) | "YOU SHOULDN'T BE IN ONE PIECE." |
| 0:15–0:27 | Mundo | 4 × 3 s: Vila, Deserto/Coliseu, Rota do Eclipse, Campos da Névoa | nomes dos lugares |
| 0:27–0:38 | Flecha | Flecha flutuando → atravessa (0:30.8) → Stand surge → roleta → **ANOMALOUS** (~0:36.2) | "THE ARROW CHOOSES." |
| 0:38–0:42.5 | Combo | 4 socos + finalizador (impacto 0:40.0) | 4-HIT COMBO |
| 0:42.5–0:49 | Parry | parry → CRITICAL (0:44.0) → parry → **BLACK FLASH** (0:46.6) | PERFECT PARRY / CRITICAL / BLACK FLASH |
| 0:49–0:53 | Dash | dash de longe com hit de chegada (0:49.75) | DASH STRIKE |
| 0:53–1:00.5 | Stands | rajada do Stand, lâmina de vento, moeda-bomba (2,5 s cada) | STAND RUSH / WIND BLADE / COIN BOMB |
| 1:00.5–1:11.5 | Tempo parado | rival pula → **o tempo para no ar** (1:01.0, imagem congela, P&B, "ゴゴゴ") → Stand descarrega → **o tempo volta** (1:06.5) | "TIME STOPS." |
| 1:11.5–1:22 | Despertar | cutscene real do despertar (estouro 1:16.8) + ult | AWAKENING / ROAD ROLLER |
| 1:22–1:31 | Boss | noite, Big C.H.O.P. contra 3 caçadores | "HUNT THE ECHOES." |
| 1:31–1:40.5 | Portal | abre (1:31.6), visitante atravessa, **acena** (1:34), volta, fecha (1:37.6) | "OTHER WORLDS ARE WATCHING." |
| 1:40.5–1:47 | Poses | 4 JoJo poses, Stands atrás, "ゴゴゴ", câmera baixa inclinada | — |
| 1:47–1:50 | To Be Continued | congela em sépia + seta | TO BE CONTINUED ⇒ |
| 1:50–1:55 | Logo | preto + BIZARRE SHOWDOWN F/X | PLAY NOW ON ROBLOX |

## Roteiro 9:16 (~60 s)
Abertura 0:00–0:05 · Flecha 0:05–0:14 (acerto 0:08.2, ANOMALOUS ~0:13.0) · Combo 0:14–0:18 (impacto 0:16.05) ·
Parry/Black Flash 0:18–0:24.5 (BF 0:22.1) · Stands 0:24.5–0:29.5 (2 golpes) · Tempo parado 0:29.5–0:39.5
(para 0:30.0, volta 0:35.5) · Portal 0:39.5–0:48 (aceno 0:42.5, fecha 0:46.1) · Poses 0:48–0:53.5 ·
To Be Continued 0:53.5–0:56 · Logo 0:56–1:00.
No 9:16 a câmera se afasta 1,6× do assunto e os textos ficam dentro da coluna.

## Correções após o 1º teste do dono (01/10)
- Som em LOOP sem fim: o zumbido da Flecha (`Shared/Awakening_Charge`, `Looped`) agora para quando a Flecha voa e no
  fim do trailer (`FX.PlaySoundUIStoppable`).
- Som de "troca de câmera": tirado o `Shared/Dash` que tocava em cada corte da montagem dos lugares.
- Abertura da praia sem o ragdoll: ele anda até a estrutura e a toca, com a câmera enquadrando ele E o ponto tocado.
- Enquadramento automático: plano com `frame = {atores/pontos}` → a câmera mantém o ângulo, recentra no grupo e se
  AFASTA até caber o corpo inteiro (cabeça e pés) na área visível do 16:9 e da coluna 9:16 (`fitFrame` no controller,
  margem 80%, teto 70 studs). Sem `frame` vale o comportamento antigo (VK no 9:16).
- Atores voam 35% do normal nos golpes que derrubam/dash (atributo `KnockbackScale` lido em `CombatService.Knockback`).

## Pontos de atenção (ver no primeiro Play)
- Os sets foram escolhidos pelos arquivos (sem o Studio aberto): se uma câmera atravessar parede/telhado ou um ator
  nascer em lugar ruim, é só pôr a Part em `Workspace.TrailerMarks.<Nome>`.
- Poses JoJo (`Trailer/Pose_*`) são procedurais (R6 sem cotovelo): ajustar ângulos em `ProcAnimDefs` se ficarem
  estranhas.
- O Black Flash depende da regra real (2 críticos seguidos); se sair só CRITICAL, aproximar o 2º parry.
- Textos sem nome de personagem de anime (o jogo é originalizado; ver BIZARRE_DIRECAO.md).
