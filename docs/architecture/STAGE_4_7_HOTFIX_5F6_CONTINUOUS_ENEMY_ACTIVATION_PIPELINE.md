# Stage 4.7 Hotfix 5f6 — Continuous Enemy Activation Pipeline

## Purpose

Hotfix 5f5 prepared only the first player-to-enemy handoff. Later enemies still began planning after the preceding actor had completely finished, so a row of enemies felt like several separate waits. Hotfix 5f6 turns the Enemy Phase into a one-actor lookahead pipeline.

## Pipeline

After an enemy has committed its authoritative action, the next eligible AI actor is identified without changing initiative or side-based order. Its planning job runs read-only while the current actor's movement tween, damage pulse or authored cadence is being presented. At handoff, the warmed complete or partial job is validated and transferred into the normal planner.

```text
Enemy A commits
├─ Enemy A movement / damage presentation
└─ Enemy B read-only planning

Enemy A presentation completes
→ Enemy B feedback
→ Enemy B consumes warmed plan
→ Enemy B commits
```

The pipeline stops at player-controlled actors and while a Reaction continuation remains unresolved.

## Implementation boundaries

- Movement, attacks, action spending and Reactions remain atomic.
- Lookahead never crosses an intervening player initiative actor.
- Hidden actors receive no selection, pulse or unnecessary HUD/board refresh.
- Movement animation wall time is excluded from the simulation frame budget.
- Stationary actions spend remaining same-frame CPU budget on the next actor.
- Moving actions use a small per-frame overlap budget during their tween.
- Side-based Enemy Phase and initiative combat use the same warmup job.
- The dependency stamp uses focused geometry, occupancy and visibility revisions rather than rebuilding a mission-wide occupancy hash every warmup frame.

## Presentation

The previous handoff may select and pulse the next visible AI actor. The next loop iteration recognises that presentation as already prepared and does not perform a second full HUD/board rebuild. Hidden AI actors bypass identifying presentation entirely unless their committed action creates a visible consequence.

## Diagnostics

The F9 snapshot includes chain warmup processing, frames, readiness, reuse, enemy-to-enemy handoff duration, avoided duplicate refreshes, avoided hidden refreshes, avoided inter-actor frames and presentation wall time excluded from simulation budgeting.
