# Stage 5.4B/C — Research and Production Queue Screen Reflow

## Purpose

Research and Production previously placed the active queue beneath the catalogue and selected-project panels. At the authored 1280 × 720 viewport, the lower queue could extend beyond the bottom of the strategic workspace.

This update makes both screens support a large project queue without increasing the strategic screen height.

## Screen contract

Both screens now use one full-height, three-column board:

1. **Catalogue** — independently scrollable list of known Research or Production entries.
2. **Selected project** — independently scrollable description, requirements, quantity and queue action.
3. **Queue** — always-visible, independently scrollable list of all open projects.

The queue is no longer stacked beneath the other panels. Outer margins, panel padding and controls are compact enough for the 1280 × 720 campaign viewport.

## Queue rows

Each row shows:

- project name;
- actual assigned workers;
- requested worker count when it differs from the actual assignment;
- time remaining or Paused;
- compact minus/plus assignment controls;
- priority up/down controls;
- cancellation.

Changing the requested worker count or project priority continues to preserve completed work. The assignment resolvers still automatically allocate the highest-rated eligible workers to the highest-priority projects.

## Concurrent project capacity

A Research or Production workplace position may now support a separate active project. Authored project-slot capacity therefore matches worker-position capacity at every current facility level:

- Fifth-God Heart Research slots: `2 / 3 / 4 / 5 / 6`;
- Workshop Production slots: `3 / 6 / 10`.

This allows the player to spread one worker across every available position and run several projects simultaneously, or concentrate several workers on fewer projects. Projects beyond available workers or positions remain queued and paused without losing progress or reservations.

## Persistence

No save migration is required. Projects already store requested worker counts, priority and completed work. Effective allocation is recalculated from current workers and facility capacity after load.

## Validation

Static content validation covers:

- the full-height three-column layout;
- independently scrolling queues;
- compact assignment controls;
- project slots matching worker positions;
- level-one concurrent assignment for both Research and Production.
