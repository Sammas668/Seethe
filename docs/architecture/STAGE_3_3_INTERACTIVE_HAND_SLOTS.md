# Stage 3.3 — Interactive Hand Slots

This update is built directly from the Stage 3.2 expanded-map project.

## Bottom-deck correction

The former `EquipmentBlock` used three wide summary buttons:

- Primary weapon.
- Secondary set.
- Quick item.

It has been replaced by a much smaller `HandBlock` containing only:

- Left Hand.
- Right Hand.

The block is 180 pixels wide instead of 260 pixels. The selected-unit block,
command buttons, spacing and phase block were also reduced slightly. This
recovers substantially more width than the amount by which the BottomDeck
was overflowing at 1280 × 720.

## Hand-slot behaviour

The prototype maps:

- `inventory.off_hand` to the visible Left Hand.
- `inventory.main_hand` to the visible Right Hand.

Clicking either hand opens the existing contextual action tray.

For a melee item, the tray shows:

- Attack.
- Full Attack.
- Drop.
- Inspect.

For a recognised ranged item such as a bow or sling, it shows:

- Ranged Attack.
- Overwatch.
- Drop.
- Inspect.

For an empty hand, it shows:

- Open Inventory.

`Inspect` and `Open Inventory` are functional. Attack, Overwatch and Drop
remain clearly disabled until their underlying combat and tactical-transfer
systems are implemented.

## Deliberately removed from the main HUD

- Prepared secondary-set summary.
- Large permanent Quick Item summary.

Those remain visible in the Inventory panel. Quick-access items can later
return as much smaller icon slots without expanding the HandBlock.

## Unchanged systems

- Tactical movement.
- Action economy.
- Sprint.
- Player and World Phases.
- Expanded tactical map.
- Read-only Inventory panel.
- Local item detection.

## Files changed

```text
bootstrap/boot/boot.gd
presentation/tactical/tactical_screen.gd
presentation/tactical/tactical_screen.tscn
docs/architecture/STAGE_3_3_INTERACTIVE_HAND_SLOTS.md
CHANGELOG_STAGE_3_3_HAND_SLOTS.md
README_FIRST.txt
PROJECT_TREE.txt
```

## Test checklist

1. Run at 1280 × 720.
2. Confirm the complete BottomDeck fits within the screen.
3. Confirm the equipment area now contains only Left Hand and Right Hand.
4. Select the Marauder, Archer and Scout.
5. Confirm each hand updates to the correct carried item.
6. Click an occupied melee hand and confirm its item-action tray opens.
7. Click the Archer's bow hand and confirm ranged actions appear.
8. Click an empty hand and confirm Open Inventory appears.
9. Use Inspect and confirm the selected item is reported in the UnitBlock.
10. Use Open Inventory from an empty hand.
11. Confirm the general Attack, Abilities, Tactics, Inventory, Interact,
    End Unit and End Phase controls remain accessible.

Godot is not installed in the generation environment, so the project still
requires one run in Godot 4.
