#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    required = [
        "STAGE_4_3_1_DOWNED_DYING_DEATH_FOUNDATION_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_3_1_DOWNED_DYING_DEATH_FOUNDATION.md",
        "domain/tactical/life/tactical_life_state_rules.gd",
        "application/tactical/life/tactical_life_state_handler.gd",
        "presentation/tactical/icons/status_unconscious_zzz.svg",
        "presentation/tactical/icons/status_dying_skull.svg",
        "presentation/tactical/icons/status_dead_skull.svg",
        "tests/tactical/stage_4_3_1_downed_dying_death_tests.gd",
        "tests/tactical/run_stage_4_3_1_tests.gd",
    ]
    for path in required:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/life/tactical_life_state_rules.gd",
        [
            "STATE_DISABLED",
            "STATE_DYING",
            "STATE_STABLE_UNCONSCIOUS",
            "STATE_NONLETHAL_UNCONSCIOUS",
            "STATE_DEAD",
            "return -maxi(1, constitution_score)",
            "return maxi(10, 10 - current_hp)",
            "DYING_SUCCESS_TARGET: int = 3",
            "DYING_FAILURE_TARGET: int = 3",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_unit_state.gd",
        [
            "var dying_successes: int = 0",
            "var dying_failures: int = 0",
            "var stable: bool = false",
            "var dead: bool = false",
            "func life_state_id()",
            "func apply_healing(",
            "func become_stable(",
            "func add_dying_successes(",
            "func add_dying_failures(",
            "func apply_disabled_strain(",
            "func participates_in_initiative()",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/life/tactical_life_state_handler.gd",
        [
            "func resolve_dying_check(",
            "func first_aid_unavailable_reason(",
            "func first_aid(",
            "func apply_healing(",
            "FIRST_AID_DC: int = 10",
            "natural_twenty",
            "natural_one",
            "Required natural roll:",
            "Dying track:",
            "TacticalChangeSet.new(",
            "snapshot_state()",
            "restore_state(dice_checkpoint)",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/initiative/initiative_turn_handler.gd",
        [
            "active.is_dying()",
            "resolve_dying_check(active_id)",
            "recovered enough to act while Disabled",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/awareness/contact_initiative_resolver.gd",
        [
            "player.participates_in_initiative()",
            "member.participates_in_initiative()",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            "UNCONSCIOUS_ZZZ_ICON",
            "DYING_SKULL_ICON",
            "DEAD_SKULL_ICON",
            "func set_life_state(",
            "func _draw_unconscious_badge(",
            "func _draw_dying_badge(",
            "func _draw_dead_badge(",
            "index < _dying_successes",
            "index < _dying_failures",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            '"First Aid [Half]"',
            "func _begin_first_aid_targeting(",
            "func _life_state_hud_context(",
            "Fort %+d vs DC %d",
            "successes",
            "failures",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/widgets/segmented_health_bar.gd",
        [
            "_current_hp = mini(current_hp, _maximum_hp)",
            "clampf(",
            '"%d / %d"',
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_3_1_downed_dying_death_tests.gd",
        [
            "_test_hp_state_ladder_and_disabled_strain",
            "_test_dying_success_failure_and_natural_results",
            "_test_first_aid_and_healing_transitions",
            "_test_nonlethal_unconsciousness_and_reopened_dying",
            "_test_initiative_dying_turn_and_body_persistence",
            "_test_squad_awareness_survives_downed_member",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/boot/boot.gd",
        ["Stage 4.3.1 downed, Dying and death foundation loaded."],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.3.1",
        failures,
        [
            "Disabled, Dying, Stable, nonlethal-unconscious and Dead states share one authority.",
            "Fortitude Dying checks track three successes and three failures.",
            "First Aid and healing are transaction-safe and fully logged.",
            "Colourful inked token emblems override awareness and stealth badges.",
            "Downed and dead bodies remain present on the tactical map.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
