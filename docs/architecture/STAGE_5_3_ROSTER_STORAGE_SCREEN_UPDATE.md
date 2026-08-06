# Stage 5.3 — Roster & Storage Screen Update

## Purpose

Replace the separate strategic Roster and Equipment screens with two player-facing workspaces:

1. **Roster & Equipment** — character-first, Xenonauts-style troop inspection and loadout management.
2. **Stronghold Storage** — item-first ownership, filtering, location and protection management.

This update establishes the initial strategic item-management boundary without turning the Storage screen into a duplicate character sheet.

## Screen contract

### Roster & Equipment

The screen contains:

- a persistent roster list;
- selected-character portrait, identity, Tier, Level, readiness, XP and carrying weight;
- Loadout, Character and History tabs;
- Primary Hand, Secondary Hand, Armour, Worn Utility, Belt and Backpack containers;
- an available-equipment pool sourced from stronghold storage;
- direct equip and return-to-storage actions;
- exact validation reasons for unavailable destinations.

The screen is character-first. Furniture—including unique installable facility objects—and structural salvage are excluded from the available-equipment pool. Built-in tactical structures are not inventory items.

### Stronghold Storage

The screen contains:

- item-category filters;
- item-location filters;
- a complete persistent item list;
- selected-item description, condition, quantity, weight, inventory size and current location;
- Protect / Unprotect;
- View Character for equipped items;
- Return to Storage where legal;
- a cross-link to Roster & Equipment for stored character-carriable items.

The screen is item-first and remains the future home of selling, dismantling, repair, furniture installation and production actions. Installable objects remain Furniture rather than becoming a separate item category.

## Authority boundaries

- `CampaignShell` sends intents and never changes item locations directly.
- `InventoryService` is the sole application service used to mutate item locations and the player protection flag.
- `StrategicEquipmentService` validates slots, hands, proficiency, carrying capacity, spatial Belt/Backpack placement and displacement.
- `CampaignSession` stages all persistent changes through `CampaignChangeSet` and `CampaignStateStore`.
- Campaign validation runs against the resulting detached candidate before commit.

## Initial transfer behaviour

The update supports:

- storage to Primary Hand;
- storage to Secondary Hand;
- storage to Armour;
- storage to Worn Utility;
- storage to Belt;
- storage to Backpack;
- carried item to another legal container on the same character;
- return to stronghold storage;
- occupied fixed-slot displacement back to storage;
- two-handed weapon handling;
- deterministic first-fit Belt and Backpack placement;
- proficiency and carrying-capacity rejection.

Character-to-character direct transfer remains a later Stage 5.3 refinement; players may return the item to storage and then assign it to another character.

## Item protection

`CampaignItemState.is_protected` is persisted with each exact item instance.

Protection:

- is player-controlled;
- does not move the item;
- does not prevent deliberate manual equipment assignment;
- is intended to exclude the item from future automatic construction, selling and dismantling selection.

## Non-goals

This update does not implement:

- deployment reservations;
- construction reservations;
- furniture selection for projects;
- automatic loadout templates;
- selling;
- dismantling;
- production;
- repair;
- Research inputs;
- character-to-character direct transfer;
- injury and recovery;
- captives.

## Acceptance summary

The update passes when:

- top navigation shows Roster and Storage rather than separate Roster and Gear screens;
- Roster & Equipment displays the selected character and exact loadout;
- a stored legal item can be assigned through a validated campaign transaction;
- displaced fixed-slot items return to storage atomically;
- an equipped item can return to storage;
- Storage filters the complete persistent item collection by category and location;
- Storage shows exact current ownership;
- protection survives save/load;
- the UI never directly mutates item state;
- all Stage 5.0–5.2 static regression suites remain green.
