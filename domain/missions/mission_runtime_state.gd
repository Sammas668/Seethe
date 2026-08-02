class_name MissionRuntimeState
extends RefCounted

var mission_instance_id: StringName = &""
var mission_definition_id: StringName = &""
var source_setup_hash: String = ""
var primary_objective_ids: Array[StringName] = []
var optional_objective_ids: Array[StringName] = []
var objectives_by_id: Dictionary = {}
var notoriety_preview_lines: Array[String] = []
var important_event_ids: Array[StringName] = []
var resolution_locked: bool = false


static func from_definition(
		definition: MissionDefinition,
		setup_hash: String
) -> MissionRuntimeState:
	var result := MissionRuntimeState.new()
	if definition == null:
		return result
	result.mission_instance_id = definition.mission_instance_id
	result.mission_definition_id = definition.mission_definition_id
	result.source_setup_hash = setup_hash
	result.notoriety_preview_lines = definition.notoriety_preview_lines.duplicate()
	for objective: MissionObjectiveDefinition in definition.primary_objectives:
		if objective == null:
			continue
		result.primary_objective_ids.append(objective.objective_id)
		result.objectives_by_id[objective.objective_id] = MissionObjectiveState.from_definition(objective)
	for objective: MissionObjectiveDefinition in definition.optional_objectives:
		if objective == null:
			continue
		result.optional_objective_ids.append(objective.objective_id)
		result.objectives_by_id[objective.objective_id] = MissionObjectiveState.from_definition(objective)
	return result


func objective(objective_id: StringName) -> MissionObjectiveState:
	return objectives_by_id.get(objective_id) as MissionObjectiveState


func objectives() -> Array[MissionObjectiveState]:
	var result: Array[MissionObjectiveState] = []
	for raw_state: Variant in objectives_by_id.values():
		var objective_state := raw_state as MissionObjectiveState
		if objective_state != null:
			result.append(objective_state)
	result.sort_custom(
		func(a: MissionObjectiveState, b: MissionObjectiveState) -> bool:
			return String(a.objective_id) < String(b.objective_id)
	)
	return result


func primary_complete() -> bool:
	if primary_objective_ids.is_empty():
		return false
	for objective_id: StringName in primary_objective_ids:
		var state := objective(objective_id)
		if state == null or not state.is_complete():
			return false
	return true


func duplicate_state() -> MissionRuntimeState:
	return from_dictionary(to_dictionary())


func equivalent_to(other: MissionRuntimeState) -> bool:
	if other == null:
		return false
	return CanonicalDataHasher.sha256_hex(to_dictionary()) == CanonicalDataHasher.sha256_hex(other.to_dictionary())


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if mission_instance_id.is_empty():
		errors.append("Mission runtime state has no mission instance ID.")
	if mission_definition_id.is_empty():
		errors.append("Mission runtime state has no mission definition ID.")
	if source_setup_hash.length() != 64:
		errors.append("Mission runtime state has no valid setup hash.")
	for objective_id: StringName in primary_objective_ids + optional_objective_ids:
		if objective(objective_id) == null:
			errors.append("Mission runtime state is missing objective %s." % objective_id)
	return errors


func to_dictionary() -> Dictionary:
	var objective_entries: Array[Dictionary] = []
	for objective_state: MissionObjectiveState in objectives():
		objective_entries.append(objective_state.to_dictionary())
	return {
		"mission_instance_id": String(mission_instance_id),
		"mission_definition_id": String(mission_definition_id),
		"source_setup_hash": source_setup_hash,
		"primary_objective_ids": _strings(primary_objective_ids),
		"optional_objective_ids": _strings(optional_objective_ids),
		"objectives": objective_entries,
		"notoriety_preview_lines": notoriety_preview_lines.duplicate(),
		"important_event_ids": _strings(important_event_ids),
		"resolution_locked": resolution_locked,
	}


static func from_dictionary(data: Dictionary) -> MissionRuntimeState:
	var result := MissionRuntimeState.new()
	result.mission_instance_id = StringName(data.get("mission_instance_id", ""))
	result.mission_definition_id = StringName(data.get("mission_definition_id", ""))
	result.source_setup_hash = String(data.get("source_setup_hash", ""))
	for raw_id: Variant in data.get("primary_objective_ids", []):
		result.primary_objective_ids.append(StringName(raw_id))
	for raw_id: Variant in data.get("optional_objective_ids", []):
		result.optional_objective_ids.append(StringName(raw_id))
	for raw_objective: Variant in data.get("objectives", []):
		if raw_objective is Dictionary:
			var objective_state := MissionObjectiveState.from_dictionary(raw_objective as Dictionary)
			result.objectives_by_id[objective_state.objective_id] = objective_state
	for raw_line: Variant in data.get("notoriety_preview_lines", []):
		result.notoriety_preview_lines.append(String(raw_line))
	for raw_id: Variant in data.get("important_event_ids", []):
		result.important_event_ids.append(StringName(raw_id))
	result.resolution_locked = bool(data.get("resolution_locked", false))
	return result


static func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result
