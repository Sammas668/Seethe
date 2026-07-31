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
        "STAGE_4_2_5_4C_CONFIRMED_FACING_ANIMATION_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_2_5_4C_CONFIRMED_FACING_ANIMATION.md",
        "presentation/tactical/tactical_screen.gd",
        "presentation/tactical/tactical_board_view.gd",
        "presentation/tactical/tactical_unit_view.gd",
        "tests/tactical/stage_4_2_5_4c_confirmed_facing_animation_tests.gd",
        "tests/tactical/run_stage_4_2_5_4c_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "unit_view.preview_facing(direction)",
            "unit_view.commit_facing_preview(_planned_facing)",
            "direction == _planned_facing",
            "Right-click the same direction to confirm; left-click cancels.",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "func _draw_facing_preview()",
            "_facing_preview_direction",
            "facing_override = _facing_preview_direction",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            "The counter remains at its committed orientation until the second click.",
            "No return animation is required because preview never rotates the counter.",
            "Confirmation is the only point at which a manual facing command animates.",
            "_animate_visual_facing(direction, COMMITTED_TURN_DURATION)",
            "wrapf(",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_2_5_4c_confirmed_facing_animation_tests.gd",
        [
            "_test_preview_does_not_rotate_counter",
            "_test_cancellation_needs_no_return_animation",
            "_test_confirmation_starts_committed_turn_tween",
            "Facing preview must not create a turn tween.",
        ],
        failures,
    )

    unit_view_text = require_file(
        "presentation/tactical/tactical_unit_view.gd", failures
    )
    preview_block = _function_block(unit_view_text, "preview_facing")
    cancel_block = _function_block(unit_view_text, "cancel_facing_preview")
    commit_block = _function_block(unit_view_text, "commit_facing_preview")

    if not preview_block:
        failures.append("Could not inspect preview_facing().")
    elif "_animate_visual_facing(" in preview_block or "create_tween(" in preview_block:
        failures.append("The first right-click preview still animates the counter.")

    if not cancel_block:
        failures.append("Could not inspect cancel_facing_preview().")
    elif "_animate_visual_facing(" in cancel_block or "create_tween(" in cancel_block:
        failures.append("Cancelling facing preview still creates a return animation.")

    if not commit_block:
        failures.append("Could not inspect commit_facing_preview().")
    elif "_animate_visual_facing(direction, COMMITTED_TURN_DURATION)" not in commit_block:
        failures.append("Second-click confirmation does not start the committed turn animation.")

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.5.4c",
        failures,
        [
            "Facing preview updates the chevron and cone without rotating the counter.",
            "Second-click confirmation starts the quick shortest-arc counter turn.",
            "Cancelling preview spends nothing and needs no return animation.",
            "Movement, Stealth, perception, initiative, AI and contextual attacks are unchanged.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
