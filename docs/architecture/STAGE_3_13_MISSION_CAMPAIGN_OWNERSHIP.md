# Stage 3.13 — Mission and Campaign Ownership

## Authoritative flow

```text
CharacterRosterState
        ↓ copied, never shared
MissionSetupSnapshot
        ↓ deployed atomically
TacticalState
        ↓ captured only when the mission resolves
MissionResult
        ↓ applied once
CampaignResultCommitService
```

## Locked implementation rules

1. `TacticalSession` does not own a `CharacterRosterRepository` and never writes campaign saves.
2. Mission characters are deep copies produced through `PersistentCharacterState.to_dictionary()` and `from_dictionary()`.
3. Tactical inventory transfers alter only `TacticalItemInstanceState.location` inside `TacticalState`.
4. `MissionResultBuilder` records survival, extraction, final equipment, acquired loot IDs, injuries and XP.
5. `CharacterRosterState.applied_result_ids` makes mission-result application idempotent across save/load.
6. `CampaignResultCommitService` rolls the roster back if its repository save fails.
7. Character deployment uses a prepared `TacticalCharacterDeploymentPlan`, validates against an isolated tactical-state copy, and commits the unit and all items together.
8. Ground items reserve IDs against every deployed loadout item. A preferred ID is deterministically suffixed when occupied.
9. Stage 3.14 replaces the temporary loadout/inbox representation with `CampaignState.items_by_id`.

## Sandbox compatibility

The clean sandbox retains the historical IDs such as `instance.ground.spear` so Stage 3.9 tests remain valid. If an old save already contains that ID in a character loadout, `MissionSetupSnapshot.unique_item_id()` assigns a collision-free mission ID instead.

## Result application semantics

- A dead persistent character is marked dead and loses items that were not extracted.
- A surviving extracted character receives final carried items at their authoritative character locations.
- XP and injuries are applied from the result record.
- Extracted unassigned loot enters stronghold storage through `CampaignState.items_by_id`.
- Reapplying the same `result_id` returns `already_applied` and changes nothing.
