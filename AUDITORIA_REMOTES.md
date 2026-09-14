# Auditoria de RemoteEvents / RemoteFunctions

Data: 2026-09-14. Fonte única de nomes: `src/shared/Modules/RemoteEvents.luau`.
Throttle: `RateLimiter` (token bucket por jogador). Chamadas acima do limite são
descartadas em silêncio. "Quem pode chamar" em Request*/Fetch* é sempre o próprio
jogador (o Roblox já garante que o `player` do `OnServerEvent` é quem disparou; o
código nunca aceita um "player alvo" vindo do cliente).

## Cliente → Servidor

| Remote | Handler | Throttle | Validação de valores | Validação de estado |
|---|---|---|---|---|
| `RequestAttack(attackId)` | CombatService | 10/s | `attackId` é string e existe em `CombatConfig.Attacks` | vivo, `CanFight`, não stunado, fora de cooldown. **Hitbox calculada no servidor** com a posição do servidor; cliente não envia alvo, posição nem dano |
| `RequestBlock(active)` | CombatService | 10/s | `active` é boolean | vivo, `CanFight`, não stunado; cooldown anti-spam de block (0,4s) |
| `RequestRespawn()` | HealthService | 1/s | — | só se o jogador estiver morto |
| `RequestAbility(slot)` | AbilityService | 8/s | `slot` é inteiro 1..8 e existe para o personagem atual | vivo, `CanFight`, não stunado, não "ocupado" (cast), cooldown **do servidor**, energia **do servidor**. Custos cobrados antes do efeito |
| `RequestSelectCharacter(id)` | AbilityService | 2/s | `id` é string e existe em `CharacterDefs` | não está em round (`InMatch`), personagem desbloqueado (`DataService.HasCharacter`) |
| `RequestQueue(inQueue)` | LobbyService | 2/s | boolean | não está em round |
| `RequestUnlockCharacter(id)` | DataService | 2/s | string e existe em `CharacterDefs` | perfil carregado, ainda não possui, moedas suficientes (tudo do servidor) |
| `FetchServerTime()` (RemoteFunction) | HealthService | 2/s | — | retorna `GetServerTimeNow()`; nil se throttled. *(antes desta auditoria não tinha handler: cliente que invocasse ficaria travado)* |

## Servidor → Cliente (Notify*)

Não recebem entrada do cliente, portanto não há validação a fazer. Todos carregam
somente dados que o servidor calculou. O cliente trata `Model?` como possivelmente nil
(personagem destruído antes do evento chegar).

`NotifyAttack`, `NotifyDamage`, `NotifyHealth`, `NotifyKill`, `NotifyCooldown`,
`NotifyBlock`, `NotifyMatchState`, `NotifyAbility`, `NotifyAbilityCooldown`,
`NotifyAbilityDenied`, `NotifyProfile`, `NotifyUnlockDenied`, `NotifyKnockback` (o cliente
vítima aplica o empurrão na própria física; o servidor concede `AntiExploit.Grace` antes).

## Onde o servidor ainda confia (ou depende) do cliente

1. **Movimento do personagem (geral do Roblox).** O cliente é dono da física do próprio
   personagem; posição/velocidade replicam do cliente para o servidor. Isso não é um
   remote nosso, mas afeta: a hitbox dos socos/habilidades usa a posição que o cliente
   reportou. Um speed/teleport hack coloca o atacante onde quiser. Mitigação futura:
   checagem de velocidade máxima no servidor (Heartbeat) e/ou usar `Humanoid.WalkSpeed`
   como teto para deslocamento por segundo.
2. **Dash (`Effect.Type = "Dash"`).** O servidor manda `NotifyAbility(..., {Speed, Duration})`
   e o *cliente* aplica o `LinearVelocity`. Um cliente modificado pode ignorar (não se
   mover) ou exagerar o dash. O **dano** continua 100% do servidor (hitbox na posição do
   servidor ao fim do dash), então o abuso se reduz ao item 1.
3. **Blink (`Teleport`).** Feito no servidor (`root.CFrame`), com raycast contra paredes.
   Não confia no cliente. OK.
4. **Nada de dano, vida, energia, cooldown, moedas, kills, vitória ou posição de acerto
   vem do cliente.** Todos os remotes Request* passam só identificadores/booleans.

## Removido/corrigido nesta auditoria

- `FetchServerTime` sem `OnServerInvoke` → implementado com throttle.
- `RequestSelectCharacter`, `RequestQueue`, `RequestRespawn` sem throttle → adicionados.
- `RequestSelectCharacter` não checava desbloqueio → agora checa via DataService.
- Throttle de ataque/block/habilidade era um intervalo fixo de 50 ms compartilhado por
  jogador → substituído por token bucket por remote.
