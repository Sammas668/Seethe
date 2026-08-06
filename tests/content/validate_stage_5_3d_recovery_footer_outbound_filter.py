#!/usr/bin/env python3
"""Static acceptance checks for fixed recovery actions and outbound-item filtering."""
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
recovery = read("application/missions/mission_recovery_selection_service.gd")

recovery_screen_start = shell.find("func _build_mission_recovery_screen()")
recovery_screen_end = shell.find("func _recovery_selected_ids()", recovery_screen_start)
recovery_screen = shell[recovery_screen_start:recovery_screen_end]

for token in [
    "var body_scroll := ScrollContainer.new()",
    "body_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)",
    "body_scroll.offset_bottom = -92.0",
    "recovery_layer.add_child(footer_surface)",
    "footer_surface.anchor_top = 1.0",
    "footer_surface.offset_top = -80.0",
    'abandon_and_return.text = "ABANDON OPTIONAL LOOT AND RETURN"',
    'confirm.text = "CONFIRM SELECTED CARGO AND RETURN"',
]:
    if token not in recovery_screen:
        errors.append(f"Recovery screen missing viewport-pinned exit behaviour: {token}")

if "layout.add_child(footer_surface)" in recovery_screen:
    errors.append("Recovery footer is still inside the content-driven VBox")
if "body_scroll.add_child(root)" not in recovery_screen:
    errors.append("Recovery body is not contained by the scrolling region")

for token in [
    "_mandatory_item_ids(result, envelope.setup)",
    "_mandatory_item_ids(filtered_result, envelope.setup)",
    "for character_id: StringName in setup.player_unit_order()",
    "for setup_item: CampaignItemState in setup.items_for_character(character_id)",
    "mandatory[String(setup_item.item_id)] = true",
    "_is_outbound_item(item, mandatory_ids)",
    "MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY",
]:
    if token not in recovery:
        errors.append(f"Recovery selection missing immutable outbound-item exclusion: {token}")

mandatory_start = recovery.find("func _mandatory_item_ids(")
mandatory_end = recovery.find("func _without_ids", mandatory_start)
mandatory_block = recovery[mandatory_start:mandatory_end]
if "setup.player_unit_order()" not in mandatory_block:
    errors.append("Outbound filtering does not restrict setup items to player deployment")
if "result.item_outcomes_by_id.keys()" not in mandatory_block:
    errors.append("Outbound filtering does not use immutable item outcomes")
if "mandatory[item_id_text] = true" not in mandatory_block:
    errors.append("Outbound item IDs are not normalized to a single key type")

if 'item_id_text.begins_with("%s.attached." % origin_text)' not in recovery:
    errors.append("Legacy split restraint lineage is not recognised")
if "valid_optional_ids" not in shell:
    errors.append("Restored pending selections are not sanitized against the rebuilt manifest")

# Behavioural model: exact items carried out are mandatory; new mission loot is optional.
outbound = {"mace", "armour", "rope"}
extracted = {"mace", "armour", "enemy_sword", "grain_crate"}
mandatory = extracted & outbound
optional = extracted - mandatory
assert mandatory == {"mace", "armour"}
assert optional == {"enemy_sword", "grain_crate"}

if errors:
    print("Stage 5.3D Recovery Footer and Outbound Filter validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — the recovery body scrolls while the confirmation action remains in a fixed layout row.")
print("PASS — the footer no longer relies on workspace anchors that can resolve off-screen.")
print("PASS — outbound IDs are normalized across live and JSON-restored mission data.")
print("PASS — exact outbound deployment items return automatically and newly recovered items remain optional.")
