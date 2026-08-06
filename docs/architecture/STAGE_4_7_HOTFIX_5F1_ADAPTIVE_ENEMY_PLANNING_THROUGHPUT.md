# Stage 4.7 Hotfix 5f1 — Adaptive Enemy Planning Throughput

## Purpose

Correct the Hotfix 5f scheduling regression where each incomplete 3 ms planning slice forced a complete rendered-frame wait. The read-only planning jobs remain resumable, but the tactical screen now consumes as many slices as fit inside the shared Enemy Phase frame budget before yielding.

## Runtime contract

- `enemy_planning_pending` does not automatically yield a frame.
- Consecutive planning and destination-visibility slices run in the current frame while the 8 ms shared Enemy Phase budget remains.
- A completed plan is exposed through an explicit read-only plan/authoritative commit boundary.
- The completed plan commits in the same frame when budget remains, or after one safe frame boundary when the budget has been exhausted.
- Hidden actors continue through planning and commitment while the shared budget remains; there is no compulsory frame between hidden slices or hidden actors.
- Visible side-based feedback starts before the first planning slice and does not delay planning.
- Presentation deferral is not reopened for every continuation slice. It is active only for a new actor's precautionary first call, completed-plan commitment, or Reaction continuation.
- Destination-visibility preparation uses the same adaptive throughput rule.

## Authoritative boundaries

Planning and destination visibility preparation are read-only. Movement, attacks, damage, Reactions, detection changes, final positions and action-budget commitments remain atomic and deterministic.

## Diagnostics

The performance snapshot now distinguishes:

- planning processing time;
- planning wall-clock time;
- planning slice count;
- planning yield count;
- maximum slices consumed in one frame;
- hidden planning frames;
- destination-visibility yields;
- end-phase to first visible enemy feedback;
- end-phase to first visible enemy action.

## Regression guarded

The static contract rejects the former pattern where `enemy_planning_pending` immediately executed `await get_tree().process_frame` before checking the shared frame budget.
