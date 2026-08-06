class_name StableReserveDropZone
extends PanelContainer

signal character_removed(character_id: StringName)

var assignment_locked: bool = false


func configure(locked: bool) -> void:
	assignment_locked = locked
	custom_minimum_size = Vector2(0, 48)
	tooltip_text = (
		"Formation is locked while the expedition is away."
		if locked
		else "Drag a deployed squad member here to return them to reserve."
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var label := Label.new()
	label.text = "RESERVES — DROP HERE TO REMOVE FROM DEPLOYMENT"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("b9b5a7"))
	margin.add_child(label)


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return (
		not assignment_locked
		and data is Dictionary
		and String((data as Dictionary).get("kind", "")) == "stable_character"
		and not StringName((data as Dictionary).get("character_id", "")).is_empty()
	)


func _drop_data(_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_position, data):
		return
	character_removed.emit(StringName((data as Dictionary).get("character_id", "")))
