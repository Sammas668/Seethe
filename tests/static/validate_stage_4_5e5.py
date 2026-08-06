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


def match_case_block(text: str, marker: str, next_marker: str) -> str:
    start = text.find(marker)
    if start < 0:
        return ""
    end = text.find(next_marker, start + len(marker))
    return text[start:] if end < 0 else text[start:end]


def main() -> int:
    failures: list[str] = []
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    for path in [
        "STAGE_4_5E5_PRECISE_ATTACK_INVALIDATION_RELEASE_NOTES.txt",
        "STAGE_4_5E5_PATCH_README.txt",
        "STAGE_4_5E5_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_5E5_PRECISE_ATTACK_INVALIDATION_VISIBILITY_CRITICAL_PATH.md",
        "tests/tactical/stage_4_5e5_precise_attack_invalidation_tests.gd",
        "tests/tactical/run_stage_4_5e5_tests.gd",
    ]:
        require_file(path, failures)

    flags_path = "domain/tactical/tactical_invalidation_flags.gd"
    flags_text = require_file(flags_path, failures)
    attack_case = match_case_block(
        flags_text, '\t\t&"attack_resolved":', '\t\t&"character_resolved":'
    )
    if not attack_case:
        failures.append("attack_resolved invalidation case is missing.")
    else:
        if "flags.token_status_changed = true" not in attack_case:
            failures.append("Ordinary attacks must invalidate token status.")
        for forbidden in [
            "flags.occupancy_changed = true",
            "flags.visibility_changed = true",
            "flags.geometry_changed = true",
        ]:
            if forbidden in attack_case:
                failures.append(
                    f"Ordinary attack defaults must not include broad invalidation: {forbidden}"
                )

    visibility_path = "application/tactical/visibility/tactical_visibility_service.gd"
    visibility_text = require_file(visibility_path, failures)
    visibility_handler = function_block(
        visibility_path, "_on_tactical_state_changed_with_flags"
    )
    if '&"attack_resolved": true' in visibility_text:
        failures.append(
            "attack_resolved must not remain a fallback visibility-affecting reason."
        )
    if "if not flags.visibility_changed:" not in visibility_handler:
        failures.append(
            "Visibility service must use the explicit visibility_changed flag."
        )
    for forbidden in ["or flags.geometry_changed", "or flags.occupancy_changed"]:
        if forbidden in visibility_handler:
            failures.append(
                f"Visibility service still infers fog invalidation from {forbidden}."
            )

    handler_path = "application/tactical/combat/attack_handler.gd"
    handler_text = require_file(handler_path, failures)
    execute = function_block(handler_path, "execute_preview")
    for token in [
        "var attack_flags := TacticalInvalidationFlags.new()",
        "attack_flags.token_status_changed = true",
        "changes.set_invalidation_flags(attack_flags)",
        "attack_flags.occupancy_changed = true",
        "attack_flags.inventory_changed = true",
        "attack_flags.initiative_changed = true",
        'Callable(self, "_record_attack_invalidation_profile")',
    ]:
        if token not in execute:
            failures.append(f"Precise attack invalidation contract missing: {token}")

    cover_apply = function_block(
        handler_path, "_apply_cover_source_damage_and_salvage"
    )
    for token in [
        "invalidation_flags.environment_visuals_changed = true",
        "invalidation_flags.geometry_changed = true",
        "invalidation_flags.visibility_changed = true",
        "_cover_integrity_blocks_sight",
        "invalidation_flags.inventory_changed = true",
    ]:
        if token not in cover_apply:
            failures.append(f"Structural attack invalidation missing: {token}")

    for token in [
        '"ordinary_attacks_without_visibility_invalidation"',
        '"attack_visibility_invalidations"',
        '"attack_geometry_invalidations"',
    ]:
        if token not in handler_text:
            failures.append(f"Attack invalidation instrumentation missing: {token}")

    board_path = "presentation/tactical/tactical_board_view.gd"
    board_text = require_file(board_path, failures)
    board_notify = function_block(board_path, "notify_state_changed")
    for token in [
        "flags: TacticalInvalidationFlags = null",
        "flags.visibility_changed or flags.exploration_changed",
        "flags.geometry_changed or flags.environment_visuals_changed",
    ]:
        if token not in board_notify:
            failures.append(f"Flag-aware board refresh missing: {token}")
    if '&"attack_resolved"' in board_notify:
        failures.append(
            "Board fog fallback must not redraw the full fog layer for ordinary attacks."
        )

    screen_path = "presentation/tactical/tactical_screen.gd"
    screen_text = require_file(screen_path, failures)
    for token in [
        "_facade.state_changed_with_flags.connect(_on_state_changed_with_flags)",
        "_pending_post_attack_flags",
        "_active_state_change_flags",
        "_deferred_state_change_flags",
        '"notify_state_changed", reason, deferred_flags',
    ]:
        if token not in screen_text:
            failures.append(f"Screen invalidation forwarding missing: {token}")
    deferred_visibility = function_block(
        screen_path, "_deferred_visibility_requires_full_rebuild"
    )
    if '&"attack_resolved"' in deferred_visibility:
        failures.append(
            "Reaction attacks must not force full visibility merely because an attack resolved."
        )
    if "flags.visibility_changed" not in deferred_visibility:
        failures.append(
            "Deferred movement visibility must inspect precise invalidation flags."
        )

    require_tokens(
        "tests/tactical/stage_4_5e5_precise_attack_invalidation_tests.gd",
        [
            "An ordinary attack must not recalculate battlefield visibility.",
            "Ordinary attack flags must not invalidate occupancy, geometry, or visibility.",
            "The ordinary attack invalidation counter must advance.",
        ],
        failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.5e5",
            "PRECISE ATTACK INVALIDATION",
            "run_stage_4_5e5_tests.gd",
        ],
        failures,
    )

    if failures:
        print("Stage 4.5e5 static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 4.5e5 static validation passed.")
    print(" - Ordinary attacks no longer invalidate battlefield visibility.")
    print(" - Fog refreshes consume precise state-change flags.")
    print(" - Structural attacks escalate geometry and sight invalidation only as needed.")
    print(" - Reaction attacks no longer force a full visibility rebuild by reason alone.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
