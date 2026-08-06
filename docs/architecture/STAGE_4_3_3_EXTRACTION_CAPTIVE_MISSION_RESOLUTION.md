# Stage 4.3.3 — Extraction, Captive Recovery and Mission Resolution

## Status

Implemented for the farm/storehouse tactical vertical slice.

## Goal

Stage 4.3.3 closes the first complete tactical mission loop:

```text
Deploy
→ infiltrate
→ fight or secure the objective
→ recover allies, bodies, captives and loot
→ physically reach extraction
→ preview and confirm the result
→ build one MissionResult
→ commit campaign consequences exactly once
→ show the committed summary
```

The implementation extends the existing mission setup/result and campaign commit
architecture. It does not create a second tactical-to-campaign mutation route.

## Ownership boundaries

### Authored content

`TacticalMapDefinition` owns:

- mission display name;
- required and optional objective IDs/text;
- primary objective tiles;
- extraction-zone definitions and authored tile coordinates;
- withdrawal and protagonist-extraction requirements.

The vertical-slice content is authored in:

`content/missions/farm_storehouse/movement_test_map.tres`

### Tactical runtime state

`TacticalState` owns only mutable mission runtime values:

- enabled/contested extraction-zone state;
- the mission-resolution lock;
- the resolved tactical result ID.

### Query layer

`TacticalExtractionManifestQuery` derives the proposed result from authoritative
state. It does not mutate tactical or campaign data.

`TacticalMissionObjectiveQuery` derives objective completion, area-secured state and
whether a player-controlled unit can still continue.

### Application layer

`ResolveTacticalMissionHandler` owns the resolution transaction:

1. rebuild the manifest;
2. classify Victory, Withdrawal, Tactical Defeat or Campaign Defeat;
3. build and validate the `MissionResult`;
4. lock tactical commands;
5. send the result through `CampaignResultCommitService` exactly once;
6. publish the committed result to presentation.

### Campaign layer

`CampaignResultCommitService` remains the only tactical-to-campaign mutation point.
It applies a candidate `CampaignState`, validates it, persists it, and only then
replaces the active root.

### Presentation

`TacticalMissionResolutionWindow` renders confirmation and summary data. It never
moves items, changes objectives, creates captives, injures characters or commits the
campaign.

## Physical extraction contract

### Conscious allies

A conscious friendly extracts only when its complete footprint is inside the enabled
zone.

### Bodies

A body extracts when its one real body item is:

- on ground inside the zone;
- being dragged with its actual dragged ground cell inside the zone; or
- packed inside the inventory of an extracted friendly character or an already
  extracted nested body.

A dragger inside the zone does not extract a body whose dragged cell remains outside.

### Captives

An enemy becomes a campaign captive only when all are true:

- alive;
- `Restrained` and `Captive` in tactical state;
- represented by an extracted body item;
- the same real restraint item remains attached and extracted.

Unconscious but unrestrained enemies and dead enemies never become living captives.

### Items

Persistent item recovery follows authoritative location:

- equipment/inventory of an extracted friendly;
- equipment/inventory/attachment of an extracted body or captive;
- tactical ground/container tile inside the zone.

Everything else is explicitly abandoned. There is no automatic whole-map victory
loot collection.

## Outcome rules

### Victory

- required objective complete;
- extraction legal;
- protagonist extracted when required;
- player confirms completion.

### Withdrawal

- required objective incomplete;
- mission permits withdrawal;
- protagonist extracted when required;
- player confirms withdrawal.

### Tactical Defeat

No conscious player-controlled unit can continue. A wiped force receives no
unexplained automatic rescue: bodies and loot merely lying in extraction are moved to
the unrecovered side of the result.

### Campaign Defeat

The protagonist is actually Dead. This locks tactical play and displays the campaign
defeat summary but deliberately does not overwrite the last safe campaign state.

## Mission result additions

`MissionResult` now records:

- explicit mission outcome;
- completed, failed and optional objectives;
- extraction-zone ID and protagonist extraction;
- per-character extraction/death/injury/missing outcomes;
- extracted and abandoned item identities;
- living captive results;
- summary event IDs;
- non-negative mission statistics.

`MissionCharacterResult` distinguishes ready, wounded, critical, recovered dead,
unrecovered dead, alive unrecovered, captured enemy and temporary-unit removal.

`MissionCaptiveResult` preserves identity, template, HP, life state, body,
restraint, faction and equipment still retained at extraction.

## Captive persistence

`CampaignState.captives_by_id` stores minimal `CampaignCaptiveState` records in
`stronghold.temporary_holding`.

This stage does not recruit, interrogate, ransom or sacrifice captives. Later systems
must consume this same authoritative record rather than recreating captured enemies.

## Idempotency and atomicity

The commit sequence is:

```text
confirm
→ rebuild manifest
→ build/validate MissionResult
→ lock tactical commands
→ validate candidate campaign
→ save candidate
→ replace campaign root
→ record mission and result IDs
→ display summary
```

Repeated application of the same result or mission is an idempotent success with no
revision advance and no duplicate character, item or captive.

If campaign validation or persistence fails, the tactical resolution lock is released
through a second tactical transaction and no campaign mutation survives.

## Presentation rules

- Extraction overlays are visible from mission start.
- Entering extraction never ends a turn or removes an entity.
- The HUD button opens a preview; it does not directly resolve the mission.
- Confirmation intentionally blocks board input.
- Cancelling restores tactical input.
- Successful commit opens a summary that reflects the committed campaign state.
- Continue does not reapply the result.
- Hit reactions and inventory animations never delay resolution.
- No initiative AI activation begins after the tactical resolution lock.

## Runtime tests

`tests/tactical/stage_4_3_3_extraction_mission_tests.gd` covers:

- authored zone loading and initial Withdrawal;
- carried-body extraction;
- dragged-body physical-position enforcement;
- living restrained captive recovery;
- no automatic rescue on Tactical Defeat;
- Victory result creation and idempotent campaign commit;
- Campaign Defeat preserving the safe campaign.

Run with:

`res://tests/tactical/run_stage_4_3_3_tests.gd`

## Deferred

- region-map navigation after Continue;
- multiple selectable extraction routes;
- evacuation countdowns and extraction-triggered reinforcements;
- walking cooperative captives;
- enemy extraction of player captives;
- prisoner processing and rescue missions;
- Notoriety and XP presentation;
- advanced recovery treatment;
- mid-mission save UI and full tactical-state serializer.
