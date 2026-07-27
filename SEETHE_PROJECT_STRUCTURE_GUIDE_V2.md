# SEETHE GODOT PROJECT STRUCTURE GUIDE — VERSION 2

This archive is the corrected and simplified starting architecture for **Seethe**.

It keeps the strongest parts of the original design:

- one authoritative campaign state;
- immutable authored definitions;
- atomic strategic commands;
- a hard boundary between campaign and tactical play;
- stable content IDs;
- deterministic random streams;
- versioned saves and migrations;
- very limited autoloads;
- UI that sends commands rather than mutating game state;
- tests focused on state ownership and save safety.

It also corrects the weaknesses identified during review:

- `app/` has been renamed to `bootstrap/`;
- the dependency model has been rewritten clearly;
- the physical folder tree is much smaller;
- archetype content has one canonical home;
- inventory reservations are not item locations;
- Notoriety is owned by the strategic region layer;
- timed progress belongs to one shared project framework;
- captives reference persistent characters instead of duplicating them;
- recruitable troops are treated as persistent characters;
- screens begin with one script and one view model, not mandatory presenter/controller layers;
- shared requirement/effect systems are introduced only when genuinely needed;
- a working boot scene and `.gitignore` are included.

The complete future architecture still exists as a documented direction, but folders should be created only when a real feature needs them.

---

# 1. First use

1. Extract the project folder.
2. Import `project.godot` into Godot.
3. Run the project once.
4. Confirm the output prints:

```text
Seethe architecture starter v2 loaded.
```

5. Read this guide before creating gameplay files.
6. Commit the clean starter to Git.
7. Build only the current milestone.

The physical folder tree is deliberately lean. Do not recreate hundreds of empty directories simply because a future system may eventually exist.

---

# 2. The dependency model

The authoritative source-code dependencies are:

```text
domain        → core
application   → domain + core
presentation  → application + read-only view models
infrastructure→ interfaces required by application/domain
bootstrap     → all layers, only for composition and startup
```

A practical map:

```text
                         bootstrap
                  creates and wires sessions
                    /       |       \
                   v        v        v

presentation  →  application  →  domain  →  core
                      ↑
                      │
              infrastructure

content uses domain definition classes
assets are consumed by presentation and authored content
```

## Hard dependency rules

### `domain/` may depend on

- `core/`

### `domain/` must never depend on

- `application/`
- `presentation/`
- `infrastructure/`
- `bootstrap/`
- Godot UI scenes
- visual Nodes
- save-file APIs
- autoload singletons

### `application/` may depend on

- `domain/`
- `core/`
- inward-facing interfaces

### `application/` must not depend on

- concrete screens
- tactical actor Nodes
- artwork
- sound
- scene-tree paths

### `presentation/` may depend on

- application commands
- application queries
- read-only view models
- presentation assets

### `presentation/` must not

- deduct resources directly;
- move campaign items directly;
- complete Research directly;
- change Notoriety directly;
- apply a mission result directly;
- alter persistent character state directly.

### `infrastructure/`

Infrastructure supplies concrete implementations for:

- save/load;
- content loading;
- file-system access;
- logging;
- build/platform integration.

Infrastructure does not own game rules.

### `bootstrap/`

Bootstrap is the only layer allowed to know about every other layer. It creates sessions and injects dependencies. It must not become a dumping ground for gameplay logic.

---

# 3. Root folders

## `bootstrap/`

Contains startup and dependency composition.

### `bootstrap/boot/`

Place:

- boot scene;
- boot script;
- dependency composition;
- campaign-session creation;
- tactical-session creation;
- transition data between campaign and tactical modes.

The included `boot.tscn` is the project main scene.

### `bootstrap/autoload/`

Keep autoloads rare.

Recommended maximum initial set:

- `game_app.gd`
- `scene_router.gd`
- `settings_manager.gd`
- `audio_manager.gd`

Do not autoload:

- campaign state;
- inventory;
- roster;
- stronghold;
- Research;
- production;
- Notoriety;
- tactical combat.

