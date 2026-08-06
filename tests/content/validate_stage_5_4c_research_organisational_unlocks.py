from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def require(path: str, *tokens: str) -> str:
    target = ROOT / path
    assert target.exists(), f"Missing Stage 5.4C file: {path}"
    text = target.read_text(encoding="utf-8")
    for token in tokens:
        assert token in text, f"{path} is missing required token: {token}"
    return text


campaign_state = require(
    "domain/campaign/campaign_state.gd",
    "const CURRENT_SAVE_VERSION: int = 23",
    "research_projects_by_id",
    "research_reservation_ids_by_project_id",
    "research_source_ids",
    "unlocked_shop_contact_ids",
    "unlocked_capability_ids",
    "allocate_research_project_id",
    "has_research_source",
    "has_shop_contact",
    'base["research_projects"]',
    'base["research_source_ids"]',
    'data.get("research_projects", [])',
)

require(
    "domain/economy/research_project_definition.gd",
    "class_name ResearchProjectDefinition",
    "starting_revealed",
    "reveal_source_ids",
    "prerequisite_research_ids",
    "required_facility_definition_id",
    "resource_costs",
    "total_work_required",
    "minimum_workers",
    "maximum_workers",
    "granted_capability_ids",
    "unlocked_contact_ids",
    "unlocked_recipe_ids",
    "unlocked_worker_definition_ids",
)
require(
    "domain/economy/research_project_state.gd",
    "class_name ResearchProjectState",
    "requested_worker_count",
    "completed_work",
    "total_work_required",
    "work_accumulator_minutes",
    "STATUS_PAUSED",
    "STATUS_APPLIED",
)

catalogue = require(
    "application/economy/research_catalogue.gd",
    "class_name ResearchCatalogue",
    'research.organised_study',
    'research.skilled_craftspeople',
    'research.master_craftspeople',
    'research.senior_researchers',
    'research.common_weapon_patterns',
    'research.field_medicine',
    'research.military_supply_contacts',
    'source.research.life_medicine',
    'source.research.life_officer',
    'contact.military_fence',
)
assert catalogue.count("_register(_project(") >= 7, "The curated initial Research set is incomplete."

resolver = require(
    "application/economy/research_assignment_resolver.gd",
    "class_name ResearchAssignmentResolver",
    "WorkforceDefinition.ROLE_RESEARCH",
    "available_ratings.sort()",
    "available_ratings.reverse()",
    "a.priority < b.priority",
    'entry["assigned_count"]',
    'entry["daily_work"]',
    "research_worker_positions_for_level",
    "research_project_slots_for_level",
    "required_facility_definition_id",
)
service = require(
    "application/economy/research_service.gd",
    "class_name ResearchService",
    "MINUTES_PER_WORK",
    "project_entries",
    "preview_start",
    "start_candidate",
    "set_requested_workers_candidate",
    "set_priority_candidate",
    "cancel_candidate",
    "advance_candidate",
    "project_snapshot",
    "reserve_research_candidate",
    "campaign.complete_research",
    "unlocked_shop_contact_ids",
    "unlocked_capability_ids",
    "time_remaining_days",
)
assert "SpinBox" not in service

reservation = require(
    "application/inventory/strategic_reservation_service.gd",
    "reserve_research_candidate",
    "PURPOSE_RESEARCH_INPUT",
    "resource_quantities",
)

workforce_catalogue = require(
    "application/economy/workforce_catalogue.gd",
    'worker.research.basic',
    'worker.research.skilled',
    'worker.research.senior',
    'research.organised_study',
    'research.senior_researchers',
)
workforce_definition = require(
    "domain/economy/workforce_definition.gd",
    'ROLE_MANUFACTURING: StringName = &"manufacturing"',
    'ROLE_RESEARCH: StringName = &"research"',
    "required_research_ids",
    "has_shop_contact",
)
assert "generalist" not in workforce_definition.lower()

shop = require(
    "application/inventory/shop_service.gd",
    "CONTACT_CATALOGUES",
    'contact.military_fence',
    'item.raiders_axe',
    'item.guard_shield',
    'item.sanctuary.capture_spear',
    "has_shop_contact",
)
production = require(
    "application/economy/production_catalogue.gd",
    'production.raiders_axe',
    'production.guard_shield',
    'production.bandage',
    'research.common_weapon_patterns',
    'research.field_medicine',
)

