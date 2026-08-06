# Stage 3.6 — XCOM Belt and Spatial Inventory

Stage 3.6 rebuilds the tactical Inventory tab around the approved XCOM and
Xenonauts-inspired composition.

## Final tactical composition

The Unit Management window still has two persistent tabs:

- **Inventory**
- **Character Sheet**

The Inventory tab now uses:

- Primary Hand.
- Secondary Hand.
- A small connected Belt grid.
- A large connected Backpack grid.
- A second connected Items in Reach grid.
- A central future-proof character-art area.
- A compact tactical-statistics panel.

There is no tactical armour slot and no prepared or readied weapon set.
Armour remains read-only information on the Character Sheet.

## Belt rules

The Belt is a physical 5 × 2 spatial grid. Items occupy connected cells rather
than one abstract button each.

- Belt to Hand: Quick Action.
- Hand to Belt: Quick Action.
- Ground to Belt: 5-foot Minor Interaction plus Quick Action.
- Backpack to or from Belt: Half Action and normally Provokes.
- Rearranging an item inside the Belt: Free.

Large objects, bows, spears, shields, armour and bulky loot cannot fit on the
Belt.

## Multi-cell inventory

The Backpack uses a 10 × 4 grid. Items store:

```text
item id
container
position
width and height
weight
two-handed flag
Belt eligibility
```

Prototype footprints include:

| Item | Footprint |
|---|---:|
| Bandage, pellet or chalk | 1 × 1 |
| Rope or manacles | 2 × 1 |
| Dagger or knife | 1 × 2 |
| Shield | 2 × 2 |
| Axe | 2 × 3 |
| Bow | 3 × 2 |
| Spear | 1 × 4 |
| Grain crate | 3 × 2 |

Items move as one object across all occupied cells. Their text is shown once,
not repeated in every occupied cell.

## Items in Reach

Items in Reach is a second connected spatial grid. It automatically arranges
all loose items currently accessible from the unit's own tile and reachable
adjacent tiles. This arrangement is presentation-only; each item retains its
real tactical-map position.

Dragging an item into Items in Reach drops it on the selected unit's current
tile. Dragging an item out picks it up using the appropriate action cost.

## Hands and two-handed equipment

Primary Hand and Secondary Hand are large equipment regions.

- One-handed items may enter either hand.
- A two-handed item must be placed through Primary Hand.
- A two-handed Primary item automatically reserves Secondary Hand.
- Removing the two-handed item releases Secondary Hand.

The tactical HUD now uses the same Primary and Secondary terminology.

## Interaction

- Drag and drop commits a valid ordinary transfer immediately.
- Click an item, then click an empty destination.
- Right-click performs a sensible quick move.
- The footer shows item weight, footprint, description and action costs.
- Invalid destinations return a clear reason.

Routine transfers no longer require permanent Confirm and Cancel buttons.

## New files

```text
domain/tactical/tactical_item_profile.gd
domain/tactical/tactical_inventory_item_state.gd
presentation/tactical/spatial_inventory_item_control.gd
presentation/tactical/spatial_inventory_grid.gd
presentation/tactical/unit_silhouette.gd
```

## Replaced or substantially revised files

```text
domain/tactical/tactical_inventory_state.gd
domain/tactical/tactical_inventory_transfer_command.gd
domain/tactical/tactical_inventory_transfer_preview.gd
domain/tactical/tactical_item_state.gd
application/tactical/tactical_inventory_transfer_handler.gd
presentation/tactical/unit_management_slot.gd
presentation/tactical/unit_management_window.gd
presentation/tactical/unit_management_window.tscn
presentation/tactical/tactical_screen.gd
presentation/tactical/tactical_screen.tscn
bootstrap/boot/boot.gd
```

## Test checklist

1. Run at 1280 × 720 and confirm the entire window fits.
2. Open Inventory and Character Sheet from the compact header tabs.
3. Switch among all three units without refreshing spent actions.
4. Confirm Primary and Secondary Hand replace Left and Right Hand wording.
5. Confirm there is no tactical armour slot or readied-set control.
6. Confirm Belt, Backpack and Items in Reach are connected grids.
7. Confirm Rope, Dagger, Bow, Spear, Axe and Grain Crate visibly occupy
   different numbers of cells.
8. Drag Belt items into an empty hand and confirm the Quick Action is spent.
9. Drag a held item to the Belt and confirm the Quick Action is spent.
10. Move a Backpack item to a hand and confirm the Half Action cost.
11. Pick up the Dropped Spear and confirm the 5-foot pickup cost.
12. Confirm the Grain Crate cannot enter the Belt or Backpack.
13. Drag a carried item into Items in Reach and confirm a tactical ground item
    appears on the current tile.
14. Equip the Shortbow through Primary Hand and confirm Secondary Hand becomes
    reserved.
15. Confirm the Character Sheet lists armour as read-only information.
16. Confirm tactical HUD hand boxes update after transfers.

The generation environment does not contain Godot, so the complete project
still requires an engine run before replacing the last confirmed working copy.
