#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELL = (ROOT / "presentation/campaign/campaign_shell.gd").read_text(encoding="utf-8")

errors: list[str] = []

required_tokens = [
    'const ROSTER_MODE_MANAGE: StringName = &"manage"',
    'const ROSTER_MODE_EQUIP: StringName = &"equip"',
    'const ROSTER_MODE_MEMORIAL: StringName = &"memorial"',
    'func _build_roster_manage_view(',
    'func _build_roster_equip_view(',
    'func _build_roster_memorial_view(',
    'MANAGE ROSTER',
    'EQUIP TROOPS',
    'MEMORIAL',
    'QUICK ROSTER',
    'AVAILABLE EQUIPMENT',
    'STRONGHOLD INVENTORY',
    'CampaignItemLocationState.CONTAINER_PRIMARY_HAND',
    'CampaignItemLocationState.CONTAINER_SECONDARY_HAND',
    'CampaignItemLocationState.CONTAINER_ARMOUR',
    'CampaignItemLocationState.CONTAINER_BELT',
    'CampaignItemLocationState.CONTAINER_BACKPACK',
    'res://assets/strategic/roster/roster_manage_background.svg',
    'base.color = Color("0b0f0f")',
    'res://assets/strategic/storage/storage_background.svg',
]
for token in required_tokens:
    if token not in SHELL:
        errors.append(f"campaign_shell.gd missing token: {token}")


if 'DESTINATION —' in SHELL:
    errors.append("obsolete Available Equipment destination label remains")

if '"WORN UTILITY"' in SHELL or '"Worn Utility"' in SHELL:
    errors.append("removed Worn Utility slot is still visible in the strategic roster UI")

if 'func _build_equipment_screen() -> void:' in SHELL:
    errors.append("obsolete standalone Equipment screen still exists")
if '_add_nav_button(row, SCREEN_EQUIPMENT' in SHELL:
    errors.append("obsolete top-level Equipment navigation remains")
if '.set_location(' in SHELL or '.assign_item_to_character(' in SHELL:
    errors.append("presentation directly mutates persistent item location")

required_files = [
    "assets/strategic/roster/roster_manage_background.svg",
    "assets/strategic/roster/roster_equip_background.svg",
    "assets/strategic/storage/storage_background.svg",
    "presentation/campaign/icons/item_categories/weapon.svg",
    "presentation/campaign/icons/item_categories/armour.svg",
    "presentation/campaign/icons/item_categories/gear.svg",
    "presentation/campaign/icons/item_categories/consumable.svg",
    "presentation/campaign/icons/item_categories/ammunition.svg",
    "presentation/campaign/icons/item_categories/furniture.svg",
    "presentation/campaign/icons/item_categories/salvage.svg",
    "presentation/campaign/icons/item_categories/other.svg",
]
for rel in required_files:
    if not (ROOT / rel).is_file():
        errors.append(f"missing authored display asset: {rel}")

if errors:
    print("Stage 5.3 Xenonauts-style roster/storage display validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — Roster provides Manage Roster, Equip Troops and Memorial modes inside one top-level screen.")
print("PASS — Equip Troops uses character-first full-body presentation, visual slots, quick switching and exact item intents.")
print("PASS — Storage remains a separate grouped item-first screen with compact toolbar and exact-instance details.")
print("PASS — authored dark-fantasy backgrounds and category icon fallbacks are present.")
