#!/usr/bin/env python3
"""Validate Stage 5.4A4 integrated resource rows in strategic Storage."""
from __future__ import annotations

from pathlib import Path

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
resources = read("domain/campaign/campaign_resource_balances.gd")
shop = read("application/inventory/shop_service.gd")

require(shell, [
    'var _selected_storage_resource_id: StringName = &""',
    'func _storage_visible_resource_ids(campaign: CampaignState)',
    'func _storage_display_entries(',
    'func _build_storage_resource_row(entry: Dictionary)',
    'func _build_storage_resource_details(',
    '[&"resources", "RESOURCES"]',
    'asset.text = "ASSET"',
    'quantity.text = "QUANTITY"',
    'storage.text = "STORAGE"',
    'No stored items or physical resources match the current search and filters.',
    'Every 100 stored units, or part thereof, use 1 Storage Space.',
    'sell.text = "SELL IN SHOP"',
    '_shop_selected_resource_id = resource_id',
], "Storage resource-row UI")

if "func _build_storage_resource_strip" in shell:
    errors.append("The obsolete separate Storage resource strip still exists.")
if 'column.add_child(_build_storage_resource_strip())' in shell:
    errors.append("Storage still renders the obsolete separate resource strip.")

require(resources, [
    'RESOURCE_STORAGE_UNITS_PER_SPACE: int = 100',
    'func storage_space_for(resource_id: StringName)',
], "Resource storage accounting")
require(shop, [
    'func preview_sell_resource',
    'func sell_resource_candidate',
    'RESOURCE_SALE_LOTS',
], "Resource Shop integration")

# Resources are visually item-like rows but must remain fungible quantities,
# not hundreds of persistent item instances.
for forbidden in (
    'campaign.allocate_shop_item_id(resource_id)',
    'CampaignItemState.new(resource_id)',
):
    if forbidden in shell or forbidden in resources:
        errors.append(f"Resources were incorrectly converted into persistent item instances: {forbidden}")

if errors:
    print("Stage 5.4A4 resource-row validation FAILED:")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("Stage 5.4A4 resource-row validation PASSED.")
