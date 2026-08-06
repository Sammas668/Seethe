class_name StablePassengerDrag
extends Button

var character_id: StringName = &""


func configure(character_id_value: StringName, display_name: String, status_text: String) -> void:
	character_id = character_id_value
	text = "%s — %s" % [display_name, status_text]
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size.y = 38
	tooltip_text = "Drag this squad member onto a numbered deployment position."


func _get_drag_data(_position: Vector2) -> Variant:
	if character_id.is_empty() or disabled:
		return null
	var preview := Label.new()
	preview.text = text
	preview.add_theme_font_size_override("font_size", 12)
	set_drag_preview(preview)
	return {
		"kind": "stable_character",
		"character_id": String(character_id),
	}
