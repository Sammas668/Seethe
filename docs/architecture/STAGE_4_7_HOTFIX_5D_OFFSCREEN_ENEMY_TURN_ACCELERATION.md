# Stage 4.7 Hotfix 5d — Off-Screen Enemy-Turn Acceleration

## Purpose

Enemy simulation remains authoritative, but presentation now waits only for consequences the player can observe.

```text
AI selects intent
→ command validates
→ transaction commits
→ observability is evaluated
→ visible consequence is presented or hidden activity completes immediately
```

The update does not skip AI rules, pathfinding, action spending, detection, reactions, initiative, hazards or final positions.

## Movement observability

AI movement is classified as:

- **Unobserved** — no path tile or final unit is visible and no player-observable Reaction occurs;
- **Partially observed** — one or more path tiles are visible, or a visible Reaction occurs, but the whole route is not visible;
- **Observed** — the complete route is visible.

Unobserved movement releases the existing visibility/perception deferral for the moved observers, flushes authoritative state changes and returns without a tween, timer or frame yield.

Partially observed movement uses only the longest contiguous player-visible path segment. The token is never reset to a hidden route origin for presentation.

## Initiative handoff

A hidden AI actor:

- is not selected in the tactical HUD;
- receives no active-unit pulse;
- receives no activation-handoff cadence;
- appears as **Enemy activity** in the phase header;
- appears as **Unknown enemy** in the initiative summary.

The handoff cadence remains for player units and visible AI units.

## Side-based Enemy Phase

The phase handoff cadence is retained only when at least one eligible Enemy Turn participant is currently visible. A phase containing only hidden participants begins resolution immediately.

Consecutive hidden actions are resolved in the existing stable order without one artificial wait per unit.

## Observable consequences

Normal presentation remains for:

- an enemy entering player sight;
- an alert/initiative transition;
- damage to a player-controlled or visible unit;
- a genuine player Reaction decision;
- visible movement segments.

A hidden attacker causing a visible result receives the generic status text **An unseen enemy action resolves** rather than exposing its identity. Its combat event remains player-visible for the impact, but the summary and detail payload redact the attacker name, weapon and roll breakdown.


## Combat-log privacy and cost

Routine enemy turn, movement and AI-failure events now carry a player/hidden visibility value determined by the tactical visibility service. Hidden journal entries remain available to diagnostics, but `TacticalCombatLog` ignores them before scheduling unread-count or deferred UI work.

## Performance diagnostics

`EnemyTurnHandler.performance_snapshot()` now includes:

```text
activation_timing.samples
activation_timing.total_usec
activation_timing.average_usec
activation_timing.maximum_usec
activation_timing.last
```

`TacticalScreen` adds counters for skipped off-screen movement batches, movement events and activation/phase handoffs.

## Boundaries

- Simulation is never replaced with a fake teleport command.
- Hidden movement still updates the moved observer through targeted visibility recalculation.
- No generic full tactical refresh is introduced.
- Player-visible events retain their existing cadence.
- No camera focus or exact hidden-position information is emitted.
