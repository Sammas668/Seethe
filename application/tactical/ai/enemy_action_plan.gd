class_name EnemyActionPlan
extends RefCounted

const KIND_COMBAT: StringName = &"combat"
const KIND_SEARCH: StringName = &"search"
const KIND_RETURN_TO_TASK: StringName = &"return_to_task"

var _valid: bool = false
var _reason: String = ""
var _kind: StringName = KIND_COMBAT
var _action_id: StringName = &""
var _target_id: StringName = &""
var _move_destination: Vector2i = Vector2i.ZERO
var _move_required: bool = false
var _attack_after_move: bool = false
var _path_cost_feet: int = 0
var _move_path: Array[Vector2i] = []
var _memory_unit_id: StringName = &""
var _goal_position: Vector2i = Vector2i(-1, -1)
var _goal_reached: bool = false
var _finalized: bool = false

var valid: bool:
	get:
		return _valid
var reason: String:
	get:
		return _reason
var kind: StringName:
	get:
		return _kind
var action_id: StringName:
	get:
		return _action_id
var target_id: StringName:
	get:
		return _target_id
var move_destination: Vector2i:
	get:
		return _move_destination
var move_required: bool:
	get:
		return _move_required
var attack_after_move: bool:
	get:
		return _attack_after_move
var path_cost_feet: int:
	get:
		return _path_cost_feet
var move_path: Array[Vector2i]:
	get:
		return _move_path.duplicate()
var memory_unit_id: StringName:
	get:
		return _memory_unit_id
var goal_position: Vector2i:
	get:
		return _goal_position
var goal_reached: bool:
	get:
		return _goal_reached


func configure_success(
		action_id_value: StringName,
		target_id_value: StringName,
		move_destination_value: Vector2i,
		move_required_value: bool,
		attack_after_move_value: bool,
		path_cost_feet_value: int,
		move_path_value: Array[Vector2i] = []
) -> void:
	if _finalized:
		return
	_valid = true
	_kind = KIND_COMBAT
	_action_id = action_id_value
	_target_id = target_id_value
	_move_destination = move_destination_value
	_move_required = move_required_value
	_attack_after_move = attack_after_move_value
	_path_cost_feet = maxi(0, path_cost_feet_value)
	_move_path = move_path_value.duplicate()
	_finalized = true


func configure_search(
		memory_unit_id_value: StringName,
		goal_position_value: Vector2i,
		move_destination_value: Vector2i,
		move_required_value: bool,
		goal_reached_value: bool,
		path_cost_feet_value: int,
		move_path_value: Array[Vector2i] = []
) -> void:
	if _finalized:
		return
	_valid = true
	_kind = KIND_SEARCH
	_memory_unit_id = memory_unit_id_value
	_goal_position = goal_position_value
	_move_destination = move_destination_value
	_move_required = move_required_value
	_goal_reached = goal_reached_value
	_path_cost_feet = maxi(0, path_cost_feet_value)
	_move_path = move_path_value.duplicate()
	_finalized = true


func configure_return_to_task(
		goal_position_value: Vector2i,
		move_destination_value: Vector2i,
		move_required_value: bool,
		goal_reached_value: bool,
		path_cost_feet_value: int,
		move_path_value: Array[Vector2i] = []
) -> void:
	if _finalized:
		return
	_valid = true
	_kind = KIND_RETURN_TO_TASK
	_goal_position = goal_position_value
	_move_destination = move_destination_value
	_move_required = move_required_value
	_goal_reached = goal_reached_value
	_path_cost_feet = maxi(0, path_cost_feet_value)
	_move_path = move_path_value.duplicate()
	_finalized = true


func configure_failure(reason_value: String) -> void:
	if _finalized:
		return
	_valid = false
	_reason = reason_value
	_finalized = true
