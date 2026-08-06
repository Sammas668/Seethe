#!/usr/bin/env python3
from pathlib import Path
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
        "STAGE_4_5E2_IMMEDIATE_COMBAT_FEEDBACK_RELEASE_NOTES.txt",
        "STAGE_4_5E2_PATCH_README.txt",
        "STAGE_4_5E2_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_5E2_IMMEDIATE_COMBAT_FEEDBACK.md",
        "tests/tactical/stage_4_5e2_combat_feedback_tests.gd",
        "tests/tactical/run_stage_4_5e2_tests.gd",
    ]:
        require_file(path, failures)

    query_path = "application/tactical/combat/attack_preview_query.gd"
    query = require_file(query_path, failures)
    validator = function_block(query_path, "validate_committed_preview")
    for token in [
        "expected_state_revision",
        "expected_geometry_revision",
        "ActionEconomyRules.attack_unavailable_reason",
        "TacticalMeleeReachRules.can_reach",
        "commit_previews_reused",
        "OperationResult.ok(preview",
    ]:
        if token not in validator:
            failures.append(f"Lightweight attack commit validation missing: {token}")
    for forbidden in [
        '_geometry_cache.evaluate',
        '_best_geometry_for_attack',
        'TacticalCombatGeometryQuery.evaluate',
        'execute(\n',
    ]:
        if forbidden in validator:
            failures.append(
                f"Commit validator must not rebuild exact attack geometry: {forbidden}"
            )

    handler_path = "application/tactical/combat/attack_handler.gd"
    handler = require_file(handler_path, failures)
    execute = function_block(handler_path, "execute_preview")
    if '_preview_query.call(\n\t\t"execute"' in execute:
        failures.append("Attack commit must not call the complete preview query.")
    for token in [
        '"validate_committed_preview"',
        'Callable(self, "_publish_attack_impact")',
        "commit_preview_reuses",
        "last_attack_commit_total_usec",
    ]:
        if token not in handler:
            failures.append(f"Attack commit/impact contract missing: {token}")
    impact_index = execute.find('Callable(self, "_publish_attack_impact")')
    commit_index = execute.find("_state_store.commit(")
    if impact_index < 0 or commit_index < 0 or impact_index > commit_index:
        failures.append(
            "Immediate combat impact must be registered as a post-commit callback before commit."
        )

    screen_path = "presentation/tactical/tactical_screen.gd"
    screen = require_file(screen_path, failures)
    state_block = function_block(screen_path, "_on_state_changed")
    if 'reason == &"attack_resolved"' not in state_block:
        failures.append("attack_resolved state changes must enter the deferred reconciliation path.")
    for token in [
        "_schedule_post_attack_reconciliation",
        "_flush_post_attack_reconciliation",
        '_process_state_change_after_commit(&"attack_resolved", true, false)',
        "_schedule_lazy_post_attack_target_scan",
        "_legal_attack_targets_dirty",
        'snapshot["post_attack"]',
    ]:
        if token not in screen:
            failures.append(f"Post-attack consolidation contract missing: {token}")

    direct = function_block(screen_path, "_execute_direct_attack")
    success_tail = direct[direct.find("var result: OperationResult"):]
    if "_refresh_all_presentation" in success_tail:
        failures.append(
            "Successful direct attacks must not perform a duplicate broad refresh."
        )
    for forbidden in [
        "_refresh_contextual_hand_attack_hover_preview()",
        "_refresh_legal_attack_targets()",
    ]:
        if forbidden in success_tail:
            failures.append(
                f"Direct attack must defer post-commit preview work: {forbidden}"
            )

    confirm = function_block(screen_path, "_confirm_selected_attack")
    if "_refresh_all_presentation()" in confirm:
        failures.append(
            "Confirmed attacks must leave broad reconciliation to attack_resolved."
        )

    damage = function_block(screen_path, "_apply_damage_committed_presentation")
    for token in [
        "_refresh_unit_status_badge_immediately(target_id)",
        "view.play_damage_reaction()",
        "_immediate_combat_impacts_presented += 1",
    ]:
        if token not in damage:
            failures.append(f"Immediate hit presentation missing: {token}")

    require_tokens(
        "tests/tactical/stage_4_5e2_combat_feedback_tests.gd",
        [
            "Commit must not rebuild five-sample geometry when revisions still match.",
            "Committed combat impact must publish before broad state reconciliation.",
            "commit_preview_reuses",
        ],
        failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.5e2",
            "IMMEDIATE COMBAT FEEDBACK AND POST-ATTACK REFRESH CONSOLIDATION",
            "run_stage_4_5e2_tests.gd",
        ],
        failures,
    )

    if failures:
        print("Stage 4.5e2 static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 4.5e2 static validation passed.")
    print(" - Commit reuses unchanged exact previews without geometry rebuilds.")
    print(" - Combat impact publishes before broad state reconciliation.")
    print(" - Successful attacks use one deferred post-attack refresh.")
    print(" - Contextual hover and legal targets are not rebuilt synchronously.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
