class_name RaidOperationState
extends RefCounted

const STATUS_PREPARING: StringName = &"preparing"
const STATUS_INCOMING: StringName = &"incoming"
const STATUS_RESOLVED: StringName = &"resolved"
const STATUS_CANCELLED: StringName = &"cancelled"

var operation_id: StringName = &""
var origin_region_id: StringName = &""
var origin_subregion_id: StringName = &""
var origin_settlement_id: StringName = &""
var force_definition_id: StringName = &"raid_force.life_retaliation_01"
var approach_id: StringName = &""
var created_tick: int = 0
var departure_tick: int = 0
var arrival_tick: int = 0
var status: StringName = STATUS_PREPARING
var objective_definition_id: StringName = &"objective.defend_stronghold"
var linked_base_defence_mission_id: StringName = &""
var resolution_record_id: StringName = &""


func is_active() -> bool:
	return status in [STATUS_PREPARING, STATUS_INCOMING]


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if operation_id.is_empty():
		errors.append("Raid operation has no ID.")
	if origin_region_id.is_empty() or origin_subregion_id.is_empty():
		errors.append("Raid operation %s has no valid origin." % operation_id)
	if arrival_tick < created_tick:
		errors.append("Raid operation %s has invalid timing." % operation_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"operation_id": String(operation_id),
		"origin_region_id": String(origin_region_id),
		"origin_subregion_id": String(origin_subregion_id),
		"origin_settlement_id": String(origin_settlement_id),
		"force_definition_id": String(force_definition_id),
		"approach_id": String(approach_id),
		"created_tick": created_tick,
		"departure_tick": departure_tick,
		"arrival_tick": arrival_tick,
		"status": String(status),
		"objective_definition_id": String(objective_definition_id),
		"linked_base_defence_mission_id": String(linked_base_defence_mission_id),
		"resolution_record_id": String(resolution_record_id),
	}


static func from_dictionary(data: Dictionary) -> RaidOperationState:
	var result := RaidOperationState.new()
	result.operation_id = StringName(data.get("operation_id", ""))
	result.origin_region_id = StringName(data.get("origin_region_id", ""))
	result.origin_subregion_id = StringName(data.get("origin_subregion_id", ""))
	result.origin_settlement_id = StringName(data.get("origin_settlement_id", ""))
	result.force_definition_id = StringName(data.get("force_definition_id", "raid_force.life_retaliation_01"))
	result.approach_id = StringName(data.get("approach_id", ""))
	result.created_tick = maxi(0, int(data.get("created_tick", 0)))
	result.departure_tick = maxi(result.created_tick, int(data.get("departure_tick", result.created_tick)))
	result.arrival_tick = maxi(result.departure_tick, int(data.get("arrival_tick", result.departure_tick)))
	result.status = StringName(data.get("status", STATUS_PREPARING))
	result.objective_definition_id = StringName(data.get("objective_definition_id", "objective.defend_stronghold"))
	result.linked_base_defence_mission_id = StringName(data.get("linked_base_defence_mission_id", ""))
	result.resolution_record_id = StringName(data.get("resolution_record_id", ""))
	return result
