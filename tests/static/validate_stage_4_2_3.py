#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []

    for path in [
        "domain/tactical/visibility/tactical_visibility_state.gd",
        "application/tactical/visibility/tactical_visibility_service.gd",
        "presentation/tactical/tactical_board_view.gd",
        "tests/tactical/stage_4_2_3_visibility_camera_tests.gd",
        "tests/tactical/run_stage_4_2_3_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "content/missions/farm_storehouse/movement_test_map.tres",
        [
            "grid_size = Vector2i(64, 64)",
            "base_sight_radius_tiles = 40",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "MIN_ZOOM",
            "MAX_ZOOM",
            "MOUSE_BUTTON_WHEEL_UP",
            "MOUSE_BUTTON_MIDDLE",
            "to_local(screen_position)",
            "is_tile_explored_by_player",
            "is_tile_visible_to_player",
            "EXPLORED_OVERLAY_COLOR",
            "UNSEEN_COLOR",
            "center_on_tile",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/visibility/tactical_visibility_service.gd",
        [
            "recalculate_all_teams",
            "is_unit_visible_to_team",
            "TacticalLineOfSightRules.has_line_of_sight",
            "TacticalGridDistance.GENERAL_SIGHT_RADIUS_TILES",
            "TacticalGridDistance.is_within_steps",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "That target is not currently visible.",
            "_visibility_service",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "visible_unit_at_tile",
            "_center_camera_on_selected_unit",
            "Wheel Zoom",
            "Middle-drag / Arrows Pan",
            "That destination is obscured by fog of war.",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_action_planner.gd",
        [
            "_candidate_attack_positions",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.3",
        failures,
        [
            "64×64 map supports cursor-centred zoom and panning.",
            "Player visibility distinguishes unseen, explored, and visible tiles.",
            "Hidden units and ground items are not presented or targetable.",
            "Screen-to-tile targeting remains transform-correct at every zoom.",
            "Enemy melee path planning no longer scans the entire large map.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
