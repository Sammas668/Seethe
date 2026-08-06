# Stage 5.3 Equip Troops Layout Tightening Update

## Decision

The Xenonauts-inspired Equip Troops screen keeps its five-part visual grammar, but functional panels no longer overlap. Space is reallocated from oversized Armour and hand panels to the carried-inventory area.

## Horizontal regions

| Region | Workspace anchors | Approximate width |
|---|---:|---:|
| Soldier information and assignments | 0.008–0.218 | 21.0% |
| Compact Armour / Primary / Secondary stack | 0.236–0.350 | 11.4% |
| Full-body character | 0.356–0.554 | 19.8% |
| Loadout, Belt and Backpack | 0.560–0.776 | 21.6% |
| Available Equipment | 0.786–0.992 | 20.6% |

Each functional region is separated by a gap. The main content ends at 0.845 of the workspace height, while character tabs begin at 0.858, preventing the bottom controls from covering the equipment screen.

## Carried inventory hierarchy

The centre-right panel uses this fixed order:

1. One-row passive template icon, selector, Save and Load strip.
2. Compact Belt grid.
3. Expandable Backpack panel as the dominant interactive area.
4. Loadout-readiness strip.
5. Undo and Return Items.

Auto-pack is deliberately not exposed. Templates provide reusable organisation, while the player retains manual drag, click placement, rotation and Clear controls. Internal deterministic packing remains available for migration and template resolution.

## Armour boundary

Armour is selected only through the exact-instance Armour selector. It is removed from the Available Equipment category tabs because it is not dragged into the hand or carried-inventory areas.

## Responsive presentation

Backpack cells scale to 24, 29, 31 or 34 pixels according to viewport width. The 10×4 authoritative Backpack dimensions remain unchanged and match tactical deployment. Available Equipment scrolls internally and cannot expand the screen.

## Authority

This is a presentation correction. `InventoryService`, `StrategicEquipmentService` and `LoadoutService` remain authoritative for ownership, legal placement, spatial positions and template application.
