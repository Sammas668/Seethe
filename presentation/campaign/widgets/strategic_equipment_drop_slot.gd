class_name StrategicEquipmentDropSlot
extends Button

signal item_drop_requested(item_id: StringName, target_container_id: StringName)

var target_container_id: StringName = &""
var source_kind: StringName = &""
var source_item_id: StringName = &""
var source_item_name: String = ""
var source_footprint: Vector2i = Vector2i.ONE


func configure(container_id: StringName, label_text: String) -> void:
	target_container_id = container_id
	text = label_text
	mouse_filter = Control.MOUSE_FILTER_STOP


func configure_drag_source(
		source_kind_value: StringName,
		item_id_value: StringName,
		item_name_value: String,
		footprint_value: Vector2i = Vector2i.ONE
) -> void:
	source_kind = source_kind_value
	source_item_id = item_id_value
	source_item_name = item_name_value
	source_footprint = footprint_value


func _get_drag_data(_position: Vector2) -> Variant:
	if source_item_id.is_empty():
		return null
	var preview := Label.new()
	preview.text = source_item_name
	preview.custom_minimum_size = Vector2(120, 36)
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	set_drag_preview(preview)
	return {
		"source_kind": source_kind,
		"source_item_id": source_item_id,
		"item_name": source_item_name,
		"footprint": source_footprint,
	}


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and not StringName((data as Dictionary).get("source_item_id", "")).is_empty()


func _drop_data(_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	var item_id := StringName((data as Dictionary).get("source_item_id", ""))
	if not item_id.is_empty():
		item_drop_requested.emit(item_id, target_container_id)
