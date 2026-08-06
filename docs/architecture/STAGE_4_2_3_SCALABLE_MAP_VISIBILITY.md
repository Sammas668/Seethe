# Stage 4.2.3 — Scalable Map and Visibility Foundation

This milestone combines the scalable-camera work from Stage 4.2.2 with the
basic visibility foundation from Stage 4.2.3.

## Battlefield scale

- The active sandbox map is 64×64 tiles.
- Mouse wheel zooms around the cursor from 38% to 165%.
- Middle-mouse drag and arrow keys pan the board.
- `C` centres the camera on the selected unit.
- Screen-to-tile conversion uses the BoardView transform, so movement and
  direct weapon targeting remain accurate at every zoom and pan position.

## Fog states

Every tile is presented to the player as one of:

- **Unseen** — opaque fog and no live information.
- **Explored** — dark map memory; live units and items remain hidden.
- **Visible** — current terrain, units, items, paths, and targeting data.

Visibility is stored separately per team. It is recalculated after committed
state changes rather than every frame. Blocked tiles interrupt line of sight,
while the blocking tile itself remains visible. A unit always sees its own and
adjacent tiles. Passive Perception provides a small sight-radius adjustment;
full stealth detection, facing, vision cones, and suspicion remain later work.

## Information protection

- Hidden enemies and neutrals have no unit view.
- Hidden ground items are not drawn.
- Hidden units cannot be selected or attacked through their occupied tile.
- AttackPreviewQuery rejects targets outside the attacker's team visibility.
- Explored tiles do not display live unit or item updates.

## Large-map AI preparation

Melee enemy planning now enumerates only valid cells around the target instead
of pathfinding from every cell on the map. Broader multi-goal pathfinding and
reachable-area caches remain Stage 4.2.7 work.

## Deferred

This is the visibility foundation, not the complete stealth system. Deferred:

- facing and vision cones;
- Undetected, Suspected, and Detected unit states;
- noise and investigation;
- last-known-position AI;
- detailed hand-inked terrain LOD assets;
- chunk rendering for 128×128 and 200×200 stress maps.
