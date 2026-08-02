# Stage 4.7 Hotfix 5f8 — Targeted Melee Pathfinding and Runtime Stall Attribution

## Purpose

Remove the remaining multi-second responsive pause between a visible melee enemy beginning its activation and producing movement or an attack. The patch changes the planning algorithm rather than presentation cadence.

## Targeted melee planning

An ordinary melee actor with a revealed hostile no longer builds the universal reachable movement field.

The planner now:

1. checks direct attacks from the current tile;
2. reserves the attack's normal-capacity cost;
3. builds the small deterministic set of legal attack-origin tiles around the target;
4. runs one resumable multi-goal A* bounded by the movement capacity remaining after the attack is reserved;
5. stops when the cheapest legal attack origin is reached;
6. reconstructs only that path.

If no attack origin can be reached this activation, the planner runs one targeted approach search toward the same goal set and retains only the path prefix affordable with the actor's full remaining movement capacity.

Ranged positioning, no-target searching and return-to-task behaviour retain the shared reachable-field planner because those behaviours genuinely compare broad sets of destinations.

## Search implementation

`MovementTargetedSearchJob` is read-only and resumable. It preserves its open set, closed set, predecessor map and cost map across planning slices and warm handoffs. The hot priority queue uses parallel typed key and priority arrays instead of allocating a Dictionary for each heap entry.

`TacticalNavigationSnapshot` captures body-dragging state once when the snapshot is constructed, preventing repeated hand-inventory scans during every neighbour expansion.

## Runtime stall attribution

When a highlighted enemy has not produced an authoritative action after 250 ms, the tactical screen records the live planning stage. Further records are emitted at 500 ms, 1 second, 2 seconds and 5 seconds.

Each record includes:

- actor ID, role and AI profile;
- highlight-to-action elapsed time;
- active planning stage;
- planning processing and wall-clock time;
- planning slices and rendered-frame yields;
- reachable-field and targeted-search counts;
- pathfinding expansions;
- targeted melee goals and reserved movement capacity;
- target and candidate counts;
- warmup readiness, reuse and invalidation reason;
- perception, ability, support and transaction timing where available.

The records are retained in the F9 performance snapshot under `enemy_runtime_stall_attribution` and are also written as warnings when a threshold is crossed.

## Preserved authority

The patch does not change:

- movement costs or alternating diagonal parity;
- difficult terrain, occupied spaces, doors or blocked corners;
- attack costs, reach or target legality;
- Reaction and Attack of Opportunity boundaries;
- perception, alert or initiative order;
- final authoritative positions.

## Acceptance contract

For a normal melee guard pursuing a revealed target:

- a direct attack performs no pathfinding;
- a move-and-attack plan builds no universal reachable field;
- the attack search is bounded to capacity after reserving the Half Action attack;
- an approach-only activation uses no more than one additional targeted search;
- a delay over 250 ms automatically identifies its current stage.
