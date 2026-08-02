#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5e3 enemy cadence tuning."""
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=ROOT_DEFAULT)
    args = parser.parse_args()
    root = args.project.resolve()

    screen_path = root / "presentation/tactical/tactical_screen.gd"
    if not screen_path.exists():
        print(f"Stage 4.7 Hotfix 5e3 validation FAILED:\n- Missing {screen_path}")
        return 1
    screen = screen_path.read_text(encoding="utf-8")
    errors: list[str] = []

    for needle in [
        "const AI_VISIBLE_MOVE_SHORT_START_SECONDS: float =",
        "const AI_VISIBLE_MOVE_SHORT_STEP_SECONDS: float =",
        "const AI_VISIBLE_MOVE_LONG_STEP_SECONDS: float =",
        "const AI_VISIBLE_MOVE_ORDINARY_CAP_SECONDS: float =",
        "const AI_VISIBLE_MOVE_MAX_SECONDS: float =",
        "var short_steps: int = mini(steps, 3)",
        "if steps > 3:",
        "minf(AI_VISIBLE_MOVE_ORDINARY_CAP_SECONDS, AI_VISIBLE_MOVE_MAX_SECONDS)",
    ]:
        require(screen, needle, "smooth movement-duration curve", errors)

    def constant(name: str) -> float:
        match = re.search(rf"const {name}: float = ([0-9.]+)", screen)
        return float(match.group(1)) if match else 999.0

    short_start = constant("AI_VISIBLE_MOVE_SHORT_START_SECONDS")
    short_step = constant("AI_VISIBLE_MOVE_SHORT_STEP_SECONDS")
    long_step = constant("AI_VISIBLE_MOVE_LONG_STEP_SECONDS")
    ordinary_cap = constant("AI_VISIBLE_MOVE_ORDINARY_CAP_SECONDS")
    maximum_cap = constant("AI_VISIBLE_MOVE_MAX_SECONDS")
    old_short_branch = "return mini(AI_VISIBLE_MOVE_MAX_SECONDS, float(steps) * 0.08)"
    forbid(screen, old_short_branch, "movement duration must not retain the discontinuous branch", errors)

    durations: list[float] = []
    for steps in range(1, 25):
        authored_short_steps = min(steps, 3)
        duration = short_start + max(0, authored_short_steps - 1) * short_step
        if steps > 3:
            duration += (steps - 3) * long_step
        durations.append(min(duration, ordinary_cap, maximum_cap))
    if any(later < earlier for earlier, later in zip(durations, durations[1:])):
        errors.append("authored enemy movement duration curve must be monotonic")
    if max(durations) > 0.420001:
        errors.append("ordinary visible enemy movement must not regress beyond the 0.42 second cap")
    if durations[0] >= 0.08 or durations[2] >= 0.24 or durations[15] >= 0.50:
        errors.append("enemy movement cadence is not faster than the Hotfix 5e2 values")

    for needle in [
        "func _begin_side_based_enemy_activation_presentation(",
        '&"enemy_activation_completed"',
        "_select_unit_for_observable_handoff(unit)",
        "_play_active_unit_handoff_pulse(unit_id)",
        "_side_based_enemy_activation_pulses += 1",
        "_begin_side_based_enemy_activation_presentation(result)",
    ]:
        require(screen, needle, "non-blocking side-based activation presentation", errors)

    helper_start = screen.find("func _begin_side_based_enemy_activation_presentation(")
    helper_end = screen.find("\n\nfunc ", helper_start + 1)
    helper = screen[helper_start : helper_end if helper_end != -1 else None]
    forbid(helper, "await ", "side-based activation pulse must not block AI", errors)
    forbid(helper, "create_timer", "side-based activation pulse must not add a timer", errors)

    enemy_phase_start = screen.find(
        "func _resolve_enemy_phase_with_reaction_prompts() -> OperationResult:"
    )
    enemy_phase_end = screen.find("\n\nfunc ", enemy_phase_start + 1)
    enemy_phase = screen[
        enemy_phase_start : enemy_phase_end if enemy_phase_end != -1 else None
    ]
    has_legacy_stationary_boundary = (
        "if not _last_ai_activation_presented_movement:" in enemy_phase
        and "_observable_stationary_activation_frame_yields += 1" in enemy_phase
        and "await get_tree().process_frame" in enemy_phase
    )
    has_rapid_cadence_successor = (
        "_visible_activation_dead_frames_avoided += 1" in enemy_phase
        and "if _last_ai_activation_presented_movement:" in enemy_phase
    )
    if not (has_legacy_stationary_boundary or has_rapid_cadence_successor):
        errors.append("Enemy Phase must retain either the 5e3 render boundary or its faster non-blocking successor")
    forbid(
        enemy_phase,
        "create_timer(",
        "ordinary Enemy Phase must not restore fixed cadence timers",
        errors,
    )

    for needle in [
        '"side_based_activation_pulses": _side_based_enemy_activation_pulses',
        '"observable_stationary_frame_yields": (',
    ]:
        require(screen, needle, "enemy cadence diagnostics", errors)

    if errors:
        print("Stage 4.7 Hotfix 5e3 enemy cadence validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Stage 4.7 Hotfix 5e3 enemy cadence validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
