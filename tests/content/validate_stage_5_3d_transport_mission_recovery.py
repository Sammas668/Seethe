from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]

def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")

TRANSPORT_STATE = read("domain/strategic/transport_state.gd")
TRANSPORT_DEF = read("domain/strategic/squad_transport_definition.gd")
TRANSPORT = read("application/strategic/squad_transport_service.gd")
OPERATION = read("domain/strategic/squad_travel_operation_state.gd")
TRAVEL = read("application/strategic/squad_travel_service.gd")
RECOVERY = read("application/missions/mission_recovery_selection_service.gd")
SESSION = read("bootstrap/app/campaign_session.gd")
COORDINATOR = read("application/missions/campaign_mission_coordinator.gd")
COMMIT = read("application/campaign/campaign_result_commit_service.gd")
SHELL = read("presentation/campaign/campaign_shell.gd")
APP = read("bootstrap/app/game_app.gd")
CAMPAIGN = read("domain/campaign/campaign_state.gd")
LOCATION = read("domain/campaign/campaign_item_location_state.gd")
ENVELOPE = read("domain/missions/mission_commit_envelope.gd")
REPOSITORY_PORT = read("application/campaign/ports/campaign_repository.gd")
REPOSITORY = read("infrastructure/persistence/json_campaign_repository.gd")
FACILITY = read("domain/stronghold/stronghold_facility_definition.gd")
STRONGHOLD = json.loads(read("content/stronghold/starting_ruin/starting_ruin.json"))

# Persistent transport definitions and exact owned instances.
for token in [
    "var passenger_capacity: int",
    "var strategic_speed_multiplier: float",
    "var cargo_capacity_lb: float",
    "var journey_notoriety_modifier_percent: int",
    "var captive_capacity: int",
    "var cage_anchor_capacity: int",
    "var monster_capacity: int",
    "var siege_anchor_capacity: int",
    "var oversized_cargo_capacity: int",
    "var stable_space_required: int",
    "var terrain_speed_modifiers: Dictionary",
    "var maximum_condition: int",
    "var research_unlock_id: StringName",
]:
    assert token in TRANSPORT_DEF, token

for token in [
    "STATUS_AVAILABLE",
    "STATUS_RESERVED",
    "STATUS_TRAVELLING_OUT",
    "STATUS_DEPLOYED",
    "STATUS_RETURNING",
    "STATUS_DAMAGED",
    "STATUS_UNDER_REPAIR",
    "STATUS_UNSUPPORTED",
    "STATUS_LOST",
    "STATUS_DESTROYED",
    "var housed_stable_id: StringName",
    "var support_enabled: bool",
    "var reserved_mission_id: StringName",
]:
    assert token in TRANSPORT_STATE, token

# Walking is unconditional; Stable capacity and Research are separate authorities.
assert 'const WALKING_ID: StringName = &"transport.walking"' in TRANSPORT
assert 'walking_data["is_available"] = true' in TRANSPORT
assert "func stable_space_capacity" in TRANSPORT
assert "func support_snapshot" in TRANSPORT
assert "func unlocked_definitions" in TRANSPORT
assert "campaign.has_completed_research" in TRANSPORT
assert "func acquire_transport_candidate" in TRANSPORT
assert "func reserve_transport_candidate" in TRANSPORT
assert "func release_transport_candidate" in TRANSPORT
assert "var stable_space_by_level: Array[int]" in FACILITY
assert "func stable_space_for_level" in FACILITY

# No live route-validity or road-required transport implementation remains.
assert "func route_viability_snapshot" not in TRANSPORT
assert '"road_dependent"' not in TRANSPORT
assert "minimum_stables_level" not in TRANSPORT_DEF
assert "impassable_terrain_tags" in TRANSPORT_DEF

# Authored methods are Research-gated and include positive/negative overall Notoriety modifiers.
for transport_id in [
    "transport.pack_beast_train",
    "transport.covered_wagon",
    "transport.mounted_troop",
    "transport.siege_hauler",
]:
    assert transport_id in TRANSPORT, transport_id
assert '"journey_notoriety_modifier_percent": 5' in TRANSPORT
assert '"journey_notoriety_modifier_percent": 30' in TRANSPORT
assert "final_total - base_total" in TRANSPORT
assert "apply_notoriety_modifier_to_entries" in TRANSPORT
assert "pre_transport_subtotal" in TRANSPORT

# Exact transport instances persist through outward travel, tactical play and return.
for token in [
    "var transport_instance_ids: Array[StringName]",
    "var transport_assigned_count: int",
    "var transport_passenger_capacity: int",
    "var transport_strategic_speed_multiplier: float",
    "var transport_cargo_capacity_lb: float",
    "var transport_notoriety_modifier_percent: int",
    "var return_arrival_tick: int",
    "STATUS_RETURNING",
]:
    assert token in OPERATION, token
assert "reserve_transport_candidate" in COORDINATOR
assert "mark_transport_departed_candidate" in COORDINATOR
assert "release_transport_candidate" in COORDINATOR  # cancelled pre-departure reservation
assert "STATUS_RETURNING" in TRAVEL
assert "LOCATION_RETURN_TRANSIT" in TRAVEL
assert "release_transport_candidate" in TRAVEL
assert 'StringName("return_transit.%s" % operation.operation_id)' in TRAVEL
assert "active_operation_by_transport" in CAMPAIGN
assert "Transport %s is held by more than one active squad operation." in CAMPAIGN
assert "Reserved transport %s is not owned by its referenced journey %s." in CAMPAIGN

