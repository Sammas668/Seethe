#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []

    for path in [
        "domain/combat/damage_profile.gd",
        "domain/tactical/tactical_unit_state.gd",
        "application/tactical/combat/attack_preview_query.gd",
        "application/tactical/combat/attack_handler.gd",
        "presentation/tactical/combat_log/tactical_combat_log.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "domain/combat/damage_profile.gd",
        [
            "CHANNEL_LETHAL",
            "CHANNEL_NONLETHAL",
            "@export var damage_channel",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_unit_state.gd",
        [
            "func apply_damage(",
            "func restore_damage_state(",
            "nonlethal_damage += requested",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_preview_query.gd",
        [
            "preview.damage_channel",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_handler.gd",
        [
            "target.apply_damage(",
            "target_nonlethal_before",
            "damage_resource_change",
            "Damage channel:",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/combat_log/tactical_combat_log.gd",
        [
            "const EXPANDED_LEFT: float = -540.0",
            "summary_label.autowrap_mode",
            "details_label.autowrap_mode",
            "toggle_button.text",
        ],
        failures,
    )
    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.0.5",
        failures,
        [
            "Lethal HP loss and nonlethal accumulation are separate channels.",
            "Lethal and nonlethal damage use the ordinary attack transaction.",
            "Expanded event summaries and details wrap within the log panel.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
