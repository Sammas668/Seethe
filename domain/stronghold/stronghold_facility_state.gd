class_name StrongholdFacilityState
extends RefCounted

const CONDITION_OPERATIONAL: StringName = &"operational"
const CONDITION_UNDER_CONSTRUCTION: StringName = &"under_construction"
const CONDITION_UPGRADING: StringName = &"upgrading"
const CONDITION_DAMAGED: StringName = &"damaged"
const CONDITION_DISABLED: StringName = &"disabled"

var instance_id: StringName = &""
var definition_id: StringName = &""
var origin: Vector2i = Vector2i.ZERO
var level: int = 1
var condition: StringName = CONDITION_OPERATIONAL
var active_project_id: StringName = &""
var is_starting_facility: bool = false
var revision: int = 0


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if instance_id.is_empty():
		errors.append("Stronghold facility state has no instance ID.")
	if definition_id.is_empty():
		errors.append("Stronghold facility %s has no definition ID." % instance_id)
	if level <= 0:
		errors.append("Stronghold facility %s has an invalid level." % instance_id)
	if condition not in [
		CONDITION_OPERATIONAL,
		CONDITION_UNDER_CONSTRUCTION,
		CONDITION_UPGRADING,
		CONDITION_DAMAGED,
		CONDITION_DISABLED,
	]:
		errors.append("Stronghold facility %s has an invalid condition." % instance_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"instance_id": String(instance_id),
		"definition_id": String(definition_id),
		"origin": [origin.x, origin.y],
		"level": level,
		"condition": String(condition),
		"active_project_id": String(active_project_id),
		"is_starting_facility": is_starting_facility,
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> StrongholdFacilityState:
	var result := StrongholdFacilityState.new()
	result.instance_id = StringName(data.get("instance_id", ""))
	result.definition_id = StringName(data.get("definition_id", ""))
	var raw_origin: Variant = data.get("origin", [0, 0])
	if raw_origin is Array and (raw_origin as Array).size() >= 2:
		result.origin = Vector2i(int((raw_origin as Array)[0]), int((raw_origin as Array)[1]))
	result.level = maxi(1, int(data.get("level", 1)))
	result.condition = StringName(data.get("condition", CONDITION_OPERATIONAL))
	result.active_project_id = StringName(data.get("active_project_id", ""))
	result.is_starting_facility = bool(data.get("is_starting_facility", false))
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result
