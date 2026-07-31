#!/usr/bin/env python3
import sys
from pathlib import Path
from validation_common import *


def between(text: str, start: str, end: str) -> str:
    start_index = text.find(start)
    if start_index < 0:
        return ""
    end_index = text.find(end, start_index + len(start))
    if end_index < 0:
        return text[start_index:]
    return text[start_index:end_index]


def main() -> int:
    failures: list[str] = []

    require_file("presentation/tactical/tactical_screen.gd", failures)
    require_file(
        "docs/architecture/STAGE_4_1_2_FRIENDLY_SELECTION.md",
        failures,
    )

    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "Friendly and neutral units remain selection/inspection targets",
            "not _facade.are_units_hostile(",
            "_select_unit(clicked_unit.unit_id)",
            "Do not construct or display an invalid attack preview.",
            "_hide_attack_cursor_preview()",
            "Input.CURSOR_POINTING_HAND",
        ],
        failures,
    )

    screen_text = (ROOT / "presentation/tactical/tactical_screen.gd").read_text(encoding="utf-8")
    click_handler = between(
        screen_text,
        "func _on_board_tile_left_clicked",
        "func _on_board_right_clicked",
    )
    if "_execute_direct_attack(clicked_unit)" not in click_handler:
        failures.append("Hostile contextual attacks were removed from the click handler.")
    if click_handler.find("_select_unit(clicked_unit.unit_id)") < 0:
        failures.append("Friendly click selection was removed from the click handler.")

    hover_handler = between(
        screen_text,
        "func _refresh_attack_hover_preview",
        "func _select_attack_target_at_tile",
    )
    if hover_handler.find("not _facade.are_units_hostile(") > hover_handler.find(
        "_facade.preview_attack("
    ):
        failures.append(
            "Friendly hover rejection must happen before attack preview creation."
        )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.1.2",
        failures,
        [
            "Friendly clicks select rather than attack.",
            "Friendly hover shows no hit-chance popup.",
            "Hostile contextual targeting remains available.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
