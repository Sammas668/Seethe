#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []

    for path in [
        "STAGE_4_2_5_3_UNIFIED_GRID_DISTANCE_PERCEPTION_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_2_5_3_UNIFIED_GRID_DISTANCE_PERCEPTION.md",
        "domain/tactical/tactical_grid_distance.gd",
        "domain/tactical/awareness/tactical_perception_rules.gd",
        "application/tactical/visibility/tactical_visibility_service.gd",
        "application/tactical/combat/attack_preview_query.gd",
        "application/tactical/ai/enemy_action_planner.gd",
        "tests/tactical/stage_4_2_5_stealth_awareness_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/tactical_grid_distance.gd",
        [
            "class_name TacticalGridDistance",
            "GENERAL_SIGHT_RADIUS_TILES: int = 40",
            "UNAWARE_FOCUSED_RANGE_TILES: int = 25",
            "CLOSE_AWARENESS_RADIUS_TILES: int = 1",
            "return delta.x + delta.y",
            "func minimum_steps_between_sets(",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/awareness/tactical_perception_rules.gd",
        [
            "TacticalGridDistance.CLOSE_AWARENESS_RADIUS_TILES",
            "TacticalGridDistance.UNAWARE_FOCUSED_RANGE_TILES",
            "TacticalGridDistance.GENERAL_SIGHT_RADIUS_TILES",
            "func aware_sight_radius_tiles() -> int:",
            "TacticalGridDistance.steps_between",
            "TacticalGridDistance.is_within_steps",
            "result += 4",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/visibility/tactical_visibility_service.gd",
        [
            "TacticalGridDistance.is_within_steps",
            "TacticalGridDistance.GENERAL_SIGHT_RADIUS_TILES",
        ],
        failures,
    )
    forbid_tokens(
        "application/tactical/visibility/tactical_visibility_service.gd",
        [
            "passive_perception",
            "maxi(absi(offset_x), absi(offset_y))",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "TacticalGridDistance.minimum_steps_between_sets",
            "TacticalGridDistance.TILE_SIZE_FEET",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_action_planner.gd",
        [
            "TacticalGridDistance.steps_between(destination, goal)",
            "TacticalGridDistance.minimum_steps_between_sets",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_2_5_stealth_awareness_tests.gd",
        [
            "_test_unified_grid_distance_and_perception_ranges",
            "A diagonal neighbour must count as two grid steps.",
            "focused_range_tiles(guard) == 25",
            "Close awareness must exclude a diagonal tile",
            "Aware perception must include the 40-square all-around boundary.",
        ],
        failures,
    )
    require_tokens(
        "content/missions/farm_storehouse/movement_test_map.tres",
        ["base_sight_radius_tiles = 40"],
        failures,
    )
    require_tokens(
        "tests/characters/stage_3_12_character_system_tests.gd",
        ["static func _resolution_service("],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.5.3",
        failures,
        [
            "Grid range uses one shared horizontal-plus-vertical distance rule.",
            "Every character reveals a 40-square wall-blocked sight radius.",
            "Unaware guards use a fixed 25-square forward cone.",
            "Close awareness is one square and still resolves a Stealth roll with +4 Detection DC.",
            "Aware guards use the 40-square all-around perception radius.",
            "Attack previews and enemy attack-position planning share the same range metric.",
            "The Stage 3.12 static-helper parser hotfix remains included.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
