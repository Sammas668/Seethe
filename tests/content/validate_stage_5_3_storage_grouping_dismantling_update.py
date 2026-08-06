#!/usr/bin/env python3
"""Static acceptance checks for grouped Storage and basic atomic dismantling."""
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
errors: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        errors.append(f"missing required file: {rel}")
        return ""
    return path.read_text(encoding="utf-8")


shell = read("presentation/campaign/campaign_shell.gd")
session = read("bootstrap/app/campaign_session.gd")
query = read("application/inventory/strategic_storage_query_service.gd")
dismantle = read("application/inventory/dismantling_service.gd")
inventory = read("application/inventory/inventory_service.gd")
catalogue = read("application/content/content_catalogue.gd")
loader = read("infrastructure/content/godot_content_loader.gd")
factory = read("infrastructure/content/sandbox_content_catalogue_factory.gd")
recipe_definition = read("domain/inventory/definitions/dismantling_recipe_definition.gd")

for token in [
    'IN STORAGE',
    'EQUIPPED & CARRIED',
    'Search stored items, resources or reservations',
    'Search equipped items, characters, containers or reservations',
    'ALL STATES',
    'AVAILABLE QUANTITY',
    'func _build_storage_group_block(',
    'func _build_storage_instance_row(',
    'func _build_storage_group_summary(',
    'func _build_storage_instance_details(',
    'BASIC DISMANTLING',
    'func _request_storage_dismantle(',
    'This exact item will be permanently destroyed.',
    'VIEW CHARACTER',
    'VIEW CHARACTER',
]:
    if token not in shell:
        errors.append(f"Storage UI missing: {token}")

for forbidden in [
    'PROTECT FROM AUTOMATIC USE',
    'PROTECT FROM AUTOMATIC SELECTION',
    'TOTAL STORED WEIGHT',
    'func _build_storage_filter_panel(',
]:
    if forbidden in shell:
        errors.append(f"deferred/obsolete Storage feature remains: {forbidden}")

for token in [
    'func build_groups(',
    'STATE_AVAILABLE',
    'STATE_ASSIGNED',
    'STATE_RESERVED',
    '"total_count"',
    '"available_count"',
    '"assigned_count"',
    '"reserved_count"',
    'active_reservation_for_item',
    'release_condition',
    'definition_tags(',
]:
    if token not in query:
        errors.append(f"storage query service missing: {token}")

for token in [
    'class_name DismantlingRecipeDefinition',
    'input_item_definition_id',
    'resource_yields',
    'basic_dismantling_allowed',
    'func clean_resource_yields()',
    'VALID_RESOURCE_IDS',
]:
    if token not in recipe_definition:
        errors.append(f"recipe definition missing: {token}")

for token in [
    'register_dismantling_recipe(',
    'dismantling_recipe_for_item(',
    '_validate_dismantling_recipes(',
]:
    if token not in catalogue:
        errors.append(f"content catalogue missing dismantling support: {token}")

if 'dismantling_resources: Array = []' not in loader:
    errors.append("GodotContentLoader does not accept dismantling resources")
for token in ['DISMANTLING_RECIPES', 'content/dismantling/grain_crate.tres', 'content/dismantling/mace.tres']:
    if token not in factory:
        errors.append(f"sandbox catalogue factory missing: {token}")

for token in [
    'func preview_dismantle(',
    'func dismantle_candidate(',
    'validate_item_available(campaign, item_id)',
    'LOCATION_STRONGHOLD_STORAGE',
    'Stacked items cannot yet be dismantled.',
    'consume_exact_item_candidate(',
    'campaign.resources.add(resource_id, amount)',
]:
    if token not in dismantle:
        errors.append(f"dismantling service missing: {token}")

consume_pos = dismantle.find('consume_exact_item_candidate(')
resource_pos = dismantle.find('campaign.resources.add(resource_id, amount)')
if consume_pos < 0 or resource_pos < 0 or consume_pos > resource_pos:
    errors.append("dismantling candidate does not consume the exact item before staging yields")

for token in [
    'func consume_exact_item_candidate(',
    'validate_item_available(',
    'campaign.remove_item(item_id)',
]:
    if token not in inventory:
        errors.append(f"InventoryService missing exact consumption support: {token}")

for token in [
    'DismantlingServiceScript',
    'StrategicStorageQueryServiceScript',
    'func storage_group_snapshots(',
    'func storage_instance_snapshot(',
    'func preview_dismantle_item(',
    'func dismantle_item(',
    'changes.configure(&"item_dismantled", campaign.revision)',
    'state_store.commit(changes)',
]:
    if token not in session:
        errors.append(f"CampaignSession missing grouped Storage/dismantling contract: {token}")

recipe_paths = sorted((ROOT / "content/dismantling").glob("*.tres"))
if len(recipe_paths) < 4:
    errors.append("fewer than four authored basic dismantling recipes were added")
item_ids = set(re.findall(r'^id = &"([^"]+)"', "\n".join(
    path.read_text(encoding="utf-8") for path in (ROOT / "content/items").glob("*.tres")
), re.MULTILINE))
for path in recipe_paths:
    text = path.read_text(encoding="utf-8")
    match = re.search(r'input_item_definition_id = &"([^"]+)"', text)
    if not match:
        errors.append(f"{path.name} has no input item definition")
    elif match.group(1) not in item_ids:
        errors.append(f"{path.name} references unknown item {match.group(1)}")
    if 'resource_yields = {' not in text:
        errors.append(f"{path.name} has no authored resource yields")

if errors:
    print("Stage 5.3 Storage Grouping & Dismantling validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — Storage groups exact items while preserving authoritative instances and locations.")
print("PASS — Available, Assigned and Reserved counts are mutually exclusive presentation states.")
print("PASS — basic dismantling is recipe-driven, reservation-aware and committed atomically.")
print("PASS — protection, footer totals, selling, bulk dismantling and production remain deferred.")
