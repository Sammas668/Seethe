class_name ActionBudgetState
extends RefCounted

var maximum_turn_capacity_feet: int
var remaining_turn_capacity_feet: int
var normal_capacity_spent_feet: int
var quick_action_available: bool
var reaction_available: bool
# A normal attack may be used only once per activation. Remaining movement
# capacity may still be spent after that attack. Full Attack uses its own
# full-action sequence and does not consume this ordinary-attack allowance.
var ordinary_attack_available: bool
var ended_activation: bool


func _init(maximum_capacity_value: int = 30) -> void:
	maximum_turn_capacity_feet = max(5, maximum_capacity_value)
	refresh_for_new_round()


func refresh_for_new_round() -> void:
	remaining_turn_capacity_feet = maximum_turn_capacity_feet
	normal_capacity_spent_feet = 0
	quick_action_available = true
	reaction_available = true
	ordinary_attack_available = true
	ended_activation = false


func spend_normal_capacity(feet: int) -> void:
	var amount := clampi(feet, 0, remaining_turn_capacity_feet)
	remaining_turn_capacity_feet -= amount
	normal_capacity_spent_feet += amount


func spend_quick_action() -> void:
	quick_action_available = false


func spend_ordinary_attack() -> void:
	ordinary_attack_available = false


func has_spent_normal_capacity() -> bool:
	return normal_capacity_spent_feet > 0


func has_any_option_remaining() -> bool:
	return remaining_turn_capacity_feet > 0 or quick_action_available


func is_visibly_finished() -> bool:
	return ended_activation or not has_any_option_remaining()
