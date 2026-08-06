# Stage 4.4e — Tactical Geometry Performance and Cover Presentation

## Purpose

Stage 4.4e is a corrective optimisation boundary over Stage 4.4d. It retains the
authoritative directional-cover, automatic-Peek, automatic-Lean and mutable-opening
rules, but prevents cursor hover from repeatedly rebuilding geometry, visibility,
HUD state and the complete tactical board.

## Presentation contract

The selected-character default is the automatic perception overlay. Movement
hover is the only ordinary state that replaces it with the cyan directional-cover
field. Attack targeting and Interact are higher-priority exclusive overlay modes.
Only one full-tile overlay authority may draw at a time.

```text
Attack targeting
→ Interact
→ Movement destination cover
→ Automatic perception
→ None
```

The selected character and movement ghost use one compact bottom-left cover icon.
It reports the worst exact result against visible known threats. During attack
targeting the target icon instead reports the exact selected-attacker relationship.
The cyan field is a knowledge-limited directional explanation and never replaces
the five-sample geometry used for actual visible enemies or committed attacks.

## Geometry ownership

`TacticalGeometryCacheService` is the shared bounded cache for authoritative
`TacticalCombatGeometryResult` values. Cache keys include identities, positions,
firing/target overrides and tactical/environment/obstruction revisions. Attack
legality, hit chance, token presentation, combat resolution, combat logs and final
AI scoring reuse the same result.

`TacticalDestinationPreview` owns one complete hover result: path, movement cost,
detection preview, exact visible-enemy cover, broad cyan field, legal automatic
Peek origins and the revisions against which it remains valid. The presentation
layer never makes this result authoritative.

`TacticalDirectionalCoverFieldQuery` builds the broad cyan field from known local
geometry with bounded radius and caching. It does not perform five exposure traces
against every map tile. Exact visible-threat cover remains authoritative.

## Hover ownership

`TacticalScreen._on_board_tile_hovered()` is the single hover-refresh owner:

```text
changed tile
→ update hover state
→ retrieve/build one preview
→ refresh HUD once
→ redraw dynamic board once
```

Nested preview helpers do not redraw. Remaining on the same tile does no work.
Returning to a valid cached tile reuses the preview.

## Automatic Peek performance

`TacticalObservationOriginQuery` caches legal centre/corner/opening origins by unit
position and geometry revision. `TacticalVisibilityService` calculates centre
visibility once, then traces only the additional directionally relevant wedges
from automatic Peek origins. Tile and unit revelation are deduplicated before
visibility/detection events are emitted. Peek remains free and symmetric.

## Automatic Lean performance

`AttackPreviewQuery` evaluates the centre origin first. A legal uncovered centre
shot ends origin search. Otherwise only lean origins facing the target survive a
cheap directional and obstruction filter. Full five-sample evaluation runs only
for surviving candidates, and the winning cached result is reused by presentation,
resolution, logs and AI. Lean remains free beyond the normal attack cost.

## AI boundary

Ranged AI performs cheap path/range/local-cover/lean-plausibility scoring over
reachable candidates, retains a bounded shortlist and runs exact path plus combat
geometry only for that shortlist. The final action still uses the same authoritative
geometry service as player attacks.

## Rendering boundary

The tactical board is separated into:

- `TacticalStaticBoardLayer`: floor, walls, openings, structures and extraction art;
- `TacticalFogLayer`: explored and current-visibility treatment;
- `TacticalBoardView`: tokens, items, paths, hover, attack, Interact, Peek/Lean and
  cover/perception overlays.

Cursor movement queues only the dynamic layer. Static and fog layers invalidate
only after their authoritative inputs change.

## Event-driven presentation

Life-state and body-state visuals update after committed tactical state signals.
The screen `_process()` loop only positions a cursor-attached attack preview and
does not reconcile status every frame.

## Instrumentation

Development performance snapshots report cache hits/misses, five-sample traces,
destination-preview builds/hits, automatic Peek origin builds, automatic Lean
candidates, AI exact shortlist evaluations and static/fog/dynamic redraw counts.
The F9 debug output is not part of normal player presentation.

## Transaction and regression boundary

This stage does not alter movement costs, attack odds, cover values, detection
rules, opening interactions, body inventory, extraction or campaign commitment.
Caches are derived and are never saved. Save/load reconstructs them from tactical
and environment state.
