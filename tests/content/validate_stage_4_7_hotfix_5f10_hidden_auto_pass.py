#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5f10."""
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
        "handler": root / "application/tactical/ai/enemy_turn_handler.gd",
        "screen": root / "presentation/tactical/tactical_screen.gd",
        "runtime": root / "tests/integration/stage_4_7_hotfix_5f10_hidden_auto_pass_tests.gd",
        "runner": root / "tests/integration/run_stage_4_7_hotfix_5f10_tests.gd",
        "doc": root / "docs/architecture/STAGE_4_7_HOTFIX_5F10_HIDDEN_AUTO_PASS_CONSOLIDATION.md",
    }
    errors: list[str] = []
    for label, path in paths.items():
        if not path.is_file():
            errors.append(f"Missing {path.relative_to(root)} ({label})")
    if errors:
        print("Stage 4.7 Hotfix 5f10 validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    handler = paths["handler"].read_text(encoding="utf-8")
    screen = paths["screen"].read_text(encoding="utf-8")

    for needle in [
        "func _try_execute_hidden_auto_pass_batch() -> OperationResult:",
        "func _is_hidden_auto_pass_batch_candidate(",
        'TacticalChangeSet.new(\n\t\t&"hidden_enemy_auto_pass_batch"',
        "changes.set_commit_validation_policy(false, false)",
        "unit.refresh_for_new_round()",
        "unit.mark_activation_ended()",
        '"hidden_auto_pass_batching"',
        '"maximum_batch_size"',
    ]:
        require(handler, needle, "enemy_turn_handler.gd", errors)

    resolve = body(handler, "func resolve_next_enemy_activation(")
    require(
        resolve,
        "var hidden_batch: OperationResult = _try_execute_hidden_auto_pass_batch()",
        "side-based hidden batch gate",
        errors,
    )
    require(
        resolve,
        "if hidden_batch != null:",
        "side-based hidden batch gate",
        errors,
    )

    batch = body(handler, "func _try_execute_hidden_auto_pass_batch() -> OperationResult:")
    require(
        batch,
        "while scan_index < _side_turn_participant_ids.size():",
        "consecutive hidden actor scan",
        errors,
    )
    require(
        batch,
        "_side_turn_index = scan_index",
        "authoritative batch progress",
        errors,
    )
    require(
        batch,
        "_record_turn_started(unit, \"Automatic Pass\")",
        "per-actor deterministic journal",
        errors,
    )
    require(
        batch,
        "_record_turn_finished(unit, false, summaries[index], false)",
        "per-actor deterministic journal",
        errors,
    )
    forbid(
        batch,
        "_begin_activation(unit",
        "hidden batch must not perform per-actor start commits",
        errors,
    )
    forbid(
        batch,
        "_finish_activation(unit",
        "hidden batch must not perform per-actor finish commits",
        errors,
    )

    state_change = body(screen, "func _on_state_changed(reason: StringName) -> void:")
    require(
        state_change,
        'if reason == &"hidden_enemy_auto_pass_batch":',
        "presentation suppression",
        errors,
    )
    require(
        state_change,
        "_hidden_auto_pass_refreshes_avoided += 1",
        "presentation suppression diagnostics",
        errors,
    )
    require(
        screen,
        "func _restore_player_input_after_phase_flow() -> void:",
        "phase-flow input recovery",
        errors,
    )
    require(
        screen,
        '"last_empty_enemy_phase_usec"',
        "empty-phase diagnostics",
        errors,
    )
    require(
        screen,
        '"end_phase_to_player_control_restored_usec"',
        "empty-phase diagnostics",
        errors,
    )

    if errors:
        print("Stage 4.7 Hotfix 5f10 hidden-auto-pass validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Stage 4.7 Hotfix 5f10 hidden-auto-pass validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
