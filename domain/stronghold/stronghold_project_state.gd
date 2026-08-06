class_name StrongholdProjectState
extends RefCounted

const KIND_CONSTRUCTION: StringName = &"construction"
const KIND_UPGRADE: StringName = &"upgrade"

var project_id: StringName = &""
var project_kind: StringName = KIND_CONSTRUCTION
var facility_instance_id: StringName = &""
var facility_definition_id: StringName = &""
var start_tick: int = 0
var completion_tick: int = 0
var target_level: int = 1
var revision: int = 0


func duration_minutes() -> int:
	return maxi(1, completion_tick - start_tick)


func remaining_minutes(campaign_tick: int) -> int:
	return maxi(0, completion_tick - campaign_tick)


func progress(campaign_tick: int) -> float:
	return clampf(
		float(campaign_tick - start_tick) / float(duration_minutes()),
		0.0,
		1.0
	)


func is_complete(campaign_tick: int) -> bool:
	return campaign_tick >= completion_tick


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if project_id.is_empty():
		errors.append("Stronghold project has no project ID.")
	if project_kind not in [KIND_CONSTRUCTION, KIND_UPGRADE]:
		errors.append("Stronghold project %s has an invalid kind." % project_id)
	if facility_instance_id.is_empty():
		errors.append("Stronghold project %s has no facility instance." % project_id)
	if facility_definition_id.is_empty():
		errors.append("Stronghold project %s has no facility definition." % project_id)
	if completion_tick <= start_tick:
		errors.append("Stronghold project %s has an invalid duration." % project_id)
	if target_level <= 0:
		errors.append("Stronghold project %s has an invalid target level." % project_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"project_id": String(project_id),
		"project_kind": String(project_kind),
		"facility_instance_id": String(facility_instance_id),
		"facility_definition_id": String(facility_definition_id),
		"start_tick": start_tick,
		"completion_tick": completion_tick,
		"target_level": target_level,
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> StrongholdProjectState:
	var result := StrongholdProjectState.new()
	result.project_id = StringName(data.get("project_id", ""))
	result.project_kind = StringName(data.get("project_kind", KIND_CONSTRUCTION))
	result.facility_instance_id = StringName(data.get("facility_instance_id", ""))
	result.facility_definition_id = StringName(data.get("facility_definition_id", ""))
	result.start_tick = maxi(0, int(data.get("start_tick", 0)))
	result.completion_tick = maxi(result.start_tick + 1, int(data.get("completion_tick", result.start_tick + 1)))
	result.target_level = maxi(1, int(data.get("target_level", 1)))
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result
