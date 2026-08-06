# Stage 4.2.5.5 — Tactical Visibility and Detection Hardening

## Purpose

Stage 4.2.5 established the complete first visual-stealth-to-initiative loop. This
hardening stage preserves that player-facing behaviour while correcting ownership,
query duplication, transaction granularity and avoidable recalculation exposed by
the larger 64×64 sandbox.

## Authoritative tactical knowledge

Current visibility is derived from current positions, sight ranges and blockers.
Explored terrain is historical mission knowledge and cannot be reconstructed from
the current board.

```text
TacticalState
└── TacticalKnowledgeState
    └── explored tiles by team

TacticalVisibilityService
└── currently visible tiles by team
```

`TacticalVisibilityService` may be destroyed and recreated without losing explored
history. `TacticalKnowledgeState.snapshot()` and `restore()` provide the boundary
needed by future tactical save, replay and deterministic-debug work.

## Shared line-of-sight authority

`TacticalLineOfSightRules` owns:

- `trace_line()`;
- `has_line_of_sight()`;
- `first_blocking_tile()`.

Ordinary team visibility, focused perception and AI last-seen checks consume this
same authority. A target wall tile remains visible; intervening blockers prevent
sight beyond it.

## Detection responsibility split

```text
DetectionObserverQuery
- hostile observer collection
- squad perception queries
- perception-overlay cache

DetectionPreviewQuery
- read-only path and per-tile avoidance previews

TacticalDetectionService
- Stealth roll outcomes
- movement interruption
- awareness/revelation commit and event records

ContactInitiativeResolver
- newly aware squad identification
- contact participant collection
- initiative totals
```

This is an incremental split rather than a rewrite. Existing handlers continue to
call `TacticalDetectionService`, which delegates read-only preview and contact work.

## Atomic squad perception

A squad refresh now:

1. checkpoints the dice source once;
2. prepares all hostile-unit resolutions without mutating tactical state;
3. rolls contact initiative once for the combined alert result;
4. snapshots every affected unit, squad, phase and action budget;
5. commits one `TacticalChangeSet`;
6. restores both tactical state and dice state if commit fails;
7. publishes detailed events only after successful commit.

This prevents partial squad knowledge and repeated full invariant/visibility passes.

## Visibility invalidation

Full team visibility now recalculates only for authored spatial reasons:

- unit movement or sprint movement;
- enemy movement;
- runtime spawn/removal;
- attacks that may change defeated sight providers;
- character resolution that may change sight-affecting state;
- map vision-blocker changes.

Inventory transfers, hand selection, action expenditure, facing and phase changes do
not rebuild 40-square team visibility.

## Perception-overlay cache

Overlay geometry is cached by:

- observer ID;
- grid position;
- resolved eight-direction facing;
- squad awareness;
- map vision fingerprint.

Returned arrays are duplicated so presentation cannot mutate the cache. The cache is
bounded and can be cleared explicitly.

## AI path-cost improvement

`MovementRules.movement_step_cost()` exposes the authoritative cost of one legal
step. `EnemyActionPlanner` now walks a path once while accumulating cost instead of
recalculating every longer prefix.

## Profiling hooks

The following diagnostics are available:

```text
TacticalVisibilityService.performance_snapshot()
TacticalDetectionService.perception_performance_snapshot()
TacticalBoardView.performance_snapshot()
```

Rendering-layer separation is deliberately deferred until local Godot profiling
shows whether static terrain or fog redraws are a material frame-time cost.

## Presentation boundary guard

Presentation still has temporary read access to the live tactical root. The Stage
4.2.5.5 validator forbids calls from presentation to known root mutators. Facade view
queries can replace direct reads gradually without a disruptive view-model rewrite.

## Acceptance criteria

- explored tiles survive visibility-service recreation;
- visibility and perception use one line trace authority;
- non-spatial commits do not rebuild team visibility;
- repeated overlay requests hit the perception cache;
- one squad perception refresh increments tactical revision once;
- every failed hidden target in the refresh is committed together;
- existing Stage 4.2.5.4a–4c controls and stealth behaviour remain unchanged;
- all static validators pass;
- the packaged Godot test passes locally in Godot 4.7.1.
