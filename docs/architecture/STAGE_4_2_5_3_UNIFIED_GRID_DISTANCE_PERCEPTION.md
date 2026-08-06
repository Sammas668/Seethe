# Stage 4.2.5.3 — Unified Grid-Distance and Perception Range Revision

## Decision

Current tactical range uses one shared grid metric:

```gdscript
distance = abs(target.x - origin.x) + abs(target.y - origin.y)
```

A diagonal neighbour is therefore two grid steps away. One step equals 5 feet.

## Locked ranges

| System | Range |
|---|---:|
| General character sight | 40 squares / 200 feet, all around |
| Unaware guard focused perception | 25 squares / 125 feet, forward cone |
| Unaware guard close awareness | 1 square / 5 feet, all around |
| Aware guard perception | 40 squares / 200 feet, all around |

All sight remains subject to line-of-sight blockers.

## Ownership

`TacticalGridDistance` owns the current grid-step calculation and shared range constants. Visibility, guard perception, direct attack previews and enemy attack-position planning use this shared service instead of defining their own Euclidean or Chebyshev interpretations.

Movement path cost remains owned by `MovementRules`. This revision does not replace pathfinding or its terrain and diagonal-step accounting; it prevents visual and direct-range systems from treating the same coordinate offset as a different number of grid squares.

## Unaware guards

An unaware guard checks its one-square all-around close-awareness area first. This area does not automatically reveal a unit. It uses the normal Stealth check with the existing +4 Detection DC bonus.

Outside close awareness, the guard checks its approximately 90-degree forward cone out to 25 grid steps. Passive Perception determines Detection DC but no longer lengthens the cone.

## Aware guards

An aware guard uses a 40-square all-around current-perception area rather than its unaware directional cone. A detected character can still break sight and re-enter Stealth when no enemy squad currently perceives them and they can pay the action cost.

## Presentation

The awareness overlay reads the same domain query used by detection. It therefore displays:

- the fixed 25-square unaware cone;
- the one-square close-awareness area;
- the 40-square aware radius;
- wall-truncated results rather than an unblocked decorative shape.

## Acceptance examples

From `(10, 10)`:

- `(10, 35)` is 25 steps;
- `(20, 25)` is 25 steps;
- `(11, 11)` is 2 steps and is not close awareness;
- `(11, 10)` is 1 step and is close awareness;
- `(30, 30)` is 40 steps and is inside aware sight;
- `(31, 30)` is 41 steps and is outside aware sight.

## Supersession

This document supersedes the range values recorded in the original Stage 4.2.5 foundation and Stage 4.2.5.1 revision. Their state, UI, search and initiative decisions remain in force except where this document changes distance or range.
