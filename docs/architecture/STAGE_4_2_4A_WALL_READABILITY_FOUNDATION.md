# Stage 4.2.4a — Wall Readability Foundation

This milestone separates physical structures from hidden information.

## Implemented

- Authored stone and wood wall tile sets in `TacticalMapDefinition`.
- One movement and sight authority: `is_blocked()` and `blocks_vision()` include
  both wall materials.
- Procedural hand-ink prototype rendering:
  - stone uses masonry courses, mortar, cracks, edge highlights and dark ink;
  - wood uses warm planks, joins, grain, pegs and dark ink.
- Orthogonal wall adjacency with isolated, straight, corner, end-cap,
  T-junction and cross geometry.
- Mixed materials touch with a visible seam rather than merging.
- Never-seen terrain uses a flat charcoal-violet ink wash with no grid or wall
  silhouette.
- Explored terrain preserves darkened structural memory without exposing live
  units or items.
- Close, tactical and far zooms progressively reduce wall detail while
  retaining material and silhouette.
- F8 toggles a wall/fog diagnostic on the hovered tile:
  - green/blue/violet outline = visible/explored/unseen;
  - red diagonal = movement blocker;
  - cyan diagonal = sight blocker.

## Non-goals

Wall damage, Hardness, doors, windows, breaching, cover, climbing, rubble and
multi-floor cutaways remain later milestones.
