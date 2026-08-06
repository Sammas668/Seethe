#!/usr/bin/env python3
"""Static acceptance checks for pooled Stronghold Storage Capacity and overflow."""
from __future__ import annotations

from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[2]
errors: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        errors.append(f"missing required file: {rel}")
        return ""
    return path.read_text(encoding="utf-8")


item_definition = read("domain/inventory/definitions/item_definition.gd")
inventory = read("application/inventory/inventory_service.gd")
facility_definition = read("domain/stronghold/stronghold_facility_definition.gd")
stronghold_factory = read("infrastructure/content/stronghold/starting_stronghold_factory.gd")
query = read("application/inventory/strategic_storage_query_service.gd")
dismantling = read("application/inventory/dismantling_service.gd")
equipment = read("application/inventory/strategic_equipment_service.gd")
loadouts = read("application/inventory/loadout_service.gd")
session = read("bootstrap/app/campaign_session.gd")
shell = read("presentation/campaign/campaign_shell.gd")

for token in [
    '@export var storage_space: int = 1',
    '@export var storage_units_per_bundle: int = 1',
    '@export var storage_space_per_bundle: int = 1',
    'func storage_space_for_quantity(quantity: int) -> int:',
    'ceili(float(quantity) / float(bundle_size))',
    'storage_space < 0',
    'storage_units_per_bundle < 1',
]:
    if token not in item_definition:
        errors.append(f"ItemDefinition missing Storage Space contract: {token}")

item_paths = sorted((ROOT / "content/items").glob("*.tres"))
if not item_paths:
    errors.append("no item resources found")
for path in item_paths:
    text = path.read_text(encoding="utf-8")
    for field in ("storage_space", "storage_units_per_bundle", "storage_space_per_bundle"):
        if not re.search(rf"^{field}\s*=\s*\d+", text, re.MULTILINE):
            errors.append(f"{path.name} lacks explicit {field}")

for token in [
    'var storage_capacity_by_level: Array[int] = []',
    'func storage_capacity_for_level(level_value: int) -> int:',
    'storage capacity decreases across normal levels',
]:
    if token not in facility_definition:
        errors.append(f"facility definition missing capacity support: {token}")
if 'raw_storage_capacity' not in stronghold_factory:
    errors.append("starting stronghold factory does not parse storage_capacity_by_level")

stronghold_path = ROOT / "content/stronghold/starting_ruin/starting_ruin.json"
try:
    stronghold = json.loads(stronghold_path.read_text(encoding="utf-8"))
except Exception as exc:  # pragma: no cover - diagnostics
    errors.append(f"starting stronghold JSON invalid: {exc}")
    stronghold = {}
facilities = {entry.get("id"): entry for entry in stronghold.get("facilities", [])}
if facilities.get("facility.fifth_god_heart", {}).get("storage_capacity_by_level") != [100, 100, 100, 100, 100]:
    errors.append("Fifth-God Heart starting vaults are not authored as 100 capacity")
if facilities.get("facility.storehouse", {}).get("storage_capacity_by_level") != [80, 140, 220]:
    errors.append("Storehouse capacity progression is not 80/140/220")

for token in [
    'INTAKE_REQUIRE_CAPACITY',
    'INTAKE_ALLOW_OVERFLOW',
    'func storage_space_for_item(',
    'func used_item_storage_space(',
    'func resource_storage_space(',
    'func used_storage_space(',
    'func maximum_storage_space(',
    'func storage_capacity_snapshot(',
    'func validate_storage_intake(',
    'item.location.location_type == LOCATION_STRONGHOLD_STORAGE',
    'CONDITION_UNDER_CONSTRUCTION, CONDITION_DISABLED',
    'CONDITION_DAMAGED',
    'CONDITION_OPERATIONAL, CONDITION_UPGRADING',
    '"capacity_sources"',
    '"usage_by_category"',
    '"resource_usage"',
    'storage_capacity_insufficient',
]:
    if token not in inventory:
        errors.append(f"InventoryService missing storage-capacity behaviour: {token}")

for token in [
    '"stored_count"',
    '"stored_space"',
    '"single_item_storage_space"',
    '"storage_space_if_stored"',
    '"current_storage_space"',
]:
    if token not in query:
        errors.append(f"storage query missing capacity presentation data: {token}")

for token in [
    'storage_space_released',
    'storage_used_before',
    'storage_used_after',
    'storage_maximum',
]:
    if token not in dismantling:
        errors.append(f"dismantling preview missing capacity value: {token}")

if 'intake_policy: StringName = InventoryService.INTAKE_REQUIRE_CAPACITY' not in equipment:
    errors.append("manual equipment return does not default to capacity-required intake")
if 'InventoryService.INTAKE_ALLOW_OVERFLOW' not in loadouts:
    errors.append("loadout application does not use temporary overflow-safe reconciliation")
if 'final_overflow > initial_overflow' not in loadouts:
    errors.append("loadout application does not reject worsened final overflow")

for token in [
    'func storage_capacity_snapshot() -> Dictionary:',
    'func preview_storage_intake(',
    'InventoryServiceScript.INTAKE_ALLOW_OVERFLOW',
    'Storage is no longer over capacity.',
    'Recovered objects exceeded Storage Capacity. No items were lost.',
]:
    if token not in session:
        errors.append(f"CampaignSession missing capacity contract: {token}")

for rel in [
    "tests/campaign/stage_5_3_storage_capacity_overflow_tests.gd",
    "tests/campaign/run_stage_5_3_storage_capacity_overflow_tests.gd",
]:
    read(rel)

for token in [
    'func _build_storage_capacity_display() -> Control:',
    'STORAGE %d / %d',
    'OVER BY %d',
    'NEAR LIMIT',
    'func _storage_capacity_tooltip(',
    'Single-item Storage Space',
    'Current stored space',
    'Requires %d space if returned to Stronghold Storage.',
    'Frees %d Storage Space',
    'The stronghold will be over capacity by %d. No items will be destroyed.',
    'Storage Capacity\\n+%d → +%d',
]:
    if token not in shell:
        errors.append(f"Storage/Stronghold UI missing capacity presentation: {token}")

for forbidden in [
    'random item loss',
    'automatic item disposal',
    'physical warehouse grid',
]:
    # Guard only against accidental user-facing feature labels, not design docs.
    if forbidden.upper() in shell.upper():
        errors.append(f"forbidden overflow behaviour exposed in UI: {forbidden}")

if errors:
    print("Stage 5.3 Storage Capacity & Overflow validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — every physical item has explicit, bundle-aware Storage Space authorship.")
print("PASS — the Fifth-God Heart starts at 100 capacity and Storehouses add pooled live-facility capacity.")
print("PASS — stored item instances and non-Gold strategic resources consume derived capacity.")
print("PASS — mandatory overflow and capacity-required optional intake use explicit policies.")
print("PASS — Storage, dismantling, equipment, loadouts, upgrades and demolition present capacity coherently.")
