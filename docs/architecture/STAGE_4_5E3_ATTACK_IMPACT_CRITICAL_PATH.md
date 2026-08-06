# Stage 4.5e3 — Attack Impact Critical Path and Combat-Log Decoupling

## Problem

Stage 4.5e2 moved `damage_committed` ahead of broad `state_changed`
reconciliation, but the first visible hit-reaction frame could still wait behind:

1. whole-state body/item/invariant validation;
2. hostile-action detection snapshots that changed nothing;
3. attack and detection journal publication;
4. synchronous combat-log control rebuilding.

Because no attacker-side acknowledgement rendered when the target was clicked,
the interval appeared as dead air.

## Locked execution order

```text
valid hostile click
→ attacker command pulse starts
→ one rendered frame
→ lightweight committed-preview validation
→ attack roll and deterministic mutations
→ targeted transaction validation for ordinary hits
→ authoritative commit
→ damage impact signal
→ state-change reconciliation is queued
→ journal events are recorded
→ combat-log controls update after the impact frame
```

A body-state transition, structural cover mutation or real alert/initiative
change escalates to the full transaction-validation path.

## Transaction policy

`TacticalChangeSet` remains full-validation by default. A caller may explicitly
set:

```gdscript
changes.set_commit_validation_policy(
    synchronise_body_items,
    validate_full_state
)
```

The ordinary attack path disables both global operations only when its possible
mutations are limited to the attacker action budget/facing and target HP or
nonlethal damage. The attack-specific invariant remains mandatory.

## Detection policy

A hostile action produces no detection resolution when all of the following are
already true:

- the target squad is Aware;
- initiative combat is active;
- the attacker is already revealed to that squad;
- the squad's last-seen tile already equals the attacker's current tile.

This does not change infiltration attacks or any attack that can reveal, alert,
update Last Seen Position or alter initiative.

## Combat-log policy

The journal remains authoritative and records events during commit. Presentation
is decoupled:

- `event_added` queues the emitted event;
- the log awaits one `process_frame`;
- collapsed mode rebuilds only its three-entry tail;
- expanded mode appends only new events matching the active filter;
- changing filters or opening the panel may still perform a deliberate full
  rebuild outside the attack-impact critical path.

`recent_events()` scans the journal backwards and stops when its limit is met.

## Player input acknowledgement

A valid attack click calls `play_attack_command_pulse()` on the attacker and then
awaits one rendered frame before commitment. The pulse means only "command
accepted"; it does not communicate hit or miss. Input is locked during that
single frame to prevent duplicate attacks.

## Performance counters

F9 reports:

- command acknowledgements and rendered-frame yields;
- lightweight versus full-validation attack commits;
- redundant hostile-action resolutions skipped;
- committed-preview validation time;
- hostile-action preparation time;
- commit-start to impact-publication time;
- deferred combat-log batches and incremental expanded entries.

## Regression boundary

The patch must not alter attack calculations, Reaction legality, Stealth,
perception information security, body creation, cover destruction or alert
semantics. Full validation remains the default for every transaction that does
not explicitly select the narrow attack policy.
