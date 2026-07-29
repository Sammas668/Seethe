class_name ActionDefinition
extends Resource

const COST_FREE: StringName = &"free"
const COST_MINOR: StringName = &"minor"
const COST_QUICK: StringName = &"quick"
const COST_HALF: StringName = &"half"
const COST_FULL: StringName = &"full"
const COST_FIXED: StringName = &"fixed"

@export var id: StringName = &""
@export var display_name: String = "Unnamed Action"
@export_multiline var description: String = ""
@export var action_cost_type: StringName = COST_HALF
@export var fixed_capacity_feet: int = 0
@export var provokes: bool = false
@export var action_tags: Array[StringName] = []


func resolved_cost() -> ActionCost:
	match action_cost_type:
		COST_FREE:
			return ActionCost.fixed_capacity(0)
		COST_MINOR:
			return ActionCost.minor_interaction()
		COST_QUICK:
			return ActionCost.quick_action()
		COST_HALF:
			return ActionCost.half_action()
		COST_FULL:
			return ActionCost.full_action()
		COST_FIXED:
			return ActionCost.fixed_capacity(maxi(0, fixed_capacity_feet))
		_:
			return ActionCost.half_action()


func cost_label() -> String:
	match action_cost_type:
		COST_FREE:
			return "Free"
		COST_MINOR:
			return "Minor Interaction"
		COST_QUICK:
			return "Quick Action"
		COST_HALF:
			return "Half Action"
		COST_FULL:
			return "Full Action"
		COST_FIXED:
			return "%d ft" % maxi(0, fixed_capacity_feet)
		_:
			return "Unknown Cost"


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Action definition has an empty ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Action %s has an empty display name." % id)
	if action_cost_type not in [
		COST_FREE,
		COST_MINOR,
		COST_QUICK,
		COST_HALF,
		COST_FULL,
		COST_FIXED,
	]:
		errors.append("Action %s has an unknown cost type." % id)
	if action_cost_type == COST_FIXED and fixed_capacity_feet < 0:
		errors.append("Action %s has a negative fixed cost." % id)
	return errors
