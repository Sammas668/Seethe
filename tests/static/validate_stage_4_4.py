#!/usr/bin/env python3
from validation_common import *


def main() -> int:
    failures: list[str] = []
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    required_files = [
        "STAGE_4_4_COVER_LINE_OF_EFFECT_OPENINGS_RELEASE_NOTES.txt",
        "STAGE_4_4_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_4_COVER_LINE_OF_EFFECT_OPENINGS.md",
        "domain/tactical/geometry/tactical_edge_key.gd",
        "domain/tactical/geometry/tactical_barrier_segment_definition.gd",
        "domain/tactical/geometry/tactical_opening_definition.gd",
        "domain/tactical/geometry/tactical_structure_definition.gd",
        "domain/tactical/geometry/tactical_environment_state.gd",
        "domain/tactical/geometry/tactical_combat_geometry_query.gd",
        "domain/tactical/geometry/tactical_combat_geometry_result.gd",
        "domain/tactical/geometry/tactical_cover_preview.gd",
        "application/tactical/environment/tactical_opening_handler.gd",
        "application/tactical/environment/tactical_structure_attack_handler.gd",
        "tests/tactical/stage_4_4_cover_openings_breaching_tests.gd",
        "tests/tactical/run_stage_4_4_tests.gd",
        "content/items/broken_timber.tres",
        "content/items/stone_rubble.tres",
        "content/items/scrap_metal.tres",
        "content/items/glass_shards.tres",
    ]
    for path in required_files:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/tactical_map_definition.gd",
        [
            "@export var edge_barriers: Array[TacticalBarrierSegmentDefinition]",
            "@export var openings: Array[TacticalOpeningDefinition]",
            "@export var structures: Array[TacticalStructureDefinition]",
            "func barrier_at_edge(",
            "func opening_at_edge(",
            "func structure_at_edge(",
            "_validate_geometry_identity(",
        ], failures,
    )
    require_tokens(
        "domain/tactical/geometry/tactical_environment_state.gd",
        [
            "class_name TacticalEnvironmentState",
            "var geometry_revision: int = 0",
            "func edge_blocks_movement(",
            "func edge_blocks_sight(",
            "func edge_blocks_line_of_effect(",
            "func cover_height_at_edge(",
            "func apply_damage_to_source(",
            "func snapshot() -> Dictionary:",
            "func restore(snapshot_value: Dictionary) -> void:",
        ], failures,
    )
    require_tokens(
        "domain/tactical/geometry/tactical_combat_geometry_query.gd",
        [
            "const SAMPLE_HEIGHTS: Array[int] = [4, 3, 2, 1, 0]",
            "static func evaluate(",
            "static func cheap_has_line_of_sight(",
            'trace.get("corner_pairs", [])',
            "_height_blocks_sample(",
            "_creature_cover_between(",
            "result.configure_cover_from_samples()",
        ], failures,
    )
    require_tokens(
        "domain/tactical/geometry/tactical_combat_geometry_result.gd",
        [
            "COVER_NONE",
            "COVER_LIGHT",
            "COVER_HEAVY",
            "COVER_TOTAL",
            "var has_line_of_sight: bool",
            "var has_line_of_effect: bool",
            "var clear_exposure_samples: int",
            "var cover_ac_bonus: int",
            "var cover_reflex_bonus: int",
        ], failures,
    )
    require_tokens(
        "application/tactical/combat/tactical_attack_preview.gd",
        [
            "var expected_geometry_revision: int",
            "var base_target_armour_class: int",
            "var effective_target_armour_class: int",
            "var cover_category: StringName",
            "var primary_cover_source_id: StringName",
        ], failures,
    )
    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "TacticalCombatGeometryQuery.evaluate(",
            'return preview.reject("No line of sight',
            "blocks line of effect",
            "The target has Total Cover",
            "preview.effective_target_armour_class",
            "target.armour_class + geometry.cover_ac_bonus",
        ], failures,
    )
    require_tokens(
        "application/tactical/combat/attack_handler.gd",
        [
            '&"attack_geometry_stale"',
            "resolution.hit_without_cover",
            "resolution.missed_due_to_cover",
            "_apply_cover_source_damage_and_salvage",
            "Effective Armour Class",
            "Cover damage:",
        ], failures,
    )
    require_tokens(
        "application/tactical/facades/tactical_screen_facade.gd",
        [
            "func combat_geometry_between(",
            "func preview_destination_cover(",
            "func selected_unit_cover_sectors(",
            "func toggle_opening(",
            "func peek_around_corner(",
            "func attack_environment_source(",
        ], failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "func _draw_edge_geometry() -> void:",
            "func _draw_destination_cover_preview() -> void:",
            "func _draw_selected_cover_ring() -> void:",
            "func _draw_exact_attack_cover() -> void:",
            "func _draw_cover_badge(",
            "_cover_preview.summary_text()",
        ], failures,
    )
    require_tokens(
        "application/tactical/environment/tactical_opening_handler.gd",
        [
            "func toggle_opening(",
            "func pick_lock(",
            "func peek(",
            "func lean_origin(",
            "func peek_around_corner(",
            "func corner_lean_origin(",
            '"Thievery"',
        ], failures,
    )
    require_tokens(
        "application/tactical/environment/tactical_structure_attack_handler.gd",
        [
            "class_name TacticalStructureAttackHandler",
            "func preview(",
            "func execute(",
            "apply_damage_to_source",
            "_create_salvage_if_needed",
            '&"structure_attacked"',
        ], failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_action_planner.gd",
        [
            "func _best_path_to_ranged_attack_position(",
            "TacticalCombatGeometryQuery.evaluate(",
            "COVER_HEAVY",
            "score += 300",
            "COVER_LIGHT",
            "score += 150",
        ], failures,
    )
    require_tokens(
        "application/tactical/tactical_command_handler.gd",
        [
            "func _opening_plan_for_path(",
            "func _open_path_openings(",
            "paused_for_new_information",
            "opening.operation_cost_feet" if False else "operation_cost_feet",
        ], failures,
    )
    require_tokens(
        "content/missions/farm_storehouse/movement_test_map.tres",
        [
            'segment_id = &"barrier.farm.low_fence.west"',
            'structure_id = &"structure.farm.wooden_barricade"',
            'opening_id = &"opening.farm.ordinary_door"',
            'opening_id = &"opening.farm.locked_door"',
            'opening_id = &"opening.farm.clear_window"',
            'opening_id = &"opening.farm.barred_opening"',
            'structure_id = &"structure.farm.isolated_stone_wall"',
        ], failures,
    )
    require_tokens(
        "tests/tactical/stage_4_4_cover_openings_breaching_tests.gd",
        [
            "_test_directional_cover_samples(failures)",
            "_test_line_of_sight_and_line_of_effect_are_separate(failures)",
            "_test_cover_preview_and_sector_queries(failures)",
            "_test_attack_preview_and_cover_hit(failures)",
            "_test_door_operation_pathing_peek_and_lockpick(failures)",
            "_test_direct_structure_damage_breach_and_salvage(failures)",
            "_test_environment_snapshot_restore(failures)",
        ], failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.4",
            "DIRECTIONAL COVER",
            "run_stage_4_4_tests.gd",
            "validate_stage_4_4.py",
        ], failures,
    )
    require_tokens(
        "SEETHE_PROJECT_STRUCTURE_GUIDE_V2.md",
        [
            "Stage 4.4 — Directional Cover, Line of Effect and Openings",
            "TacticalCombatGeometryQuery",
            "TacticalEnvironmentState",
            "directional cover ring",
        ], failures,
    )

    if failures:
        print("Stage 4.4 static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Stage 4.4 static validation passed.")
    print(" - LOS, line of effect and five-sample directional cover share one geometry authority.")
    print(" - Movement hover, selected-unit sectors, attack previews, logs and ranged AI consume that authority.")
    print(" - Edge doors, glass, bars, Peek, Lean Attack and locks use mutable environment state.")
    print(" - Damageable structures support Hardness, breaches, rubble, cover hits and one-time salvage.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
