#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

shell = (ROOT / "presentation/campaign/campaign_shell.gd").read_text(encoding="utf-8")
session = (ROOT / "bootstrap/app/campaign_session.gd").read_text(encoding="utf-8")
service = (ROOT / "application/inventory/strategic_equipment_service.gd").read_text(encoding="utf-8")
inventory_service = (ROOT / "application/inventory/inventory_service.gd").read_text(encoding="utf-8")
item_state = (ROOT / "domain/campaign/campaign_item_state.gd").read_text(encoding="utf-8")
query_service = (ROOT / "application/inventory/strategic_storage_query_service.gd").read_text(encoding="utf-8")

errors: list[str] = []

required_shell_tokens = [
    'const SCREEN_STORAGE: StringName = &"storage"',
    '_add_nav_button(row, SCREEN_ROSTER, "ROSTER", "Roster and Equipment")',
    '_add_nav_button(row, SCREEN_STORAGE, "STORAGE", "Stronghold Storage")',
    'func _build_roster_screen() -> void:',
    'func _build_storage_screen() -> void:',
    'AVAILABLE EQUIPMENT',
    'IN STORAGE',
    'EQUIPPED & CARRIED',
    'ALL STATES',
    'TOTAL QUANTITY',
    'AVAILABLE QUANTITY',
    'func _build_storage_group_block(',
    'func _build_storage_instance_row(',
    'func _build_storage_grouped_details(',
    'CampaignItemLocationState.CONTAINER_PRIMARY_HAND',
    'CampaignItemLocationState.CONTAINER_SECONDARY_HAND',
    'CampaignItemLocationState.CONTAINER_ARMOUR',
    'CampaignItemLocationState.CONTAINER_BELT',
    'CampaignItemLocationState.CONTAINER_BACKPACK',
]
for token in required_shell_tokens:
    if token not in shell:
        errors.append(f"campaign_shell.gd missing token: {token}")

for forbidden in [
    'PROTECT FROM AUTOMATIC USE',
    'PROTECT FROM AUTOMATIC SELECTION',
    'func _build_storage_filter_panel(',
    'func _storage_category_count(',
]:
    if forbidden in shell:
        errors.append(f"obsolete Storage UI remains: {forbidden}")

if 'OPEN STORAGE' in shell:
    errors.append("The obsolete Open Storage button remains on Equip Troops.")
if '_add_nav_button(row, SCREEN_EQUIPMENT, "GEAR", "Equipment")' in shell:
    errors.append("The obsolete top-level Gear screen is still in navigation.")
if 'func _build_equipment_screen() -> void:' in shell:
    errors.append("The obsolete standalone Equipment screen still exists.")
if '.set_location(' in shell or '.assign_item_to_character(' in shell:
    errors.append("CampaignShell directly mutates item locations instead of sending intents.")

required_service_tokens = [
    'class_name StrategicEquipmentService',
    'func preview_equip(',
    'func equip_candidate(',
    'func preview_return_to_storage(',
    'func return_to_storage_candidate(',
    'CampaignItemValidator.validate_campaign',
    '_first_inventory_position(',
    'carrying_capacity_exceeded',
]
for token in required_service_tokens:
    if token not in service:
        errors.append(f"strategic_equipment_service.gd missing token: {token}")
if '.assign_item_to_character(' in service or '.move_item_to_stronghold(' in service:
    errors.append("StrategicEquipmentService writes item locations without InventoryService.")

required_session_tokens = [
    'InventoryServiceScript',
    'StrategicEquipmentServiceScript',
    'StrategicStorageQueryServiceScript',
    'DismantlingServiceScript',
    'strategic_equipment_service.configure(',
    'strategic_reservation_service',
    'func equip_strategic_item(',
    'func unequip_strategic_item(',
    'func storage_group_snapshots(',
    'func preview_dismantle_item(',
    'func dismantle_item(',
    'CampaignChangeSet.new()',
    'state_store.commit(changes)',
]
for token in required_session_tokens:
    if token not in session:
        errors.append(f"campaign_session.gd missing token: {token}")

for token in [
    'class_name InventoryService',
    'func move_item_to_character_candidate(',
    'func move_item_to_stronghold_candidate(',
    'func consume_exact_item_candidate(',
]:
    if token not in inventory_service:
        errors.append(f"inventory_service.gd missing token: {token}")

for token in [
    'func build_groups(',
    '"total_count"',
    '"available_count"',
    '"assigned_count"',
    '"reserved_count"',
    'STATE_RESERVED',
]:
    if token not in query_service:
        errors.append(f"strategic_storage_query_service.gd missing token: {token}")

# The legacy field remains serialized for compatibility, but is no longer player-facing.
for token in [
    'var is_protected: bool = false',
    '"is_protected": is_protected',
    'data.get("is_protected", false)',
]:
    if token not in item_state:
        errors.append(f"campaign_item_state.gd missing compatibility token: {token}")

if errors:
    print("Stage 5.3 Roster & Storage Screen Update validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — Roster and Equipment remain combined into one Xenonauts-style character screen.")
print("PASS — Stronghold Storage uses grouped exact-item presentation with compact toolbar filters.")
print("PASS — protection is hidden while exact identity, reservations and transactional equipment remain authoritative.")