Those belong to the active campaign or tactical session.

### `bootstrap/config/`

Place:

- build configuration;
- debug flags;
- shared non-balance constants;
- default settings Resources.

Do not place weapon damage, class progression or facility costs here. Those belong in authored content definitions.

---

## `core/`

Contains reusable low-level types that are not specific to one game feature.

### `core/ids/`

Place:

- stable content-ID validation;
- generated runtime entity IDs;
- typed ID helpers.

Authored IDs should be stable and readable:

```text
class.barbarian
archetype.reaver
facility.generic.storehouse
region.ilyra.starter
item.weapon.spear.common
mission.raid.farm_storehouse
```

Runtime instances use generated IDs:

```text
character:<generated_id>
item:<generated_id>
facility:<generated_id>
project:<generated_id>
mission:<generated_id>
```

Never use a file path as a persistent content ID.

### `core/results/`

Place structured success, failure and validation results here.

A failed operation should return explicit errors and make no state changes.

### `core/changes/`

Place the atomic strategic change-set model here.

A `ChangeSet` may contain:

- expected campaign revision;
- records to create;
- records to update;
- records to remove;
- resource deltas;
- inventory transfers;
- reservation changes;
- post-commit events.

The state store validates and commits the complete change once.

### `core/events/`

Place generic event infrastructure here.

Events notify systems after a successful commit. Events must not replace the transaction that created them.

### `core/random/`

Place deterministic RNG streams here.

Recommended named streams:

```text
campaign
mission_generation
loot
character_names
enemy_force
tactical_combat
tactical_ai
base_assembly
story_events
```

A mission must record its seed and generation inputs.

### `core/serialisation/`

Place dictionary conversion, version-safe parsing and type registration here.

Never save:

- Nodes;
- live Resource instances;
- signal connections;
- object instance IDs;
- UI selection;
- scene-tree paths.

### `core/grid/`

Place square-grid and hex-grid mathematics here.

### `core/diagnostics/`

Place invariants, assertions, state dumps and performance timers here.

---

# 4. Domain ownership

The domain records game truth.

A domain feature may later be expanded into:

```text
feature/
├── definitions/
├── state/
├── rules/
└── enums/
```

Do not create those subfolders until the feature has enough files to justify them.

---

## `domain/campaign/`

Contains the authoritative campaign root.

Recommended high-level shape:

```text
CampaignState
├── schema_version
├── content_version
├── revision
├── campaign_id
├── campaign_tick
├── difficulty_id
├── rng_state
├── world_state
├── stronghold_state
├── facilities_by_id
├── projects_by_id
├── characters_by_id
├── items_by_id
├── reservations_by_id
├── captives_by_character_id
├── research_state
├── resources_by_id
├── resolved_mission_ids
├── story_flags
└── history
```

All mutable campaign records are ultimately owned by this root.

Derived indexes are rebuilt after loading. Do not save a second authoritative copy of derived data.

Examples of derived indexes:

- items by location;
- facilities by definition;
- characters by readiness;
- projects by queue;
- agents by region;
- occupied plots derived from facility footprints.

---

## `domain/strategic/`

Contains the regional campaign map.

Place here:

- region definitions;
- authored hexes and routes;
- sites;
- agents;
- opportunities;
- incoming operations;
- region-state rules;
- time interruption rules.

### `domain/strategic/notoriety/`

Notoriety is owned by the region layer.

The system is deliberately small:

```text
RegionalNotorietyState
├── region_id
└── value_0_to_100
```

Mission resolution produces:

```text
NotorietyReport
├── region_id
├── lines
├── total_delta
├── old_value
└── new_value
```

At 100, the strategic system creates one incoming raid operation. Resolving that operation applies the authored reduction.

Do not create:

- Exposure;
- hidden regional strength;
- hidden discovery score;
- a second retaliation meter.

---

## `domain/stronghold/`

Contains the fixed Fifth-God ruin, plots, facilities and defence layout.

Place here:

