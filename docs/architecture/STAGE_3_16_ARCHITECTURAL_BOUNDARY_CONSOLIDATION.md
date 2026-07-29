# Stage 3.16 — Architectural Boundary Consolidation

## Purpose

Stage 3.16 cleans the outer architectural boundaries around the campaign item,
mission-result and tactical transaction foundations completed in Stages 3.13–3.15.
It does not redesign the existing Character Sheet or tactical inventory presentation.

## Dependency direction

```text
domain <- application <- presentation
                   ^
                   |
             infrastructure
```

`bootstrap/debug` is the composition root. It may know the application contracts,
concrete Godot infrastructure, authored sandbox resources and presentation entry
points.

## Persistence boundary

`CampaignRepository` is the application-facing port. `JsonCampaignRepository` is
the infrastructure implementation using `FileAccess`, `DirAccess`, `JSON`,
`ProjectSettings` and `user://` paths.

The JSON implementation preserves the Stage 3.15 safety behaviour:

1. serialize in memory;
2. write a temporary file;
3. reopen and validate it;
4. rotate the prior valid save to backup;
5. replace the current save;
6. verify the final file;
7. preserve damaged files and attempt backup recovery;
8. never silently overwrite an unrecoverable corrupt save.

## Content boundary

`ContentCatalogue` is now an application contract and read registry.
`GodotContentLoader` and `SandboxContentCatalogueFactory` remain infrastructure.
The catalogue is frozen after loading so runtime systems cannot mutate authored
registries accidentally.

## Mission setup and result integrity

`MissionSetupBuilder` owns setup orchestration. The domain snapshot does not call
application factories.

Mission results now validate:

- setup and result identity;
- source campaign revision;
- deployed participant coverage;
- item origin and persistent identity;
- extracted quantity, condition and modifier conservation;
- exact authorised values for generated items;
- generated-item provenance source IDs;
- legal campaign destinations;
- character extraction ownership;
- campaign item definition and location rules.

## Tactical transaction boundary

`TacticalChangeSet` now contains typed `TacticalMutationStep` and
`TacticalValidationRule` records rather than unstructured dictionaries.
`TacticalStateStore.commit()` is the shared runtime commit route.

Initial mission assembly remains explicitly separate: the deployment service may
prepare and atomically assemble initial state before the live session starts.
`RuntimeSpawnHandler` uses `TacticalStateStore.commit()` for reinforcements,
summons and other mid-mission spawns.

The former `duplicate_for_validation()` name was replaced with
`shallow_copy_for_assembly_validation()` to make its shallow-copy semantics clear.

## Presentation boundary

The tactical presentation no longer queries concrete content infrastructure or
runs movement/action rules itself. It uses:

- `TacticalScreenFacade`;
- `MovementPreviewQuery`;
- `ActionAvailabilityQuery`;
- existing inventory-transfer preview results;
- `PortraitAssetResolver` for stable portrait IDs.

The player roster is generated from the session's player-unit order instead of
fixed Marauder, Archer and Scout controls.

## Portrait persistence

Campaign saves retain stable IDs such as `portrait.hakon_rusk`. Resource paths are
resolved only at the presentation asset boundary. Legacy path-based portrait saves
are migrated on load.

## Deliberately deferred work

The following are not required for Stage 3.16 correctness and remain later work:

- decomposing `CampaignState` inheritance into composed strategic substates;
- replacing all domain display formatting with localization-ready view models;
- deriving extraction from authored extraction zones and objectives;
- typed damage/condition mutations for the upcoming combat implementation;
- splitting the largest tactical presentation scripts into smaller scene controllers.
