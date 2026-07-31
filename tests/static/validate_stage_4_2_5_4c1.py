#!/usr/bin/env python3
import sys
from validation_common import *


CONSUMERS = [
    "application/tactical/ai/enemy_action_planner.gd",
    "application/tactical/combat/attack_preview_query.gd",
    "application/tactical/visibility/tactical_visibility_service.gd",
    "domain/tactical/awareness/tactical_perception_rules.gd",
    "tests/tactical/stage_4_2_5_stealth_awareness_tests.gd",
]


def main() -> int:
    failures: list[str] = []

    for path in [
        "STAGE_4_2_5_4C1_GRID_DISTANCE_PRELOAD_HOTFIX.txt",
        "docs/architecture/STAGE_4_2_5_4C1_GRID_DISTANCE_PRELOAD_HOTFIX.md",
        "domain/tactical/tactical_grid_distance.gd",
        *CONSUMERS,
    ]:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/tactical_grid_distance.gd",
        [
            "class_name TacticalGridDistance",
            "static func steps_between",
            "static func minimum_steps_between_sets",
            "const TILE_SIZE_FEET: int = 5",
        ],
        failures,
    )

    preload = (
        'const TacticalGridDistance: Script = preload(\n'
        '\t"res://domain/tactical/tactical_grid_distance.gd"\n'
        ')'
    )
    for path in CONSUMERS:
        require_tokens(path, [preload, "TacticalGridDistance."], failures)

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.5.4c1",
        failures,
        [
            "Every TacticalGridDistance consumer has an explicit parse-safe preload.",
            "The shared grid-distance implementation remains the sole rules authority.",
            "Gameplay and presentation behaviour are unchanged.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