- stronghold definitions;
- plot definitions;
- facility definitions;
- facility instances;
- restoration state;
- facility placement and connectivity;
- facility operation;
- damage state;
- base-defence module references.

Facility occupancy is derived from:

```text
facility definition footprint
+ facility origin
+ facility orientation
```

Do not independently save both the facility footprint and a second plot-occupancy authority.

---

## `domain/projects/`

Owns all timed progress and queue state.

Use the shared framework for:

- restoration;
- construction;
- repair;
- recruitment;
- Research;
- production;
- dismantling;
- interrogation where time is required.

Recommended shared state:

```text
TimedProjectState
├── project_id
├── project_definition_id
├── project_kind
├── queue_id
├── target_reference
├── start_tick
├── completion_tick
├── status
├── committed_input_ids
└── project_specific_state_id
```

Do not duplicate progress fields across:

- Research state;
- manufacturing orders;
- construction state;
- recruitment state.

Permanent Research knowledge belongs to Research state after completion. Active Research time belongs to `TimedProjectState`.

Use typed project-specific records rather than an unrestricted `Dictionary` payload.

---

## `domain/characters/`

Owns persistent character identity and condition.

Every recruitable troop is a persistent character.

A character record may include:

- name;
- definition ID;
- level and XP;
- class ranks;
- archetype choices;
- equipment references;
- injuries;
- readiness;
- assignment;
- history;
- permanent death.

Troop Tier belongs to the authored troop type. Troop Level belongs to one individual recruit. Levelling never changes a recruit into another troop type.

Temporary mission-created units do not enter the roster unless an explicit conversion succeeds.

---

## `domain/inventory/`

Owns persistent items, item locations and reservations.

### Item location

Each persistent item has exactly one authoritative location.

Valid location categories may include:

```text
STRONGHOLD_STORAGE
ITEM_CONTAINER
CHARACTER_EQUIPPED
CHARACTER_CARRIED
FACILITY_INSTALLATION
MISSION_GROUND
MISSION_CONTAINER
TRANSIT
ENEMY_HOLDING
DESTROYED
```

### Reservation

A reservation is not a location.

A bed reserved for construction remains in stronghold storage. The reservation merely prevents incompatible use.

Recommended reservation state:

```text
InventoryReservationState
├── reservation_id
├── item_id
├── quantity
├── purpose
├── requesting_operation_id
└── status
```

The following must always remain true:

- one item has one location;
- reserved quantity never exceeds available quantity;
- reserving an item does not move it;
- consuming an item closes the reservation in the same atomic commit;
- cancelling a pre-commit plan releases the reservation without changing location.

---

## `domain/missions/`

Owns the formal strategic/tactical boundary.

### Campaign to tactical

```text
CampaignState
    ↓
MissionSetupBuilder
    ↓
Immutable MissionSetupSnapshot
    ↓
TacticalState
```

### Tactical to campaign

```text
TacticalState
    ↓
MissionResult
    ↓
ResolveMissionCommand
    ↓
One atomic campaign ChangeSet
```

A mission result must never be applied twice.

The campaign should track resolved mission IDs.

---

## `domain/tactical/`

Contains tactical truth and pure tactical rules.

Recommended tactical state:

```text
TacticalState
├── mission_id
├── mission_seed
├── round_number
├── phase
├── active_unit_id
├── initiative_order
├── units_by_id
├── items_by_id
├── structures_by_id
├── objectives_by_id
├── tile_states
├── alert_groups
├── reinforcements
└── event_ledger
```

Tactical Nodes only display this state.

Tactical commands may include:

- move;
- attack;
- use ability;
- interact;
- overwatch;
- end turn;
- end phase.

Tactical events may include:

- movement;
- attack;
- damage;
- reaction;
- detection;
- alert;
- status;
- objective change;
- environmental destruction.

The tactical event queue resolves completely before another normal action begins.

---

## `domain/shared/`

This folder is intentionally small in the starter.

Place only genuinely shared primitives here, such as:

