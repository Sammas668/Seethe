#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []

    for path in [
        "STAGE_4_2_5_2_PER_TILE_STEALTH_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_2_5_2_PER_TILE_STEALTH_TRAIL.md",
        "presentation/tactical/icons/stealth_hood_icon.svg",
        "domain/tactical/awareness/movement_detection_tile_preview.gd",
        "domain/tactical/awareness/tactical_detection_tile_check.gd",
        "domain/tactical/awareness/movement_detection_preview.gd",
        "domain/tactical/awareness/tactical_detection_resolution.gd",
        "application/tactical/awareness/tactical_detection_service.gd",
        "application/tactical/tactical_command_handler.gd",
        "application/tactical/sprint_move_handler.gd",
        "presentation/tactical/tactical_board_view.gd",
        "presentation/tactical/tactical_unit_view.gd",
        "tests/tactical/stage_4_2_5_stealth_awareness_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/awareness/movement_detection_preview.gd",
        [
            "var tile_previews: Array[MovementDetectionTilePreview] = []",
            "func risk_tile_count() -> int:",
            "func preview_for_tile(tile: Vector2i)",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/awareness/tactical_detection_resolution.gd",
        [
            "var tile_checks: Array[TacticalDetectionTileCheck] = []",
            "var movement_stop_index: int = -1",
            "func movement_interrupted() -> bool:",
            "func committed_path(planned_path: Array[Vector2i])",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/awareness/tactical_detection_service.gd",
        [
            "for index: int in range(1, path.size()):",
            "_collect_tile_exposures",
            "_resolve_tile_check",
            "resolution.movement_stop_index = index",
            "Movement interrupted on this tile.",
            "required natural roll %s",
            '"roll_records": roll_records',
        ],
        failures,
    )
    require_tokens(
        "application/tactical/tactical_command_handler.gd",
        [
            "detection_resolution.committed_path",
            "MovementRules.calculate_path_cost",
            "actual_destination",
            "Movement stopped on the first failed Stealth tile.",
            "OperationResult.ok(committed_path_result",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/sprint_move_handler.gd",
        [
            "detection_resolution.committed_path",
            "Sprint stopped on the first failed Stealth tile.",
            "Full Action and Reaction remain spent.",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "STEALTH_HOOD_ICON",
            "func _draw_detection_badges() -> void:",
            "for tile_preview: MovementDetectionTilePreview",
            "tile_preview.display_percent()",
        ],
        failures,
    )
    forbid_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "_draw_roll_die_symbol",
            '"20"',
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            "STEALTH_HOOD_ICON",
            "draw_texture_rect(",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_2_5_stealth_awareness_tests.gd",
        [
            "_test_per_tile_preview_rolls_and_interruption",
            "preview.tile_previews.size() >= 2",
            "Movement must stop on the first square whose Stealth roll fails.",
            "The roll log must contain every Stealth roll made before interruption.",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.5.2",
        failures,
        [
            "The d20 movement badge has been removed.",
            "A shared hooded-Stealth texture is used on tokens and risky path tiles.",
            "Every perceived path tile previews its own chance to avoid detection.",
            "Movement rolls each risky tile and stops on the first failure.",
            "Ordinary movement spends only the distance actually travelled.",
            "The roll log exposes raw rolls, modifiers, DCs and required natural rolls.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
