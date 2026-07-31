# Stage 4.2.5.4 — Character Facing and Symmetric Perception

## Purpose

This stage gives facing a single authoritative tactical meaning without making
ordinary attacks or revealed-target visibility depend on token orientation.
Facing controls passive detection of **hidden** units. Revealed combatants use
ordinary wall-blocked sight.

## Perception contract

| Target state | Perception used |
|---|---|
| Revealed to an aware squad | 40-square, 360-degree ordinary sight |
| Hidden or not yet revealed | 25-square, approximately 90-degree focused cone |
| Hidden within one grid step | One-square all-around close perception, normal Stealth check with the close bonus |

Grid ranges continue to use `TacticalGridDistance.steps_between`, so a diagonal
neighbour is two steps.

## Facing state

`TacticalUnitState.facing_direction` is the sole tactical authority. It is an
eight-direction `Vector2i` normalized through
`TacticalPerceptionRules.normalized_facing`.

Facing changes occur through commands and committed action handlers:

- ordinary movement: final completed path step;
- Sprint: final completed path step;
- attack: direction from attacker to target;
- manual player turn: `FacingHandler`, costing 5 feet.

Presentation reads committed facing and never mutates it directly.

## Manual orientation

With an active player character selected, right-clicking a legal map tile sends
a Face Direction request. Attack targeting and special-mode cancellation keep
input priority. The action:

- costs 5 feet of normal turn capacity;
- preserves Stealth;
- does not consume the Quick Action;
- refreshes the player squad's passive perception;
- compares hidden enemies against their retained Stealth result.

## Symmetric hidden-unit knowledge

The session creates `squad.player.team` and assigns all player units to it for
perception and shared exact-position knowledge. `revealed_to_squad_ids` is now
used symmetrically by player and enemy units.

A hidden unit is excluded from enemy presentation when it is not revealed to
any player-team squad. Once detected, it is revealed to the player team. This
does not make an enemy squad aware and does not begin initiative; alert
transition remains specific to an enemy squad detecting a player threat.

## No reroll fishing

A hidden unit stores:

- `current_stealth_roll_valid`;
- `current_stealth_roll_value`;
- `current_stealth_total`.

Entering Stealth establishes the result. Hidden movement replaces it with the
most recent per-tile Stealth result. Passive orientation checks reuse it.
Turning away and back therefore changes which units are compared but never
creates another Stealth roll.

## Last-seen presentation

Player squad memory uses the same `last_seen_positions_by_unit_id` contract as
enemy squads. If a previously revealed enemy leaves all player ordinary sight,
the live token disappears and the final confirmed tile receives a subtle
last-seen marker. The marker is historical information and never tracks hidden
movement.

## Boundaries

This stage does not implement Active Search, AI Hide decisions, directional
cover, Overwatch, Brace or authored eight-direction sprites. Those systems must
consume the same facing and perception queries later rather than introduce
parallel orientation state.
