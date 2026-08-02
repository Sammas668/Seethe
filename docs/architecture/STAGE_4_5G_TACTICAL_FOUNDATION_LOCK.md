# Stage 4.5g — Tactical Foundation Lock

Stage 4.5g freezes the transaction, visibility, mission-boundary and generated-item authority rules used by later authored missions.

## Explicit invalidation ownership

Every production `TacticalChangeSet` receives a `TacticalInvalidationContract` at construction. The diagnostic reason remains readable but never decides refresh behaviour. Missing contracts fail before mutation.

Locked narrow contracts:

- ordinary attack: action budget, affected tokens, combat presentation, and ammunition only when consumed;
- ordinary movement: occupancy, action budget, moved token, moved observer, and affected team;
- inventory transfer: affected items and owners only;
- pending Reaction decision: pending-decision and relevant token presentation only;
- local geometry: environment presentation, affected region/source, cover and visibility only when sight blocking genuinely changes.

## Complete rollback

`TacticalTransactionSnapshot` captures root, occupancy, blocker, knowledge and geometry revisions together with authoritative spatial signatures and pending resolution state. Rejected transactions restore the snapshot. Disposable query caches may be cleared, but no authoritative key may describe an uncommitted world change.

Randomness remains event-owned: a failed transaction may restore only the checkpoint it owns and may never rewind a previously committed Reaction.

## Mission setup identity

`MissionSetupSnapshot.finalize()` hashes deterministic canonical gameplay data with SHA-256. Identity, objectives, deployment, item manifests, policies and extraction zones are read-only after finalisation. `verify_integrity()` recalculates the hash after load and before launch, result building or campaign commit.

`MissionResult.source_setup_hash` must match the finalised setup hash.

## Trusted generated items

A generated tactical item and `TacticalGeneratedItemProvenance` enter `TacticalState` in the same transaction. The result references provenance IDs but cannot create proof for itself. At resolution lock, `MissionAuthoritySnapshot` copies the authoritative ledger and hashes it.

Campaign application receives a `MissionCommitEnvelope` containing:

1. finalised setup;
2. mission result;
3. authority snapshot.

The campaign validates item definition, quantity, condition, modifiers, mission ID and setup hash, then records each provenance ID as consumed exactly once.

## Exploration ordering

Direct commit during tactical state notification fails with `nested_tactical_commit_forbidden`. Derived exploration uses `commit_after_notifications()` and a deduplication key. Parent listeners finish before the exploration revision is published.

## Locked tactical behaviour

- Attacks of Opportunity resolve before entry.
- Overwatch and Brace resolve after entry.
- interrupted movement and player decisions live in `TacticalState`;
- safe path segments remain batched;
- ordinary attack does not rebuild geometric visibility;
- movement updates the moved observer rather than every observer;
- failed commands are true no-ops for authoritative state;
- campaign result application is one-use and setup-bound.

Changing these rules after Stage 4.5g requires an explicit design decision, updated regression tests and a release-note entry.
