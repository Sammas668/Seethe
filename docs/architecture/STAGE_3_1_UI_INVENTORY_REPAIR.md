# Stage 3.1 — Tactical UI Repair and Functional Inventory

This update responds directly to the 1280 × 720 screenshot review.

## Layout repairs

- The tactical HUD now uses anchored Controls instead of relying on one fixed 1280 × 720 arrangement.
- The tactical board is recalculated and centred whenever the viewport size changes.
- The right information panel is narrower and contains only essential selected-unit and path information.
- Long contextual descriptions were removed from the permanent right panel.
- Recent status moved to a thin strip above the command deck.
- The full event history is available through a collapsible LOG drawer.
- The bottom command deck was reduced from 110 pixels to 86 pixels.
- The Round / Phase / End Phase section is wider and no longer clips at 1280 × 720.
- Permanent tutorial text was removed from the roster and replaced by a small help tooltip.
- The right panel clips its own contents defensively, preventing it from drawing beneath the bottom deck.

## Inventory redesign

The former read-only text panel has been replaced by a tactical inventory manipulation screen.

The inventory now contains:

- Equipment slots: Main Hand, Off Hand, Armour and Secondary set.
- Four Quick Access slots.
- Twelve Backpack slots.
- Twelve Local Access cells representing items on the unit's own or adjacent tiles.
- Persistent tactical item instances rather than display-only strings.
- Item category, weight, description and location state.
- Drag-and-drop between valid slots.
- Left-click item selection followed by an empty destination.
- Right-click quick movement to a sensible available destination.
- Valid target highlighting.
- A pending-action preview before commitment.
- Confirm and Cancel controls.
- Action-economy costs applied only on confirmation.
- Unit carrying limits.
- Map item markers that update when items are picked up or dropped.

## Implemented costs

- Pick up a normal local item: Minor Interaction, 5 ft.
- Pick up bulky loot: Half Action.
- Drop a carried item: Free.
- Move between Backpack and equipment: Half Action.
- Move between Quick Access and readied equipment: Quick Action.
- Reorder within Backpack or within Quick Access: Free.

The cost logic is implemented in `domain/tactical/tactical_inventory_rules.gd` and validated by `application/tactical/tactical_inventory_transfer_handler.gd`.

## New files

```text
domain/tactical/inventory_transfer_preview.gd
domain/tactical/tactical_inventory_transfer_command.gd
domain/tactical/tactical_inventory_rules.gd
application/tactical/tactical_inventory_transfer_handler.gd
presentation/tactical/inventory_slot.gd
docs/architecture/STAGE_3_1_UI_INVENTORY_REPAIR.md
```

## Changed files

```text
bootstrap/boot/boot.gd
domain/tactical/tactical_inventory_state.gd
domain/tactical/tactical_item_state.gd
domain/tactical/tactical_state.gd
presentation/tactical/tactical_unit_view.gd
presentation/tactical/tactical_screen.gd
presentation/tactical/tactical_screen.tscn
README_FIRST.txt
PROJECT_TREE.txt
```

## Recommended Godot test checklist

1. Run at 1280 × 720.
2. Confirm no text or controls draw beneath the bottom command deck.
3. Confirm the End Phase block is fully visible.
4. Resize the window and confirm the tactical board remains centred between the side panels.
5. Open and close the LOG drawer.
6. Open Inventory with the button and the `I` key.
7. Drag the Dropped Spear into an empty Backpack slot.
8. Confirm the action preview says 5 ft before commitment.
9. Confirm the transfer and verify the spear disappears from the map.
10. Drag the Grain Crate into the Backpack.
11. Confirm it costs a Half Action because it is bulky.
12. Drop a carried item into an empty Local Access cell.
13. Confirm dropping is free and the gold map marker appears on the unit's tile.
14. Move a packed item to Quick Access and confirm the Quick Action cost.
15. Verify invalid destinations remain unavailable and display a reason.
16. Verify carrying limits prevent impossible pickups.
17. End the Player Phase and verify normal capacities and Quick Actions refresh.

Godot is not installed in the generation environment, so this checklist must still be run in the engine.
