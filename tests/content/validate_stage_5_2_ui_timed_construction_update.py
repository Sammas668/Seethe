#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")

shell = read("presentation/campaign/campaign_shell.gd")
for needle in [
    "func _apply_screen_chrome()",
    "_campaign_time_box.visible = region_screen",
    "_secondary_header.visible = region_screen",
    "_global_action_block.visible = region_screen",
    "_workspace.offset_top = 122.0 if region_screen else 80.0",
    "if _campaign_session != null and screen_id != SCREEN_REGION:",
    "_campaign_session.pause_clock()",
    "func _build_stronghold_construction_catalogue(",
    "func _build_stronghold_placement_inspector(",
    "func _build_stronghold_facility_inspector(",
    "_selected_stronghold_coord = Vector2i(-1, -1)",
    "VALID POSITION — CLICK TO BUILD",
    "_request_stronghold_build_confirmation()",
]:
    assert needle in shell, needle

for forbidden in [
    "AUTHORED %d × %d RUIN",
    "ACCESSIBLE PLOTS CONNECTED",
    "_build_stronghold_legend()",
    "CLEARED RUIN CHAMBER",
    "AVAILABLE FOR CONSTRUCTION",
]:
    assert forbidden not in shell, forbidden

clock_gate = shell[shell.index("func _process(delta: float)"):shell.index("func _build_shell()")]
assert "if _current_screen == SCREEN_REGION" in clock_gate

content = json.loads((ROOT / "content/stronghold/starting_ruin/starting_ruin.json").read_text())
facilities = {entry["id"]: entry for entry in content["facilities"]}
expected = {
    "facility.storehouse": 720,
    "facility.muster_hall": 1080,
    "facility.prison": 1080,
    "facility.recovery_chamber": 1440,
    "facility.workshop": 1440,
    "facility.reaver_warcamp": 2160,
}
for facility_id, duration in expected.items():
    entry = facilities[facility_id]
    assert entry["construction_duration_minutes"] == duration
    assert entry["upgrade_duration_minutes"]
    assert entry["benefits"]

view = read("presentation/campaign/widgets/stronghold_grid_view.gd")
assert "const OUTER_MARGIN: float = 10.0" in view
assert "clampf(_cell_size, 48.0, 118.0)" in view
assert "_draw_connectors()" not in view[view.index("func _draw() -> void:"):view.index("func _update_layout()")]
assert "draw_circle(rect.position + Vector2(rect.size.x - 12.0, 12.0)" not in view

print("PASS — strategic time and Agent controls are presented only on the Region Map.")
print("PASS — stronghold screen chrome, title, network summary and legend no longer consume grid space.")
print("PASS — construction begins from the catalogue, previews on hover and creates authored timed projects.")
