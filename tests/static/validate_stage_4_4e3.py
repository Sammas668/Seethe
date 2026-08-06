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
        "STAGE_4_4E3_POST_MOVEMENT_TURN_HANDOFF_RELEASE_NOTES.txt",
        "STAGE_4_4E3_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_4E3_POST_MOVEMENT_TURN_HANDOFF.md",
        "tests/tactical/stage_4_4e3_post_movement_turn_handoff_tests.gd",
        "tests/tactical/run_stage_4_4e3_tests.gd",
    ]
    for path in required_files:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/visibility/tactical_visibility_state.gd",
        [
            "var _visible_counts_by_team",
            "var _visible_indices_by_unit",
            "func replace_unit_visibility(",
            "func remove_unit_visibility(",
            "counts[index] += 1",
            "counts[index] = maxi(0, counts[index] - 1)",
        ], failures,
    )
    require_tokens(
        "application/tactical/visibility/tactical_visibility_service.gd",
        [
            "func recalculate_units(",
            "func end_recalculation_deferral_for_units(",
            "incremental_recalculation_count",
            "full_recalculation_count",
            "current_perception_resolved",
            "replace_unit_visibility",
        ], failures,
    )
    require_tokens(
        "application/tactical/facades/tactical_screen_facade.gd",
        [
            "func end_visibility_recalculation_deferral()",
            "func end_visibility_recalculation_deferral_for_units(",
            "moved_unit_ids",
            "force_full_visibility",
            "end_recalculation_deferral_for_units",
        ], failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "func _process_post_movement_refresh(",
            "func _complete_movement_handoff_after_frame(",
            "_targeted_post_movement_refresh_count",
            "_last_post_movement_refresh_usec",
            "await get_tree().process_frame",
            "No fixed dead-air",
            "end_visibility_recalculation_deferral_for_units(",
            "moved_unit_ids",
        ], failures,
    )

    finish_block = function_block(
        "presentation/tactical/tactical_screen.gd",
        "_finish_movement_presentation",
    )
    if "_process_state_change_after_commit" in finish_block:
        failures.append("Movement completion still uses the broad state-change presentation path.")
    if "create_timer" in finish_block:
        failures.append("Movement completion still contains a fixed timer.")

    screen_text = (ROOT / "presentation/tactical/tactical_screen.gd").read_text(encoding="utf-8")
    for delay in ["create_timer(0.28)", "create_timer(0.35)"]:
        if delay in screen_text:
            failures.append(f"Post-action dead-air timer remains: {delay}")

    service_text = (
        ROOT / "application/tactical/visibility/tactical_visibility_service.gd"
    ).read_text(encoding="utf-8")
    perception_callback = function_block(
        "application/tactical/visibility/tactical_visibility_service.gd",
        "_on_tactical_state_changed_with_flags",
    )
    if "current_perception_resolved" not in perception_callback:
        failures.append("Perception commits are not explicitly excluded from tile visibility rebuilding.")

    require_tokens(
        "README_FIRST.txt",
        ["STAGE 4.4e3", "POST-MOVEMENT DELTA REFRESH"],
        failures,
    )

    if failures:
        print("Stage 4.4e3 static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 4.4e3 static validation passed.")
    print(" - Ordinary movement uses per-unit visibility contributions.")
    print(" - Post-movement presentation uses one targeted refresh.")
    print(" - Fixed 0.28 s and 0.35 s post-action waits are removed.")
    print(" - Perception commits no longer trigger all-team tile visibility scans.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
