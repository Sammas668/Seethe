# Stage 5.3 Xenonauts Equip Proportions Update

## Current decision

Equip Troops uses percentage-anchored regions rather than competing expanding columns. The later **Equip Layout Tightening Update** supersedes the original overlapping composition while preserving the Xenonauts screen grammar.

The persistent visual order is:

1. Soldier information and assignment selector on the left.
2. Compact Armour, Primary, Secondary and Carry Weight stack.
3. Full-body character art as the central anchor.
4. Loadout controls and carried spatial inventory to the character's right.
5. Available Equipment in the far-right rail.

## Horizontal proportions

| Region | Workspace anchors | Approximate width |
|---|---:|---:|
| Left information rail | 0.008–0.218 | 21.0% |
| Equipped stack | 0.236–0.350 | 11.4% |
| Character art | 0.356–0.554 | 19.8% |
| Carried inventory | 0.560–0.776 | 21.6% |
| Available equipment | 0.786–0.992 | 20.6% |

Functional regions no longer overlap. Decorative art may approach neighbouring frames, but it never covers interactive controls.

## Responsive behaviour

- Main regions are percentage anchored, not driven by competing minimum widths.
- Main content ends before the character-tab strip begins.
- Available Equipment clips and scrolls internally.
- Backpack cells scale to 24, 29, 31 or 34 pixels based on viewport width.
- Long dropdown items cannot force their rail wider.
- The full-body character remains centred while the Backpack receives the dominant interactive area in the centre-right rail.

## Interaction boundaries

- Armour is selected through the exact-instance Armour selector and is not shown as an Available Equipment tab.
- Auto-pack remains an internal migration/template service and is not exposed on the equipment screen.
- Belt and Backpack retain manual drag, click placement, rotation and Clear controls.

## Authority

The update changes presentation only. `InventoryService`, `StrategicEquipmentService` and `LoadoutService` remain authoritative for item ownership, legal placement and template resolution.
