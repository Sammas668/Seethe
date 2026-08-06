#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    for path in [
        "presentation/tactical/tactical_screen.gd",
        "presentation/tactical/tactical_screen.tscn",
        "presentation/tactical/tactical_board_view.gd",
        "application/tactical/facades/tactical_screen_facade.gd",
        "tests/presentation/stage_4_1_1_direct_weapon_targeting_tests.gd",
        "tests/presentation/run_stage_4_1_1_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "presentation/tactical/tactical_screen.tscn",
        [
            'name="AttackModeButton"',
            'text = "NORMAL · LETHAL"',
            'name="PowerAttackValueButton"',
            'name="AttackCursorPreview"',
            'toggle_mode = true',
            'visible = false',
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "_select_weapon_from_hand",
            "_execute_direct_attack",
            "_cycle_attack_mode",
            "_refresh_attack_cursor_preview",
            "Input.CURSOR_CROSS",
            "Input.CURSOR_FORBIDDEN",
            "Left-click a legal hostile to attack.",
            "_contextual_attack_hover_active",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "board_right_clicked(tile: Vector2i)",
            "INVALID_TARGET_COLOR",
            "_draw_target_cells",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/facades/tactical_screen_facade.gd",
        [
            "func are_units_hostile",
            "TEAM_RELATIONS_SCRIPT",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.1.1",
        failures,
        [
            "Held weapons provide direct contextual battlefield attacks.",
            "Hovering a hostile shows hit chance, damage mode and cost beside the cursor.",
            "Left-clicking a legal hostile attacks with the selected hand.",
            "The old visible Attack tab remains removed.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