- stat blocks;
- tag sets;
- location references;
- basic target references.

Do not begin by building a universal language for every possible future mechanic.

Promotion rule:

> A concept becomes shared when at least two implemented systems need equivalent behaviour, or when the locked tactical rules already require it as a universal primitive.

Safe early shared primitives include:

- action cost;
- target reference;
- stat modifier;
- damage;
- healing;
- status application;
- resource spending;
- footprint;
- movement profile;
- requirement result;
- tactical event.

A unique Lich ritual, Mycelium network or Hydra multi-head rule may use a dedicated executor built on shared primitives.

---

# 5. Application layer

The application layer performs game use cases.

The physical starter uses one folder per current feature rather than creating mandatory `commands/`, `handlers/` and `queries/` subfolders immediately.

When a feature grows, expand it to:

```text
application/stronghold/
├── commands/
├── handlers/
└── queries/
```

Do not create those subfolders for a feature with only one or two files.

## Command flow

```text
Presentation sends command
    ↓
Application handler reads state and definitions
    ↓
Domain rules validate and calculate
    ↓
Handler prepares complete ChangeSet
    ↓
CampaignStateStore commits once
    ↓
Post-commit events publish
    ↓
Application query builds ViewModel
    ↓
Presentation refreshes
```

## `application/campaign/`

Place:

- campaign state store;
- change-set committer;
- runtime indexes;
- campaign query context;
- new-campaign creation.

## `application/strategic/`

Place:

- agent deployment;
- agent movement;
- opportunity generation coordination;
- mission acceptance;
- raid operation creation;
- strategic map queries.

## `application/stronghold/`

Place:

- build facility;
- restore plot;
- repair facility;
- cancel project;
- stronghold queries;
- future base-defence assembly planning.

## `application/inventory/`

Place:

- move item;
- equip item;
- unequip item;
- reserve item;
- release reservation;
- sell item;
- dismantle item;
- inventory and loadout queries.

## `application/missions/`

Place:

- mission setup builder;
- mission launch;
- mission result resolver;
- result idempotency checks;
- mission briefing and result queries.

## `application/tactical/`

Place:

- tactical state store;
- tactical command handling;
- tactical event processing;
- tactical result building.

## `application/time/`

Place:

- campaign scheduler;
- time scale;
- completion processing;
- interruption ordering.

---

# 6. Infrastructure

## `infrastructure/content/`

Place:

- content catalogue;
- content manifest;
- stable ID index;
- duplicate ID validation;
- missing reference validation.

Authored definitions remain immutable during play.

## `infrastructure/persistence/`

Place:

- save service;
- serializer;
- deserializer;
- validation;
- atomic file writing;
- backup rotation;
- save metadata.

Runtime saves belong in:

```text
user://saves/
```

not in `res://`.

### Safe save process

1. Validate campaign invariants.
2. Write a temporary save.
3. Read it back.
4. Validate the loaded result.
5. Rotate the previous backup.
6. Rename the temporary file to the final save.

### Versions

Maintain:

- schema version;
- content version;
- game build version.

## `infrastructure/persistence/migrations/`

Place explicit save migrations here.

Removed or renamed content IDs must have:

- a migration;
- a valid fallback;
- or a clear controlled error.

Never silently load a broken reference as `null`.

## `infrastructure/diagnostics/`

Place logging, crash reports and state dumps here.

## `infrastructure/platform/`

Place file-system and platform-specific gateways here.

---

# 7. Presentation

Presentation displays state and translates user actions into commands.

## `presentation/shell/`

Place the persistent campaign frame here.

Suggested shape:

```text
CampaignShell
├── PersistentStrategicHUD
├── NavigationBar
├── ScreenContainer
├── ContextPanelHost
├── NotificationDrawer
├── ModalHost
├── TooltipHost
└── TransitionOverlay
```

## `presentation/screens/region_map/`

Begin with:

```text
region_map_screen.tscn
region_map_screen.gd
region_map_view_model.gd
```

