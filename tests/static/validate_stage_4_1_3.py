#!/usr/bin/env python3
import re
import sys
from pathlib import Path
from validation_common import *


TACTICAL_MUTATORS = [
    "add_unit",
    "remove_unit",
    "set_unit_position",
    "add_item",
    "remove_item",
    "move_item",
    "rebuild_unit_occupancy",
    "rebuild_ground_item_index",
]


def validate_presentation_does_not_mutate_live_state(failures: list[str]) -> None:
    presentation_root = ROOT / "presentation"
    for path in presentation_root.rglob("*.gd"):
        text = path.read_text(encoding="utf-8")
        for mutator in TACTICAL_MUTATORS:
            patterns = [
                rf"\.state\(\)\s*\.\s*{re.escape(mutator)}\s*\(",
                rf"\.state\s*\.\s*{re.escape(mutator)}\s*\(",
            ]
            if any(re.search(pattern, text, flags=re.MULTILINE) for pattern in patterns):
                failures.append(
                    f"Presentation bypasses TacticalStateStore in "
                    f"{path.relative_to(ROOT)} via {mutator}()."
                )


def main() -> int:
    failures: list[str] = []

    for path in [
        "domain/combat/attack_definition.gd",
        "application/tactical/combat/attack_preview_query.gd",
        "application/tactical/combat/attack_handler.gd",
        "application/tactical/combat/tactical_dice_roller.gd",
        "application/tactical/ai/enemy_action_plan.gd",
        "application/tactical/ai/enemy_action_planner.gd",
        "application/tactical/ai/enemy_turn_handler.gd",
        "tests/combat/stage_4_1_3_combat_integrity_tests.gd",
        "tests/combat/run_stage_4_1_3_tests.gd",
    ]:
        require_file(path, failures)

    require_absent("content/actions/mace_nonlethal_attack.tres", failures)

    require_tokens(
        "domain/combat/attack_definition.gd",
        [
            "implementation_profile_id",
            "IMPLEMENTATION_MELEE_WEAPON",
            "player_usable",
            "ai_usable",
            "supports_power_attack",
            "supports_nonlethal",
            "is_implemented_melee_weapon_attack",
            "controller_can_use",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "_definition_is_supported",
            "attack.is_implemented_melee_weapon_attack()",
            "attack.controller_can_use",
            "attack.supports_nonlethal",
            "attack.allows_power_attack()",
        ],
        failures,
    )
    forbid_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "SUPPORTED_ACTION_IDS",
            "AI_SUPPORTED_ACTION_IDS",
            "action.raiders_axe_attack",
            "action.training_spear_attack",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/tactical_dice_roller.gd",
        [
            "func snapshot_state()",
            "func restore_state(",
            '"rng_state"',
            '"scripted_index"',
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_handler.gd",
        [
            "Randomness is resolved before the TacticalChangeSet begins",
            "_resolve_roll_outcome",
            "_apply_resolved_attack",
            'call("snapshot_state")',
            'call("restore_state", dice_checkpoint)',
        ],
        failures,
    )

    handler_text = (ROOT / "application/tactical/combat/attack_handler.gd").read_text(
        encoding="utf-8"
    )
    stage_start = handler_text.find("var changes: TacticalChangeSet")
    commit_start = handler_text.find("_state_store.commit", stage_start)
    staged_region = handler_text[stage_start:commit_start]
    if "roll_die" in staged_region or "roll_dice" in staged_region:
        failures.append("Random dice calls remain inside the staged attack mutation.")

    require_tokens(
        "application/tactical/ai/enemy_action_planner.gd",
        [
            "func plan_activation",
            "for target: TacticalUnitState in _state_store.state.get_units()",
            "TEAM_RELATIONS_SCRIPT.are_hostile",
            "is_supported_ai_action",
            "_best_path_to_attack_position",
        ],
        failures,
    )
    forbid_tokens(
        "application/tactical/ai/enemy_action_planner.gd",
        ["get_player_units()"],
        failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_turn_handler.gd",
        [
            "ENEMY_ACTION_PLANNER_SCRIPT",
            'call("plan_activation", unit)',
            "_recover_activation_failure",
            "_record_ai_failure",
            "The Enemy Turn will continue with the next participant.",
        ],
        failures,
    )
    require_tokens(
        "tests/combat/stage_4_1_3_combat_integrity_tests.gd",
        [
            "_test_failed_commit_restores_dice_stream",
            "_test_definition_capabilities_replace_weapon_whitelist",
            "_test_enemy_failure_finalizes_and_continues",
            "action.test_new_sword_attack",
        ],
        failures,
    )

    validate_presentation_does_not_mutate_live_state(failures)
    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.1.3",
        failures,
        [
            "Dice outcomes are resolved before deterministic tactical mutation and restored after failed commits.",
            "Attack support is driven by definition capabilities rather than weapon IDs.",
            "Enemy planning is separated from execution and searches all hostile active units.",
            "Enemy activation failures finalize safely and do not stop the Enemy Turn.",
            "Presentation is statically forbidden from calling live tactical mutators.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
