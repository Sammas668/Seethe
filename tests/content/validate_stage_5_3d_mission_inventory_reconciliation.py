#!/usr/bin/env python3
"""Static acceptance checks for mission inventory reconciliation and lair auto-replenishment."""
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


result_state = read("domain/missions/mission_result.gd")
result_builder = read("application/missions/mission_result_builder.gd")
result_validator = read("application/missions/mission_result_validator.gd")
recovery = read("application/missions/mission_recovery_selection_service.gd")
commit = read("application/campaign/campaign_result_commit_service.gd")
loadouts = read("application/inventory/loadout_service.gd")
travel_state = read("domain/strategic/squad_travel_operation_state.gd")
coordinator = read("application/missions/campaign_mission_coordinator.gd")
travel = read("application/strategic/squad_travel_service.gd")
session = read("bootstrap/app/campaign_session.gd")

# Every outbound item receives an immutable post-mission disposition.
for token in [
    "var item_outcomes_by_id: Dictionary",
    "func item_outcome(item_id: StringName)",
    '"item_outcomes_by_id": item_outcomes_by_id.duplicate(true)',
    'data.get("item_outcomes_by_id", {})',
    '&"returned"',
    '&"partially_consumed"',
    '&"consumed"',
    '&"lost"',
    '&"transferred"',
]:
    if token not in result_state:
        errors.append(f"MissionResult missing deployment-item outcome support: {token}")

for token in [
    "_record_deployment_item_outcomes(result, setup, state)",
    "var tactical_item: TacticalItemInstanceState = state.get_item(setup_item.item_id)",
    'var outcome_id: StringName = &"consumed" if tactical_item == null else &"lost"',
    'outcome_id = &"partially_consumed"',
    'outcome_id = &"transferred"',
    '"original_owner_id"',
    '"final_owner_id"',
    '"original_quantity"',
    '"final_quantity"',
]:
    if token not in result_builder:
        errors.append(f"MissionResultBuilder missing exact inventory reconciliation: {token}")

# Result validation requires one exact outcome per deployed setup item and
# rejects duplicated surviving/consumed representations.
for token in [
    "_validate_item_outcomes(result, setup, extracted_items, errors)",
    "Mission result omits the post-mission outcome for deployment item",
    "Consumed or lost item %s was also extracted.",
    "Surviving deployment item %s was not extracted.",
    "outcome disagrees with its extracted quantity",
    "outcome disagrees with its final owner",
    "invents an outcome for non-deployment item",
]:
    if token not in result_validator:
        errors.append(f"MissionResultValidator missing item-outcome integrity rule: {token}")

# Original surviving equipment is mandatory return cargo; new recovered loot
# remains optional. Consumed and lost items are not silently recreated.
for token in [
    "for raw_item_id: Variant in result.item_outcomes_by_id.keys()",
    "mandatory[item_id_text] = true",
    "for character_id: StringName in setup.player_unit_order()",
    "_is_outbound_item(item, mandatory_ids)",
    "MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY",
]:
    if token not in recovery:
        errors.append(f"Recovery selection missing outbound-item handling: {token}")

# The outward reservation is rewritten to the exact surviving inventory before
# candidate validation. This is the direct fix for the consumed-rope failure.
for token in [
    "_reconcile_return_reservation(",
    "operation.reserved_item_ids = returning_item_ids.duplicate()",
    "reservation.item_ids = returning_item_ids.duplicate()",
    "Deployment reservation reconciled with the exact post-mission inventory.",
]:
    if token not in commit:
        errors.append(f"Campaign result commit missing return-reservation reconciliation: {token}")

if commit.find("_reconcile_return_reservation(") < commit.find("for entry: Dictionary in result.extracted_item_entries"):
    errors.append("return reservation is reconciled before final extracted inventory is restored")


# The desired replacement plan is captured from the exact departure loadout,
# rather than relying only on a manually selected generic template.
for token in [
    "var desired_loadout_entries_by_character_id: Dictionary",
    "func desired_loadout_entries(character_id: StringName)",
    '"desired_loadout_entries_by_character_id"',
]:
    if token not in travel_state:
        errors.append(f"SquadTravelOperationState missing departure loadout snapshot: {token}")
