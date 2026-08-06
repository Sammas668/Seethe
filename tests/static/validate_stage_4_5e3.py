#!/usr/bin/env python3
from validation_common import *


def function_block(path: str, function_name: str) -> str:
    text = (ROOT / path).read_text(encoding="utf-8")
    marker = f"func {function_name}("
    start = text.find(marker)
    if start < 0:
        return ""
    end = text.find("\nfunc ", start + len(marker))
    return text[start:] if end < 0 else text[start:end]


def main() -> int:
    failures: list[str] = []
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    for path in [
        "STAGE_4_5E3_ATTACK_IMPACT_CRITICAL_PATH_RELEASE_NOTES.txt",
        "STAGE_4_5E3_PATCH_README.txt",
        "STAGE_4_5E3_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_5E3_ATTACK_IMPACT_CRITICAL_PATH.md",
        "tests/tactical/stage_4_5e3_attack_impact_critical_path_tests.gd",
        "tests/tactical/run_stage_4_5e3_tests.gd",
    ]:
        require_file(path, failures)

    change_set_path = "application/tactical/transactions/tactical_change_set.gd"
    change_set = require_file(change_set_path, failures)
    for token in [
        "func set_commit_validation_policy(",
        "_synchronise_body_items_before_validation",
        "_validate_full_state_after_steps",
        "if _synchronise_body_items_before_validation:",
        "if _validate_full_state_after_steps:",
    ]:
        if token not in change_set:
            failures.append(f"Targeted transaction validation contract missing: {token}")

    handler_path = "application/tactical/combat/attack_handler.gd"
    handler = require_file(handler_path, failures)
    execute = function_block(handler_path, "execute_preview")
    for token in [
        "changes.set_commit_validation_policy(",
        "lightweight_attack_commits",
        "full_validation_attack_commits",
        "redundant_hostile_action_resolutions_skipped",
        "last_impact_publish_usec_from_commit_start",
    ]:
        if token not in handler:
            failures.append(f"Attack critical-path metric/policy missing: {token}")
    impact_index = execute.find('Callable(self, "_publish_attack_impact")')
    attack_log_index = execute.find('Callable(self, "_record_attack_event")')
    detection_log_index = execute.find('Callable(_detection_service, "record_resolution")')
    if impact_index < 0 or attack_log_index < 0 or impact_index > attack_log_index:
        failures.append("Attack impact must be the first post-commit attack callback.")
    if detection_log_index >= 0 and impact_index > detection_log_index:
        failures.append("Attack impact must publish before detection journal recording.")

    detection_path = "application/tactical/awareness/tactical_detection_service.gd"
    detection = require_file(detection_path, failures)
    hostile = function_block(detection_path, "prepare_hostile_action_resolution")
    for token in [
        "target_squad.is_aware()",
        "phase_state.is_initiative_combat()",
        "attacker.is_revealed_to_squad(target.squad_id)",
        "target_squad.last_seen_position(attacker.unit_id)",
        "_redundant_hostile_action_resolutions_skipped += 1",
    ]:
        if token not in hostile:
            failures.append(f"Redundant hostile-action suppression missing: {token}")
    if "func performance_snapshot() -> Dictionary:" not in detection:
        failures.append("Detection performance snapshot is missing.")

    journal_path = "application/tactical/events/tactical_event_journal.gd"
    recent = function_block(journal_path, "recent_events")
    if "var matching := events(" in recent:
        failures.append("recent_events must not deep-copy the complete journal.")
    for token in [
        "for index: int in range(_events.size() - 1, -1, -1):",
        "if reverse_result.size() >= limit:",
    ]:
        if token not in recent:
            failures.append(f"Tail-only journal scan missing: {token}")

    log_path = "presentation/tactical/combat_log/tactical_combat_log.gd"
    log = require_file(log_path, failures)
    on_event = function_block(log_path, "_on_event_added")
    if "_refresh_all()" in on_event:
        failures.append("event_added must not synchronously rebuild the combat log.")
    for token in [
        "await get_tree().process_frame",
        "_pending_journal_events",
        "_append_expanded_event(event_value)",
        "frame_deferred_event_batches",
        "incremental_expanded_entries_added",
    ]:
        if token not in log:
            failures.append(f"Frame-deferred combat-log update missing: {token}")

    screen_path = "presentation/tactical/tactical_screen.gd"
    screen = require_file(screen_path, failures)
    direct = function_block(screen_path, "_execute_direct_attack")
    confirm = function_block(screen_path, "_confirm_selected_attack")
    for block_name, block in [("direct", direct), ("confirmed", confirm)]:
        for token in [
            "_play_attack_command_acknowledgement",
            "_attack_command_in_progress = true",
            "_attack_command_in_progress = false",
        ]:
            if token not in block:
                failures.append(f"{block_name} attack acknowledgement missing: {token}")
        if "await get_tree().process_frame" in block:
            failures.append(
                f"{block_name} attack must not retain the superseded pre-commit frame wait."
            )
    post_attack_frame = function_block(
        screen_path,
        "_flush_post_attack_reconciliation_after_frame",
    )
    if "await get_tree().process_frame" not in post_attack_frame:
        failures.append(
            "Broad post-attack reconciliation must wait until after the first impact frame."
        )
    for token in [
        "command_acknowledgements",
        "command_frame_yields",
        'snapshot["combat_log"]',
    ]:
        if token not in screen:
            failures.append(f"Attack-screen performance contract missing: {token}")

    unit_view = require_file("presentation/tactical/tactical_unit_view.gd", failures)
    for token in [
        "const ATTACK_COMMAND_PULSE_DURATION: float = 0.18",
        "func play_attack_command_pulse() -> void:",
        "_attack_command_pulse_strength()",
    ]:
        if token not in unit_view:
            failures.append(f"Attack command pulse missing: {token}")

    require_tokens(
        "tests/tactical/stage_4_5e3_attack_impact_critical_path_tests.gd",
        [
            "The damage impact must publish before the attack journal entry.",
            "An ordinary known-combat hit must use targeted commit validation.",
            "An already-known combat attack must skip redundant hostile-action resolution.",
            "Recent events must preserve chronological order for the journal tail.",
        ],
        failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.5e3",
            "ATTACK IMPACT CRITICAL PATH AND COMBAT-LOG DECOUPLING",
            "run_stage_4_5e3_tests.gd",
        ],
        failures,
    )

    if failures:
        print("Stage 4.5e3 static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 4.5e3 static validation passed.")
    print(" - Valid attack clicks receive a non-blocking acknowledgement without a pre-commit frame wait.")
    print(" - Ordinary combat hits use targeted transaction validation.")
    print(" - Redundant hostile-action detection is skipped in known combat.")
    print(" - Impact publishes before journal work and log UI updates one frame later.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
