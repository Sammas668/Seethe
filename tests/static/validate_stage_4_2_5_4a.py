#!/usr/bin/env python3
import sys
from validation_common import *


def _function_block(text: str, function_name: str) -> str:
    marker = f"func {function_name}"
    start = text.find(marker)
    if start < 0:
        return ""
    next_function = text.find("\nfunc ", start + len(marker))
    return text[start:] if next_function < 0 else text[start:next_function]


def main() -> int:
    failures: list[str] = []

    for path in [
        "STAGE_4_2_5_4A_SYMMETRICAL_INTENT_CONTROLS_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_2_5_4A_SYMMETRICAL_INTENT_CONTROLS.md",
        "presentation/tactical/tactical_screen.gd",
        "presentation/tactical/tactical_board_view.gd",
        "presentation/tactical/tactical_unit_view.gd",
        "tests/tactical/stage_4_2_5_4a_intent_controls_tests.gd",
        "tests/tactical/run_stage_4_2_5_4a_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "enum BoardIntentMode",
            "MOVE_PREVIEW",
            "FACING_PREVIEW",
            "_planned_destination",
            "_planned_facing",
            "func _begin_or_update_move_preview(",
            "func _confirm_planned_movement(",
            "func _begin_or_update_facing_preview(",
            "func _confirm_facing_preview(",
            "direction == _planned_facing",
            "_cancel_move_preview(\"Movement preview cancelled.\")",
            "_cancel_facing_preview(\"Facing preview cancelled.\")",
            "unit_view.preview_facing(direction)",
            "unit_view.commit_facing_preview(_planned_facing)",
            "_facing_commit_in_progress",
            "Left-click the destination again to move; right-click cancels.",
            "Right-click the same direction to confirm; left-click cancels.",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "func _draw_hover_highlight()",
            "var cumulative_cost: int = 0",
            "var diagonal_parity: int = unit.diagonal_steps_used % 2",
            "base_cost * _map_definition.movement_multiplier(tile)",
            "var destination: Vector2i = _preview_result.path.back()",
            "_draw_detection_badges()",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            "PREVIEW_TURN_DURATION: float = 0.12",
            "CANCEL_TURN_DURATION: float = 0.10",
            "func preview_facing(",
            "func cancel_facing_preview()",
            "func commit_facing_preview(",
            "wrapf(",
            "_draw_counter_front()",
            "Badges are drawn in local screen orientation",
            "position = _tile_to_world(path[0])",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_2_5_4a_intent_controls_tests.gd",
        [
            "_test_movement_preview_is_non_mutating",
            "_test_facing_preview_is_non_mutating_and_direction_based",
            "_test_authoritative_confirmation_still_commits",
            "Facing preview must not spend the 5-foot committed cost.",
        ],
        failures,
    )

    screen_text = require_file("presentation/tactical/tactical_screen.gd", failures)
    hover_block = _function_block(screen_text, "_on_board_tile_hovered")
    if not hover_block:
        failures.append("Could not inspect _on_board_tile_hovered().")
    else:
        for forbidden in [
            "preview_movement(",
            "preview_movement_detection(",
            "_refresh_path_preview()",
            "_update_facing_preview()",
        ]:
            if forbidden in hover_block:
                failures.append(
                    f"Hover still performs planning work: {forbidden}"
                )

    right_click_block = _function_block(screen_text, "_on_board_right_clicked")
    if "_cycle_attack_mode()" in right_click_block:
        failures.append(
            "Right-click attack-targeting cancellation was replaced by mode cycling."
        )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.5.4a",
        failures,
        [
            "Hover no longer creates movement or Stealth previews.",
            "Left-click previews and confirms movement; right-click cancels it.",
            "Right-click previews and confirms facing by quantised direction; left-click cancels it.",
            "Facing preview is immediate, smooth and non-mutating until confirmation.",
            "Token badges remain upright while directional counter artwork turns.",
            "Existing movement, Stealth, perception, initiative and AI rules remain unchanged.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
