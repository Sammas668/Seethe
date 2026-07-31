#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []

    for path in [
        "domain/tactical/definitions/tactical_wall_material_definition.gd",
        "presentation/tactical/walls/wall_adjacency_resolver.gd",
        "presentation/tactical/walls/tactical_wall_renderer.gd",
        "presentation/tactical/walls/tactical_fog_renderer.gd",
        "content/environment/walls/stone_wall_definition.tres",
        "content/environment/walls/wood_wall_definition.tres",
        "tests/tactical/stage_4_2_4a_wall_readability_tests.gd",
        "tests/tactical/run_stage_4_2_4a_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/tactical_map_definition.gd",
        [
            "stone_wall_tiles",
            "wood_wall_tiles",
            "func wall_material_id",
            "func wall_variant_seed",
            "func validate_definition",
            "or is_wall(tile)",
        ],
        failures,
    )
    require_tokens(
        "content/missions/farm_storehouse/movement_test_map.tres",
        [
            "stone_wall_tiles = Array[Vector2i]",
            "wood_wall_tiles = Array[Vector2i]",
            "Vector2i(8, 2)",
            "Vector2i(15, 12)",
            "Vector2i(24, 29)",
            "Vector2i(25, 29)",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "WALL_ADJACENCY_RESOLVER_SCRIPT",
            "TACTICAL_WALL_RENDERER_SCRIPT",
            "TACTICAL_FOG_RENDERER_SCRIPT",
            "STONE_WALL_DEFINITION",
            "WOOD_WALL_DEFINITION",
            "KEY_F8",
            "draw_unseen",
            "draw_explored",
            "_wall_definition_for_tile",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/walls/tactical_wall_renderer.gd",
        [
            "_draw_stone",
            "_draw_wood",
            "_draw_external_edges",
            "zoom_level < 0.55",
            "zoom_level >= 1.05",
        ],
        failures,
    )
    forbid_tokens(
        "bootstrap/boot/boot.gd",
        ['print("Seethe Stage 4.2.4 phase compatibility hotfix loaded.")'],
        failures,
    )
    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.4a",
        failures,
        [
            "Stone and wooden walls are authored separately.",
            "Walls share movement and sight authority with the tactical map.",
            "Unseen fog exposes no wall silhouette or grid pattern.",
            "Explored walls remain readable as darkened map memory.",
            "Wall detail scales across close, tactical, and far zoom.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
