# Stage 4.4e1 — Cover UI Simplification and Movement Animation Hotfix

## Purpose

Stage 4.4e1 is a corrective presentation boundary over Stage 4.4e. It does not
alter tactical geometry or movement resolution. It reduces cover UI to two token
icons and prevents committed-state refreshes from snapping a unit to its final
cell before the movement tween is visible.

## Cover presentation contract

Only Light and Heavy Cover receive token icons:

- Light Cover: half shield;
- Heavy Cover: full shield;
- Exposed or no known hostile: no icon;
- Total Cover: no ordinary token icon; attack legality reports the shot as blocked.

One context owns the shield at a time:

```text
ordinary selection
→ selected character shield

movement destination hover
→ selected shield hidden
→ movement ghost shield

attack targeting
→ selected and ghost shields hidden
→ exact target shield
```

The automatic perception overlay remains the default selected-character tile
field. Movement hover temporarily replaces it with the cyan directional-cover
field. Attack and Interact remain higher-priority exclusive overlays.

## Cheap directional field

`TacticalDirectionalCoverFieldQuery` reads only local known cover around the
proposed destination and projects bounded directional wedges. It is explanatory,
not authoritative. It does not perform five exposure traces from every field tile.

Exact `TacticalCombatGeometryResult` values remain authoritative for visible
enemies, attack targeting, committed attacks and combat logs.

The board draws each cyan field tile with one fill. Heavy and Total categories add
one border. Per-tile hatch loops are deliberately excluded from the hover path.

## Hover boundary

A destination preview contains path, movement cost, exact visible-threat cover and
the cheap directional field. It does not calculate hypothetical automatic Peek,
perception or detection from the proposed tile.

```text
changed hover tile
→ retrieve/build one destination preview
→ update HUD once
→ redraw dynamic overlay once
```

Automatic Peek and perception are calculated once from the actual committed final
position.

## Authoritative movement and presentation

Movement remains a synchronous atomic tactical transaction. Detection resolution
may shorten the completed path before commit. Presentation then uses that completed
path without changing the authoritative result.

```text
commit authoritative movement
→ collect state-change callbacks
→ defer full visibility/current-perception rebuild
→ start movement and dragged-body tweens
→ wait for every moving view to finish
→ release visibility/perception deferral once
→ consolidate state presentation
→ synchronise all views to authoritative state
→ continue player or AI flow
```

`TacticalUnitView.animate_path()` resets the view to the committed path origin,
animates every completed path segment and emits `movement_animation_finished`.
`snap_to_tile()` ignores synchronisation attempts while that tween is active.

The tactical screen tracks presentation-only movement state with:

- `_movement_commit_in_progress`;
- `_movement_animation_active`;
- `_animating_unit_ids`;
- `_deferred_state_change_reasons`;
- `_deferred_damage_events`.

These fields do not own tactical state and are never saved.

## Visibility and perception deferral

`TacticalVisibilityService` supports nested recalculation deferral. Movement-related
state changes set one pending flag, and `end_recalculation_deferral()` performs one
full rebuild.

`TacticalDetectionService` separately defers only the post-action
`resolve_current_perception_for_squad()` refresh. Path detection preparation and
its possible movement interruption still resolve before movement commits, so the
rules are unchanged.

## AI movement

`EnemyTurnHandler` emits a presentation event after an enemy movement transaction
commits. Initiative and side-based enemy movement events are collected and animated
through the same batch presentation boundary. The next activation or environment
phase does not begin until the movement presentation completes.

## Dragged bodies

The dragger animates through the completed path. A dragged body's presentation
path begins at its pre-move ground cell and follows the dragger's previous cells.
For `A → B → C → D`, the dragger ends at `D` and the body ends at `C`.

## Regression boundary

This patch does not change:

- cover values or exposure sampling;
- movement costs or diagonal calculation;
- path detection and interruption;
- automatic Peek or Lean rules;
- opening interaction;
- body ownership and inventory locations;
- extraction or campaign commitment.

Derived caches and presentation flags are not saved. Save/load reconstructs them
from authoritative tactical state.
