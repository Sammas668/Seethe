class_name Stage45FAuthoritativeInterruptedMovementTests
extends RefCounted


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_operation_result_states(failures)
	_test_coordinator_path_boundaries(failures)
	_test_pending_state_is_authoritative_and_copyable(failures)
	_test_pending_command_gate(failures)
	_test_failed_commit_restores_all_revision_counters(failures)
	_test_known_invalidation_policies(failures)
	return failures


static func _test_operation_result_states(failures: Array[String]) -> void:
	var committed := OperationResult.committed(&"payload", "Committed.", 7)
	var no_change := OperationResult.no_change(null, "No change.")
	var pending := OperationResult.pending(&"reaction_pending", null, "Pending.", 8)
	var deferred := OperationResult.deferred(null, "Deferred.", 8)
	_expect(committed.success, "Committed result must succeed.", failures)
	_expect(committed.commit_status == OperationResult.STATUS_COMMITTED, "Committed status is wrong.", failures)
	_expect(committed.committed_revision == 7, "Committed revision was not retained.", failures)
	_expect(no_change.commit_status == OperationResult.STATUS_NO_CHANGE, "No-change status is wrong.", failures)
	_expect(pending.commit_status == OperationResult.STATUS_PENDING, "Pending status is wrong.", failures)
	_expect(deferred.commit_status == OperationResult.STATUS_DEFERRED, "Deferred status is wrong.", failures)


static func _test_coordinator_path_boundaries(failures: Array[String]) -> void:
	var coordinator := TacticalMovementResolutionCoordinator.new()
	var path: Array[Vector2i] = [
		Vector2i(2, 2),
		Vector2i(3, 2),
		Vector2i(4, 2),
		Vector2i(5, 2),
	]
	var prefix: Array[Vector2i] = coordinator.prefix_before_step(path, 2)
	var continuation: Array[Vector2i] = coordinator.continuation_from_entered_step(path, 2)
	_expect(prefix == [Vector2i(2, 2), Vector2i(3, 2)], "Before-entry prefix must end on the origin tile.", failures)
	_expect(continuation == [Vector2i(4, 2), Vector2i(5, 2)], "After-entry continuation must begin on the entered tile.", failures)


static func _test_pending_state_is_authoritative_and_copyable(failures: Array[String]) -> void:
	var state := TacticalState.new()
	var mover := TacticalUnitState.new(&"mover", "Mover", Vector2i(2, 2), 30, &"enemy")
	var reactor := TacticalUnitState.new(&"reactor", "Reactor", Vector2i(3, 2), 30, &"player")
	state.units_by_id[mover.unit_id] = mover
	state.units_by_id[reactor.unit_id] = reactor
	var candidate := ReactionCandidate.new()
	candidate.reaction_kind = ReactionCandidate.KIND_ATTACK_OF_OPPORTUNITY
	candidate.source_unit_id = reactor.unit_id
	candidate.target_unit_id = mover.unit_id
	candidate.movement_action_id = &"movement.test"
	candidate.trigger_origin = Vector2i(2, 2)
	candidate.trigger_destination = Vector2i(1, 2)
	candidate.target_position = candidate.trigger_origin
	candidate.path_index = 1
	candidate.timing_kind = ReactionCandidate.TIMING_BEFORE_ENTRY
	candidate.legal = true
	var request := ReactionDecisionRequest.new()
	request.request_id = &"reaction.request.test"
	request.candidate = candidate
	request.reacting_unit_id = reactor.unit_id
	request.triggering_unit_id = mover.unit_id
	var pending := PendingMovementReactionState.new()
	pending.movement_action_id = &"movement.test"
	pending.mover_unit_id = mover.unit_id
	pending.controller_id = mover.controller_type
	pending.full_path = [Vector2i(2, 2), Vector2i(1, 2)]
	pending.committed_prefix = [Vector2i(2, 2)]
	pending.trigger_path_index = 1
	pending.next_step_index = 1
	pending.current_position = Vector2i(2, 2)
	pending.pending_step_origin = Vector2i(2, 2)
	pending.pending_step_destination = Vector2i(1, 2)
	pending.pending_timing_kind = ReactionCandidate.TIMING_BEFORE_ENTRY
	pending.candidate = candidate
	pending.request = request
	pending.continuation_kind = PendingMovementReactionState.CONTINUATION_ENEMY_MOVEMENT
	pending.source_revision = state.revision
	state.pending_movement_reaction = pending
	_expect(state.has_pending_tactical_decision(), "TacticalState must own the unresolved decision.", failures)
	_expect(state.validate_pending_reaction_invariants().is_empty(), "Valid pending movement state failed invariants.", failures)
	var copy: PendingMovementReactionState = pending.duplicate_state()
	copy.suppressed_candidate_keys["candidate"] = true
	_expect(not pending.suppressed_candidate_keys.has("candidate"), "Pending-state copy must isolate suppression changes.", failures)


