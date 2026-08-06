#!/usr/bin/env python3
"""Validate Stage 5.4A3 Storage tabs and Marauder-only Raider's Sack fixture."""
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
errors: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        errors.append(f"Missing required file: {rel}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def require(text: str, tokens: list[str], label: str) -> None:
    for token in tokens:
        if token not in text:
            errors.append(f"{label} missing contract: {token}")


shell = read("presentation/campaign/campaign_shell.gd")
query = read("application/inventory/strategic_storage_query_service.gd")
session = read("bootstrap/app/campaign_session.gd")
inventory = read("application/inventory/inventory_service.gd")
equipment = read("application/inventory/strategic_equipment_service.gd")
loadout = read("application/inventory/loadout_service.gd")
shop = read("application/inventory/shop_service.gd")
dismantle = read("application/inventory/dismantling_service.gd")
migration = read("application/campaign/migrations/marauder_loadout_migration.gd")
prestige = read("application/characters/troop_prestige_service.gd")
validator = read("application/campaign/campaign_item_validator.gd")
state = read("domain/campaign/campaign_state.gd")
runtime = read("tests/integration/stage_5_4a_storage_shop_tests.gd")

require(shell, [
    'const STORAGE_VIEW_STORED: StringName = &"storage"',
    'const STORAGE_VIEW_EQUIPPED: StringName = &"equipped"',
    'func _build_storage_location_tabs()',
    '"IN STORAGE"',
    '"EQUIPPED & CARRIED"',
    'Only this tab uses Storage Space.',
    'EQUIPPED & CARRIED · 0 STORAGE SPACE',
    'Search stored items, resources or reservations',
    'Search equipped items, characters, containers or reservations',
    'return reservation_name.to_upper() if not reservation_name.is_empty() else "RESERVED"',
    'PERMANENT TIER FIXTURE',
], "Storage UI")

header_start = shell.find("func _build_storage_group_header()")
header_end = shell.find("func _build_storage_group_block(", header_start)
header = shell[header_start:header_end]
for forbidden in ('"TOTAL"', '"AVAILABLE"', '"ASSIGNED"', '"RESERVED"'):
    if forbidden in header:
        errors.append(f"Storage header still exposes obsolete summary column {forbidden}.")
for required in ('"ASSET"', '"QUANTITY"', '"STORAGE"'):
    if required not in header:
        errors.append(f"Storage header missing {required}.")

require(query, [
    'LOCATION_FILTER_STORAGE',
    'LOCATION_FILTER_EQUIPPED',
    'location_filter: StringName = LOCATION_FILTER_ALL',
    '_location_matches_filter(item.location.location_type, location_filter)',
    'location_type == LOCATION_STRONGHOLD_STORAGE',
    'location_type in [LOCATION_CHARACTER_EQUIPMENT, LOCATION_CHARACTER_INVENTORY]',
], "Storage query")
require(session, [
    'location_filter: StringName = &"all"',
    'strategic_storage_query_service.build_groups(',
    'definition.fixed_inventory_fixture',
    'All movable equipment returned to stronghold storage.',
    'cannot be moved by loadout restore',
], "Campaign session")
require(inventory, [
    'definition.fixed_inventory_fixture',
    '&"fixed_inventory_fixture"',
    'cannot be moved, transferred or repositioned',
    'cannot be returned to Storage',
], "Inventory service")
require(equipment, [
    'definition.fixed_inventory_fixture',
    'placed_ids.append(item.item_id)',
    'The selected container has no movable items.',
    'cannot be returned to Storage',
], "Strategic equipment service")
require(loadout, [
    'existing_definition.fixed_inventory_fixture',
    'continue',
], "Loadout service")
require(shop, [
    'definition.fixed_inventory_fixture',
    '&"shop_fixed_fixture"',
], "Shop service")
require(dismantle, [
    'definition.fixed_inventory_fixture',
    '&"dismantle_fixed_fixture"',
], "Dismantling service")
require(migration, [
    'RAIDERS_BURDEN_FEAT_ID',
    'RAIDERS_SACK_DEFINITION_ID',
    'RAIDERS_SACK_POSITION: Vector2i = Vector2i(5, 0)',
    'static func should_have_raiders_sack',
    'static func repair_raiders_sack_fixture',
    'Save loading must never rebuild a player\'s ordinary loadout.',
    '_return_overlapping_belt_items_to_storage',
    'campaign.remove_item(obsolete_sack.item_id)',
], "Raider's Sack lifecycle migration")
require(prestige, [
    'character.active_tier_starting_feat_ids = stage.tier_starting_feat_ids.duplicate()',
    'MarauderLoadoutMigration.repair_raiders_sack_fixture(',
    'Earlier levels and earned features were retained; Tier starting feats were replaced.',
], "Prestige fixture integration")
require(validator, [
    'Fixed fixture %s must remain in a character inventory.',
    'Raider\'s Sack %s must remain on its owner\'s Belt.',
    'must own exactly one fixed Raider\'s Sack',
    'retains Raider\'s Sack after Raider\'s Burden was replaced',
], "Campaign item validation")
require(runtime, [
    '_test_storage_location_views',
    '_test_raiders_sack_tier_fixture',
    'Raider\'s Sack remained removable.',
    'Save migration rebuilt an ordinary Marauder loadout item.',
    'Raider\'s Sack survived replacement of Raider\'s Burden.',
], "Runtime coverage")

version = re.search(r"const CURRENT_SAVE_VERSION: int = (\d+)", state)
if not version or int(version.group(1)) < 21:
    errors.append("Campaign save version was not advanced to at least 21.")

if errors:
    print("Stage 5.4A3 Storage tabs and Raider's Sack validation FAILED:")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("Stage 5.4A3 Storage tabs and Raider's Sack validation PASSED.")
