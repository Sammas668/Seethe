from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    target = ROOT / path
    assert target.exists(), f"Missing Stage 5.4A2 file: {path}"
    return target.read_text(encoding="utf-8")


resources = read("domain/campaign/campaign_resource_balances.gd")
for token in (
    '&"textiles"',
    "var textiles: int = 0",
    "STORAGE_RESOURCE_IDS",
    "RESOURCE_STORAGE_UNITS_PER_SPACE: int = 100",
    "func storage_space_for",
    "func total_storage_space",
    '"textiles": textiles',
):
    assert token in resources, f"Campaign resources missing: {token}"

inventory = read("application/inventory/inventory_service.gd")
for token in (
    "func used_item_storage_space",
    "func resource_storage_space",
    "func projected_resource_storage_space",
    '"resource_used"',
    '"resource_usage"',
):
    assert token in inventory, f"Inventory storage accounting missing: {token}"

shop = read("application/inventory/shop_service.gd")
for token in (
    "RESOURCE_SALE_LOTS",
    '&"wood": {"display_name": "Wood", "lot_size": 10, "gold_per_lot": 2}',
    '&"stone": {"display_name": "Stone", "lot_size": 10, "gold_per_lot": 1}',
    '&"metal": {"display_name": "Metal", "lot_size": 10, "gold_per_lot": 5}',
    '&"food": {"display_name": "Food", "lot_size": 10, "gold_per_lot": 2}',
    '&"textiles": {"display_name": "Textiles", "lot_size": 10, "gold_per_lot": 3}',
    '&"magic": {"display_name": "Magic", "lot_size": 1, "gold_per_lot": 2}',
    "func preview_sell_resource",
    "func sell_resource_candidate",
    'resource_id == &"gold"',
):
    assert token in shop, f"Resource Shop selling missing: {token}"

transaction = read("domain/economy/shop_transaction_state.gd")
for token in (
    "var resource_id",
    "var resource_amount",
    "func is_resource_transaction",
    "attempts to sell Gold",
):
    assert token in transaction, f"Shop transaction resource provenance missing: {token}"

session = read("bootstrap/app/campaign_session.gd")
for token in (
    "func preview_shop_sell_resource",
    "func sell_shop_resource",
    '&"shop_resource_sale"',
):
    assert token in session, f"CampaignSession resource sale boundary missing: {token}"

shell = read("presentation/campaign/campaign_shell.gd")
for token in (
    '&"textiles": "T"',
    '[&"resources", "RESOURCES"]',
    "func _request_shop_sell_resource",
    'return "Resources"',
    "func _build_storage_resource_row",
    'storage.text = str(int(entry.get("storage_space", 0)))',
    "Every 100 stored units, or part thereof, use 1 Storage Space.",
):
    assert token in shell, f"Campaign UI missing Textiles/resource sale presentation: {token}"

state = read("domain/campaign/campaign_state.gd")
version_match = re.search(r"const CURRENT_SAVE_VERSION: int = (\d+)", state)
assert version_match and int(version_match.group(1)) >= 20

new_campaign = read("application/campaign/new_campaign_service.gd")
assert "campaign.resources.textiles = 0" in new_campaign

grain = read("content/dismantling/grain_sack.tres")
assert 'resource_yields = {"food": 3, "textiles": 1}' in grain
for path, item_id in (
    ("content/dismantling/empty_sack.tres", "item.empty_sack"),
    ("content/dismantling/rope.tres", "item.rope"),
):
    text = read(path)
    assert f'input_item_definition_id = &"{item_id}"' in text
    assert 'resource_yields = {"textiles": 1}' in text

factory = read("infrastructure/content/sandbox_content_catalogue_factory.gd")
for token in (
    'preload("res://content/dismantling/empty_sack.tres")',
    'preload("res://content/dismantling/rope.tres")',
):
    assert token in factory

integration = read("tests/integration/stage_5_4a_storage_shop_tests.gd")
for token in (
    "_test_textiles_storage_and_resource_sales",
    'preview_shop_sell_resource(&"wood", 2)',
    'sell_shop_resource(&"wood", 2)',
    'preview_shop_sell_resource(&"gold", 1)',
):
    assert token in integration

print("PASS — Textiles, resource Storage usage and fixed-lot resource selling are integrated.")
