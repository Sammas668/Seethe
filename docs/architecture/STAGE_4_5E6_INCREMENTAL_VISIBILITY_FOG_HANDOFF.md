# Stage 4.5e6 — Incremental Visibility and Fog Handoff

## Purpose

Remove the large main-thread hitch that occurred after a unit finished moving
into unexplored space. The static tactical environment already exists beneath
fog; the expensive work was repeated LOS trace allocation, full-state
validation for exploration and rebuilding every fog tile.

## Mission-start bake

`TacticalVisibilityRayCache` is prepared during `TacticalSession`
construction, before the tactical screen opens. It stores the relative tile,
edge-crossing and exact-corner trace templates for every offset inside the
40-tile Manhattan sight radius. Runtime FOV checks translate these templates to
the observer rather than rebuilding trace dictionaries and arrays for every
candidate tile.

The static board layer and the complete 64×64 fog mask are also created when
the tactical board is configured. Terrain is never generated as fog is
removed; fog only changes the mask state covering already-present terrain.

## Runtime visibility

Visibility remains authoritative and edge-aware. Cached rays still test:

- full-tile vision blockers;
- closed doors and other dynamic edge blockers;
- exact diagonal corner pairs;
- breached or destroyed structures through the environment geometry revision.

A bounded field cache is keyed by origin, Peek direction and geometry
revision. Automatic Peek uses prefiltered directional ray buckets rather than
iterating the complete radius square for every origin.

## Exploration transaction

Exploration changes only the knowledge grid. Its `TacticalChangeSet` therefore
uses targeted validation:

```gdscript
changes.set_commit_validation_policy(false, false)
```

The transaction validates the team IDs and tile bounds, but does not
synchronise body items or run `TacticalState.validate_all()`.

## Visibility delta

Each recalculation publishes a per-team delta:

```text
newly_visible
no_longer_visible
newly_explored
visibility_revision
knowledge_revision
```

The screen facade forwards this signal to the board. The player fog layer
updates only those changed cells.

## Fog mask

`TacticalFogLayer` stores one RGBA pixel per tactical tile:

```text
transparent = visible
translucent dark = explored
opaque dark = unseen
```

The 64×64 image is uploaded as one nearest-filtered texture. `_draw()` issues
one `draw_texture_rect()` call instead of querying and drawing all 4,096 tiles.
A full mask rebuild is retained only as a revision-recovery fallback.

## Performance instrumentation

F9 now exposes:

- mission-start ray bake time and ray count;
- centre and automatic-Peek ray checks;
- field-cache hits and misses;
- newly explored count and exploration commit time;
- visibility-delta build time and changed-cell count;
- fog mask updates, full rebuilds, texture uploads and changed cells.

## Boundaries

This patch does not change Stealth, detection, Last Seen Position, automatic
Peek legality, edge-based doors or sight rules. It does not precompute every
origin-to-target pair, because dynamic doors and destructible structures would
make that cache unnecessarily large and expensive to invalidate.
