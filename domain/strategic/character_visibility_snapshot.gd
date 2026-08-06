class_name CharacterVisibilitySnapshot
extends RefCounted

var character_id: StringName = &""
var display_name: String = ""
var base_visibility: int = 1
var modifier_lines: Array[Dictionary] = []
var final_visibility: int = 1
var equipment_revision: int = 0


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if character_id.is_empty():
		errors.append("Character visibility snapshot has no character ID.")
	if final_visibility < 0:
		errors.append("Character visibility snapshot %s is negative." % character_id)
	var calculated: int = base_visibility
	for line: Dictionary in modifier_lines:
		calculated += int(line.get("value", 0))
	if calculated != final_visibility:
		errors.append(
			"Character visibility snapshot %s does not match its displayed entries."
			% character_id
		)
	return errors


func explanation_lines() -> Array[String]:
	var result: Array[String] = []
	result.append("Base humanoid presence %+d" % base_visibility)
	for line: Dictionary in modifier_lines:
		result.append("%s %+d" % [String(line.get("label", "Visibility modifier")), int(line.get("value", 0))])
	return result


func to_dictionary() -> Dictionary:
	return {
		"character_id": String(character_id),
		"display_name": display_name,
		"base_visibility": base_visibility,
		"modifier_lines": modifier_lines.duplicate(true),
		"final_visibility": final_visibility,
		"equipment_revision": equipment_revision,
	}


static func from_dictionary(data: Dictionary) -> CharacterVisibilitySnapshot:
	var result := CharacterVisibilitySnapshot.new()
	result.character_id = StringName(data.get("character_id", ""))
	result.display_name = String(data.get("display_name", ""))
	result.base_visibility = maxi(0, int(data.get("base_visibility", 1)))
	var raw_lines: Variant = data.get("modifier_lines", [])
	if raw_lines is Array:
		for raw_line: Variant in raw_lines as Array:
			if raw_line is Dictionary:
				result.modifier_lines.append((raw_line as Dictionary).duplicate(true))
	result.final_visibility = maxi(0, int(data.get("final_visibility", result.base_visibility)))
	result.equipment_revision = maxi(0, int(data.get("equipment_revision", 0)))
	return result
