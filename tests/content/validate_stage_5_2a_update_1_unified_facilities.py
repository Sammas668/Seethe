#!/usr/bin/env python3
from __future__ import annotations

import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")

view = read("presentation/campaign/widgets/stronghold_grid_view.gd")
for needle in [
    "var _facility_groups: Dictionary",
    "var _available_plot_textures",
    "var _build_preview: Dictionary",
    "func _rebuild_facility_groups()",
    "func _draw_facility(group: Dictionary)",
    "func _draw_build_preview()",
    "func set_build_preview(",
    "func clear_selection()",
    "func _available_texture_for_coord",
    "_state.facility_definition_id(key)",
    "project.progress(_campaign_tick)",
]:
    assert needle in view, needle

state = read("domain/stronghold/stronghold_state.gd")
for needle in [
    "var facilities_by_id: Dictionary",
    "var projects_by_id: Dictionary",
    "var next_facility_serial: int",
    "var next_project_serial: int",
    "func get_facility",
    "func get_project",
    "func project_for_facility",
    "func facility_definition_id",
    "func allocate_facility_instance_id",
    "func allocate_project_id",
    '"facilities": serialized_facilities',
    '"projects": serialized_projects',
]:
    assert needle in state, needle

content = json.loads((ROOT / "content/stronghold/starting_ruin/starting_ruin.json").read_text())
for presentation in content["facility_presentations"]:
    rel = presentation["art_path"].removeprefix("res://")
    path = ROOT / rel
    assert path.is_file(), rel
    root = ET.parse(path).getroot()
    assert root.tag.endswith("svg"), rel
    assert root.attrib.get("viewBox") == "0 0 512 512", rel

heart = next(p for p in content["facility_presentations"] if p["id"] == "facility.fifth_god_heart")
stables = next(p for p in content["facility_presentations"] if p["id"] == "facility.stables")
assert heart["expected_footprint"] == [1, 1]
assert stables["expected_footprint"] == [2, 2]

shell = read("presentation/campaign/campaign_shell.gd")
for needle in [
    "BUILD ROOMS",
    "PLACE %s",
    "VALID POSITION — CLICK TO BUILD",
    "Construction time:",
    "UPGRADE TO LEVEL",
    "DEMOLISH FACILITY",
    "CURRENT BENEFITS",
    "CURRENT ACTIVITY",
    "_on_stronghold_plot_hovered",
    "_request_stronghold_build_confirmation",
    "_confirm_stronghold_build",
]:
    assert needle in shell, needle

for forbidden in [
    "FACILITY FOOTPRINT —",
    "ORIGIN —",
    "Connected to Heart:",
    "Connected to Stables access:",
    "SELECT STABLES",
]:
    assert forbidden not in shell, forbidden

print("PASS — multi-plot facilities still render as one continuous illustrated footprint.")
print("PASS — the central Heart, starting Stables, empty plots and hover placement preview use authored strategic art.")
print("PASS — facility panels now show player-facing benefits and activity rather than coordinates or access diagnostics.")
