# Stage 5.4 Stabilisation Pass

## Purpose

This pass hardens the Stage 5.4 strategic economy before Stage 5.5 adds base-defence complexity. It does not add a new campaign feature family. It aligns authored data and validation, restores a trustworthy documentation entry point, establishes recoverable source history, removes obsolete patch-generation infrastructure, and begins splitting the largest presentation and AI files along existing seams.

## Stronghold validation decision

The starting Stables are authored infrastructure, not a catalogue option.

- `facility.stables` is a completed starting facility.
- It occupies the authored 2×2 footprint at origin `(2, 5)`.
- It is non-demolishable.
- It is not buildable at campaign start.
- `facility.living_quarters` remains buildable.

The static validator and the Godot behavioural test now check both facts independently: the Stables must exist in the starting state and must not appear in `buildable_facilities()`.

## Initial CampaignShell extraction

Research and Production presentation were moved from `presentation/campaign/campaign_shell.gd` into:

- `presentation/campaign/controllers/research_screen_controller.gd`
- `presentation/campaign/controllers/production_screen_controller.gd`

`CampaignShell` remains the strategic composition root. It owns top-level screen routing, shared chrome, and the campaign-session reference. The extracted controllers own screen-local selection state, queue rows, confirmation dialogs, and project commands. Domain state still changes only through `CampaignSession` services.

This reduces `campaign_shell.gd` from approximately 11.8k lines to approximately 11.0k lines without changing the Stage 5.4 save model or transaction ownership.

## Enemy-turn consolidation

The former Hotfix 5d–5f10 static validation chain has been replaced by one current pipeline validator:

- `tests/content/validate_enemy_turn_pipeline.py`

Activation timing history and presentation timing attribution moved into:

- `application/tactical/ai/enemy_turn_instrumentation.gd`

`EnemyTurnHandler` still owns activation sequencing, planning jobs, warmup reuse, reaction continuation, movement and attack commits. The instrumentation class owns timing samples, slow-activation history and presentation-time merging. This is the first extraction from the enemy-turn monolith; it is not a full AI rewrite.

## Patch consolidation

The obsolete `tools/patching/` source-rewriting scripts were removed. Their applied changes remain in the canonical source, and their history is preserved by Git.

Historical release notes and runtime regression tests may retain old stage or hotfix names. They are records and tests, not mechanisms for modifying current source.

## Behavioural coverage

`tests/integration/stage_5_4_stabilisation_tests.gd` verifies:

- the starting Stables are instantiated, operational and 2×2;
- the Stables are excluded from the build catalogue;
- Living Quarters remain buildable;
- the full Stage 5.4B manufacturing/personnel/repair behavioural suite;
- the full Stage 5.4C research/unlock behavioural suite.

The runtime suite requires Godot 4.7.1 and is not replaced by Python token checks.

## Deliberately deferred

This pass does not complete the full `campaign_shell.gd` or `tactical_screen.gd` decomposition. Recommended next extractions are Storage/Shop, Roster/Workforce, Stronghold presentation, tactical inventory drag/drop, tactical HUD, and reaction prompts. Each should be a separate Git commit with behavioural tests.
