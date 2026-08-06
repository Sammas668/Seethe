#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    required = [
        "STAGE_4_3_1B_DYING_TRACKER_ENEMY_EYE_ADJUSTMENT_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_3_1B_DYING_TRACKER_ENEMY_EYE_ADJUSTMENT.md",
        "tests/tactical/run_stage_4_3_1b_tests.gd",
    ]
    for path in required:
        require_file(path, failures)

    require_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            "DYING_TRACK_PIP_RADIUS: float = 1.15",
            "DYING_TRACK_PIP_HORIZONTAL_OFFSET: float = 9.2",
            "DYING_TRACK_PIP_VERTICAL_SPACING: float = 3.2",
            "DYING_SKULL_ART_SIZE: float = 11.5",
            "centre.x - DYING_TRACK_PIP_HORIZONTAL_OFFSET",
            "centre.x + DYING_TRACK_PIP_HORIZONTAL_OFFSET",
            "Color(0.24, 0.78, 0.35, 1.0)",
            "Color(0.92, 0.16, 0.19, 1.0)",
            'if _aware_badge and _team_id == &"enemy":',
            "characters never show this badge",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_3_1a_token_status_squad_alert_tests.gd",
        [
            "_test_awareness_eye_is_enemy_only",
            "Player characters must never show the enemy patrol awareness eye.",
            "An active aware enemy patrol member must still show the awareness eye.",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/boot/boot.gd",
        [
            "Stage 4.3.1b dying tracker and enemy-only awareness icon adjustment loaded."
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.3.1b",
        failures,
        [
            "The Dying skull is larger while its tracks sit outside the standard badge.",
            "Dying successes use green pips and failures use red pips.",
            "Awareness eyes appear only on aware enemy patrol members.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