captive = require(
    "application/campaign/captive_service.gd",
    "preview_interrogate",
    "interrogate_captive",
    "preview_interrogate_for_campaign",
    'source.research.life_officer',
    'source.research.life_medicine',
    "This captive has no authored Research or contact knowledge to reveal.",
)
require(
    "domain/campaign/campaign_captive_state.gd",
    "interrogation_completed",
    "interrogation_result_ids",
)

facility_definition = require(
    "domain/stronghold/stronghold_facility_definition.gd",
    "research_project_slots_by_level",
    "research_worker_positions_by_level",
    "research_max_workers_per_project_by_level",
    "research_project_slots_for_level",
    "research_worker_positions_for_level",
    "research_max_workers_for_level",
)
require(
    "infrastructure/content/stronghold/starting_stronghold_factory.gd",
    "research_project_slots_by_level",
    "research_worker_positions_by_level",
    "research_max_workers_per_project_by_level",
)
stronghold = json.loads((ROOT / "content/stronghold/starting_ruin/starting_ruin.json").read_text(encoding="utf-8"))
facilities = {entry["id"]: entry for entry in stronghold["facilities"]}
heart = facilities["facility.fifth_god_heart"]
assert heart["research_project_slots_by_level"] == [2, 3, 4, 5, 6]
assert heart["research_worker_positions_by_level"] == [2, 3, 4, 5, 6]
assert heart["research_max_workers_per_project_by_level"] == [2, 3, 3, 4, 4]

session = require(
    "bootstrap/app/campaign_session.gd",
    "ResearchCatalogueScript",
    "ResearchAssignmentResolverScript",
    "ResearchServiceScript",
    "research_project_completed",
    "func research_entries",
    "func research_projects",
    "func preview_research_project",
    "func begin_research_project",
    "func set_research_workers",
    "func move_research_priority",
    "func cancel_research_project",
    "research_service.advance_candidate(candidate, tick_delta)",
    "func preview_interrogate_captive",
    "func interrogate_captive",
)

shell = require(
    "presentation/campaign/campaign_shell.gd",
    'const SCREEN_RESEARCH: StringName = &"research"',
    '_add_nav_button(row, SCREEN_RESEARCH, "RESEARCH"',
    "ResearchScreenControllerScript",
    "_research_screen_controller.build()",
    'interrogate.text = "INTERROGATE"',
)
research_ui = require(
    "presentation/campaign/controllers/research_screen_controller.gd",
    "class_name ResearchScreenController",
    "func build",
    "func _build_research_project_row",
    '"RESEARCH QUEUE"',
    '"ADD TO RESEARCH QUEUE"',
    'assign_label.text = "ASSIGN"',
    '"WORKERS %d / %d REQUESTED"',
    "func _request_begin_research",
    "func _request_set_research_workers",
    "func _request_move_research_priority",
    "func _request_cancel_research",
)
assert "SpinBox" not in research_ui, "Research must not reintroduce the detached SpinBox timer defect."
assert "Work/day" not in research_ui and "work per day" not in research_ui.lower(), (
    "Ordinary Research rows must show worker count and time, not work-rate maths."
)
assert "Master ×" not in research_ui and "Skilled ×" not in research_ui
assert "commissioned market item" not in shell.lower()

require(
    "tests/integration/stage_5_4c_research_organisational_unlocks_tests.gd",
    "Stage54CResearchOrganisationalUnlocksTests",
    "_test_research_workers_and_monthly_quality_unlock",
    "_test_level_one_heart_runs_one_project_per_position",
    'allocation.get("slots", 0)) == 2',
    'allocation.get("assigned", 0)) == 2',
    "_test_best_research_workers_and_priority",
    "_test_captive_source_shop_and_production_unlocks",
    "_test_permanent_knowledge_pause_and_save_round_trip",
)

print("PASS — Stage 5.4C Research, Research workforce, captive sources and organisational unlocks are integrated.")
