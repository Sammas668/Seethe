#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    for path in [
        "domain/tactical/tactical_team_relations.gd",
        "application/tactical/ai/enemy_turn_handler.gd",
        "tests/combat/stage_4_0_1_team_control_tests.gd",
        "tests/combat/run_stage_4_0_1_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/tactical_unit_state.gd",
        [
            "CONTROLLER_PLAYER",
            "CONTROLLER_AI",
            "TURN_BEHAVIOR_AUTO_PASS",
            "controller_type",
            "participates_in_enemy_turn",
            "counts_for_victory",
            "is_player_controlled",
            "should_receive_enemy_turn",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_team_relations.gd",
        [
            "RELATION_ALLIED",
            "RELATION_HOSTILE",
            "RELATION_NEUTRAL",
            "are_hostile",
            "are_allied",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "TEAM_RELATIONS_SCRIPT",
            "are_hostile",
            "Neutral targets are unavailable",
            "Allied targets are unavailable",
            "attacker.is_player_controlled",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_turn_handler.gd",
        [
            "resolve_enemy_turn",
            "get_enemy_turn_units",
            "TacticalChangeSet.new",
            "refresh_for_new_round",
            "mark_activation_ended",
            "unit_turn_started",
            "unit_passed",
            "_state_store.commit",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/debug/tactical_sandbox_factory.gd",
        [
            "_configure_training_dummy",
            "CONTROLLER_AI",
            "TURN_BEHAVIOR_AUTO_PASS",
            "false",
            '"Training Dummy"',
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "Enemy Turn: AI-controlled enemy units are activating.",
            "resolve_enemy_turn",
            "unit.is_player_controlled",
            "OBJECTIVE · Fight the enemy Settlement Guard",
        ],
        failures,
    )
    require_tokens(
        "tests/combat/stage_4_0_1_team_control_tests.gd",
        [
            "_test_dummy_enemy_classification",
            "_test_team_relationship_targeting",
            "_test_dummy_cannot_be_player_controlled",
            "_test_enemy_turn_auto_pass",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)
    return finish(
        "Stage 4.0.1",
        failures,
        [
            "The Training Dummy is an AI-controlled enemy, not a player unit.",
            "Only hostile team relationships are valid attack targets.",
            "Enemy Turn participants activate and automatically pass through TacticalStateStore.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
