# Stage 4.5e7a — Bounded Visibility Prewarm and Startup Safety

## Failure corrected

The first Stage 4.5e7 implementation called
`_prebake_walkable_visibility_fields()` from
`TacticalVisibilityService.configure()`. On the 64×64 sandbox map that meant
iterating every walkable origin, running the hybrid FOV calculation for each one,
and additionally generating automatic-opening and corner-Peek fields. All of
that work ran synchronously while the session was being created.

The loading overlay could render once, but Godot then remained inside one large
main-thread call stack. The project could become unresponsive or terminate
before the tactical screen appeared.

## Startup contract

Mission construction now performs only a bounded active-observer prewarm:

```text
configure visibility core
→ collect currently deployed, active observer origins
→ prewarm centre and currently legal Peek fields
→ stop at 96 fields
→ calculate initial team visibility
→ open tactical screen
```

The startup path must never loop across every map coordinate.

## Destination preparation

The first deliberate click on a legal movement destination already owns the
expensive movement preview work. Stage 4.5e7a also prepares the final-position
visibility field at that point:

```text
first destination click
→ build and lock route
→ calculate Stealth and Reaction previews
→ prepare final centre and automatic-Peek visibility field
→ retain prepared field

second click
→ commit and animate movement
→ consume prepared field at arrival
→ publish direct visibility delta
```

The route remains click-locked. Cursor movement does not repeat the destination
FOV preparation.

## Cache and memory boundaries

- Centre fields remain indexed by map tile and local geometry stamp.
- Automatic-Peek fields use an LRU-style order capped at 512 entries.
- Startup retains at most 96 newly warmed centre/Peek fields.
- A full-map bake method remains only as a compatibility entry point and now
  delegates to the bounded prewarm.
- Geometry changes still invalidate fields through local 8×8 chunk revisions.

## Retained Stage 4.5e7 systems

- compact one-bit-per-tile visibility fields;
- hybrid edge-aware shadowcasting with exact ambiguous-boundary refinement;
- direct bytewise visibility replacement and team reference-count crossings;
- incremental exploration transactions;
- delta-updated fog mask;
- exact walls, doors, windows and sealed diagonal-corner rules;
- automatic Peek, Stealth, Last Seen Position and alert behaviour.

## Performance counters

F9 now reports the bounded startup field count and limit, whether the full-map
startup bake was skipped, destination prewarm count/cache hits, destination
prewarm time, prepared-field reuse and the existing FOV/delta/fog timings.
