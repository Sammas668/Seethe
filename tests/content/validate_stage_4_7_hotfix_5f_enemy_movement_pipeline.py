#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5f."""
from __future__ import annotations

import argparse
from pathlib import Path

ROOT_DEFAULT = Path(__file__).resolve().parents[2]


def require(text: str, needle: str, label: str, errors: list[str]) -> None:
    if needle not in text:
        errors.append(f"{label} missing: {needle}")


def forbid(text: str, needle: str, label: str, errors: list[str]) -> None:
    if needle in text:
        errors.append(f"{label} must not contain: {needle}")


def function_body(text: str, signature: str) -> str:
    start = text.find(signature)
    if start < 0:
        return ""
    end = text.find("\n\nfunc ", start + len(signature))
    return text[start : end if end >= 0 else None]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=ROOT_DEFAULT)
    args = parser.parse_args()
    root = args.project.resolve()

    paths = {
        "planner": root / "application/tactical/ai/enemy_action_planner.gd",
        "planning_job": root / "application/tactical/ai/enemy_activation_planning_job.gd",
        "field_job": root / "domain/tactical/movement_reachable_field_job.gd",
        "handler": root / "application/tactical/ai/enemy_turn_handler.gd",
        "detection": root / "application/tactical/awareness/tactical_detection_service.gd",
        "visibility": root / "application/tactical/visibility/tactical_visibility_service.gd",
        "visibility_job": root / "application/tactical/visibility/tactical_visibility_preparation_job.gd",
        "change_set": root / "application/tactical/transactions/tactical_change_set.gd",
        "snapshot": root / "application/tactical/transactions/tactical_transaction_snapshot.gd",
        "store": root / "application/tactical/tactical_state_store.gd",
        "state": root / "domain/tactical/tactical_state.gd",
        "facade": root / "application/tactical/facades/tactical_screen_facade.gd",
        "screen": root / "presentation/tactical/tactical_screen.gd",
    }
    errors: list[str] = []
    for label, path in paths.items():
        if not path.exists():
            errors.append(f"Missing {path.relative_to(root)} ({label}).")
    if errors:
        print("Stage 4.7 Hotfix 5f enemy movement pipeline validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    text = {key: path.read_text(encoding="utf-8") for key, path in paths.items()}

    for needle in [
        "class_name EnemyActivationPlanningJob",
        'STAGE_DIRECT_ATTACK_CHECKS: StringName = &"direct_attack_checks"',
        'STAGE_REACHABLE_FIELD: StringName = &"reachable_field"',
        'STAGE_NO_TARGET_GOAL_SCAN: StringName = &"no_target_goal_scan"',
        "var processing_slices: int",
    ]:
        require(text["planning_job"], needle, "enemy_activation_planning_job.gd", errors)

    for needle in [
        "class_name MovementReachableFieldJob",
        "func step(deadline_usec: int",
        "maximum_expansions",
        "func _heap_push(",
        "func _heap_pop(",
        "pathfinding_expansions",
    ]:
        require(text["field_job"], needle, "movement_reachable_field_job.gd", errors)

    for needle in [
        "func begin_plan_activation(",
        "func step_plan_job(",
        "_step_direct_attack_checks(job)",
        "_begin_job_reachable_field(job, unit)",
        "_insert_bounded_ranged_candidate(",
        "RANGED_EXACT_SHORTLIST_SIZE: int = 12",
        "_step_no_target_goal_scan(job, deadline_usec)",
        '"reachable_field_builds"',
        '"planning_slices"',
    ]:
        require(text["planner"], needle, "enemy_action_planner.gd", errors)
    direct_pos = text["planner"].find("_step_direct_attack_checks(job)")
    field_pos = text["planner"].find("_begin_job_reachable_field(job, unit)")
    if direct_pos < 0 or field_pos < 0 or direct_pos > field_pos:
        errors.append("Direct attack checks must precede the first reachable-field build.")
    forbid(
        function_body(text["planner"], "func _step_ranged_candidate_scan("),
        "sort_custom",
        "bounded ranged candidate scan",
        errors,
    )
    forbid(
        text["planner"],
        "MovementRules.find_path(",
        "enemy planner per-candidate pathfinding",
        errors,
    )

    for needle in [
        "func peek_next_enemy_activation_unit_id() -> StringName:",
        "func has_pending_enemy_planning() -> bool:",
        '&"enemy_planning_pending"',
        "DEFAULT_AI_PLANNING_BUDGET_USEC: int = 3000",
        "_begin_destination_visibility_without_blocking(",
        '"step_visibility_preparation_job"',
        "_request_post_move_perception_refresh(unit)",
        'set_commit_validation_policy(false, false)',
        "func _validate_action_budget_state(",
        '"destination_visibility_slices"',
    ]:
        require(text["handler"], needle, "enemy_turn_handler.gd", errors)
    forbid(
        text["handler"],
        "func _prepare_plan_destination_visibility(",
        "synchronous destination-visibility preparation",
        errors,
    )

    for needle in [
        "func refresh_current_perception_for_ai_planning(",
        "func _perception_signature_for_squad(",
        "_perception_signature_by_squad",
        "_perception_refresh_skipped_count",
        "_last_perception_observer_target_pairs",
        "bypass_presentation_deferral",
    ]:
        require(text["detection"], needle, "tactical_detection_service.gd", errors)

    for needle in [
        "class_name TacticalVisibilityPreparationJob",
        "var processing_slices: int",
        "var cache_hits: int",
        "var cache_misses: int",
        "func cancel() -> void:",
    ]:
        require(text["visibility_job"], needle, "tactical_visibility_preparation_job.gd", errors)
    for needle in [
        "func begin_visibility_preparation_for_destination(",
        "func step_visibility_preparation_job(",
        "func cancel_visibility_preparation_job(",
        "allow_calculation",
        "job.result_field.merge_from(field)",
        "job.geometry_revision != _state_store.state.geometry_revision()",
        '"destination_preparation_job_slices"',
    ]:
        require(text["visibility"], needle, "tactical_visibility_service.gd", errors)

    for needle in [
        "func set_commit_validation_policy(",
        "func uses_full_state_validation() -> bool:",
        "TacticalTransactionSnapshot.capture(",
        '"last_snapshot_usec"',
        '"last_validation_usec"',
    ]:
        require(text["change_set"], needle, "tactical_change_set.gd", errors)
    require(
        text["snapshot"],
        "include_signatures: bool = true",
        "tactical_transaction_snapshot.gd",
        errors,
    )
    require(
        text["snapshot"],
        "authoritative_visibility_blocker_signature_from_occupancy(",
        "tactical_transaction_snapshot.gd",
        errors,
    )
    require(
        text["state"],
        "func authoritative_visibility_blocker_signature_from_occupancy(",
        "tactical_state.gd",
        errors,
    )
    for needle in [
        "DEVELOPMENT_FULL_AUDIT_INTERVAL: int = 32",
        "_run_development_full_state_audit_if_due(",
        "OS.is_debug_build()",
        "func performance_snapshot() -> Dictionary:",
    ]:
        require(text["store"], needle, "tactical_state_store.gd", errors)

    for needle in [
        "func peek_next_enemy_activation_unit_id() -> StringName:",
        "func has_pending_enemy_planning() -> bool:",
        '"transactions": TacticalChangeSet.performance_snapshot()',
        '"state_store": (',
    ]:
        require(text["facade"], needle, "tactical_screen_facade.gd", errors)

    for needle in [
        "_begin_side_based_enemy_activation_feedback(next_actor_id)",
        'result.code == &"enemy_planning_pending"',
        "await get_tree().process_frame",
        "carrier_duration: float = -1.0",
        "presentation_path,\n\t\t\tmovement_duration",
    ]:
        require(text["screen"], needle, "tactical_screen.gd", errors)

    if errors:
        print("Stage 4.7 Hotfix 5f enemy movement pipeline validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Stage 4.7 Hotfix 5f enemy movement pipeline validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
