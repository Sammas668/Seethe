# Stage 4.7 Hotfix 5e — Enemy-Turn Responsiveness and Cadence Pass

## Purpose

Hotfix 5d removed presentation work for completely hidden enemy actions. Hotfix 5e addresses the remaining delay that can occur inside one enemy activation: repeated pathfinding, large ranged-position scans, accumulated visible-action cadence and whole-phase synchronous execution.

The correction does not change combat authority, movement cost, detection, Reactions, action spending, final positions or AI permissions. It changes how existing decisions are calculated, scheduled and presented.

## Presentation contract

Enemy activation and phase labels no longer own blocking handoff timers. Activation pulses remain visual feedback but run independently of AI resolution. The former move-to-attack cadence is zero; the final movement frame and immediate damage response communicate the transition.

Visible enemy movement uses a total-duration budget instead of a fixed delay for every tile:

- routes of one to three steps retain the existing readable 0.08-second step rate;
- longer routes progressively accelerate;
- ordinary AI movement is capped at 0.50 seconds;
- player movement keeps its existing timing;
- first reveal, alert transition, genuine Reaction decisions and movement interruption retain authored acknowledgement cadence.

Partially observed routes still animate only their observable segment. Completely hidden routes retain the Hotfix 5d immediate path.

## One reachable field per activation

`MovementRules.build_reachable_field()` performs one bounded Dijkstra expansion from the acting unit using its current remaining movement capacity and diagonal parity. `MovementReachableField` stores:

- cheapest movement cost by parity-aware state;
- predecessor state for route reconstruction;
- the cheapest state for each reachable tile;
- the number of pathfinding expansions.

`EnemyActionPlanner` builds one field at the beginning of an activation and uses it for melee positioning, ranged positioning, pursuit, Last Seen Position search and return-to-task movement. Candidate destinations are scored first. Only the selected destination reconstructs a route.

The selected route is carried in `EnemyActionPlan` and revalidated with `MovementRules.calculate_path_cost()` during authoritative movement commit. The handler falls back to a fresh path query only for compatibility callers that do not supply a planned route.

## Shared pathfinder correction

Ordinary A* now uses a binary min-heap with deterministic tie-breaking and lazy stale-entry rejection. It no longer scans an array to find the lowest score or to determine open-set membership. This improves player and AI route queries without changing movement legality or cost.

## Responsive Enemy Phase execution

`EnemyTurnHandler.resolve_next_enemy_activation()` resolves exactly one complete side-based actor and returns either:

- `enemy_activation_completed`;
- `reaction_pending`;
- `enemy_turn_completed`;
- or a failure result.

The existing `resolve_enemy_turn()` remains as a compatibility loop for tests and non-presentational callers.

`TacticalScreen` drives Enemy Phase actor by actor. Completely hidden cheap actors may resolve in the same frame, but the screen yields after an 8,000-microsecond simulation budget. A yield can occur only between complete authoritative activations. It never divides a transaction, movement step, attack, Reaction chain or pending decision.

The initiative AI loop uses the same safe frame budget between consecutive AI actors.

## Diagnostics

Enemy AI performance output now records:

- total simulation and presentation time;
- start effects;
- support and rescue checks;
- perception refresh;
- ability selection;
- planning;
- reachable-field construction;
- cheap candidate scoring;
- exact geometry evaluation;
- Reaction scanning;
- movement commit;
- attack commit;
- activation finish;
- unit type and AI profile;
- plan kind and target count;
- reachable tile count;
- cheap and exact candidate counts;
- pathfinding expansions;
- player visibility.

The handler retains the twelve slowest activation samples. The presentation layer adds the measured movement/presentation duration to the matching sample after visible work completes.

## Architectural boundaries

- Domain movement code owns legal path cost and route reconstruction.
- Application AI owns destination choice and authoritative activation progression.
- Presentation owns animation duration, safe frame yielding and feedback cadence.
- The UI never changes tactical state directly.
- Frame yielding is not gameplay timing and must never alter deterministic results.
- Hidden-information redaction introduced in Hotfix 5d remains authoritative.
