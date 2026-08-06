#!/usr/bin/env python3
"""Static checks for the Stage 5.3 assignment and carried-grid expansion update."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "presentation/campaign/campaign_shell.gd"
errors: list[str] = []

if not SHELL.is_file():
    errors.append("missing campaign_shell.gd")
    shell = ""
else:
    shell = SHELL.read_text(encoding="utf-8")

for name, expected in {
    "EQUIP_LEFT_RAIL_LEFT": 0.008,
    "EQUIP_LEFT_RAIL_RIGHT": 0.164,
    "EQUIP_CARRIED_LEFT": 0.548,
    "EQUIP_CARRIED_RIGHT": 0.708,
    "EQUIP_CARRIED_SHIFT_X": -24.0,
    "EQUIP_CARRIED_EXPAND_RIGHT_X": 48.0,
    "EQUIP_AVAILABLE_LEFT": 0.750,
}.items():
    match = re.search(rf"const {name}: float = (-?[0-9.]+)", shell)
    if match is None:
        errors.append(f"missing layout constant: {name}")
    elif abs(float(match.group(1)) - expected) > 0.0001:
        errors.append(f"{name} expected {expected}, got {match.group(1)}")

for token in [
    "carried.offset_left += EQUIP_CARRIED_SHIFT_X",
    "carried.offset_right += EQUIP_CARRIED_SHIFT_X + EQUIP_CARRIED_EXPAND_RIGHT_X",
]:
    if token not in shell:
        errors.append(f"missing fixed-left carried-column expansion: {token}")

left_start = shell.find("func _build_equip_left_rail(")
left_end = shell.find("func _build_equip_character_info_panel(", left_start)
left = shell[left_start:left_end]
for token in [
    "var rail := Control.new()",
    "rail.clip_contents = false",
    "information.anchor_right = 1.0",
    "information.anchor_bottom = 0.54",
    "information.offset_bottom = -6.0",
    "assignments.anchor_left = 0.0",
    "assignments.anchor_right = 1.30",
    "assignments.anchor_top = 0.54",
    "assignments.offset_top = 6.0",
]:
    if token not in left:
        errors.append(f"left rail missing independent panel geometry: {token}")

assign_start = shell.find("func _build_equip_assignment_panel(")
assign_end = shell.find("func _equip_group_includes_character(", assign_start)
assign = shell[assign_start:assign_end]
for token in [
    "base_selector.fit_to_longest_item = false",
    "base_selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS",
    "group_selector.fit_to_longest_item = false",
    "group_selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS",
    "button.clip_text = true",
]:
    if token not in assign:
        errors.append(f"Assignments lost static content safeguards: {token}")

cell_start = shell.find("func _strategic_inventory_cell_size()")
cell_end = shell.find("func _build_level_up_content(", cell_start)
cell = shell[cell_start:cell_end]
for token in [
    "canvas_width * (EQUIP_CARRIED_RIGHT - EQUIP_CARRIED_LEFT)",
    "+ EQUIP_CARRIED_EXPAND_RIGHT_X",
    "var usable_grid_width: float = maxf(190.0, carried_width - 12.0)",
    "return clampf(floorf(usable_grid_width / 10.0), 19.0, 36.0)",
]:
    if token not in cell:
        errors.append(f"inventory grids missing bounded diagonal expansion: {token}")

inventory_start = shell.find("func _build_visual_inventory_slot(")
inventory_end = shell.find("func _strategic_inventory_cell_size()", inventory_start)
inventory = shell[inventory_start:inventory_end]
for token in [
    "var cell_size: float = _strategic_inventory_cell_size()",
    "grid.configure(container_id, dimensions.x, dimensions.y, Vector2(cell_size, cell_size))",
    "grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN",
]:
    if token not in inventory:
        errors.append(f"inventory slot lost fixed-column square-grid rule: {token}")

if errors:
    print("Stage 5.3 assignment and carried-grid expansion validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — the carried loadout column expands 48 px right while its left edge stays fixed.")
print("PASS — Soldier Information keeps its accepted width and Assignments is 30% wider.")
print("PASS — Belt and Backpack cells expand diagonally to the maximum bounded square size.")
