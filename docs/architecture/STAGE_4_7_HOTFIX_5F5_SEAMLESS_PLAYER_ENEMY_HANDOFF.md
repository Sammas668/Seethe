# Stage 4.7 Hotfix 5f5 — Seamless Player-to-Enemy Handoff

## Purpose

Move safe, read-only enemy planning into player decision time so pressing **End Turn** does not begin a visible waiting period. The authoritative activation still starts only after turn ownership changes.

## Runtime contract

- The tactical screen spends at most 1.5 ms per idle frame warming the immediate eligible AI participant.
- Forecast planning never mutates tactical state, spends capacity, rolls dice, attacks, moves or opens a Reaction.
- Forecast jobs carry projected capacity and diagonal parity for the upcoming activation.
- The plan is validated against unit, target, occupancy, geometry, equipment, condition, awareness and perception dependencies before reuse.
- An End Turn transaction that changes only the outgoing player's activation marker does not invalidate a valid warm plan.
- Start-of-activation effects and AI ability selection still resolve before the warmed plan is consumed. Any relevant change invalidates the plan and falls back to ordinary resumable planning.
- Player input locks immediately; visible enemy feedback and the initiative AI coordinator start in the same input frame.
- The state-change callback suppresses duplicate board rebuilds and duplicate AI scheduling while the explicit handoff coordinator owns the transition.

## Side-based play

During the player phase, the first meaningful actor in stable Enemy Phase order is warmed. Defeated, incapacitated, unaware and automatic-pass participants remain on the authoritative order but do not consume forecast planning work.

## Initiative play

Only the immediate eligible AI participant after the active player is warmed. If another player-controlled participant acts next, no enemy plan is prepared. Round-wrap forecasting uses the actor's refreshed maximum capacity and zero diagonal parity.

## Invalidations

A warmed plan is discarded when any relevant dependency changes, including actor or target position, life state, geometry, occupancy, awareness, revelation, timed effects, modifiers or owned equipment. The existing frame-budgeted planner then resumes without freezing the main thread.

## Diagnostics

The performance snapshot reports warmup processing time, idle frames, plan readiness, reuse and invalidation counts, invalidation reason, handoff-to-feedback time, handoff-to-authoritative-commit time, handoff-to-movement time, avoided full refreshes and avoided duplicate AI schedules.
