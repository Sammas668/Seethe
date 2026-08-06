#!/usr/bin/env python3
from pathlib import Path
from validation_common import *


def function_block(path: str, function_name: str) -> str:
    text = (ROOT / path).read_text(encoding="utf-8")
    marker = f"func {function_name}("
    start = text.find(marker)
    if start < 0:
        return ""
    next_func = text.find("\nfunc ", start + len(marker))
    return text[start:] if next_func < 0 else text[start:next_func]


def main() -> int:
    failures: list[str] = []
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    required_files = [
        "STAGE_4_4E3A_CLICK_LOCKED_MOVEMENT_PREVIEW_CORRECTION_RELEASE_NOTES.txt",
        "STAGE_4_4E3A_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_4E3A_CLICK_LOCKED_MOVEMENT_PREVIEW_CORRECTION.md",
        "tests/tactical/stage_4_4e3a_click_locked_movement_preview_tests.gd",
        "tests/tactical/run_stage_4_4e3a_tests.gd",
    ]
    for path in required_files:
        require_file(path, failures)

    screen_path = "presentation/tactical/tactical_screen.gd"
    screen_text = require_file(screen_path, failures)
    hover_block = function_block(screen_path, "_on_board_tile_hovered")
    if not hover_block:
        failures.append("Missing _on_board_tile_hovered().")
    else:
        for forbidden in [
            "_destination_preview_for(",
            "_refresh_hover_movement_preview(",
            "preview_movement(",
            "_refresh_path_preview()",
        ]:
            if forbidden in hover_block:
                failures.append(f"Ordinary hover still performs movement planning: {forbidden}")
        if hover_block.count("_refresh_hud()") != 1:
            failures.append("Hover must contain one conditional HUD-refresh call.")
        if hover_block.count("_refresh_board_view()") != 1:
            failures.append("Hover must request exactly one board redraw.")
        if "previous_attack_target_id" not in hover_block:
            failures.append("Hover HUD refresh is not gated by attack-context changes.")

    if "func _refresh_hover_movement_preview(" in screen_text:
        failures.append("The obsolete hover movement-preview function still exists.")
    if "func _restore_locked_preview_or_clear(" in screen_text:
        failures.append("The obsolete hover path restoration function still exists.")

    refresh_block = function_block(screen_path, "_refresh_path_preview")
    if "_refresh_hover_movement_preview" in refresh_block:
        failures.append("State-change preview refresh still delegates to cursor hover.")
    if "_clear_destination_preview_visuals()" not in refresh_block:
        failures.append("No-intent state refresh does not clear stale destination visuals.")
    if "_planned_destination" not in refresh_block or "_destination_preview_for" not in refresh_block:
        failures.append("Clicked destination revalidation is missing.")

    click_block = function_block(screen_path, "_handle_left_click")
    if "tile == _planned_destination" not in click_block:
        failures.append("Second-click confirmation no longer checks the locked destination.")
    if click_block.find("_confirm_planned_movement()") > click_block.find("_begin_or_update_move_preview(tile)"):
        failures.append("Second-click confirmation must occur before replacement preview creation.")

    begin_block = function_block(screen_path, "_begin_or_update_move_preview")
    for token in [
        "_destination_preview_for(selected_unit, tile)",
        "_board_intent_mode = BoardIntentMode.MOVE_PREVIEW",
        "_planned_destination = tile",
        "Left-click the destination again to move",
    ]:
        if token not in begin_block:
            failures.append(f"First-click locked preview is missing: {token}")

    require_tokens(
        "tests/tactical/stage_4_4e3a_click_locked_movement_preview_tests.gd",
        [
            "Hovering an empty tile must not build a movement preview.",
            "Moving the cursor must preserve the locked destination.",
            "Clicking another legal tile must replace the locked destination.",
            "Right-click must cancel MOVE_PREVIEW intent.",
            "The second left-click on the same destination must commit movement.",
        ],
        failures,
    )
    require_tokens(
        "README_FIRST.txt",
        ["STAGE 4.4e3a", "CLICK-LOCKED MOVEMENT PREVIEW"],
        failures,
    )

    if failures:
        print("Stage 4.4e3a static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 4.4e3a static validation passed.")
    print(" - Empty-tile hover performs no movement planning.")
    print(" - First click locks one path; cursor movement preserves it.")
    print(" - Second same-tile click confirms; different click replaces; right-click cancels.")
    print(" - Ordinary hover redraws the board without rebuilding the full HUD.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
