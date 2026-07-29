#!/usr/bin/env python3
from __future__ import annotations
import hashlib
import sys
from validation_common import *

EXPECTED_SHEET_SHA = "ab59e1dcd8f4d098eb1e6ac4582d51a67d8bff98c1fca26f48056c1b8a63d2e5"

def main() -> int:
    failures: list[str] = []
    required = [
        "domain/characters/definitions/character_template_definition.gd",
        "domain/characters/state/persistent_character_state.gd",
        "domain/characters/resolution/resolved_character_snapshot.gd",
        "domain/characters/resolution/character_resolver.gd",
        "application/characters/character_factory.gd",
        "application/characters/character_resolution_service.gd",
        "application/campaign/ports/campaign_repository.gd",
        "infrastructure/persistence/json_campaign_repository.gd",
        "application/characters/tactical_character_deployment_service.gd",
        "bootstrap/debug/tactical_sandbox_factory.gd",
        "content/characters/reaver/marauder_tier_1.tres",
        "content/character_effects/rage.tres",
    ]
    for path in required:
        require_file(path, failures)
    require_tokens("domain/characters/state/persistent_character_state.gd", [
        "ROLE_PLAYER", "ROLE_ENEMY", "ROLE_NEUTRAL", "func award_xp", "func add_injury",
        "func effective_portrait_id", "func to_dictionary()", "static func from_dictionary",
    ], failures)
    require_tokens("domain/characters/resolution/character_resolver.gd", [
        "class_name CharacterResolver", "_resolve_abilities", "_resolve_core_stats",
        "_resolve_actions", '_new_stat(&"armour_class"', '_new_stat(&"maximum_hp"',
        '_new_stat(&"passive_perception"',
    ], failures)
    require_tokens("bootstrap/debug/tactical_sandbox_factory.gd", [
        "CharacterFactory.create_player_character", "CharacterFactory.create_enemy_character",
        "CharacterFactory.create_neutral_character", "Generated Settlement Guard", "Generated Farmhand",
    ], failures)
    template = require_file("content/characters/reaver/marauder_tier_1.tres", failures)
    for token in [
        'id = &"character_template.reaver.marauder_tier_1"', "base_attack_bonus = 3",
        "base_hp_before_constitution = 26", "base_turn_capacity_feet = 80",
        "passive_perception_base = 10", "perception_skill_bonus = 6",
        'default_defence_profile_id = &"defence.patchwork_raider_armour"',
    ]:
        if token not in template:
            failures.append(f"Marauder template missing canonical value: {token}")
    for path in (ROOT / "content/characters").rglob("*.tres"):
        if '"instance_id"' in path.read_text(encoding="utf-8"):
            failures.append(f"template owns persistent item identity: {path.relative_to(ROOT)}")
    for obsolete in [
        "domain/tactical/tactical_inventory_rules.gd", "domain/tactical/tactical_item_state.gd",
        "domain/tactical/tactical_item_profile.gd", "application/characters/tactical_character_persistence_service.gd",
    ]:
        require_absent(obsolete, failures)
    scene = ROOT / "presentation/tactical/unit_management_window.tscn"
    if scene.is_file() and hashlib.sha256(scene.read_bytes()).hexdigest() != EXPECTED_SHEET_SHA:
        failures.append("existing Character Sheet scene changed visually")
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_balanced_delimiters(failures)
    return finish("Stage 3.12", failures, ["Persistent characters resolve from reusable authored templates."])

if __name__ == "__main__":
    sys.exit(main())
