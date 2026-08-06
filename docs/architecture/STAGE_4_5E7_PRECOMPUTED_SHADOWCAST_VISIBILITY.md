# Stage 4.5e7 — Compact Shadowcast Visibility and Direct Deltas

> **Stage 4.5e7a correction:** the original synchronous all-walkable-origin
> mission-load bake was unsafe and has been replaced by bounded active-observer
> prewarming plus clicked-destination preparation.

## Purpose

Remove the remaining pause between the final movement animation frame and fog
revelation. Stage 4.5e6 made fog drawing incremental, but a new observer origin
could still synchronously test thousands of destination rays at arrival.

## Hybrid exact FOV core

`TacticalEdgeShadowcastFov` calculates one field in three bounded passes:

1. Tile shadowcasting produces a fast superset of potentially visible cells.
2. A conservative angular-occlusion sweep accepts cells that are unambiguously
   visible around blocking tile squares and blocking edge segments.
3. Only the small ambiguous boundary set is checked with the existing exact
   relative ray, including intermediate blockers, dynamic edge crossings and
   sealed diagonal-corner pairs.

This preserves the authoritative sight result while avoiding one complete exact
ray for every tile in the 40-tile Manhattan radius.

## Compact fields

`TacticalVisibilityField` stores one bit per map tile. On a 64×64 map, a centre
field occupies 512 bytes before its index list is requested. Index lists are
built lazily only for fields that active observers actually contribute.

## Bounded startup prewarm

Before the tactical screen opens, session construction prewarms only the centre
and automatic-Peek fields required by currently deployed observers. A hard
field-count limit protects startup. The service must not iterate every walkable
map origin from `configure()`.

When the player deliberately clicks and locks a movement destination, the exact
centre and legal automatic-Peek fields for that final position are prepared and
retained. The second click and movement animation can therefore reuse the
prepared field without paying a new-origin calculation at arrival.

## Local geometry invalidation

The FOV core records sight-blocker signatures in 8×8 chunks. A cached origin is
validated against the chunk revisions within its sight radius. Opening one door
or breaching one wall changes only the relevant chunk revision, so distant
origin fields remain valid.

## Prepared movement field

After movement animation begins, `TacticalScreen` asks the visibility service to
merge the already-baked centre and automatic-Peek fields for moved units. The
prepared immutable field is consumed at the movement handoff if position and
geometry revision still match.

No visibility is displayed early. The work is only prepared early.

## Direct team deltas

`TacticalVisibilityState.replace_unit_visibility_field()` XOR-diffs the moved
unit's old and new masks byte by byte while updating team reference counts. It
visits only changed bits and records:

```text
0 → 1  newly visible
1 → 0  no longer visible
```

The incremental movement path publishes those crossings directly. It no longer
creates complete before/after team-visible snapshots, enumerates the complete new
unit field, or scans all map cells to rediscover the same delta. Exploration
candidates are queued only from the final team 0→1 crossings, rather than
reinserting every visible tile after each move.

## Existing boundaries retained

- The 40-tile Manhattan sight radius is unchanged.
- Full-tile blockers, doors, windows, edge structures and sealed diagonal
  corners retain exact compatibility checks.
- Automatic Peek remains free and automatic.
- Stealth, detection, Last Seen Position and alert rules are unchanged.
- Fog remains a nearest-filtered, delta-updated mask.
- Full-team rebuilds remain available for genuine structural or mission-level
  invalidation.

## Performance instrumentation

F9 exposes:

- bounded startup centre and Peek fields prewarmed;
- startup field limit, prewarm time and retained bitset bytes;
- clicked-destination preparation count, cache hits and time;
- shadowcast cells visited;
- conservative candidates and ambiguous exact refinements;
- centre/Peek cache hits and misses;
- prepared-field hits and misses;
- changed geometry chunks;
- direct-delta updates and cancelled intermediate crossings;
- exploration and fog-mask timings inherited from Stage 4.5e6.
