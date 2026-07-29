class_name MovementPathResult
extends RefCounted

var success: bool = false
var path: Array[Vector2i] = []
var cost_feet: int = 0
var diagonal_steps: int = 0
var failure_reason: String = ""


static func completed(
		path_value: Array[Vector2i],
		cost_value: int,
		diagonal_steps_value: int
) -> MovementPathResult:
	var result := MovementPathResult.new()
	result.success = true
	result.path = path_value.duplicate()
	result.cost_feet = cost_value
	result.diagonal_steps = diagonal_steps_value
	return result


static func failed(reason: String) -> MovementPathResult:
	var result := MovementPathResult.new()
	result.failure_reason = reason
	return result
