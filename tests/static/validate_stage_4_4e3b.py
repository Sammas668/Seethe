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
        "STAGE_4_4E3B_READABILITY_CADENCE_STEALTH_PATH_PREVIEW_RELEASE_NOTES.txt",
        "STAGE_4_4E3B_PATCH_README.txt",
        "STAGE_4_4E3B_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_4E3B_READABILITY_CADENCE_STEALTH_PATH_PREVIEW.md",
        "tests/tactical/stage_4_4e3b_readability_stealth_preview_tests.gd",
        "tests/tactical/run_stage_4_4e3b_tests.gd",
    ]
    for path in required_files:
        require_file(path, failures)

    screen_path = "presentation/tactical/tactical_screen.gd"
    screen_text = require_file(screen_path, failures)
    unit_view_text = require_file(
        "presentation/tactical/tactical_unit_view.gd", failures
    )

    hover_block = function_block(screen_path, "_on_board_tile_hovered")
    for forbidden in [
        "_destination_preview_for(",
        "preview_movement_detection(",
        "preview_movement(",
        "observation_origins_for_unit(",
    ]:
        if forbidden in hover_block:
            failures.append(
                f"Empty-tile hover restored forbidden planning work: {forbidden}"
            )

    destination_block = function_block(screen_path, "_destination_preview_for")
    for required in [
        "_facade.preview_movement(",
        "_facade.preview_movement_detection(",
        "_movement_detection_preview_query_count += 1",
        "result.automatic_peek_origins.clear()",
    ]:
        if required not in destination_block:
            failures.append(f"Clicked destination preview is missing: {required}")
    if "result.detection_preview = null" in destination_block:
        failures.append("The old blanket detection-preview removal is still active.")
    if "observation_origins_for_unit" in destination_block:
        failures.append("Automatic-Peek destination markers were unintentionally restored.")

    refresh_block = function_block(screen_path, "_refresh_path_preview")
    if "_planned_destination" not in refresh_block:
        failures.append("Locked destination revalidation is missing.")
    if "_hovered_tile" in refresh_block and "_attack_targeting" not in refresh_block:
        failures.append("Path refresh appears to rebuild from ordinary cursor hover.")

    for token in [
        "enum PresentationCadenceEvent",
        "const ACTIVATION_HANDOFF_SECONDS: float = 0.15",
        "const AI_MOVE_TO_ATTACK_SECONDS: float = 0.18",
        "const PHASE_HANDOFF_SECONDS: float = 0.25",
        "const REVEAL_ACKNOWLEDGEMENT_SECONDS: float = 0.35",
        "const ALERT_ACKNOWLEDGEMENT_SECONDS: float = 0.40",
        "func _cadence_seconds(",
        "func _await_presentation_cadence(",
        "func _set_pending_movement_cadence(",
        "func _queue_state_change_cadence(",
        "func _play_active_unit_handoff_pulse(",
    ]:
        if token not in screen_text:
            failures.append(f"Central cadence contract is missing: {token}")

    finish_block = function_block(screen_path, "_finish_movement_presentation")
    if "create_timer" in finish_block:
        failures.append("Movement completion still owns a blanket fixed timer.")
    complete_block = function_block(
        screen_path, "_complete_movement_handoff_after_frame"
    )
    if "await get_tree().process_frame" not in complete_block:
        failures.append("The final movement frame is not presented before handoff.")
    if "PresentationCadenceEvent.AI_MOVE_TO_ATTACK" not in complete_block:
        failures.append("AI movement-to-attack presentation cadence is missing.")
    if "_apply_deferred_damage_events()" not in complete_block:
        failures.append("Deferred damage presentation is not released by the handoff.")

    end_phase_block = function_block(screen_path, "_on_end_phase_pressed")
    if "PresentationCadenceEvent.PHASE_HANDOFF" not in end_phase_block:
        failures.append("Player-to-enemy phase handoff does not use the central cadence.")
    if "create_timer(0.20)" in end_phase_block:
        failures.append("The old blanket 0.20-second phase timer remains.")

    ai_block = function_block(screen_path, "_run_initiative_ai")
    if "create_timer(0.20)" in ai_block:
        failures.append("The old AI pre-action blanket timer remains.")
    for required in [
        "PresentationCadenceEvent.ACTIVATION_HANDOFF",
        "_movement_control_owner_before_commit = acting_unit_id",
        "_play_active_unit_handoff_pulse",
    ]:
        if required not in ai_block:
            failures.append(f"Initiative AI cadence is missing: {required}")

    for token in [
        "func play_active_handoff_pulse()",
        "ACTIVE_HANDOFF_PULSE_DURATION",
        "_active_handoff_pulse_progress",
        "_active_handoff_pulse_strength()",
    ]:
        if token not in unit_view_text:
            failures.append(f"Active-unit pulse is missing: {token}")

    legacy_text = require_file("tests/static/validate_stage_4_4e1.py", failures)
    if '"result.detection_preview = null"' in legacy_text:
        failures.append("The legacy Stage 4.4e1 validator still requires null detection previews.")
    if "Clicked movement planning must retain the bounded Stealth preview." not in legacy_text:
        failures.append("The legacy validator was not revised to the clicked-preview contract.")

    require_tokens(
        "tests/tactical/stage_4_4e3b_readability_stealth_preview_tests.gd",
        [
            "Hovering an empty tile must not query Stealth detection.",
            "The first destination click must build exactly one detection preview.",
            "Cursor movement must preserve the locked per-tile Stealth trail.",
            "Replacing the destination must query one replacement detection preview.",
            "Ordinary movement must have no fixed post-action delay.",
            "A combined event chain must retain one highest-priority cadence event.",
        ],
        failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.4e3b",
            "READABILITY CADENCE AND STEALTH PATH PREVIEW RESTORATION",
            "run_stage_4_4e3b_tests.gd",
            "validate_stage_4_4e3b.py",
        ],
        failures,
    )

    if failures:
        print("Stage 4.4e3b static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Stage 4.4e3b static validation passed.")
    print(" - Empty-tile hover performs no path or detection query.")
    print(" - First-click routes restore one locked per-tile Stealth preview.")
    print(" - Ordinary movement has no fixed wait; meaningful events use central cadence.")
    print(" - Combined events select one priority pause and active units receive a pulse.")
    print(" - Stage 4.4e3 and Stage 4.4e3a performance/input contracts remain intact.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
