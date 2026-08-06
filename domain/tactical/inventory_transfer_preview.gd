class_name InventoryTransferPreview
extends RefCounted

var success: bool = false
var reason: String = ""
var action_name: String = ""
var action_cost: ActionCost
var cost_feet: int = 0
var remaining_after: int = 0


static func accepted(
		action_name_value: String,
		action_cost_value: ActionCost,
		cost_feet_value: int,
		remaining_after_value: int
) -> InventoryTransferPreview:
	var result := InventoryTransferPreview.new()
	result.success = true
	result.action_name = action_name_value
	result.action_cost = action_cost_value
	result.cost_feet = cost_feet_value
	result.remaining_after = remaining_after_value
	return result


static func rejected(reason_value: String) -> InventoryTransferPreview:
	var result := InventoryTransferPreview.new()
	result.success = false
	result.reason = reason_value
	return result
