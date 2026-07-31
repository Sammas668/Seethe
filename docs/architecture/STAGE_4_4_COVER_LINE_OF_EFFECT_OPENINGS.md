# Stage 4.4 — Directional Cover, Line of Effect and Openings

## Status

Implemented tactical pre-alpha milestone.

Stage 4.4 extends the completed mission loop with one shared combat-geometry and mutable-environment boundary. It preserves existing full-tile walls, adds normalised edge geometry, separates line of sight from line of effect, derives directional cover from five exposure samples, exposes that information through compact tactical UI, and supports doors, windows, bars, locks, Peek, Lean Attack, damageable structures, breaching, rubble and structural salvage.

The release is internally organised as:

```text
4.4a1  Combat Geometry Kernel
4.4a2  Directional Cover Gameplay and UI
4.4b1  Doors, Windows and Opening State
4.4b2  Peek, Lean Attack and Locks
4.4c1  Damageable Tactical Structures
4.4c2  Cover Hits, Breaching, Rubble and Salvage
```

## Locked rules

### Distinct geometry questions

```text
Line of sight
Can the observer see the target position?

Line of effect
Can the selected direct attack physically reach the target?

Cover
How many of the target's exposure samples are protected by solid material?
```

Concealment remains separate and is not implemented by this milestone.

### Cover categories

| Clear samples | Cover | Effect |
|---:|---|---|
| 5 | None | No modifier |
| 3–4 | Light | +2 AC, +1 Reflex |
| 1–2 | Heavy | +4 AC, +2 Reflex |
| 0 | Total | Cannot normally be directly targeted |

Cover is directional. It is recalculated for every attacker-target pair and is never stored as one universal property of a tile or unit.

A similarly sized or larger conscious standing creature may provide Light Cover. Dying, unconscious and dead units do not provide ordinary creature cover.

## Geometry ownership

### Authored geometry

`TacticalMapDefinition` owns immutable authored geometry:

```text
full-tile walls
edge barriers
opening definitions
structure definitions
```

Existing wood and stone wall tiles remain supported. They represent solid occupied space and are not migrated into edge records.

`TacticalEdgeKey` normalises the two tiles bordering an edge. Doors, windows, bars, fences and edge structures use that key so an edge has one identity regardless of traversal direction.

### Runtime geometry

`TacticalEnvironmentState` owns mutable tactical state:

```text
opening_states_by_id
structure_states_by_id
geometry_revision
```

Opening or damaging geometry never rewrites the authored `.tres` resource. Every geometry-changing action increments `geometry_revision`. Movement, visibility, attacks, cover UI and AI all consume that same revision.

## Combat geometry authority

`TacticalCombatGeometryQuery` is the shared rule authority for:

- attack previews;
- committed attacks;
- movement destination cover previews;
- the selected-character directional cover ring;
- Peek and Lean Attack origins;
- ranged enemy position scoring.

The query returns `TacticalCombatGeometryResult`, including:

```text
has_line_of_sight
has_line_of_effect
clear_exposure_samples
cover_category
cover_ac_bonus
cover_reflex_bonus
primary_cover_source_id
blocking_sight_source_id
blocking_effect_source_id
geometry_revision
```

The low-level trace uses supercover-style traversal and records crossed tiles, crossed edges and exact-corner intersections. A zero-width diagonal gap is blocked only when both side obstacles are solid.

Ordinary fog-of-war visibility continues to use the cheaper single LOS query. Five exposure traces are reserved for combat, hovered destinations, selected-unit cover presentation and bounded AI candidate evaluation.

## Attack integration

`TacticalAttackPreview` records base AC, cover bonus, effective AC, exposure count, primary cover source, tactical revision and geometry revision.

A direct attack requires:

```text
line of sight
line of effect
cover other than Total
```

The UI distinguishes:

- no line of sight;
- visible target but blocked line of effect;
- Total Cover.

Committed attacks use effective AC. Critical confirmation uses the same effective AC. `TacticalAttackResolution` records `hit_without_cover` and `missed_due_to_cover`.

When a miss occurs only because of structural cover, the already rolled damage is applied to the primary cover source. Hardness reduces the damage. There is no second attack roll.

Structure attacks use the ordinary attack economy, facing and Disabled-strain rules. Their rollback restores action budget, facing, life state, environment state and any newly created salvage.

## Compact cover presentation

### Movement destination preview

When a reachable destination is hovered:

1. the normal path and destination ghost remain visible;
2. cover is evaluated from every currently visible living hostile to the hovered destination;
3. one compact temporary shield badge appears beside each relevant hostile;
4. one short summary appears beside the destination ghost.

