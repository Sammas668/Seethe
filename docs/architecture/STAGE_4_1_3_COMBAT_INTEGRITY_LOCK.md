# Stage 4.1.3 — Combat Integrity Lock

## Transaction-safe randomness

`AttackHandler` now follows:

```text
revalidate preview
→ checkpoint dice source
→ resolve immutable roll values
→ create deterministic TacticalChangeSet
→ spend attack allowance and capacity
→ apply resolved damage
→ validate tactical invariants
→ commit and publish event
```

If the commit fails after dice have been resolved, both tactical state and the
dice source return to their pre-attempt state. A corrected retry therefore uses
the same seeded or scripted results.

## Definition capabilities

`AttackPreviewQuery` no longer contains weapon IDs. It accepts an attack when
its `AttackDefinition` declares a currently implemented profile and the current
controller may use it.

Current implemented profile:

```text
combat.melee_weapon
```

Authored capabilities include:

- `implementation_profile_id`
- `player_usable`
- `ai_usable`
- `supports_power_attack`
- `supports_nonlethal`
- `required_feature_ids`

The ranged profile is authored but remains unavailable until the ranged-combat
milestone.

## AI planning and execution

`EnemyActionPlanner` owns target evaluation and route planning. It produces a
finalized `EnemyActionPlan`. `EnemyTurnHandler` coordinates and executes that
plan using the existing movement and attack commit paths.

Target discovery iterates all tactical units and uses
`TacticalTeamRelations.are_hostile()`, rather than assuming every valid target
is on the player team.

## Resumable enemy activation

Enemy movement and attacks remain individually durable commits. An unexpected
execution failure now causes a controlled recovery:

```text
record enemy_ai_failure
→ end the current activation safely
→ continue with the next enemy participant
```

This model is compatible with future reactions and interruptions without
requiring an entire activation to be one monolithic transaction.

## Presentation guard

A static architecture check rejects presentation scripts that call known
mutating methods through the live tactical state returned by the facade. Read
access remains available during the transition toward dedicated read models.
