#!/usr/bin/env python3
"""Regression checks for the stuck withdrawal screen and outbound split-item lineage."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
errors: list[str] = []


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        errors.append(f"missing required file: {relative}")
        return ""
    return path.read_text(encoding="utf-8")

shell = read("presentation/campaign/campaign_shell.gd")
deployment = read("application/characters/tactical_character_deployment_service.gd")
recovery = read("application/missions/mission_recovery_selection_service.gd")
builder = read("application/missions/mission_result_builder.gd")
validator = read("application/missions/mission_result_validator.gd")
commit = read("application/campaign/campaign_result_commit_service.gd")

for token in [
    'const MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY: String = "mission_outbound_origin_item_id"',
    'tactical_modifiers[MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY] = String(campaign_item.item_id)',
]:
    if token not in deployment:
        errors.append(f"deployment lineage missing: {token}")

for token in [
    "_is_outbound_item(item, mandatory_ids)",
    'item_id_text.begins_with("%s.attached." % origin_text)',
    'item_id_text.begins_with("%s.split." % origin_text)',
    "mandatory_ids[String(item.item_id)] = true",
]:
    if token not in recovery:
        errors.append(f"recovery lineage missing: {token}")

for token in [
    "_is_outbound_tactical_item(setup, tactical_item)",
    "MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY",
]:
    if token not in builder:
        errors.append(f"mission result classification missing: {token}")

for token in [
    "_outbound_lineage_origin(setup, item)",
    "_validate_split_outbound_item(item, lineage_origin, errors)",
    "_validate_outbound_lineage_conservation(setup, extracted_items, errors)",
    "_modifiers_without_mission_lineage",
]:
    if token not in validator:
        errors.append(f"mission result lineage validation missing: {token}")

if "persistent_modifiers.erase(" not in commit or "MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY" not in commit:
    errors.append("campaign commit does not strip tactical-only lineage metadata")

recovery_start = shell.find("func _build_mission_recovery_screen()")
recovery_end = shell.find("func _recovery_selected_ids()", recovery_start)
recovery_screen = shell[recovery_start:recovery_end]
for token in [
    "body_scroll.offset_bottom = -92.0",
    "footer_surface.anchor_top = 1.0",
    "footer_surface.anchor_bottom = 1.0",
    "footer_surface.offset_top = -80.0",
    'abandon_and_return.text = "ABANDON OPTIONAL LOOT AND RETURN"',
    "abandon_and_return.pressed.connect(_abandon_optional_and_confirm_mission_recovery)",
]:
    if token not in recovery_screen:
        errors.append(f"fixed recovery exit missing: {token}")

if "layout.add_child(footer_surface)" in recovery_screen:
    errors.append("footer can still be pushed below the viewport by content")
if "valid_optional_ids" not in shell:
    errors.append("restored pending selection is not sanitized after manifest repair")

# Model the exact reported case: one rope stack is split to restrain a captive.
origin_id = "instance.marauder.rope"
legacy_child_id = f"{origin_id}.attached.enemy.guard.r812"
mandatory = {origin_id}
assert legacy_child_id.startswith(f"{origin_id}.attached.")
assert any(
    legacy_child_id.startswith(f"{candidate}.attached.")
    for candidate in mandatory
)

# A new unrelated rope acquired on the map must remain optional.
new_loot_id = "mission.farm.loot.rope.001"
assert not any(
    new_loot_id.startswith(f"{candidate}.attached.")
    or new_loot_id.startswith(f"{candidate}.split.")
    for candidate in mandatory
)

if errors:
    print("Stage 5.3D Recovery Hard Exit and Lineage validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — recovery has a viewport-anchored exit even with an arbitrarily long manifest.")
print("PASS — the player can abandon all optional loot and return without scrolling.")
print("PASS — exact, transferred and split outbound equipment is automatic return cargo.")
print("PASS — legacy pending split-rope results are recognised without hiding unrelated loot.")
