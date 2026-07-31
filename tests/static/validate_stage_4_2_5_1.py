#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []

    for path in [
        "STAGE_4_2_5_1_RELEASE_NOTES.txt",
        "STAGE_4_2_5_1A_HOTFIX_NOTES.txt",
        "docs/architecture/STAGE_4_2_5_1_STEALTH_SEARCH_UI_REVISION.md",
        "application/tactical/ai/enemy_action_plan.gd",
        "application/tactical/ai/enemy_action_planner.gd",
        "application/tactical/ai/enemy_turn_handler.gd",
        "application/tactical/awareness/stealth_handler.gd",
        "application/tactical/awareness/tactical_detection_service.gd",
        "domain/tactical/awareness/movement_detection_preview.gd",
        "domain/tactical/awareness/tactical_detection_resolution.gd",
        "tests/tactical/stage_4_2_5_stealth_awareness_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/awareness/movement_detection_preview.gd",
        [
            "var avoid_detection_chance_percent: int = 100",
            'return "%d%%" % avoid_detection_chance_percent',
        ],
        failures,
    )
    require_tokens(
        "application/tactical/awareness/stealth_handler.gd",
        [
            "Break every guard's current line of perception",
            "unit.conceal_from_squad(squad_id)",
            "unit.action_budget.spend_quick_action()",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/awareness/tactical_detection_resolution.gd",
        [
            "revealed_at_destination_squad_ids",
            "lost_sight_squad_ids",
            "last_seen_tile_by_squad_id",
            "stealth_broken",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_action_plan.gd",
        [
            'KIND_SEARCH: StringName = &"search"',
            'KIND_RETURN_TO_TASK: StringName = &"return_to_task"',
            "func configure_search(",
            "func configure_return_to_task(",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_turn_handler.gd",
        [
            "_execute_search_or_return_plan",
            "_refresh_squad_perception",
            "_forget_last_seen",
            "returned toward its prior guard task",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_2_5_stealth_awareness_tests.gd",
        [
            "_test_close_awareness_uses_a_bonus_not_automatic_detection",
            "_test_lost_sight_and_rehide",
            "_test_guard_searches_last_seen_then_returns",
            "avoid_detection_chance_percent",
        ],
        failures,
    )

    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "func _draw_selection_outline() -> void:",
            "func tile_to_world(tile: Vector2i) -> Vector2:",
            "func screen_to_tile(screen_position: Vector2) -> Vector2i:",
            "func tile_to_screen(tile: Vector2i) -> Vector2:",
            "func _screen_to_tile(screen_position: Vector2) -> Vector2i:",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.5.1",
        failures,
        [
            "The displayed percentage is explicitly the chance to avoid detection.",
            "Close proximity raises Detection DC instead of forcing automatic discovery.",
            "Breaking perception allows a Quick Action Stealth re-entry.",
            "Squads retain Last Seen Position memory without retaining hidden live coordinates.",
            "Search and return-to-task behaviours operate without adding extra awareness states.",
            "The initiative order occupies the existing top-right hint area during combat.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
