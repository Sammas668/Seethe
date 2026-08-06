#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(rel: str) -> str:
    path = ROOT / rel
    assert path.is_file(), f"Missing {rel}"
    return path.read_text(encoding="utf-8")


stronghold = json.loads(read("content/stronghold/starting_ruin/starting_ruin.json"))
facilities = {entry["id"]: entry for entry in stronghold["facilities"]}
assert facilities["facility.stables"]["starting_facility"] is True
assert facilities["facility.stables"]["buildable"] is False
assert facilities["facility.stables"]["footprint"] == [2, 2]
assert facilities["facility.living_quarters"]["buildable"] is True

shell = read("presentation/campaign/campaign_shell.gd")
production = read("presentation/campaign/controllers/production_screen_controller.gd")
research = read("presentation/campaign/controllers/research_screen_controller.gd")
assert "ProductionScreenControllerScript" in shell
assert "ResearchScreenControllerScript" in shell
assert "_production_screen_controller.build()" in shell
assert "_research_screen_controller.build()" in shell
assert "func _build_production_screen" not in shell
assert "func _build_research_screen" not in shell
assert "class_name ProductionScreenController" in production
assert "class_name ResearchScreenController" in research
assert len(shell.splitlines()) < 11200, "CampaignShell extraction regressed; the monolith grew past the stabilisation boundary."

assert not (ROOT / "tools/patching").exists(), "Obsolete source-rewriting patch scripts still exist."
assert (ROOT / ".gitignore").is_file()

readme = read("README_FIRST.txt")
for token in (
    "STAGE 5.4 STABILISATION",
    "run_stage_5_4_stabilisation_validation.py",
    "run_stage_5_4_stabilisation_tests.gd",
):
    assert token in readme, f"README_FIRST.txt is missing {token}"
for rel in (
    "docs/architecture/STAGE_5_4_STABILISATION_PASS.md",
    "docs/architecture/SOURCE_CHANGE_AND_RELEASE_POLICY.md",
    "STAGE_5_4_STABILISATION_RELEASE_NOTES.txt",
    "STAGE_5_4_STABILISATION_VALIDATION_RESULTS.txt",
):
    assert (ROOT / rel).is_file(), f"README/document trail points to missing {rel}"

instrumentation = read("application/tactical/ai/enemy_turn_instrumentation.gd")
handler = read("application/tactical/ai/enemy_turn_handler.gd")
assert "class_name EnemyTurnInstrumentation" in instrumentation
assert "ENEMY_TURN_INSTRUMENTATION_SCRIPT" in handler
assert "var _activation_timing_samples" not in handler
assert (ROOT / "tests/content/validate_enemy_turn_pipeline.py").is_file()

integration = read("tests/integration/stage_5_4_stabilisation_tests.gd")
assert "_test_starting_stables_are_preplaced_not_buildable" in integration
assert "Stage54BManufacturingPersonnelRepairTests.run_all()" in integration
assert "Stage54CResearchOrganisationalUnlocksTests.run_all()" in integration

print("PASS — Stage 5.4 stabilisation aligns authored content, documentation, controllers, patch policy and enemy instrumentation.")
