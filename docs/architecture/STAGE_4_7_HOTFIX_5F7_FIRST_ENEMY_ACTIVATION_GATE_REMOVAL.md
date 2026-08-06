# Stage 4.7 Hotfix 5f7 — First-Enemy Activation Gate Removal

## Purpose

Remove the remaining synchronous work between an enemy becoming visibly active and its movement or attack beginning. Hotfix 5f7 preserves the continuous planning pipeline from 5f6 while making squad perception and warm-plan validation ready before presentation.

## Implementation contract

- Each resolved or primed squad perception state receives a monotonic dependency revision.
- Player-time and chain warmups resolve queued perception before planning and record that revision.
- Activation handoff validation occurs before the enemy is highlighted.
- A valid warm plan skips the ordinary activation perception refresh.
- Warm-plan dependency checks use geometry, occupancy, visibility-blocker, perception, actor and revealed-target values rather than a mission-wide item/effect string.
- Ordinary guards bypass specialist start-effect, spellcasting and support scans.
- Exceptional effects, changed perception or stale dependencies discard the forecast and use the existing responsive fallback planner.
- Side-based and initiative AI use the same prevalidation boundary.

## Authoritative safeguards

No movement, attack, Reaction, action-budget or detection state is committed during warmup. Start-of-activation effects still resolve before action commitment. Any committed start effect invalidates the forecast. Queued perception work, changed geometry, changed occupancy or changed target state also invalidates the forecast.

## Diagnostics

The performance snapshot records activation perception-gate time, warmup validation time, cold replans, perception invalidations, pre-activation validations and enemy-highlight-to-action wall time.
