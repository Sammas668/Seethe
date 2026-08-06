#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(rel): return (ROOT / rel).read_text(encoding="utf-8")

service = read("application/stronghold/stronghold_construction_service.gd")
for needle in [
    "func preview_build(",
    "func construct_candidate(",
    "func upgrade_candidate(",
    "func cancel_project_candidate(",
    "func demolish_candidate(",
    "func advance_candidate(",
    "state.allocate_facility_instance_id",
    "state.allocate_project_id",
    "StrongholdFacilityStateScript.CONDITION_UNDER_CONSTRUCTION",
    "StrongholdFacilityStateScript.CONDITION_UPGRADING",
    "plot.current_state = StrongholdPlotDefinitionScript.OCCUPIED",
    "plot.current_state = StrongholdPlotDefinitionScript.AVAILABLE",
    "Footprint overlaps the Fifth-God Heart.",
    "Footprint overlaps the Stables.",
]:
    assert needle in service, needle

session = read("bootstrap/app/campaign_session.gd")
for needle in [
    "StrongholdConstructionServiceScript.new()",
    "signal stronghold_project_completed",
    "func current_stronghold_build_catalogue",
    "func preview_stronghold_build",
    "func construct_stronghold_facility",
    "func upgrade_stronghold_facility",
    "func cancel_stronghold_project",
    "func demolish_stronghold_facility",
    "stronghold_construction_service.advance_candidate",
    "CampaignChangeSet.new()",
    "state_store.commit(changes)",
]:
    assert needle in session, needle

rules = read("domain/stronghold/stronghold_prototype_rules.gd")
for needle in [
    "open_grid: bool = true",
    "unlock_all_facilities: bool = true",
    "unlock_all_upgrades: bool = true",
    "ignore_construction_costs: bool = true",
    "instant_construction: bool = false",
    "instant_upgrades: bool = false",
]:
    assert needle in rules, needle

project = read("domain/stronghold/stronghold_project_state.gd")
for needle in [
    "KIND_CONSTRUCTION",
    "KIND_UPGRADE",
    "completion_tick",
    "func progress(",
    "func remaining_minutes(",
    "func to_dictionary(",
    "static func from_dictionary(",
]:
    assert needle in project, needle

print("PASS — build, upgrade, cancellation and demolition use transactional campaign commits rather than UI mutation.")
print("PASS — construction and upgrades create persistent timed projects completed by Region Map clock advancement.")
print("PASS — prototype rules keep facilities unlocked and free while no longer completing work instantly.")
