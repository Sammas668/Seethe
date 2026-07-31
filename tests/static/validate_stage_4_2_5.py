#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []

    for path in [
        "domain/tactical/awareness/tactical_squad_state.gd",
        "domain/tactical/awareness/tactical_perception_rules.gd",
        "domain/tactical/awareness/movement_detection_preview.gd",
        "domain/tactical/awareness/tactical_detection_resolution.gd",
        "application/tactical/awareness/tactical_detection_service.gd",
        "application/tactical/awareness/stealth_handler.gd",
        "application/tactical/initiative/initiative_turn_handler.gd",
        "tests/tactical/stage_4_2_5_stealth_awareness_tests.gd",
        "tests/tactical/run_stage_4_2_5_tests.gd",
        "docs/architecture/STAGE_4_2_5_STEALTH_AWARENESS_ALERT_FOUNDATION.md",
    ]:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/awareness/tactical_squad_state.gd",
        [
            'AWARENESS_UNAWARE: StringName = &"unaware"',
            'AWARENESS_AWARE: StringName = &"aware"',
            "func make_aware() -> void:",
            "last_seen_positions_by_unit_id",
            "func remember_last_seen(",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_unit_state.gd",
        [
            "var squad_id: StringName",
            "var facing_direction: Vector2i",
            "var stealth_enabled: bool",
            "var revealed_to_squad_ids: Array[StringName]",
            "var assigned_task_position: Vector2i",
            "func shows_hidden_badge() -> bool:",
            "func stealth_bonus() -> int:",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_phase_state.gd",
        [
            'MODE_SIDE_BASED: StringName = &"side_based"',
            'MODE_INITIATIVE: StringName = &"initiative"',
            "var initiative_order: Array[StringName]",
            "var contact_round_active: bool",
            "func begin_initiative(",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/awareness/tactical_perception_rules.gd",
        [
            "CLOSE_AWARENESS_TILES: int = TacticalGridDistance.CLOSE_AWARENESS_RADIUS_TILES",
            "CONE_DOT_THRESHOLD",
            "func is_in_focused_cone(",
            "TacticalLineOfSightRules.has_line_of_sight",
            "func avoid_detection_chance_percent(",
            "BAND_CLOSE:",
            "result += 4",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/awareness/tactical_detection_service.gd",
        [
            "func preview_for_path(",
            "func prepare_path_resolution(",
            "func prepare_hostile_action_resolution(",
            "func can_enter_stealth(",
            "func resolve_current_perception_for_squad(",
            "lost_sight_squad_ids",
            "last_seen_tile_by_squad_id",
            "begin_initiative_combat",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_action_planner.gd",
        [
            "is_unit_revealed_to_squad",
            "_plan_search_or_return",
            "last_seen_unit_ids",
            "assigned_task_position",
            "_furthest_affordable_destination",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            "func set_hidden_badge",
            "func set_aware_badge",
            "func _draw_mask_badge",
            "func _draw_eye_badge",
            "func set_active_initiative",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "KEY_V",
            "_draw_perception_overlays",
            "func _draw_detection_badges() -> void:",
            "STEALTH_HOOD_ICON",
            "tile_preview.display_percent()",
            "_avoid_chance_color",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            '"Enter Stealth [Quick]"',
            "preview_movement_detection",
            '"Stealth checks: %d',
            "_initiative_order_summary",
            '"END TEAM PHASE"',
            "func _play_alert_flash()",
            "func _run_initiative_ai()",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.5",
        failures,
        [
            "Binary squad awareness and per-squad live revelation remain authoritative.",
            "Movement trails show per-tile chances to avoid detection with the shared Stealth icon.",
            "Close awareness uses the same Stealth roll with a +4 Detection DC bonus.",
            "Initiative order replaces the controls hint in the top-right HUD during combat.",
            "Characters may re-enter Stealth after breaking every guard's current perception.",
            "Aware guards search Last Seen Positions and then return toward their assigned task.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
