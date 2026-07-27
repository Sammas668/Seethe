# Stage 1 — Tactical Movement Implementation

This project now includes the first executable Seethe gameplay slice: one unit moving on a 20 × 20 square grid using the real shared movement-capacity rules.

## Implemented

- One selectable player unit.
- 30-foot turn capacity.
- Orthogonal movement at 5 feet per tile.
- Alternating diagonal movement at 5, 10, 5, 10 feet.
- Diagonal parity persists across separate moves in the same phase.
- Difficult terrain doubles the cost of entering a tile.
- Blocked terrain and sealed-corner validation.
- Path preview showing legal and over-budget routes.
- Command-handler validation before tactical state changes.
- State-driven unit position with a separate animated visual Node.
- End Phase refreshes movement and diagonal parity.
- Authored map data stored as a content Resource.

## File ownership

```text
core/results/
└── operation_result.gd

domain/tactical/
├── tactical_map_definition.gd
├── tactical_state.gd
├── tactical_unit_state.gd
├── move_command.gd
├── movement_path_result.gd
└── movement_rules.gd

application/tactical/
├── tactical_state_store.gd
└── tactical_command_handler.gd

presentation/tactical/
├── tactical_screen.tscn
├── tactical_screen.gd
├── tactical_unit_view.tscn
└── tactical_unit_view.gd

content/missions/farm_storehouse/
└── movement_test_map.tres
```

## Architecture flow

```text
Mouse hover
    ↓
Presentation asks MovementRules for a preview
    ↓
Player clicks destination
    ↓
MoveCommand
    ↓
TacticalCommandHandler recomputes and validates the route
    ↓
TacticalUnitState changes
    ↓
TacticalStateStore emits state_changed
    ↓
Presentation refreshes and animates the path
```

The view never decides that a move is legal and never writes the unit's real grid position directly.

## Manual acceptance checks

1. Run the project.
2. Confirm the 20 × 20 board appears.
3. Hover over nearby tiles and inspect the movement cost.
4. Move orthogonally six clear tiles and confirm all 30 feet are spent.
5. Click End Phase and confirm capacity returns to 30 feet.
6. Make multiple diagonal moves and confirm their costs alternate 5 and 10 feet across the whole phase.
7. Hover over brown tiles and confirm the route cost includes difficult terrain.
8. Try to move onto a black tile and confirm the move is rejected.
9. Preview a route costing more than the remaining capacity and confirm it appears red.
10. Right-click to deselect and left-click the unit to select it again.

## Deliberately deferred

- Multiple friendly units.
- Enemy patrols.
- Detection and alert transition.
- Initiative.
- Attacks.
- Reactions.
- Loot and extraction.
- Mission snapshots and campaign persistence.

Those systems should be added only after this movement prototype has been run and checked in Godot.
