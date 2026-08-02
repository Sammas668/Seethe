#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    required = [
        "STAGE_4_3_1E_DISABLED_ACTION_HIT_REACTION_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_3_1E_DISABLED_ACTION_HIT_REACTION_CORRECTION.md",
        "tests/tactical/stage_4_3_1e_disabled_hit_reaction_tests.gd",
        "tests/tactical/run_stage_4_3_1e_tests.gd",
    ]
    for path in required:
        require_file(path, failures)

    require_tokens(
        "application/tactical/tactical_command_handler.gd",
        [
            "Ordinary movement at exactly 0 HP",
            "func _apply_move_budget(",
            "unit.action_budget.spend_normal_capacity(cost_feet)",
        ],
        failures,
    )
    movement_text = require_file(
        "application/tactical/tactical_command_handler.gd", failures
    )
    if movement_text:
        start = movement_text.find("func _apply_move_budget(")
        end = movement_text.find("\n\nfunc ", start + 1)
        section = movement_text[start:end if end >= 0 else None]
        if "apply_disabled_strain" in section:
            failures.append(
                "ordinary movement still applies Disabled strain inside _apply_move_budget"
            )

    require_tokens(
        "domain/tactical/action_economy_rules.gd",
        [
            "func is_disabled_strenuous_cost(",
            "return cost.category == ActionCost.Category.HALF",
            "func spend_with_disabled_strain(",
            "unit.apply_disabled_strain()",
            "Disabled characters cannot take Full Actions.",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/tactical_inventory_transfer_handler.gd",
        [
            "unit_was_disabled",
            "ActionEconomyRules.is_disabled_strenuous_cost(plan.action_cost)",
            "func _apply_disabled_inventory_strain(",
            "The transfer and all of its action costs resolve first.",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/combat/attack_handler.gd",
        [
            "signal damage_committed(event: Dictionary)",
            "attacker_was_disabled",
            "_apply_disabled_attack_strain",
            "_emit_damage_committed(attacker, target, resolution)",
            "before journal publication",
            '"target_id": target.unit_id',
        ],
        failures,
    )
    require_tokens(
        "application/tactical/facades/tactical_screen_facade.gd",
        [
            "signal damage_committed(event: Dictionary)",
            'has_signal("damage_committed")',
            "func _on_damage_committed(event: Dictionary)",
            "damage_committed.emit(event)",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "_facade.damage_committed.connect(_on_damage_committed)",
            "func _on_damage_committed(event: Dictionary)",
            "_refresh_unit_status_badge_immediately(target_id)",
            "view.play_damage_reaction()",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            "const DAMAGE_REACTION_DURATION: float = 0.8",
            "func play_damage_reaction() -> void:",
            "_damage_reaction_tween.kill()",
            "_damage_reaction_progress = 1.0",
            "_damage_reaction_progress = 0.0",
            "draw_set_transform(",
            "draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)",
            "Selection rings, initiative rings and all state badges remain fixed",
        ],
        failures,
    )
    token_text = require_file("presentation/tactical/tactical_unit_view.gd", failures)
    if token_text:
        start = token_text.find("func play_damage_reaction() -> void:")
        end = token_text.find("\n\nfunc ", start + 1)
        section = token_text[start:end if end >= 0 else None]
        if "await" in section:
            failures.append("play_damage_reaction must not await its tween")

    require_tokens(
        "tests/tactical/stage_4_3_1e_disabled_hit_reaction_tests.gd",
        [
            "Ordinary movement at exactly 0 HP must not cause Disabled strain.",
            "A normal Quick Action must not automatically worsen Disabled.",
            "A strenuous Half Action must resolve and then reduce a Disabled character to -1 HP.",
            "The damage presentation event must fire before the attack journal record is published.",
            "The combat log must contain the attack after the commit finishes.",
            "A miss or zero applied damage must not trigger a token hit reaction.",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/boot/boot.gd",
        [
            "Stage 4.3.1e Disabled action and non-blocking hit reaction correction loaded."
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.3.1e",
        failures,
        [
            "Exactly 0 HP now keeps reduced movement without automatic deterioration.",
            "Strenuous Half Actions still resolve and then apply 1 HP of Disabled strain.",
            "Committed positive damage emits after authoritative mutation, before journal publication and broad reconciliation.",
            "The 0.8-second token reaction never awaits or moves status badges.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
