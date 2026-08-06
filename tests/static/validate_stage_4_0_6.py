#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []

    for path in [
        "domain/tactical/action_budget_state.gd",
        "domain/tactical/action_economy_rules.gd",
        "domain/combat/attack_definition.gd",
        "domain/characters/resolution/resolved_character_snapshot.gd",
        "application/tactical/combat/attack_preview_query.gd",
        "application/tactical/combat/attack_handler.gd",
        "presentation/tactical/tactical_screen.gd",
        "presentation/tactical/tactical_screen.tscn",
        "content/actions/mace_attack.tres",
        "content/items/mace.tres",
        "tests/combat/stage_4_0_practice_dummy_tests.gd",
    ]:
        require_file(path, failures)

    require_absent("content/actions/mace_nonlethal_attack.tres", failures)

    require_tokens(
        "domain/tactical/action_budget_state.gd",
        [
            "ordinary_attack_available",
            "func spend_ordinary_attack()",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/action_economy_rules.gd",
        [
            "func attack_unavailable_reason(",
            "already made its normal attack",
            "func spend_attack(",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "damage_channel: StringName",
            "nonlethal_penalty = -4",
            "trait.take_them_alive",
            "_is_blunt_damage_type",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "_selected_damage_channel",
            "_cycle_attack_mode",
            '"NORMAL · %s" % mode_text',
            '"NONLETHAL"',
            '"LETHAL"',
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.tscn",
        ['node name="Action5"'],
        failures,
    )
    require_tokens(
        "content/items/mace.tres",
        ['granted_action_ids = Array[StringName]([&"action.mace_attack"])'],
        failures,
    )
    require_tokens(
        "tests/combat/stage_4_0_practice_dummy_tests.gd",
        [
            "_test_single_normal_attack_allowance",
            "_test_nonlethal_mode_and_marauder_exemption",
            "A second normal attack must be rejected",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.0.6",
        failures,
        [
            "A unit can make only one normal attack per activation.",
            "Remaining movement capacity is still usable after that attack.",
            "Every supported weapon attack can choose lethal or nonlethal damage.",
            "Nonlethal attacks normally take -4 to hit.",
            "Marauder Take Them Alive ignores that penalty with blunt weapons.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
