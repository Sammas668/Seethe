#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []

    for path in [
        "application/tactical/ai/enemy_turn_handler.gd",
        "application/tactical/ai/enemy_action_planner.gd",
        "application/tactical/ai/enemy_action_plan.gd",
        "application/tactical/combat/attack_preview_query.gd",
        "application/tactical/combat/attack_handler.gd",
        "domain/tactical/tactical_unit_state.gd",
        "tests/combat/stage_4_1_active_enemy_tests.gd",
        "tests/combat/run_stage_4_1_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "application/tactical/ai/enemy_turn_handler.gd",
        [
            "TURN_BEHAVIOR_STANDARD",
            "ENEMY_ACTION_PLANNER_SCRIPT",
            "plan_activation",
            "_commit_enemy_move",
            "execute_preview",
            "_recover_activation_failure",
            "unit_turn_started",
            "unit_turn_ended",
            "unit_passed",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_action_planner.gd",
        [
            "_best_path_to_attack_position",
            "_furthest_affordable_destination",
            "state.get_units()",
            "TEAM_RELATIONS_SCRIPT.are_hostile",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "is_supported_ai_action",
            "_definition_is_supported",
            "state.phase_state.is_enemy_turn",
            "attacker.is_ai_controlled",
            "attacker.is_defeated",
            "target.is_defeated",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_unit_state.gd",
        [
            "COMBAT_STATE_ACTIVE",
            "COMBAT_STATE_DEFEATED",
            "combat_state",
            "func is_defeated()",
            "func can_take_actions()",
            "func life_state_id()",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/debug/tactical_sandbox_factory.gd",
        [
            "_configure_active_enemy",
            "TURN_BEHAVIOR_STANDARD",
            "Vector2i(7, 4)",
            '"Generated Settlement Guard"',
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "OBJECTIVE · Fight the enemy Settlement Guard",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/combat_log/tactical_event_formatter.gd",
        [
            'return "ENEMY TURN"',
        ],
        failures,
    )
    require_tokens(
        "tests/combat/stage_4_1_active_enemy_tests.gd",
        [
            "_test_guard_is_active_ai",
            "_test_guard_moves_and_attacks",
            "_test_downed_units_skip",
            "action.training_spear_attack",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.1",
        failures,
        [
            "The Settlement Guard uses Standard Combat AI during the Enemy Turn.",
            "Enemy movement and attacks use TacticalStateStore and the shared attack pipeline.",
            "The Guard targets active hostile units through team relations.",
            "Units below 0 HP become Dying and skip ordinary activations.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
