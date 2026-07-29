class_name TacticalInventoryTransferPreview
extends RefCounted

var success: bool = false
var reason: String = ""
var action_name: String = ""
var item_name: String = ""
var action_cost: ActionCost
var requires_quick_action: bool = false
var provokes: bool = false
var cost_feet: int = 0
var remaining_capacity_after: int = 0
var plan: TacticalInventoryTransferPlan


static func accepted(
		action_name_value: String,
		item_name_value: String,
		action_cost_value: ActionCost,
		requires_quick_value: bool,
		provokes_value: bool,
		cost_feet_value: int,
		remaining_after_value: int,
		plan_value: TacticalInventoryTransferPlan
) -> TacticalInventoryTransferPreview:
	var preview := TacticalInventoryTransferPreview.new()
	preview.success = true
	preview.action_name = action_name_value
	preview.item_name = item_name_value
	preview.action_cost = action_cost_value
	preview.requires_quick_action = requires_quick_value
	preview.provokes = provokes_value
	preview.cost_feet = cost_feet_value
	preview.remaining_capacity_after = remaining_after_value
	preview.plan = plan_value
	return preview


static func rejected(reason_value: String) -> TacticalInventoryTransferPreview:
	var preview := TacticalInventoryTransferPreview.new()
	preview.success = false
	preview.reason = reason_value
	return preview
