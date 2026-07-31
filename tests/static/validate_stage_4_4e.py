#!/usr/bin/env python3
from pathlib import Path
from validation_common import *


def function_block(path: str, function_name: str) -> str:
    text = (ROOT / path).read_text(encoding="utf-8")
    marker = f"func {function_name}("
    start = text.find(marker)
    if start < 0:
        return ""
    next_func = text.find("\nfunc ", start + len(marker))
    return text[start:] if next_func < 0 else text[start:next_func]


def main() -> int:
    failures: list[str] = []
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    required_files = [
        "STAGE_4_4E_TACTICAL_GEOMETRY_PERFORMANCE_COVER_PRESENTATION_RELEASE_NOTES.txt",
        "STAGE_4_4E_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_4E_TACTICAL_GEOMETRY_PERFORMANCE_COVER_PRESENTATION.md",
        "application/tactical/queries/tactical_geometry_cache_service.gd",
        "domain/tactical/geometry/tactical_directional_cover_field.gd",
        "domain/tactical/geometry/tactical_directional_cover_field_query.gd",
        "domain/tactical/geometry/tactical_destination_preview.gd",
        "presentation/tactical/tactical_static_board_layer.gd",
        "presentation/tactical/tactical_fog_layer.gd",
        "tests/tactical/stage_4_4e_tactical_geometry_performance_cover_presentation_tests.gd",
        "tests/tactical/run_stage_4_4e_tests.gd",
    ]
    for path in required_files:
        require_file(path, failures)

    require_tokens(
        "application/tactical/queries/tactical_geometry_cache_service.gd",
        [
            "class_name TacticalGeometryCacheService",
            "const MAX_ENTRIES: int = 1024",
            '"cache_hits"',
            '"cache_misses"',
            '"five_sample_traces"',
            "state.geometry_revision()",
            "func evaluate(",
        ], failures,
    )
    require_tokens(
        "domain/tactical/geometry/tactical_directional_cover_field_query.gd",
        [
            "class_name TacticalDirectionalCoverFieldQuery",
            "const FIELD_RADIUS_TILES: int = 18",
            "const MAX_CACHE_ENTRIES: int = 256",
            "state.knowledge_state.revision",
            "func performance_snapshot()",
            "is_tile_explored",
        ], failures,
    )
    require_tokens(
        "domain/tactical/geometry/tactical_destination_preview.gd",
        [
            "class_name TacticalDestinationPreview",
            "var cover_field: TacticalDirectionalCoverField",
            "var tactical_revision: int",
            "var geometry_revision: int",
            "var knowledge_revision: int",
            "var visibility_revision: int",
            "func is_valid_for(",
        ], failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "var _destination_preview_cache: Dictionary",
            "func _destination_preview_for(",
            "func _apply_destination_preview(",
            "_destination_preview_cache_hits",
            "_destination_preview_cache_misses",
            "func _print_tactical_performance_snapshot()",
            "Life-state visuals are event-driven",
            "KEY_F9",
        ], failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "enum OverlayMode",
            "AUTOMATIC_PERCEPTION",
            "MOVEMENT_COVER",
            "ATTACK_TARGETING",
            "INTERACT",
            "COVER_FIELD_LIGHT",
            "COVER_FIELD_HEAVY",
            "COVER_FIELD_TOTAL",
            "func _draw_directional_cover_field()",
            "TacticalStaticBoardLayer",
            "TacticalFogLayer",
            "Stage 4.4e replaces that text with the bottom-left shield and cyan field",
        ], failures,
    )
    require_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            "func set_cover_category(",
            "func _draw_cover_badge()",
            "TacticalCombatGeometryResult.COVER_LIGHT",
            "TacticalCombatGeometryResult.COVER_HEAVY",
            "TacticalCombatGeometryResult.COVER_TOTAL",
            '&"neutral"',
        ], failures,
    )
    require_tokens(
        "application/tactical/visibility/tactical_visibility_service.gd",
        [
            "_peek_additional_los_trace_count",
            "additional_peek_only",
            "centre_visible",
            "observation_origin_cache",
            "func performance_snapshot()",
        ], failures,
    )
    require_tokens(
        "domain/tactical/geometry/tactical_observation_origin_query.gd",
        [
            "const MAX_CACHE_ENTRIES: int = 512",
            "static var _origin_cache: Dictionary",
            "free Peek rule",
            "func performance_snapshot()",
        ], failures,
    )
    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "TacticalGeometryCacheService",
            "_geometry_cache.evaluate(",
            "centre shot",
            "direction.dot",
            "func performance_snapshot()",
        ], failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_action_planner.gd",
        [
            "const RANGED_EXACT_SHORTLIST_SIZE: int = 12",
            "cheap_candidates",
            "exact_count",
            "_cheap_ranged_position_score",
            "_ranged_exact_candidates_evaluated",
            "func performance_snapshot()",
        ], failures,
    )
    require_tokens(
        "presentation/tactical/tactical_static_board_layer.gd",
        [
            "class_name TacticalStaticBoardLayer",
            "func refresh_environment()",
            '"redraw_count"',
        ], failures,
    )
    require_tokens(
        "presentation/tactical/tactical_fog_layer.gd",
        [
            "class_name TacticalFogLayer",
            "func refresh_fog()",
            '"redraw_count"',
        ], failures,
    )
    require_tokens(
        "tests/tactical/stage_4_4e_tactical_geometry_performance_cover_presentation_tests.gd",
        [
            "_test_combat_geometry_cache_reuses_exact_result",
            "_test_observation_origins_are_cached_without_spending_capacity",
            "_test_directional_cover_field_is_cached_and_knowledge_bound",
            "_test_destination_preview_revision_contract",
            "_test_performance_snapshot_exposes_optimisation_counters",
        ], failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.4e",
            "CYAN DIRECTIONAL-COVER FIELD",
            "run_stage_4_4e_tests.gd",
            "validate_stage_4_4e.py",
            "STAGE 4.4d",
        ], failures,
    )
    require_tokens(
        "SEETHE_PROJECT_STRUCTURE_GUIDE_V2.md",
        [
            "Stage 4.4e — Tactical Geometry Performance and Cover Presentation",
            "TacticalGeometryCacheService",
            "TacticalDestinationPreview",
            "TacticalStaticBoardLayer",
            "automatic perception overlay",
        ], failures,
    )

    hover_block = function_block(
        "presentation/tactical/tactical_screen.gd", "_on_board_tile_hovered"
    )
    if not hover_block:
        failures.append("Missing _on_board_tile_hovered function.")
    else:
        if hover_block.count("_refresh_hud()") != 1:
            failures.append("Hover must refresh the HUD exactly once.")
        if hover_block.count("_refresh_board_view()") != 1:
            failures.append("Hover must refresh the board exactly once.")
        if "tile == _hovered_tile" not in hover_block:
            failures.append("Hover must ignore unchanged cursor tiles.")

    process_block = function_block("presentation/tactical/tactical_screen.gd", "_process")
    if "reconcile" in process_block.lower() or "life_state" in process_block.lower():
        failures.append("The per-frame screen process must not reconcile life-state visuals.")

    draw_block = function_block("presentation/tactical/tactical_board_view.gd", "_draw")
    if "_draw_board()" in draw_block:
        failures.append("Dynamic board draw must not rebuild the legacy complete board.")
    if "_draw_selected_cover_ring()" in draw_block:
        failures.append("The obsolete selected-character cover ring must not be drawn.")
    if "_draw_perception_overlays()" not in draw_block or "_draw_directional_cover_field()" not in draw_block:
        failures.append("Board draw must switch exclusively between perception and cover overlays.")

    if failures:
        print("Stage 4.4e static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Stage 4.4e static validation passed.")
    print(" - Hover owns one preview, one HUD update and one dynamic redraw.")
    print(" - Shared bounded caches cover geometry, destination previews, Peek origins and cyan fields.")
    print(" - Automatic perception and movement cover use mutually exclusive tile overlays.")
    print(" - Bottom-left token shields replace the scattered cover-ring presentation.")
    print(" - Static environment, fog and dynamic tactical drawing are separated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
