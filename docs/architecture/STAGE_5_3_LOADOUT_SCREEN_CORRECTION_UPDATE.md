# Stage 5.3 Loadout Screen Correction Update

## Scope

This correction retains the Xenonauts-inspired Equip Troops structure while ensuring that the interface behaves responsively, exposes only real Seethe equipment containers and does not create a persistent armour-repair chore.

## Responsive layout contract

The strategic equipment workspace uses three expanding columns rather than three competing fixed widths:

- character identity and resolved statistics;
- character presentation and loadout;
- available items.

The centre receives the largest stretch ratio. Available-item content scrolls within its panel and may not expand the parent screen. Spatial inventory cells reduce at narrower supported desktop widths, while all item state and grid coordinates remain unchanged.

## Supported strategic containers

The player-facing strategic loadout contains:

- Primary Hand;
- Secondary Hand;
- Armour;
- Belt;
- Backpack;
- ammunition carried through the appropriate authored container rules.

`worn_utility` is legacy vocabulary only. Old items are migrated in this order:

1. Belt when legal and space exists;
2. Backpack when legal and space exists;
3. Stronghold Storage.

New assignments to Worn Utility are invalid.

## Strategic armour condition

Recovered persistent armour is considered repaired and serviceable. Strategic presentation does not display ordinary armour condition, and persistent armour resolves at condition `1.0` after extraction, recovery, equipping and migration.

This does not reverse authored terminal outcomes. Armour may still remain lost, captured or destroyed when the mission result explicitly says so.

## Save migration

Campaign save version 11 runs `StrategicLoadoutCorrectionMigration` before campaign validation. It repairs legacy Worn Utility locations, updates template container rules and normalises persistent armour condition without creating duplicate item instances.
