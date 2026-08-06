class_name ActiveMissionState
extends RefCounted

const STATUS_HIDDEN: StringName = &"hidden"
const STATUS_DISCOVERED: StringName = &"discovered"
const STATUS_AVAILABLE: StringName = &"available"
# Compatibility state retained for older saves and direct briefing callers.
const STATUS_BRIEFING: StringName = &"briefing"
const STATUS_EN_ROUTE: StringName = &"en_route"
const STATUS_REGISTERED: StringName = &"registered"
const STATUS_IN_TACTICAL: StringName = &"in_tactical"
const STATUS_RESOLVED: StringName = &"resolved"
const STATUS_EXPIRED: StringName = &"expired"
const STATUS_CANCELLED: StringName = &"cancelled"

var mission_instance_id: StringName = &""
var mission_definition_id: StringName = &""
var site_id: StringName = &""
var status: StringName = STATUS_AVAILABLE
var selected_character_ids: Array[StringName] = []
var campaign_squad_id: StringName = &""
var stable_bay_id: StringName = &""
var transport_method_id: StringName = &"transport.walking"
var transport_asset_id: StringName = &""
var registered_setup_dictionary: Dictionary = {}
var setup_hash: String = ""
var mission_seed: int = 0
var source_campaign_revision: int = 0
var created_campaign_tick: int = 0
var discovered_tick: int = 0
var expiry_tick: int = -1
var expiry_event_id: StringName = &""
var last_resolved_expiry_event_id: StringName = &""
var expiry_suspended_tick: int = -1
var remaining_availability_at_dispatch: int = -1
var discovering_agent_id: StringName = &""
var risk_rating: StringName = &"unknown"
var opposition_information: StringName = &"unknown"
var reward_preview: Array[String] = []
var travel_operation_id: StringName = &""
var deployment_reservation_id: StringName = &""
var committed_result_id: StringName = &""


func is_registered() -> bool:
	return (
		status in [STATUS_EN_ROUTE, STATUS_REGISTERED, STATUS_IN_TACTICAL]
		and not registered_setup_dictionary.is_empty()
	)


func is_actionable() -> bool:
	return status not in [STATUS_HIDDEN, STATUS_RESOLVED, STATUS_EXPIRED, STATUS_CANCELLED]


func is_available() -> bool:
	return status in [STATUS_DISCOVERED, STATUS_AVAILABLE, STATUS_BRIEFING]


func can_expire() -> bool:
	return is_available() and expiry_tick >= 0 and expiry_suspended_tick < 0


func remaining_minutes(campaign_tick: int) -> int:
	if expiry_tick < 0:
		return -1
	if expiry_suspended_tick >= 0:
		return maxi(0, remaining_availability_at_dispatch)
	return maxi(0, expiry_tick - campaign_tick)


func setup_snapshot() -> MissionSetupSnapshot:
	if registered_setup_dictionary.is_empty():
		return null
	var result := MissionSetupSnapshot.from_dictionary(
		registered_setup_dictionary.duplicate(true)
	)
	return result if result.verify_integrity() else null


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if mission_instance_id.is_empty():
		errors.append("Active mission has no instance ID.")
	if mission_definition_id.is_empty():
		errors.append("Active mission %s has no definition ID." % mission_instance_id)
	if status not in [
		STATUS_HIDDEN,
		STATUS_DISCOVERED,
		STATUS_AVAILABLE,
		STATUS_BRIEFING,
		STATUS_EN_ROUTE,
		STATUS_REGISTERED,
		STATUS_IN_TACTICAL,
		STATUS_RESOLVED,
		STATUS_EXPIRED,
		STATUS_CANCELLED,
	]:
		errors.append("Active mission %s has invalid status %s." % [mission_instance_id, status])
	if mission_seed < 0:
		errors.append("Active mission %s has an invalid seed." % mission_instance_id)
	if source_campaign_revision < 0:
		errors.append("Active mission %s has an invalid source revision." % mission_instance_id)
	if created_campaign_tick < 0 or discovered_tick < 0:
		errors.append("Active mission %s has invalid discovery timing." % mission_instance_id)
	if expiry_tick >= 0 and expiry_tick < discovered_tick:
		errors.append("Active mission %s expires before discovery." % mission_instance_id)
	if expiry_suspended_tick >= 0 and status not in [STATUS_EN_ROUTE, STATUS_REGISTERED, STATUS_IN_TACTICAL, STATUS_RESOLVED]:
		errors.append("Mission %s suspended expiry outside a committed operation." % mission_instance_id)
	if is_registered():
		if deployment_reservation_id.is_empty():
			errors.append(
				"Registered mission %s has no deployment reservation."
				% mission_instance_id
			)
		if setup_hash.length() != 64:
			errors.append("Registered mission %s has no valid setup hash." % mission_instance_id)
		var setup: MissionSetupSnapshot = setup_snapshot()
		if setup == null:
			errors.append("Registered mission %s has no valid immutable setup." % mission_instance_id)
		else:
			if setup.mission_id != mission_instance_id:
				errors.append("Registered mission %s setup belongs to another mission." % mission_instance_id)
			if setup.finalized_setup_hash() != setup_hash:
				errors.append("Registered mission %s setup hash does not match." % mission_instance_id)
	return errors


