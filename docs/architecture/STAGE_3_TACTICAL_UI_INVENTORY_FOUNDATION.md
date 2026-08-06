# Stage 3 — Tactical HUD and Inventory UI Foundation

This update replaces the temporary Stage 2 side panel and test-button grid with a compact tactical interface inspired by the interaction principles of Xenonauts and classic XCOM.

It does not copy their artwork or exact screen layout. It establishes Seethe's own permanent tactical HUD contract.

## Implemented

- Persistent top objective, phase and shortcut bar.
- Compact vertical squad roster.
- Selected-unit status panel.
- Numerical and graphical turn-capacity display.
- Half-Action threshold marker on the capacity bar.
- Separate Quick Action and Reaction indicators.
- Bottom command deck.
- Permanent Attack, Abilities, Tactics, Inventory, Interact, End Unit and End Phase controls.
- Contextual action tray instead of permanently showing every possible action.
- Equipment and quick-access buttons.
- Permanent Inventory button with nearby-item count.
- Tactical Inventory overlay.
- Equipped, quick-access and packed-item sections.
- Local-access section showing known items on the current and adjacent tiles.
- Gold tactical item markers on the map.
- Keyboard shortcuts:
  - `1`, `2`, `3` select squad members.
  - `I` opens or closes Inventory.
  - `Esc` closes or cancels the current UI mode.
- Functional Sprint movement mode:
  - Full Action.
  - Up to 150% normal Speed.
  - Requires an untouched normal-action budget.
  - Removes the Reaction until refresh.
  - Cannot cross difficult terrain in this prototype.
- Ready Stance remains a functional Quick Action budget test through the final action tray.
- Existing normal movement, pathfinding, player-phase switching and World Phase refresh remain intact.

## Deliberately not implemented yet

The Inventory panel is read-only. It establishes layout, local-access discovery and the permanent button, but does not yet move items.

Deferred inventory commands include:

- pick up;
- drop;
- equip;
- unequip;
- pass to adjacent ally;
- move to Quick Access;
- retrieve from packed storage;
- open a container;
- transfer bulky loot.

Attack, Interact, Disengage and Overwatch are visible in their final UI homes but remain disabled until their underlying systems exist.

## Files added

```text
domain/tactical/tactical_inventory_state.gd
domain/tactical/tactical_item_state.gd
domain/tactical/sprint_move_command.gd
application/tactical/sprint_move_handler.gd
docs/architecture/STAGE_3_TACTICAL_UI_INVENTORY_FOUNDATION.md
```

## Files changed

```text
bootstrap/boot/boot.gd
domain/tactical/tactical_unit_state.gd
domain/tactical/tactical_state.gd
presentation/tactical/tactical_screen.gd
presentation/tactical/tactical_screen.tscn
CHANGELOG_STAGE_3_UI.md
PROJECT_TREE.txt
```

## Recommended test checklist

1. Run the project at 1280 × 720.
2. Confirm the map remains unobstructed between the left roster and right information panel.
3. Select each unit through the map, roster and keyboard shortcuts.
4. Confirm individual movement budgets remain independent.
5. Hover routes and verify green/amber preview distinction.
6. Open Tactics and select Sprint.
7. Confirm the route changes to Sprint presentation.
8. Sprint a unit and verify its normal capacity becomes zero.
9. Confirm its Reaction becomes spent.
10. Open Inventory with the button and the `I` key.
11. Confirm the selected unit's equipped, quick and packed items appear.
12. Confirm local item lists change when selecting or moving units.
13. Confirm the Inventory button displays a nearby-item count.
14. Confirm map movement cannot occur while Inventory is open.
15. Confirm `Esc` closes Inventory or cancels Sprint/context modes.
16. End the Player Phase and confirm all appropriate allowances refresh next round.

## Next stage

The recommended next stage is the practice-dummy combat loop using the HUD that now exists:

- target selection;
- attack preview;
- melee and ranged attacks;
- attack roll;
- Armour Class;
- damage;
- combat event log;
- dummy defeat and reset.
