# Stage 3.8 — Tactical Foundation Consolidation

Stage 3.8 preserves the working Stage 3.7 tactical UI while replacing the
prototype state shortcuts beneath it. This stage is deliberately architectural:
it prepares inventory, movement and mission composition for combat, extraction,
saving and persistent campaign equipment.

## Implemented outcomes

### One authoritative item instance

Every tactical item now exists once in `TacticalState.items_by_id` as a
`TacticalItemInstanceState`.

An instance owns:

- a globally unique `item_id`;
- an immutable `ItemDefinition` reference and `definition_id`;
- quantity;
- condition;
- one `TacticalItemLocationState`;
- optional instance-specific tactical modifiers.

Moving an item changes its location. It does not convert the item into a second
state class, create a replacement ID, lose stack quantity or recalculate its
identity from its display name.

Supported location/container combinations currently include:

- Primary Hand;
- Secondary Hand;
- Belt;
- Backpack;
- tactical ground / Items in Reach;
- future tactical containers and destroyed state identifiers.

The removed prototype classes were:

```text
domain/tactical/tactical_inventory_item_state.gd
domain/tactical/tactical_item_state.gd
domain/tactical/tactical_item_profile.gd
```

### Authored ItemDefinition resources

Item rules no longer depend on tests such as whether a display name contains
`bow`, `spear` or `grain crate`.

Definitions now live under `content/items/` and declare:

```text
id
display_name
description
weight_lb
inventory_footprint
handedness
belt_allowed
backpack_allowed
equipment_tags
granted_action_ids
tactical_visual_category
```

The prototype includes definitions for the Training Axe, Training Shortbow,
Shortbow and Quiver, Training Spear, Dagger, Knife, Sling, Buckler, Bandage,
Rope, Manacles, Rations, Smoke Pellet, Spare Arrows, Chalk, Lockpicks, Empty
Sack and Grain Crate.

### Atomic inventory-transfer planning

`TacticalInventoryTransferHandler` now builds a complete
`TacticalInventoryTransferPlan` before state changes begin. The plan contains:

- persistent item ID;
- expected source and target locations;
- action cost;
- additional Quick Action requirement;
- Provokes flag;
- resulting carried weight;
- expected tactical-state revision.

Execution verifies that the state and source still match the plan, snapshots the
unit budget and item location, applies the transfer, validates invariants and
emits one state-change notification. A failed commit restores the complete
budget and the original item location.

### Derived carried weight

Current weight is no longer stored and manually adjusted in several handlers.
It is derived from the authoritative item registry and each item's current
location. This prevents drift after failed transfers or later save/load work.

### TacticalSession composition boundary

Prototype mission assembly moved out of `tactical_screen.gd`.

```text
application/tactical/tactical_session.gd
application/tactical/tactical_sandbox_factory.gd
```

`TacticalSandboxFactory` creates the test map, units, character sheets and item
instances. `TacticalSession` owns the state store and application handlers. The
boot layer creates the session and supplies it to the tactical screen.

The presentation layer now displays a configured session rather than constructing
its own game state.

### Dynamic, footprint-aware occupancy

`TacticalState` maintains a runtime `unit_id_by_cell` index. A unit's complete
footprint is indexed, not only its origin tile.

`TacticalNavigationSnapshot` combines:

- authored static blocked terrain;
- difficult terrain;
- current unit occupancy;
- the moving unit's footprint;
- exclusion of the mover from its own blocking data.

Normal movement and Sprint now use this runtime snapshot, so a path cannot pass
through another actor. The Sprint difficult-terrain check also skips the
starting cell, allowing a unit to Sprint out of difficult terrain when the
remaining route is clear.

### Obsolete UI cleanup

The hidden legacy `RightPanel` and old `InventoryPanel` were removed from
`tactical_screen.tscn`, together with obsolete node references and the empty
legacy confirmation callback. The current Unit Management window remains the
only tactical inventory interface.

### One refresh path

Committed handlers emit `state_changed`; presentation refreshes from that
signal. The inventory window no longer performs a second explicit full refresh
after a successful transfer.

## Item invariants

`TacticalState.validate_item_invariants()` checks the most important rules:

- registry key equals item ID;
- definition exists and matches its ID;
- quantity is valid;
- each item has one location;
- carried items reference an existing unit;
- equipped items use legal hand containers;
- non-equippable items cannot appear in hands;
- two-handed items cannot occupy Secondary Hand;
- Belt and Backpack placements stay inside their grids;
- spatial items do not overlap;
- each hand contains at most one item;
- a two-handed Primary item reserves Secondary Hand;
- derived weight does not exceed carrying capacity.

## Automated invariant tests

The test suite is located at:

```text
tests/tactical/stage_3_8_invariant_tests.gd
tests/tactical/run_stage_3_8_tests.gd
```

It covers:

1. Ground → Hand → Ground preserves the same item ID.
2. Failed transfers preserve item location and action resources.
3. A two-handed Primary item reserves Secondary Hand.
4. Stack quantity survives pickup.
5. Duplicate IDs are rejected.
6. Carried weight equals the authoritative item sum.
7. Same-grid rearrangement is free.
8. Items outside local reach cannot be picked up.
9. Dynamic occupancy prevents paths through another actor.
10. Replaying a transfer cannot duplicate an item.
11. A stale validated plan is rejected without moving the item or spending capacity.

Run from a Godot 4 command line:

```text
godot --headless --path . -s tests/tactical/run_stage_3_8_tests.gd
```

The generation environment did not provide a runnable Godot executable, so the
archive has received static validation but the tests must still be executed in
Godot locally.

## Manual acceptance checklist

1. Open the project at 1280 × 720.
2. Confirm the tactical screen starts without parser errors.
3. Open Inventory and switch between all three units.
4. Drag the ground spear into Secondary Hand, then drop it again.
5. Confirm the ground marker represents the same item and no duplicate appears.
6. Pick up the stack of two Bandages and confirm its quantity remains two.
7. Confirm the Grain Crate cannot enter Belt or Backpack.
8. Confirm the Archer's two-handed bow reserves Secondary Hand.
9. Rearrange Backpack items without spending capacity.
10. Move Belt ↔ Hand and confirm it spends one Quick Action.
11. Attempt a failed transfer and confirm no action resource is lost.
12. Move a unit around another unit and confirm the path does not cross it.
13. End the phase and confirm action resources refresh normally.
14. Run the automated Stage 3.8 invariant tests.

## Intentional limits

Stage 3.8 does not yet add combat, enemies, mission persistence, containers,
corpses, item rotation, equipment durability effects or a final campaign item
repository. It establishes the stable tactical contracts those systems will use.

The next feature milestone is Stage 4.0: weapon-driven attacks and a resettable
practice dummy using `ItemDefinition.granted_action_ids` rather than display-name
matching.
