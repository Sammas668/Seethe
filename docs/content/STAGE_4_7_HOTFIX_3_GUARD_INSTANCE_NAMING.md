# Stage 4.7 Hotfix 3 — Approved Guard Instance Naming

## Defect

The farm mission instantiated two approved `character_template.life.sanctuary_spear_guard` units, but assigned the mission-local display labels **Sanctuary Storehouse Guard** and **Sanctuary Field Guard**. Those labels incorrectly suggested that the mission was generating two separate Guard types or character sheets.

## Correction

Both persistent tactical instances now display as **Sanctuary Spear Guard**. Their distinct persistent IDs remain:

- `character.life.sanctuary_spear_guard.0001`
- `character.life.sanctuary_spear_guard.0002`

Both use the same approved source content:

- template: `character_template.life.sanctuary_spear_guard`
- AI profile: `ai.life.sanctuary_spear_guard`
- Capture Spear and Sanctuary Blackjack loadout
- Warrior 1 resolved sheet and approved capture-focused features

The posting location remains represented by position, squad and patrol-path data rather than by inventing a second unit title.

## Regression protection

The Stage 4.7 sheet-conformance validator now fails if either misleading label returns and requires exactly two `Sanctuary Spear Guard` instance labels in the authored farm mission.
