# Stage 3.4 — Compact Bottom Deck

This update fixes the remaining Stage 3.3 layout problems at 1280 × 720.

## UnitBlock

The visible UnitBlock now uses four compact rows:

- Unit name.
- HP, AC and capacity combined into one line.
- Smaller capacity bar.
- Quick Action, Reaction and contextual status combined into one line.

The redundant capacity/Q/R label remains hidden for script compatibility
and no longer consumes vertical space.

The UnitBlock is also narrower, has smaller internal spacing, a shorter
capacity bar and a smaller context font.

## CommandBlock

- Command button widths and spacing were reduced.
- Command font size was reduced to 12.
- Context action buttons were reduced to 72 × 28.
- HandBlock and PhaseBlock were narrowed slightly.
- BottomDeck margins and MainRow spacing were reduced.

## Unchanged

Movement, phases, Sprint, hand-slot actions, Inventory, unit selection and
the expanded tactical map are unchanged.

## Test checklist

1. Run at 1280 × 720.
2. Confirm the UnitBlock remains fully inside the BottomDeck.
3. Confirm HP, AC, capacity, Quick Action and Reaction remain visible.
4. Confirm the complete CommandBlock and End Phase control fit on-screen.
5. Select every unit.
6. Hover movement paths.
7. Click both hand slots and every action-category button.
8. Open and close Inventory.
9. End the Player Phase.

Godot is not installed in the generation environment, so the project still
requires one test run in Godot 4.
