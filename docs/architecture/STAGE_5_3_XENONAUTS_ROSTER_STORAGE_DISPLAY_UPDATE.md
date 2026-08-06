# Stage 5.3 — Xenonauts-Style Roster and Storage Display Update

## Purpose

Reorganises the Stage 5.3 strategic character and inventory presentation around the two management patterns proven by Xenonauts:

- a large sortable roster table for comparing the whole force;
- a dedicated character-focused equipment view for managing one persistent individual;
- a separate item-first storage screen for locating and protecting the complete collection.

The update changes presentation and navigation only. Existing persistent character records, exact item identities, equipment validation and InventoryService transaction ownership remain authoritative.

## Roster modes

The single top-level Roster screen now contains:

1. Manage Roster — sortable troop table with status filters and aggregate readiness counts.
2. Equip Troops — large full-body character presentation, visual equipment slots, quick character switching and a compatible item pool.
3. Memorial — permanent record of dead campaign characters.

## Equip Troops

The layout is character-first:

- left: identity, resolved headline statistics and quick roster;
- centre: full-body art, visual armour/hand/belt/backpack slots and character information tabs;
- right: item-category tabs and exact persistent storage items available for the selected destination.

Equipment changes still call CampaignSession and StrategicEquipmentService. The UI does not write item locations.

## Storage

The storage screen is item-first:

- left: category and location filters;
- centre: compact table of all matching persistent item instances;
- right: large item presentation, description, location, condition, protection and legal cross-links.

Furniture—including unique installable facility objects—and salvage remain visible in Storage but are excluded from character equipment pools. Storage has no separate Installations category.

## Art and atmosphere

New authored strategic SVG backgrounds provide a dark Fifth-God Muster Hall, armoury and Storehouse context. Generic category icons provide a stable visual fallback until each persistent item definition receives bespoke art.
