# Stage 3.2 — Expanded Tactical Map UI

This update is built from the last working Stage 3 project and changes only the tactical layout.

## Changes

- The former right information panel is no longer visible or interactive.
- Its complete area is returned to the tactical map.
- The board is slightly enlarged and centred between the squad roster and the right edge.
- `RosterSubtitle` is removed.
- `ItemLegend` is removed.
- Selected-unit information is consolidated into the bottom `UnitBlock`.
- The `UnitBlock` now shows:
  - unit name;
  - HP and Armour Class;
  - remaining capacity;
  - Quick Action and Reaction states;
  - compact capacity bar;
  - Half-Action threshold;
  - current tile;
  - path and terrain preview;
  - recent status messages.
- Equipment and command widths are reduced so the expanded unit block does not push phase controls off-screen.
- Context action buttons share available width.

## Stability approach

The old `RightPanel` nodes remain hidden for compatibility with the last working script. This prevents another script/scene mismatch and another null-instance error while still reclaiming all visible map space.

No inventory, movement, phase or action-economy models were changed.

## Test checklist

1. Run at 1280 × 720.
2. Confirm the right side is entirely tactical-map viewing space.
3. Confirm the board is centred and slightly larger.
4. Confirm the roster has no subtitle or item legend.
5. Select every squad member.
6. Confirm the UnitBlock updates HP, AC, capacity, Quick Action and Reaction.
7. Hover movement paths and confirm path and terrain appear in the UnitBlock.
8. Open each action category and confirm a recent status message appears.
9. Open and close Inventory.
10. End the phase and confirm the phase controls remain visible.

Godot is not installed in the generation environment, so the project still requires one test run in Godot 4.
