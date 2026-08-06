#!/usr/bin/env python3
"""Static acceptance checks for the latest Equip Troops compact-layout correction."""
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
    "EQUIP_LEFT_RAIL_RIGHT": 0.216,
    "EQUIP_EQUIPPED_LEFT": 0.230,
    "EQUIP_EQUIPPED_RIGHT": 0.302,
    "EQUIP_CHARACTER_LEFT": 0.310,
    "EQUIP_CHARACTER_RIGHT": 0.560,
    "EQUIP_CARRIED_LEFT": 0.570,
    "EQUIP_CARRIED_RIGHT": 0.770,
    "EQUIP_AVAILABLE_LEFT": 0.785,
    "EQUIP_AVAILABLE_RIGHT": 0.992,
    "EQUIP_CONTENT_BOTTOM": 0.850,
    "EQUIP_CHARACTER_TABS_TOP": 0.865,
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

for label, right_edge, next_left in [
    ("equipped/character", values.get("EQUIP_EQUIPPED_RIGHT", 1), values.get("EQUIP_CHARACTER_LEFT", 0)),
    ("character/carried", values.get("EQUIP_CHARACTER_RIGHT", 1), values.get("EQUIP_CARRIED_LEFT", 0)),
    ("carried/available", values.get("EQUIP_CARRIED_RIGHT", 1), values.get("EQUIP_AVAILABLE_LEFT", 0)),
]:
    if right_edge >= next_left:
        errors.append(f"functional regions overlap: {label}")
if values.get("EQUIP_CONTENT_BOTTOM", 1) >= values.get("EQUIP_CHARACTER_TABS_TOP", 0):
    errors.append("main content overlaps the character tab strip")

required_tokens = [
    'if _roster_mode == ROSTER_MODE_EQUIP',
    'base.color = Color("0b0f0f")',
    'func _build_equip_left_rail(',
    'rail.add_theme_constant_override("separation", 12)',
    'information.size_flags_stretch_ratio = 1.08',
    'assignments.size_flags_stretch_ratio = 0.92',
    '"PERCEPTION"',
    'slot.custom_minimum_size = Vector2(0, 58)',
    'slot.icon = icon_texture',
    'slot.add_theme_constant_override("icon_max_width", 42)',
    'heading.add_theme_font_size_override("font_size", 9)',
    'panel.custom_minimum_size = Vector2(0, 52)',
    'icon.texture = ARMOUR_SLOT_ICON',
    'panel.custom_minimum_size.y = 36',
    'icon.custom_minimum_size = Vector2(24, 24)',
    'panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN',
    'select.add_theme_font_size_override("font_size", 9)',
    'grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN',
    'return 27.0',
    'return 29.0',
    'return 32.0',
    'storage_drop.configure(&"stronghold_storage", "DROP TO STORAGE")',
    'category_row.columns = 4',
    'storage.text = "OPEN STORAGE"',
]
for token in required_tokens:
    if token not in shell:
        errors.append(f"campaign_shell.gd missing compact-layout token: {token}")

carried_start = shell.find("func _build_equip_carried_panel(")
carried_end = shell.find("func _build_compact_loadout_strip(", carried_start)
carried = shell[carried_start:carried_end]
for forbidden in ['"AUTO-PACK"', '"UNDO"', '"RETURN ITEMS"', '"RETURN CARRIED ITEMS"']:
    if forbidden in carried:
        errors.append(f"current carried panel still exposes {forbidden}")

inventory_start = shell.find("func _build_visual_inventory_slot(")
inventory_end = shell.find("func _strategic_inventory_cell_size()", inventory_start)
inventory = shell[inventory_start:inventory_end]
if 'CenterContainer.new()' in inventory:
    errors.append("Belt/Backpack still use a centring wrapper that creates empty margins")
if 'clear.text = "CLEAR"' in inventory:
    errors.append("Belt/Backpack still expose redundant Clear/return controls")

available_start = shell.find("func _build_equip_available_items(")
available_end = shell.find("func _build_available_equipment_card(", available_start)
available = shell[available_start:available_end]
if '[EQUIPMENT_CATEGORY_ARMOUR, "ARMOUR"]' in available:
    errors.append("Available Equipment still exposes an Armour tab")

for rel in [
    "assets/strategic/roster/armour_slot_icon.svg",
    "assets/strategic/roster/weapon_slot_icon.svg",
    "assets/strategic/roster/empty_slot_icon.svg",
    "assets/strategic/roster/linked_slot_icon.svg",
]:
    if not (ROOT / rel).is_file():
        errors.append(f"missing compact equipment icon: {rel}")

if errors:
    print("Stage 5.3 Equip Layout Tightening validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — compact equipment, character, carried inventory and item rails do not overlap.")
print("PASS — Soldier Information and Assignments share one contained left rail with Perception visible.")
print("PASS — Armour, Primary and Secondary use small labels and icon-led controls.")
print("PASS — Belt and Backpack remove redundant controls and centring whitespace.")
print("PASS — the Equip screen uses a neutral background and compact right-rail footer.")
