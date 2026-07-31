# Stage 4.3.1e — Disabled Action and Non-Blocking Hit Reaction Correction

## Purpose

Bring the exact-0-HP action contract into line with Seethe's tactical rules and
make committed damage readable without inserting presentation timing into combat
resolution.

## Exact 0 HP

Exactly 0 HP remains **Disabled**, not unconscious or defeated. A Disabled unit:

- refreshes to 50% normal turn capacity;
- retains one Quick Action;
- has no Reaction;
- cannot take a Full Action;
- may use ordinary movement within its reduced capacity without losing HP;
- may use ordinary Minor Interactions without automatically losing HP;
- loses 1 HP after a strenuous Half Action, including an attack, First Aid or
  a Half-Action inventory transfer,
  and therefore becomes Dying if still alive.

The existing later-stage Dying tracker, negative-HP visibility, death threshold,
healing transitions and downed-body presentation are retained unchanged by this
correction.

## Damage event order

`AttackHandler.damage_committed` is emitted only after the complete tactical
change set succeeds. At that point:

1. HP, nonlethal damage and life state are authoritative;
2. post-commit combat-log recording has completed;
3. `TacticalStateStore.state_changed` has already fired;
4. presentation receives the damage event.

The event is forwarded by `TacticalScreenFacade`. The screen refreshes the
life-state badge and calls `TacticalUnitView.play_damage_reaction()` without
awaiting it.

## Token presentation

The reaction lasts 0.8 seconds. It applies a crimson pulse and subtle diminishing
local shake to token artwork only. Selection rings, initiative rings and status
badges are drawn after the local transform is reset, so a Dying or Dead marker is
readable immediately.

A repeated hit kills the previous tween, restores the presentation baseline and
restarts at full intensity. The tween never changes grid position, action state,
input state, initiative state or AI scheduling.

## Boundaries

- No gameplay handler awaits presentation.
- No board-input lock is introduced.
- Misses and zero applied damage emit no hit event.
- Both lethal HP loss and committed nonlethal damage use the same visual event.
- Environmental damage can adopt the same post-commit event contract when those
  handlers become part of the vertical slice.
