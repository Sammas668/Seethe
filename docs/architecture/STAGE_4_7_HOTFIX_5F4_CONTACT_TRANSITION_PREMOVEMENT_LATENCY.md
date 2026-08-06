# Stage 4.7 Hotfix 5f4 — Contact Transition and Pre-Movement Latency

## Purpose

Hotfix 5f4 removes the long responsive-but-empty pause between an enemy detecting the player, initiative starting, the first guard receiving its activation pulse, and that guard beginning to move.

The correction does not alter animation speed, initiative order, movement costs, detection rules, attack legality, or Reaction timing. It reduces repeated authoritative work and overlaps read-only planning with the existing alert presentation.

## Corrected contact pipeline

The contact pipeline is now:

1. Detection resolves and commits revelation, last-seen memory, squad awareness, and contact initiative atomically.
2. The committed detection primes the detecting squad's deterministic perception signature.
3. The first visible AI actor is selected and pulsed as soon as the contact presentation begins.
4. A read-only planning job advances during the alert acknowledgement window.
5. The alert acknowledgement continues to block authoritative movement and attacks, but no longer blocks read-only planning.
6. At activation start, the warmed job is validated against the current state revision, geometry, actor budget, life state, squad awareness, and revealed hostile positions.
7. A valid job is reused. A stale job is discarded and the normal resumable planner takes over.
8. The first activation skips the repeated whole-squad perception refresh when the contact resolution signature remains current.

## Perception no-change rules

A perception resolution does not create a tactical transaction merely to assign values already present in authoritative state. The following are no-change cases:

- revealed to the same squad remains revealed;
- last-seen memory remains the same tile;
- an aware squad remains aware;
- a search already cancelled remains cancelled;
- a lost-sight request for an already concealed unit;
- a persistent Stealth result identical to the stored result.

Detection checks may still be journalled without creating a state transaction.

## Targeted rollback scope

Detection rollback snapshots now include only:

- the phase state;
- units directly affected by the resolution;
- squads whose awareness, search state, revelation, or last-seen memory may change;
- initiative participants whose activation markers may be lifted;
- dice state where a roll occurred.

Unrelated squads and unrelated unit action budgets are no longer copied for ordinary current-perception repair.

## Contact warmup safety

Contact warmup is read-only. It cannot:

- spend capacity;
- resolve start-of-activation effects;
- commit movement;
- resolve an attack;
- consume a Reaction;
- mutate visibility, perception, or initiative;
- publish journal events.

Authoritative commitment remains blocked until the alert cadence completes. The warmed job is reused only if its signature remains valid after start-of-activation effects, support checks, and the authoritative perception boundary.

## Presentation behaviour

The transition into initiative already performs the necessary full board and HUD refresh. The first AI activation reuses that presentation state and avoids a second complete refresh. Activation pulses are not replayed by the alert cadence runner when they were already started at contact.

## Diagnostics

Performance snapshots include:

- contact detection timestamp;
- first AI pulse timestamp;
- first movement tween timestamp;
- contact-to-pulse duration;
- pulse-to-movement duration;
- warmup processing time and frame count;
- warmup ready, reused, and invalidated counts;
- perception refreshes skipped from the contact resolution;
- no-change perception transactions avoided;
- unrelated squad and action-budget snapshots avoided;
- duplicate contact presentation refreshes avoided.

## Acceptance target

For an ordinary visible guard that detects the player and acts first:

- contact feedback appears immediately;
- the existing alert acknowledgement is used for read-only planning;
- the detecting squad does not repeat unchanged perception work;
- the guard normally begins movement in the same or next rendered frame after the alert cadence releases commitment;
- expensive fallback planning remains resumable and does not freeze the main thread.
