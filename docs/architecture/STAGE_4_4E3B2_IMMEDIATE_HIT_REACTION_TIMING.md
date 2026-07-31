# Stage 4.4e3b2 — Immediate Hit-Reaction Timing Correction

## Purpose

Remove the remaining presentation gap between a committed damaging attack and the
crimson token pulse/shake that confirms the hit.

Stage 4.4e3b deliberately added a short `AI_MOVE_TO_ATTACK` readability cadence,
but its movement handoff released deferred damage presentation only after that
cadence. The attack result, HP change and combat log were already authoritative,
yet the target remained visually still for 0.18 seconds. That made a resolved hit
feel delayed.

## Correct event order

For an attack whose damage event was held while an AI movement path animated, the
presentation order is now:

```text
movement reaches its final tile
-> release deferred damage presentation
-> refresh the target's life-state badge
-> start the non-blocking crimson pulse and local shake
-> present one rendered frame
-> apply any reveal, alert, interruption or handoff cadence
-> continue the activation flow
```

The damage reaction therefore begins before any readability wait. The existing
cadence remains useful after the impact has become readable; it no longer postpones
the impact confirmation itself.

## Runtime boundary

`TacticalScreen._complete_movement_handoff_after_frame()` now calls
`_apply_deferred_damage_events()` before its first `await` and before
`_await_presentation_cadence()`.

This preserves the original Stage 4.3.1e contract:

- committed damage is authoritative before presentation;
- life-state badges update immediately;
- `TacticalUnitView.play_damage_reaction()` is fire-and-forget;
- the reaction never blocks input, AI, initiative or state mutation;
- misses and zero applied damage still emit no damage reaction;
- repeated hits restart the existing tween from full intensity.

## Preserved behaviour

- The hit reaction duration and artwork are unchanged.
- Ordinary movement still has no fixed post-movement delay.
- The 0.18-second AI movement-to-attack cadence remains centrally tuneable, but it
  occurs after hit confirmation begins.
- Reveal, alert, interruption, phase and activation cadences remain event-driven.
- Click-locked movement, Stealth trail percentages and cover-display priority are
  unchanged.
- No domain combat, attack-roll, damage, perception or initiative rule changes.

## Acceptance criteria

1. A deferred damaging hit starts its token reaction before any cadence timer.
2. The reaction is visible on the first frame presented after movement completes.
3. The AI movement-to-attack cadence may continue while the reaction animates.
4. No second post-hit wait is introduced.
5. Non-moving attacks retain their existing immediate damage event path.
6. The reaction remains non-blocking and does not participate in combat resolution.
