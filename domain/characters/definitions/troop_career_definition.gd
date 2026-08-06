class_name TroopCareerDefinition
extends Resource

@export var career_id: StringName = &""
@export var base_class_id: StringName = &""
@export var archetype_id: StringName = &""
@export var base_henchman_type_id: StringName = &""
@export var base_recruitment_definition_id: StringName = &""
@export var stage_ids: Array[StringName] = []
@export var signature_facility_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if career_id.is_empty():
		errors.append("Troop career has no ID.")
	if base_class_id.is_empty():
		errors.append("Troop career %s has no base class." % career_id)
	if base_henchman_type_id.is_empty():
		errors.append("Troop career %s has no base henchman type." % career_id)
	if stage_ids.is_empty():
		errors.append("Troop career %s has no prestige stages." % career_id)
	var seen: Dictionary = {}
	for stage_id: StringName in stage_ids:
		if stage_id.is_empty() or seen.has(stage_id):
			errors.append("Troop career %s has an empty or repeated stage." % career_id)
		seen[stage_id] = true
	return errors
