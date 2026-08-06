# Stage 4.3.1 — Downed, Dying and Death Foundation

## Purpose

Stage 4.3.1 establishes one authoritative tactical life-state model before
capture, restraint, extraction, and persistent casualties are added.

## State ladder

```text
HP > 0                  NORMAL
HP = 0                  DISABLED
-Con < HP < 0           DYING or STABLE_UNCONSCIOUS
HP <= -Con              DEAD
nonlethal > current HP  NONLETHAL_UNCONSCIOUS
```

`TacticalLifeStateRules` is the shared rule authority. `TacticalUnitState`
retains the mission-authoritative values that cannot be derived from HP alone:
Stable, Dead, Dying successes, Dying failures, and the round of the last Dying
check.

## Dying checks

At the start of a Dying participant's initiative turn:

```text
d20 + Fortitude vs DC 10 - current HP
```

- success: one success pip;
- failure: one failure pip;
- natural 20: two successes and 1 HP;
- natural 1: two failures;
- three successes: Stable;
- three failures: Dead;
- HP at or below negative Constitution: immediate death.

The roll, modifier, total, DC, required natural roll, track changes, and final
life state are recorded through the tactical event journal.

## Transactions

`TacticalLifeStateHandler` owns Dying checks, First Aid, and healing. Random
results use a dice checkpoint. Every mutation is staged through
`TacticalChangeSet`, restores the life-state snapshot on failure, and publishes
records only after commit.

Attack, movement, and First Aid transactions snapshot both action budget and
life state so Disabled strain is rollback-safe.

## Initiative

Dying units remain initiative participants so their checks continue and allies
receive a rescue window. Stable, nonlethally unconscious, and dead units remain
physical tactical units but do not receive ordinary activations. A natural 20
that raises a Dying unit to 0 HP allows the resulting Disabled unit to use its
limited activation.

## Presentation priority

```text
DEAD
DYING
STABLE / NONLETHAL UNCONSCIOUS
HIDDEN
AWARE
```

Body state therefore replaces an awareness eye or stealth mask on the token.
The icon textures use Seethe's colourful inked, opaque-gouache visual language,
with simplified silhouettes for token-scale readability.

## Deferred work

Capture, restraint, body dragging, finishing actions, resurrection, enemy aid
AI, and campaign injury/death persistence remain later Stage 4.3 work.