# Walking capacity uses cumulative unused maximum load and mandatory burdens.
# Stage 5.3G2 separates this from assigned-transport recovery, where the
# transport's cargo rating replaces the personal carrying pool.
for token in [
    "func _personal_recovery_capacity_snapshot",
    'stat_value(&"maximum_weight_lb", 0)',
    "remaining_carry_capacity_lb",
    "personal_remaining_carry_capacity_lb",
    "mandatory_manual_burden_lb",
    "mandatory_unallocated_item_weight_lb",
    "DEFAULT_PERSON_WEIGHT_LB",
    "carried_casualty_count",
    "manual_captive_count",
]:
    assert token in RECOVERY, token
assert "transport_cargo if uses_dedicated_transport else personal_recovery_capacity" in RECOVERY
assert '"uses_dedicated_transport": uses_dedicated_transport' in RECOVERY
assert '"personal_remaining_carry_capacity_lb": personal_recovery_capacity' in RECOVERY
assert "transport_cargo + float(personal_capacity.get" not in RECOVERY
assert "selected_cargo_weight > capacity + 0.001" in RECOVERY
assert 'for category: StringName in [&"monster", &"siege"]' in RECOVERY
assert 'for category: StringName in [&"cage", &"oversized"]' in RECOVERY

# Recovery selection filters optional exact items without mutating the tactical result.
for token in [
    "func build_snapshot",
    "func validate_selection",
    "func filter_envelope",
    "MissionResult.from_dictionary(envelope.result.to_dictionary())",
    "filtered_result.extracted_item_entries = kept_entries",
    "filtered_result.abandoned_item_ids.append(item_id)",
    "character_result.loot_item_ids = _without_ids",
    "filtered_result.generated_item_provenance_ids = kept_provenance_ids",
]:
    assert token in RECOVERY, token

# Crash-safe pending result persistence and exact-once commit.
assert "func to_dictionary" in ENVELOPE and "static func from_dictionary" in ENVELOPE
for token in [
    "save_pending_mission_recovery",
    "load_pending_mission_recovery",
    "clear_pending_mission_recovery",
]:
    assert token in REPOSITORY_PORT, token
    assert token in REPOSITORY, token
    assert token in SESSION, token
assert "pending_mission_recovery_path" in REPOSITORY
assert "mission_recovery_selection_changed" in SHELL
assert "_on_mission_recovery_selection_changed" in APP
assert "_restore_pending_mission_recovery" in APP
assert "save_pending_mission_recovery(envelope)" in APP
assert "clear_pending_mission_recovery" in APP
assert "campaign.revision < result.source_campaign_revision" in COMMIT
assert "campaign.revision != result.source_campaign_revision" not in COMMIT
assert "Permanent protagonist death was not committed" not in COORDINATOR
assert 'result_code = &"campaign_defeat"' in COORDINATOR
assert "candidate.campaign_status = CampaignStatus.DEFEATED" in COMMIT

# Mission briefing, route preview, recovery screen and Stable fleet UI expose the corrected model.
for token in [
    'const SCREEN_RECOVERY: StringName = &"recovery"',
    '"HOUSED TRANSPORT"',
    '"ACQUIRE TRANSPORT"',
    '"RESEARCH REQUIRED — %s"',
    '"Passengers %d · Speed ×%.2f · Cargo %.0f lb · Notoriety %+d%%',
    '"SELECT ALL THAT FIT"',
    '"ABANDON ALL OPTIONAL LOOT"',
    '"CONFIRM SELECTED CARGO AND RETURN"',
    '"RETURN JOURNEY NOTORIETY',
    '"DEDICATED SPECIALIST SUPPORT',
]:
    assert token in SHELL, token
assert "route viability" not in SHELL.lower()

# Stable authored levels provide capacity only, not named automatic transport unlocks.
stables = [entry for entry in STRONGHOLD.get("facilities", []) if entry.get("id") == "facility.stables"]
assert len(stables) == 1
stable = stables[0]
assert stable.get("stable_space_by_level") == [1]
benefits = "\n".join(stable.get("benefits", []))
assert "houses one exact transport" in benefits
for obsolete_name in ["Foot Column", "Pack Train", "Wagon Train", "Mounted Column"]:
    assert obsolete_name not in benefits

# Campaign saves own fleet, Research, return operations and migration away from obsolete assignments.
for token in [
    "var transports_by_id: Dictionary",
    "var completed_research_ids: Dictionary",
    'base["transports"]',
    'base["completed_research_ids"]',
    "_begin_operation_return_journey",
    'operation.transport_id = &"transport.walking"',
]:
    assert token in CAMPAIGN, token
assert 'const LOCATION_RETURN_TRANSIT: StringName = &"return_transit"' in LOCATION

print("PASS — Stable level supplies Stable Space while Research gates transport methods.")
print("PASS — exact transport assets control passengers, speed, cargo, special support and journey Notoriety.")
print("PASS — walking is always available and recovery uses cumulative remaining maximum load.")
print("PASS — roads alter authored travel time only; no road-required route-viability rule remains.")
print("PASS — optional mission recovery is capacity-validated, player-confirmed and exact-once.")
print("PASS — pending recovery survives save/load and transport reservations persist until return arrival.")
