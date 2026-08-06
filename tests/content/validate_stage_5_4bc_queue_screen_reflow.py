from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELL_PATH = ROOT / "presentation/campaign/campaign_shell.gd"
RESEARCH_CONTROLLER_PATH = ROOT / "presentation/campaign/controllers/research_screen_controller.gd"
PRODUCTION_CONTROLLER_PATH = ROOT / "presentation/campaign/controllers/production_screen_controller.gd"
STRONGHOLD_PATH = ROOT / "content/stronghold/starting_ruin/starting_ruin.json"


def function_block(source: str, name: str, next_name: str) -> str:
    start_token = f"func {name}"
    end_token = f"func {next_name}"
    assert start_token in source, f"Missing {name}."
    assert end_token in source, f"Missing boundary function {next_name}."
    return source[source.index(start_token):source.index(end_token)]


shell = SHELL_PATH.read_text(encoding="utf-8")
research_source = RESEARCH_CONTROLLER_PATH.read_text(encoding="utf-8")
production_source = PRODUCTION_CONTROLLER_PATH.read_text(encoding="utf-8")
research = function_block(research_source, "build", "_build_research_project_row")
production = function_block(production_source, "build", "_build_production_project_row")
research_row = function_block(research_source, "_build_research_project_row", "_request_begin_research")
production_row = function_block(production_source, "_build_production_project_row", "_request_begin_production")
assert 'ResearchScreenControllerScript' in shell and 'ProductionScreenControllerScript' in shell
assert '_research_screen_controller.build()' in shell and '_production_screen_controller.build()' in shell

for label, block in (("Research", research), ("Production", production)):
    assert "var board := HBoxContainer.new()" in block, f"{label} did not adopt the side-by-side board."
    assert "board.size_flags_vertical = Control.SIZE_EXPAND_FILL" in block
    assert "queue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL" in block
    assert "queue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL" in block
    assert "queue_panel.custom_minimum_size.x = 400" in block
    assert "custom_minimum_size.y = 220" not in block
    assert "custom_minimum_size.y = 230" not in block

assert '"RESEARCH QUEUE"' in research
assert '"PRODUCTION QUEUE"' in production
assert '"ADD TO RESEARCH QUEUE"' in research
assert '"ADD TO PRODUCTION QUEUE"' in production

for label, row in (("Research", research_row), ("Production", production_row)):
    assert 'assign_label.text = "ASSIGN"' in row, f"{label} row has no compact assignment control."
    assert '"WORKERS %d / %d REQUESTED"' in row
    assert 'time_text: String = "PAUSED"' in row
    assert 'cancel.text = "CANCEL"' in row
    assert 'up.text = "▲"' in row and 'down.text = "▼"' in row

stronghold = json.loads(STRONGHOLD_PATH.read_text(encoding="utf-8"))
facilities = {entry["id"]: entry for entry in stronghold["facilities"]}
heart = facilities["facility.fifth_god_heart"]
workshop = facilities["facility.workshop"]
assert heart["research_project_slots_by_level"] == heart["research_worker_positions_by_level"]
assert workshop["production_project_slots_by_level"] == workshop["production_worker_positions_by_level"]
assert heart["research_project_slots_by_level"][0] == 2
assert workshop["production_project_slots_by_level"][0] == 3

print("PASS — Research and Production use full-height three-column queue screens with concurrent assignment capacity.")
