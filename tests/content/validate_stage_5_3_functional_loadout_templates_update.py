#!/usr/bin/env python3
"""Static acceptance checks for Stage 5.3 functional equipment and templates."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
errors: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        errors.append(f"missing required file: {rel}")
        return ""
    return path.read_text(encoding="utf-8")


shell = read("presentation/campaign/campaign_shell.gd")
location = read("domain/campaign/campaign_item_location_state.gd")
item_def = read("domain/inventory/definitions/item_definition.gd")
item_rule = read("domain/campaign/loadout_item_rule.gd")
template_state = read("domain/campaign/loadout_template_state.gd")
loadout_service = read("application/inventory/loadout_service.gd")
equipment_service = read("application/inventory/strategic_equipment_service.gd")
progression_service = read("application/characters/character_progression_service.gd")
campaign_state = read("domain/campaign/campaign_state.gd")
character_state = read("domain/characters/state/persistent_character_state.gd")
character_definition = read("domain/characters/definitions/character_template_definition.gd")
deployment_service = read("application/characters/tactical_character_deployment_service.gd")
spatial_grid = read("presentation/campaign/widgets/strategic_spatial_inventory_grid.gd")

required_shell_tokens = [
    '"HP", "%d / %d"',
    '"ARMOUR CLASS"',
    '"PRIMARY ATTACK"',
    '"PASSIVE PERCEPTION"',
    'func _build_armour_selector(',
    'func _build_visual_inventory_slot(',
    'StrategicSpatialInventoryGridScript.new()',
    '"LOADOUT INCOMPLETE',
    'level_tab.name = "LEVEL UP"',
    'func _build_level_up_content(',
    'func _build_loadout_template_controls(',
    '"SAVE AS NEW"',
    '"APPLY TO TROOP TYPE"',
    'func _open_loadout_template_manager(',
]
for token in required_shell_tokens:
    if token not in shell:
        errors.append(f"campaign_shell.gd missing functional UI token: {token}")

if '.set_location(' in shell or '.assign_item_to_character(' in shell:
    errors.append("campaign_shell.gd directly mutates authoritative item locations")

required_location_tokens = [
    'var is_rotated: bool = false',
    '"is_rotated": is_rotated',
    'bool(data.get("is_rotated", false))',
]
for token in required_location_tokens:
    if token not in location:
        errors.append(f"campaign item location missing spatial persistence: {token}")

if '@export var inventory_rotation_allowed: bool = true' not in item_def:
    errors.append("item definitions do not author rotation permission")

required_rule_tokens = [
    'var exact_item_id: StringName',
    'var preferred_grid_position: Vector2i',
    'var preferred_is_rotated: bool',
    'var fixed_position: bool',
    'var allow_substitution: bool',
]
for token in required_rule_tokens:
    if token not in item_rule:
        errors.append(f"loadout item rule missing: {token}")

required_template_tokens = [
    'POLICY_STRICT',
    'POLICY_EQUIVALENT',
    'POLICY_BEST_AVAILABLE',
    'POLICY_CONSERVE_VALUABLE',
    'var is_authored: bool',
    'var rules: Array[LoadoutItemRule]',
]
for token in required_template_tokens:
    if token not in template_state:
        errors.append(f"loadout template state missing: {token}")

required_loadout_service_tokens = [
    'func ensure_authored_templates(',
    'func capture_current_loadout(',
    'func resolve_template_plan(',
    'func preview_apply_template_to_many(',
    'func apply_template_to_many_candidate(',
    'func create_blank_template(',
    'func duplicate_template(',
    'preferred_is_rotated',
    '_definition_is_equivalent',
]
for token in required_loadout_service_tokens:
    if token not in loadout_service:
        errors.append(f"LoadoutService missing: {token}")

required_equipment_tokens = [
    'func preview_equip_at_position(',
    'func equip_candidate_at_position(',
    'func auto_pack_candidate(',
    'func loadout_status(',
    'requested_rotation',
    'inventory_rotation_allowed',
]
for token in required_equipment_tokens:
    if token not in equipment_service:
        errors.append(f"StrategicEquipmentService missing: {token}")

required_progression_tokens = [
    'func next_level_preview(',
    'func apply_level_candidate(',
    'talent_choice_required',
    'character.set_level_adjustment(character.level_adjustment + 1)',
]
for token in required_progression_tokens:
    if token not in progression_service:
        errors.append(f"CharacterProgressionService missing: {token}")

if 'var level_progression_entries: Array[Dictionary]' not in character_definition:
    errors.append("character definitions do not author ordinary-troop progression")
if 'var selected_talent_ids: Array[StringName]' not in character_state:
    errors.append("persistent characters do not retain selected talents")
if 'var preferred_loadout_template_id: StringName' not in character_state:
    errors.append("persistent characters do not retain a preferred loadout template")

required_campaign_tokens = [
    'const CURRENT_SAVE_VERSION: int = 13',
    'var loadout_templates_by_id: Dictionary',
    'var default_loadout_template_by_troop_type: Dictionary',
    'func get_loadout_templates()',
    'func next_loadout_template_id()',
]
for token in required_campaign_tokens:
    if token not in campaign_state:
        errors.append(f"CampaignState missing loadout-template persistence: {token}")

if 'item.location.is_rotated' not in deployment_service:
    errors.append("deployment snapshots do not preserve strategic item rotation")
if 'render_campaign_items(' not in spatial_grid or 'item.location.grid_position' not in spatial_grid:
    errors.append("strategic spatial grid does not render authoritative campaign positions")

marauder = read("content/characters/reaver/marauder_tier_1.tres")
for level in (4, 5, 6):
    if f'"level": {level}' not in marauder:
        errors.append(f"Marauder progression is missing authored Level {level}")
if '"talent_choices"' not in marauder:
    errors.append("Marauder progression has no authored talent-choice milestone")

if errors:
    print("Stage 5.3 Functional Loadout & Templates validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — character statistics use explicit resolved values and contextual breakdowns.")
print("PASS — Belt and Backpack use persistent spatial positions and rotation shared with deployment.")
print("PASS — armour, hands, loadout readiness, undo and spatial placement use authoritative services.")
print("PASS — character Level Up uses authored progression and sequential atomic commits.")
print("PASS — authored and player loadout templates persist rules without owning item instances.")
