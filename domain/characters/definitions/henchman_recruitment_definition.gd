class_name HenchmanRecruitmentDefinition
extends Resource

@export var recruitment_id: StringName = &""
@export var base_class_id: StringName = &""
@export var career_id: StringName = &""
@export var resulting_character_template_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var starting_level: int = 1
@export var starting_xp: int = 0
@export var required_protagonist_class_level: int = 1
@export var required_facility_id: StringName = &""
@export var resource_costs: Dictionary = {}
@export var starting_loadout_id: StringName = &""
@export var duration_ticks: int = 0
@export var roster_capacity_cost: int = 1
@export var market_offer_count: int = 4
@export var name_pool_id: StringName = &""
@export var portrait_pool_id: StringName = &""


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if recruitment_id.is_empty():
		errors.append("Recruitment definition has no ID.")
	if base_class_id.is_empty():
		errors.append("Recruitment %s has no base class." % recruitment_id)
	if career_id.is_empty():
		errors.append("Recruitment %s has no career." % recruitment_id)
	if resulting_character_template_id.is_empty():
		errors.append("Recruitment %s has no character template." % recruitment_id)
	if starting_level != 1:
		errors.append("Ordinary recruitment %s must start at Level 1." % recruitment_id)
	if duration_ticks < 0:
		errors.append("Recruitment %s has invalid duration." % recruitment_id)
	if market_offer_count <= 0:
		errors.append("Recruitment %s has no market offers." % recruitment_id)
	return errors
