# Stage 5.2 Stronghold UI & Timed Construction Update

## Strategic screen rule

Only the Region Map advances campaign time. Every other campaign screen is a paused planning surface. Contextual chrome hides clock, speed, Agent and mission controls outside the map and reallocates that space to the active management workspace.

## Stronghold panel states

The stronghold side panel has three player-facing states:

1. **Construction catalogue** — default when no facility is selected.
2. **Placement** — active after choosing a room; hover determines origin and click confirms a valid position.
3. **Facility details** — shown for completed, damaged, disabled, constructing or upgrading facilities.

Empty plots are not inspector subjects. Clicking one clears facility selection.

## Timed project ownership

`StrongholdState` owns `StrongholdProjectState` records. A project records:

- stable project identity;
- construction or upgrade kind;
- facility instance and definition;
- start and completion campaign ticks;
- target level;
- revision.

The facility stores only its active project ID and current condition. Covered plots repeat the project ID for presentation and validation, but do not own project timing.

## Construction transaction

Construction validates the complete footprint before mutation, then atomically:

- allocates one facility instance;
- allocates one project;
- creates the facility as `under_construction`;
- occupies every plot;
- records the same project on every covered plot.

Cancellation removes the unfinished facility and releases all plots in the same candidate transaction.

## Upgrade transaction

An operational facility starts one upgrade project and enters `upgrading`. Its level is unchanged until the completion tick. Cancellation returns it to `operational` without granting the level.

## Clock integration

`CampaignSession.process_strategic_time()` advances stronghold projects inside the same runtime campaign change set as Agents, mission expiry and squad travel. Completion:

- applies the result once;
- clears plot and facility project references;
- removes the active project record;
- persists at a safe clock boundary;
- emits a presentation-only completion signal.

## Presentation

Multi-plot facilities remain one view, one illustration, one selection target and one progress bar. Connectivity remains available to services and developer validation but is not displayed as player-facing diagnostics in the open-grid prototype.
