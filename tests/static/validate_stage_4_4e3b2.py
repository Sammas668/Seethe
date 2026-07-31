#!/usr/bin/env python3
from pathlib import Path
from validation_common import *


def function_block(path: str, function_name: str) -> str:
    text = (ROOT / path).read_text(encoding="utf-8")
    marker = f"func {function_name}("
    start = text.find(marker)
    if start < 0:
        return ""
    next_func = text.find("\nfunc ", start + len(marker))
    return text[start:] if next_func < 0 else text[start:next_func]


def main() -> int:
    failures: list[str] = []
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    required_files = [
        "STAGE_4_4E3B2_IMMEDIATE_HIT_REACTION_TIMING_RELEASE_NOTES.txt",
        "STAGE_4_4E3B2_PATCH_README.txt",
        "STAGE_4_4E3B2_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_4E3B2_IMMEDIATE_HIT_REACTION_TIMING.md",
        "tests/tactical/stage_4_4e3b2_immediate_hit_reaction_tests.gd",
        "tests/tactical/run_stage_4_4e3b2_tests.gd",
    ]
    for path in required_files:
        require_file(path, failures)

    screen_path = "presentation/tactical/tactical_screen.gd"
    screen_text = require_file(screen_path, failures)
    unit_view_text = require_file(
        "presentation/tactical/tactical_unit_view.gd", failures
    )

    complete_block = function_block(
        screen_path, "_complete_movement_handoff_after_frame"
    )
    release_index = complete_block.find("_apply_deferred_damage_events()")
    frame_index = complete_block.find("await get_tree().process_frame")
    cadence_index = complete_block.find("await _await_presentation_cadence(cadence_event)")
    if release_index < 0:
        failures.append("Movement handoff no longer releases deferred damage events.")
    if frame_index < 0:
        failures.append("Movement handoff no longer presents a rendered frame.")
    if cadence_index < 0:
        failures.append("Movement handoff no longer applies event-driven cadence.")
    if release_index >= 0 and frame_index >= 0 and release_index > frame_index:
        failures.append("Deferred hit confirmation is still released after the first frame await.")
    if release_index >= 0 and cadence_index >= 0 and release_index > cadence_index:
        failures.append("Deferred hit confirmation is still released after readability cadence.")
    if "if cadence_event == PresentationCadenceEvent.AI_MOVE_TO_ATTACK" in complete_block:
        failures.append("The old AI branch still delays hit confirmation until after cadence.")
    for required in [
        "final position, fog delta and hit confirmation together",
        "Any additional wait now happens after hit confirmation has already begun",
    ]:
        if required not in complete_block:
            failures.append(f"Immediate hit-reaction contract is missing: {required}")

    damage_signal_block = function_block(screen_path, "_on_damage_committed")
    for required in [
        "_deferred_damage_events.append",
        "_apply_damage_committed_presentation(event)",
    ]:
        if required not in damage_signal_block:
            failures.append(f"Damage event routing is missing: {required}")

    damage_apply_block = function_block(
        screen_path, "_apply_damage_committed_presentation"
    )
    for required in [
        "_refresh_unit_status_badge_immediately(target_id)",
        "view.play_damage_reaction()",
    ]:
        if required not in damage_apply_block:
            failures.append(f"Immediate damage presentation is missing: {required}")
    if "await " in damage_apply_block:
        failures.append("Damage presentation must remain fire-and-forget.")

    reaction_block_start = unit_view_text.find("func play_damage_reaction() -> void:")
    reaction_block_end = unit_view_text.find("\nfunc ", reaction_block_start + 1)
    reaction_block = (
        unit_view_text[reaction_block_start:]
        if reaction_block_end < 0
        else unit_view_text[reaction_block_start:reaction_block_end]
    )
    if "await " in reaction_block:
        failures.append("TacticalUnitView.play_damage_reaction must not await its tween.")
    for required in [
        "_damage_reaction_tween.kill()",
        "_damage_reaction_progress = 0.0",
        "DAMAGE_REACTION_DURATION",
    ]:
        if required not in reaction_block:
            failures.append(f"Existing hit-reaction behaviour changed unexpectedly: {required}")

    require_tokens(
        "tests/tactical/stage_4_4e3b2_immediate_hit_reaction_tests.gd",
        [
            "Movement handoff must release deferred damage before its first await.",
            "The crimson pulse and shake must begin before readability cadence.",
            "Hit confirmation must begin before the cadence runner starts.",
        ],
        failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.4e3b2",
            "IMMEDIATE HIT-REACTION TIMING CORRECTION",
            "run_stage_4_4e3b2_tests.gd",
        ],
        failures,
    )

    if failures:
        print("Stage 4.4e3b2 static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 4.4e3b2 static validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
