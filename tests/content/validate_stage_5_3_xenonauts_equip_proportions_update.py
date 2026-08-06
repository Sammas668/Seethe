#!/usr/bin/env python3
"""Static acceptance checks for the Xenonauts-proportioned Equip Troops update."""
from __future__ import annotations

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
icon = ROOT / "assets/strategic/roster/loadout_template_icon.svg"

required_proportions = [
    "const EQUIP_LEFT_RAIL_LEFT: float = 0.008",
    "const EQUIP_LEFT_RAIL_RIGHT: float = 0.216",
    "const EQUIP_EQUIPPED_LEFT: float = 0.230",
    "const EQUIP_EQUIPPED_RIGHT: float = 0.302",
    "const EQUIP_CHARACTER_LEFT: float = 0.310",
    "const EQUIP_CHARACTER_RIGHT: float = 0.560",
    "const EQUIP_CARRIED_LEFT: float = 0.570",
    "const EQUIP_CARRIED_RIGHT: float = 0.770",
    "const EQUIP_AVAILABLE_LEFT: float = 0.785",
    "const EQUIP_AVAILABLE_RIGHT: float = 0.992",
    "const EQUIP_CONTENT_BOTTOM: float = 0.850",
    "const EQUIP_CHARACTER_TABS_TOP: float = 0.865",
]
for token in required_proportions:
    if token not in shell:
        errors.append(f"Equip Troops proportion missing or changed: {token}")

required_shell_tokens = [
    "func _build_xenonauts_loadout_composition(",
    "func _place_equip_region(",
    "func _build_equip_character_info_panel(",
    "func _build_equip_assignment_panel(",
    "func _build_equip_left_rail(",
    'base_label.text = "BASE"',
    'group_label.text = "SQUAD"',
    '"CURRENT MISSION SQUAD"',
    "func _build_equip_equipped_stack(",
    "func _build_equip_character_figure(",
    "func _build_equip_carried_panel(",
    "func _build_compact_loadout_strip(",
    'icon.mouse_filter = Control.MOUSE_FILTER_IGNORE',
    'save.text = "SAVE"',
    'load_button.text = "LOAD"',
    "func _build_equip_character_tabs(",
    'panel.custom_minimum_size.x = 0',
    'scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED',
    "selector.fit_to_longest_item = false",
    "figure.z_index = 0",
    "equipped.z_index = 2",
    "carried.z_index = 2",
    "available.z_index = 3",
    "func _identity_portrait_texture(",
]
for token in required_shell_tokens:
    if token not in shell:
        errors.append(f"campaign_shell.gd missing proportion-layout token: {token}")

if "main.add_child(_build_equip_character_sidebar" in shell:
    errors.append("Equip Troops still uses the old equal-column composition")
if not icon.is_file():
    errors.append("missing passive loadout-template icon")
else:
    icon_text = icon.read_text(encoding="utf-8")
    if "<svg" not in icon_text or "#c0a35e" not in icon_text:
        errors.append("loadout-template icon is not the authored dark-fantasy SVG")

if errors:
    print("Stage 5.3 Xenonauts Equip Proportions validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — Equip Troops uses stable Xenonauts-like percentage regions instead of competing fixed columns.")
print("PASS — soldier information and assignment selectors occupy the left rail.")
print("PASS — compact equipment, full-body figure, enlarged carried inventory and available items use non-overlapping regions.")
print("PASS — loadout controls are a passive icon, dropdown, Save and Load controls.")
print("PASS — the far-right equipment list clips and scrolls inside its proportional rail.")
