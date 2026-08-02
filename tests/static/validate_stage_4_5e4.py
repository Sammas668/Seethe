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
        "STAGE_4_5E4_ZERO_DEAD_FRAME_ATTACK_COMMITMENT_RELEASE_NOTES.txt",
        "STAGE_4_5E4_PATCH_README.txt",
        "STAGE_4_5E4_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_5E4_ZERO_DEAD_FRAME_ATTACK_COMMITMENT.md",
        "tests/tactical/stage_4_5e4_zero_dead_frame_attack_tests.gd",
        "tests/tactical/run_stage_4_5e4_tests.gd",
    ]:
        require_file(path, failures)

    screen_path = "presentation/tactical/tactical_screen.gd"
    screen = require_file(screen_path, failures)
    direct = function_block(screen_path, "_execute_direct_attack")
    confirmed = function_block(screen_path, "_confirm_selected_attack")

    for label, block in [("direct", direct), ("confirmed", confirmed)]:
        if not block:
            failures.append(f"Missing {label} attack function block.")
            continue
        if "await get_tree().process_frame" in block:
            failures.append(
                f"{label} attack still inserts a rendered frame before commitment."
            )
        for token in [
            "_attack_command_in_progress = true",
            "_play_attack_command_acknowledgement",
            "_facade.execute_attack_preview",
            "_attack_command_in_progress = false",
            "_attack_command_dead_frames_avoided += 1",
        ]:
            if token not in block:
                failures.append(f"{label} zero-dead-frame contract missing: {token}")
        pulse_index = block.find("_play_attack_command_acknowledgement")
        execute_index = block.find("_facade.execute_attack_preview")
        if pulse_index < 0 or execute_index < 0 or pulse_index > execute_index:
            failures.append(
                f"{label} attack acknowledgement must begin before authoritative commitment."
            )

    preview_index = direct.find("var preview = _attack_preview")
    pulse_index = direct.find("_play_attack_command_acknowledgement")
    if pulse_index < 0 or preview_index < 0 or pulse_index > preview_index:
        failures.append(
            "Direct hostile clicks must be acknowledged before fallback exact-preview work."
        )
    for token in [
        "_attack_clicks_using_primed_preview",
        "_attack_click_preview_fallbacks",
        "_last_attack_click_to_result_usec",
        "_last_attack_click_to_impact_usec",
        '"dead_frames_avoided"',
        '"last_click_to_impact_usec"',
    ]:
        if token not in screen:
            failures.append(f"Attack click-to-impact instrumentation missing: {token}")

    damage = function_block(screen_path, "_apply_damage_committed_presentation")
    for token in [
        "_last_attack_click_to_impact_usec",
        "Time.get_ticks_usec() - _attack_click_started_usec",
        "view.play_damage_reaction()",
    ]:
        if token not in damage:
            failures.append(f"Click-to-impact measurement missing: {token}")

    post_attack = function_block(
        screen_path, "_flush_post_attack_reconciliation_after_frame"
    )
    if "await get_tree().process_frame" not in post_attack:
        failures.append(
            "Only broad post-attack reconciliation should remain frame-deferred."
        )

    handler_path = "application/tactical/combat/attack_handler.gd"
    execute = function_block(handler_path, "execute_preview")
    impact_index = execute.find('Callable(self, "_publish_attack_impact")')
    journal_index = execute.find('Callable(self, "_record_attack_event")')
    if impact_index < 0 or journal_index < 0 or impact_index > journal_index:
        failures.append("Combat impact must remain ahead of attack journal publication.")

    require_tokens(
        "tests/tactical/stage_4_5e4_zero_dead_frame_attack_tests.gd",
        [
            "A committed hit must publish impact synchronously before execute returns.",
            "The attack commit must reuse the accepted preview.",
        ],
        failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.5e4",
            "ZERO-DEAD-FRAME ATTACK COMMITMENT",
            "run_stage_4_5e4_tests.gd",
        ],
        failures,
    )

    if failures:
        print("Stage 4.5e4 static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 4.5e4 static validation passed.")
    print(" - Direct and confirmed attacks contain no pre-commit process-frame wait.")
    print(" - Hostile clicks are acknowledged before any fallback exact-preview work.")
    print(" - Accepted previews commit in the same input frame.")
    print(" - Broad reconciliation remains deferred behind the first impact frame.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
