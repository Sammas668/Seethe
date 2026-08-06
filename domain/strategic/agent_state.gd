class_name AgentState
extends RefCounted

const STATUS_AT_STRONGHOLD: StringName = &"at_stronghold"
const STATUS_TRAVELLING: StringName = &"travelling"
const STATUS_DEPLOYED: StringName = &"deployed"
const VALID_STATUSES: Array[StringName] = [
	STATUS_AT_STRONGHOLD,
	STATUS_TRAVELLING,
	STATUS_DEPLOYED,
]

var agent_id: StringName = &""
var display_name: String = "Agent"
var current_region_id: StringName = &""
var current_hex: RegionHexCoord
var status: StringName = STATUS_AT_STRONGHOLD
var active_travel_plan: AgentTravelPlan
var discovery_due_tick: int = -1
var discovery_seed: int = 0
var pending_discovery_event_id: StringName = &""
var last_resolved_arrival_plan_id: StringName = &""
var last_resolved_discovery_event_id: StringName = &""
var discovery_attempt_sequence: int = 0
var deployment_sequence: int = 0
var last_generated_site_id: StringName = &""


func is_available_for_dispatch() -> bool:
	return status in [STATUS_AT_STRONGHOLD, STATUS_DEPLOYED]


func operating_radius() -> int:
	return 2


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if agent_id.is_empty():
		errors.append("Campaign Agent has no ID.")
	if current_region_id.is_empty():
		errors.append("Agent %s has no region." % agent_id)
	if current_hex == null:
		errors.append("Agent %s has no map hex." % agent_id)
	if status not in VALID_STATUSES:
		errors.append("Agent %s has invalid status %s." % [agent_id, status])
	if status == STATUS_TRAVELLING:
		if active_travel_plan == null:
			errors.append("Travelling Agent %s has no travel plan." % agent_id)
		else:
			errors.append_array(active_travel_plan.validate_state())
	elif active_travel_plan != null:
		errors.append("Stationary Agent %s retained an active travel plan." % agent_id)
	if discovery_due_tick < -1:
		errors.append("Agent %s has invalid hidden discovery timing." % agent_id)
	if discovery_due_tick >= 0 and pending_discovery_event_id.is_empty():
		errors.append("Agent %s has hidden discovery timing without an event ID." % agent_id)
	if discovery_attempt_sequence < 0:
		errors.append("Agent %s has invalid discovery attempt sequence." % agent_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"agent_id": String(agent_id),
		"display_name": display_name,
		"current_region_id": String(current_region_id),
		"current_hex": _coord_pair(current_hex),
		"status": String(status),
		"active_travel_plan": (
			active_travel_plan.to_dictionary()
			if active_travel_plan != null
			else {}
		),
		"discovery_due_tick": discovery_due_tick,
		"discovery_seed": discovery_seed,
		"pending_discovery_event_id": String(pending_discovery_event_id),
		"last_resolved_arrival_plan_id": String(last_resolved_arrival_plan_id),
		"last_resolved_discovery_event_id": String(last_resolved_discovery_event_id),
		"discovery_attempt_sequence": discovery_attempt_sequence,
		"deployment_sequence": deployment_sequence,
		"last_generated_site_id": String(last_generated_site_id),
	}


static func from_dictionary(data: Dictionary) -> AgentState:
	var result := AgentState.new()
	result.agent_id = StringName(data.get("agent_id", ""))
	result.display_name = String(data.get("display_name", "Agent"))
	result.current_region_id = StringName(data.get("current_region_id", ""))
	result.current_hex = _coord_from_pair(data.get("current_hex", []))
	result.status = StringName(data.get("status", STATUS_AT_STRONGHOLD))
	var raw_plan: Variant = data.get("active_travel_plan", {})
	if raw_plan is Dictionary and not (raw_plan as Dictionary).is_empty():
		result.active_travel_plan = AgentTravelPlan.from_dictionary(raw_plan as Dictionary)
	result.discovery_due_tick = int(data.get("discovery_due_tick", -1))
	result.discovery_seed = int(data.get("discovery_seed", 0))
	result.pending_discovery_event_id = StringName(data.get("pending_discovery_event_id", ""))
	result.last_resolved_arrival_plan_id = StringName(data.get("last_resolved_arrival_plan_id", ""))
	result.last_resolved_discovery_event_id = StringName(data.get("last_resolved_discovery_event_id", ""))
	result.discovery_attempt_sequence = maxi(0, int(data.get("discovery_attempt_sequence", 0)))
	result.deployment_sequence = maxi(0, int(data.get("deployment_sequence", 0)))
	result.last_generated_site_id = StringName(data.get("last_generated_site_id", ""))
	return result


static func _coord_pair(coord: RegionHexCoord) -> Array[int]:
	return [coord.offset_col, coord.offset_row] if coord != null else []


static func _coord_from_pair(raw_value: Variant) -> RegionHexCoord:
	if not raw_value is Array:
		return null
	var pair: Array = raw_value as Array
	if pair.size() < 2:
		return null
	return RegionHexCoord.from_offset(int(pair[0]), int(pair[1]))
