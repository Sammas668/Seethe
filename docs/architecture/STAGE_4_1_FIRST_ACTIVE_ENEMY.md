# Stage 4.1 — First Active Enemy Combatant

Stage 4.1 turns the Settlement Guard from an automatic-pass fixture into the
first enemy that can move and attack through the same tactical systems as the
player.

## Behaviour

During the Enemy Turn the Guard:

1. refreshes its activation;
2. selects the nearest reachable active player character;
3. attacks immediately when already in reach;
4. otherwise moves into reach while reserving the attack cost when possible;
5. attacks after movement when legal;
6. otherwise moves as close as its remaining capacity permits;
7. ends its activation, or passes safely when no legal plan exists.

Movement and attacks commit through `TacticalStateStore`. The Guard uses its
resolved Training Spear attack, the shared attack preview, the shared dice
roller, critical confirmation, lethal damage, and the structured tactical log.

## Minimal defeat state

Lethal damage that reduces a unit to 0 HP changes its combat state to
`Defeated`. Defeated units remain on the map, cannot move or attack, and skip
future activations. Death, corpses, bleeding, stabilisation, equipment drops,
and campaign injury consequences remain deferred.
