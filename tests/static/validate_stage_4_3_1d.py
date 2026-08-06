#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    required = [
        "STAGE_4_3_1D_DIAGONAL_MELEE_ALERT_DEDUPLICATION_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_3_1D_DIAGONAL_MELEE_ALERT_DEDUPLICATION.md",
        "domain/tactical/combat/tactical_melee_reach_rules.gd",
        "tests/tactical/stage_4_3_1d_diagonal_melee_alert_dedup_tests.gd",
        "tests/tactical/run_stage_4_3_1d_tests.gd",
    ]
    for path in required:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/combat/tactical_melee_reach_rules.gd",
        [
            "class_name TacticalMeleeReachRules",
            "func can_reach(",
            "func minimum_reach_distance_feet(",
            "func has_sealed_diagonal_contact(",
            "map_definition.is_blocked(horizontal_step)",
            "map_definition.is_blocked(vertical_step)",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "TacticalMeleeReachRules.minimum_reach_distance_feet(",
            "TacticalMeleeReachRules.can_reach(",
            "A sealed corner blocks the diagonal melee attack.",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_action_planner.gd",
        [
            "TacticalMeleeReachRules.minimum_reach_distance_feet(",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/awareness/tactical_detection_service.gd",
        [
            "non_interrupting_reacquired_squad_ids",
            "var detection_interrupts_movement: bool = unit.stealth_enabled",
            "not squad.is_aware()",
            "An already-aware squad reacquired the visible unit without interrupting movement.",
            '"movement_interrupted": interrupted_on_this_tile',
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "_known_aware_enemy_squad_ids",
            "func _aware_enemy_squad_id_set()",
            "and new_enemy_squad_alerted",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_3_1d_diagonal_melee_alert_dedup_tests.gd",
        [
            "Open diagonal adjacency must count as 5-foot melee contact.",
            "Two solid orthogonal blockers must seal a diagonal melee corner.",
            "The guard must attack from the diagonal instead of repositioning.",
            "Reacquisition by an already-aware squad must not pause visible movement.",
            "A failed Stealth check must still stop movement even when the squad is already aware.",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/boot/boot.gd",
        [
            "Stage 4.3.1d diagonal melee contact and alert deduplication loaded."
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.3.1d",
        failures,
        [
            "Open diagonals count as 5-foot melee contact unless both corner sides are blocked.",
            "Player previews, committed attacks and enemy AI share one melee-reach authority.",
            "Already-aware visible reacquisition no longer interrupts movement or repeats the alert flash.",
            "Failed Stealth and first-time squad alerts still interrupt normally.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
