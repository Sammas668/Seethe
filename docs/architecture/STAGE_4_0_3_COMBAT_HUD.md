# Stage 4.0.3 — Combat HUD readability

Stage 4.0.3 is a presentation-only combat readability pass with one reserved tactical field for future nonlethal damage.

## Segmented health authority

The bar uses the unit's existing tactical values:

- `maximum_hp` defines the full width;
- `current_hp` defines the green region from the left edge;
- `maximum_hp - current_hp` defines the red lethal-damage region on the right;
- `nonlethal_damage` defines the white overlay advancing from the left.

As lethal damage accumulates, the green/red boundary moves left. As nonlethal damage accumulates, the white overlay moves right. The white overlay is deliberately allowed to approach or cross the current-HP boundary so a later unconsciousness rule can be read visually.

Stage 4.0.3 does not apply nonlethal damage. The field is initialised to zero and preserved when a resolved character refreshes.

## Squad cards

The old multiline button text has been replaced with a composed roster card:

- wrapped shortcut and character name;
- segmented numerical health bar;
- wrapped capacity and activation state.

The card remains a normal Button, so selection, keyboard shortcuts and player-phase disabling remain unchanged.

## Selected-unit block

The bottom HUD now displays:

- wrapped character name;
- the same segmented health bar with current/max HP centred inside;
- Armour Class and remaining/maximum capacity beneath it;
- the existing turn-capacity bar;
- wrapped context text rather than clipped text.

No attack, damage, inventory, enemy-turn or campaign rules are changed by this milestone.
