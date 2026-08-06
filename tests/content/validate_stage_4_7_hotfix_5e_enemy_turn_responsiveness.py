#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5e."""
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=ROOT_DEFAULT)
    args = parser.parse_args()
    root = args.project.resolve()

    paths = {
        "field": root / "domain/tactical/movement_reachable_field.gd",
        "movement": root / "domain/tactical/movement_rules.gd",
        "plan": root / "application/tactical/ai/enemy_action_plan.gd",
        "planner": root / "application/tactical/ai/enemy_action_planner.gd",
        "planning_job": root / "application/tactical/ai/enemy_activation_planning_job.gd",
        "field_job": root / "domain/tactical/movement_reachable_field_job.gd",
        "handler": root / "application/tactical/ai/enemy_turn_handler.gd",
        "facade": root / "application/tactical/facades/tactical_screen_facade.gd",
        "screen": root / "presentation/tactical/tactical_screen.gd",
        "view": root / "presentation/tactical/tactical_unit_view.gd",
    }
    errors: list[str] = []
    for label, path in paths.items():
        if not path.exists():
            errors.append(f"Missing {path.relative_to(root)} ({label}).")
    if errors:
        print("Stage 4.7 Hotfix 5e validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    text = {key: path.read_text(encoding="utf-8") for key, path in paths.items()}

    for needle in [
        "class_name MovementReachableField",
        "var cost_by_key: Dictionary",
        "var predecessor_by_key: Dictionary",
        "func path_to(tile: Vector2i) -> MovementPathResult:",
        "func reachable_tile_count() -> int:",
        "pathfinding_expansions",
    ]:
        require(text["field"], needle, "movement_reachable_field.gd", errors)

    for needle in [
        "static func build_reachable_field(",
        "func _heap_push(",
        "func _heap_pop(",
        "func _heap_entry_precedes(",
        "MovementReachableField",
    ]:
        require(text["movement"], needle, "movement_rules.gd", errors)
    forbid(text["movement"], "func _pop_lowest", "movement_rules.gd", errors)

    for needle in [
        "var _move_path: Array[Vector2i]",
        "var move_path: Array[Vector2i]:",
        "move_path_value: Array[Vector2i] = []",
    ]:
        require(text["plan"], needle, "enemy_action_plan.gd", errors)

    for needle in [
        "func begin_plan_activation(",
        "func step_plan_job(",
        "_begin_job_reachable_field(job, unit)",
        "job.reachable_field.path_to(",
        "RANGED_EXACT_SHORTLIST_SIZE",
        "func last_plan_diagnostics() -> Dictionary:",
        '"reachable_field_usec"',
        '"candidate_scoring_usec"',
        '"exact_geometry_usec"',
        '"pathfinding_expansions"',
    ]:
        require(text["planner"], needle, "enemy_action_planner.gd", errors)
    for needle in [
        "class_name EnemyActivationPlanningJob",
        "STAGE_DIRECT_ATTACK_CHECKS",
        "STAGE_REACHABLE_FIELD",
    ]:
        require(text["planning_job"], needle, "enemy_activation_planning_job.gd", errors)
    for needle in [
        "class_name MovementReachableFieldJob",
        "func step(deadline_usec: int",
        "func _heap_push(",
        "func _heap_pop(",
    ]:
        require(text["field_job"], needle, "movement_reachable_field_job.gd", errors)
    forbid(
        text["planner"],
        "MovementRules.find_path(",
        "enemy_action_planner.gd must not launch per-candidate A* searches",
        errors,
    )
    if text["planner"].count("_begin_job_reachable_field(job, unit)") < 1:
        errors.append(
            "enemy_action_planner.gd must create the shared reachable field lazily."
        )

    resolve_enemy_start = text["handler"].find(
        "func resolve_enemy_turn() -> OperationResult:"
    )
    resolve_enemy_end = text["handler"].find("\n\nfunc ", resolve_enemy_start + 1)
    resolve_enemy_body = text["handler"][
        resolve_enemy_start : resolve_enemy_end if resolve_enemy_end != -1 else None
    ]
    for needle in [
        "var result: OperationResult = resolve_next_enemy_activation()",
        '&"reaction_pending"',
        '&"enemy_turn_completed"',
        "return result",
    ]:
        require(resolve_enemy_body, needle, "resolve_enemy_turn return contract", errors)
    forbid(
        resolve_enemy_body,
        "while true:",
        "resolve_enemy_turn must expose a statically provable return path",
        errors,
    )

    for needle in [
        "func resolve_next_enemy_activation(",
        '&"enemy_activation_completed"',
        '&"enemy_turn_completed"',
        "func _move_path_from_plan(plan: RefCounted) -> Array[Vector2i]:",
        "MovementRules.calculate_path_cost(",
        "func record_last_presentation_timing(presentation_usec: int) -> void:",
        '"slowest": _slow_activation_history.duplicate(true)',
        '"start_effects"',
        '"support_and_rescue"',
        '"perception"',
        '"ability_selection"',
        '"planning"',
        '"reachable_field"',
        '"candidate_scoring"',
        '"exact_geometry"',
        '"reaction_scan"',
        '"movement_commit"',
        '"attack_commit"',
        '"finish_activation"',
    ]:
        require(text["handler"], needle, "enemy_turn_handler.gd", errors)

    for needle in [
        "func resolve_next_enemy_activation(",
        "func enemy_ai_performance_snapshot() -> Dictionary:",
        "func record_last_ai_presentation_timing(presentation_usec: int) -> void:",
    ]:
        require(text["facade"], needle, "tactical_screen_facade.gd", errors)

    for needle in [
        "const ACTIVATION_HANDOFF_SECONDS: float = 0.0",
        "const AI_MOVE_TO_ATTACK_SECONDS: float = 0.0",
        "const PHASE_HANDOFF_SECONDS: float = 0.0",
        "const AI_VISIBLE_MOVE_MAX_SECONDS: float =",
        "const ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC: int = 8000",
        "func _movement_animation_duration(",
        "_facade.resolve_next_enemy_activation(remaining_budget_usec)",
        "_enemy_phase_hidden_activations_batched",
        "await get_tree().process_frame",
        "_facade.record_last_ai_presentation_timing(",
    ]:
        require(text["screen"], needle, "tactical_screen.gd", errors)

    enemy_phase_start = text["screen"].find(
        "func _resolve_enemy_phase_with_reaction_prompts() -> OperationResult:"
    )
    enemy_phase_end = text["screen"].find("\n\nfunc ", enemy_phase_start + 1)
    enemy_phase_body = text["screen"][
        enemy_phase_start : enemy_phase_end if enemy_phase_end != -1 else None
    ]
    for needle in [
        "resolve_next_enemy_activation",
        "ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC",
        'result.code == &"enemy_turn_completed"',
    ]:
        require(enemy_phase_body, needle, "responsive Enemy Phase loop", errors)

    for needle in [
        "total_movement_duration: float = -1.0",
        "step_duration = total_movement_duration / float(movement_steps)",
    ]:
        require(text["view"], needle, "tactical_unit_view.gd", errors)

    if errors:
        print("Stage 4.7 Hotfix 5e enemy-turn responsiveness validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Stage 4.7 Hotfix 5e enemy-turn responsiveness validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
