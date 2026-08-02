# Stage 4.7 Hotfix 5f — Enemy Movement Pipeline and Cadence Deep Optimisation

## Purpose

Hotfix 5f removes the remaining long pauses surrounding enemy movement without changing tactical rules. It targets synchronous read-only planning, repeated perception work, destination visibility cache misses and broad validation around small transactions.

The authoritative boundaries remain unchanged: movement, capacity spending, attacks, damage, detection, alert, initiative and Reactions still commit atomically through the existing tactical transaction architecture.

## Planning pipeline

Visible and hidden enemy activations now use a resumable `EnemyActivationPlanningJob`.

The job proceeds through deterministic stages:

1. target discovery;
2. direct attack checks from the current tile;
3. incremental reachable-field construction only when movement is required;
4. target and destination scoring;
5. bounded ranged shortlist evaluation;
6. exact geometry for the final shortlist;
7. destination visibility preparation;
8. completed immutable plan.

Read-only work runs in short processing slices. No tactical state mutates until the plan is complete. The compatibility `plan_activation()` entry point can still run the same job synchronously for tests and non-presentational callers.

## Stationary attacks

Direct legal attacks are tested before pathfinding. A unit that can attack from its current position returns a stationary plan and records zero reachable-field builds and expansions.

## Reachable movement field

Movement-requiring activations create one `MovementReachableFieldJob`. It stores cheapest costs, predecessor state and diagonal parity using a deterministic binary heap. The selected route is reconstructed only after destination choice.

Melee, ranged, search and return-to-task planning reuse the same field.

## Ranged scoring

Ranged planning rejects out-of-range tiles before line-of-sight and cover work. It retains only a deterministic bounded shortlist rather than allocating and sorting every plausible destination. Exact combat geometry is performed only for shortlisted candidates.

## Visibility preparation

The selected AI destination receives an actual prepared visibility field through `TacticalVisibilityPreparationJob`. Missing component fields are calculated during read-only planning rather than after the movement tween reaches its destination.

Prepared results include the geometry revision. A changed geometry revision invalidates the job safely.

## Perception ownership

Authoritative AI perception no longer waits behind player-facing fog presentation. Before planning, the detection service can refresh the acting squad immediately.

A deterministic perception signature includes relevant squad awareness, observer state, hostile state and geometry revision. Unchanged signatures skip repeated observer-target work. Post-movement requests remain coalesced through the existing detection service.

## Presentation cadence

The tactical screen peeks the next side-based enemy participant before resolution. A visible enemy is selected and receives its non-blocking activation pulse before planning begins. Hidden actors remain unidentified.

When planning returns `enemy_planning_pending`, the screen yields a real process frame and resumes the same job. The pulse is not restarted on every slice.

Dragged-body presentation uses the carrier's accelerated movement duration so a secondary tween cannot silently extend the handoff.

## Transaction safeguards

Simple action-budget-only transactions use targeted validation and lightweight transaction snapshots. Spatial movement, combat, detection, alert, life-state and Reaction boundaries retain stronger validation.

Development builds periodically run a full-state audit after lightweight commits. Full snapshots calculate the occupancy signature once and reuse it when deriving the visibility-blocker signature.

## Diagnostics

Performance snapshots expose planning slices, direct attack checks, reachable-field builds and expansions, candidate counts, shortlist counts, exact geometry, destination visibility preparation, perception refresh and skip counts, observer-target pairs, transaction snapshot and validation timing, movement presentation and total activation timing.

The slow-activation history remains available through the tactical performance diagnostics.

## Behaviour preserved

Hotfix 5f does not alter:

- movement costs or diagonal rules;
- difficult terrain and occupancy;
- AI difficulty, attack accuracy or damage;
- Attack of Opportunity and Overwatch timing;
- Reaction interruption and continuation;
- squad-limited alert and initiative order;
- hidden-information redaction;
- final authoritative positions.
