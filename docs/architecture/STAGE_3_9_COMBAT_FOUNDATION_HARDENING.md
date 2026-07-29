# Stage 3.9 — Combat Foundation Hardening

Stage 3.9 is the final focused consolidation before practice-dummy combat.
It preserves the Stage 3.8.1 tactical interface and inventory interactions while
hardening shared content, placement invariants, rollback testing and
presentation boundaries.

## Shared content ownership

`ItemDefinition` is no longer tactical-only:

```text
domain/inventory/definitions/item_definition.gd
```

The same definition can now support campaign storage, tactical equipment,
shops, dismantling, manufacturing and extraction.

A shared `ContentCatalogue` validates item, action and defence resources:

```text
infrastructure/content/content_catalogue.gd
infrastructure/content/sandbox_content_catalogue_factory.gd
```

The sandbox currently registers:

- 18 item definitions;
- 10 typed action definitions;
- 3 typed defence profiles.

## Typed combat definitions

Combat no longer treats formatted Character Sheet strings as future rules.
The new typed foundation is:

```text
domain/actions/action_definition.gd
domain/combat/attack_definition.gd
domain/combat/damage_profile.gd
domain/combat/range_profile.gd
domain/combat/defence_profile.gd
```

Current equipped items grant authored action IDs. The Character Sheet resolves
those IDs through the catalogue and renders their damage, range and action
cost. Actual targeting and resolution remain Stage 4.0 work.

## Commands belong to application

Application requests and transfer records moved out of `domain/tactical/`:

```text
application/tactical/commands/
application/tactical/transfers/
```

Domain now retains state, rules and rule results rather than application
messages.

## Unit placement invariants

`TacticalState` now validates and rejects:

- overlapping footprints;
- out-of-bounds units;
- units on statically blocked terrain;
- zero or negative footprints;
- stale or inconsistent occupancy indexes.

`add_unit()` and `set_unit_position()` validate before committing. Rebuilding
the occupancy index no longer silently overwrites an existing occupant.

## Exhaustive item-location invariants

Item validation now checks:

- known location types;
- legal container kinds;
- valid owner requirements;
- ground positions inside the tactical map;
- destroyed items with no owner or container;
- legal Belt and Backpack placement;
- legal hand equipment;
- grid overlap and bounds;
- carrying limits;
- definition identity;
- condition range;
- stackability and maximum stack size.

## Stack rules

`ItemDefinition` now includes:

```gdscript
@export var stackable: bool = false
@export var maximum_stack_size: int = 1
```

Bandages, arrows, chalk, rations and smoke pellets use authored stack limits.
Weapons and other equipment remain quantity-one instances.

## Proven rollback

The automated suite now forces a failure after action cost and item movement
have begun. It verifies restoration of:

- item location;
- normal capacity;
- Quick Action;
- tactical revision;
- ground-item indexes.

The test seam is one-shot and exists only to exercise the genuine rollback
path.

## Board presentation extraction

Board drawing and pointer input moved from `tactical_screen.gd` into:

```text
presentation/tactical/tactical_board_view.gd
```

The board view now owns:

- terrain drawing;
- ground-item markers;
- movement-path drawing;
- selection outlines;
- screen-to-tile conversion;
- board mouse input.

`tactical_screen.gd` continues coordinating selection, handlers, HUD and
screen-level state. No large presenter hierarchy was introduced.

## Refresh rule

State-changing handlers refresh presentation through the synchronous
`state_changed` signal. Manual refreshes remain for UI-only changes such as
selection, hover, trays, targeting modes and modal visibility.

## Presentation dependency policy

For the current production stage:

> Presentation may read domain state but must never mutate it directly.

All state changes still go through application handlers.

## Automated test command

```bash
godot --headless --path . -s tests/tactical/run_stage_3_9_tests.gd
```

The suite includes identity, transfer atomicity, genuine rollback, stack
rules, item locations, unit placement, dynamic occupancy, typed action
resolution and session-wide validation.

## Stage 4 boundary

Stage 3.9 authors attack data but does not implement combat resolution.
Stage 4.0 should add:

```text
equipped item instance
→ ItemDefinition
→ granted AttackDefinition
→ target preview
→ attack command
→ roll and damage
→ practice dummy HP
```
