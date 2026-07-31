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
        "STAGE_4_4E1_COVER_UI_MOVEMENT_ANIMATION_HOTFIX_RELEASE_NOTES.txt",
        "STAGE_4_4E1_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_4E1_COVER_UI_MOVEMENT_ANIMATION_HOTFIX.md",
        "tests/tactical/stage_4_4e1_cover_ui_movement_animation_hotfix_tests.gd",
        "tests/tactical/run_stage_4_4e1_tests.gd",
    ]
    for path in required_files:
        require_file(path, failures)

    require_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            "signal movement_animation_finished",
            "func is_movement_animating()",
            "func animate_path(",
            "movement_animation_finished.emit(unit_id)",
            "authoritative state may already be at the destination",
            "TacticalCombatGeometryResult.COVER_LIGHT",
            "TacticalCombatGeometryResult.COVER_HEAVY",
            "Total Cover is reported as Blocked",
        ], failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "signal movement_presentation_finished",
            "var _movement_commit_in_progress: bool",
            "var _movement_animation_active: bool",
            "var _animating_unit_ids: Dictionary",
            "var _deferred_state_change_reasons: Dictionary",
            "var _deferred_damage_events: Array[Dictionary]",
            "func _begin_movement_presentation_batch(",
            "func _finish_movement_presentation()",
            "func _is_unit_presentation_animating(",
            "begin_visibility_recalculation_deferral",
            "end_visibility_recalculation_deferral",
            "result.automatic_peek_origins.clear()",
            "func _cover_icon_category(",
        ], failures,
    )
    require_tokens(
        "application/tactical/facades/tactical_screen_facade.gd",
        [
            "signal movement_committed(event: Dictionary)",
            "func begin_visibility_recalculation_deferral()",
            "func end_visibility_recalculation_deferral()",
            "begin_perception_recalculation_deferral",
            "end_perception_recalculation_deferral",
        ], failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_turn_handler.gd",
        [
            "signal movement_committed(event: Dictionary)",
            "movement_committed.emit({",
            '"dragged_body_cells_before"',
        ], failures,
    )
    require_tokens(
        "application/tactical/visibility/tactical_visibility_service.gd",
        [
            "_recalculation_deferral_depth",
            "_deferred_recalculation_pending",
            "func begin_recalculation_deferral()",
            "func end_recalculation_deferral()",
        ], failures,
    )
    require_tokens(
        "application/tactical/awareness/tactical_detection_service.gd",
        [
            "_perception_recalculation_deferral_depth",
            "_deferred_perception_squad_ids",
            "func begin_perception_recalculation_deferral()",
            "func end_perception_recalculation_deferral()",
            "Perception refresh deferred until movement presentation completes.",
        ], failures,
    )
    require_tokens(
        "domain/tactical/geometry/tactical_directional_cover_field_query.gd",
        [
            "const FIELD_RADIUS_TILES: int = 18",
            "const PROJECTION_LENGTH_TILES: int = 8",
            "const PROJECTION_HALF_WIDTH_TILES: int = 4",
            "func _project_directional_wedge(",
            '"projected_tile_checks"',
            "does not scan a bounding square",
        ], failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "hypothetical/automatic Peek markers are not drawn during hover",
            "avoids per-tile hatch loops",
            "TacticalCombatGeometryResult.COVER_LIGHT",
            "TacticalCombatGeometryResult.COVER_HEAVY",
            "COVER_TOTAL, COVER_NONE and &\"neutral\" intentionally draw nothing",
        ], failures,
    )
    require_tokens(
        "tests/tactical/stage_4_4e1_cover_ui_movement_animation_hotfix_tests.gd",
        [
            "_test_cover_token_accepts_only_context_categories",
            "_test_movement_view_starts_without_authoritative_snap",
            "_test_directional_cover_field_uses_bounded_projection",
            "_test_visibility_and_perception_deferral_is_balanced",
            "_test_automatic_peek_remains_free_after_hotfix",
        ], failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.4e1",
            "TWO COVER ICONS",
            "MOVEMENT ANIMATION BOUNDARY",
            "run_stage_4_4e1_tests.gd",
            "validate_stage_4_4e1.py",
        ], failures,
    )
    require_tokens(
        "SEETHE_PROJECT_STRUCTURE_GUIDE_V2.md",
        [
            "Stage 4.4e1 — Cover UI Simplification and Movement Animation Hotfix",
            "movement_animation_finished",
            "visibility recalculation deferral",
            "one contextual shield",
        ], failures,
    )

    cover_icon_block = function_block(
        "presentation/tactical/tactical_screen.gd", "_cover_icon_category"
    )
    if not cover_icon_block:
        failures.append("Missing _cover_icon_category function.")
    else:
        if "COVER_LIGHT" not in cover_icon_block or "COVER_HEAVY" not in cover_icon_block:
            failures.append("The contextual shield filter must retain Light and Heavy Cover.")
        if "COVER_TOTAL" in cover_icon_block or 'neutral' in cover_icon_block:
            failures.append("Total and neutral states must not receive token shields.")

    destination_block = function_block(
        "presentation/tactical/tactical_screen.gd", "_destination_preview_for"
    )
    if "preview_movement_detection" not in destination_block:
        failures.append("Clicked movement planning must retain the bounded Stealth preview.")
    if "observation_origins_for_unit" in destination_block:
        failures.append("Movement hover must not calculate hypothetical automatic Peek origins.")
    if "result.automatic_peek_origins.clear()" not in destination_block:
        failures.append("Movement destination previews must explicitly contain no Peek markers.")

    draw_block = function_block("presentation/tactical/tactical_board_view.gd", "_draw")
    if "_draw_automatic_peek_markers()" in draw_block:
        failures.append("Dynamic hover drawing must not draw automatic Peek markers.")
    if "_draw_physical_edge_cover(" in draw_block:
        failures.append("The obsolete edge-shield cluster must not be drawn.")

    field_block = function_block(
        "presentation/tactical/tactical_board_view.gd", "_draw_directional_cover_field"
    )
    if "while " in field_block:
        failures.append("The cyan field must not run a per-tile hatch loop.")

    snap_block = function_block("presentation/tactical/tactical_unit_view.gd", "snap_to_tile")
    if "is_movement_animating()" not in snap_block or "return" not in snap_block:
        failures.append("snap_to_tile must refuse to snap an active movement tween.")

    confirm_block = function_block(
        "presentation/tactical/tactical_screen.gd", "_confirm_planned_movement"
    )
    if "_refresh_all_presentation" in confirm_block or "_refresh_board_view" in confirm_block:
        failures.append("Committed player movement must begin animation before a full presentation refresh.")
    if "_begin_movement_presentation" not in confirm_block:
        failures.append("Committed player movement must enter the animation boundary.")

    if failures:
        print("Stage 4.4e1 static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Stage 4.4e1 static validation passed.")
    print(" - Cover tokens are limited to one contextual Light/Heavy shield.")
    print(" - Empty-tile hover performs no planning; clicked routes retain bounded Stealth information.")
    print(" - Cyan cover projection and drawing are bounded and low-call.")
    print(" - Player and AI movement animate before deferred visibility/presentation refresh.")
    print(" - Active movement tweens cannot be snapped to the committed destination early.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
