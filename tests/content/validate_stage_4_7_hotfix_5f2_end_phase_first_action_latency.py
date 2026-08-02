#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5f2."""
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
        "handler": root / "application/tactical/ai/enemy_turn_handler.gd",
        "facade": root / "application/tactical/facades/tactical_screen_facade.gd",
        "screen": root / "presentation/tactical/tactical_screen.gd",
        "visibility": root / "application/tactical/visibility/tactical_visibility_service.gd",
        "doc": root / "docs/architecture/STAGE_4_7_HOTFIX_5F2_END_PHASE_FIRST_ACTION_LATENCY.md",
    }
    errors: list[str] = []
    for label, path in paths.items():
        if not path.exists():
            errors.append(f"Missing {path.relative_to(root)} ({label}).")
    if errors:
        print("Stage 4.7 Hotfix 5f2 latency validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    text = {key: path.read_text(encoding="utf-8") for key, path in paths.items()}
    handler = text["handler"]
    screen = text["screen"]
    facade = text["facade"]
    planner = text["planner"]

    for needle in [
        "DEFAULT_AI_PLANNING_BUDGET_USEC: int = 3000",
        "func has_pending_enemy_destination_visibility() -> bool:",
        "func step_pending_enemy_destination_visibility(",
        "func cancel_pending_enemy_destination_visibility() -> void:",
        "func _begin_destination_visibility_without_blocking(",
        "func _reconcile_destination_visibility_after_commit(",
        '"destination_visibility_pending": has_pending_enemy_destination_visibility()',
        "_clear_pending_planning_job(false, false)",
    ]:
        require(handler, needle, "enemy_turn_handler.gd", errors)

    planning_state = function_body(handler, "func has_pending_enemy_planning() -> bool:")
    plan_ready = function_body(handler, "func is_enemy_plan_ready_to_commit() -> bool:")
    forbid(planning_state, "_pending_visibility_job", "planning readiness", errors)
    forbid(plan_ready, "_pending_visibility_job", "plan commitment readiness", errors)
    begin_visibility = function_body(
        handler, "func _begin_destination_visibility_without_blocking("
    )
    require(
        begin_visibility,
        "_store_completed_plan_for_commit(unit, plan, refresh_budget)",
        "non-blocking destination visibility",
        errors,
    )
    forbid(
        begin_visibility,
        "step_visibility_preparation_job",
        "pre-movement visibility gate",
        errors,
    )

    for needle in [
        "func has_pending_enemy_destination_visibility() -> bool:",
        "func step_pending_enemy_destination_visibility(budget_usec: int = 3000) -> bool:",
        "func cancel_pending_enemy_destination_visibility() -> void:",
        '"resolve_next_enemy_activation", maxi(250, budget_usec)',
        '"resolve_initiative_activation", active_id, maxi(250, budget_usec)',
    ]:
        require(facade, needle, "tactical_screen_facade.gd", errors)

    for needle in [
        "const HIDDEN_AI_VISIBILITY_FAST_BUDGET_USEC: int = 16000",
        "_facade.resolve_next_enemy_activation(remaining_budget_usec)",
        "_facade.resolve_active_ai_initiative(remaining_budget_usec)",
        "if resuming_reaction or plan_ready:",
        "func _pump_ai_destination_visibility_during_movement() -> void:",
        "func _complete_pending_ai_destination_visibility(",
        "call_deferred(\"_pump_ai_destination_visibility_during_movement\")",
        "func _complete_pending_ai_destination_visibility(",
        "HIDDEN_AI_VISIBILITY_FAST_BUDGET_USEC",
        '"end_phase_to_first_visible_movement_usec"',
        '"frames_yielded_before_first_visible_action"',
        '"hidden_actors_before_first_visible_action"',
    ]:
        require(screen, needle, "tactical_screen.gd", errors)

    side_loop = function_body(
        screen, "func _resolve_enemy_phase_with_reaction_prompts() -> OperationResult:"
    )
    forbid(
        side_loop,
        "if resuming_reaction or plan_ready or not had_pending_planning:",
        "planning-only visibility deferral",
        errors,
    )
    ready_start = side_loop.find('if result.code == &"enemy_plan_ready":')
    presentation_start = side_loop.find("_begin_side_based_enemy_activation_presentation")
    ready_branch = side_loop[ready_start:presentation_start] if ready_start >= 0 else ""
    forbid(
        ready_branch,
        "await get_tree().process_frame",
        "plan-ready render boundary",
        errors,
    )

    for needle in [
        "job.reachable_builder.step(deadline_usec, 512)",
        "processed >= 512 or Time.get_ticks_usec() >= deadline_usec",
        "processed >= RANGED_EXACT_SHORTLIST_SIZE",
    ]:
        require(planner, needle, "enemy_action_planner.gd", errors)

    require(
        text["visibility"],
        "job.geometry_revision != _state_store.state.geometry_revision()",
        "visibility job stale-geometry guard",
        errors,
    )

    if errors:
        print("Stage 4.7 Hotfix 5f2 latency validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Stage 4.7 Hotfix 5f2 latency validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
