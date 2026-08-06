# Stage 3.15 — Mission, Save and Tactical Transaction Integrity

## Implemented

- Moved mission setup orchestration into `MissionSetupBuilder`; the domain
  `MissionSetupSnapshot` no longer calls application services.
- Added an explicit deployed-participant manifest to mission setup data.
- Added `MissionResultValidator`, which checks the result against its original
  setup, current campaign and content catalogue.
- Added campaign revision conflict rejection before mission results can commit.
- Preserved exactly-once result behaviour by checking applied result IDs before
  the revision guard.
- Reworked campaign persistence to use a verified temporary file, backup
  rotation, corrupt-file preservation and backup recovery.
- Prevented a failed campaign load from being silently replaced by a new save.
- Added `TacticalChangeSet` and routed movement, Sprint, action spending,
  phase transitions, inventory transfers and character-modifier resolution
  through one rollback-capable commit boundary.
- Removed the obsolete tactical-to-campaign live persistence service.
- Added Stage 3.15 runtime and static validation suites.

## Compatibility

- Existing Stage 3.12–3.14 campaign JSON remains supported.
- The existing Character Sheet scene and visual layout are unchanged.
- Existing item identities, portrait data and campaign-item migration remain
  intact.
