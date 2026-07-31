#!/usr/bin/env python3
import sys
from validation_common import *


def _function_block(text: str, function_name: str) -> str:
    marker = f"func {function_name}"
    start = text.find(marker)
    if start < 0:
        return ""
    next_function = text.find("\nfunc ", start + len(marker))
    return text[start:] if next_function < 0 else text[start:next_function]


def main() -> int:
    failures: list[str] = []

    for path in [
        "STAGE_4_2_5_4B_CONTEXTUAL_HAND_ATTACKS_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_2_5_4B_CONTEXTUAL_HAND_ATTACKS.md",
        "presentation/tactical/tactical_screen.gd",
        "presentation/tactical/tactical_screen.tscn",
        "tests/tactical/stage_4_2_5_4b_contextual_hand_attack_tests.gd",
        "tests/tactical/run_stage_4_2_5_4b_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "_selected_hand_by_unit_id",
            "_contextual_attack_hover_active",
            "func _apply_hand_selection(",
            "func _refresh_contextual_hand_attack_hover_preview(",
            "func _sync_selected_hand_attack(",
            "A hostile click is always interpreted as an attempted strike",
            "_execute_direct_attack(clicked_unit)",
            "Left-click a legal hostile to attack.",
            "Contextual attacks are unavailable.",
            "_attack_targeting or _contextual_attack_hover_active",
            "button_pressed = (",
            "persistent hand choice",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.tscn",
        [
            "keep the Secondary Hand selected for contextual basic attacks",
            "keep the Primary Hand selected for contextual basic attacks",
            "toggle_mode = true",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_2_5_4b_contextual_hand_attack_tests.gd",
        [
            "_test_screen_defaults_to_a_persistent_hand_without_targeting",
            "_test_hand_memory_is_per_character",
            "_test_selected_hand_attack_uses_authoritative_attack_pipeline",
            "Selecting the default hand must not enter basic-attack targeting mode.",
        ],
        failures,
    )

    screen_text = require_file("presentation/tactical/tactical_screen.gd", failures)
    hand_block = _function_block(screen_text, "_select_weapon_from_hand")
    if not hand_block:
        failures.append("Could not inspect _select_weapon_from_hand().")
    elif "_begin_attack_targeting(" in hand_block:
        failures.append("Clicking a hand still enters automatic attack targeting.")

    default_block = _function_block(screen_text, "_select_default_weapon_for_unit")
    if not default_block:
        failures.append("Could not inspect _select_default_weapon_for_unit().")
    elif "_begin_attack_targeting(" in default_block:
        failures.append("Selecting a character still enters automatic attack targeting.")

    left_click_block = _function_block(screen_text, "_on_board_tile_left_clicked")
    hostile_index = left_click_block.find("_execute_direct_attack(clicked_unit)")
    movement_index = left_click_block.find("_handle_left_click(tile)")
    if hostile_index < 0 or movement_index < 0 or hostile_index > movement_index:
        failures.append("Hostile contextual attacks do not take priority over movement.")

    clear_block = _function_block(screen_text, "_clear_weapon_selection")
    for forbidden in [
        '_selected_weapon_hand_kind = &""',
        '_selected_weapon_item_id = &""',
    ]:
        if forbidden in clear_block:
            failures.append(
                f"Cancelling explicit targeting still clears persistent hand state: {forbidden}"
            )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.5.4b",
        failures,
        [
            "Selecting a character no longer enters basic-attack targeting.",
            "One hand remains selected and is remembered independently per character.",
            "Hovering a hostile previews the selected hand's basic attack.",
            "Left-clicking a hostile attacks immediately when legal and never plans movement.",
            "Explicit complex targeting remains available without clearing hand selection.",
            "Movement, facing, Stealth, perception, initiative and AI remain unchanged.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
