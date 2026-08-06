from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def require(path: str, *tokens: str) -> str:
    target = ROOT / path
    assert target.exists(), f"Missing Stage 5.4B file: {path}"
    text = target.read_text(encoding="utf-8")
    for token in tokens:
        assert token in text, f"{path} is missing required token: {token}"
    return text


campaign_state = require(
    "domain/campaign/campaign_state.gd",
    "const CURRENT_SAVE_VERSION: int = 23",
    "workforce_counts_by_definition_id",
    "workforce_offers_by_id",
    "production_projects_by_id",
    "allocate_production_project_id",
    "allocate_production_item_id",
    'base["workforce_counts"]',
    'base["production_projects"]',
    'data.get("workforce_counts", {})',
    'data.get("production_projects", [])',
)

require(
    "domain/economy/workforce_definition.gd",
    "class_name WorkforceDefinition",
    'ROLE_MANUFACTURING: StringName = &"manufacturing"',
    'ROLE_RESEARCH: StringName = &"research"',
    "work_rating",
    "personnel_capacity_cost",
    "required_research_ids",
)
require(
    "domain/economy/workforce_offer_state.gd",
    "class_name WorkforceOfferState",
    "worker_definition_id",
    "market_revision",
)
require(
    "domain/economy/production_recipe_definition.gd",
    "class_name ProductionRecipeDefinition",
    "TYPE_MANUFACTURE_ITEM",
    "TYPE_REPAIR_ITEM",
    "resource_costs",
    "total_work_required",
    "minimum_workers",
    "maximum_workers",
    "restore_to_full_condition",
)
require(
    "domain/economy/production_project_state.gd",
    "class_name ProductionProjectState",
    "requested_worker_count",
    "assigned_worker_count",
    "completed_work",
    "total_work_required",
    "work_accumulator_minutes",
    "reservation_id",
    "target_item_id",
    "STATUS_PAUSED",
    "STATUS_APPLIED",
)

personnel = require(
    "application/economy/personnel_capacity_service.gd",
    "class_name PersonnelCapacityService",
    "campaign.roster_capacity",
    "personnel_capacity_for_level",
    "manufacturing_workers",
    "research_workers",
    "campaign.protagonist_character_id",
)
workforce_catalogue = require(
    "application/economy/workforce_catalogue.gd",
    'worker.manufacturing.basic',
    'worker.manufacturing.skilled',
    'worker.manufacturing.master',
    'worker.research.basic',
    'research.skilled_craftspeople',
    'research.master_craftspeople',
)
workforce_service = require(
    "application/economy/workforce_service.gd",
    "CAMPAIGN_MONTH_TICKS",
    "refresh_market_if_due_candidate",
    "hire_candidate",
    "dismiss_candidate",
    "Personnel capacity is full.",
)
resolver = require(
    "application/economy/workforce_assignment_resolver.gd",
    "available_ratings.sort()",
    "available_ratings.reverse()",
    "a.priority < b.priority",
    "project.requested_worker_count",
    'entry["assigned_count"]',
    'entry["daily_work"]',
    "production_worker_positions_for_level",
    "production_project_slots_for_level",
    'result["slots"] = project_slots',
)
# Ordinary project presentation must not expose the grade composition even
# though the resolver retains it for deterministic calculation/debugging.
assert 'entry["ratings"] = ratings' in resolver

production_catalogue = require(
    "application/economy/production_catalogue.gd",
    'production.mace',
    'production.rope',
    'production.manacles',
    'repair.mace',
    'repair.rope',
    'repair.manacles',
    "repair_recipe_for_item",
)
production = require(
    "application/economy/production_service.gd",
    "MINUTES_PER_WORK",
    "preview_start",
    "start_candidate",
    "set_requested_workers_candidate",
    "set_priority_candidate",
    "cancel_candidate",
    "advance_candidate",
    "project_snapshot",
    "reserved_output_storage_space",
    "reserve_production_candidate",
    "campaign.allocate_production_item_id()",
    "CampaignItemLocationState.stronghold_storage()",
    "repair_item.condition = (",
    "output_item_ids.append(repair_item.item_id)",
)
# Repairs restore the same state object; they must not allocate a new item ID.
repair_branch = production.split("if recipe_value.project_type == ProductionRecipeDefinition.TYPE_REPAIR_ITEM:", 2)[-1].split("else:", 1)[0]
assert "allocate_production_item_id" not in repair_branch, "Repair must not replace the persistent item instance."

