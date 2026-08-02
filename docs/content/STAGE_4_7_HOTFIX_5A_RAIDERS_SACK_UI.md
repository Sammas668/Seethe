# Stage 4.7 Hotfix 5a — Raider's Sack Inventory UI

Raider's Sack remains an authoritative permanent item occupying the rightmost 2×2 cells of a Marauder's Belt. It is rendered through the normal spatial inventory-item control, but cannot be moved because it is a fixed fixture.

## Interaction

- Left-click Raider's Sack to open it.
- Opening displays a compact `floating panel` rather than adding another panel to the main inventory layout.
- The floating panel contains the authoritative 4×3 `raider_sack` grid, large enough for one Medium body.
- Click the red **X** in the popup's top-right corner to close it.
- Opening or closing is presentation-only and spends no action or tactical revision.

## State ownership

The Sack item remains in the Belt. A captive or compatible burden placed inside uses the existing `raider_sack` item location and keeps its identity, body inventory, weight, restraint state and mission classification. This hotfix changes only discoverability and presentation; the Hotfix 5 transfer and extraction rules remain authoritative.
