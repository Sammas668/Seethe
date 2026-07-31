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
        "STAGE_4_4E3B1_STEALTH_BADGE_COVER_PRIORITY_RELEASE_NOTES.txt",
        "STAGE_4_4E3B1_PATCH_README.txt",
        "STAGE_4_4E3B1_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_4E3B1_STEALTH_BADGE_COVER_PRIORITY.md",
        "tests/tactical/stage_4_4e3b1_stealth_cover_priority_tests.gd",
        "tests/tactical/run_stage_4_4e3b1_tests.gd",
    ]
    for path in required_files:
        require_file(path, failures)

    board_path = "presentation/tactical/tactical_board_view.gd"
    board_text = require_file(board_path, failures)
    ghost_block = function_block(board_path, "_draw_movement_ghost")
    priority_block = function_block(board_path, "_tile_has_detection_badge")
    path_block = function_block(board_path, "_draw_path_preview")

    for required in [
        "not _tile_has_detection_badge(destination)",
        "TacticalCombatGeometryResult.COVER_LIGHT",
        "TacticalCombatGeometryResult.COVER_HEAVY",
        "_draw_cover_badge(",
    ]:
        if required not in ghost_block:
            failures.append(
                f"Movement-ghost Stealth/cover priority is missing: {required}"
            )

    if "return" in ghost_block.split("not _tile_has_detection_badge(destination)", 1)[-1].split("_draw_cover_badge", 1)[0]:
        failures.append(
            "The Stealth-priority branch must suppress only the shield, not the movement ghost."
        )

    for required in [
        "_detection_preview == null",
        "_detection_preview.preview_for_tile(tile)",
        "tile_preview.has_detection_risk()",
    ]:
        if required not in priority_block:
            failures.append(f"Detection-badge lookup is missing: {required}")

    if "_draw_detection_badges()" not in path_block:
        failures.append("Per-tile Stealth badges are no longer drawn with the path.")
    if "_draw_directional_cover_field()" not in board_text:
        failures.append("The directional cover field was unintentionally removed.")

    # The correction must not introduce any new tactical query or hover work.
    hover_text = require_file(
        "presentation/tactical/tactical_screen.gd", failures
    )
    hover_start = hover_text.find("func _on_board_tile_hovered(")
    hover_end = hover_text.find("\nfunc ", hover_start + 1)
    hover_block = hover_text[hover_start:hover_end] if hover_start >= 0 else ""
    for forbidden in [
        "preview_movement(",
        "preview_movement_detection(",
        "preview_destination_cover(",
        "observation_origins_for_unit(",
    ]:
        if forbidden in hover_block:
            failures.append(
                f"Stage 4.4e3b1 restored forbidden hover query work: {forbidden}"
            )

    require_tokens(
        "tests/tactical/stage_4_4e3b1_stealth_cover_priority_tests.gd",
        [
            "A destination Stealth percentage must suppress the cover shield.",
            "An unknown-risk question mark must suppress the cover shield.",
            "A certain-detection 0% badge must suppress the cover shield.",
            "A different destination without Stealth risk must retain its cover shield.",
        ],
        failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.4e3b1",
            "STEALTH BADGE AND COVER-SHIELD PRIORITY CORRECTION",
            "run_stage_4_4e3b1_tests.gd",
            "validate_stage_4_4e3b1.py",
        ],
        failures,
    )

    if failures:
        print("Stage 4.4e3b1 static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Stage 4.4e3b1 static validation passed.")
    print(" - Risky destination tiles prioritise the Stealth badge over the cover shield.")
    print(" - Safe destinations retain the contextual Light/Heavy cover shield.")
    print(" - Movement ghost, directional cover field and clicked-route detection trail remain intact.")
    print(" - No pathfinding, detection, cover, visibility or Peek query was added to hover.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