static func _test_pending_command_gate(failures: Array[String]) -> void:
	var state := TacticalState.new()
	state.pending_movement_reaction = PendingMovementReactionState.new()
	var store := TacticalStateStore.new(state)
	var blocked := TacticalChangeSet.new(&"test_blocked_while_pending", state.revision, TacticalInvalidationContract.no_visual_change())
	blocked.set_commit_validation_policy(false, false)
	blocked.stage(
		func() -> bool:
			return true,
		func() -> void:
			pass,
		"Blocked mutation failed."
	)
	var blocked_result: OperationResult = store.commit(blocked)
	_expect(not blocked_result.success, "Unrelated command must be rejected while a decision is pending.", failures)
	_expect(blocked_result.code == &"pending_tactical_decision", "Pending gate returned the wrong failure code.", failures)
	var allowed := TacticalChangeSet.new(&"movement_reaction_updated", state.revision, TacticalInvalidationContract.pending_decision())
	allowed.set_allow_while_pending(true)
	allowed.set_commit_validation_policy(false, false)
	allowed.stage(
		func() -> bool:
			return true,
		func() -> void:
			pass,
		"Pending-safe mutation failed."
	)
	var allowed_result: OperationResult = store.commit(allowed)
	_expect(allowed_result.success, "Explicit pending-safe mutation must commit.", failures)
	_expect(allowed_result.commit_status == OperationResult.STATUS_COMMITTED, "Committed change set must report COMMITTED.", failures)


static func _test_failed_commit_restores_all_revision_counters(failures: Array[String]) -> void:
	var state := TacticalState.new()
	state.revision = 11
	state.occupancy_revision = 12
	state.visibility_blocker_revision = 13
	state.knowledge_state.revision = 14
	state.environment_state.geometry_revision = 15
	var changes := TacticalChangeSet.new(&"test_rejected_change", state.revision, TacticalInvalidationContract.no_visual_change())
	changes.set_commit_validation_policy(false, false)
	changes.stage(
		func() -> bool:
			state.occupancy_revision = 112
			state.visibility_blocker_revision = 113
			state.knowledge_state.revision = 114
			state.environment_state.geometry_revision = 115
			return true,
		func() -> void: pass,
		"Revision mutation failed."
	)
	changes.stage(
		func() -> bool:
			return false,
		func() -> void:
			pass,
		"Forced failure.",
		&"forced_failure"
	)
	var result: OperationResult = changes.execute(state)
	_expect(not result.success, "Forced transaction must fail.", failures)
	_expect(state.revision == 11, "Root tactical revision changed after rollback.", failures)
	_expect(state.occupancy_revision == 12, "Occupancy revision changed after rollback.", failures)
	_expect(state.visibility_blocker_revision == 13, "Visibility-blocker revision changed after rollback.", failures)
	_expect(state.knowledge_state.revision == 14, "Knowledge revision changed after rollback.", failures)
	_expect(state.environment_state.geometry_revision == 15, "Geometry revision changed after rollback.", failures)


static func _test_known_invalidation_policies(failures: Array[String]) -> void:
	var inventory := TacticalInvalidationContract.inventory()
	var initiative := TacticalInvalidationContract.initiative()
	var pending := TacticalInvalidationContract.pending_decision()
	_expect(inventory.inventory_changed, "Inventory transfer must invalidate inventory.", failures)
	_expect(initiative.initiative_changed, "Initiative advancement must invalidate initiative.", failures)
	_expect(pending.token_status_changed, "Pending Reaction must invalidate status presentation.", failures)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
