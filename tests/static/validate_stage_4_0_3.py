#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    for path in [
        "presentation/tactical/widgets/segmented_health_bar.gd",
        "presentation/tactical/widgets/roster_unit_button.gd",
        "tests/presentation/stage_4_0_3_health_bar_tests.gd",
        "tests/presentation/run_stage_4_0_3_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "presentation/tactical/widgets/segmented_health_bar.gd",
        [
            "LethalDamageFill",
            "NonlethalDamageFill",
            "_lethal_fill.position = Vector2(health_width, 0.0)",
            "_nonlethal_fill.position = Vector2.ZERO",
            '"%d / %d"',
            "Nonlethal damage",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/widgets/roster_unit_button.gd",
        [
            "AUTOWRAP_WORD_SMART",
            "HEALTH_BAR_SCRIPT",
            "refresh_unit",
            "unit.nonlethal_damage",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "ROSTER_UNIT_BUTTON_SCRIPT",
            "_unit_health_bar",
            '"set_values"',
            "unit.nonlethal_damage",
            '"AC %d"',
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.tscn",
        [
            "UnitHealthBar",
            "segmented_health_bar.gd",
            "autowrap_mode = 3",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_unit_state.gd",
        [
            "var nonlethal_damage: int = 0",
            "previous_nonlethal_damage",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)
    return finish(
        "Stage 4.0.3",
        failures,
        [
            "Squad cards wrap text and use compact segmented health bars.",
            "Red lethal damage advances from right to left as HP is lost.",
            "White nonlethal damage advances from left to right.",
            "The selected-unit HUD shows the numerical HP value inside the bar.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
