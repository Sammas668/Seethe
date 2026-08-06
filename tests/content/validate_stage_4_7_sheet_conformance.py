#!/usr/bin/env python3
"""Static conformance gate for the approved Stage 4.7 character sheets.

This validator deliberately checks authored facts and their mechanical hooks, rather
than accepting a similarly named generic template. Runtime tests remain responsible
for proving the resolved totals inside Godot.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Iterable


TEMPLATE_FILES = {
    "character_template.reaver.marauder_tier_1": "content/characters/reaver/marauder_tier_1.tres",
    "character_template.life.sanctuary_spear_guard": "content/characters/life/sanctuary_spear_guard.tres",
    "character_template.life.sanctuary_archer": "content/characters/life/sanctuary_archer.tres",
    "character_template.life.mercy_bearer": "content/characters/life/mercy_bearer.tres",
}

ACTION_FILES = {
    "action.sanctuary.capture_spear_attack": "content/actions/capture_spear_attack.tres",
    "action.sanctuary.capture_bow_attack": "content/actions/capture_bow_attack.tres",
    "action.sanctuary.blackjack_attack": "content/actions/sanctuary_blackjack_attack.tres",
    "action.mercy.cure_light_wounds": "content/actions/mercy/cure_light_wounds.tres",
    "action.mercy.cure_moderate_wounds": "content/actions/mercy/cure_moderate_wounds.tres",
    "action.mercy.command_kneel": "content/actions/mercy/command_kneel.tres",
    "action.mercy.sanctuary": "content/actions/mercy/sanctuary.tres",
    "action.mercy.hold_person": "content/actions/mercy/hold_person.tres",
    "action.mercy.mercys_rebuke": "content/actions/mercy/mercys_rebuke.tres",
    "action.mercy.guidance": "content/actions/mercy/guidance.tres",
    "action.mercy.resistance": "content/actions/mercy/resistance.tres",
    "action.mercy.detect_poison": "content/actions/mercy/detect_poison.tres",
    "action.mercy.light": "content/actions/mercy/light.tres",
}


def _read(project: Path, relative: str, errors: list[str]) -> str:
    path = project / relative
    if not path.is_file():
        errors.append(f"Missing required file: {relative}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def _require(text: str, fragments: Iterable[str], label: str, errors: list[str]) -> None:
    for fragment in fragments:
        if fragment not in text:
            errors.append(f"{label} is missing authored contract: {fragment}")


def _forbid(text: str, fragments: Iterable[str], label: str, errors: list[str]) -> None:
    for fragment in fragments:
        if fragment in text:
            errors.append(f"{label} still references forbidden substitute content: {fragment}")


def validate(project: Path) -> list[str]:
    errors: list[str] = []
    spec_path = project / "content/characters/specifications/stage_4_7_approved_sheets.json"
    if not spec_path.is_file():
        return ["Missing approved character-sheet specification JSON."]
    try:
        spec = json.loads(spec_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"Approved character-sheet specification is invalid: {exc}"]

    sheets = spec.get("sheets", {})
    if set(sheets) != set(TEMPLATE_FILES):
        errors.append("Approved specification does not contain exactly the four locked sheets.")

    expected_template_fragments = {
        "character_template.reaver.marauder_tier_1": [
            'class_name_text = "Barbarian 3"',
            'base_ability_scores = {"CHA": 8, "CON": 14, "DEX": 13, "INT": 10, "STR": 15, "WIS": 12}',
            "base_attack_bonus = 3",
            'base_save_bonuses = {"fortitude": 3, "reflex": 1, "will": 1}',
            "base_hp_before_constitution = 26",
            "hp_constitution_levels = 3",
            "base_turn_capacity_feet = 80",
            "sprint_multiplier = 1.5",
            '&"feature.fast_movement"', '&"feature.uncanny_dodge"', '&"feature.trap_sense_1"',
            'ability_resource_maximums = {"resource.rage": 1}',
            '"duration_rounds": 7',
            '"uses_per_mission": 1',
            "carrying_strength_bonus = 4",
            '&"item.raiders_axe"', '&"item.patchwork_raider_armour"', '&"item.mace"',
            '&"item.reaver_dagger"', '&"item.manacles"', '&"item.marauder_keys"',
            '&"item.bandage"', '&"item.rope"', '&"item.raiders_sack"',
            '&"proficiency.martial_weapons"', '&"proficiency.medium_armour"',
            '&"proficiency.shields_except_tower"',
        ],
        "character_template.life.sanctuary_spear_guard": [
            'class_name_text = "Warrior 1"',
            'base_ability_scores = {"CHA": 9, "CON": 14, "DEX": 10, "INT": 10, "STR": 14, "WIS": 10}',
            "base_attack_bonus = 1",
            'base_save_bonuses = {"fortitude": 2, "reflex": 0, "will": 0}',
            "base_hp_before_constitution = 8",
            "hp_constitution_levels = 1",
            'default_defence_profile_id = &"defence.sanctuary_guard_armour"',
            '&"feat.weapon_focus.sanctuary_blackjack"',
            '&"feat.subdual_takedown"',
            '&"action.grapple"', '&"action.trip"', '&"action.shove"',
            '&"action.restrain"', '&"action.first_aid"',
            '&"item.sanctuary.capture_spear"', '&"item.sanctuary.blackjack"',
        ],
        "character_template.life.sanctuary_archer": [
            'class_name_text = "Warrior 1"',
            'base_ability_scores = {"CHA": 10, "CON": 12, "DEX": 14, "INT": 10, "STR": 10, "WIS": 12}',
            "base_attack_bonus = 1",
            'base_save_bonuses = {"fortitude": 2, "reflex": 0, "will": 0}',
            "base_hp_before_constitution = 8",
            "hp_constitution_levels = 1",
            '&"feat.weapon_focus.sanctuary_capture_bow"',
            '&"feat.patient_overwatch"',
            '"reaction_attack_modifier": -1',
            '&"item.sanctuary.capture_bow"', '&"item.sanctuary.padded_arrows"',
        ],
        "character_template.life.mercy_bearer": [
            'class_name_text = "Cleric 3"',
            'base_ability_scores = {"CHA": 14, "CON": 14, "DEX": 10, "INT": 10, "STR": 12, "WIS": 16}',
            "base_attack_bonus = 2",
            'base_save_bonuses = {"fortitude": 3, "reflex": 1, "will": 3}',
            "base_hp_before_constitution = 18",
            "hp_constitution_levels = 3",
            'default_defence_profile_id = &"defence.mercy_bearer_breastplate"',
            '&"feat.combat_casting"', '&"feat.augmented_healing"',
            '&"feat.spell_focus.compulsion"', '&"feature.mercy_intercession"',
            '&"action.mercy.cure_light_wounds"', '&"action.mercy.cure_moderate_wounds"',
            '&"action.mercy.command_kneel"', '&"action.mercy.sanctuary"',
            '&"action.mercy.hold_person"', '&"action.mercy.mercys_rebuke"',
            '&"action.mercy.guidance"', '&"action.mercy.resistance"',
            '&"action.mercy.detect_poison"', '&"action.mercy.light"',
            '&"item.mercy.cradling_shield"', '&"item.mercy.field_kit"',
            '&"item.manacles"', '&"item.mercy.divine_focus"',
        ],
    }

    for template_id, relative in TEMPLATE_FILES.items():
        text = _read(project, relative, errors)
        if not text:
            continue
        _require(text, [f'id = &"{template_id}"'], relative, errors)
        _require(text, expected_template_fragments[template_id], relative, errors)
        if template_id == "character_template.reaver.marauder_tier_1":
            _forbid(
                text,
                [
                    '&"item.rations"',
                    '&"item.empty_sack"',
                    '&"item.reinforced_captive_carrying_belt"',
                    '"maximum_value": 3',
                ],
                relative,
                errors,
            )
            _require(
                text,
                [
                    '"maximum_value_source": &"bab"',
                    'grid_position": Vector2i(5, 0)',
                ],
                relative,
                errors,
            )

    expected_action_fragments = {
        "action.sanctuary.capture_spear_attack": [
            'damage_type = &"blunt"', 'damage_channel = &"nonlethal"',
            'damage_mode_policy = &"nonlethal_only"', 'attack_ability = &"strength"',
            'damage_ability = &"strength"', 'supports_power_attack = false',
        ],
        "action.sanctuary.capture_bow_attack": [
            'damage_type = &"blunt"', 'damage_channel = &"nonlethal"',
            'damage_mode_policy = &"nonlethal_only"', 'range_increment_feet = 60',
            'ammunition_tag = &"padded_arrow"', 'ammunition_per_attack = 1',
        ],
        "action.sanctuary.blackjack_attack": [
            'damage_type = &"blunt"', 'damage_channel = &"nonlethal"',
            'damage_mode_policy = &"nonlethal_only"', 'attack_ability = &"strength"',
        ],
        "action.mercy.cure_light_wounds": ["dice_count = 1", "die_size = 8", "flat_bonus = 5", 'resource_cost = 1'],
        "action.mercy.cure_moderate_wounds": ["dice_count = 2", "die_size = 8", "flat_bonus = 7", 'resource_cost = 1'],
        "action.mercy.command_kneel": ['save_type = &"will"', "save_dc = 15", '&"compulsion"'],
        "action.mercy.sanctuary": ['condition_id = &"effect.sanctuary"', "bonus_value = 14", 'resource_cost = 1'],
        "action.mercy.hold_person": ['save_type = &"will"', "save_dc = 16", 'condition_id = &"condition.hold_person"', "duration_rounds = 3", "concentration = true"],
        "action.mercy.mercys_rebuke": ['damage_channel = &"nonlethal"', "dice_count = 2", "die_size = 6", "flat_bonus = 3", 'save_type = &"will"', "save_dc = 15", "half_on_save = true"],
        "action.mercy.guidance": ['condition_id = &"effect.guidance"', "bonus_value = 1"],
        "action.mercy.resistance": ['condition_id = &"effect.resistance"', "bonus_value = 1"],
        "action.mercy.detect_poison": ['implementation_profile_id = &"ability.detect_poison"'],
        "action.mercy.light": ['implementation_profile_id = &"ability.light"', "bonus_value = 20"],
    }
    for action_id, relative in ACTION_FILES.items():
        text = _read(project, relative, errors)
        if not text:
            continue
        _require(text, [f'id = &"{action_id}"'], relative, errors)
        _require(text, expected_action_fragments[action_id], relative, errors)

    rage = _read(project, "content/character_effects/rage.tres", errors)
    _require(rage, [
        'ability_modifiers = {"CON": 4, "STR": 4}',
        'stat_modifiers = {"armour_class": -2, "will": 2}',
        'one use per mission', 'seven rounds',
    ], "Marauder Rage modifier", errors)
    _forbid(rage, ['"maximum_hp": 6', 'two uses per mission', 'six rounds'], "Marauder Rage modifier", errors)

    for item_path, fragments in {
        "content/items/patchwork_raider_armour_item.tres": ['id = &"item.patchwork_raider_armour"', 'defence_profile_id = &"defence.patchwork_raider_armour"', '&"armour"'],
        "content/items/marauder_keys.tres": ['id = &"item.marauder_keys"'],
        "content/items/raiders_sack.tres": [
            'id = &"item.raiders_sack"',
            'fixed_inventory_fixture = true',
            'internal_container_kind = &"raider_sack"',
            'internal_container_size = Vector2i(4, 3)',
        ],
    }.items():
        _require(_read(project, item_path, errors), fragments, item_path, errors)

    blackjack_item = _read(project, "content/items/sanctuary_blackjack.tres", errors)
    _require(blackjack_item, [
        'id = &"item.sanctuary.blackjack"',
        'belt_allowed = true',
        'inventory_footprint = Vector2i(1, 2)',
    ], "Sanctuary Blackjack item", errors)

    content_catalogue = _read(project, "application/content/content_catalogue.gd", errors)
    _require(content_catalogue, [
        'func _validate_character_default_loadout(',
        'not definition.belt_allowed',
        'not definition.backpack_allowed',
        'occupied_inventory_cells',
        'definition.is_two_handed()',
    ], "ContentCatalogue default-loadout validation", errors)

    catalogue = _read(project, "infrastructure/content/sandbox_content_catalogue_factory.gd", errors)
    mission = _read(project, "content/missions/farm_storehouse/life_farm_storehouse_raid_01.tres", errors)
    _require(catalogue, [
        'preload("res://content/characters/life/sanctuary_spear_guard.tres")',
        'preload("res://content/characters/life/sanctuary_archer.tres")',
        'preload("res://content/characters/life/mercy_bearer.tres")',
        'preload("res://content/ai_profiles/life_sanctuary_spear_guard.tres")',
        'preload("res://content/ai_profiles/life_sanctuary_archer.tres")',
        'preload("res://content/ai_profiles/life_mercy_bearer.tres")',
    ], "production catalogue", errors)
    _forbid(catalogue, [
        'content/characters/life/settlement_guard.tres',
        'content/characters/life/settlement_archer.tres',
        'content/characters/life/patrol_leader.tres',
        'content/characters/life/novice_mercy_bearer.tres',
        'content/ai_profiles/life_patrol_leader.tres',
    ], "production catalogue", errors)
    _require(mission, [
        'template_id = &"character_template.life.sanctuary_spear_guard"',
        'template_id = &"character_template.life.sanctuary_archer"',
        'template_id = &"character_template.life.mercy_bearer"',
        'ai_profile_override_id = &"ai.life.sanctuary_spear_guard"',
        'ai_profile_override_id = &"ai.life.sanctuary_archer"',
        'ai_profile_override_id = &"ai.life.mercy_bearer"',
    ], "farm mission", errors)
    _forbid(mission, spec.get("forbidden_production_templates", []), "farm mission", errors)
    _forbid(mission, spec.get("forbidden_farm_items", []), "farm mission", errors)
    _forbid(mission, [
        'display_name = "Sanctuary Storehouse Guard"',
        'display_name = "Sanctuary Field Guard"',
    ], "farm mission guard instance naming", errors)
    if mission.count('display_name = "Sanctuary Spear Guard"') != 2:
        errors.append(
            "Farm mission must label both approved Guard instances as Sanctuary Spear Guard."
        )

    attack_preview = _read(project, "application/tactical/combat/attack_preview_query.gd", errors)
    tactical_screen = _read(project, "presentation/tactical/tactical_screen.gd", errors)
    reaction_service = _read(project, "application/tactical/reactions/tactical_reaction_service.gd", errors)
    body_handler = _read(project, "application/tactical/body/tactical_body_action_handler.gd", errors)
    attack_handler = _read(project, "application/tactical/combat/attack_handler.gd", errors)
    ability_service = _read(project, "application/tactical/abilities/tactical_ability_service.gd", errors)
    unit_state = _read(project, "domain/tactical/tactical_unit_state.gd", errors)
    resolved = _read(project, "domain/characters/resolution/resolved_character_snapshot.gd", errors)

    _require(attack_preview, ['has_trait(&"feat.power_attack")', 'has_trait(&"trait.take_them_alive")'], "attack preview", errors)
    _require(tactical_screen, ['has_trait(&"feat.power_attack")', '&"rage_toggle"'], "tactical HUD", errors)
    _require(reaction_service, ['has_trait(&"feat.patient_overwatch")', 'reaction_attack_modifier'], "reaction service", errors)
    _require(body_handler, ['has_trait(&"trait.take_them_alive")', 'ActionCost.quick_action()'], "body action handler", errors)
    _require(attack_handler, [
        'has_trait(&"feat.subdual_takedown")', 'mark_subdual_takedown_target',
        'has_trait(&"feature.mercy_intercession")', 'resource.mercy.intercession',
        'effect.sanctuary', 'effect.guidance',
    ], "attack handler", errors)
    _require(ability_service, [
        'PROFILE_HEAL', 'PROFILE_SAVE_CONDITION', 'PROFILE_NONLETHAL_SAVE_DAMAGE',
        'condition.hold_person', 'effect.resistance', 'resolve_start_of_activation',
    ], "ability service", errors)
    _require(unit_state, [
        'func begin_rage()', 'func end_rage()', 'resource.rage',
        'func subdual_takedown_bonus', 'func saving_throw_bonus',
    ], "tactical unit state", errors)
    _require(resolved, [
        'feat.weapon_focus.sanctuary_blackjack',
        'feat.weapon_focus.sanctuary_capture_bow',
        'func concentration_bonus',
    ], "resolved character snapshot", errors)

    # Detect the duplicate function-signature corruption seen in earlier generated patches.
    for gd in project.rglob("*.gd"):
        text = gd.read_text(encoding="utf-8", errors="replace")
        if re.search(r"\)\s*->\s*\w+:\s*\n\)\s*->\s*\w+:", text):
            errors.append(f"Duplicate function signature terminator in {gd.relative_to(project)}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=".")
    args = parser.parse_args()
    project = Path(args.project).resolve()
    errors = validate(project)
    if errors:
        print("Stage 4.7 current sheet/loadout conformance validation FAILED:")
        for error in errors:
            print(f" - {error}")
        return 1
    print("Stage 4.7 current sheet/loadout conformance validation PASSED (4 approved sheets).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
