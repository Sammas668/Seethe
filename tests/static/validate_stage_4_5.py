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

    required_files = [
        "STAGE_4_5_REACTIONS_THREATENED_MOVEMENT_RELEASE_NOTES.txt",
        "STAGE_4_5_PATCH_README.txt",
        "STAGE_4_5_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_5_REACTIONS_THREATENED_MOVEMENT.md",
        "domain/tactical/reactions/reaction_resource_state.gd",
        "domain/tactical/reactions/reaction_reservation_state.gd",
        "domain/tactical/reactions/reaction_candidate.gd",
        "domain/tactical/reactions/reaction_decision_request.gd",
        "domain/tactical/reactions/reaction_decision_resolution.gd",
        "domain/tactical/reactions/movement_reaction_preview.gd",
        "application/tactical/reactions/tactical_reaction_service.gd",
        "presentation/tactical/icons/reaction_aoo_icon.svg",
        "presentation/tactical/icons/reaction_overwatch_bow_icon.svg",
        "presentation/tactical/icons/reaction_brace_spear_icon.svg",
        "tests/tactical/stage_4_5_reaction_tests.gd",
        "tests/tactical/run_stage_4_5_tests.gd",
    ]
    for path in required_files:
        require_file(path, failures)

    budget = require_file("domain/tactical/action_budget_state.gd", failures)
    for token in [
        "ReactionResourceState.AVAILABLE",
        "ReactionResourceState.RESERVED",
        "ReactionResourceState.SPENT",
        "func reserve_reaction(",
        "func spend_reaction(",
        "func cancel_reaction_reservation(",
        "func reaction_snapshot(",
        "legacy snapshots stored a single boolean",
    ]:
        if token not in budget:
            failures.append(f"Reaction resource contract missing: {token}")

    service_path = "application/tactical/reactions/tactical_reaction_service.gd"
    service = require_file(service_path, failures)
    for token in [
        "signal reaction_decision_requested",
        "signal reaction_decision_cleared",
        "func preview_path_reactions(",
        "func first_player_reaction_for_path(",
        "func preview_provoking_action_reactions(",
        "func resolve_ai_reactions_for_provoking_action(",
        "func first_player_reaction_for_provoking_action(",
        "func open_player_decision(",
        "func resolve_pending_decision(",
        "func prepare_overwatch(",
        "func prepare_brace(",
        "func prepare_best_ai_reservation(",
        'request.use_label = "Use Reaction"',
        'request.decline_label = "Decline"',
        'request.use_label = "Fire"',
        'request.decline_label = "Hold Fire"',
        'request.use_label = "Use Brace"',
        'request.decline_label = "Hold Brace"',
        "not mover.disengage_active",
        "ReactionCandidate.TIMING_BEFORE_ENTRY",
        "ReactionCandidate.TIMING_AFTER_ENTRY",
        "_declined_candidate_keys",
        "_ensure_reaction_indexes",
        "_threat_source_ids_by_tile",
        "_reserved_source_ids_by_tile",
        "threat_cache_rebuilds",
        "_reaction_tie_break",
        "reserved_weapon_item_id = _source_item_id",
        "mover.stealth_enabled",
        "is_revealed_to_squad",
    ]:
        if token not in service:
            failures.append(f"Shared Reaction pipeline missing: {token}")
    if "create_timer" in service:
        failures.append("Reaction authority must not introduce presentation timers.")

    screen_path = "presentation/tactical/tactical_screen.gd"
    screen = require_file(screen_path, failures)
    hover = function_block(screen_path, "_on_board_tile_hovered")
    destination = function_block(screen_path, "_destination_preview_for")
    if "preview_movement_reactions" in hover:
        failures.append("Cursor hover must not calculate Reaction previews.")
    if "preview_movement_reactions" not in destination:
        failures.append("Clicked destination preview must calculate one Reaction preview.")
    for token in [
        "ReactionDecisionPrompt",
        "_resolve_visible_reaction_prompt",
        "KEY_ESCAPE",
        "MOUSE_BUTTON_RIGHT",
        "_resolve_enemy_phase_with_reaction_prompts",
        "_resolve_initiative_ai_with_reaction_prompts",
        "ReactionReservationState.KIND_OVERWATCH",
        "ReactionReservationState.KIND_BRACE",
    ]:
        if token not in screen:
            failures.append(f"Reaction presentation/decision wiring missing: {token}")

    enemy_phase_loop = function_block(
        screen_path,
        "_resolve_enemy_phase_with_reaction_prompts",
    )
    initiative_loop = function_block(
        screen_path,
        "_resolve_initiative_ai_with_reaction_prompts",
    )
    for label, block in [
        ("enemy-phase Reaction coroutine", enemy_phase_loop),
        ("initiative AI Reaction coroutine", initiative_loop),
    ]:
        if "return OperationResult.fail(" not in block:
            failures.append(
                f"{label} needs an explicit fallback return for the GDScript parser."
            )

    board = require_file("presentation/tactical/tactical_board_view.gd", failures)
    for token in [
        "reaction_aoo_icon.svg",
        "reaction_overwatch_bow_icon.svg",
        "reaction_brace_spear_icon.svg",
        "_draw_reaction_badges",
        "hit_chance_percent",
        "_tile_has_reaction_badge",
    ]:
        if token not in board:
            failures.append(f"Reaction tile badge contract missing: {token}")
    if "reaction_overwatch_bow_icon.svg" not in board:
        failures.append("Overwatch must use the dedicated bow icon.")

    enemy = require_file("application/tactical/ai/enemy_turn_handler.gd", failures)
    for token in [
        "reaction_pending",
        "open_pending_reaction_decision",
        "resume_after_reaction",
        "prepare_best_ai_reservation",
        "first_player_reaction_for_provoking_action",
        '"context_kind": &"provoking_action"',
    ]:
        if token not in enemy:
            failures.append(f"AI Reaction integration missing: {token}")

    facade = require_file("application/tactical/facades/tactical_screen_facade.gd", failures)
    for token in [
        "preview_provoking_action_reactions",
        "resolve_ai_reactions_for_provoking_action",
        "provoking_reaction_stopped_action",
        "attack_no_longer_legal_after_reaction",
    ]:
        if token not in facade:
            failures.append(f"Provoking-action Reaction integration missing: {token}")

    require_tokens(
        "content/actions/training_shortbow_attack.tres",
        ["provokes = true"],
        failures,
    )

    unit_view = require_file("presentation/tactical/tactical_unit_view.gd", failures)
    for token in [
        "movement_reaction_presentation",
        "reaction_events",
        "TIMING_BEFORE_ENTRY",
        "TIMING_AFTER_ENTRY",
    ]:
        if token not in unit_view:
            failures.append(f"Spatial Reaction presentation missing: {token}")

    # Rollback snapshots must preserve complete reservations, not flatten them.
    for rel in [
        "application/tactical/body/tactical_body_action_handler.gd",
        "application/tactical/spend_action_handler.gd",
        "application/tactical/life/tactical_life_state_handler.gd",
        "application/tactical/environment/tactical_structure_attack_handler.gd",
        "application/tactical/combat/attack_handler.gd",
        "application/tactical/end_phase_handler.gd",
        "application/tactical/awareness/detection_batch_transaction_support.gd",
        "application/tactical/awareness/tactical_detection_service.gd",
        "application/tactical/initiative/initiative_turn_handler.gd",
        "application/tactical/tactical_inventory_transfer_handler.gd",
    ]:
        body = require_file(rel, failures)
        if '"reaction": unit.action_budget.reaction_available' in body:
            failures.append(f"{rel} still flattens a Reaction reservation to a boolean.")

    require_tokens(
        "application/tactical/tactical_inventory_transfer_handler.gd",
        [
            "_transfer_cancels_reaction_reservation",
            "cancel_reaction_reservation",
            "reserved_weapon_item_id",
        ],
        failures,
    )

    attack_preview_query = require_file(
        "application/tactical/combat/attack_preview_query.gd",
        failures,
    )
    if "TacticalGridDistance.distance_feet" in attack_preview_query:
        failures.append(
            "Attack preview still calls nonexistent TacticalGridDistance.distance_feet()."
        )
    if "TacticalGridDistance.feet_between(first, second)" not in attack_preview_query:
        failures.append(
            "Attack preview must use the existing TacticalGridDistance.feet_between() API."
        )

    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.5",
            "REACTIONS AND THREATENED MOVEMENT",
            "run_stage_4_5_tests.gd",
        ],
        failures,
    )

    if failures:
        print("Stage 4.5 static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 4.5 static validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