Add a separate controller or presenter only when the screen genuinely becomes difficult to coordinate or test.

## `presentation/screens/stronghold/`

Begin with:

```text
stronghold_screen.tscn
stronghold_screen.gd
stronghold_view_model.gd
```

## `presentation/tactical/`

Place:

- tactical camera;
- map view;
- actor views;
- overlays;
- HUD;
- animation;
- tactical input translation.

A tactical actor Node may contain:

- sprite;
- animation player;
- selection outline;
- health display;
- audio origin;
- visual-effect anchors.

It must not own:

- persistent XP;
- campaign equipment ownership;
- permanent injuries;
- class progression;
- campaign assignment.

## `presentation/widgets/`

Place reusable Controls here.

Examples:

- character row;
- item row;
- resource cost;
- status icon;
- mission card;
- facility tile;
- Notoriety report line;
- confirmation modal;
- tooltip.

## `presentation/view_models/`

Place disposable read-only display records here.

## `presentation/themes/`

Place:

- main Theme Resource;
- colour tokens;
- typography tokens;
- spacing tokens;
- icon registry.

## `presentation/input/`

Place strategic and tactical input contexts here.

Only the active game mode should receive gameplay input.

---

# 8. Authored content

The physical starter includes only content areas required by the first milestone.

## `content/manifest/`

The content catalogue starts here.

## `content/regions/ilyra_starter_region/`

Place:

- region definition;
- authored hex map;
- sites;
- routes;
- agent starting data;
- first opportunities;
- story events;
- raid operation definitions.

Create subfolders only when there are enough files to justify them.

## `content/strongholds/fifth_god_ruin_01/`

Place:

- stronghold definition;
- authored plot layout;
- fixed Heart and entrance;
- first assault route;
- future tactical module references.

## `content/facilities/generic/`

Place generic facilities such as:

- Storehouse;
- Armoury;
- Prison;
- Workshop;
- Research Chamber.

## `content/archetypes/reaver/`

This is the single canonical home for all Reaver-specific authored content.

Recommended future contents:

```text
content/archetypes/reaver/
├── reaver_definition.tres
├── abilities/
├── troops/
├── facilities/
├── research/
└── strategic_actions/
```

Do not duplicate Reaver facilities under a separate global `facilities/archetype/reaver/` path.

Do not duplicate Reaver Research under a global `research/archetype/` path.

Global folders are reserved for genuinely shared content.

## `content/characters/`

Use persistent terminology.

Recommended future groups:

```text
protagonists/
shared_recruits/
unique_followers/
story_characters/
enemies/
civilians/
temporary_units/
```

Do not use `ordinary_troops/`.

Archetype-specific recruits remain within their archetype folder.

## `content/items/`

Place first weapons, armour, consumables and carried objects here.

Split into subfolders when the file count becomes large enough.

## `content/missions/farm_storehouse/`

Place the first golden-path mission:

- mission definition;
- tactical map scene;
- objectives;
- deployment zones;
- patrol paths;
- loot anchors;
- extraction zone;
- validation metadata.

## `content/statuses/`

Place authored status definitions here.

## `content/ai_profiles/`

Place reusable enemy and civilian AI profiles here.

---

# 9. Assets

## `assets/art/`

Place presentation artwork here.

Do not put authoritative gameplay values in art imports.

## `assets/audio/`

Place music, ambience, UI and combat audio here.

Create more subfolders only when the asset count requires them.

---

# 10. Tests

## `tests/unit/`

Pure rule tests.

## `tests/integration/`

Cross-system tests.

## `tests/invariants/`

Universal state truths.

## `tests/content/`

Authored-content validation.

Critical first tests:

1. Content IDs are unique.
2. Broken references are rejected.
3. Building a facility through a command succeeds atomically.
4. Invalid placement makes no changes.
5. Save/load round trip preserves state.
6. Derived facility occupancy rebuilds after loading.
7. Every item has exactly one location.
8. Reservation does not change item location.
9. A mission result cannot be applied twice.
10. The same mission snapshot and seed create the same initial tactical state.

