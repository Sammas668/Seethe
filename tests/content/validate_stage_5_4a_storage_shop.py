from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def require(path: str, *tokens: str) -> str:
    target = ROOT / path
    assert target.exists(), f"Missing required Stage 5.4A file: {path}"
    text = target.read_text(encoding="utf-8")
    for token in tokens:
        assert token in text, f"{path} is missing required token: {token}"
    return text


item_definition = require(
    "domain/inventory/definitions/item_definition.gd",
    "shop_category_id",
    "shop_buy_price_gold",
    "shop_sell_price_gold",
    "shop_starting_available",
    "can be sold for more than its purchase price",
)
shop_service = require(
    "application/inventory/shop_service.gd",
    "func starting_catalogue_entries",
    "func sell_storage_entries",
    "func preview_buy",
    "func buy_candidate",
    "func preview_sell",
    "func sell_candidate",
    "campaign.allocate_shop_item_id()",
    "campaign.record_shop_transaction(transaction)",
    "shop_item_protected",
    "validate_item_available",
)
transaction_state = require(
    "domain/economy/shop_transaction_state.gd",
    "class_name ShopTransactionState",
    "KIND_BUY",
    "KIND_SELL",
    "does not conserve Gold",
    "records no exact item identity",
)
campaign_state = require(
    "domain/campaign/campaign_state.gd",
    "shop_transactions_by_id",
    "next_shop_transaction_sequence",
    "next_shop_item_sequence",
    'base["shop_transactions"]',
    'data.get("shop_transactions", [])',
)
campaign_version_match = re.search(r"const CURRENT_SAVE_VERSION: int = (\d+)", campaign_state)
assert campaign_version_match and int(campaign_version_match.group(1)) >= 20, "Campaign save schema regressed below Stage 5.4A."
campaign_session = require(
    "bootstrap/app/campaign_session.gd",
    "const ShopServiceScript",
    "func shop_buy_entries",
    "func shop_sell_entries",
    "func preview_shop_buy",
    "func buy_shop_item",
    "func preview_shop_sell",
    "func sell_shop_item",
    '&"shop_purchase"',
    '&"shop_sale"',
)
shell = require(
    "presentation/campaign/campaign_shell.gd",
    'const SCREEN_SHOP: StringName = &"shop"',
    '_add_nav_button(row, SCREEN_SHOP, "SHOP"',
    "func _build_shop_screen",
    "func _request_shop_buy",
    "func _request_shop_sell",
    "func _build_storage_resource_row",
    "func _build_storage_resource_details",
    'protect.text = "UNPROTECT" if item.is_protected else "PROTECT"',
    'repair.text = "REPAIR"',
)
dismantling = require(
    "application/inventory/dismantling_service.gd",
    "This item is protected from dismantling",
)
require(
    "content/dismantling/grain_sack.tres",
    'input_item_definition_id = &"item.grain_sack"',
    'resource_yields = {"food": 3, "textiles": 1}',
)
require(
    "infrastructure/content/sandbox_content_catalogue_factory.gd",
    'preload("res://content/dismantling/grain_sack.tres")',
)
require(
    "tests/integration/stage_5_4a_storage_shop_tests.gd",
    "Stage54AStorageShopTests",
    "_test_shop_buy_sell_and_save_round_trip",
    "_test_protected_and_reserved_items_are_blocked",
    "_test_general_storage_dismantling",
)

item_paths = sorted((ROOT / "content/items").glob("*.tres"))
assert item_paths, "No item definitions found."
starting_ids: set[str] = set()
for path in item_paths:
    text = path.read_text(encoding="utf-8")
    for token in (
        "shop_category_id =",
        "shop_buy_price_gold =",
        "shop_sell_price_gold =",
        "shop_starting_available =",
    ):
        assert token in text, f"{path.name} is missing {token}"
    item_match = re.search(r'^id = &"([^"]+)"', text, re.MULTILINE)
    assert item_match, f"{path.name} has no item ID"
    item_id = item_match.group(1)
    buy = int(re.search(r"shop_buy_price_gold = (\d+)", text).group(1))
    sell = int(re.search(r"shop_sell_price_gold = (\d+)", text).group(1))
    starting = re.search(r"shop_starting_available = (true|false)", text).group(1) == "true"
    assert buy >= 0 and sell >= 0, f"{item_id} has a negative Shop price"
    if buy > 0:
        assert sell <= buy, f"{item_id} permits immediate buy-resell profit"
    if starting:
        assert buy > 0, f"{item_id} is in the starting catalogue without a purchase price"
        starting_ids.add(item_id)

expected_starting = {
    "item.bandage",
    "item.buckler",
    "item.chalk",
    "item.dagger",
    "item.empty_sack",
    "item.mace",
    "item.manacles",
    "item.rope",
    "item.sling",
    "item.spare_arrows",
    "item.training_spear",
}
assert expected_starting <= starting_ids, (
    "The approved common starting catalogue is incomplete: "
    f"missing {sorted(expected_starting - starting_ids)}"
)

# The Shop remains an immediate Buy/Sell interface when later Production and
# Research screens are present. Those screens now live in dedicated controllers;
# Stage 5.4C must still not add commissioned market orders.
production_controller = require(
    "presentation/campaign/controllers/production_screen_controller.gd",
    "class_name ProductionScreenController",
    "func build",
)
research_controller = require(
    "presentation/campaign/controllers/research_screen_controller.gd",
    "class_name ResearchScreenController",
    "func build",
)
strategic_ui = "\n".join((shell, production_controller, research_controller)).lower()
assert "commissioned market item" not in strategic_ui

print(
    "Stage 5.4A static validation passed: "
    f"{len(item_paths)} item definitions, {len(starting_ids)} starting Shop goods."
)