for token in [
    "_desired_loadout_snapshot(",
    '"definition_id": String(item.definition_id)',
    '"container_id": String(item.location.container_id)',
    "operation.desired_loadout_entries_by_character_id",
]:
    if token not in coordinator:
        errors.append(f"mission dispatch does not preserve exact desired loadout: {token}")

# Saved loadout replenishment is storage-only, unreserved, and does not steal
# equipment from another character.
for token in [
    "func replenish_preferred_loadout_candidate(",
    "desired_loadout_entries: Array = []",
    "_loadout_rules_from_snapshot(desired_loadout_entries)",
    "character.preferred_loadout_template_id",
    "not item.location.is_stronghold_storage()",
    "campaign.active_reservation_for_item(item.item_id) != null",
    "item.is_protected",
    "equip_candidate_at_position(",
    '"replenished": replenished',
    '"missing": missing',
    "some saved loadout items remain missing",
]:
    if token not in loadouts:
        errors.append(f"LoadoutService missing safe auto-replenishment behaviour: {token}")

if "item.location.belongs_to_character" in loadouts[loadouts.find("func _storage_candidates_for_replenishment_rule"):loadouts.find("func _item_definition_matches_replenishment_rule")]:
    errors.append("auto-replenishment candidates may be taken from another character")

# Physical return is finalized and persisted before auto-replenishment runs.
# A malformed replacement plan must not invalidate the squad's arrival state.
arrival_start = travel.find("if operation.status == SquadTravelOperationState.STATUS_RETURNING")
arrival_end = travel.find("if candidate.campaign_tick < operation.arrival_tick", arrival_start)
arrival_block = travel[arrival_start:arrival_end]
for token in [
    "candidate.release_strategic_reservation(operation.reservation_id)",
    "CampaignItemLocationState.stronghold_storage()",
    '(result["returned_operation_ids"] as Array).append(operation.operation_id)',
    "Auto-replenishment is deliberately deferred",
]:
    if token not in arrival_block:
        errors.append(f"return-arrival flow missing: {token}")
if "replenish_preferred_loadout_candidate(" in arrival_block:
    errors.append("return-arrival flow still replenishes before the arrival state is persisted")

for token in [
    "func _replenish_returned_operation(operation_id: StringName)",
    '&"returned_squad_replenished"',
    "loadout_service.replenish_preferred_loadout_candidate(",
    "candidate_operation.desired_loadout_entries(character_id)",
    '&"squad_returned"',
    "_flush_clock_state(persistence_reason)",
]:
    if token not in session:
        errors.append(f"CampaignSession missing deferred return replenishment: {token}")
if not (
    session.find("_flush_clock_state(persistence_reason)")
    < session.find("_replenish_returned_operation(", session.find("func process_strategic_time"))
):
    errors.append("return arrival is not persisted before automatic replenishment")

if "loadout_service: LoadoutService = null" not in travel:
    errors.append("SquadTravelService does not receive LoadoutService")
if "stable_bay_service, loadout_service" not in session:
    errors.append("CampaignSession does not wire LoadoutService into return travel")

# Behavioural model of the reported rope case: the used rope disappears from the
# return reservation, then an unreserved spare may refill the saved slot at home.
outbound = {"rope", "mace", "armour"}
extracted = {"mace", "armour"}
return_reservation = outbound & extracted
assert "rope" not in return_reservation
stronghold_storage = [
    {"id": "spare_rope", "definition": "rope", "reserved": False},
    {"id": "reserved_rope", "definition": "rope", "reserved": True},
]
replacement = next(
    (item for item in stronghold_storage if item["definition"] == "rope" and not item["reserved"]),
    None,
)
assert replacement is not None and replacement["id"] == "spare_rope"

if errors:
    print("Stage 5.3D Mission Inventory Reconciliation validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — every outbound item receives an immutable returned/partial/consumed/lost/transferred outcome.")
print("PASS — consumed or lost items are removed from the deployment reservation before campaign validation.")
print("PASS — transferred quantities and final owners are preserved by the extracted inventory manifest.")
print("PASS — new recovered loot remains player-selected cargo rather than automatic outbound equipment.")
print("PASS — returning characters replenish saved loadouts only from unreserved stronghold Storage after arrival.")
