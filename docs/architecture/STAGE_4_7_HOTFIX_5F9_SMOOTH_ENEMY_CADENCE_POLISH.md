# Stage 4.7 Hotfix 5f9 — Smooth Enemy Cadence Polish

## Purpose

Hotfix 5f8 removed the multi-second melee-planning stall. Hotfix 5f9 preserves that performance correction while tuning the now-fast Enemy Phase into a readable continuous sequence.

The patch has two goals:

1. remove the remaining blocking contact acknowledgement from the first-action critical path; and
2. restore a small amount of visual weight only where the preceding action supplied no useful movement presentation.

It does not reintroduce broad pathfinding, fixed inter-actor delays, or presentation work that can hide a real performance regression.

## Contact transition

The authored alert flash remains visible for 0.25 seconds, but authoritative AI commitment is blocked for no more than 0.06 seconds. Read-only contact warmup continues during this lead. The flash may finish while the first enemy action is already being presented.

Reaction prompts, mission-ending events and explicitly authored scripted sequences remain blocking when required.

## Typed warm-plan validation

`EnemyPlanDependencyStamp` replaces the remaining joined-string validation on the handoff critical path. It captures typed revision and actor/target fields while a plan is prepared:

- geometry revision;
- occupancy revision;
- visibility-blocker revision;
- squad perception revision;
- actor position, task, profile, capacity and life state;
- squad awareness and search state;
- revealed target positions and combat state.

At handoff, the plan is validated through direct comparisons. The legacy string-signature functions remain only for older development tests and do not run on the ordinary handoff path.

## Visible movement curve

Enemy movement remains continuous and linear between intermediate tiles, with only the final step settling slightly.

Working presentation values:

- one tile: 0.060 seconds;
- two tiles: 0.105 seconds;
- three tiles: 0.150 seconds;
- ordinary route cap: 0.34 seconds;
- absolute route cap: 0.40 seconds.

Partially observed paths animate only their visible segment. Dragged bodies remain synchronised with the carrier.

## Adaptive visible handoff

No universal enemy-to-enemy timer is added.

A 0.07-second readable handoff is used only when:

- both the completed and next activations are observable; and
- the completed action was stationary or its visible movement lasted under 0.10 seconds.

Movement lasting at least 0.10 seconds supplies its own cadence and receives no extra handoff. Hidden actors receive no spacing. The next actor's pulse and planning may begin during the micro-handoff, and harmless cosmetic effects may overlap.

## Diagnostics

The F9 performance snapshot retains Hotfix 5f8 stall attribution and adds `enemy_cadence_polish`:

- `blocking_alert_acknowledgement_usec`;
- `adaptive_visible_handoff_usec`;
- `adaptive_visible_handoff_count`;
- `last_visible_movement_duration_seconds`.

These values distinguish intentional presentation time from planning or transaction stalls.

## Authoritative boundaries preserved

Hotfix 5f9 does not change:

- initiative or side-based actor order;
- AI target selection or path selection;
- movement costs and diagonal parity;
- detection, revelation or alert;
- attacks, damage or life-state transitions;
- Reaction and Attack of Opportunity timing;
- hidden-identity and combat-log redaction;
- final authoritative positions.

## Acceptance targets

- First visible contact action begins while the alert flash remains active.
- Blocking alert lead is at most 0.06 seconds in the ordinary path.
- One-to-three-tile movement remains brisk but readable.
- Movement of at least 0.10 seconds adds no inter-actor timer.
- Stationary and near-instant visible actions receive approximately 0.07 seconds of readable handoff.
- Hidden actors receive no added cadence.
- Hotfix 5f8 automatic stall attribution remains active.
