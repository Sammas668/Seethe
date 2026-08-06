# Stage 4.0.1 — Team Control and Enemy Turn

## Purpose

Establish the minimum allegiance and control model required before expanding combat. The Training Dummy is a genuine enemy-team participant rather than a player unit or an arbitrary attackable object.

## Locked runtime distinctions

- `team_id` determines tactical allegiance.
- `controller_type` determines who may issue commands.
- `turn_behavior` determines what the controller does during its activation.
- `participates_in_enemy_turn` determines whether an enemy receives an activation.
- `counts_for_victory` remains independent from team membership.

The Training Dummy is configured as:

```text
team_id                    enemy
controller_type            ai
turn_behavior              auto_pass
participates_in_enemy_turn true
counts_for_victory         false
persistence_scope          mission
```

## Team relationships

`TacticalTeamRelations` currently resolves:

```text
Player ↔ Player   Allied
Enemy  ↔ Enemy    Allied
Player ↔ Enemy    Hostile
Player ↔ Neutral  Neutral
Enemy  ↔ Neutral  Neutral
```

Stage 4.0.1 attacks require a hostile relationship. Friendly fire and attacks against neutrals remain deferred.

## Enemy Turn skeleton

Ending the Player Phase begins the existing World Phase, presented as the Enemy Turn. `EnemyTurnHandler` gathers eligible AI-controlled enemy units and commits one activation per participant through `TacticalStateStore`.

The current fallback is Automatic Pass:

```text
refresh activation resources
→ record turn start
→ no legal actions available
→ mark activation ended
→ record automatic pass
```

The Training Dummy therefore participates in enemy turn flow without moving or attacking. The Settlement Guard uses the same fallback until Stage 4.2 supplies real AI behaviour.

## Player-control safeguards

- Player roster generation includes only player-team participants.
- Tactical commands require `unit.is_player_controlled()`.
- Enemy and neutral units remain inspectable but read-only.
- The Training Dummy cannot become an attacker through the player combat interface.

## Deferred

- Individual initiative.
- Enemy movement and attacks.
- Victory resolution.
- Nonlethal defeat and unconsciousness.
- Reactions, opportunity attacks and stealth transitions.
