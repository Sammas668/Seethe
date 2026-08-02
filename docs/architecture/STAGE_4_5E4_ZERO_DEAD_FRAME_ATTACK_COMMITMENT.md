# Stage 4.5e4 — Zero-Dead-Frame Attack Commitment

## Problem

Stage 4.5e3 placed a deliberate `await get_tree().process_frame` between a
valid hostile click and `execute_attack_preview()`. The intent was to render an
attacker acknowledgement before synchronous rules work, but it guaranteed a
blank click-to-impact frame and could make the command pulse appear frozen.

A direct click could also calculate a fallback exact preview before even
starting that acknowledgement.

## Locked attack order

```text
valid hostile click
→ lock duplicate attack input
→ record click timestamp
→ start non-blocking attacker command pulse
→ reuse the primed exact preview, or calculate one fallback preview
→ commit the accepted preview immediately in the same input frame
→ publish authoritative damage impact
→ start target badge update, red pulse and vibration
→ defer broad reconciliation and combat-log presentation
```

There is no `process_frame` or timer between command acknowledgement and attack
commitment.

## Preview policy

Hovering or explicit target selection remains responsible for priming the exact
preview. A click that already owns a matching preview increments the primed
preview counter and commits it immediately.

A click without a matching preview may still request one exact fallback preview
for correctness. The command acknowledgement begins before that fallback work,
and the fallback is measured separately.

## Presentation policy

`play_attack_command_pulse()` is fire-and-forget. It never gates the attack.
The target damage reaction still begins only after authoritative damage commits.
Broad `attack_resolved` reconciliation remains deferred by one frame so it does
not compete with the first damage-reaction frame.

## Performance counters

F9 reports:

- command acknowledgements;
- legacy command frame yields, which must remain zero;
- dead pre-commit frames avoided;
- attacks using a primed preview;
- click-time exact-preview fallbacks;
- last click-to-result microseconds;
- last click-to-impact microseconds.

## Regression boundary

The correction does not weaken attack validation, alter hit calculations, move
journal work ahead of impact, or change Reaction and alert semantics. It removes
only the artificial rendered-frame boundary on player attack commitment.
