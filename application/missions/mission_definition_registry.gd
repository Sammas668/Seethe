class_name MissionDefinitionRegistry
extends RefCounted

const AUTHORED_MISSIONS: Array[MissionDefinition] = [
	preload("res://content/missions/farm_storehouse/life_farm_storehouse_raid_01.tres"),
]


static func all_definitions() -> Array[MissionDefinition]:
	var result: Array[MissionDefinition] = []
	for definition: MissionDefinition in AUTHORED_MISSIONS:
		if definition != null:
			result.append(definition)
	return result


static func definition(definition_id: StringName) -> MissionDefinition:
	for candidate: MissionDefinition in AUTHORED_MISSIONS:
		if candidate != null and candidate.mission_definition_id == definition_id:
			return candidate
	return null


static func validate_registry() -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for definition: MissionDefinition in AUTHORED_MISSIONS:
		if definition == null:
			errors.append("Mission registry contains a missing definition.")
			continue
		if seen.has(definition.mission_definition_id):
			errors.append("Mission registry duplicates %s." % definition.mission_definition_id)
		seen[definition.mission_definition_id] = true
		errors.append_array(definition.validate_definition())
	return errors
