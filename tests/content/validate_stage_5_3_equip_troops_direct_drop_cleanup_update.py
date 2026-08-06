#!/usr/bin/env python3
"""Static acceptance checks for direct-drop hand slots and Available Equipment cleanup."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "presentation/campaign/campaign_shell.gd"
errors: list[str] = []

if not SHELL.is_file():
    errors.append("missing campaign_shell.gd")
    shell = ""
else:
    shell = SHELL.read_text(encoding="utf-8")

slot_start = shell.find("func _build_visual_equipment_slot(")
slot_end = shell.find("func _build_visual_inventory_slot(", slot_start)
slot = shell[slot_start:slot_end]
for token in [
    "slot.toggle_mode = false",
    "slot.focus_mode = Control.FOCUS_NONE",
    "slot.item_drop_requested.connect",
    "slot.configure_drag_source(",
]:
    if token not in slot:
        errors.append(f"hand slot missing direct-drop behaviour: {token}")
for forbidden in [
    "slot.button_pressed = slot_id == _roster_selected_slot",
    "_roster_selected_slot = slot_id",
    "slot.pressed.connect",
]:
    if forbidden in slot:
        errors.append(f"obsolete hand-slot selection remains: {forbidden}")

available_start = shell.find("func _build_equip_available_items(")
available_end = shell.find("func _build_available_equipment_card(", available_start)
available = shell[available_start:available_end]
for forbidden in [
    "DESTINATION —",
    "var slot_label := Label.new()",
    "currently selected destination",
    "_preferred_destination_for_definition(definition)",
]:
    if forbidden in available:
        errors.append(f"obsolete Available Equipment destination UI remains: {forbidden}")
for token in [
    "Show only items accepted by at least one hand, Belt or Backpack drop target.",
    "_preview_available_equipment_destination(",
    "panel.item_drop_requested.connect",
]:
    if token not in available:
        errors.append(f"Available Equipment missing drag-first compatibility behaviour: {token}")

helper_start = shell.find("func _available_equipment_destinations(")
helper_end = shell.find("func _equipment_comparison_text(", helper_start)
helper = shell[helper_start:helper_end]
for token in [
    "CampaignItemLocationState.CONTAINER_PRIMARY_HAND",
    "CampaignItemLocationState.CONTAINER_SECONDARY_HAND",
    "CampaignItemLocationState.CONTAINER_BELT",
    "CampaignItemLocationState.CONTAINER_BACKPACK",
    "func _preview_available_equipment_destination(",
    "if preview.success:",
]:
    if token not in helper:
        errors.append(f"generic compatibility helper missing: {token}")
if "_roster_selected_slot" in helper:
    errors.append("generic Available Equipment compatibility still depends on a selected destination")

if errors:
    print("Stage 5.3 direct-drop cleanup validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — Primary and Secondary remain direct drag targets without selectable state.")
print("PASS — Available Equipment no longer shows or depends on a destination selection.")
print("PASS — Compatible filtering accepts an item when any real loadout drop target accepts it.")
