#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5f5."""
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
        "job": root / "application/tactical/ai/enemy_activation_planning_job.gd",
        "planner": root / "application/tactical/ai/enemy_action_planner.gd",
        "handler": root / "application/tactical/ai/enemy_turn_handler.gd",
        "facade": root / "application/tactical/facades/tactical_screen_facade.gd",
        "screen": root / "presentation/tactical/tactical_screen.gd",
        "doc": root / "docs/architecture/STAGE_4_7_HOTFIX_5F5_SEAMLESS_PLAYER_ENEMY_HANDOFF.md",
    }
    errors: list[str] = []
    for label, path in paths.items():
        if not path.is_file():
            errors.append(f"Missing {path.relative_to(root)} ({label})")
    if errors:
        print("Stage 4.7 Hotfix 5f5 validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    text = {name: path.read_text(encoding="utf-8") for name, path in paths.items()}
    job = text["job"]
    planner = text["planner"]
    handler = text["handler"]
    facade = text["facade"]
    screen = text["screen"]

    for needle in [
        "var forecast_mode: bool = false",
        "var available_capacity_feet: int = -1",
        "var planning_diagonal_steps: int = -1",
        "capacity_override_feet: int = -1",
        "forecast: bool = false",
    ]:
        require(job, needle, "enemy_activation_planning_job.gd", errors)

    for needle in [
        "func begin_plan_activation(",
        "capacity_override_feet: int = -1",
        "diagonal_steps_override: int = -1",
        "forecast: bool = false",
        "func _forecast_direct_attack_succeeds(",
        "job.available_capacity_feet",
        "job.planning_diagonal_steps",
    ]:
        require(planner, needle, "enemy_action_planner.gd", errors)

    for needle in [
        "func peek_next_ai_handoff_unit_id() -> StringName:",
        "func warmup_next_ai_handoff(",
        "func cancel_handoff_ai_warmup() -> void:",
        "func _next_ai_handoff_candidate() -> Dictionary:",
        "func _handoff_warmup_signature_for_unit(",
        "func _take_valid_handoff_warmup_job(",
        '"begin_plan_activation",\n\t\t\tunit,\n\t\t\tforecast_capacity,',
        '"handoff_warmup_reused"',
        'snapshot["handoff_warmup"]',
    ]:
        require(handler, needle, "enemy_turn_handler.gd", errors)

    warmup = function_body(handler, "func warmup_next_ai_handoff(")
    require(warmup, '"step_plan_job"', "budgeted anticipatory warmup", errors)
    for forbidden in ["_state_store.commit", "_commit_enemy_move", "_execute_attack"]:
        forbid(warmup, forbidden, "read-only anticipatory warmup", errors)

    for needle in [
        "func peek_next_ai_handoff_unit_id() -> StringName:",
        "func warmup_next_ai_handoff(",
        "func cancel_handoff_ai_warmup() -> void:",
    ]:
        require(facade, needle, "tactical_screen_facade.gd", errors)

    for needle in [
        "const ENEMY_HANDOFF_IDLE_WARMUP_BUDGET_USEC: int = 1500",
        "_step_idle_enemy_handoff_warmup()",
        "func _step_idle_enemy_handoff_warmup() -> void:",
        "_facade.warmup_next_ai_handoff(",
        "func _begin_seamless_initiative_handoff() -> void:",
        "_player_to_enemy_handoff_in_progress",
        "_handoff_duplicate_ai_schedules_avoided += 1",
        "_handoff_full_refreshes_avoided += 1",
        '"idle_warmup_processing_usec"',
        '"handoff_to_authoritative_commit_usec"',
        '"handoff_to_movement_tween_usec"',
    ]:
        require(screen, needle, "tactical_screen.gd", errors)

    end_unit = function_body(screen, "func _on_end_unit_pressed() -> void:")
    require(end_unit, "_begin_seamless_initiative_handoff()", "direct initiative handoff", errors)
    require(end_unit, "_board_view.set_input_enabled(false)", "immediate input lock", errors)

    state_change = function_body(screen, "func _process_state_change_after_commit(")
    require(
        state_change,
        "if _player_to_enemy_handoff_in_progress:",
        "duplicate callback scheduling guard",
        errors,
    )
    require(
        state_change,
        "and not _player_to_enemy_handoff_in_progress",
        "broad board refresh suppression",
        errors,
    )

    handoff = function_body(screen, "func _begin_seamless_initiative_handoff() -> void:")
    require(handoff, "_run_initiative_ai()", "same-frame AI coordinator start", errors)
    forbid(handoff, "call_deferred", "same-frame AI coordinator start", errors)
    forbid(handoff, "await get_tree().process_frame", "same-frame AI coordinator start", errors)

    if errors:
        print("Stage 4.7 Hotfix 5f5 seamless handoff validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Stage 4.7 Hotfix 5f5 seamless handoff validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
