# Stage 4.5f — Authoritative Interrupted Movement and Reaction Resolution

## Purpose

Stage 4.5f removes the unsafe transaction boundary in which a Reaction attack could commit against a proposed path before the movement that triggered it became authoritative. Movement is now coordinated as safe committed segments separated by consequential rule boundaries.

## Locked timing

```text
Validate next step
→ resolve leaving-tile Interrupts
→ enter the destination when legal
→ resolve entering-area Interrupts
→ resolve hazards, detection and visibility consequences
→ continue or stop
```

- **Attack of Opportunity:** before entry; an incapacitated mover remains on the origin tile.
- **Overwatch and Brace:** after entry; an incapacitated mover remains on the triggering tile.

## Architecture

`TacticalMovementResolutionCoordinator` supplies the shared path-boundary and continuation helpers used by player movement, Sprint and enemy movement. It does not own pathfinding, attacks or visibility.

`TacticalState.pending_movement_reaction` is the authoritative record for an interrupted action. It stores the movement identity, path progress, interruption position, candidate, request, suppressed candidates and enemy continuation payload. Reconstructing services or presentation can therefore recover the same prompt and continuation.

While this record exists, `TacticalStateStore` rejects unrelated mutations. Reaction resolution, pending-state updates and lightweight exploration changes explicitly opt into pending-safe commits.

## Safe segment batching

Rules are evaluated step by step, but consecutive tiles with no Reaction, hazard, detection, newly revealed information or player decision may commit as one segment. This preserves the visibility and fog performance work from Stages 4.5e5–4.5e7a.

## RNG ownership

Each Reaction attack owns its own dice checkpoint. A successful Reaction commit permanently advances the stream. A later movement-segment failure can restore only work performed after that committed event.

## Rollback invariant

Rejected transactions restore tactical revision, occupancy revision, visibility-blocker revision, knowledge revision and environment-geometry revision. A failed command is therefore a true no-op for authoritative state and cache identity.

## Derived exploration

Visibility may calculate exploration during a state-change notification, but the resulting `exploration_updated` change set is queued with `commit_after_notifications()`. It commits only after the current signal stack completes, preventing nested authoritative commits.

## Invalidation policy

Production reasons now cover movement segments, pending Reaction states, inventory transfers, body actions, phase starts and initiative advancement. Unknown reasons report an error and use a full-refresh fallback rather than risking stale presentation.

## Non-goals

This stage does not add Counterspell, Intercept, Guard Ally, authored Reaction resources, a universal event scripting system, salvage authority changes or wall-material registries.
