#!/usr/bin/env python3
"""Validate Stage 5.4A5: Gold is funds, not a Storage-list asset."""
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
    'if resource_id == &"gold":',
    'continue',
    'Gold is campaign funds, not a stored physical resource.',
    'gold.text = "GOLD  %d"',
    'campaign.resources.amount(&"gold")',
    'func _build_shop_screen()',
], "Gold presentation boundary")

# The Storage resource details path should now only describe physical resources.
storage_section = shell.split("func _storage_visible_resource_ids", 1)[1].split("func _build_shop_screen", 1)[0]
for forbidden in (
    'Coin used for trade. Gold does not consume Stronghold Storage Space.',
    'Gold uses no Stronghold Storage Space.',
    'Gold Coins are the Shop currency and cannot be sold.',
    '"CURRENCY" if resource_id == &"gold" else "RESOURCE"',
):
    if forbidden in storage_section:
        errors.append(f"Storage still contains a Gold-row presentation branch: {forbidden}")

# Gold remains a campaign balance and Shop currency, and remains excluded from
# physical resource Storage-space accounting and resource selling.
require(resources, [
    '&"gold"',
    'if resource_id == &"gold" or not STORAGE_RESOURCE_IDS.has(resource_id):',
], "Campaign funds accounting")
require(shop, [
    'Gold cannot be sold for Gold.',
    'campaign.resources.amount(&"gold")',
], "Shop Gold handling")

if errors:
    print("Stage 5.4A5 Gold-as-funds validation FAILED:")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("Stage 5.4A5 Gold-as-funds validation PASSED.")
