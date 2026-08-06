#!/usr/bin/env python3
"""Static acceptance checks for the Stage 5.3 static loadout column and storage-drop update."""
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
slot = read("presentation/campaign/widgets/strategic_equipment_drop_slot.gd")
storage_panel = read("presentation/campaign/widgets/strategic_storage_drop_panel.gd")

# The column keeps its accepted left position, receives the existing shift,
# and now widens exactly 48 px toward Available Equipment.
for name, expected in {
    "EQUIP_CARRIED_LEFT": 0.548,
    "EQUIP_CARRIED_RIGHT": 0.708,
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
        errors.append(f"missing fixed left edge / 48 px right expansion: {token}")

# Both content-sensitive selectors must be isolated behind clipped plain Controls.
loadout_start = shell.find("func _build_compact_loadout_strip(")
loadout_end = shell.find("func _build_equip_character_tabs(", loadout_start)
loadout = shell[loadout_start:loadout_end]
armour_start = shell.find("func _build_armour_selector(")
armour_end = shell.find("func _build_loadout_readiness_strip(", armour_start)
armour = shell[armour_start:armour_end]
for label, chunk in [("loadout", loadout), ("armour", armour)]:
    for token in [
        "var selector_holder := Control.new()",
        "selector_holder.clip_contents = true",
        "selector_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL",
        "selector.fit_to_longest_item = false",
        "selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS",
        "selector_holder.add_child(selector)",
        "selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)",
    ]:
        if token not in chunk:
            errors.append(f"{label} selector missing static-width safeguard: {token}")

# Available Equipment itself is now the return-to-storage drop target.
available_start = shell.find("func _build_equip_available_items(")
available_end = shell.find("func _build_available_equipment_card(", available_start)
available = shell[available_start:available_end]
for token in [
    "var panel = StrategicStorageDropPanelScript.new()",
    "panel.item_drop_requested.connect",
    "_request_roster_unequip(item_id)",
]:
    if token not in available:
        errors.append(f"Available Equipment missing storage-drop integration: {token}")
for forbidden in ["DROP TO STORAGE", "OPEN STORAGE"]:
    if forbidden in available:
        errors.append(f"obsolete storage control remains: {forbidden}")

# Hand slots must be drag sources, while Belt/Backpack already use spatial item controls.
for token in [
    "func configure_drag_source(",
    "func _get_drag_data(",
    '"source_item_id": source_item_id',
]:
    if token not in slot:
        errors.append(f"equipment slot missing drag-source support: {token}")
if "slot.configure_drag_source(" not in shell:
    errors.append("equipped hand slots are not configured as drag sources")

for token in [
    "class_name StrategicStorageDropPanel",
    "source_kind != &\"stronghold_storage\"",
    "item_drop_requested.emit(item_id)",
    "NOTIFICATION_DRAG_BEGIN",
    "NOTIFICATION_DRAG_END",
    "_capture_and_ignore_descendants(self)",
    "get_viewport().gui_is_dragging()",
]:
    if token not in storage_panel:
        errors.append(f"storage panel missing full-surface drop behaviour: {token}")

if errors:
    print("Stage 5.3 static loadout column and storage-drop validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — armour and template names cannot resize the bounded loadout column.")
print("PASS — the complete column keeps its left edge and widens 48 px toward Available Equipment.")
print("PASS — Available Equipment is the full-surface return-to-storage drop target.")
print("PASS — dedicated Drop to Storage and Open Storage controls are absent.")
print("PASS — equipped hand items can be dragged back to storage.")
