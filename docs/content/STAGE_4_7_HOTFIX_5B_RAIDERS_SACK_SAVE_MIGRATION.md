# Stage 4.7 Hotfix 5b — Raider's Sack Save Migration

## Problem confirmed

The Hotfix 5a UI existed, but an older local debug campaign could still open with the pre-Hotfix Marauder loadout. In that state the Mace remained in Primary Hand, Raider's Axe could remain in the Belt, the deprecated carrying belt remained in the Backpack, and Raider's Sack was never deployed.

Two connected defects caused this:

1. campaign item validation treated every fixed equipment location as a hand, so adding Patchwork Raider Armour caused the corrective campaign transaction to be rejected;
2. authored mission assembly logged campaign-bootstrap failure but continued with the stale campaign.

Old saves could also be rejected before the normal sandbox repair ran because obsolete items and old weapon locations were validated against the new item definitions.

## Correction

- Fixed character equipment validation now distinguishes Primary/Secondary Hand from Armour and Worn Utility.
- `MarauderLoadoutMigration` repairs existing Marauder records before save validation.
- The repaired campaign is persisted atomically through the existing repository backup path.
- The same migration remains idempotently available during sandbox bootstrap.
- Authored mission assembly now fails closed if campaign bootstrap fails instead of opening a stale partial mission.
- Runtime coverage checks both Hakon Rusk and Svala Thorn for one Raider's Sack at Belt position `(5, 0)`.

## Correct deployed Marauder layout

- Primary Hand: Raider's Axe
- Secondary Hand: Empty
- Armour: Patchwork Raider Armour
- Belt: Mace, Raider's Dagger, two Manacle sets, Raider's Keys, Bandage
- Belt rightmost 2×2: Raider's Sack
- Backpack: Rope

Raider's Sack remains a normal fixed 2×2 Belt item. Left-clicking it opens the floating 2×2 captive inventory panel, and the red X closes that panel.