No persistent line-of-fire web is drawn. No cover badges are placed on every reachable tile. Hidden enemies and unexplored geometry never generate previews.

### Selected-character directional cover ring

Only the selected character displays the directional cover ring. Visible hostiles are grouped into eight sectors. Each occupied sector shows the worst cover result in that direction:

```text
Exposed < Light < Heavy < Total
```

A count marks grouped threats. The ring remains outside the token artwork and below life-state badges in visual priority.

### Exact attack cover

During attack targeting, the target displays the exact attacker-to-target cover grade, AC modifier and clear exposure count. This is the most prominent cover presentation because it describes the result that will be committed.

All three presentations consume the same `TacticalCombatGeometryQuery` result.

## Openings

`TacticalOpeningDefinition` owns authored edge, type, material, initial state, operation cost, lock DC and salvage profile. `TacticalOpeningState` owns current HP, state, lock/bar/jam state and one-time salvage flag.

Supported sandbox openings:

- ordinary wooden door;
- locked wooden door;
- intact clear window;
- barred opening.

An ordinary unlocked door costs 5 feet to open or close. A known closed door may be included in movement. If opening it reveals new information, the door remains open, the cost remains spent, movement pauses beside it and remaining capacity is preserved.

Opening changes immediately update movement, LOS, line of effect, directional cover and visibility.

Clear intact glass permits sight but blocks ordinary direct line of effect. Broken glass permits both. Bars permit sight and partial line of effect while supplying directional cover.

## Peek, Lean Attack and locks

Peek spends 5 feet, uses a temporary edge or corner origin and does not move the unit. It reveals only information visible from that origin and cannot include an attack.

Lean Attack uses a normal attack cost and a temporary edge or corner origin. The unit's footprint does not move. LOS, line of effect and both sides' cover are recalculated from the lean origin.

Ordinary lockpicking uses:

```text
d20 + Thievery + selected tool bonus vs lock DC
```

The sandbox lockpicks provide an authored Thievery bonus.

## Damageable structures and breaches

`TacticalStructureDefinition` owns geometry, AC, Hardness, maximum HP, integrity thresholds and salvage profile. `TacticalStructureState` owns current HP, integrity state and the one-time salvage flag.

Structures are environment records, never fake characters. They can share attack-roll and damage presentation without receiving initiative, morale or inventory.

Integrity states are:

```text
Intact
Damaged
Breached
Destroyed
Cleared
```

Crossing an integrity threshold may change movement blocking, LOS, line of effect, exposure samples, difficult terrain and visual state. The environment revision changes before another action starts.

Destroyed structures may create rubble and one new persistent salvage item. The original structure does not become an inventory item. The `salvage_generated` flag prevents duplication after repeated damage or save/load.

## Sandbox content

The farm/storehouse sandbox includes:

```text
low fence                 Light Cover example
wooden barricade          Heavy Cover and cover-hit example
ordinary door             movement-integrated opening
locked door               Thievery and tool example
clear window              LOS/LOE separation example
barred opening            partial opening example
isolated stone wall       structure attack and breach example
```

Salvage definitions include broken timber, stone rubble, scrap metal and glass shards.

## Transaction boundaries

Every geometry-changing command follows:

```text
validate current tactical and geometry revisions
→ stage action cost and facing
→ stage opening or structure mutation
→ stage rubble or salvage
→ commit one TacticalChangeSet
→ synchronise body items and occupancy
→ validate tactical invariants
→ increment tactical revision
→ publish state change
→ rebuild presentation from authoritative state
```

UI controls never directly mutate opening, structure, cover or item state.

## Save/load boundary

Tactical persistence must preserve opening states, structure HP and integrity, rubble, generated salvage and enough environment state to rebuild geometry deterministically. Geometry caches and cover previews are derived and are never saved.

## Tests

Runtime entry point:

```text
res://tests/tactical/run_stage_4_4_tests.gd
```

Static entry point:

```text
python tests/static/validate_stage_4_4.py
```

The Stage 4.4 suite covers authored geometry, directional exposure, LOS/LOE separation, creature cover, movement and sector previews, attack cover, cover-hit damage, door operation, lockpicking, Peek, Lean Attack, direct structure damage, breach, salvage and environment snapshot restoration.

## Out of scope

- concealment and smoke;
- elevation and three-dimensional exposure;
- projectile flight simulation;
- blind fire and suppression;
- creature-cover interception damage;
- multi-wall penetration;
- multi-floor structural collapse;
- physics debris;
- Attacks of Opportunity and Overwatch.

Those reaction systems remain Stage 4.5.