func to_dictionary() -> Dictionary:
	var selected_ids: Array[String] = []
	for character_id: StringName in selected_character_ids:
		selected_ids.append(String(character_id))
	return {
		"mission_instance_id": String(mission_instance_id),
		"mission_definition_id": String(mission_definition_id),
		"site_id": String(site_id),
		"status": String(status),
		"selected_character_ids": selected_ids,
		"campaign_squad_id": String(campaign_squad_id),
		"stable_bay_id": String(stable_bay_id),
		"transport_method_id": String(transport_method_id),
		"transport_asset_id": String(transport_asset_id),
		"registered_setup": registered_setup_dictionary.duplicate(true),
		"setup_hash": setup_hash,
		"mission_seed": mission_seed,
		"source_campaign_revision": source_campaign_revision,
		"created_campaign_tick": created_campaign_tick,
		"discovered_tick": discovered_tick,
		"expiry_tick": expiry_tick,
		"expiry_event_id": String(expiry_event_id),
		"last_resolved_expiry_event_id": String(last_resolved_expiry_event_id),
		"expiry_suspended_tick": expiry_suspended_tick,
		"remaining_availability_at_dispatch": remaining_availability_at_dispatch,
		"discovering_agent_id": String(discovering_agent_id),
		"risk_rating": String(risk_rating),
		"opposition_information": String(opposition_information),
		"reward_preview": reward_preview.duplicate(),
		"travel_operation_id": String(travel_operation_id),
		"deployment_reservation_id": String(deployment_reservation_id),
		"committed_result_id": String(committed_result_id),
	}


static func from_dictionary(data: Dictionary) -> ActiveMissionState:
	var result := ActiveMissionState.new()
	result.mission_instance_id = StringName(data.get("mission_instance_id", ""))
	result.mission_definition_id = StringName(data.get("mission_definition_id", ""))
	result.site_id = StringName(data.get("site_id", ""))
	result.status = StringName(data.get("status", STATUS_AVAILABLE))
	for raw_id: Variant in data.get("selected_character_ids", []):
		var character_id := StringName(raw_id)
		if not character_id.is_empty():
			result.selected_character_ids.append(character_id)
	result.campaign_squad_id = StringName(data.get("campaign_squad_id", ""))
	result.stable_bay_id = StringName(data.get("stable_bay_id", ""))
	result.transport_method_id = StringName(data.get("transport_method_id", "transport.walking"))
	result.transport_asset_id = StringName(data.get("transport_asset_id", ""))
	var raw_setup: Variant = data.get("registered_setup", {})
	var legacy_setup_integrity: bool = false
	if raw_setup is Dictionary:
		var raw_setup_dictionary: Dictionary = raw_setup as Dictionary
		legacy_setup_integrity = int(raw_setup_dictionary.get("integrity_format", 1)) < 2
		var loaded_setup: MissionSetupSnapshot = MissionSetupSnapshot.from_dictionary(
			raw_setup_dictionary.duplicate(true)
		)
		if loaded_setup != null and loaded_setup.verify_integrity():
			result.registered_setup_dictionary = loaded_setup.to_dictionary()
		else:
			result.registered_setup_dictionary = raw_setup_dictionary.duplicate(true)
	result.setup_hash = String(data.get("setup_hash", ""))
	if legacy_setup_integrity and not result.registered_setup_dictionary.is_empty():
		var migrated_setup: MissionSetupSnapshot = MissionSetupSnapshot.from_dictionary(
			result.registered_setup_dictionary.duplicate(true)
		)
		if migrated_setup != null and migrated_setup.verify_integrity():
			result.setup_hash = migrated_setup.finalized_setup_hash()
	result.mission_seed = maxi(0, int(data.get("mission_seed", 0)))
	result.source_campaign_revision = maxi(0, int(data.get("source_campaign_revision", 0)))
	result.created_campaign_tick = maxi(0, int(data.get("created_campaign_tick", 0)))
	result.discovered_tick = maxi(0, int(data.get("discovered_tick", result.created_campaign_tick)))
	result.expiry_tick = int(data.get("expiry_tick", -1))
	result.expiry_event_id = StringName(data.get("expiry_event_id", ""))
	result.last_resolved_expiry_event_id = StringName(data.get("last_resolved_expiry_event_id", ""))
	result.expiry_suspended_tick = int(data.get("expiry_suspended_tick", -1))
	result.remaining_availability_at_dispatch = int(data.get("remaining_availability_at_dispatch", -1))
	result.discovering_agent_id = StringName(data.get("discovering_agent_id", ""))
	result.risk_rating = StringName(data.get("risk_rating", "unknown"))
	result.opposition_information = StringName(data.get("opposition_information", "unknown"))
	var raw_rewards: Variant = data.get("reward_preview", [])
	if raw_rewards is Array:
		for raw_reward: Variant in raw_rewards as Array:
			result.reward_preview.append(String(raw_reward))
	result.travel_operation_id = StringName(data.get("travel_operation_id", ""))
	result.deployment_reservation_id = StringName(data.get("deployment_reservation_id", ""))
	result.committed_result_id = StringName(data.get("committed_result_id", ""))
	return result
