# Stage 4.3.1a — Token Status and Shared Squad Alert Correction

## Locked presentation contract

Every status emblem attached to a tactical counter uses the same anchor, radius, outline thickness and icon box. Body state has priority over awareness and Stealth:

```text
Dead → Dying → Unconscious/Stable → Hidden → Aware
```

The Dying badge contains the three success and three failure pips inside the common badge frame. Entering Dying displays an empty track immediately. Pips change only when a Dying-track result changes them.

## Locked squad contract

The generated Settlement Guard and Settlement Archer are both members of `squad.settlement_watch.a`. If either confirms a hostile:

- Squad A becomes Aware;
- both eligible members enter initiative;
- only the player character actually detected becomes revealed to Squad A;
- unrelated Squad B remains Unaware.

## Immediate presentation contract

`TacticalScreen` refreshes body-state badges at the start of every committed tactical-state notification and explicitly after attack commits. The token therefore changes before the player can issue another contextual attack.

## Non-goals

This correction does not change the Dying formula, success/failure thresholds, death threshold, AI rescue behaviour, body carrying, Finish Off or capture rules.
