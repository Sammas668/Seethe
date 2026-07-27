# Stage 3.5 — Xenonauts-Inspired Unit Management

This update replaces the old read-only tactical Inventory overlay with a
dedicated Unit Management window.

## Two primary tabs

The window has two top-level tabs:

- **Equipment & Inventory**
- **Character Sheet**

Changing tabs, changing the viewed unit and inspecting information are free.

The window retains the selected unit while changing tabs. The player may also
switch between deployed units with:

- Previous and next buttons.
- Number keys `1`, `2` and `3`.
- Left and right arrow keys.

## Equipment & Inventory

The Equipment tab includes:

- Left Hand.
- Right Hand.
- Readied secondary set.
- Armour.
- Four Quick Access slots.
- A 6 × 4 packed-storage grid.
- A 3 × 3 local-access tile selector.
- Loose ground items on the selected accessible tile.
- A Drop to Current Tile destination.
- Persistent HP, capacity, Quick Action, Reaction and weight information.

Items can be moved by:

- Drag and drop.
- Selecting an item, then selecting a green destination.
- Right-clicking for a sensible quick move.

Every meaningful transfer is previewed before confirmation.

Implemented prototype costs:

- Normal ground pickup: 5 ft Minor Interaction.
- Bulky ground pickup: Half Action.
- Drop to the current tile: Free.
- Packed storage to or from equipment: Half Action.
- Equipment or Quick Access changes: Quick Action.
- Reordering within packed storage or Quick Access: Free.

Occupied destinations do not automatically swap. The player must first clear
the destination, preventing accidental item loss.

Bulky loot such as the Grain Crate cannot be placed in packed storage or Quick
Access. The current prototype permits it to be moved into a hand while a later
stage will add proper two-handed bulky-carry states.

## Character Sheet

The Character Sheet is tactical and read-only. It displays:

- Name.
- Level.
- Class.
- Archetype.
- Unit type.
- HP.
- Armour Class.
- Speed.
- Carry weight.
- Six ability scores and modifiers.
- Initiative.
- Passive Perception.
- Fortitude, Reflex and Will.
- Relevant skills.
- Current equipment.
- Current attacks.
- Defences and resistances.
- Abilities.
- Conditions.
- Injuries.

The three prototype units have separate test sheets. These values are engine
test data, not final class balance.

## Architecture

New files:

```text
domain/tactical/tactical_character_sheet_state.gd
domain/tactical/tactical_inventory_transfer_command.gd
domain/tactical/tactical_inventory_transfer_preview.gd
application/tactical/tactical_inventory_transfer_handler.gd
presentation/tactical/unit_management_slot.gd
presentation/tactical/unit_management_window.gd
presentation/tactical/unit_management_window.tscn
```

Changed files:

```text
domain/tactical/tactical_unit_state.gd
domain/tactical/tactical_state.gd
presentation/tactical/tactical_screen.gd
bootstrap/boot/boot.gd
README_FIRST.txt
PROJECT_TREE.txt
```

The former Inventory panel remains hidden in the tactical scene for
compatibility, but the Inventory button now opens the new Unit Management
window.

## Test checklist

1. Run at 1280 × 720.
2. Open Unit Management with the Inventory button or `I`.
3. Switch between Equipment and Character Sheet.
4. Switch between all three units without closing the window.
5. Confirm switching units does not reactivate ended units or restore actions.
6. Confirm each Character Sheet displays different values.
7. Select an item and verify valid destinations turn green.
8. Drag an item between empty packed-storage slots.
9. Pick up the Dropped Spear and confirm its 5 ft cost.
10. Attempt to pick up the Grain Crate and confirm its Half Action cost.
11. Confirm the Grain Crate cannot enter packed storage or Quick Access.
12. Move a packed item to Quick Access and confirm the Half Action preview.
13. Move a held or quick item to another ready slot and confirm the Quick
    Action preview.
14. Drop a carried item and confirm a gold ground marker appears.
15. Verify the tactical HUD hand slots update after a confirmed transfer.
16. Press `Esc` or `I` to close the window.
17. End the Player Phase and verify allowances refresh.

Godot is not installed in the generation environment. The project therefore
still requires an engine test before it should replace the confirmed working
copy.
