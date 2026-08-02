# Stage 4.7 Hotfix 5f2 — End-Phase-to-First-Action Latency Pass

## Purpose

Remove the responsive but visibly empty delay between committing the player phase and the first enemy movement presentation. Hotfix 5f2 keeps resumable AI planning, one reachable field per moving activation, bounded ranged scoring, perception signatures and prepared destination visibility, but removes cold destination FOV from the pre-movement critical path.

## Corrected execution order

The side-based and initiative AI paths now use this order:

1. begin visible actor feedback without waiting;
2. run read-only planning using the actual remaining shared frame budget;
3. expose the completed plan immediately;
4. open presentation deferral only for authoritative commitment;
5. commit movement or attack in the same frame;
6. emit the movement event and start the token tween;
7. advance destination visibility while the token is moving;
8. merge the prepared field at the final movement boundary;
9. continue directly into hidden actors while the shared budget remains.

A cold centre or Peek/Lean visibility field no longer blocks `enemy_plan_ready` or movement commitment.

## Planning throughput

- The tactical screen passes the actual remaining 8 ms Enemy Phase budget to the handler and planner.
- Read-only planning never opens visibility presentation deferral.
- A completed plan commits immediately; there is no compulsory plan/commit render boundary.
- Reachable-field, ranged scan, exact geometry, approach and no-target scans are deadline-driven with high safety ceilings rather than tiny normal batch limits.
- Hidden actors continue in authoritative order and are batched while budget remains.

## Destination visibility

- `EnemyTurnHandler` owns one optional destination-visibility preparation job for the committed mover.
- The job is not included in `has_pending_enemy_planning()` and does not gate `is_enemy_plan_ready_to_commit()`.
- Visible and partially visible movement advance the job during the existing movement tween.
- Any cold-field remainder is completed before the movement deferral is released.
- Completely unobserved movement uses a larger same-frame preparation budget to avoid adding empty rendered frames before the first visible actor.
- A failed, interrupted or stale movement cancels the preparation job safely.
- Geometry revision validation remains authoritative in `TacticalVisibilityService`.

## Presentation boundaries

Planning is read-only and deferral-free. Visibility/perception presentation deferral begins only for:

- completed-plan commitment;
- Reaction continuation.

Movement, attacks, damage, Reactions, perception, alert, final positions and action capacity remain atomic and deterministic.

## Diagnostics

The performance snapshot records:

- end phase to first visible feedback;
- end phase to first visible action;
- end phase to first visible movement tween;
- frames yielded before the first visible action;
- hidden actors completed before the first visible action;
- enemy phase commit time;
- first feedback and first movement timestamps;
- planning slices, yields and maximum slices per frame;
- destination-visibility yields and preparation diagnostics.

## Non-goals

This patch does not reorder enemy actors, change AI destination scoring, alter movement costs, weaken Reaction timing, skip visible consequences, or expose hidden identities.
