class_name MissionObjectiveState
extends RefCounted

const STATUS_ACTIVE: StringName = &"active"
const STATUS_COMPLETED: StringName = &"completed"
const STATUS_FAILED: StringName = &"failed"
const STATUS_IMPOSSIBLE: StringName = &"impossible"

var objective_id: StringName = &""
var display_name: String = "Mission objective"
var optional: bool = false
var status: StringName = STATUS_ACTIVE
var current_quantity: int = 0
var required_quantity: int = 1
var contributing_entity_ids: Array[StringName] = []
var failure_reason: String = ""
var completion_revision: int = -1
var failure_revision: int = -1


static func from_definition(definition: MissionObjectiveDefinition) -> MissionObjectiveState:
	var result := MissionObjectiveState.new()
	if definition == null:
		return result
	result.objective_id = definition.objective_id
	result.display_name = definition.display_name
	result.optional = definition.optional
	result.required_quantity = definition.required_quantity
	return result


func is_complete() -> bool:
	return status == STATUS_COMPLETED


func is_failed() -> bool:
	return status in [STATUS_FAILED, STATUS_IMPOSSIBLE]


func duplicate_state() -> MissionObjectiveState:
	return from_dictionary(to_dictionary())


func to_dictionary() -> Dictionary:
	var ids: Array[String] = []
	for entity_id: StringName in contributing_entity_ids:
		ids.append(String(entity_id))
	return {
		"objective_id": String(objective_id),
		"display_name": display_name,
		"optional": optional,
		"status": String(status),
		"current_quantity": current_quantity,
		"required_quantity": required_quantity,
		"contributing_entity_ids": ids,
		"failure_reason": failure_reason,
		"completion_revision": completion_revision,
		"failure_revision": failure_revision,
	}


static func from_dictionary(data: Dictionary) -> MissionObjectiveState:
	var result := MissionObjectiveState.new()
	result.objective_id = StringName(data.get("objective_id", ""))
	result.display_name = String(data.get("display_name", "Mission objective"))
	result.optional = bool(data.get("optional", false))
	result.status = StringName(data.get("status", STATUS_ACTIVE))
	result.current_quantity = maxi(0, int(data.get("current_quantity", 0)))
	result.required_quantity = maxi(1, int(data.get("required_quantity", 1)))
	for raw_id: Variant in data.get("contributing_entity_ids", []):
		result.contributing_entity_ids.append(StringName(raw_id))
	result.failure_reason = String(data.get("failure_reason", ""))
	result.completion_revision = int(data.get("completion_revision", -1))
	result.failure_revision = int(data.get("failure_revision", -1))
	return result
