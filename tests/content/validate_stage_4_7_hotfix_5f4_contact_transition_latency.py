#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5f4."""
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
        "detection": root / "application/tactical/awareness/tactical_detection_service.gd",
        "batch": root / "application/tactical/awareness/detection_batch_transaction_support.gd",
        "handler": root / "application/tactical/ai/enemy_turn_handler.gd",
        "facade": root / "application/tactical/facades/tactical_screen_facade.gd",
        "screen": root / "presentation/tactical/tactical_screen.gd",
        "doc": root / "docs/architecture/STAGE_4_7_HOTFIX_5F4_CONTACT_TRANSITION_PREMOVEMENT_LATENCY.md",
    }
    errors: list[str] = []
    for label, path in paths.items():
        if not path.is_file():
            errors.append(f"Missing {path.relative_to(root)} ({label})")
    if errors:
        print("Stage 4.7 Hotfix 5f4 validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    text = {name: path.read_text(encoding="utf-8") for name, path in paths.items()}
    detection = text["detection"]
    batch = text["batch"]
    handler = text["handler"]
    facade = text["facade"]
    screen = text["screen"]

    for needle in [
        "_contact_primed_squad_ids",
        "func _prime_perception_signatures_from_resolution(",
        "resolution.newly_aware_squad_ids.has(squad_id)",
        '&"perception_current_from_contact"',
        "func _resolution_changes_authoritative_state(",
        "_perception_no_change_transactions_avoided += 1",
        "var no_change_records: Array[TacticalDetectionResolution] = []",
        "func _record_avoided_snapshot_scope(",
    ]:
        require(detection, needle, "tactical_detection_service.gd", errors)

    current_resolution = function_body(
        detection, "func _prepare_current_position_resolution("
    )
    require(
        current_resolution,
        "observing_squad.last_seen_position(unit.unit_id)",
        "unchanged last-seen filtering",
        errors,
    )
    forbid(
        current_resolution,
        "resolution.last_seen_tile_by_squad_id[squad_id] = unit.grid_position\n\t\tresolution.revealed_at_destination_squad_ids.append(squad_id)",
        "legacy unconditional revealed-state mutation",
        errors,
    )

    for needle in [
        "_affected_squad_ids_for_resolutions(resolutions)",
        "for participant_value: Variant in resolution.initiative_totals_by_unit_id.keys()",
    ]:
        require(batch, needle, "targeted detection rollback snapshot", errors)
    forbid(
        batch,
        "for squad: TacticalSquadState in _state_store.state.get_squads():",
        "all-squad rollback snapshot",
        errors,
    )
    forbid(
        batch,
        "for unit: TacticalUnitState in _state_store.state.get_units():\n\t\tbudget_snapshots.append",
        "all-unit budget rollback snapshot",
        errors,
    )

    for needle in [
        "func warmup_initiative_activation(",
        "func cancel_contact_ai_warmup() -> void:",
        "func _contact_warmup_signature_for_unit(",
        "func _take_valid_contact_warmup_job(",
        '"contact_warmup_reused"',
        '&"perception_current_from_contact"',
    ]:
        require(handler, needle, "enemy_turn_handler.gd", errors)

    warmup = function_body(handler, "func warmup_initiative_activation(")
    require(warmup, '"begin_plan_activation"', "read-only contact warmup", errors)
    require(warmup, '"step_plan_job"', "budgeted contact warmup", errors)
    for forbidden in ["_commit_enemy_move", "_execute_attack", "_state_store.commit"]:
        forbid(warmup, forbidden, "read-only contact warmup", errors)

    for needle in [
        "func warmup_active_ai_initiative(",
        "func cancel_contact_ai_warmup() -> void:",
    ]:
        require(facade, needle, "tactical_screen_facade.gd", errors)

    for needle in [
        "func _await_alert_cadence_with_contact_warmup(seconds: float) -> void:",
        "func _step_contact_ai_warmup() -> void:",
        "_facade.warmup_active_ai_initiative(4000)",
        "_contact_presentation_ready_unit_id",
        "_duplicate_contact_refreshes_avoided += 1",
        '"contact_to_activation_pulse_usec"',
        '"activation_pulse_to_movement_tween_usec"',
    ]:
        require(screen, needle, "tactical_screen.gd", errors)

    cadence = function_body(screen, "func _await_presentation_cadence(event_kind: int) -> void:")
    require(
        cadence,
        "await _await_alert_cadence_with_contact_warmup(seconds)",
        "alert cadence planning overlap",
        errors,
    )

    runner = function_body(screen, "func _run_queued_state_change_cadence() -> void:")
    require(
        runner,
        "_last_handoff_pulsed_unit_id != unit_id",
        "contact pulse deduplication",
        errors,
    )

    if errors:
        print("Stage 4.7 Hotfix 5f4 contact transition validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Stage 4.7 Hotfix 5f4 contact transition validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
