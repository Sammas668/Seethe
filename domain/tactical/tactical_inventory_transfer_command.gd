class_name TacticalInventoryTransferCommand
extends RefCounted

var unit_id: StringName
var item_id: StringName
var source_slot_id: StringName
var target_slot_id: StringName


func _init(
        unit_id_value: StringName = &"",
        item_id_value: StringName = &"",
        source_slot_value: StringName = &"",
        target_slot_value: StringName = &""
) -> void:
    unit_id = unit_id_value
    item_id = item_id_value
    source_slot_id = source_slot_value
    target_slot_id = target_slot_value
