class_name SpendActionCommand
extends RefCounted

var unit_id: StringName
var action_name: String
var action_cost: ActionCost


func _init(
        unit_id_value: StringName = &"",
        action_name_value: String = "Test Action",
        action_cost_value: ActionCost = null
) -> void:
    unit_id = unit_id_value
    action_name = action_name_value
    action_cost = action_cost_value if action_cost_value != null else ActionCost.half_action()
