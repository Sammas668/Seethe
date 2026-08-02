# Stage 4.7 Hotfix 2 — Deployment Loadout Legality

## Defect

The approved Sanctuary Spear Guard and Sanctuary Archer carry the Sanctuary Blackjack as a Belt sidearm. The authored item definition incorrectly set `belt_allowed = false`. Tactical assembly therefore rejected the first Guard's Blackjack with `deployment_item_invalid`.

## Correction

The Sanctuary Blackjack remains a 1x2 one-handed nonlethal capture weapon and is now explicitly Belt-legal. This matches its approved role as a readily accessible secondary capture weapon and fits the existing 5x2 Belt grid.

## Prevention

`ContentCatalogue.validate_catalogue()` now validates every registered character template's default loadout before the catalogue freezes. It checks:

- referenced item existence;
- stack quantity;
- hand-equipment legality;
- duplicate hand occupation;
- two-handed conflicts;
- Belt and Backpack permission;
- inventory-grid bounds;
- overlapping inventory footprints;
- unknown container kinds.

This shifts the failure boundary from partial mission assembly to content loading. A future invalid default loadout should be reported as a catalogue error before any unit deploys.

The validator immediately exposed three additional latent overlaps. The Guard bandage, Archer bandage and Mercy-Bearer divine focus now occupy non-overlapping Backpack cells. These changes affect storage layout only, not approved equipment or statistics.

## Unchanged design

No character statistic, feat, attack, spell, AI profile or HUD layout changed. Stage 4.7 Hotfix 1 remains the authority for the approved Marauder, Sanctuary Spear Guard, Sanctuary Archer and Mercy-Bearer sheets.
