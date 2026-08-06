class_name TacticalTransactionSnapshot
extends RefCounted

var root_revision: int = 0
var occupancy_revision: int = 0
var visibility_blocker_revision: int = 0
var knowledge_revision: int = 0
var environment_geometry_revision: int = 0
var mission_resolution_locked: bool = false
var resolved_mission_result_id: StringName = &""
var pending_movement_reaction: PendingMovementReactionState
var occupancy_signature: String = ""
var visibility_blocker_signature: String = ""


static func capture(
	state: TacticalState,
	include_signatures: bool = true
) -> TacticalTransactionSnapshot:
	var result := TacticalTransactionSnapshot.new()
	if state == null:
		return result
	result.root_revision = state.revision
	result.occupancy_revision = state.occupancy_revision
	result.visibility_blocker_revision = state.visibility_blocker_revision
	result.knowledge_revision = (
		state.knowledge_state.revision if state.knowledge_state != null else 0
	)
	result.environment_geometry_revision = (
		state.environment_state.geometry_revision
		if state.environment_state != null
		else 0
	)
	result.mission_resolution_locked = state.mission_resolution_locked
	result.resolved_mission_result_id = state.resolved_mission_result_id
	result.pending_movement_reaction = (
		state.pending_movement_reaction.duplicate_state()
		if state.pending_movement_reaction != null
		else null
	)
	if include_signatures:
		result.occupancy_signature = state.authoritative_occupancy_signature()
		result.visibility_blocker_signature = (
			state.authoritative_visibility_blocker_signature_from_occupancy(
				result.occupancy_signature
			)
		)
	return result


func restore_revisions(state: TacticalState) -> void:
	if state == null:
		return
	state.revision = root_revision
	state.occupancy_revision = occupancy_revision
	state.visibility_blocker_revision = visibility_blocker_revision
	if state.knowledge_state != null:
		state.knowledge_state.revision = knowledge_revision
	if state.environment_state != null:
		state.environment_state.geometry_revision = environment_geometry_revision
	state.mission_resolution_locked = mission_resolution_locked
	state.resolved_mission_result_id = resolved_mission_result_id
	state.pending_movement_reaction = (
		pending_movement_reaction.duplicate_state()
		if pending_movement_reaction != null
		else null
	)
