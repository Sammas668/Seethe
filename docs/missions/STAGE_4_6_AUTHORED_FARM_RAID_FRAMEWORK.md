# Stage 4.6 — Authored Farm Raid Framework

Stage 4.6 replaces direct sandbox startup with the first reusable authored mission path.

## Runtime flow

```text
MissionDefinition registry
→ DebugMissionSelector
→ MissionSetupSnapshot finalisation
→ AuthoredMissionFactory
→ TacticalState with MissionRuntimeState
→ committed tactical events
→ MissionObjectiveService reconciliation
→ extraction manifest
→ MissionAuthoritySnapshot and MissionResult
→ immutable mission summary
```

## Authored mission content

`life_farm_storehouse_raid_01.tres` owns mission identity, briefing, selected test force, NPC placements, physical loot, objective definitions and preview profiles. `life_farm_storehouse_map_01.tres` owns the 40×40 map, static open storehouse entrance, deployment and extraction zones, patrol paths, recoverable-prop anchors, reinforcement anchor, civilian work anchor and daylight placeholder.

The first mission deliberately remains single-floor. Doors, destructive entry routes and hazards are Stage 4.8 work.

## Objectives

The primary objective is `EXTRACT_ITEMS` for two items tagged `mission_supply`. The mission contains three qualifying supply objects so one can be lost without making the mission immediately impossible.

Optional objectives are:

- extract a living, restrained settlement guard;
- extract intact furniture;
- avoid civilian deaths;
- reach extraction before the end of round eight.

Objective progress is derived from authoritative tactical state. Presentation never marks an objective complete directly. Objective changes use an explicit `mission_state` invalidation contract and derived reconciliations are queued after current state notifications.

## Setup and result integrity

The finalised setup hash includes the authored mission definition ID, tactical map definition ID and isolated objective definitions. The result copies the exact setup hash and records objective outcome dictionaries, Notoriety preview lines and important event IDs. Generated-item authority remains owned by tactical provenance records rather than the result.

## Current limits

- Squad placement uses authored starting positions selected through the briefing flow; free placement inside the deployment zone is deferred.
- Reinforcements are a visible deadline objective only; forces do not spawn yet.
- XP and Notoriety are preview records and are not applied to a strategic region.
- Final protagonist and enemy content is Stage 4.7.
- Functional doors, recoverable-world breadth, structure destruction and hazards are Stage 4.8.
