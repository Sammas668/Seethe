#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5f7."""
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
        "detection": root / "application/tactical/awareness/tactical_detection_service.gd",
        "abilities": root / "application/tactical/abilities/tactical_ability_service.gd",
        "facade": root / "application/tactical/facades/tactical_screen_facade.gd",
        "screen": root / "presentation/tactical/tactical_screen.gd",
        "doc": root / "docs/architecture/STAGE_4_7_HOTFIX_5F7_FIRST_ENEMY_ACTIVATION_GATE_REMOVAL.md",
    }
    errors: list[str] = []
    for label, path in paths.items():
        if not path.is_file():
            errors.append(f"Missing {path.relative_to(root)} ({label})")
    if errors:
        print("Stage 4.7 Hotfix 5f7 validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    handler = paths["handler"].read_text(encoding="utf-8")
    detection = paths["detection"].read_text(encoding="utf-8")
    abilities = paths["abilities"].read_text(encoding="utf-8")
    facade = paths["facade"].read_text(encoding="utf-8")
    screen = paths["screen"].read_text(encoding="utf-8")

    for needle in [
        "func perception_revision_for_squad(squad_id: StringName) -> int:",
        "func prepare_current_perception_for_ai_warmup(",
        "func has_queued_perception_refresh_for_squad(squad_id: StringName) -> bool:",
        "_advance_perception_revision(squad_id)",
    ]:
        require(detection, needle, "tactical_detection_service.gd", errors)

    for needle in [
        "func has_start_of_activation_work(unit_id: StringName) -> bool:",
        "func has_ai_usable_special_abilities(unit_id: StringName) -> bool:",
    ]:
        require(abilities, needle, "tactical_ability_service.gd", errors)

    for needle in [
        "func prepare_ai_activation_handoff(unit_id: StringName) -> OperationResult:",
        "_handoff_warmup_perception_revision",
        "_contact_warmup_perception_revision",
        '&"perception_current_from_warmup"',
        '&"warmup_revision_current"',
        '"activation_perception_gate_usec"',
        '"cold_replan_after_warmup"',
        "_has_adjacent_restrained_ally(unit)",
    ]:
        require(handler, needle, "enemy_turn_handler.gd", errors)

    signature = body(handler, "func _handoff_warmup_signature_for_unit(")
    for forbidden in [
        ".sha256_text()",
        "state.get_items()",
        "active_character_modifier_ids",
        "timed_effect_rounds",
        '"r:%d" % state.revision',
    ]:
        forbid(signature, forbidden, "lightweight plan dependency stamp", errors)
    require(signature, '"p:%d" % _perception_revision_for_squad', "perception revision stamp", errors)

    execute = body(handler, "func _execute_standard_combat(")
    take_pos = execute.find("_take_valid_contact_warmup_job(unit)")
    perception_pos = execute.find("_refresh_squad_perception(unit)")
    if take_pos < 0 or perception_pos < 0 or take_pos > perception_pos:
        errors.append("Warm plan must be consumed before the fallback perception refresh.")
    require(execute, '"has_start_of_activation_work"', "ordinary guard effect fast path", errors)
    require(execute, '"has_ai_usable_special_abilities"', "ordinary guard ability fast path", errors)

    require(
        facade,
        "func prepare_ai_activation_handoff(unit_id: StringName) -> OperationResult:",
        "tactical_screen_facade.gd",
        errors,
    )
    initiative = body(screen, "func _run_initiative_ai() -> void:")
    prepare_pos = initiative.find("_facade.prepare_ai_activation_handoff(acting_unit_id)")
    observable_pos = initiative.find("var acting_handoff_observable")
    if prepare_pos < 0 or observable_pos < 0 or prepare_pos > observable_pos:
        errors.append("Initiative warmup validation must occur before visible actor feedback.")
    side = body(screen, "func _resolve_enemy_phase_with_reaction_prompts() -> OperationResult:")
    require(side, "_facade.prepare_ai_activation_handoff(next_actor_id)", "side-based prevalidation", errors)

    if errors:
        print("Stage 4.7 Hotfix 5f7 first-enemy gate validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Stage 4.7 Hotfix 5f7 first-enemy activation-gate validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
