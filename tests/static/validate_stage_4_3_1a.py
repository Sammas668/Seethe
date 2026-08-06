#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    required = [
        "STAGE_4_3_1A_TOKEN_STATUS_SQUAD_ALERT_CORRECTION_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_3_1A_TOKEN_STATUS_SQUAD_ALERT_CORRECTION.md",
        "tests/tactical/stage_4_3_1a_token_status_squad_alert_tests.gd",
        "tests/tactical/run_stage_4_3_1a_tests.gd",
    ]
    for path in required:
        require_file(path, failures)

    require_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            "TOKEN_BADGE_RADIUS: float = 7.0",
            "TOKEN_BADGE_ICON_SIZE: float = 12.0",
            "DYING_TRACK_PIP_RADIUS: float",
            "func _draw_token_badge_backplate(",
            "func displayed_badge_kind()",
            "BADGE_KIND_DYING",
            "BADGE_KIND_UNCONSCIOUS",
            "BADGE_KIND_DEAD",
            "func _draw_track_pip(",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/debug/tactical_sandbox_factory.gd",
        [
            "var watch_members: Array[StringName] = []",
            "watch_members.append(guard.unit_id)",
            "watch_members.append(archer.unit_id)",
            "GUARD_SQUAD_A_ID",
            "watch_members",
            "GUARD_SQUAD_B_ID",
            "[PRACTICE_DUMMY_ID]",
            "Detection by either member therefore alerts both members",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "func _refresh_unit_status_badge_immediately(",
            "func _refresh_all_unit_status_badges_immediately()",
            "_refresh_all_unit_status_badges_immediately()",
            "_refresh_unit_status_badge_immediately(target.unit_id)",
            "_refresh_unit_status_badge_immediately(committed_target_id)",
            "the frame in which the attack/healing transaction commits",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "if target.is_defeated():",
            'return preview.reject("That target is already Defeated.")',
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_3_1a_token_status_squad_alert_tests.gd",
        [
            "_test_generated_watch_members_share_alert",
            "_test_body_state_badge_changes_immediately",
            "Every conscious member of the detecting squad must enter initiative.",
            "Entering Dying must immediately replace the awareness eye",
            "empty success/failure track until its turn",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/boot/boot.gd",
        ["Stage 4.3.1a token status and shared squad alert correction"],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.3.1a",
        failures,
        [
            "All token status badges use one standard 14-pixel footprint.",
            "The generated guard and archer share one authored alert squad.",
            "Body-state icons replace eye and hood badges immediately on commit.",
            "Dying pips begin empty and update only with the Dying track.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
