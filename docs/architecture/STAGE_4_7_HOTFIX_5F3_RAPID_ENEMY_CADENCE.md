# Stage 4.7 Hotfix 5f3 — Rapid Enemy Cadence and Continuous Movement

## Purpose

Hotfix 5f2 removed the largest pre-animation latency, but ordinary visible enemy activations still felt like separate miniature cutscenes. Hotfix 5f3 shortens routine movement, removes compulsory post-activation frames, replaces per-tile easing with continuous travel, and allows harmless presentation effects to overlap the next activation.

## Presentation contract

- Visible activation feedback remains non-blocking.
- Intermediate movement steps use linear interpolation; only the final step receives a slight ease-out.
- One-, two- and three-tile enemy routes target approximately 0.05, 0.085 and 0.12 seconds.
- Ordinary visible enemy movement is capped at 0.30 seconds, with an absolute 0.36-second cap.
- A completed visible movement does not force an additional process-frame wait.
- Stationary attacks, activation pulses, damage reactions, badge transitions and combat-log animation may overlap the next actor's read-only planning.
- Reveal, alert and interruption acknowledgements are reduced to 0.20, 0.25 and 0.15 seconds respectively.
- Reaction decisions, authoritative movement, attacks, initiative transitions and mission-ending events remain serial and atomic.

## Destination visibility handoff

Destination visibility continues to advance during the movement tween. At the final tile the screen spends a bounded same-frame allowance on any remainder. A rare cold-field overrun completes in the same handoff rather than adding empty rendered frames. Diagnostics distinguish ordinary same-frame completions from overruns.

## Targeted activation feedback

The pre-planning handoff now updates only token selection, finished-state visuals and the non-blocking pulse. Full HUD and board reconciliation occurs once at the authoritative action handoff.

## Authority preserved

This patch does not change movement costs, diagonal parity, path selection, attack legality, detection, squad alert, initiative order, Reaction timing, final positions or hidden-information redaction.
