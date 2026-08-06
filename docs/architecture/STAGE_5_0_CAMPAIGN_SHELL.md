# Stage 5.0 — Campaign Shell

## Completion gate

A campaign can be created, saved and loaded; the top-shell Region Map,
Stronghold, Roster and Equipment screens display authoritative campaign data;
the Farm Raid is registered through an immutable setup, launched, resolved and
committed exactly once; its Mission Summary survives reload; and permanent
protagonist death restores the last safe state without applying the lethal result.

## Runtime ownership

```text
GameApp
└── CampaignSession
    ├── ContentCatalogue
    ├── JsonCampaignRepository
    ├── CampaignStateStore
    ├── StrategicClockService
    ├── NewCampaignService
    └── CampaignMissionCoordinator
```

`CampaignSession` is the only long-lived runtime owner of the live campaign
store. Presentation issues intents. Tactical code receives only isolated mission
inputs and returns an immutable result envelope.

## Production flow

```text
Main Menu
→ Campaign Shell / Region Map
→ Mission Briefing
→ safe checkpoint
→ ActiveMissionState + finalised MissionSetupSnapshot
→ TacticalSession
→ MissionCommitEnvelope
→ CampaignResultCommitService
→ Mission Summary
→ Region Map
```

## Campaign state added at Stage 5.0

- campaign ID and seed;
- campaign status and strategic tick;
- protagonist and current region identity;
- six shared resource balances;
- campaign-owned active mission registry;
- mission instance sequence;
- latest committed result identity.

No Agent, construction, Research, Notoriety or raid state is introduced.

## Immutable mission registration

The campaign creates a unique mission instance ID independently of the authored
mission definition. Registration:

1. writes the safe checkpoint;
2. calculates the expected post-commit campaign revision;
3. creates a deterministic mission seed;
4. copies selected characters and equipment into the setup;
5. adds mission-local actors/items;
6. finalises and hashes the setup;
7. commits ActiveMissionState and the setup atomically;
8. assembles tactical play from the registered setup.

Unrelated strategic mutation is unavailable while the campaign is in tactical
play.

## Result boundary

`ResolveTacticalMissionHandler` locks tactical commands and produces a validated
`MissionCommitEnvelope`. It does not persist campaign state. The outer
`CampaignMissionCoordinator` verifies:

- envelope integrity;
- registered mission identity;
- setup hash;
- source campaign revision;
- result ID and resolved mission idempotency;
- generated-item provenance.

Only then does `CampaignResultCommitService` stage, validate, save and replace
the campaign root.

## Defeat boundary

Campaign Defeat uses the same verified setup/result envelope, but the result is
not committed. The safe checkpoint is the recovery authority. The player may
reload it or return to the Main Menu.

## Strategic shell layout

The persistent shell is top-only:

```text
[Menu / day / time] [resources] [Map Ruin Roster Gear] [Mission / Last Report]
[time controls]               [current screen title]
[                                                                        ]
[                       full-height workspace                            ]
[                                                                        ]
```

There is no left navigation rail and no bottom information strip. Contextual
site/facility panels overlay the workspace rather than shrinking it.

## Stage 5.0 screen responsibilities

- **Main Menu:** New Campaign, Load Campaign, Settings and Quit.
- **Region Map:** authored Life-realm presentation, pan/zoom, ruin/farm site
  selection and Farm Raid briefing entry.
- **Stronghold:** read-only ruin, Heart, entrance and real campaign counts.
- **Roster:** read-only persistent identity, level/XP, readiness, history and
  equipment summary.
- **Equipment:** read-only character loadouts and stronghold storage.
- **Mission Briefing:** objectives, risks/rewards, squad validation and deploy.
- **Mission Summary:** already-committed outcome, characters, objectives, loot,
  captives and campaign revision.
- **Campaign Defeat:** reload safe state or return to Main Menu.

## Safe save boundaries

Stage 5.0 saves after new campaign creation, batched strategic time changes,
mission registration, successful result commitment, leaving Mission Summary and
manual save. It never saves a partial result transaction or a permanent
protagonist-death result.
