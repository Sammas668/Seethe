class_name TacticalMovementResolutionCoordinator
extends RefCounted

const CONTROLLER_AI: StringName = &"ai"
const CONTROLLER_PLAYER: StringName = &"player"

var _reaction_service: TacticalReactionService


func configure(reaction_service: TacticalReactionService) -> void:
	_reaction_service = reaction_service


func first_reaction_boundary(
		mover_id: StringName,
		planned_path: Array[Vector2i],
		movement_kind: StringName,
		movement_action_id: StringName,
		controller_kind: StringName
) -> Dictionary:
	if _reaction_service == null:
		return {
			"candidate": null,
			"prefix_path": planned_path.duplicate(),
			"movement_action_id": movement_action_id,
		}
	if controller_kind == CONTROLLER_PLAYER:
		return _reaction_service.first_player_reaction_for_path(
			mover_id,
			planned_path,
			movement_kind,
			movement_action_id
		)
	return _reaction_service.first_ai_reaction_for_path(
		mover_id,
		planned_path,
		movement_kind,
		movement_action_id
	)


func candidates_for_step(
		mover_id: StringName,
		origin: Vector2i,
		destination: Vector2i,
		path_index: int,
		movement_kind: StringName,
		movement_action_id: StringName
) -> Array[ReactionCandidate]:
	if _reaction_service == null:
		return []
	return _reaction_service.candidates_for_movement_step(
		mover_id,
		origin,
		destination,
		path_index,
		movement_kind,
		movement_action_id
	)


func prefix_before_step(
		planned_path: Array[Vector2i],
		step_index: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var end_index: int = clampi(step_index - 1, 0, planned_path.size() - 1)
	for index: int in range(0, end_index + 1):
		result.append(planned_path[index])
	return result


func continuation_from_entered_step(
		planned_path: Array[Vector2i],
		step_index: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if planned_path.is_empty():
		return result
	var start_index: int = clampi(step_index, 0, planned_path.size() - 1)
	for index: int in range(start_index, planned_path.size()):
		result.append(planned_path[index])
	return result


func build_pending_state(
		mover: TacticalUnitState,
		planned_path: Array[Vector2i],
		committed_prefix: Array[Vector2i],
		candidate: ReactionCandidate,
		movement_action_id: StringName,
		continuation_kind: StringName,
		continuation_payload: Dictionary,
		step_cost_feet: int = 0,
		step_diagonal_steps: int = 0,
		step_cost_prepaid: bool = false,
		source_revision: int = -1
) -> PendingMovementReactionState:
	var pending := PendingMovementReactionState.new()
	pending.movement_action_id = movement_action_id
	pending.mover_unit_id = mover.unit_id if mover != null else &""
	pending.controller_id = mover.controller_type if mover != null else &""
	pending.full_path = planned_path.duplicate()
	pending.committed_prefix = committed_prefix.duplicate()
	pending.trigger_path_index = candidate.path_index if candidate != null else -1
	pending.next_step_index = -1
	if candidate != null:
		pending.next_step_index = candidate.path_index
		if candidate.timing_kind == ReactionCandidate.TIMING_AFTER_ENTRY:
			pending.next_step_index += 1
	pending.current_position = mover.grid_position if mover != null else Vector2i(-1, -1)
	pending.pending_step_origin = candidate.trigger_origin if candidate != null else Vector2i(-1, -1)
	pending.pending_step_destination = (
		candidate.trigger_destination if candidate != null else Vector2i(-1, -1)
	)
	pending.pending_step_cost_feet = step_cost_feet
	pending.pending_step_diagonal_steps = step_diagonal_steps
	pending.pending_step_cost_prepaid = step_cost_prepaid
	pending.pending_timing_kind = candidate.timing_kind if candidate != null else &""
	pending.candidate = candidate
	pending.continuation_kind = continuation_kind
	pending.continuation_sequence_id = movement_action_id
	pending.continuation_actor_id = pending.mover_unit_id
	pending.continuation_payload = continuation_payload.duplicate(true)
	pending.source_revision = source_revision
	return pending
