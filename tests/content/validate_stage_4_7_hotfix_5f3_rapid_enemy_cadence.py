#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5f3."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT_DEFAULT = Path(__file__).resolve().parents[2]


def require(text: str, needle: str, label: str, errors: list[str]) -> None:
    if needle not in text:
        errors.append(f"{label} missing: {needle}")


def function_body(text: str, signature: str) -> str:
    start = text.find(signature)
    if start < 0:
        return ""
    end = text.find("\n\nfunc ", start + len(signature))
    return text[start : end if end >= 0 else None]


def float_constant(text: str, name: str) -> float | None:
    match = re.search(rf"const {re.escape(name)}: float = ([0-9.]+)", text)
    return float(match.group(1)) if match else None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=ROOT_DEFAULT)
    args = parser.parse_args()
    root = args.project.resolve()

    screen_path = root / "presentation/tactical/tactical_screen.gd"
    view_path = root / "presentation/tactical/tactical_unit_view.gd"
    doc_path = root / "docs/architecture/STAGE_4_7_HOTFIX_5F3_RAPID_ENEMY_CADENCE.md"
    errors: list[str] = []
    for path in [screen_path, view_path, doc_path]:
        if not path.is_file():
            errors.append(f"Missing {path.relative_to(root)}")
    if errors:
        print("Stage 4.7 Hotfix 5f3 validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    screen = screen_path.read_text(encoding="utf-8")
    view = view_path.read_text(encoding="utf-8")

    expected_maxima = {
        # Hotfix 5f9 deliberately restores a small amount of readable weight
        # while remaining far below the pre-5f3 movement timings.
        "AI_VISIBLE_MOVE_SHORT_START_SECONDS": 0.060,
        "AI_VISIBLE_MOVE_SHORT_STEP_SECONDS": 0.045,
        "AI_VISIBLE_MOVE_LONG_STEP_SECONDS": 0.016,
        "AI_VISIBLE_MOVE_ORDINARY_CAP_SECONDS": 0.34,
        "AI_VISIBLE_MOVE_MAX_SECONDS": 0.40,
        "REVEAL_ACKNOWLEDGEMENT_SECONDS": 0.20,
        "ALERT_ACKNOWLEDGEMENT_SECONDS": 0.25,
        "INTERRUPTION_ACKNOWLEDGEMENT_SECONDS": 0.15,
    }
    values: dict[str, float] = {}
    for name, maximum in expected_maxima.items():
        value = float_constant(screen, name)
        if value is None:
            errors.append(f"tactical_screen.gd missing float constant {name}")
            continue
        values[name] = value
        if value > maximum + 0.000001:
            errors.append(f"{name}={value} exceeds the Hotfix 5f3 maximum {maximum}")

    if len(values) >= 5:
        durations: list[float] = []
        for steps in range(1, 40):
            short_steps = min(steps, 3)
            duration = values["AI_VISIBLE_MOVE_SHORT_START_SECONDS"]
            duration += max(0, short_steps - 1) * values["AI_VISIBLE_MOVE_SHORT_STEP_SECONDS"]
            if steps > 3:
                duration += (steps - 3) * values["AI_VISIBLE_MOVE_LONG_STEP_SECONDS"]
            durations.append(min(
                duration,
                values["AI_VISIBLE_MOVE_ORDINARY_CAP_SECONDS"],
                values["AI_VISIBLE_MOVE_MAX_SECONDS"],
            ))
        if any(b < a for a, b in zip(durations, durations[1:])):
            errors.append("Enemy movement duration curve must remain monotonic")
        if durations[0] > 0.060001 or durations[2] > 0.150001 or max(durations) > 0.400001:
            errors.append("Enemy movement curve does not meet the current rapid/readable cadence targets")

    animate = function_body(view, "func animate_path(")
    for needle in [
        "movement_step.set_trans(Tween.TRANS_LINEAR)",
        "movement_step.set_trans(Tween.TRANS_SINE)",
        "movement_step.set_ease(Tween.EASE_OUT)",
        "if index == path.size() - 1:",
    ]:
        require(animate, needle, "continuous movement tween", errors)
    if "_movement_tween.set_trans(Tween.TRANS_SINE)" in animate:
        errors.append("animate_path must not apply sine easing to every tile")

    enemy_loop = function_body(
        screen, "func _resolve_enemy_phase_with_reaction_prompts() -> OperationResult:"
    )
    for needle in [
        "_visible_activation_dead_frames_avoided += 1",
        "if _last_ai_activation_presented_movement:",
        "frame_budget_started_usec = Time.get_ticks_usec()",
    ]:
        require(enemy_loop, needle, "rapid Enemy Phase handoff", errors)
    legacy_wait = """if _last_ai_resolution_observable:\n\t\t\tif not _last_ai_activation_presented_movement:\n\t\t\t\t_observable_stationary_activation_frame_yields += 1\n\t\t\tawait get_tree().process_frame"""
    if legacy_wait in enemy_loop:
        errors.append("Enemy Phase still contains the compulsory visible-actor frame wait")

    feedback = function_body(screen, "func _begin_side_based_enemy_activation_feedback(")
    if "_refresh_hud()" in feedback or "_refresh_board_view()" in feedback:
        errors.append("Pre-planning activation feedback must remain targeted")

    finish = function_body(screen, "func _finish_movement_presentation() -> void:")
    require(
        finish,
        "_complete_pending_ai_destination_visibility_same_frame()",
        "same-frame destination visibility handoff",
        errors,
    )
    if "await _complete_pending_ai_destination_visibility()" in finish:
        errors.append("Movement endpoint must not yield rendered frames for destination visibility")

    for needle in [
        '"visible_activation_dead_frames_avoided"',
        '"destination_visibility_same_frame_completions"',
        '"destination_visibility_final_budget_overruns"',
    ]:
        require(screen, needle, "Hotfix 5f3 diagnostics", errors)

    if errors:
        print("Stage 4.7 Hotfix 5f3 rapid cadence validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Stage 4.7 Hotfix 5f3 rapid cadence validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
