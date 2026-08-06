#!/usr/bin/env python3
"""Static acceptance checks for the Stage 5.3 Equip Troops Unified Loadout Column Update."""
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
    "EQUIP_LEFT_RAIL_RIGHT": 0.164,
    "EQUIP_CHARACTER_LEFT": 0.175,
    "EQUIP_CHARACTER_RIGHT": 0.565,
    "EQUIP_CARRIED_BOTTOM": 0.850,
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

for name in ["EQUIP_CARRIED_LEFT", "EQUIP_CARRIED_RIGHT"]:
    match = re.search(rf"const {name}: float = ([0-9.]+)", shell)
    if match is None:
        errors.append(f"missing layout constant: {name}")
    else:
        values[name] = float(match.group(1))

carried_width = values.get("EQUIP_CARRIED_RIGHT", 0.0) - values.get("EQUIP_CARRIED_LEFT", 0.0)
if abs(carried_width - 0.160) > 0.0001:
    errors.append(f"unified loadout width changed: expected 0.160, got {carried_width:.3f}")
if values.get("EQUIP_CARRIED_RIGHT", 1.0) >= values.get("EQUIP_AVAILABLE_LEFT", 0.0):
    errors.append("unified loadout column overlaps Available Equipment")

composition_start = shell.find("func _build_xenonauts_loadout_composition(")
composition_end = shell.find("func _place_equip_region(", composition_start)
composition = shell[composition_start:composition_end]
if "var equipped := _build_equip_equipped_stack" in composition:
    errors.append("the obsolete separate equipment strip is still rendered beside the portrait")
if "EQUIP_CHARACTER_LEFT" not in composition or "EQUIP_CARRIED_BOTTOM" not in composition:
    errors.append("composition does not use the expanded portrait and full-height loadout regions")

carried_start = shell.find("func _build_equip_carried_panel(")
carried_end = shell.find("func _build_compact_loadout_strip(", carried_start)
carried = shell[carried_start:carried_end]
required_carried_order = [
    "_build_compact_loadout_strip",
    "CONTAINER_BELT",
    "CONTAINER_BACKPACK",
    "_build_equip_equipped_stack",
    "_build_loadout_readiness_strip",
]
positions = [carried.find(token) for token in required_carried_order]
if any(pos < 0 for pos in positions):
    errors.append("unified loadout column is missing a required section")
elif positions != sorted(positions):
    errors.append("loadout column order is not template, Belt, Backpack, equipped footer, readiness")
if "PanelContainer.new()" in carried:
    errors.append("the carried column still draws one tall empty backing panel")

footer_start = shell.find("func _build_equip_equipped_stack(")
footer_end = shell.find("func _build_equip_character_figure(", footer_start)
footer = shell[footer_start:footer_end]
for token in [
    "hands := HBoxContainer.new()",
    'CONTAINER_PRIMARY_HAND, "PRIMARY"',
    'CONTAINER_SECONDARY_HAND, "SECONDARY"',
    'carry_heading.text = "CARRY WEIGHT"',
]:
    if token not in footer:
        errors.append(f"compact equipped footer missing: {token}")
if footer.find("_build_armour_selector") > footer.find("hands := HBoxContainer.new()"):
    errors.append("Armour is not above the side-by-side hand slots")
if footer.find("hands := HBoxContainer.new()") > footer.find('carry_heading.text = "CARRY WEIGHT"'):
    errors.append("Carry Weight is not below Primary and Secondary")

strip_start = shell.find("func _build_compact_loadout_strip(")
strip_end = shell.find("func _build_equip_character_tabs()", strip_start)
strip = shell[strip_start:strip_end]
for token in [
    "selector.fit_to_longest_item = false",
    "selector.custom_minimum_size = Vector2(0, 24)",
    "selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS",
    "save.custom_minimum_size = Vector2(38, 24)",
    "load_button.custom_minimum_size = Vector2(38, 24)",
    "row.clip_contents = true",
]:
    if token not in strip:
        errors.append(f"compact loadout selector missing width safeguard: {token}")

slot_start = shell.find("func _build_visual_equipment_slot(")
slot_end = shell.find("func _build_visual_inventory_slot(", slot_start)
slot = shell[slot_start:slot_end]
for token in [
    "var icon_texture: Texture2D = null",
    "var icon_path: String = _item_icon_path(definition)",
    "slot.configure(slot_id, \"\")",
    "item_drop_requested.connect",
]:
    if token not in slot:
        errors.append(f"hand slot is not an image-only drag target: {token}")

card_start = shell.find("func _build_available_equipment_card(")
card_end = shell.find("func _category_for_slot(", card_start)
card = shell[card_start:card_end]
for forbidden in ['equip.text = "PLACE"', "Double-click alternative"]:
    if forbidden in card:
        errors.append(f"Available Equipment still exposes click-to-equip UI: {forbidden}")
if "_get_drag_data" not in read("presentation/tactical/spatial_inventory_item_control.gd"):
    errors.append("available item controls no longer expose drag data")

if errors:
    print("Stage 5.3 Equip Troops Unified Loadout Column validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — screen reads soldier information, full-body portrait, unified loadout, then available equipment.")
print("PASS — loadout selector truncates inside the fixed carried-column width.")
print("PASS — Armour, Primary, Secondary and Carry Weight use the space beneath Backpack.")
print("PASS — Primary and Secondary are image-only drag-and-drop targets.")
print("PASS — Available Equipment remains drag-first and does not overlap the loadout column.")
