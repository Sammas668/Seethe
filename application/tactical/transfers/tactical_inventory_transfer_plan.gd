class_name TacticalInventoryTransferPlan
extends RefCounted

var item_id: StringName
var unit_id: StringName
var source_location: TacticalItemLocationState
var target_location: TacticalItemLocationState
var action_cost: ActionCost
var requires_quick_action: bool
var provokes: bool
var expected_state_revision: int
var resulting_weight_lb: float
var action_name: String


func _init(
		item_id_value: StringName = &"",
		unit_id_value: StringName = &"",
		source_location_value: TacticalItemLocationState = null,
		target_location_value: TacticalItemLocationState = null,
		action_cost_value: ActionCost = null,
		requires_quick_action_value: bool = false,
		provokes_value: bool = false,
		expected_state_revision_value: int = 0,
		resulting_weight_value: float = 0.0,
		action_name_value: String = ""
) -> void:
	item_id = item_id_value
	unit_id = unit_id_value
	source_location = source_location_value
	target_location = target_location_value
	action_cost = action_cost_value
	requires_quick_action = requires_quick_action_value
	provokes = provokes_value
	expected_state_revision = expected_state_revision_value
	resulting_weight_lb = resulting_weight_value
	action_name = action_name_value
