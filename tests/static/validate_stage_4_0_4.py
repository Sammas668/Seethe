#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []

    for path in [
        "presentation/tactical/tactical_screen.gd",
        "presentation/tactical/tactical_screen.tscn",
        "presentation/tactical/combat_log/tactical_combat_log.gd",
        "tests/presentation/stage_4_0_4_hud_layout_tests.gd",
        "tests/presentation/run_stage_4_0_4_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "presentation/tactical/tactical_screen.tscn",
        [
            'offset_top = 570.0',
            'custom_minimum_size = Vector2(265, 0)',
            'custom_minimum_size = Vector2(0, 52)',
            'UnitCapacityValueLabel',
            'text = "30 / 30 ft"',
            'horizontal_alignment = 1',
            'vertical_alignment = 1',
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "_unit_capacity_value_label",
            '"%d / %d ft"',
            '"AC %d" % unit.armour_class',
            'Half Action threshold',
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/combat_log/tactical_combat_log.gd",
        [
            "const COLLAPSED_TOP: float = -260.0",
            "const EXPANDED_TOP: float = -660.0",
            "const BOTTOM_OFFSET: float = -158.0",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.0.4",
        failures,
        [
            "Movement capacity is shown numerically inside its bar.",
            "The bottom UnitBlock reserves enough height for wrapped context text.",
            "Armour Class no longer duplicates the movement value.",
            "The Tactical Log remains clear of the taller bottom deck.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
