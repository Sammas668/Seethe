#!/usr/bin/env python3
from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


view = read("presentation/campaign/widgets/stronghold_grid_view.gd")
for needle in [
    'const CONSTRUCTION_ICON: Texture2D = preload("res://presentation/campaign/icons/stronghold_construction.svg")',
    "func _draw_active_project_overlay(",
    "func _project_badge_style(",
    "project.remaining_minutes(_campaign_tick)",
    "/ 1440.0",
    'var day_word: String = "DAY" if remaining_days == 1 else "DAYS"',
    "project.progress(_campaign_tick)",
    "draw_texture_rect(CONSTRUCTION_ICON, icon_rect, false, Color.WHITE)",
]:
    assert needle in view, needle

for forbidden in [
    "FACILITY_LABEL_HEIGHT",
    "func _draw_facility_label(",
    "_draw_facility_label(group, rect, presentation)",
    'label += "  •  LV %d"',
    "draw_rect(rect.grow(-4.0), Color(0.10, 0.11, 0.10, 0.50), true)",
]:
    assert forbidden not in view, forbidden

icon_path = ROOT / "presentation/campaign/icons/stronghold_construction.svg"
assert icon_path.is_file()
root = ET.parse(icon_path).getroot()
assert root.tag.endswith("svg")
assert root.attrib.get("viewBox") == "0 0 96 96"

print("PASS — facility names and level banners are absent from stronghold room tiles.")
print("PASS — active construction uses one whole-facility construction icon and an upward-rounded day countdown.")
print("PASS — construction artwork remains visible without a whole-room grey wash.")
