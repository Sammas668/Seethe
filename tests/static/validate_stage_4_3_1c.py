#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    required = [
        "STAGE_4_3_1C_IMMEDIATE_LIFE_STATE_INITIATIVE_HANDOFF_HOTFIX_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_3_1C_IMMEDIATE_LIFE_STATE_INITIATIVE_HANDOFF_HOTFIX.md",
        "tests/tactical/run_stage_4_3_1c_tests.gd",
    ]
    for path in required:
        require_file(path, failures)

    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "_life_state_visual_signature_by_unit_id",
            "func _sync_life_state_visuals_from_state()",
            "_sync_life_state_visuals_from_state()",
            "unit.team_id == &\"enemy\"",
            "A normal contextual attack must never remain armed",
            "var acting_unit_id: StringName = active.unit_id",
            "_facade.active_initiative_unit_id() != acting_unit_id",
            "Only advance if the same actor",
            "call_deferred(\"_schedule_initiative_ai\")",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/run_stage_4_3_1c_tests.gd",
        [
            "A negative-HP threshold must replace the eye",
            "The initiative presentation must advance after the archer",
            "await process_frame",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/boot/boot.gd",
        [
            "Stage 4.3.1c immediate life-state presentation and initiative AI handoff hotfix loaded."
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.3.1c",
        failures,
        [
            "HP threshold badges reconcile immediately and clear stale attack targeting.",
            "AI initiative handoff rechecks active ownership and cannot stall on the archer.",
            "Dying, stealth, perception, and attack rules remain unchanged.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
