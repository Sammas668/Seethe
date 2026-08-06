# Stage 4.7 Hotfix 5f10 — Hidden Auto-Pass and Empty Enemy Phase Consolidation

## Purpose

Remove the apparent freeze when the player ends the opening phase before moving or revealing any enemy.

The fault was not pathfinding. Every hidden unaware enemy still executed an individual activation-start transaction and an activation-end transaction. Each transaction emitted state-change notifications and caused broad tactical presentation reconciliation even though the player could observe none of the changed action budgets.

## Implementation

### One authoritative hidden-pass batch

`EnemyTurnHandler` now detects consecutive actors that are:

- AI-controlled Enemy Phase participants;
- completely hidden from the player;
- in an unaware squad or explicitly authored to auto-pass.

The handler refreshes and ends every compatible actor inside one lightweight `TacticalChangeSet`.

The batch:

- preserves stable activation order;
- records the ordinary start and pass journal events for every actor;
- advances the authoritative participant index for every actor;
- validates every affected action budget;
- increments the tactical revision once.

The batch stops before any actor that is visible, aware and capable of acting, or otherwise requires the normal activation pipeline.

### No invisible presentation rebuild

The tactical screen recognises `hidden_enemy_auto_pass_batch` as a budget-only hidden transaction. It does not rebuild tokens, fog, cover, contextual attacks, the board or the HUD for that intermediate change.

The normal World Phase and next Player Phase still complete authoritatively. One consolidated presentation refresh occurs when player control returns.

### Input recovery

The side-based phase flow now has an explicit player-input restoration guard. Successful completion and safe failure paths clear phase-flow locks, and board input is re-enabled whenever authoritative state has returned to Player Phase.

## Preserved behaviour

- stable enemy activation ordering;
- per-enemy journal history;
- action-budget refresh and ended state;
- Enemy Phase → World Phase → Player Phase order;
- detection, alert, movement, attacks and Reactions;
- visible or consequential actors using the normal pipeline;
- development full-state audits after lightweight transactions.

## Diagnostics

The AI snapshot reports hidden auto-pass actors, batches, transactions, total processing time and maximum batch size.

The tactical presentation snapshot reports avoided hidden-pass refreshes, empty Enemy Phase duration, End Phase-to-control-restored time and current input-lock duration.
