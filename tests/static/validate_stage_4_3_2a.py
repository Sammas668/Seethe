#!/usr/bin/env python3
from validation_common import *


def main() -> int:
    failures: list[str] = []
    for path in [
        "STAGE_4_3_2A_DRAGGED_BODY_PATH_FOLLOWING_HOTFIX_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_3_2A_DRAGGED_BODY_PATH_FOLLOWING.md",
        "tests/tactical/stage_4_3_2_body_item_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/tactical_state.gd",
        [
            "func dragged_body_cell_snapshot(",
            "func move_dragged_bodies_to_cell(",
            "func restore_dragged_body_cells(",
            "result[item.item_id] = item.location.map_position",
            "body_unit.grid_position = cell",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/tactical_command_handler.gd",
        [
            "dragged_body_cell_snapshot(unit.unit_id)",
            "committed_path_result.path.size() - 2",
            "dragged_body_destination",
            "move_dragged_bodies_to_cell(",
            "restore_dragged_body_cells(",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/sprint_move_handler.gd",
        [
            "dragged_body_cell_snapshot(unit.unit_id)",
            "committed_path_result.path.size() - 2",
            "move_dragged_bodies_to_cell(",
            "restore_dragged_body_cells(",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_turn_handler.gd",
        [
            "dragged_body_cell_snapshot(unit.unit_id)",
            "path.path[path.path.size() - 2]",
            "move_dragged_bodies_to_cell(",
            "restore_dragged_body_cells(",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "func _dragged_body_visual_cells(",
            "func _animate_dragged_body_paths(",
            "carrier_path.size() - 1",
            "view.animate_path(body_path)",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_3_2_body_item_tests.gd",
        [
            "_find_multi_tile_path(session, actor)",
            "committed_path.path.size() - 2",
            "After a multi-tile move, the dragged body must finish in the carrier's penultimate path tile.",
            "The linked fallen character position must follow the dragged body item.",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.3.2a",
        failures,
        [
            "Dragged bodies now finish in the carrier path's penultimate tile.",
            "Rollback restores exact pre-move body cells.",
            "Player, Sprint and enemy-AI movement share the same rule.",
            "Body presentation follows the route with a one-tile delay.",
        ],
    )


if __name__ == "__main__":
    raise SystemExit(main())
