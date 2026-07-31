#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []

    for path in [
        "STAGE_4_2_5_4_CHARACTER_FACING_SYMMETRIC_PERCEPTION_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_2_5_4_CHARACTER_FACING_SYMMETRIC_PERCEPTION.md",
        "application/tactical/facing/facing_handler.gd",
        "application/tactical/tactical_command_handler.gd",
        "application/tactical/sprint_move_handler.gd",
        "application/tactical/combat/attack_handler.gd",
        "application/tactical/awareness/tactical_detection_service.gd",
        "application/tactical/awareness/detection_observer_query.gd",
        "application/tactical/visibility/tactical_visibility_service.gd",
        "presentation/tactical/tactical_board_view.gd",
        "presentation/tactical/tactical_screen.gd",
        "presentation/tactical/tactical_unit_view.gd",
        "tests/tactical/stage_4_2_5_4_facing_perception_tests.gd",
        "tests/tactical/run_stage_4_2_5_4_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "application/tactical/facing/facing_handler.gd",
        [
            "class_name FacingHandler",
            "FACE_DIRECTION_COST_FEET: int = 5",
            "func preview_direction(",
            "func execute(",
            "resolve_current_perception_for_squad",
            "spend_normal_capacity(FACE_DIRECTION_COST_FEET)",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/tactical_command_handler.gd",
        [
            "facing_before: Vector2i",
            "actual_facing: Vector2i",
            "committed_path_result.path.back()",
            "_set_unit_position_and_facing",
            "resolve_current_perception_for_squad(unit.squad_id)",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/sprint_move_handler.gd",
        [
            "facing_before: Vector2i",
            "actual_facing: Vector2i",
            "_set_unit_position_and_facing",
            "sprint_perception_refresh_failed",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_handler.gd",
        [
            "_spend_attack_cost_and_face",
            "target_position - attacker.grid_position",
            '"facing": unit.facing_direction',
            "attack_perception_refresh_failed",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_unit_state.gd",
        [
            "current_stealth_roll_valid",
            "current_stealth_roll_value",
            "current_stealth_total",
            "func set_current_stealth_roll(",
            "func clear_current_stealth_roll()",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/awareness/tactical_detection_service.gd",
        [
            "PLAYER_TEAM_SQUAD_ID",
            "_resolve_tile_check_with_existing_roll",
            "unit.current_stealth_roll_valid",
            "Passive perception revealed the hidden unit",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/awareness/detection_observer_query.gd",
        [
            "if use_ordinary_sight:",
            "TacticalPerceptionRules.is_in_aware_radius",
            "TacticalPerceptionRules.is_in_focused_cone",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/visibility/tactical_visibility_service.gd",
        [
            "unit.stealth_enabled",
            "is_unit_revealed_to_team",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "_facing_preview_direction",
            "_facade.face_direction(",
            "Right-click: Face (5 ft)",
            "Passive Perception %d",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "_draw_facing_preview()",
            "_draw_last_seen_markers()",
            "player_last_seen_positions()",
            "facing_override = _facing_preview_direction",
            "_draw_direction_arrow(",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            "_draw_facing_tick()",
        ],
        failures,
    )
    forbid_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            'if _team_id == &"enemy":\n\t\t_draw_facing_tick()',
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_2_5_4_facing_perception_tests.gd",
        [
            "_test_movement_faces_last_completed_step",
            "_test_manual_facing_costs_five_feet",
            "_test_stationary_hidden_enemy_reuses_stealth_result",
            "_test_player_perception_reveals_without_starting_initiative",
            "Repeated orientation must not fish for fresh passive Perception rolls.",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.5.4",
        failures,
        [
            "Voluntary movement and attacks update authoritative eight-direction facing.",
            "Right-click Face Direction costs 5 feet and previews the focused perception cone.",
            "Player characters use the same focused and close perception rules against hidden enemies.",
            "Stationary hidden enemies retain one Stealth result, preventing orientation reroll fishing.",
            "Detected hidden enemies are revealed to the player team without triggering enemy-alert initiative.",
            "Confirmed last-seen enemy positions remain visible without tracking hidden live movement.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
