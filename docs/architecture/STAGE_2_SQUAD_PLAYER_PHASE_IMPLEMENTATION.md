# STAGE 2 - SQUAD PLAYER PHASE IMPLEMENTATION

This update extends the Stage 1 tactical movement prototype into a complete friendly squad Player Phase.

## Implemented behaviour

- Three friendly units:
  - Test Marauder: 30 ft maximum capacity.
  - Test Archer: 30 ft maximum capacity.
  - Test Scout: 40 ft maximum capacity.
- Each unit tracks movement and action spending independently.
- The player can switch freely between partially activated units.
- Movement still uses the real 5 ft / alternating diagonal / difficult-terrain rules.
- Test Half Action consumes 50% of the selected unit's maximum capacity.
- Test Full Action consumes 100% and is unavailable after any normal capacity is spent.
- Test Quick Action uses a separate once-per-round allowance.
- Reactions are displayed as a separate future allowance but are not yet spent by any Stage 2 action.
- End Unit marks a unit as finished without refreshing it.
- Selecting an ended unit reactivates only its existing unspent budget.
- End Player Phase enters a short placeholder World Phase.
- The next Player Phase increments the round and refreshes every friendly unit exactly once.
- Action availability reasons appear as button tooltips.
- Units with ended or exhausted activations are visibly dimmed.

## Changed folders

```text
bootstrap/boot/
application/tactical/
content/missions/farm_storehouse/
domain/tactical/
presentation/tactical/
docs/architecture/
```

## New files

```text
domain/tactical/action_cost.gd
domain/tactical/action_budget_state.gd
domain/tactical/tactical_phase_state.gd
domain/tactical/spend_action_command.gd
domain/tactical/action_economy_rules.gd
domain/tactical/end_phase_command.gd
application/tactical/spend_action_handler.gd
application/tactical/end_phase_handler.gd
docs/architecture/STAGE_2_SQUAD_PLAYER_PHASE_IMPLEMENTATION.md
```

## Updated files

```text
bootstrap/boot/boot.gd
domain/tactical/tactical_unit_state.gd
domain/tactical/tactical_state.gd
domain/tactical/tactical_map_definition.gd
application/tactical/tactical_command_handler.gd
presentation/tactical/tactical_screen.gd
presentation/tactical/tactical_screen.tscn
presentation/tactical/tactical_unit_view.gd
content/missions/farm_storehouse/movement_test_map.tres
```

## Architecture decisions

The selected unit's state is not owned by the HUD. All action spending is stored in `ActionBudgetState` within `TacticalUnitState`.

The screen creates commands. Application handlers validate them, call domain rules and update the tactical state store.

The World Phase is currently a timed placeholder. Stage 3 can insert guard patrol and perception processing between `begin_world_phase()` and `complete_world_phase()` without changing the Player Phase architecture.

## Acceptance tests

1. Move the Marauder 10 ft, switch to the Archer, then return to the Marauder. The Marauder must still have 20 ft.
2. Use a Half Action with the Marauder after moving 10 ft. It should retain 5 ft.
3. Move a 30 ft unit 20 ft. Half Action must become unavailable.
4. Use a Half Action with the 40 ft Scout. It should retain 20 ft.
5. Use a Quick Action after movement. Normal capacity must not change.
6. Try a Full Action after any movement. It must be unavailable.
7. Use a Full Action before movement. Normal capacity must become 0.
8. End a unit and select it again. It must reactivate without refreshing spent capacity or Quick Action.
9. End the Player Phase. The World Phase label must appear briefly.
10. When the next Player Phase starts, all three units must refresh and the round must increase once.

## Next stage

Stage 3 should add one enemy guard, a patrol route, World Phase movement, Passive Perception and Unaware / Investigating / Alerted state changes. The current phase handler is designed so that those systems can be inserted without rewriting the Player Phase.