reservation_state = require(
    "domain/campaign/strategic_reservation_state.gd",
    "resource_quantities",
    "output_storage_space",
    '"resource_quantities"',
    '"output_storage_space"',
)
require(
    "application/inventory/strategic_reservation_service.gd",
    "available_resource_amount",
    "reserved_output_storage_space",
    "reserve_production_candidate",
    "resource_quantities",
    "output_storage_space",
)

facility_definition = require(
    "domain/stronghold/stronghold_facility_definition.gd",
    "personnel_capacity_by_level",
    "production_project_slots_by_level",
    "production_worker_positions_by_level",
    "production_max_workers_per_project_by_level",
    "personnel_capacity_for_level",
    "production_project_slots_for_level",
    "production_worker_positions_for_level",
    "production_max_workers_for_level",
)
require(
    "infrastructure/content/stronghold/starting_stronghold_factory.gd",
    "personnel_capacity_by_level",
    "production_project_slots_by_level",
    "production_worker_positions_by_level",
    "production_max_workers_per_project_by_level",
)
stronghold_data = json.loads((ROOT / "content/stronghold/starting_ruin/starting_ruin.json").read_text(encoding="utf-8"))
facilities = {entry["id"]: entry for entry in stronghold_data["facilities"]}
assert "facility.living_quarters" in facilities, "Living Quarters facility is missing."
assert facilities["facility.living_quarters"]["personnel_capacity_by_level"] == [8, 14, 22]
workshop = facilities["facility.workshop"]
assert workshop["production_project_slots_by_level"] == [3, 6, 10]
assert workshop["production_worker_positions_by_level"] == [3, 6, 10]
assert workshop["production_max_workers_per_project_by_level"] == [3, 4, 6]
assert (ROOT / "assets/strategic/stronghold/facilities/living_quarters.svg").exists()

session = require(
    "bootstrap/app/campaign_session.gd",
    "PersonnelCapacityServiceScript",
    "WorkforceCatalogueScript",
    "WorkforceServiceScript",
    "ProductionCatalogueScript",
    "WorkforceAssignmentResolverScript",
    "ProductionServiceScript",
    "production_project_completed",
    "func personnel_capacity_snapshot",
    "func workforce_market",
    "func hire_workforce",
    "func dismiss_workforce",
    "func production_available_recipes",
    "func production_projects",
    "func begin_production_project",
    "func set_production_workers",
    "func move_production_priority",
    "func cancel_production_project",
    "func repair_recipe_for_item",
    "production_service.advance_candidate(candidate, tick_delta)",
)

shell = require(
    "presentation/campaign/campaign_shell.gd",
    'const SCREEN_PRODUCTION: StringName = &"production"',
    'const ROSTER_MODE_WORKFORCE: StringName = &"workforce"',
    '_add_nav_button(row, SCREEN_PRODUCTION, "PRODUCTION"',
    "func _build_roster_workforce_view",
    "ProductionScreenControllerScript",
    "_production_screen_controller.build()",
    'repair.text = "REPAIR"',
    "func _request_item_repair",
)
production_ui = require(
    "presentation/campaign/controllers/production_screen_controller.gd",
    "class_name ProductionScreenController",
    "func build",
    "func _build_production_project_row",
    '"PRODUCTION QUEUE"',
    '"ADD TO PRODUCTION QUEUE"',
    'assign_label.text = "ASSIGN"',
    '"WORKERS %d / %d REQUESTED"',
    "func request_item_repair",
)
assert "SpinBox" not in production_ui, "Production must not reintroduce the detached SpinBox timer defect."
assert "Work/day" not in production_ui and "work per day" not in production_ui.lower(), (
    "Ordinary Production project UI must show worker count and time, not work-rate maths."
)
assert "Master ×" not in production_ui and "Skilled ×" not in production_ui
assert "ResearchScreenControllerScript" in shell, "Stage 5.4C Research screen routing is missing."
require(
    "tests/integration/stage_5_4b_manufacturing_personnel_repair_tests.gd",
    "_test_level_one_workshop_runs_one_project_per_position",
    'allocation.get("slots", 0)) == 3',
    'allocation.get("assigned", 0)) == 3',
)

require(
    "application/inventory/strategic_equipment_service.gd",
    "Destroyed items must be repaired before they can be equipped.",
)
require(
    "application/inventory/shop_service.gd",
    "Destroyed items cannot be sold intact. Repair or dismantle them instead.",
    "reserved_output_storage_space",
)
require(
    "application/characters/henchman_recruitment_service.gd",
    "PersonnelCapacityService",
    "Personnel capacity is full.",
)

print("PASS — Stage 5.4B personnel, Production, automatic worker allocation and same-ID repair are integrated.")
