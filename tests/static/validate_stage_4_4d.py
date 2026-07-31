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
        "STAGE_4_4D_COVER_READABILITY_AUTOMATIC_PEEK_LEAN_INTERACT_RELEASE_NOTES.txt",
        "STAGE_4_4D_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_4D_COVER_READABILITY_AUTOMATIC_PEEK_LEAN_INTERACT.md",
        "domain/tactical/geometry/tactical_observation_origin.gd",
        "domain/tactical/geometry/tactical_observation_origin_query.gd",
        "domain/tactical/geometry/tactical_firing_origin.gd",
        "domain/tactical/geometry/tactical_firing_origin_query.gd",
        "tests/tactical/stage_4_4d_cover_readability_automatic_opening_tests.gd",
        "tests/tactical/run_stage_4_4d_tests.gd",
    ]
    for path in required_files:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/geometry/tactical_observation_origin_query.gd",
        [
            "class_name TacticalObservationOriginQuery",
            "static func legal_origins(",
            "uses_automatic_peek = true",
            "KIND_OPENING_PEEK",
            "KIND_CORNER_PEEK",
            "free Peek rule",
        ], failures,
    )
    require_tokens(
        "domain/tactical/geometry/tactical_firing_origin_query.gd",
        [
            "class_name TacticalFiringOriginQuery",
            "static func legal_origins(",
            "uses_automatic_lean = true",
            "KIND_OPENING_LEAN",
            "KIND_CORNER_LEAN",
        ], failures,
    )
    require_tokens(
        "application/tactical/visibility/tactical_visibility_service.gd",
        [
            "OBSERVATION_ORIGIN_QUERY_SCRIPT",
            "func _reveal_from_origin(",
            "legal_origins(",
            "Peek is now an automatic",
        ], failures,
    )
    require_tokens(
        "application/tactical/awareness/detection_observer_query.gd",
        [
            "OBSERVATION_ORIGIN_QUERY_SCRIPT",
            "_has_los_from_observation_origins",
            "legal_origins(",
        ], failures,
    )
    require_tokens(
        "application/tactical/combat/tactical_attack_preview.gd",
        [
            "var uses_automatic_lean: bool",
            "var firing_origin_kind: StringName",
            "var firing_edge_id: StringName",
            "var normal_origin_hit_chance: int",
            "var chosen_origin_hit_chance: int",
        ], failures,
    )
    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "func _best_geometry_for_attack(",
            "TacticalFiringOriginQuery.legal_origins(",
            '"uses_automatic_lean"',
            "preview.action_cost_feet = cost_feet",
            "attack.resolved_cost()",
        ], failures,
    )
    require_tokens(
        "domain/tactical/geometry/tactical_cover_preview.gd",
        [
            "func worst_category()",
            "func worst_label()",
            "func compact_breakdown()",
            'return "EXPOSED"',
        ], failures,
    )
    require_tokens(
        "application/tactical/environment/tactical_opening_handler.gd",
        [
            "func available_interactions(",
            '&"toggle_opening"',
            '&"pick_lock"',
            "Stage 4.4d makes Peek an automatic",
        ], failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "_interact_button.pressed.connect(_toggle_interact_mode)",
            "func _toggle_interact_mode()",
            "func _handle_interact_click(",
            "opening_interaction_options",
            "Right-click is reserved for facing",
            "Automatic Lean",
        ], failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "func _draw_inked_door(",
            "func _draw_inked_window(",
            "func _draw_physical_edge_cover(",
            "func _draw_destination_cover_preview()",
            "func _draw_interaction_highlights()",
            "func _draw_automatic_peek_markers()",
            "func _draw_automatic_lean_origin()",
            "worst_label()",
            "compact_breakdown()",
        ], failures,
    )
    require_tokens(
        "application/tactical/facades/tactical_screen_facade.gd",
        [
            "func opening_interaction_options(",
            "func adjacent_interactable_openings(",
            "func observation_origins_for_unit(",
            "func physical_edge_cover(",
        ], failures,
    )
    require_tokens(
        "tests/tactical/stage_4_4d_cover_readability_automatic_opening_tests.gd",
        [
            "_test_automatic_peek_origins_are_free(failures)",
            "_test_automatic_lean_origins_are_free(failures)",
            "_test_interact_options_exclude_peek_and_lean(failures)",
            "_test_cover_preview_worst_case_summary(failures)",
            "_test_physical_edge_cover_preview(failures)",
            "_test_ranged_preview_never_adds_lean_cost(failures)",
        ], failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.4d",
            "AUTOMATIC PEEK",
            "run_stage_4_4d_tests.gd",
            "validate_stage_4_4d.py",
        ], failures,
    )
    require_tokens(
        "SEETHE_PROJECT_STRUCTURE_GUIDE_V2.md",
        [
            "Stage 4.4d — Cover Readability, Automatic Peek and Lean, and Interact",
            "TacticalObservationOriginQuery",
            "TacticalFiringOriginQuery",
            "Interact button",
        ], failures,
    )

    peek_block = function_block(
        "application/tactical/environment/tactical_opening_handler.gd", "peek"
    )
    corner_block = function_block(
        "application/tactical/environment/tactical_opening_handler.gd", "peek_around_corner"
    )
    for name, block in [("peek", peek_block), ("peek_around_corner", corner_block)]:
        if not block:
            failures.append(f"Missing compatibility function {name}.")
            continue
        if "spend_normal_capacity" in block or "OPENING_COST_FEET" in block:
            failures.append(f"{name} must not spend movement or action capacity in Stage 4.4d.")

    screen_text = (ROOT / "presentation/tactical/tactical_screen.gd").read_text(encoding="utf-8")
    prohibited_menu_strings = ["Peek — 5 ft", "Peek Around Corner", "Lean Attack Around"]
    for token in prohibited_menu_strings:
        if token in screen_text:
            failures.append(f"Right-click/Interact UI still exposes obsolete command text: {token}")

    if failures:
        print("Stage 4.4d static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Stage 4.4d static validation passed.")
    print(" - Movement destinations expose compact worst-case and physical-edge cover before commitment.")
    print(" - Peek visibility is automatic, symmetric and free of movement/action expenditure.")
    print(" - Ranged attacks automatically choose legal centre or lean origins without extra cost.")
    print(" - Thick inked openings use the existing Interact action while right-click remains facing.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
