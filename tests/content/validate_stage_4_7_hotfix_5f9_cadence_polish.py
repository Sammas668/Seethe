#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5f9."""
from __future__ import annotations

import argparse
import re
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


def constant(text: str, name: str) -> float | None:
    match = re.search(rf"const {re.escape(name)}: float = ([0-9.]+)", text)
    return float(match.group(1)) if match else None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=ROOT_DEFAULT)
    args = parser.parse_args()
    root = args.project.resolve()
    paths = {
        "screen": root / "presentation/tactical/tactical_screen.gd",
        "handler": root / "application/tactical/ai/enemy_turn_handler.gd",
        "stamp": root / "application/tactical/ai/enemy_plan_dependency_stamp.gd",
        "runtime": root / "tests/integration/stage_4_7_hotfix_5f9_cadence_polish_tests.gd",
        "doc": root / "docs/architecture/STAGE_4_7_HOTFIX_5F9_SMOOTH_ENEMY_CADENCE_POLISH.md",
    }
    errors: list[str] = []
    for label, path in paths.items():
        if not path.is_file():
            errors.append(f"Missing {path.relative_to(root)} ({label})")
    if errors:
        print("Stage 4.7 Hotfix 5f9 validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    screen = paths["screen"].read_text(encoding="utf-8")
    handler = paths["handler"].read_text(encoding="utf-8")
    stamp = paths["stamp"].read_text(encoding="utf-8")

    expected = {
        "AI_VISIBLE_MOVE_SHORT_START_SECONDS": 0.06,
        "AI_VISIBLE_MOVE_SHORT_STEP_SECONDS": 0.045,
        "AI_VISIBLE_MOVE_LONG_STEP_SECONDS": 0.015,
        "AI_VISIBLE_MOVE_ORDINARY_CAP_SECONDS": 0.34,
        "AI_VISIBLE_MOVE_MAX_SECONDS": 0.40,
        "ALERT_ACTION_LEAD_SECONDS": 0.06,
        "AI_VISIBLE_SHORT_ACTION_HANDOFF_SECONDS": 0.07,
        "AI_VISIBLE_MOVEMENT_SUPPLIES_CADENCE_SECONDS": 0.10,
    }
    for name, expected_value in expected.items():
        value = constant(screen, name)
        if value is None or abs(value - expected_value) > 0.000001:
            errors.append(f"{name} must equal {expected_value}, found {value}")

    for needle in [
        "ALERT_FLASH_SECONDS",
        "blocking_seconds = minf(authored_seconds, ALERT_ACTION_LEAD_SECONDS)",
        "_blocking_alert_acknowledgement_usec += maxi(",
        "func _adaptive_visible_handoff_seconds(",
        "func _await_adaptive_visible_handoff(",
        "_last_ai_visible_movement_duration_seconds",
        'snapshot["enemy_cadence_polish"]',
        '"adaptive_visible_handoff_usec"',
    ]:
        require(screen, needle, "tactical_screen.gd", errors)

    movement = body(screen, "func _movement_animation_duration(")
    for needle in [
        "AI_VISIBLE_MOVE_ORDINARY_CAP_STEPS",
        "AI_VISIBLE_MOVE_ORDINARY_CAP_SECONDS",
        "AI_VISIBLE_MOVE_MAX_SECONDS",
    ]:
        require(movement, needle, "readable movement curve", errors)

    initiative = body(screen, "func _run_initiative_ai() -> void:")
    require(
        initiative,
        "await _await_adaptive_visible_handoff(next_after_ai)",
        "initiative adaptive handoff",
        errors,
    )
    side = body(screen, "func _resolve_enemy_phase_with_reaction_prompts() -> OperationResult:")
    require(
        side,
        "await _await_adaptive_visible_handoff(next_side_actor)",
        "side-based adaptive handoff",
        errors,
    )

    for needle in [
        "class_name EnemyPlanDependencyStamp",
        "var target_unit_ids: Array[StringName]",
        "static func capture(",
        "func matches(",
        "state.spatial_occupancy_revision()",
        "state.spatial_visibility_blocker_revision()",
    ]:
        require(stamp, needle, "enemy_plan_dependency_stamp.gd", errors)

    prepare = body(handler, "func prepare_ai_activation_handoff(unit_id: StringName) -> OperationResult:")
    require(prepare, "_prevalidated_ai_handoff_stamp = stamp", "typed handoff prevalidation", errors)
    forbid(prepare, "_handoff_warmup_signature_for_unit", "critical handoff validation", errors)
    forbid(prepare, "_contact_warmup_signature_for_unit", "critical handoff validation", errors)

    take = body(handler, "func _take_valid_handoff_warmup_job(")
    require(take, "_prevalidated_ai_handoff_stamp == _handoff_warmup_stamp", "stamp reuse", errors)
    forbid(take, "_handoff_warmup_signature_for_unit", "warm plan consumption", errors)

    warmup = body(handler, "func warmup_next_ai_handoff(")
    require(warmup, "EnemyPlanDependencyStamp.capture(", "stamp capture", errors)
    require(warmup, "_handoff_warmup_stamp.matches(", "stamp comparison", errors)

    if errors:
        print("Stage 4.7 Hotfix 5f9 cadence-polish validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Stage 4.7 Hotfix 5f9 cadence-polish validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
