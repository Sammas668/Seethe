# Stage 3.9.2 — Tactical Event and Roll Log

Stage 3.9.2 adds the permanent tactical journal that Stage 4 combat will use
for attacks, damage, saving throws, conditions, reactions and major mission
events.

## Placement

The collapsed log is anchored at the bottom-right of the tactical map:

- 10 px from the right edge.
- 8 px above the BottomDeck.
- 340 px wide.
- 102 px high.
- Three recent committed events visible.

It sits directly above the Phase block without resizing the battlefield.

Press `L` or click the arrow to expand the drawer upward from the same anchor.
The expanded drawer is 440 px wide and approximately 500 px high.

Opening Unit Management automatically collapses the drawer.

## Two distinct information systems

The existing BottomDeck status line remains temporary guidance:

```text
Choose a destination.
Sprint selected.
That tile is occupied.
```

The tactical journal records committed results:

```text
Test Marauder moved 15 ft.
Test Scout picked up Training Spear.
Round 2 — Player Phase.
```

Selection, hovering, cancelled actions and failed commands do not create
successful journal entries.

## Current recorded events

The prototype now journals:

- Initial round and Player Phase.
- Normal movement.
- Sprint.
- Generic budget actions such as Ready Stance.
- Unit ending.
- Unit reactivation.
- Inventory pickup.
- Inventory dropping.
- Equipping either hand.
- Moving items between Belt, Backpack and hands.
- World Phase beginning.
- New Player Phase beginning.

Free rearrangement inside the same Belt or Backpack grid is intentionally not
recorded.

## Structured event model

Gameplay does not author final UI sentences as its only data. Each event stores
structured fields:

```text
event_id
sequence_number
round_number
phase_id
event_type
category
summary
source_actor_id
target_actor_ids
action_id
item_id
details
roll_records
modifier_records
effect_records
resource_changes
visibility
parent_event_id
metadata
```

Roll, modifier and effect record factories already exist for Stage 4.

The player-facing journal hides events whose visibility is not `player`.
This permits future stealth, hidden traps and secret checks without leaking
information. A separate developer view may later request hidden events.

## Filters

The expanded drawer has four filters:

- ALL
- ROLLS
- COMBAT
- EVENTS

Existing non-combat actions appear under EVENTS. Stage 4 attacks will appear
under COMBAT and will also match ROLLS when they contain roll records.

## Expandable entries

Each full-log entry displays a compact summary. Clicking the summary reveals:

- Round and phase.
- Named action details.
- Source and destination.
- Action cost.
- Capacity and Quick Action changes.
- Future dice results.
- Future named modifiers.
- Future opposing values and outcomes.
- Future effects such as HP or condition changes.

## Architecture

New domain event schemas:

```text
domain/tactical/events/
├── tactical_event_type.gd
├── tactical_event_record.gd
├── tactical_roll_record.gd
├── tactical_modifier_record.gd
└── tactical_effect_record.gd
```

Session journal:

```text
application/tactical/events/
└── tactical_event_journal.gd
```

Presentation:

```text
presentation/tactical/combat_log/
├── tactical_combat_log.gd
├── tactical_combat_log.tscn
└── tactical_event_formatter.gd
```

`TacticalSession` owns one journal and injects it into application handlers.
Handlers publish only after their state mutation has committed successfully.

## Test checklist

1. Run the project at 1280 × 720.
2. Confirm the compact log appears above the Phase block.
3. Confirm its initial entry says Round 1 — Player Phase.
4. Move a unit and confirm one movement line appears.
5. Press `L` and confirm the drawer expands upward.
6. Click the movement entry and confirm distance, coordinates and capacity are
   shown.
7. Sprint and confirm Full Action and Reaction loss are shown.
8. Pick up the ground spear and confirm item, source, destination and cost are
   shown.
9. Rearrange an item within the same Backpack and confirm no journal clutter is
   added.
10. Attempt an invalid action and confirm it does not appear as a committed
    event.
11. End the phase and confirm World and next Player phase entries appear.
12. Open Unit Management and confirm the drawer collapses.
13. Test ALL, ROLLS, COMBAT and EVENTS filters.
14. Resize the window and confirm the log remains anchored at bottom-right.
15. Run the headless test suite:

```bash
godot --headless --path . -s tests/tactical/run_stage_3_9_2_tests.gd
```

Godot was unavailable in the packaging environment, so local parser and runtime
verification remain required.
