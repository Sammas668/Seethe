#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5f8."""
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


def body(text: str, signature: str) -> str:
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
        "job": root / "application/tactical/ai/enemy_activation_planning_job.gd",
        "search": root / "domain/tactical/movement_targeted_search_job.gd",
        "navigation": root / "domain/tactical/tactical_navigation_snapshot.gd",
        "handler": root / "application/tactical/ai/enemy_turn_handler.gd",
        "screen": root / "presentation/tactical/tactical_screen.gd",
        "runtime": root / "tests/integration/stage_4_7_hotfix_5f8_targeted_melee_stall_tests.gd",
        "doc": root / "docs/architecture/STAGE_4_7_HOTFIX_5F8_TARGETED_MELEE_AND_STALL_ATTRIBUTION.md",
    }
    errors: list[str] = []
    for label, path in paths.items():
        if not path.is_file():
            errors.append(f"Missing {path.relative_to(root)} ({label})")
    if errors:
        print("Stage 4.7 Hotfix 5f8 validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    text = {key: path.read_text(encoding="utf-8") for key, path in paths.items()}
    for needle in [
        "class_name MovementTargetedSearchJob",
        "var open_keys: Array[Vector3i]",
        "var open_priorities: PackedInt64Array",
        "func step(deadline_usec: int, maximum_expansions: int = 1024) -> bool:",
        "func _heuristic_to_goals(tile: Vector2i) -> int:",
    ]:
        require(text["search"], needle, "movement_targeted_search_job.gd", errors)
    forbid(
        text["search"],
        'open_heap.append({"key": key, "priority": priority})',
        "allocation-light targeted heap",
        errors,
    )

    for needle in [
        'STAGE_TARGETED_MELEE_ATTACK_SEARCH: StringName = &"targeted_melee_attack_search"',
        'STAGE_TARGETED_MELEE_APPROACH_SEARCH: StringName = &"targeted_melee_approach_search"',
        "var targeted_search: MovementTargetedSearchJob",
    ]:
        require(text["job"], needle, "enemy_activation_planning_job.gd", errors)

    for needle in [
        "_begin_targeted_melee_attack_search(job, unit)",
        "_step_targeted_melee_attack_search(job, deadline_usec)",
        "_step_targeted_melee_approach_search(job, deadline_usec)",
        '"targeted_melee_attack_capacity_feet"',
        '"targeted_melee_expansions"',
        '"planning_stage"',
    ]:
        require(text["planner"], needle, "enemy_action_planner.gd", errors)
    scoring = body(text["planner"], "func _step_target_scoring(")
    require(scoring, "_begin_targeted_melee_attack_search(job, unit)", "melee scoring fast path", errors)
    forbid(scoring, "_best_path_to_attack_position(", "melee scoring universal-field path", errors)
    direct = body(text["planner"], "func _step_direct_attack_checks(")
    require(direct, "if job.attack.attack_kind == AttackDefinition.ATTACK_RANGED:", "ranged-only field branch", errors)

    require(text["navigation"], "var mover_dragging_body: bool = false", "navigation snapshot", errors)
    require(text["navigation"], "mover_dragging_body = _resolve_mover_dragging_body()", "cached drag state", errors)
    require(text["handler"], '"targeted_melee_search_builds"', "handler diagnostics", errors)

    for needle in [
        "ENEMY_STALL_THRESHOLDS_USEC",
        "func _record_enemy_stall_thresholds(unit_id: StringName) -> void:",
        '"planning_stage": planner.get("planning_stage", &"unknown")',
        "Stage 4.7 Hotfix 5f8 enemy stall attribution",
        'snapshot["enemy_runtime_stall_attribution"]',
    ]:
        require(text["screen"], needle, "tactical_screen.gd", errors)

    if errors:
        print("Stage 4.7 Hotfix 5f8 targeted-melee/stall validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Stage 4.7 Hotfix 5f8 targeted-melee/stall validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
