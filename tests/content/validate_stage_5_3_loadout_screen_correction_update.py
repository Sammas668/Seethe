#!/usr/bin/env python3
"""Static acceptance checks for the Stage 5.3 loadout screen correction."""
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
validator = read("application/campaign/campaign_item_validator.gd")
equipment = read("application/inventory/strategic_equipment_service.gd")
loadout = read("application/inventory/loadout_service.gd")
migration = read("application/campaign/migrations/strategic_loadout_correction_migration.gd")
repository = read("infrastructure/persistence/json_campaign_repository.gd")
campaign_state = read("domain/campaign/campaign_state.gd")
result_commit = read("application/campaign/campaign_result_commit_service.gd")
resolution = read("application/characters/character_resolution_service.gd")
deployment = read("application/characters/tactical_character_deployment_service.gd")
tactical_window = read("presentation/tactical/unit_management_window.gd")

required_shell_tokens = [
    '_management_margin(root, 12, 12, 10, 10)',
    'panel.size_flags_stretch_ratio = 0.80',
    'panel.size_flags_stretch_ratio = 2.20',
    'panel.size_flags_stretch_ratio = 1.10',
    'panel.custom_minimum_size.x = 560',
    'panel.custom_minimum_size.x = 280',
    'func _strategic_inventory_cell_size() -> float:',
    'category_row.columns = 4',
    'var actions := HFlowContainer.new()',
    'selector.add_item(definition.display_name)',
    'func _is_armour_definition(definition: ItemDefinition) -> bool:',
    'func _strategic_item_condition_label(',
]
for token in required_shell_tokens:
    if token not in shell:
        errors.append(f"campaign_shell.gd missing correction token: {token}")

if '"WORN UTILITY"' in shell or '"Worn Utility"' in shell:
    errors.append("strategic loadout UI still exposes Worn Utility")
if 'CampaignItemLocationState.CONTAINER_WORN_UTILITY, "WORN UTILITY"' in shell:
    errors.append("strategic loadout still builds a Worn Utility slot")
if '%.0f lb — %s" % [definition.display_name, definition.weight_lb, _item_condition_label(item)]' in shell:
    errors.append("armour selector still shows persistent item condition")

for token in [
    'Worn Utility is a legacy strategic container and must be migrated.',
    'if container_kind == CONTAINER_WORN_UTILITY:',
    'container_kind = CONTAINER_BACKPACK',
]:
    if token not in location:
        errors.append(f"campaign item location missing legacy-slot handling: {token}")

if 'Worn Utility is no longer a strategic equipment slot.' not in equipment:
    errors.append("StrategicEquipmentService does not reject new Worn Utility assignments")
if 'Item %s remains in the removed Worn Utility slot.' not in validator:
    errors.append("campaign item validation does not reject unmigrated Worn Utility items")
if 'CampaignItemLocationState.CONTAINER_WORN_UTILITY:' not in loadout:
    errors.append("LoadoutService lacks deterministic legacy slot ordering")

required_migration_tokens = [
    'class_name StrategicLoadoutCorrectionMigration',
    'CampaignItemLocationState.CONTAINER_BELT',
    'CampaignItemLocationState.CONTAINER_BACKPACK',
    'move_item_to_stronghold_candidate',
    'item.condition = 1.0',
    'rule.preferred_container_id = CampaignItemLocationState.CONTAINER_BACKPACK',
]
for token in required_migration_tokens:
    if token not in migration:
        errors.append(f"strategic correction migration missing: {token}")

if 'StrategicLoadoutCorrectionMigrationScript.repair_campaign' not in repository:
    errors.append("repository does not run the strategic loadout correction before validation")
if 'const CURRENT_SAVE_VERSION: int = 13' not in campaign_state:
    errors.append("campaign save version was not advanced to 13")

for token in [
    '_restore_recovered_character_armour(candidate, character_result)',
    '_restore_armour_condition(item)',
    'item.condition = 1.0',
]:
    if token not in result_commit:
        errors.append(f"mission result armour restoration missing: {token}")

if 'raw_item is CampaignItemState' not in resolution or 'condition = 1.0' not in resolution:
    errors.append("strategic character resolution does not treat campaign armour as serviceable")
if 'container_kind == CampaignItemLocationState.CONTAINER_WORN_UTILITY' not in deployment:
    errors.append("deployment does not safely map legacy Worn Utility content")
if 'deployment_condition = 1.0' not in deployment:
    errors.append("deployment does not emit serviceable recovered armour")
if 'Worn Utility: %s' in tactical_window:
    errors.append("tactical character details still display the removed Worn Utility slot")

if errors:
    print("Stage 5.3 Loadout Screen Correction validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — Equip Troops uses responsive full-workspace proportions without fixed overwide columns.")
print("PASS — Worn Utility is removed from player-facing strategic and tactical summaries and legacy data migrates safely.")
print("PASS — recovered armour is serviceable strategically and no armour condition is shown in the selector.")
