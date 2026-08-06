class_name DefenceProfile
extends Resource

@export var id: StringName = &""
@export var display_name: String = "No Armour"
@export var armour_class_bonus: int = 0
@export var defence_tags: Array[StringName] = []
@export_multiline var notes: String = ""


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Defence profile has an empty ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Defence profile %s has an empty display name." % id)
	return errors
