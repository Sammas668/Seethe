class_name CharacterModifierDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Unnamed Modifier"
@export_multiline var description: String = ""
@export var ability_modifiers: Dictionary = {}
@export var stat_modifiers: Dictionary = {}
@export var granted_action_ids: Array[StringName] = []
@export var sheet_condition_text: String = ""


func ability_modifier(abbreviation: String) -> int:
	return int(ability_modifiers.get(abbreviation, 0))


func stat_modifier(stat_id: StringName) -> int:
	return int(stat_modifiers.get(String(stat_id), 0))


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Character modifier has an empty ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Character modifier %s has an empty display name." % id)
	return errors
