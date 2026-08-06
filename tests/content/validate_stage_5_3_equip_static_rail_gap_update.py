#!/usr/bin/env python3
"""Static checks for the Stage 5.3 fixed left rail and carried-column gap update."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELL_PATH = ROOT / "presentation/campaign/campaign_shell.gd"
errors: list[str] = []

if not SHELL_PATH.is_file():
    errors.append("missing campaign_shell.gd")
    shell = ""
else:
    shell = SHELL_PATH.read_text(encoding="utf-8")

for name, expected in {
    "EQUIP_LEFT_RAIL_LEFT": 0.008,
    "EQUIP_LEFT_RAIL_RIGHT": 0.164,
    "EQUIP_CARRIED_SHIFT_X": -24.0,
    "EQUIP_CARRIED_EXPAND_RIGHT_X": 48.0,
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
        errors.append(f"missing carried-column geometry rule: {token}")

left_start = shell.find("func _build_equip_left_rail(")
left_end = shell.find("func _build_equip_character_info_panel(", left_start)
left = shell[left_start:left_end]
for token in [
    "var rail := Control.new()",
    "rail.clip_contents = false",
    "rail.custom_minimum_size.x = 0",
    "rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL",
    "information.anchor_right = 1.0",
    "assignments.anchor_right = 1.30",
]:
    if token not in left:
        errors.append(f"left rail missing authored panel-width rule: {token}")

assign_start = shell.find("func _build_equip_assignment_panel(")
assign_end = shell.find("func _equip_group_includes_character(", assign_start)
assign = shell[assign_start:assign_end]
for token in [
    "panel.custom_minimum_size.x = 0",
    "column.custom_minimum_size.x = 0",
    "var base_selector_holder := Control.new()",
    "base_selector_holder.clip_contents = true",
    "base_selector.fit_to_longest_item = false",
    "base_selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS",
    "base_selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)",
    "var group_selector_holder := Control.new()",
    "group_selector_holder.clip_contents = true",
    "group_selector.fit_to_longest_item = false",
    "group_selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS",
    "group_selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)",
    "scroll.custom_minimum_size.x = 0",
    "list.custom_minimum_size.x = 0",
    "button.clip_text = true",
    "button.custom_minimum_size = Vector2(0, 30)",
]:
    if token not in assign:
        errors.append(f"Assignments missing static-width safeguard: {token}")

if errors:
    print("Stage 5.3 fixed left rail and carried-column gap validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — Soldier Information retains the Ready Troops width and Assignments uses its authored 130% width.")
print("PASS — long assignment labels truncate inside clipped fixed-width controls.")
print("PASS — the loadout column widens exactly 48 px toward Available Equipment.")
