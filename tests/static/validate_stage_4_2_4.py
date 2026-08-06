#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []

    for path in [
        "domain/tactical/tactical_phase_state.gd",
        "application/tactical/end_phase_handler.gd",
        "application/tactical/facades/tactical_screen_facade.gd",
        "presentation/tactical/tactical_screen.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/tactical_phase_state.gd",
        [
            'const ENEMY_PHASE: StringName = &"enemy"',
            "func is_enemy_phase() -> bool:",
            "func begin_enemy_phase() -> void:",
            "func is_world_phase() -> bool:",
            "func begin_world_phase() -> void:",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "phase_state.current_phase == TacticalPhaseState.ENEMY_PHASE",
            "phase_state.is_world_phase()",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/end_phase_handler.gd",
        [
            "_state_store.state.phase_state.current_phase",
            "!= TacticalPhaseState.ENEMY_PHASE",
            "func begin_environment_phase()",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.4",
        failures,
        [
            "The authoritative three-phase TacticalPhaseState is installed.",
            "HUD phase display no longer depends on is_enemy_phase().",
            "Enemy-to-World transition uses the authoritative phase ID.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
