# Stage 4.4d — Cover Readability, Automatic Peek and Lean, and Interact

## Status

Implemented tactical presentation and interaction revision layered over Stage 4.4 combat geometry.

## Purpose

Stage 4.4 established separate line of sight, line of effect, directional cover, edge openings and damageable structures. Stage 4.4d does not replace that geometry. It makes the information readable before commitment and removes manual geometric micro-actions.

The locked player contract is:

```text
Move hover
→ preview physical edge cover and current visible-threat cover
→ preview automatic observation origins
→ commit only after the position is understood

Ranged attack
→ evaluate centre and legal lean origins
→ select the best legal origin automatically
→ charge only the ordinary attack cost

Physical opening manipulation
→ use the existing Interact command
→ keep right-click available for facing
```

## Ownership boundaries

### Authoritative geometry

`TacticalCombatGeometryQuery` remains the sole authority for line of sight, line of effect and cover. UI code displays geometry results but never recreates cover rules.

### Automatic observation origins

`TacticalObservationOriginQuery` derives zero-cost observation origins from the observer's current or proposed tile:

- centre origin;
- open doorway or window edges;
- legal sides of adjacent solid corners.

`TacticalVisibilityService` unions visibility from all legal origins. `DetectionObserverQuery` consumes the same origins so player and AI perception remain symmetrical.

Peek is not an action and owns no state. It never spends movement, actions, Quick Actions or Reactions.

### Automatic firing origins

`TacticalFiringOriginQuery` derives:

- the ordinary centre origin;
- legal opening lean origins;
- legal corner lean origins.

`AttackPreviewQuery` evaluates all legal origins for compatible ranged attacks. It prefers the centre origin when equally effective, otherwise selects the legal origin with the best cover result. The chosen origin is recorded in `TacticalAttackPreview` and revalidated at commitment.

Lean never spends additional movement or action capacity. The attack pays only `AttackDefinition.resolved_cost()`.

### Opening interaction

`TacticalOpeningHandler.available_interactions()` returns the legal physical operations for an adjacent opening. `TacticalScreen` enters Interact mode through the existing Interact button, highlights adjacent openings and either executes a single legal option or displays a compact choice list.

Peek and Lean are deliberately absent from the interaction list. Right-click no longer routes opening commands and remains the facing input.

## Cover presentation hierarchy

### Ordinary selected-unit state

The selected unit shows:

- physical edge shields on protected sides;
- one compact badge for the least favourable current cover result against visible enemies.

The old persistent eight-sector cover ring is no longer the primary presentation.

### Movement destination hover

Only the currently hovered destination receives detailed information:

- destination ghost and path;
- physical edge shields;
- a large least-favourable result: Exposed, Light, Heavy or Total;
- one compact category count line;
- small exact-result shields beside currently visible enemies;
- small eye markers showing automatic observation origins from the proposed tile.

No persistent firing lines or all-tile cover overlays are drawn.

### Attack targeting

The selected target shows exact cover, AC modifier and exposed sample count. If the chosen shot uses a lean origin, the board shows a short lean trace and edge-origin ghost, while the preview identifies Automatic Lean.

## Opening presentation

Doors, windows and bars remain mechanically edge-based. `TacticalBoardView` now renders them as substantial hand-inked architectural features:

- thick dark frames;
- painted wood, glass or metal fills;
- plank divisions, hatch strokes and visible bars;
- a visible swung door leaf when open;
- visible frame and fragments when broken;
- lock and damage marks layered on the object.

The artwork may extend slightly into both adjacent tiles while the authoritative edge remains unchanged.

## State and transaction rules

Automatic Peek and Lean are queries, not mutations. They do not enter `TacticalChangeSet`.

Physical opening operations retain the existing transaction order:

```text
validate adjacency and opening state
→ stage normal operation cost
→ stage opening state change
→ commit once
→ increment geometry revision
→ rebuild movement, visibility, line of effect and cover
→ emit presentation events
```

A changed geometry or tactical revision invalidates a stale attack origin and forces a fresh preview.

## Information restrictions

Movement destination previews and current-cover badges use only currently revealed hostile units and known geometry. Automatic observation markers may show the direction of possible observation but do not reveal hidden units or unexplored contents before movement commits.

## Regression boundary

Stage 4.4d must preserve:

- fog of war and squad-limited awareness;
- action economy and initiative;
- body, inventory and restraint interactions;
- extraction and mission resolution;
- idempotent campaign commitment;
- non-blocking hit reactions;
- Stage 4.4 structure damage, breaching, rubble and salvage.

## Runtime entry point

```text
res://tests/tactical/run_stage_4_4d_tests.gd
```

## Static entry point

```text
python tests/static/validate_stage_4_4d.py
```
