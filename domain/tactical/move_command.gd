class_name MoveCommand
extends RefCounted

var unit_id: StringName
var destination: Vector2i


func _init(
        unit_id_value: StringName = &"",
        destination_value: Vector2i = Vector2i.ZERO
) -> void:
    unit_id = unit_id_value
    destination = destination_value
