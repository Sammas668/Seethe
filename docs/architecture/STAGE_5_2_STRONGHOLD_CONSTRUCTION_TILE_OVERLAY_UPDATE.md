# Stage 5.2 Stronghold Construction Tile Overlay Update

## Purpose

Keep the stronghold grid artwork-led and readable while making active construction unmistakable at a glance.

## Presentation contract

- Completed facility tiles show room artwork, exterior frame, hover and selection only.
- Facility names, levels, footprint data and other permanent text do not appear on grid tiles.
- A facility with an active construction or upgrade project keeps its artwork at normal brightness.
- One construction icon is drawn over the complete facility footprint.
- One countdown badge shows whole days remaining, rounded upward, with a large number and small `DAY` or `DAYS` label.
- Multi-plot facilities never repeat the icon or countdown per occupied plot.
- A thin whole-footprint progress line may supplement the countdown without obscuring the room art.

## State ownership

The overlay reads `StrongholdProjectState` and the current campaign tick. It does not own time, mutate projects or change facility condition. Completion remains authoritative in `StrongholdConstructionService` and `CampaignSession`.

## Countdown rule

`days_remaining = max(1, ceil(remaining_minutes / 1440.0))`

The overlay disappears as soon as the active project record is removed at completion or cancellation.
