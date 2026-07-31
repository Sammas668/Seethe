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
        "STAGE_4_4E2_CRITICAL_INTERACTION_COVER_MOVEMENT_PIPELINE_RELEASE_NOTES.txt",
        "STAGE_4_4E2_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_4E2_CRITICAL_INTERACTION_COVER_MOVEMENT_PIPELINE.md",
        "domain/tactical/tactical_map_runtime_index.gd",
        "domain/tactical/tactical_invalidation_flags.gd",
        "domain/tactical/geometry/tactical_local_cover_result.gd",
        "domain/tactical/geometry/tactical_local_cover_query.gd",
        "tests/tactical/stage_4_4e2_critical_interaction_cover_movement_tests.gd",
        "tests/tactical/run_stage_4_4e2_tests.gd",
    ]
    for path in required_files:
        require_file(path, failures)

    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "signal interaction_target_clicked",
            "func _interaction_target_at_screen_position(",
            "func _distance_to_segment(",
            "adjacent_interactable_openings",
            "adjacent_interactable_structures",
            '"target_kind": &"opening"',
            '"target_kind": &"structure"',
        ], failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "interaction_target_clicked.connect",
            "func _on_board_interaction_target_clicked(",
            "func _schedule_post_commit_perception_flush()",
            "func _flush_post_commit_perception()",
            "flush_requested_perception_refreshes",
        ], failures,
    )
    require_tokens(
        "domain/tactical/geometry/tactical_local_cover_query.gd",
        [
            "class_name TacticalLocalCoverQuery",
            "func evaluate_position(",
            "strongest_local_cover",
            "HEIGHT_LOW",
            "HEIGHT_HIGH",
            "HEIGHT_FULL",
            "COVER_HEAVY",
        ], failures,
    )
    require_tokens(
        "application/tactical/facades/tactical_screen_facade.gd",
        [
            "func local_cover_at(",
            "TacticalLocalCoverQuery.evaluate_position",
            "local.strongest_local_cover",
            "func flush_requested_perception_refreshes()",
        ], failures,
    )
    require_tokens(
        "core/results/operation_result.gd",
        [
            "STATUS_REJECTED_BEFORE_COMMIT",
            "STATUS_COMMITTED",
            "STATUS_COMMITTED_WITH_WARNING",
            "var committed_revision",
            "static func committed(",
            "static func committed_with_warning(",
        ], failures,
    )
    for path in [
        "application/tactical/tactical_command_handler.gd",
        "application/tactical/sprint_move_handler.gd",
        "application/tactical/facing/facing_handler.gd",
        "application/tactical/combat/attack_handler.gd",
    ]:
        require_tokens(path, [
            "request_current_perception_for_squad",
            "OperationResult.committed(",
        ], failures)
        text = (ROOT / path).read_text(encoding="utf-8")
        if "perception_refresh_failed" in text:
            failures.append(f"{path} still reports ordinary failure after a committed action.")

    require_tokens(
        "application/tactical/tactical_command_handler.gd",
        [
            "a newly opened door always commits as a separate",
            "required to cross",
            "paused before crossing the opening",
        ], failures,
    )
    require_tokens(
        "application/tactical/visibility/tactical_visibility_service.gd",
        [
            "state_changed_with_flags.connect",
            "func _on_tactical_state_changed_with_flags(",
            "TacticalChangeSet.new(",
            '&"exploration_updated"',
            "func _apply_exploration_batches(",
        ], failures,
    )
    exploration_block = function_block(
        "application/tactical/visibility/tactical_visibility_service.gd",
        "_commit_exploration_batch",
    )
    if "knowledge_state.mark_many_explored" in exploration_block:
        failures.append("Exploration commit must not mutate knowledge directly outside TacticalChangeSet.")

    require_tokens(
        "domain/tactical/tactical_map_runtime_index.gd",
        [
            "PackedByteArray",
            "FLAG_BLOCKS_MOVEMENT",
            "barrier_by_edge",
            "opening_by_edge",
            "structure_by_edge",
            "func opening_at_edge(",
            "func structure_at_edge(",
        ], failures,
    )
    require_tokens(
        "domain/tactical/tactical_map_definition.gd",
        [
            "var _runtime_index_cache",
            "func runtime_index()",
            "func invalidate_runtime_index()",
            "runtime_index().opening_at_edge",
            "runtime_index().structure_at_edge",
        ], failures,
    )
    require_tokens(
        "domain/tactical/tactical_state.gd",
        [
            "var occupancy_revision",
            "var visibility_blocker_revision",
            "func spatial_occupancy_revision()",
            "func spatial_visibility_blocker_revision()",
        ], failures,
    )
    geometry_key = function_block(
        "application/tactical/queries/tactical_geometry_cache_service.gd",
        "_cache_key",
    )
    if "state.revision" in geometry_key:
        failures.append("Geometry cache still invalidates on the entire tactical revision.")
    for token in [
        "spatial_occupancy_revision",
        "geometry_revision",
        "spatial_visibility_blocker_revision",
    ]:
        if token not in geometry_key:
            failures.append(f"Geometry cache key is missing {token}.")

    require_tokens(
        "domain/tactical/tactical_invalidation_flags.gd",
        [
            "class_name TacticalInvalidationFlags",
            "occupancy_changed",
            "visibility_changed",
            "exploration_changed",
            "geometry_changed",
            "inventory_changed",
            "static func for_reason",
        ], failures,
    )
    require_tokens(
        "application/tactical/tactical_state_store.gd",
        [
            "signal state_changed_with_flags",
            "change_set.invalidation_flags",
        ], failures,
    )
    require_tokens(
        "tests/tactical/stage_4_4e2_critical_interaction_cover_movement_tests.gd",
        [
            "_test_runtime_map_index_matches_authored_map",
            "_test_local_wall_cover_uses_full_shield_category",
            "_test_committed_result_cannot_be_reported_as_rejected",
            "_test_closed_door_is_a_separate_movement_boundary",
            "_test_exploration_batch_commits_through_state_store",
            "_test_edge_native_interaction_hit_target",
        ], failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.4e2",
            "EDGE-NATIVE INTERACT",
            "LOCAL PHYSICAL COVER",
            "COMMITTED ACTION SEMANTICS",
            "RUNTIME MAP INDEX",
        ], failures,
    )
    require_tokens(
        "SEETHE_PROJECT_STRUCTURE_GUIDE_V2.md",
        [
            "Stage 4.4e2 — Critical Interaction, Cover and Movement-Pipeline Correction",
            "TacticalMapRuntimeIndex",
            "TacticalLocalCoverQuery",
            "TacticalInvalidationFlags",
        ], failures,
    )

    if failures:
        print("Stage 4.4e2 static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Stage 4.4e2 static validation passed.")
    print(" - Interact selects exact highlighted edge feature IDs.")
    print(" - Token shields report local physical cover while attacks keep exact cover.")
    print(" - Committed actions queue perception rather than failing after commit.")
    print(" - Door crossing is separated from opening and exploration commits atomically.")
    print(" - Runtime map indexes and spatial cache revisions replace hot linear scans.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
