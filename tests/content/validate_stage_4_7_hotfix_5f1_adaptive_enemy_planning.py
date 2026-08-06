#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5f1."""
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
        "handler": root / "application/tactical/ai/enemy_turn_handler.gd",
        "facade": root / "application/tactical/facades/tactical_screen_facade.gd",
        "screen": root / "presentation/tactical/tactical_screen.gd",
    }
    errors: list[str] = []
    for label, path in paths.items():
        if not path.exists():
            errors.append(f"Missing {path.relative_to(root)} ({label}).")
    if errors:
        print("Stage 4.7 Hotfix 5f1 adaptive planning validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    text = {key: path.read_text(encoding="utf-8") for key, path in paths.items()}
    handler = text["handler"]
    facade = text["facade"]
    screen = text["screen"]
    side_loop = function_body(
        screen,
        "func _resolve_enemy_phase_with_reaction_prompts() -> OperationResult:",
    )
    initiative_loop = function_body(
        screen,
        "func _resolve_initiative_ai_with_reaction_prompts(",
    )

    for needle in [
        "func is_enemy_plan_ready_to_commit() -> bool:",
        "func commit_ready_enemy_activation() -> OperationResult:",
        '&"enemy_plan_ready"',
        "func pending_enemy_planning_is_visibility() -> bool:",
        "func record_enemy_planning_frame_yield(",
        '"planning_processing_usec"',
        '"planning_wall_clock_usec"',
        '"planning_yield_count"',
        '"planning_max_slices_per_frame"',
        '"hidden_planning_frames"',
        '"destination_visibility_yield_count"',
        "return _begin_destination_visibility_without_blocking(",
    ]:
        require(handler, needle, "enemy_turn_handler.gd", errors)

    for needle in [
        "func enemy_planning_ready_to_commit() -> bool:",
        "func commit_ready_enemy_activation() -> OperationResult:",
        "func pending_enemy_planning_is_visibility() -> bool:",
        "func record_enemy_planning_frame_yield(",
    ]:
        require(facade, needle, "tactical_screen_facade.gd", errors)

    for needle in [
        "var planning_slices_this_frame: int = 0",
        "var frame_budget_started_usec: int = Time.get_ticks_usec()",
        "if frame_processing_usec < ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC:",
        "_facade.commit_ready_enemy_activation()",
        "_facade.enemy_planning_ready_to_commit()",
        "_release_ai_planning_only_deferral()",
        "_facade.record_enemy_planning_frame_yield(",
        '"planning_slice_count"',
        '"planning_yield_count"',
        '"planning_max_slices_per_frame"',
        '"hidden_planning_frames"',
        '"destination_visibility_yield_count"',
        '"end_phase_to_first_enemy_feedback_usec"',
        '"end_phase_to_first_visible_action_usec"',
    ]:
        require(screen, needle, "tactical_screen.gd", errors)

    pending_start = side_loop.find('if result.code == &"enemy_planning_pending":')
    ready_start = side_loop.find('if result.code == &"enemy_plan_ready":')
    pending_branch = side_loop[pending_start:ready_start]
    require(
        pending_branch,
        "if frame_processing_usec < ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC:",
        "side-based planning pending branch",
        errors,
    )
    require(
        pending_branch,
        "continue",
        "side-based same-frame planning continuation",
        errors,
    )
    if (
        "await get_tree().process_frame" in pending_branch
        and pending_branch.find("await get_tree().process_frame")
        < pending_branch.find("ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC")
    ):
        errors.append(
            "Side-based planning must test the shared frame budget before yielding."
        )

    require(
        initiative_loop,
        "Time.get_ticks_usec() - frame_budget_started_usec",
        "initiative adaptive planning budget",
        errors,
    )
    require(
        initiative_loop,
        "_facade.commit_ready_enemy_activation()",
        "initiative plan commitment boundary",
        errors,
    )

    forbid(
        side_loop,
        'if result.code == &"enemy_planning_pending":\n\t\t\t_enemy_phase_frame_yields += 1\n\t\t\tawait get_tree().process_frame',
        "one-slice-per-frame side-based scheduler",
        errors,
    )
    forbid(
        initiative_loop,
        'if result.code == &"enemy_planning_pending":\n\t\t\t_enemy_phase_frame_yields += 1\n\t\t\tawait get_tree().process_frame',
        "one-slice-per-frame initiative scheduler",
        errors,
    )

    require(
        side_loop,
        "if resuming_reaction or plan_ready:",
        "strict side-based commit-only deferral boundary",
        errors,
    )
    require(
        initiative_loop,
        "if resuming_reaction or plan_ready:",
        "strict initiative commit-only deferral boundary",
        errors,
    )

    if errors:
        print("Stage 4.7 Hotfix 5f1 adaptive planning validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Stage 4.7 Hotfix 5f1 adaptive planning validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
