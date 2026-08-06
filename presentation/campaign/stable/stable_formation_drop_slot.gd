class_name StableFormationDropSlot
extends Button

signal character_dropped(slot_id: StringName, character_id: StringName)

var slot_id: StringName = &""
var display_number: int = 0
var current_character_id: StringName = &""
var assignment_locked: bool = false


func configure(
		slot_id_value: StringName,
		display_number_value: int,
		character_id_value: StringName,
		character_name: String,
		locked: bool
) -> void:
	slot_id = slot_id_value
	display_number = display_number_value
	current_character_id = character_id_value
	assignment_locked = locked
	disabled = locked
	custom_minimum_size = Vector2(138, 62)
	text = "%d\n%s" % [
		display_number,
		character_name.to_upper() if not character_name.is_empty() else "EMPTY",
	]
	tooltip_text = (
		"Formation is locked while the expedition is away."
		if locked
		else "Drag a reserve here, or drag this occupied position onto another to swap them. Right-click clears it."
	)


func _get_drag_data(_position: Vector2) -> Variant:
	if assignment_locked or current_character_id.is_empty():
		return null
	var preview := Label.new()
	preview.text = text.replace("\n", " — ")
	preview.add_theme_font_size_override("font_size", 12)
	set_drag_preview(preview)
	return {
		"kind": "stable_character",
		"character_id": String(current_character_id),
		"source_slot_id": String(slot_id),
	}


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
	character_dropped.emit(
		slot_id,
		StringName((data as Dictionary).get("character_id", ""))
	)


func _gui_input(event: InputEvent) -> void:
	if (
		not assignment_locked
		and event is InputEventMouseButton
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT
		and (event as InputEventMouseButton).pressed
	):
		character_dropped.emit(slot_id, &"")
		accept_event()
