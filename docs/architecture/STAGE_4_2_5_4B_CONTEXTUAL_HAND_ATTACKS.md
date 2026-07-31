# Stage 4.2.5.4b — Persistent Hand Selection and Contextual Basic Attacks

## Boundary

This stage changes tactical input and presentation only. Attack validation and resolution still pass through the existing application facade and attack handler. Movement, Stealth, perception, initiative and AI rules are unchanged.

## Persistent hand intent

`TacticalScreen` remembers one selected hand per player character in `_selected_hand_by_unit_id`. The current character always resolves to either `KIND_PRIMARY_HAND` or `KIND_SECONDARY_HAND`; the selection never becomes `NONE` while a player character is active. A remembered empty hand remains a valid selection so later unarmed and manoeuvre actions can use the same input model.

The hand selection is presentation-session state rather than campaign equipment state. Equipment location remains authoritative in `TacticalState`.

## Contextual attack contract

With no explicit ability-targeting mode active:

1. Hovering a visible hostile asks the facade for an attack preview using the selected hand's first supported basic attack.
2. The cursor preview displays the same hit chance, damage, action cost, mode and Power Attack information used by explicit targeting.
3. Left-clicking the hostile revalidates the attack through `preview_attack()` and commits it through `execute_attack_preview()` only when legal.
4. A hostile tile is never interpreted as a movement destination or inspection selection.

No automatic move-to-attack behaviour is introduced.

## Input priority

| Click context | Result |
|---|---|
| Legal hostile | Cancel board preview and attack with selected hand |
| Illegal hostile | Cancel board preview and report the exact attack failure |
| Friendly or neutral unit | Select or inspect that unit |
| Empty ground | Use the existing movement preview/confirmation flow |
| Right-click ground | Use the existing facing preview/confirmation flow |

Explicit spell, area, multi-step and later ability targeting still uses `_attack_targeting` or its future typed equivalent. Cancelling such a mode restores the persistent selected-hand attack rather than clearing hand selection.

## Presentation ownership

- Hand buttons display and change persistent selection.
- `TacticalScreen` requests contextual attack previews and decides click intent.
- `TacticalBoardView` only highlights the currently hovered contextual target.
- The facade remains the authority for legality, costs and attack execution.

## Non-goals

- No auto-pathing into attack range.
- No change to attack maths or repeated-attack penalties.
- No Full Attack implementation.
- No new unarmed, grapple or spell targeting content.
- No change to movement, facing, Stealth, initiative or AI.