---

# 11. Screen complexity rule

Do not require four scripts for every screen.

Start with:

```text
screen.tscn
screen.gd
screen_view_model.gd
```

Add:

- controller;
- presenter;
- coordinator;
- local service;

only when the screen has substantial logic that benefits from independent testing or reuse.

The architecture should reduce complexity, not create ceremony.

---

# 12. Shared-system promotion rule

Before creating a generic system, ask:

1. Do at least two implemented features need the same behaviour?
2. Is the behaviour truly equivalent?
3. Is the concept already a locked universal tactical primitive?
4. Would data-driving it make the feature clearer?
5. Would a dedicated executor be easier to understand?

Use shared systems for stable primitives.

Use dedicated code for distinctive mechanics.

Do not create abstractions merely because a future feature might need them.

---

# 13. Recommended first implementation files

Create these next:

```text
bootstrap/autoload/game_app.gd
bootstrap/boot/dependency_builder.gd
bootstrap/boot/campaign_session.gd

core/ids/entity_id_generator.gd
core/results/operation_result.gd
core/changes/change_set.gd
core/events/domain_event.gd

domain/campaign/campaign_state.gd
domain/stronghold/stronghold_definition.gd
domain/stronghold/facility_definition.gd
domain/stronghold/stronghold_state.gd
domain/stronghold/facility_state.gd
domain/inventory/item_definition.gd
domain/inventory/item_state.gd
domain/inventory/item_location.gd
domain/inventory/inventory_reservation_state.gd

application/campaign/campaign_state_store.gd
application/campaign/campaign_runtime_indexes.gd
application/stronghold/build_facility_command.gd
application/stronghold/build_facility_handler.gd
application/stronghold/stronghold_query.gd

infrastructure/content/content_catalog.gd
infrastructure/content/content_validator.gd
infrastructure/persistence/save_service.gd
infrastructure/persistence/save_serializer.gd
infrastructure/persistence/save_deserializer.gd

presentation/shell/campaign_shell.tscn
presentation/screens/stronghold/stronghold_screen.tscn
presentation/screens/stronghold/stronghold_screen.gd
presentation/screens/stronghold/stronghold_view_model.gd
```

The first milestone is successful when:

1. The boot scene runs.
2. Content definitions load and validate.
3. A new campaign state is created.
4. A Storehouse can be built through one command.
5. A failed build makes no changes.
6. Reservation remains separate from item location.
7. The Stronghold screen refreshes through a query.
8. Save/load preserves the campaign.
9. Derived occupancy rebuilds after loading.
10. The project remains understandable without opening dozens of unused folders.

---

# 14. When to add future folders

Create a new physical folder only when at least one of these is true:

- the feature is part of the current milestone;
- the parent folder contains enough files to become hard to navigate;
- a new ownership boundary has become real;
- a test category needs a stable home;
- authored content has become numerous enough to require grouping.

The complete future structure is documented in:

```text
docs/architecture/FUTURE_STRUCTURE_REFERENCE.md
```

Do not copy that complete tree into the active project prematurely.

---

# 15. Final checklist before adding a feature

Ask:

1. Is this authored content, runtime state, a rule, a workflow, infrastructure or presentation?
2. Who owns the mutable state?
3. Is there exactly one authoritative copy?
4. Does the UI only send an intention?
5. Is the strategic change atomic?
6. Can the state be saved using stable IDs?
7. Is reservation separate from location?
8. Does tactical play use a snapshot rather than the live campaign?
9. Can the mission result be applied only once?
10. Is random generation deterministic?
11. Is this shared abstraction already justified?
12. Does the file need to exist for the current milestone?

Preserve the boundaries. Expand the tree only when the game earns the complexity.

---

# Implemented milestone

The project now includes Stage 1 tactical movement. See `docs/architecture/STAGE_1_TACTICAL_MOVEMENT_IMPLEMENTATION.md` for file ownership, controls, validation rules and deferred work.
