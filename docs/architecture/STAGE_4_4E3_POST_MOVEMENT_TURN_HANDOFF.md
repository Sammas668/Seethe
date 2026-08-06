# Stage 4.4e3 — Post-Movement Delta Refresh and Turn-Handoff

## Corrected cadence

```text
movement transaction commits
→ token and dragged body animate
→ moved observer visibility contribution is replaced
→ newly explored tiles and queued perception resolve
→ affected fog, tokens, cover and HUD refresh once
→ one rendered frame
→ next action or activation
```

Ordinary movement never calls `recalculate_all_teams()` during the presentation handoff.

## Incremental visibility model

`TacticalVisibilityState` stores:

- a per-team tile reference-count array;
- the tile-index contribution for every observing unit;
- the team associated with each contribution.

Replacing one unit's contribution subtracts its old tile indices and adds its new visible tile indices. Tiles remain visible when another allied observer still contributes to them.

`TacticalVisibilityService.recalculate_units()` performs the moved-observer path. `end_recalculation_deferral_for_units()` uses it after ordinary movement. Major geometry changes set the full-rebuild fallback.

## Perception boundary

`current_perception_resolved` changes detection and reveal records, not geometric tile visibility. It therefore updates tactical presentation without triggering another all-team sight scan.

## Minimal presentation refresh

`TacticalScreen._process_post_movement_refresh()` updates only the handoff-critical presentation:

- selected/active unit;
- changed fog and token visibility;
- current local cover icon;
- phase, initiative and action HUD;
- alert flash when a real alert occurred.

It does not run the normal broad state-change reconciliation path. No blanket post-movement timer is used.

## Full rebuild cases

A full visibility rebuild remains valid for:

- mission loading or deployment assembly;
- floor changes;
- doors, windows or structures changing geometry;
- large scripted reveals;
- debug/recovery validation.
