# Stage 4.2.5.4c1 — Tactical Grid Distance Preload Hotfix

## Problem

`EnemyActionPlanner` and several other scripts consumed `TacticalGridDistance` only through its global `class_name`. A copied project can be parsed before Godot has rebuilt the global script-class cache, producing `Identifier "TacticalGridDistance" not declared in the current scope`.

## Resolution

Every direct consumer now declares:

```gdscript
const TacticalGridDistance: Script = preload(
    "res://domain/tactical/tactical_grid_distance.gd"
)
```

Existing calls such as `TacticalGridDistance.steps_between(...)` and shared constants therefore resolve from a deterministic local dependency during parsing.

## Boundary

The hotfix does not duplicate the range formulas or move ownership out of `tactical_grid_distance.gd`. It only makes the dependency explicit and parse-order independent.
