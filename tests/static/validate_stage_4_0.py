#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    for path in [
        "application/tactical/combat/tactical_attack_preview.gd",
        "application/tactical/combat/tactical_attack_resolution.gd",
        "application/tactical/combat/tactical_dice_roller.gd",
        "application/tactical/combat/attack_preview_query.gd",
        "application/tactical/combat/attack_handler.gd",
        "content/characters/prototypes/practice_dummy.tres",
        "content/defences/practice_dummy.tres",
        "tests/combat/stage_4_0_practice_dummy_tests.gd",
        "tests/combat/run_stage_4_0_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "_definition_is_supported",
            "is_implemented_melee_weapon_attack",
            "controller_can_use",
            "hit_chance_percent",
            "power_attack_value",
            "expected_state_revision",
            "_minimum_distance_feet",
            "state.granted_action_ids_for_unit",
        ],
        failures,
    )
    forbid_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "SUPPORTED_ACTION_IDS",
            "AI_SUPPORTED_ACTION_IDS",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_handler.gd",
        [
            "TacticalChangeSet.new",
            "ActionEconomyRules.spend",
            "critical_confirmation",
            "natural_one",
            "natural_twenty",
            "critical_multiplier",
            "attack_resolved",
            "roll_records",
            "effect_records",
            "_state_store.commit",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/tactical_dice_roller.gd",
        [
            "set_seed",
            "set_scripted_results",
            "roll_die",
            "roll_dice",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "_begin_attack_targeting",
            "_execute_direct_attack",
            "_refresh_attack_cursor_preview",
            "_select_weapon_from_hand",
            "_adjust_power_attack",
            "_attack_preview_status",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "_draw_attack_targets",
            "_legal_attack_target_ids",
            "LEGAL_TARGET_COLOR",
            "SELECTED_TARGET_COLOR",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/debug/tactical_sandbox_factory.gd",
        [
            "PRACTICE_DUMMY_ID",
            "PRACTICE_DUMMY_TEMPLATE_ID",
            "Vector2i(3, 2)",
        ],
        failures,
    )
    require_tokens(
        "tests/combat/stage_4_0_practice_dummy_tests.gd",
        [
            "_test_normal_hit_transaction_and_log",
            "_test_natural_one_automatic_miss",
            "_test_natural_twenty_and_critical_confirmation",
            "_test_power_attack_and_rage_recalculation",
            "_test_seeded_rolls_are_repeatable",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)
    return finish(
        "Stage 4.0",
        failures,
        [
            "Axe, lethal mace, and melee dagger attacks use one preview and commit pipeline.",
            "Natural 1, natural 20, critical confirmation, Power Attack, and Rage are resolved visibly.",
            "Attack cost and damage commit atomically through TacticalStateStore.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
