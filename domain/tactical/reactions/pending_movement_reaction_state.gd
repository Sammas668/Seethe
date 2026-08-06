class_name PendingMovementReactionState
extends RefCounted

const CONTINUATION_ENEMY_MOVEMENT: StringName = &"enemy_movement"
const CONTINUATION_ENEMY_PROVOKING_ACTION: StringName = &"enemy_provoking_action"
const CONTINUATION_STANDALONE_REACTION: StringName = &"standalone_reaction"

var movement_action_id: StringName = &""
var mover_unit_id: StringName = &""
var controller_id: StringName = &""

var full_path: Array[Vector2i] = []
var committed_prefix: Array[Vector2i] = []
var trigger_path_index: int = -1
var next_step_index: int = -1
var current_position: Vector2i = Vector2i(-1, -1)
var movement_mode: StringName = &"normal"
var movement_spent_feet: int = 0
var diagonal_steps_spent: int = 0

var pending_step_origin: Vector2i = Vector2i(-1, -1)
var pending_step_destination: Vector2i = Vector2i(-1, -1)
var pending_step_cost_feet: int = 0
var pending_step_diagonal_steps: int = 0
var pending_step_cost_prepaid: bool = false
var pending_timing_kind: StringName = &""

var candidate: ReactionCandidate
var request: ReactionDecisionRequest
var decision_resolved: bool = false
var resolved_choice: StringName = &""

var continuation_kind: StringName = &""
var continuation_sequence_id: StringName = &""
var continuation_actor_id: StringName = &""
var continuation_payload: Dictionary = {}
var suppressed_candidate_keys: Dictionary = {}
var source_revision: int = -1


func has_unresolved_decision() -> bool:
	return request != null and not decision_resolved and not request.resolved


func is_for_movement(action_id: StringName) -> bool:
	return not action_id.is_empty() and movement_action_id == action_id


func candidate_is_suppressed(key: String) -> bool:
	return suppressed_candidate_keys.has(key)


func duplicate_state() -> PendingMovementReactionState:
	var result := PendingMovementReactionState.new()
	result.movement_action_id = movement_action_id
	result.mover_unit_id = mover_unit_id
	result.controller_id = controller_id
	result.full_path = full_path.duplicate()
	result.committed_prefix = committed_prefix.duplicate()
	result.trigger_path_index = trigger_path_index
	result.next_step_index = next_step_index
	result.current_position = current_position
	result.movement_mode = movement_mode
	result.movement_spent_feet = movement_spent_feet
	result.diagonal_steps_spent = diagonal_steps_spent
	result.pending_step_origin = pending_step_origin
	result.pending_step_destination = pending_step_destination
	result.pending_step_cost_feet = pending_step_cost_feet
	result.pending_step_diagonal_steps = pending_step_diagonal_steps
	result.pending_step_cost_prepaid = pending_step_cost_prepaid
	result.pending_timing_kind = pending_timing_kind
	result.candidate = candidate
	result.request = request
	result.decision_resolved = decision_resolved
	result.resolved_choice = resolved_choice
	result.continuation_kind = continuation_kind
	result.continuation_sequence_id = continuation_sequence_id
	result.continuation_actor_id = continuation_actor_id
	result.continuation_payload = continuation_payload.duplicate(true)
	result.suppressed_candidate_keys = suppressed_candidate_keys.duplicate(true)
	result.source_revision = source_revision
	return result
