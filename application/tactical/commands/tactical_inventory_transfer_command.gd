class_name TacticalInventoryTransferCommand
extends RefCounted

var unit_id: StringName
var source_kind: StringName
var source_item_id: StringName
var target_kind: StringName
var target_cell_index: int


func _init(
		unit_id_value: StringName = &"",
		source_kind_value: StringName = &"",
		source_item_id_value: StringName = &"",
		target_kind_value: StringName = &"",
		target_cell_index_value: int = -1
) -> void:
	unit_id = unit_id_value
	source_kind = source_kind_value
	source_item_id = source_item_id_value
	target_kind = target_kind_value
	target_cell_index = target_cell_index_value
