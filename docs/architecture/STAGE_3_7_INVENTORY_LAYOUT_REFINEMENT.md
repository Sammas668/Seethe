# Stage 3.7 — Inventory Layout Refinement

This is a presentation-only refinement built directly from the Stage 3.6
XCOM Belt and Spatial Inventory project.

## Implemented changes

- Removed the large bottom instructional/context footer from the Unit
  Management window.
- Backpack and Items in Reach now inherit the reclaimed vertical space.
- Moved the two tab buttons into a centred `TabGroup` in the permanent top
  header.
- Added flexible spacers on both sides of the tab group so it no longer sits
  over the right-hand character-statistics panel.
- Moved item instructions and action previews beneath the Belt.
- Reduced the moved text to a 10-pixel UI font.
- Shortened the default help copy to:
  - `Drag an item, click a destination, or right-click for a quick move.`
  - `Belt ↔ Hand: Quick Action. Backpack is slower.`
- Kept selected-item and action-cost feedback in the same compact under-Belt
  area.

## Unchanged

- Primary and Secondary Hand rules.
- Two-handed weapon reservation.
- Belt, Backpack and Items in Reach grid sizes.
- Multi-cell item placement.
- Drag-and-drop, click-destination and right-click movement.
- Inventory action costs.
- Character Sheet contents.
- Tactical HUD and movement systems.

## Files changed

```text
bootstrap/boot/boot.gd
presentation/tactical/unit_management_window.gd
presentation/tactical/unit_management_window.tscn
docs/architecture/STAGE_3_7_INVENTORY_LAYOUT_REFINEMENT.md
CHANGELOG_STAGE_3_7_INVENTORY_LAYOUT_REFINEMENT.md
README_FIRST.txt
PROJECT_TREE.txt
```

## Test checklist

1. Run at 1280 × 720.
2. Open Inventory and confirm there is no footer at the bottom.
3. Confirm Backpack and Items in Reach extend into the reclaimed space.
4. Confirm Inventory and Character Sheet tabs are centred in the top header.
5. Confirm the tabs no longer appear attached to or underneath the stat panel.
6. Confirm both instruction lines fit beneath the Belt at the smaller size.
7. Select items in every container and confirm selected-item information appears
   beneath the Belt.
8. Perform Belt-to-Hand, Backpack and Items-in-Reach transfers.
9. Switch to Character Sheet and back.
10. Switch units and close the window with `I`, `Esc` and `X`.

Godot is not installed in the generation environment, so an engine run is still
required before replacing the last confirmed working project.
