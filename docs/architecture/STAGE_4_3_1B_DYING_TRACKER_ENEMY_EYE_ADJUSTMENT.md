# Stage 4.3.1b — Dying Tracker and Enemy-Only Awareness Icon Adjustment

## Scope

This is a presentation-only refinement of Stage 4.3.1a. It changes neither
life-state rules nor squad-awareness state.

## Dying emblem

The central skull remains inside the common fourteen-pixel status backplate,
but now uses an 11.5-pixel artwork region so its colourful inked silhouette is
readable. The two three-step tracks sit outside that backplate:

```text
green success pips   skull   red failure pips
```

The complete tracker is wider because it communicates two independent values,
while its central status icon retains the same scale and anchor as the eye,
hood, ZZZ and Dead emblems.

Filled success pips use painted green. Filled failure pips use painted crimson.
Empty pips use darker inked variants and remain outlined.

## Awareness-eye meaning

The eye is not a general combat icon. It means that an enemy patrol member's
squad is Aware and actively participating in combat. Consequently:

- aware conscious enemy: eye;
- unaware enemy: no eye;
- player character: never eye;
- Dying, unconscious or Dead enemy: body-state badge overrides eye.

This is enforced in `TacticalUnitView.displayed_badge_kind()` so an accidental
player-side `set_aware_badge(true)` cannot render the enemy patrol symbol.

## Tests

The Stage 4.3.1a runtime suite now also verifies that:

- an aware enemy still receives the eye;
- a player does not receive the eye even if the presentation flag is set;
- existing body-state badge priority remains intact.
