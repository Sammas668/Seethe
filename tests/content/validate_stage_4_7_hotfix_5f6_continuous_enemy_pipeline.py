#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5f6."""
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
        "doc": root / "docs/architecture/STAGE_4_7_HOTFIX_5F6_CONTINUOUS_ENEMY_ACTIVATION_PIPELINE.md",
    }
    errors: list[str] = []
    for label, path in paths.items():
        if not path.is_file():
            errors.append(f"Missing {path.relative_to(root)} ({label})")
    if errors:
        print("Stage 4.7 Hotfix 5f6 validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    handler = paths["handler"].read_text(encoding="utf-8")
    facade = paths["facade"].read_text(encoding="utf-8")
    screen = paths["screen"].read_text(encoding="utf-8")

    for needle in [
        "func _unit_requires_planned_ai_activation(unit: TacticalUnitState) -> bool:",
        "if phase.is_enemy_turn():",
        "var chain_warmup: bool = active.is_ai_controlled()",
        "chain_warmup and not active.action_budget.ended_activation",
        '"chain": true',
        'snapshot["chain_warmup"]',
        '"chain_warmup_reused"',
        "state.spatial_occupancy_revision()",
        "state.spatial_visibility_blocker_revision()",
    ]:
        require(handler, needle, "enemy_turn_handler.gd", errors)

    signature = function_body(handler, "func _handoff_warmup_signature_for_unit(")
    forbid(
        signature,
        "authoritative_occupancy_signature()",
        "lightweight handoff dependency stamp",
        errors,
    )
    forbid(signature, ".sha256_text()", "lightweight handoff dependency stamp", errors)

    warmup = function_body(handler, "func warmup_next_ai_handoff(")
    for forbidden in ["_state_store.commit", "_execute_attack", "_commit_enemy_move"]:
        forbid(warmup, forbidden, "read-only chain warmup", errors)

    require(
        facade,
        "# Hotfix 5f6: also serves one-actor enemy-to-enemy lookahead.",
        "tactical_screen_facade.gd",
        errors,
    )

    for needle in [
        "const ENEMY_CHAIN_WARMUP_BUDGET_USEC: int = 1800",
        "var chain_overlap: bool = (",
        "_facade.warmup_next_ai_handoff(lookahead_remaining_usec)",
        "_facade.warmup_next_ai_handoff(\n\t\t\tside_lookahead_remaining_usec",
        "_prepared_ai_presentation_unit_id",
        "_duplicate_enemy_refreshes_avoided += 1",
        "_hidden_actor_refreshes_avoided += 1",
        "initiative_frame_budget_started_usec = Time.get_ticks_usec()",
        "_presentation_wall_time_excluded_usec += _last_ai_activation_presentation_usec",
        '"enemy_to_enemy_handoff_usec"',
        '"forced_inter_actor_frames_avoided"',
    ]:
        require(screen, needle, "tactical_screen.gd", errors)

    idle_warmup = function_body(screen, "func _step_idle_enemy_handoff_warmup() -> void:")
    require(idle_warmup, "_movement_animation_active", "movement-overlap warmup", errors)
    require(idle_warmup, "_cadence_wait_depth > 0", "cadence-overlap warmup", errors)
    require(idle_warmup, "ENEMY_CHAIN_WARMUP_BUDGET_USEC", "chain warmup budget", errors)

    initiative_loop = function_body(screen, "func _run_initiative_ai() -> void:")
    require(
        initiative_loop,
        "elif presentation_already_prepared:",
        "duplicate presentation suppression",
        errors,
    )
    hidden_branch = initiative_loop[initiative_loop.find("else:\n\t\t\t_prepared_ai_presentation_unit_id") :]
    if hidden_branch:
        first_pulse = hidden_branch.find("if (")
        hidden_prefix = hidden_branch[: first_pulse if first_pulse >= 0 else None]
        forbid(hidden_prefix, "_refresh_hud()", "hidden actor handoff", errors)
        forbid(hidden_prefix, "_refresh_board_view()", "hidden actor handoff", errors)

    if errors:
        print("Stage 4.7 Hotfix 5f6 continuous enemy pipeline validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Stage 4.7 Hotfix 5f6 continuous enemy pipeline validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
