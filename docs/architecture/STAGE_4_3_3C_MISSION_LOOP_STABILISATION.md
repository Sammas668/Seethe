# Stage 4.3.3c — Mission-Loop Stabilisation

## Status

Implemented consolidation milestone following Stage 4.3.3b.

This stage does not add a new tactical verb. It hardens the complete mission loop before directional cover, line of effect and openings are introduced.

## Player loop protected by this stage

```text
Deploy
→ infiltrate
→ fight
→ incapacitate or kill enemies
→ restrain captives
→ loot and recover bodies
→ move characters, bodies, captives and items into extraction
→ preview Victory or Withdrawal
→ confirm once
→ commit one MissionResult
→ reload the campaign without duplication
→ view the committed summary
```

## Manifest integrity boundary

`TacticalExtractionManifestValidator` now validates the complete derived manifest before mission resolution may continue.

It checks that:

- every active friendly or friendly body has exactly one extracted or abandoned outcome;
- every non-body tactical item has exactly one extracted or abandoned outcome;
- extracted and abandoned lists never overlap;
- conscious, unrestrained enemies cannot be recovered;
- only living, Restrained characters marked Captive can become captive results;
- every captive has a physically recovered body item;
- Tactical Defeat and Campaign Defeat recover no characters, bodies, captives or property;
- the manifest belongs to the current tactical revision.

This validator operates on the derived manifest and authoritative `TacticalState`. It does not own state and does not mutate either object.

## Revision-bound extraction previews

Every extraction preview records:

```gdscript
manifest.source_tactical_revision
```

The confirmation window carries that revision back with the player’s confirmation. `ResolveTacticalMissionHandler` rejects the request with `extraction_preview_stale` if any tactical transaction committed after the preview was produced.

The confirmation UI also rebuilds itself from authoritative state whenever a tactical state-change signal arrives while the confirmation is open. This means item transfers, Untie, healing, restraint changes, body movement or objective changes cannot leave the visible manifest silently stale.

Confirmation still rebuilds and validates the manifest again. The UI preview is never trusted as the mission result.

## Persistence regression boundary

`TacticalSandboxFactory.create_session()` now accepts an optional campaign save path. This allows the end-to-end test to use an isolated JSON save without touching the player’s normal campaign file.

The automated regression test performs:

```text
create isolated campaign save
→ start Raid the Storehouse
→ down one guard
→ restrain that guard
→ Search the guard and drop equipment in extraction
→ leave the second guard active
→ preview Withdrawal
→ verify the pre-resolution campaign save is unresolved
→ confirm Withdrawal
→ reload campaign JSON
→ verify mission history, captive, items and character progression
→ reapply the same MissionResult
→ verify idempotent no-change
```

This verifies the campaign persistence boundary around extraction. It does not introduce a general mid-mission tactical save UI or a complete tactical-state serializer.

## Transport and recovery regression coverage

The Stage 4.3.3c runtime suite additionally verifies:

- a friendly body in another character’s Backpack becomes an extracted critical casualty;
- a body in a Hand counts from its actual dragged ground cell;
- unconscious but unrestrained enemies are recovered bodies, not Captives;
- dead enemies remain corpse recovery, not Captives;
- restrained living enemies become Captives;
- Tactical Defeat produces no extracted item entries or captive results;
- the authored map, deployed units, extraction registry, player visibility and ground-body token rule remain intact.

## Transaction order remains unchanged

```text
Player confirms the revision-bound preview
→ current tactical revision is checked
→ manifest is rebuilt from authoritative state
→ manifest integrity is validated
→ immutable MissionResult is built
→ MissionResult is validated against setup and campaign
→ TacticalState locks resolution
→ CampaignResultCommitService commits one atomic CampaignChangeSet
→ repository saves the candidate campaign
→ resolved mission/result IDs prevent reapplication
→ committed summary is shown
```

No animation, hit reaction or UI transition participates in this transaction.

## Files introduced

```text
application/tactical/extraction/
    tactical_extraction_manifest_validator.gd

tests/tactical/
    stage_4_3_3c_mission_loop_stabilisation_tests.gd
    run_stage_4_3_3c_tests.gd

tests/static/
    validate_stage_4_3_3c.py
```

## Files materially updated

```text
domain/tactical/extraction/tactical_extraction_manifest.gd
application/tactical/extraction/tactical_extraction_manifest_query.gd
application/tactical/extraction/resolve_tactical_mission_handler.gd
application/tactical/facades/tactical_screen_facade.gd
presentation/tactical/missions/tactical_mission_resolution_window.gd
presentation/tactical/tactical_screen.gd
bootstrap/debug/tactical_sandbox_factory.gd
README_FIRST.txt
SEETHE_PROJECT_STRUCTURE_GUIDE_V2.md
```

## Deferred work

Stage 4.3.3c deliberately does not add:

- full mid-mission tactical save/load;
- campaign-layer mission selection or return navigation;
- prisoner management;
- XP presentation and levelling UI;
- advanced injuries;
- Notoriety;
- automatic victory loot collection;
- cover, line of effect, doors or breaching.

The next major milestone is Stage 4.4a — Directional Cover and Line of Effect.
