#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    required = [
        "STAGE_4_2_6_INITIATIVE_LIFECYCLE_BASIC_AI_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_2_6_INITIATIVE_LIFECYCLE_BASIC_AI.md",
        "content/characters/prototypes/guard_archer_enemy.tres",
        "tests/tactical/stage_4_2_6_initiative_lifecycle_ai_tests.gd",
        "tests/tactical/run_stage_4_2_6_tests.gd",
    ]
    for path in required:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/tactical_phase_state.gd",
        [
            "pending_initiative_unit_ids",
            "pending_initiative_totals_by_unit_id",
            "func queue_initiative_participants(",
            "func activate_round_order(",
            "func end_initiative(",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_state.gd",
        [
            "func skip_ineligible_active_initiative_unit(",
            "func should_end_initiative_combat(",
            "func end_initiative_combat(",
            "func _activate_pending_for_new_round(",
            "func _advance_search_rounds(",
            "func _sort_initiative_ids(",
            "participant.refresh_for_new_round()",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/awareness/tactical_squad_state.gd",
        [
            "DEFAULT_SEARCH_ROUNDS",
            "search_rounds_remaining",
            "func begin_search(",
            "func consume_search_round(",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_unit_state.gd",
        [
            "action_incapacitated",
            "func is_incapacitated(",
            "func can_take_actions(",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/awareness/contact_initiative_resolver.gd",
        [
            "player.participates_in_initiative()",
            "member.participates_in_initiative()",
            "pending_initiative_unit_ids.has(",
            "func _squad_has_initiative_participant(",
            "if not joins_from_detection and not already_in_combat:",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/initiative/initiative_turn_handler.gd",
        [
            "func normalize_active_turn(",
            "initiative_ineligible_unit_skipped",
            "initiative_combat_ended",
        ],
        failures,
    )
    require_tokens(
        "domain/combat/attack_definition.gd",
        ["func is_implemented_ranged_weapon_attack() -> bool:"],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "attack.is_implemented_ranged_weapon_attack()",
            "range_penalty = -2 * increment_index",
            "TacticalLineOfSightRules.has_line_of_sight(",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_action_planner.gd",
        [
            "func _best_path_to_ranged_attack_position(",
            "func _ranged_position_can_attack(",
            "func _attack_preference_score(",
            "MovementRules.movement_step_cost(",
        ],
        failures,
    )
    forbid_tokens(
        "application/tactical/ai/enemy_action_planner.gd",
        ["var prefix: Array[Vector2i] = []"],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        ["JOINS NEXT ROUND:", "_schedule_initiative_normalization"],
        failures,
    )
    require_tokens(
        "bootstrap/debug/tactical_sandbox_factory.gd",
        ["ENEMY_ARCHER_TEMPLATE_ID", "Generated Settlement Archer"],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_2_6_initiative_lifecycle_ai_tests.gd",
        [
            "_test_contact_round_preservation_and_round_refresh",
            "_test_new_squad_joins_at_next_round_boundary",
            "_test_unrelated_aware_squad_stays_out_of_contact",
            "_test_ineligible_and_removed_participants_advance_safely",
            "_test_melee_and_ranged_enemy_planners",
            "_test_five_round_two_squad_combat_and_clean_end",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/boot/boot.gd",
        ["Stage 4.2.6 initiative lifecycle and basic AI completion loaded."],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.6",
        failures,
        [
            "Contact-round spending is preserved and full rounds refresh once.",
            "New squads join at the next round boundary without revealing hidden units.",
            "Ineligible and removed initiative participants advance safely.",
            "Bounded searches end combat and restore side-based team turns.",
            "Melee guards and settlement archers use simple revealed-target planners.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
