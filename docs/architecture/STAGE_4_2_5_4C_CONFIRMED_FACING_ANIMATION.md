# Stage 4.2.5.4c — Confirmed Facing Animation

## Interaction contract

Manual facing remains a symmetrical two-click command:

1. The first right-click selects one of eight proposed facing directions.
2. Presentation immediately redraws the proposed chevron and perception cone.
3. The tactical counter remains at its committed orientation.
4. A second right-click in the same quantised direction commits the command.
5. The authoritative facing changes, 5 feet of turn capacity is spent, and the counter rotates through the shortest arc over 0.12 seconds.

A right-click in another direction changes the preview only. A left-click cancels the preview. Because preview no longer rotates the counter, cancellation does not require a return tween.

## Ownership

- `tactical_screen.gd` owns preview intent and authoritative confirmation.
- `tactical_board_view.gd` draws the proposed facing chevron and perception cone.
- `tactical_unit_view.gd` keeps the counter visually committed during preview and starts its tween only from `commit_facing_preview()`.
- The facing application handler remains the sole authority for cost and state mutation.

## Non-goals

This revision does not change perception geometry, Stealth, movement, attacks, initiative or AI. Automatic turns caused by committed movement and attacks continue to animate normally.
