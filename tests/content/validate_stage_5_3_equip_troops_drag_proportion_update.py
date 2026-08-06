#!/usr/bin/env python3
"""Static acceptance checks for the Stage 5.3 Equip Troops Drag Proportion Update."""
from __future__ import annotations

import re
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
expected = {
    "EQUIP_LEFT_RAIL_LEFT": 0.008,
    "EQUIP_LEFT_RAIL_RIGHT": 0.164,
    "EQUIP_EQUIPPED_LEFT": 0.175,
    "EQUIP_EQUIPPED_RIGHT": 0.245,
    "EQUIP_CHARACTER_LEFT": 0.252,
    "EQUIP_CHARACTER_RIGHT": 0.565,
    "EQUIP_CARRIED_LEFT": 0.575,
    "EQUIP_CARRIED_RIGHT": 0.735,
    "EQUIP_CARRIED_BOTTOM": 0.600,
    "EQUIP_AVAILABLE_LEFT": 0.750,
    "EQUIP_AVAILABLE_RIGHT": 0.992,
}
values: dict[str, float] = {}
for name, wanted in expected.items():
    match = re.search(rf"const {name}: float = ([0-9.]+)", shell)
    if match is None:
        errors.append(f"missing layout constant: {name}")
        continue
    value = float(match.group(1))
    values[name] = value
    if abs(value - wanted) > 0.0001:
        errors.append(f"{name} expected {wanted:.3f}, got {value:.3f}")

left_width = values.get("EQUIP_LEFT_RAIL_RIGHT", 0) - values.get("EQUIP_LEFT_RAIL_LEFT", 0)
former_left_width = 0.216 - 0.008
if abs(left_width - former_left_width * 0.75) > 0.002:
    errors.append("left rail is not 75% of the former width")

carried_width = values.get("EQUIP_CARRIED_RIGHT", 0) - values.get("EQUIP_CARRIED_LEFT", 0)
if abs(carried_width - 0.16) > 0.002:
    errors.append("carried loadout column is not the requested 20% narrower 0.16 share")

for label, right_edge, next_left in [
    ("left/equipped", values.get("EQUIP_LEFT_RAIL_RIGHT", 1), values.get("EQUIP_EQUIPPED_LEFT", 0)),
    ("equipped/character", values.get("EQUIP_EQUIPPED_RIGHT", 1), values.get("EQUIP_CHARACTER_LEFT", 0)),
    ("character/carried", values.get("EQUIP_CHARACTER_RIGHT", 1), values.get("EQUIP_CARRIED_LEFT", 0)),
    ("carried/available", values.get("EQUIP_CARRIED_RIGHT", 1), values.get("EQUIP_AVAILABLE_LEFT", 0)),
]:
    if right_edge >= next_left:
        errors.append(f"functional regions overlap: {label}")

required_tokens = [
    'portrait.custom_minimum_size = Vector2(42, 58)',
    'name.add_theme_font_size_override("font_size", 12)',
    'slot.custom_minimum_size = Vector2(0, 48)',
    'slot.configure(slot_id, "")',
    'slot.icon = icon_texture',
    'slot.add_theme_constant_override("icon_max_width", 44)',
    'belt.custom_minimum_size.y = 62',
    'EQUIP_CARRIED_BOTTOM',
    'return 19.0',
    'return 22.0',
    'return 24.0',
    'return 26.0',
    'drag_item.tooltip_text = "Drag to a hand, Belt or Backpack."',
    'The card exposes no click-to-equip button',
]
for token in required_tokens:
    if token not in shell:
        errors.append(f"campaign_shell.gd missing update token: {token}")

card_start = shell.find("func _build_available_equipment_card(")
card_end = shell.find("func _category_for_slot(", card_start)
card = shell[card_start:card_end]
for forbidden in ['equip.text = "PLACE"', '_request_roster_equip(item_id, character_id, slot_id)', 'Double-click alternative']:
    if forbidden in card:
        errors.append(f"available equipment card retains click-to-equip affordance: {forbidden}")
if '_get_drag_data' not in read("presentation/tactical/spatial_inventory_item_control.gd"):
    errors.append("available equipment control no longer exposes drag data")

composition_start = shell.find("func _build_xenonauts_loadout_composition(")
composition_end = shell.find("func _place_equip_region(", composition_start)
composition = shell[composition_start:composition_end]
if 'EQUIP_CARRIED_BOTTOM' not in composition:
    errors.append("carried panel still extends to the full content bottom")

if errors:
    print("Stage 5.3 Equip Troops Drag Proportion validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — Soldier Information and Assignments use the narrower 75%-width left rail.")
print("PASS — Primary and Secondary are compact icon-only drop boxes.")
print("PASS — Loadout, Belt and Backpack occupy a 20%-narrower non-overlapping column.")
print("PASS — the carried panel ends beneath the Backpack instead of leaving a tall empty panel.")
print("PASS — Available Equipment is drag-first and exposes no click-to-equip PLACE button.")
