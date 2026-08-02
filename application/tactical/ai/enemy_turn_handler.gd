class_name EnemyTurnHandler
extends RefCounted

signal movement_committed(event: Dictionary)

const ENEMY_ACTION_PLANNER_SCRIPT: Script = preload(
	"res://application/tactical/ai/enemy_action_planner.gd"
)
const MOVEMENT_COORDINATOR_SCRIPT: Script = preload(
	"res://application/tactical/movement/tactical_movement_resolution_coordinator.gd"
)

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _catalogue: ContentCatalogue
var _event_journal: RefCounted
var _attack_preview_query: RefCounted
var _attack_handler: RefCounted
var _detection_service: TacticalDetectionService
var _visibility_service: RefCounted
var _action_planner: RefCounted
var _body_action_handler: TacticalBodyActionHandler
var _reaction_service: TacticalReactionService
var _ability_service: TacticalAbilityService
var _movement_coordinator: TacticalMovementResolutionCoordinator
var _side_turn_participant_ids: Array[StringName] = []
var _side_turn_index: int = 0
var _side_turn_summaries: Array[String] = []
var _activation_timing_samples: int = 0
var _activation_total_usec: int = 0
var _activation_max_usec: int = 0
var _last_activation_timing: Dictionary = {}
var _active_activation_breakdown: Dictionary = {}
var _slow_activation_history: Array[Dictionary] = []
var _activation_sample_serial: int = 0
var _pending_planning_job: EnemyActivationPlanningJob
var _pending_completed_plan: RefCounted
var _pending_visibility_job: RefCounted
var _pending_planning_unit_id: StringName = &""
var _pending_planning_side_based: bool = false
var _pending_planning_refresh_budget: bool = true
var _pending_planning_mode: StringName = &""
var _pending_activation_simulation_usec: int = 0
var _pending_planning_frame_yield_count: int = 0
var _pending_planning_max_slices_per_frame: int = 0
var _pending_hidden_planning_frames: int = 0
var _pending_destination_visibility_yield_count: int = 0
var _contact_warmup_job: EnemyActivationPlanningJob
var _contact_warmup_unit_id: StringName = &""
var _contact_warmup_signature: String = "" # Legacy debug-only signature.
var _contact_warmup_stamp: EnemyPlanDependencyStamp
var _contact_warmup_perception_revision: int = 0
var _contact_warmup_processing_usec: int = 0
var _contact_warmup_slices: int = 0
var _contact_warmup_ready_count: int = 0
var _contact_warmup_reused_count: int = 0
var _contact_warmup_invalidated_count: int = 0
# Hotfix 5f5 keeps the next likely enemy plan warm while the player is deciding.
# Unlike contact warmup, this job may target an actor that does not yet own the
# turn, so it uses forecast capacity without mutating authoritative state.
var _handoff_warmup_job: EnemyActivationPlanningJob
var _handoff_warmup_unit_id: StringName = &""
var _handoff_warmup_signature: String = "" # Legacy debug-only signature.
var _handoff_warmup_stamp: EnemyPlanDependencyStamp
var _handoff_warmup_perception_revision: int = 0
# The screen validates the warmup before it presents the active enemy. The
# activation then consumes it without rebuilding a mission-wide signature
# between the pulse and movement.
var _prevalidated_ai_handoff_unit_id: StringName = &""
var _prevalidated_ai_handoff_kind: StringName = &""
var _prevalidated_ai_handoff_signature: String = "" # Legacy debug-only signature.
var _prevalidated_ai_handoff_stamp: EnemyPlanDependencyStamp
var _warmup_validation_total_usec: int = 0
var _activation_perception_gate_total_usec: int = 0
var _cold_replan_after_warmup_count: int = 0
var _warmup_invalidated_by_perception_count: int = 0
var _warmup_full_signature_builds: int = 0 # Retained for legacy diagnostics; Hotfix 5f9 keeps this at zero.
var _warmup_revision_stamp_builds: int = 0
var _warmup_revision_stamp_comparisons: int = 0
var _handoff_warmup_source_revision: int = -1
var _handoff_warmup_mode: StringName = &""
var _handoff_warmup_capacity_feet: int = 0
var _handoff_warmup_diagonal_steps: int = 0
var _handoff_warmup_processing_usec: int = 0
var _handoff_warmup_slices: int = 0
var _handoff_warmup_ready_count: int = 0
var _handoff_warmup_reused_count: int = 0
var _handoff_warmup_invalidated_count: int = 0
var _handoff_warmup_idle_frames: int = 0
var _handoff_warmup_last_invalidation_reason: StringName = &""
var _handoff_warmup_is_chain: bool = false
var _chain_warmup_started_count: int = 0
var _chain_warmup_processing_usec: int = 0
var _chain_warmup_slices: int = 0
var _chain_warmup_ready_count: int = 0
var _chain_warmup_reused_count: int = 0
var _chain_warmup_invalidated_count: int = 0
# Hotfix 5f10 batches consecutive completely hidden no-action actors into one
# lightweight authoritative transaction. This keeps untouched opening phases
# from rebuilding tactical presentation for every individual pass.
var _hidden_auto_pass_actor_count: int = 0
var _hidden_auto_pass_batch_count: int = 0
var _hidden_auto_pass_transaction_count: int = 0
var _hidden_auto_pass_total_usec: int = 0
var _hidden_auto_pass_max_batch_size: int = 0

const SLOW_ACTIVATION_HISTORY_LIMIT: int = 12
const DEFAULT_AI_PLANNING_BUDGET_USEC: int = 3000


func _init() -> void:
	pass


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		catalogue: ContentCatalogue,
		event_journal_value: RefCounted = null,
		attack_preview_query: RefCounted = null,
		attack_handler: RefCounted = null,
		detection_service: TacticalDetectionService = null,
		visibility_service: RefCounted = null
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_catalogue = catalogue
	_event_journal = event_journal_value
	_attack_preview_query = attack_preview_query
	_attack_handler = attack_handler
	_detection_service = detection_service
	_visibility_service = visibility_service
	_action_planner = ENEMY_ACTION_PLANNER_SCRIPT.new() as RefCounted
	_action_planner.call(
		"configure",
		_state_store,
		_map_definition,
		_catalogue,
		_attack_preview_query
	)


func performance_snapshot() -> Dictionary:
	var planner_snapshot: Dictionary = (
		_action_planner.call("performance_snapshot")
		if (
			_action_planner != null
			and _action_planner.has_method("performance_snapshot")
		)
		else {}
	)
	var snapshot: Dictionary = planner_snapshot.duplicate(true)
	var last_plan_snapshot: Dictionary = planner_snapshot.get("last_plan", {})
	snapshot["contact_warmup"] = {
		"unit_id": _contact_warmup_unit_id,
		"pending": (
			_contact_warmup_job != null and not _contact_warmup_job.complete
		),
		"ready": (
			_contact_warmup_job != null and _contact_warmup_job.complete
		),
		"processing_usec": _contact_warmup_processing_usec,
		"slices": _contact_warmup_slices,
		"ready_count": _contact_warmup_ready_count,
		"reused_count": _contact_warmup_reused_count,
		"invalidated_count": _contact_warmup_invalidated_count,
	}
	snapshot["chain_warmup"] = {
		"started_count": _chain_warmup_started_count,
		"processing_usec": _chain_warmup_processing_usec,
		"slices": _chain_warmup_slices,
		"ready_count": _chain_warmup_ready_count,
		"reused_count": _chain_warmup_reused_count,
		"invalidated_count": _chain_warmup_invalidated_count,
	}
	snapshot["handoff_warmup"] = {
		"unit_id": _handoff_warmup_unit_id,
		"mode": _handoff_warmup_mode,
		"pending": (
			_handoff_warmup_job != null and not _handoff_warmup_job.complete
		),
		"ready": (
			_handoff_warmup_job != null and _handoff_warmup_job.complete
		),
		"capacity_feet": _handoff_warmup_capacity_feet,
		"diagonal_steps": _handoff_warmup_diagonal_steps,
		"processing_usec": _handoff_warmup_processing_usec,
		"slices": _handoff_warmup_slices,
		"idle_frames": _handoff_warmup_idle_frames,
		"ready_count": _handoff_warmup_ready_count,
		"reused_count": _handoff_warmup_reused_count,
		"invalidated_count": _handoff_warmup_invalidated_count,
		"last_invalidation_reason": _handoff_warmup_last_invalidation_reason,
	}
	snapshot["hidden_auto_pass_batching"] = {
		"actors": _hidden_auto_pass_actor_count,
		"batches": _hidden_auto_pass_batch_count,
		"transactions": _hidden_auto_pass_transaction_count,
		"total_usec": _hidden_auto_pass_total_usec,
		"maximum_batch_size": _hidden_auto_pass_max_batch_size,
	}
	snapshot["first_enemy_activation_gate"] = {
		"warmup_validation_total_usec": _warmup_validation_total_usec,
		"activation_perception_gate_total_usec": (
			_activation_perception_gate_total_usec
		),
		"cold_replan_after_warmup": _cold_replan_after_warmup_count,
		"warmup_invalidated_by_perception": (
			_warmup_invalidated_by_perception_count
		),
		"warmup_full_signature_builds": _warmup_full_signature_builds,
		"warmup_revision_stamp_builds": _warmup_revision_stamp_builds,
		"warmup_revision_stamp_comparisons": (
			_warmup_revision_stamp_comparisons
		),
	}
	snapshot["pending_planning"] = {
		"unit_id": _pending_planning_unit_id,
		"mode": _pending_planning_mode,
		"pending": _pending_planning_job != null and not _pending_planning_job.complete,
		"plan_ready": _pending_completed_plan != null,
		"frame_yields": _pending_planning_frame_yield_count,
		"max_slices_per_frame": _pending_planning_max_slices_per_frame,
		"hidden_planning_frames": _pending_hidden_planning_frames,
		"destination_visibility_yields": _pending_destination_visibility_yield_count,
		"planning_stage": last_plan_snapshot.get("planning_stage", &"none"),
	}
	snapshot["activation_timing"] = {
		"samples": _activation_timing_samples,
		"total_usec": _activation_total_usec,
		"average_usec": (
			_activation_total_usec / _activation_timing_samples
			if _activation_timing_samples > 0
			else 0
		),
		"maximum_usec": _activation_max_usec,
		"last": _last_activation_timing.duplicate(true),
		"slowest": _slow_activation_history.duplicate(true),
	}
	return snapshot


func record_last_presentation_timing(presentation_usec: int) -> void:
	if _last_activation_timing.is_empty():
		return
	var safe_presentation_usec: int = maxi(0, presentation_usec)
	var accumulated_presentation_usec: int = (
		int(_last_activation_timing.get("presentation_usec", 0))
		+ safe_presentation_usec
	)
	var simulation_usec: int = int(
		_last_activation_timing.get(
			"simulation_usec",
			_last_activation_timing.get("total_usec", 0)
		)
	)
	_last_activation_timing["presentation_usec"] = accumulated_presentation_usec
	_last_activation_timing["total"] = simulation_usec + accumulated_presentation_usec
	_last_activation_timing["total_with_presentation_usec"] = (
		simulation_usec + accumulated_presentation_usec
	)
	var sample_serial: int = int(
		_last_activation_timing.get("sample_serial", -1)
	)
	for index: int in range(_slow_activation_history.size()):
		if int(_slow_activation_history[index].get("sample_serial", -2)) != sample_serial:
			continue
		_slow_activation_history[index] = _last_activation_timing.duplicate(true)
		break
	_sort_slow_activation_history()


func configure_body_actions(handler: TacticalBodyActionHandler) -> void:
	_body_action_handler = handler


func configure_abilities(service: TacticalAbilityService) -> void:
	_ability_service = service


func configure_reactions(service: TacticalReactionService) -> void:
	_reaction_service = service
	_movement_coordinator = (
		MOVEMENT_COORDINATOR_SCRIPT.new()
		as TacticalMovementResolutionCoordinator
	)
	_movement_coordinator.configure(service)


func has_pending_reaction() -> bool:
	var pending: PendingMovementReactionState = _pending_reaction_state()
	return (
		pending != null
		and pending.continuation_kind in [
			PendingMovementReactionState.CONTINUATION_ENEMY_MOVEMENT,
			PendingMovementReactionState.CONTINUATION_ENEMY_PROVOKING_ACTION,
		]
	)


func open_pending_reaction_decision() -> OperationResult:
	var pending: PendingMovementReactionState = _pending_reaction_state()
	if _reaction_service == null or pending == null or pending.candidate == null:
		return OperationResult.fail(&"reaction_decision_missing", "No player Reaction is pending.")
	if pending.has_unresolved_decision():
		return OperationResult.pending(
			&"reaction_decision_pending",
			pending.request,
			"The player Reaction decision is already open.",
			_state_store.state.revision
		)
	return _reaction_service.open_player_decision(pending.candidate)


func resume_after_reaction() -> OperationResult:
	var pending: PendingMovementReactionState = _pending_reaction_state()
	if _reaction_service == null or pending == null:
		return OperationResult.fail(
			&"reaction_resume_missing",
			"No interrupted enemy activation is waiting."
		)
	if pending.has_unresolved_decision() or not pending.decision_resolved:
		return OperationResult.fail(
			&"reaction_decision_unresolved",
			"Resolve the player Reaction decision first."
		)
	_restore_side_turn_progress_from_pending(pending)
	var unit: TacticalUnitState = _state_store.state.get_unit(pending.mover_unit_id)
	if unit == null:
		_finish_pending_context(pending, false)
		return OperationResult.fail(
			&"reaction_mover_missing",
			"The interrupted enemy no longer exists."
		)
	if pending.continuation_kind == PendingMovementReactionState.CONTINUATION_ENEMY_PROVOKING_ACTION:
		return _resume_provoking_action(
			pending.continuation_payload,
			unit,
			pending
		)
	if not unit.can_take_actions():
		var stopped_result: OperationResult = _finish_activation(
			unit,
			true,
			"%s was stopped by a Reaction." % unit.display_name,
			true
		)
		_finish_pending_context(pending, true)
		return stopped_result

	if (
		pending.pending_timing_kind == ReactionCandidate.TIMING_BEFORE_ENTRY
		and pending.pending_step_cost_prepaid
		and unit.grid_position == pending.pending_step_origin
	):
		var next_before: ReactionCandidate = _next_player_candidate_for_pending_step(
			pending,
			unit,
			ReactionCandidate.TIMING_BEFORE_ENTRY
		)
		if next_before != null:
			return _replace_pending_candidate(pending, next_before)
		var entered: OperationResult = _commit_enemy_entry_without_budget(
			unit,
			pending.pending_step_origin,
			pending.pending_step_destination,
			pending.pending_step_cost_feet,
			pending.pending_step_diagonal_steps
		)
		if not entered.success:
			return entered
		pending = pending.duplicate_state()
		pending.current_position = unit.grid_position
		pending.next_step_index = pending.trigger_path_index + 1
		pending.source_revision = _state_store.state.revision
		var updated_pending: OperationResult = _reaction_service.commit_pending_movement_reaction(
			pending,
			&"movement_reaction_updated"
		)
		if not updated_pending.success:
			return updated_pending

	var next_after: ReactionCandidate = _next_player_candidate_for_pending_step(
		pending,
		unit,
		ReactionCandidate.TIMING_AFTER_ENTRY
	)
	if next_after != null:
		return _replace_pending_candidate(pending, next_after)

	var remaining_path: Array[Vector2i] = [unit.grid_position]
	for index: int in range(maxi(0, pending.next_step_index), pending.full_path.size()):
		var tile: Vector2i = pending.full_path[index]
		if remaining_path.back() != tile:
			remaining_path.append(tile)
	if remaining_path.size() > 1:
		var continuation: OperationResult = _commit_enemy_path_with_reactions(
			unit,
			remaining_path,
			pending.movement_action_id,
			pending.continuation_payload.get("post_move", {}) as Dictionary,
			bool(pending.continuation_payload.get("side_based", false))
		)
		if not continuation.success or continuation.code == &"reaction_pending":
			return continuation

	var cleared_before_post_move: OperationResult = (
		_reaction_service.clear_pending_movement_reaction(
			pending.movement_action_id
		)
	)
	if not cleared_before_post_move.success:
		return cleared_before_post_move

	var result: OperationResult = _complete_post_move_context(
		unit,
		pending.continuation_payload.get("post_move", {}) as Dictionary,
		bool(pending.continuation_payload.get("side_based", false)),
		pending.movement_action_id
	)
	if result.code == &"reaction_pending":
		return result
	_finish_pending_context(pending, true)
	return result


func _next_player_candidate_for_pending_step(
		pending: PendingMovementReactionState,
		unit: TacticalUnitState,
		timing_kind: StringName
) -> ReactionCandidate:
	if (
		pending == null
		or unit == null
		or _movement_coordinator == null
		or pending.pending_step_origin.x < 0
		or pending.pending_step_destination.x < 0
	):
		return null
	for candidate: ReactionCandidate in _movement_coordinator.candidates_for_step(
		unit.unit_id,
		pending.pending_step_origin,
		pending.pending_step_destination,
		pending.trigger_path_index,
		pending.movement_mode,
		pending.movement_action_id
	):
		if candidate.timing_kind != timing_kind:
			continue
		var reactor: TacticalUnitState = _state_store.state.get_unit(
			candidate.source_unit_id
		)
		if reactor != null and reactor.is_player_controlled():
			return candidate
	return null


func _replace_pending_candidate(
		pending: PendingMovementReactionState,
		candidate: ReactionCandidate
) -> OperationResult:
	var updated: PendingMovementReactionState = pending.duplicate_state()
	updated.candidate = candidate
	updated.request = null
	updated.decision_resolved = false
	updated.resolved_choice = &""
	updated.pending_timing_kind = candidate.timing_kind
	updated.source_revision = _state_store.state.revision
	var committed: OperationResult = _reaction_service.commit_pending_movement_reaction(
		updated,
		&"movement_reaction_updated"
	)
	if not committed.success:
		return committed
	return OperationResult.pending(
		&"reaction_pending",
		updated,
		"Another eligible Reaction must resolve before movement continues.",
		_state_store.state.revision
	)


func _resume_provoking_action(
		context: Dictionary,
		unit: TacticalUnitState,
		pending: PendingMovementReactionState
) -> OperationResult:
	if not unit.can_take_actions():
		var stopped: OperationResult = _finish_activation(
			unit,
			true,
			"%s was stopped before completing a provoking action." % unit.display_name,
			true
		)
		_finish_pending_context(pending, true)
		return stopped
	var target: TacticalUnitState = _state_store.state.get_unit(
		StringName(context.get("target_id", &""))
	)
	var action_id := StringName(context.get("action_id", &""))
	if target == null or target.is_defeated():
		var no_target: OperationResult = _finish_activation(
			unit,
			false,
			"%s's provoking action lost its target." % unit.display_name
		)
		_finish_pending_context(pending, true)
		return no_target
	var preview: Variant = _preview_attack(unit, target, action_id)
	if not _preview_succeeds(preview):
		var invalid: OperationResult = _finish_activation(
			unit,
			false,
			"%s's provoking action is no longer legal." % unit.display_name
		)
		_finish_pending_context(pending, true)
		return invalid
	var cleared_before_attack: OperationResult = (
		_reaction_service.clear_pending_movement_reaction(
			pending.movement_action_id
		)
	)
	if not cleared_before_attack.success:
		return cleared_before_attack
	var attack_result: OperationResult = _execute_attack(preview)
	if not attack_result.success:
		_finish_pending_context(pending, true)
		return attack_result
	var finished: OperationResult = _finish_activation(
		unit,
		true,
		"%s completed its provoking attack." % unit.display_name
	)
	_finish_pending_context(pending, true)
	return finished


func _finish_pending_context(
		pending: PendingMovementReactionState,
		advance_side_turn: bool
) -> void:
	if pending == null:
		return
	if advance_side_turn and bool(pending.continuation_payload.get("side_based", false)):
		_side_turn_index += 1
	if _reaction_service != null:
		var cleared: OperationResult = _reaction_service.clear_pending_movement_reaction(
			pending.movement_action_id
		)
		if not cleared.success:
			push_warning(cleared.message)


func _pending_reaction_state() -> PendingMovementReactionState:
	if _state_store == null or _state_store.state == null:
		return null
	return _state_store.state.pending_movement_reaction


func _restore_side_turn_progress_from_pending(
		pending: PendingMovementReactionState
) -> void:
	if pending == null or not bool(pending.continuation_payload.get("side_based", false)):
		return
	_side_turn_participant_ids.clear()
	for value: Variant in pending.continuation_payload.get("side_turn_participant_ids", []):
		_side_turn_participant_ids.append(StringName(value))
	_side_turn_index = int(pending.continuation_payload.get("side_turn_index", _side_turn_index))


func resolve_enemy_turn() -> OperationResult:
	# Compatibility entry point for tests and non-presentational callers. Runtime
	# presentation schedules planning slices adaptively, while this path resolves
	# planning and commitment synchronously.
	var result: OperationResult = resolve_next_enemy_activation()
	while (
		result.success
		and result.code not in [
			&"reaction_pending",
			&"enemy_turn_completed",
		]
	):
		if has_pending_enemy_destination_visibility():
			step_pending_enemy_destination_visibility(1_000_000)
			continue
		if result.code == &"enemy_plan_ready":
			result = commit_ready_enemy_activation()
		else:
			result = resolve_next_enemy_activation(1_000_000)
	return result


func peek_next_enemy_activation_unit_id() -> StringName:
	if not _pending_planning_unit_id.is_empty():
		return _pending_planning_unit_id
	if _state_store == null or _state_store.state == null:
		return &""
	if not _state_store.state.phase_state.is_enemy_turn():
		return &""
	_ensure_side_turn_participants()
	if _side_turn_index < 0 or _side_turn_index >= _side_turn_participant_ids.size():
		return &""
	return _side_turn_participant_ids[_side_turn_index]


func has_pending_enemy_planning() -> bool:
	# Destination visibility is deliberately not a planning gate. A completed
	# movement plan may commit while its read-only FOV job runs during the tween.
	return (
		(_pending_planning_job != null and not _pending_planning_job.complete)
		or _pending_completed_plan != null
	)


func is_enemy_plan_ready_to_commit() -> bool:
	return (
		_pending_completed_plan != null
		and _pending_planning_job == null
		and not _pending_planning_unit_id.is_empty()
	)


func pending_enemy_planning_is_visibility() -> bool:
	# Retained for compatibility with the 5f1 diagnostics surface. Visibility
	# preparation no longer returns enemy_planning_pending.
	return false


func has_pending_enemy_destination_visibility() -> bool:
	return (
		_pending_visibility_job != null
		and not bool(_pending_visibility_job.get("complete"))
	)


func pending_enemy_destination_visibility_unit_id() -> StringName:
	if _pending_visibility_job == null:
		return &""
	return StringName(_pending_visibility_job.get("unit_id"))


func step_pending_enemy_destination_visibility(
		budget_usec: int = DEFAULT_AI_PLANNING_BUDGET_USEC
) -> bool:
	if _pending_visibility_job == null:
		return true
	if bool(_pending_visibility_job.get("complete")):
		_capture_destination_visibility_job_diagnostics(_pending_visibility_job)
		_pending_visibility_job = null
		return true
	if (
		_visibility_service == null
		or not _visibility_service.has_method("step_visibility_preparation_job")
	):
		_cancel_pending_enemy_destination_visibility()
		return true
	var unit_id := StringName(_pending_visibility_job.get("unit_id"))
	var destination := Vector2i(_pending_visibility_job.get("destination"))
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null or unit.grid_position != destination:
		_cancel_pending_enemy_destination_visibility()
		return true
	var started_usec: int = Time.get_ticks_usec()
	var complete: bool = bool(_visibility_service.call(
		"step_visibility_preparation_job",
		_pending_visibility_job,
		maxi(250, budget_usec)
	))
	_add_activation_stage_time(&"destination_visibility_prepare", started_usec)
	if not complete:
		return false
	_capture_destination_visibility_job_diagnostics(_pending_visibility_job)
	_pending_visibility_job = null
	return true


func cancel_pending_enemy_destination_visibility() -> void:
	_cancel_pending_enemy_destination_visibility()


func _cancel_pending_enemy_destination_visibility() -> void:
	if (
		_pending_visibility_job != null
		and _visibility_service != null
		and _visibility_service.has_method("cancel_visibility_preparation_job")
	):
		_visibility_service.call(
			"cancel_visibility_preparation_job",
			_pending_visibility_job
		)
	_pending_visibility_job = null


func record_enemy_planning_frame_yield(
		slices_this_frame: int,
		hidden_actor: bool
) -> void:
	_pending_planning_frame_yield_count += 1
	_pending_planning_max_slices_per_frame = maxi(
		_pending_planning_max_slices_per_frame,
		maxi(0, slices_this_frame)
	)
	if hidden_actor:
		_pending_hidden_planning_frames += 1
	if pending_enemy_planning_is_visibility():
		_pending_destination_visibility_yield_count += 1


func commit_ready_enemy_activation() -> OperationResult:
	if not is_enemy_plan_ready_to_commit():
		return OperationResult.fail(
			&"enemy_plan_not_ready",
			"No completed enemy plan is ready to commit."
		)
	var unit_id: StringName = _pending_planning_unit_id
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		_clear_pending_planning_job()
		return OperationResult.fail(
			&"enemy_planning_unit_missing",
			"The enemy whose plan completed no longer exists."
		)
	var plan: RefCounted = _pending_completed_plan
	var refresh_budget: bool = _pending_planning_refresh_budget
	var mode: StringName = _pending_planning_mode
	_clear_pending_planning_job(false, false)
	var commit_started_usec: int = Time.get_ticks_usec()
	var result: OperationResult = _execute_planned_combat(
		unit,
		plan,
		refresh_budget
	)
	_pending_activation_simulation_usec += maxi(
		0,
		Time.get_ticks_usec() - commit_started_usec
	)
	_reconcile_destination_visibility_after_commit(unit, result)
	_record_activation_timing_elapsed(
		unit_id,
		_pending_activation_simulation_usec,
		result,
		mode
	)
	_pending_activation_simulation_usec = 0
	if mode != &"side_based":
		return result
	if result.code == &"reaction_pending":
		return result
	if not result.success:
		var recovered: OperationResult = _recover_activation_failure(
			unit_id,
			result
		)
		if not recovered.success:
			return recovered
		result = recovered
	if not result.message.is_empty():
		_side_turn_summaries.append(result.message)
	_side_turn_index += 1
	return OperationResult.new(
		true,
		&"enemy_activation_completed",
		result.message,
		{
			"unit_id": unit_id,
			"participant_index": _side_turn_index,
			"participant_count": _side_turn_participant_ids.size(),
			"turn_complete": false,
		},
		OperationResult.STATUS_COMMITTED,
		[],
		_state_store.state.revision
	)


func resolve_next_enemy_activation(
		budget_usec: int = DEFAULT_AI_PLANNING_BUDGET_USEC
) -> OperationResult:
	if _state_store == null or _state_store.state == null:
		return OperationResult.fail(
			&"enemy_turn_state_missing",
			"The tactical state is unavailable."
		)
	if not _state_store.state.phase_state.is_enemy_turn():
		_reset_side_turn_progress()
		return OperationResult.fail(
			&"enemy_turn_wrong_phase",
			"Enemy activations are available only during the Enemy Turn."
		)
	if has_pending_reaction():
		return OperationResult.pending(
			&"reaction_pending",
			_pending_reaction_state(),
			"A player Reaction decision is pending.",
			_state_store.state.revision
		)

	_ensure_side_turn_participants()
	if _side_turn_index >= _side_turn_participant_ids.size():
		return _complete_side_turn_result()

	# A completely hidden, unaware or authored auto-pass actor has no tactical
	# consequence to present. Resolve every consecutive compatible actor in one
	# lightweight transaction before entering the ordinary per-unit pipeline.
	if not has_pending_enemy_planning():
		var hidden_batch: OperationResult = _try_execute_hidden_auto_pass_batch()
		if hidden_batch != null:
			return hidden_batch

	var unit_id: StringName = (
		_pending_planning_unit_id
		if not _pending_planning_unit_id.is_empty()
		else _side_turn_participant_ids[_side_turn_index]
	)
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if is_enemy_plan_ready_to_commit():
		return _plan_ready_result(unit)
	var slice_started_usec: int = Time.get_ticks_usec()
	var result: OperationResult
	if has_pending_enemy_planning():
		result = _continue_pending_planning_activation(budget_usec)
	else:
		_begin_activation_diagnostics(unit, &"side_based")
		_pending_activation_simulation_usec = 0
		result = _execute_activation(unit_id, budget_usec)
	_pending_activation_simulation_usec += maxi(
		0,
		Time.get_ticks_usec() - slice_started_usec
	)
	if result.code in [
		&"enemy_planning_pending",
		&"enemy_plan_ready",
	]:
		return result
	_record_activation_timing_elapsed(
		unit_id,
		_pending_activation_simulation_usec,
		result,
		&"side_based"
	)
	_pending_activation_simulation_usec = 0
	if result.code == &"reaction_pending":
		return result
	if not result.success:
		var recovered: OperationResult = _recover_activation_failure(unit_id, result)
		if not recovered.success:
			return recovered
		result = recovered
	if not result.message.is_empty():
		_side_turn_summaries.append(result.message)
	_side_turn_index += 1

	return OperationResult.new(
		true,
		&"enemy_activation_completed",
		result.message,
		{
			"unit_id": unit_id,
			"participant_index": _side_turn_index,
			"participant_count": _side_turn_participant_ids.size(),
			"turn_complete": false,
		},
		OperationResult.STATUS_COMMITTED,
		[],
		_state_store.state.revision
	)


func _ensure_side_turn_participants() -> void:
	if not _side_turn_participant_ids.is_empty():
		return
	_side_turn_participant_ids = _stable_participant_ids()
	_side_turn_index = 0
	_side_turn_summaries.clear()
	_record_activation_order(_side_turn_participant_ids)


func _complete_side_turn_result() -> OperationResult:
	var participant_ids: Array[StringName] = _side_turn_participant_ids.duplicate()
	var summaries: Array[String] = _side_turn_summaries.duplicate()
	_reset_side_turn_progress()
	var message: String = "Enemy Turn completed."
	if not summaries.is_empty():
		message = "Enemy Turn completed: %s" % "; ".join(PackedStringArray(summaries))
	return OperationResult.new(
		true,
		&"enemy_turn_completed",
		message,
		{
			"participant_ids": participant_ids,
			"turn_complete": true,
		},
		OperationResult.STATUS_COMMITTED,
		[],
		_state_store.state.revision
	)


func _reset_side_turn_progress() -> void:
	_clear_pending_planning_job()
	_cancel_contact_warmup(false)
	_cancel_handoff_warmup(&"side_turn_reset", false)
	_side_turn_participant_ids.clear()
	_side_turn_index = 0
	_side_turn_summaries.clear()


func peek_next_ai_handoff_unit_id() -> StringName:
	var candidate: Dictionary = _next_ai_handoff_candidate()
	return StringName(candidate.get("unit_id", &""))


func prepare_ai_activation_handoff(unit_id: StringName) -> OperationResult:
	if _state_store == null or _state_store.state == null:
		return OperationResult.fail(
			&"ai_handoff_state_missing",
			"The tactical state is unavailable."
		)
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null or not unit.is_ai_controlled():
		_clear_prevalidated_ai_handoff()
		return OperationResult.no_change(
			unit_id,
			"No AI handoff warmup is available for this actor."
		)
	var started_usec: int = Time.get_ticks_usec()
	var kind: StringName = &""
	var stamp: EnemyPlanDependencyStamp
	var current_perception_revision: int = _perception_revision_for_squad(
		unit.squad_id
	)
	if _contact_warmup_job != null and _contact_warmup_unit_id == unit_id:
		kind = &"contact"
		stamp = _contact_warmup_stamp
		_warmup_revision_stamp_comparisons += 1
		if (
			stamp == null
			or not stamp.matches(
				_state_store.state,
				unit,
				unit.action_budget.remaining_turn_capacity_feet,
				unit.diagonal_steps_used,
				&"contact",
				current_perception_revision
			)
		):
			_contact_warmup_invalidated_count += 1
			if current_perception_revision != _contact_warmup_perception_revision:
				_warmup_invalidated_by_perception_count += 1
			_cancel_contact_warmup(false)
			kind = &""
	elif _handoff_warmup_job != null and _handoff_warmup_unit_id == unit_id:
		kind = &"handoff"
		stamp = _handoff_warmup_stamp
		_warmup_revision_stamp_comparisons += 1
		if (
			stamp == null
			or not stamp.matches(
				_state_store.state,
				unit,
				_handoff_warmup_capacity_feet,
				_handoff_warmup_diagonal_steps,
				_handoff_warmup_mode,
				current_perception_revision
			)
		):
			if current_perception_revision != _handoff_warmup_perception_revision:
				_warmup_invalidated_by_perception_count += 1
			_cancel_handoff_warmup(&"dependencies_changed")
			kind = &""
	_warmup_validation_total_usec += maxi(0, Time.get_ticks_usec() - started_usec)
	if kind.is_empty():
		_clear_prevalidated_ai_handoff()
		return OperationResult.no_change(
			unit_id,
			"The active enemy will use responsive fallback planning."
		)
	_prevalidated_ai_handoff_unit_id = unit_id
	_prevalidated_ai_handoff_kind = kind
	_prevalidated_ai_handoff_stamp = stamp
	return OperationResult.pending(
		&"enemy_handoff_prevalidated",
		unit_id,
		"The active enemy plan was validated before presentation.",
		_state_store.state.revision
	)


func _clear_prevalidated_ai_handoff() -> void:
	_prevalidated_ai_handoff_unit_id = &""
	_prevalidated_ai_handoff_kind = &""
	_prevalidated_ai_handoff_signature = ""
	_prevalidated_ai_handoff_stamp = null


func _perception_revision_for_squad(squad_id: StringName) -> int:
	if (
		_detection_service == null
		or not _detection_service.has_method("perception_revision_for_squad")
	):
		return 0
	return int(_detection_service.call(
		"perception_revision_for_squad", squad_id
	))


func _prepare_perception_before_warmup(
		unit: TacticalUnitState
) -> OperationResult:
	if _detection_service == null or unit == null or unit.squad_id.is_empty():
		return OperationResult.ok(false, "No warmup perception refresh was required.")
	if _detection_service.has_method("prepare_current_perception_for_ai_warmup"):
		return _detection_service.call(
			"prepare_current_perception_for_ai_warmup", unit.squad_id
		) as OperationResult
	return _refresh_squad_perception(unit)


func _warmup_perception_is_current(
		unit: TacticalUnitState,
		expected_revision: int
) -> bool:
	if unit == null or expected_revision <= 0:
		return false
	if (
		_detection_service != null
		and _detection_service.has_method(
			"has_queued_perception_refresh_for_squad"
		)
		and bool(_detection_service.call(
			"has_queued_perception_refresh_for_squad", unit.squad_id
		))
	):
		return false
	return _perception_revision_for_squad(unit.squad_id) == expected_revision


func warmup_next_ai_handoff(
		budget_usec: int = DEFAULT_AI_PLANNING_BUDGET_USEC
) -> OperationResult:
	if _state_store == null or _state_store.state == null:
		return OperationResult.fail(
			&"handoff_warmup_state_missing",
			"The tactical state is unavailable."
		)
	if _action_planner == null or has_pending_reaction() or has_pending_enemy_planning():
		_cancel_handoff_warmup(&"planning_unavailable")
		return OperationResult.no_change(
			null,
			"Enemy handoff warmup is not currently available."
		)
	var candidate: Dictionary = _next_ai_handoff_candidate()
	var unit_id := StringName(candidate.get("unit_id", &""))
	if unit_id.is_empty():
		_cancel_handoff_warmup(&"no_upcoming_ai")
		return OperationResult.no_change(
			null,
			"No immediate AI handoff requires preparation."
		)
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if (
		unit == null
		or not unit.is_ai_controlled()
		or not unit.can_take_actions()
		or unit.squad_id.is_empty()
		or not _state_store.state.is_squad_aware(unit.squad_id)
	):
		_cancel_handoff_warmup(&"actor_ineligible")
		return OperationResult.no_change(
			unit_id,
			"The upcoming actor is not eligible for AI handoff warmup."
		)
	var forecast_capacity: int = int(candidate.get(
		"capacity_feet",
		unit.action_budget.remaining_turn_capacity_feet
	))
	var forecast_diagonal: int = int(candidate.get(
		"diagonal_steps",
		unit.diagonal_steps_used
	))
	var mode := StringName(candidate.get("mode", &"initiative"))
	var chain_warmup: bool = bool(candidate.get("chain", false))
	var candidate_matches_existing: bool = (
		_handoff_warmup_job != null
		and _handoff_warmup_unit_id == unit_id
		and _handoff_warmup_mode == mode
		and _handoff_warmup_capacity_feet == forecast_capacity
		and _handoff_warmup_diagonal_steps == forecast_diagonal
	)
	if (
		not candidate_matches_existing
		or _handoff_warmup_source_revision != _state_store.state.revision
	):
		var perception_result: OperationResult = _prepare_perception_before_warmup(unit)
		if perception_result == null or not perception_result.success:
			_cancel_handoff_warmup(&"perception_refresh_failed")
			return (
				perception_result
				if perception_result != null
				else OperationResult.fail(
					&"handoff_perception_result_missing",
					"Enemy perception warmup returned no result."
				)
			)
	var perception_revision: int = _perception_revision_for_squad(unit.squad_id)
	var dependencies_match: bool = false
	if candidate_matches_existing and _handoff_warmup_stamp != null:
		_warmup_revision_stamp_comparisons += 1
		dependencies_match = _handoff_warmup_stamp.matches(
			_state_store.state,
			unit,
			forecast_capacity,
			forecast_diagonal,
			mode,
			perception_revision
		)
	if not dependencies_match:
		_cancel_handoff_warmup(&"dependencies_changed", false)
		_handoff_warmup_stamp = EnemyPlanDependencyStamp.capture(
			_state_store.state,
			unit,
			forecast_capacity,
			forecast_diagonal,
			mode,
			perception_revision
		)
		_warmup_revision_stamp_builds += 1
		_handoff_warmup_job = _action_planner.call(
			"begin_plan_activation",
			unit,
			forecast_capacity,
			forecast_diagonal,
			true
		) as EnemyActivationPlanningJob
		if _handoff_warmup_job == null:
			return OperationResult.fail(
				&"handoff_warmup_job_missing",
				"The enemy planner returned no handoff warmup job."
			)
		_handoff_warmup_unit_id = unit_id
		_handoff_warmup_signature = ""
		_handoff_warmup_perception_revision = perception_revision
		_handoff_warmup_source_revision = _state_store.state.revision
		_handoff_warmup_mode = mode
		_handoff_warmup_capacity_feet = forecast_capacity
		_handoff_warmup_diagonal_steps = forecast_diagonal
		_handoff_warmup_is_chain = chain_warmup
		_handoff_warmup_processing_usec = 0
		_handoff_warmup_slices = 0
		if chain_warmup:
			_chain_warmup_started_count += 1
	elif _handoff_warmup_source_revision != _state_store.state.revision:
		_handoff_warmup_source_revision = _state_store.state.revision
	if _handoff_warmup_job.complete:
		return OperationResult.pending(
			&"enemy_handoff_warmup_ready",
			_handoff_warmup_job.plan,
			"The next enemy plan is ready before handoff.",
			_state_store.state.revision
		)
	var started_usec: int = Time.get_ticks_usec()
	var complete: bool = bool(_action_planner.call(
		"step_plan_job",
		_handoff_warmup_job,
		maxi(250, budget_usec)
	))
	var elapsed_usec: int = maxi(0, Time.get_ticks_usec() - started_usec)
	_handoff_warmup_processing_usec += elapsed_usec
	_handoff_warmup_slices += 1
	_handoff_warmup_idle_frames += 1
	if chain_warmup:
		_chain_warmup_processing_usec += elapsed_usec
		_chain_warmup_slices += 1
	if complete:
		_handoff_warmup_ready_count += 1
		if chain_warmup:
			_chain_warmup_ready_count += 1
		return OperationResult.pending(
			&"enemy_handoff_warmup_ready",
			_handoff_warmup_job.plan,
			"The next enemy plan is ready before handoff.",
			_state_store.state.revision
		)
	return OperationResult.pending(
		&"enemy_handoff_warmup_pending",
		_handoff_warmup_job,
		"The next enemy plan is warming during player decision time.",
		_state_store.state.revision
	)


func cancel_handoff_ai_warmup() -> void:
	_cancel_handoff_warmup(&"cancelled")


func _next_ai_handoff_candidate() -> Dictionary:
	if _state_store == null or _state_store.state == null:
		return {}
	var phase: TacticalPhaseState = _state_store.state.phase_state
	if phase.is_side_based():
		if phase.is_player_phase():
			var player_phase_ids: Array[StringName] = _stable_participant_ids()
			for unit_id: StringName in player_phase_ids:
				var first: TacticalUnitState = _state_store.state.get_unit(unit_id)
				if not _unit_requires_planned_ai_activation(first):
					continue
				return {
					"unit_id": first.unit_id,
					"mode": &"side_based",
					"capacity_feet": first.action_budget.maximum_turn_capacity_feet,
					"diagonal_steps": 0,
					"chain": false,
				}
			return {}
		if phase.is_enemy_turn():
			_ensure_side_turn_participants()
			for index: int in range(_side_turn_index, _side_turn_participant_ids.size()):
				var next_side: TacticalUnitState = _state_store.state.get_unit(
					_side_turn_participant_ids[index]
				)
				if not _unit_requires_planned_ai_activation(next_side):
					continue
				return {
					"unit_id": next_side.unit_id,
					"mode": &"side_based",
					"capacity_feet": next_side.action_budget.maximum_turn_capacity_feet,
					"diagonal_steps": 0,
					"chain": true,
				}
		return {}
	if not phase.is_initiative_combat():
		return {}
	var active: TacticalUnitState = _state_store.state.active_initiative_unit()
	if active == null:
		return {}
	var chain_warmup: bool = active.is_ai_controlled()
	if chain_warmup and not active.action_budget.ended_activation:
		# The current actor is still planning/committing. Lookahead becomes valid
		# only once its authoritative activation has finished.
		return {}
	if not chain_warmup and not active.is_player_controlled():
		return {}
	var order: Array[StringName] = phase.initiative_order
	if order.is_empty():
		return {}
	for offset: int in range(1, order.size() + 1):
		var index: int = (phase.active_initiative_index + offset) % order.size()
		var candidate: TacticalUnitState = _state_store.state.get_unit(order[index])
		if candidate == null or not candidate.can_take_actions():
			continue
		# Only the immediate eligible handoff may be warmed. A player actor is an
		# authoritative pipeline stop, never something AI lookahead may cross.
		if candidate.is_player_controlled():
			return {}
		if not _unit_requires_planned_ai_activation(candidate):
			continue
		var wrapped: bool = index <= phase.active_initiative_index
		return {
			"unit_id": candidate.unit_id,
			"mode": &"initiative",
			"capacity_feet": (
				candidate.action_budget.maximum_turn_capacity_feet
				if wrapped
				else candidate.action_budget.remaining_turn_capacity_feet
			),
			"diagonal_steps": 0 if wrapped else candidate.diagonal_steps_used,
			"chain": chain_warmup,
		}
	return {}


func _unit_requires_planned_ai_activation(unit: TacticalUnitState) -> bool:
	return (
		unit != null
		and unit.is_ai_controlled()
		and unit.can_take_actions()
		and not unit.is_defeated()
		and not unit.is_incapacitated()
		and not unit.squad_id.is_empty()
		and _state_store.state.is_squad_aware(unit.squad_id)
		and unit.turn_behavior == TacticalUnitState.TURN_BEHAVIOR_STANDARD
	)


func _handoff_warmup_signature_for_unit(
		unit: TacticalUnitState,
		forecast_capacity: int,
		forecast_diagonal: int,
		mode: StringName
) -> String:
	if unit == null or _state_store == null or _state_store.state == null:
		return ""
	var state: TacticalState = _state_store.state
	var squad: TacticalSquadState = state.get_squad(unit.squad_id)
	var parts: Array[String] = [
		"g:%d" % state.geometry_revision(),
		"o:%d" % state.spatial_occupancy_revision(),
		"v:%d" % state.spatial_visibility_blocker_revision(),
		"p:%d" % _perception_revision_for_squad(unit.squad_id),
		"m:%s" % String(mode),
		"u:%s:%d:%d:%d:%d:%s" % [
			String(unit.unit_id),
			unit.grid_position.x,
			unit.grid_position.y,
			unit.assigned_task_position.x,
			unit.assigned_task_position.y,
			String(unit.ai_profile_id),
		],
		"b:%d:%d:%d" % [
			forecast_capacity,
			forecast_diagonal,
			unit.action_budget.maximum_turn_capacity_feet,
		],
		"l:%s:%d:%d:%d" % [
			String(unit.life_state_id()),
			unit.current_hp,
			unit.nonlethal_damage,
			1 if unit.can_take_actions() else 0,
		],
		"s:%s:%s:%d" % [
			String(unit.squad_id),
			String(squad.awareness if squad != null else &""),
			squad.search_rounds_remaining if squad != null else 0,
		],
	]
	# Target fingerprints are intentionally limited to revealed hostiles. Spatial
	# revisions already cover every blocker/occupant; this list captures combat
	# values that can alter target scoring without scanning the whole mission.
	var hostiles: Array[TacticalUnitState] = []
	for other: TacticalUnitState in state.get_units():
		if (
			other != null
			and other.team_id != unit.team_id
			and not other.is_defeated()
			and other.is_revealed_to_squad(unit.squad_id)
		):
			hostiles.append(other)
	hostiles.sort_custom(
		func(a: TacticalUnitState, b: TacticalUnitState) -> bool:
			return String(a.unit_id) < String(b.unit_id)
	)
	for hostile: TacticalUnitState in hostiles:
		parts.append(
			"h:%s:%d:%d:%s:%d:%d:%d" % [
				String(hostile.unit_id),
				hostile.grid_position.x,
				hostile.grid_position.y,
				String(hostile.life_state_id()),
				hostile.current_hp,
				hostile.armour_class,
				1 if hostile.stealth_enabled else 0,
			]
		)
	return "|".join(PackedStringArray(parts))


func _take_valid_handoff_warmup_job(
		unit: TacticalUnitState
) -> EnemyActivationPlanningJob:
	if (
		unit == null
		or _handoff_warmup_job == null
		or _handoff_warmup_unit_id != unit.unit_id
	):
		return null
	if (
		unit.action_budget.remaining_turn_capacity_feet
		!= _handoff_warmup_capacity_feet
		or unit.diagonal_steps_used != _handoff_warmup_diagonal_steps
	):
		_cancel_handoff_warmup(&"budget_changed")
		return null
	var prevalidated: bool = (
		_prevalidated_ai_handoff_unit_id == unit.unit_id
		and _prevalidated_ai_handoff_kind == &"handoff"
		and _prevalidated_ai_handoff_stamp == _handoff_warmup_stamp
	)
	if not prevalidated:
		_warmup_revision_stamp_comparisons += 1
		if (
			_handoff_warmup_stamp == null
			or not _handoff_warmup_stamp.matches(
				_state_store.state,
				unit,
				_handoff_warmup_capacity_feet,
				_handoff_warmup_diagonal_steps,
				_handoff_warmup_mode,
				_perception_revision_for_squad(unit.squad_id)
			)
		):
			_cancel_handoff_warmup(&"dependencies_changed")
			return null
	if not _warmup_perception_is_current(
		unit, _handoff_warmup_perception_revision
	):
		_warmup_invalidated_by_perception_count += 1
		_cancel_handoff_warmup(&"perception_changed")
		return null
	var result: EnemyActivationPlanningJob = _handoff_warmup_job
	if _handoff_warmup_is_chain:
		_chain_warmup_reused_count += 1
	_handoff_warmup_job = null
	_handoff_warmup_unit_id = &""
	_handoff_warmup_signature = ""
	_handoff_warmup_stamp = null
	_handoff_warmup_source_revision = -1
	_handoff_warmup_mode = &""
	_handoff_warmup_is_chain = false
	_handoff_warmup_reused_count += 1
	_handoff_warmup_perception_revision = 0
	_clear_prevalidated_ai_handoff()
	return result


func _cancel_handoff_warmup(
		reason: StringName,
		count_invalidation: bool = true
) -> void:
	if (
		_handoff_warmup_job != null
		and not _handoff_warmup_job.complete
		and _action_planner != null
		and _action_planner.has_method("cancel_plan_job")
	):
		_action_planner.call("cancel_plan_job", _handoff_warmup_job)
	if count_invalidation and _handoff_warmup_job != null:
		_handoff_warmup_invalidated_count += 1
		if _handoff_warmup_is_chain:
			_chain_warmup_invalidated_count += 1
	_handoff_warmup_last_invalidation_reason = reason
	_handoff_warmup_job = null
	_handoff_warmup_unit_id = &""
	_handoff_warmup_signature = ""
	_handoff_warmup_stamp = null
	_handoff_warmup_source_revision = -1
	_handoff_warmup_mode = &""
	_handoff_warmup_is_chain = false
	_handoff_warmup_capacity_feet = 0
	_handoff_warmup_diagonal_steps = 0
	_handoff_warmup_perception_revision = 0
	_clear_prevalidated_ai_handoff()


func warmup_initiative_activation(
		unit_id: StringName,
		budget_usec: int = DEFAULT_AI_PLANNING_BUDGET_USEC
) -> OperationResult:
	_cancel_handoff_warmup(&"contact_superseded")
	if _state_store == null or _state_store.state == null:
		return OperationResult.fail(
			&"initiative_state_missing",
			"The tactical state is unavailable."
		)
	var phase: TacticalPhaseState = _state_store.state.phase_state
	if not phase.is_initiative_combat() or not phase.is_active_unit(unit_id):
		_cancel_contact_warmup()
		return OperationResult.fail(
			&"contact_warmup_wrong_actor",
			"The contact warmup actor is no longer active."
		)
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if (
		unit == null
		or not unit.is_ai_controlled()
		or not unit.can_take_actions()
		or unit.squad_id.is_empty()
		or not _state_store.state.is_squad_aware(unit.squad_id)
		or _action_planner == null
		or has_pending_reaction()
	):
		_cancel_contact_warmup()
		return OperationResult.no_change(
			unit_id,
			"The active unit is not eligible for contact planning warmup."
		)
	if _contact_warmup_job == null or _contact_warmup_unit_id != unit_id:
		var perception_result: OperationResult = _prepare_perception_before_warmup(unit)
		if perception_result == null or not perception_result.success:
			_cancel_contact_warmup()
			return (
				perception_result
				if perception_result != null
				else OperationResult.fail(
					&"contact_perception_result_missing",
					"Contact perception warmup returned no result."
				)
			)
	var perception_revision: int = _perception_revision_for_squad(unit.squad_id)
	var dependencies_match: bool = false
	if _contact_warmup_job != null and _contact_warmup_unit_id == unit_id:
		_warmup_revision_stamp_comparisons += 1
		dependencies_match = (
			_contact_warmup_stamp != null
			and _contact_warmup_stamp.matches(
				_state_store.state,
				unit,
				unit.action_budget.remaining_turn_capacity_feet,
				unit.diagonal_steps_used,
				&"contact",
				perception_revision
			)
		)
	if not dependencies_match:
		_cancel_contact_warmup(false)
		_contact_warmup_stamp = EnemyPlanDependencyStamp.capture(
			_state_store.state,
			unit,
			unit.action_budget.remaining_turn_capacity_feet,
			unit.diagonal_steps_used,
			&"contact",
			perception_revision
		)
		_warmup_revision_stamp_builds += 1
		_contact_warmup_job = _action_planner.call(
			"begin_plan_activation",
			unit
		) as EnemyActivationPlanningJob
		if _contact_warmup_job == null:
			return OperationResult.fail(
				&"contact_warmup_job_missing",
				"The enemy planner returned no contact warmup job."
			)
		_contact_warmup_unit_id = unit_id
		_contact_warmup_signature = ""
		_contact_warmup_perception_revision = perception_revision
		_contact_warmup_processing_usec = 0
		_contact_warmup_slices = 0
	if _contact_warmup_job.complete:
		return OperationResult.pending(
			&"enemy_contact_warmup_ready",
			_contact_warmup_job.plan,
			"The first enemy plan is prepared for contact.",
			_state_store.state.revision
		)
	var started_usec: int = Time.get_ticks_usec()
	var complete: bool = bool(_action_planner.call(
		"step_plan_job",
		_contact_warmup_job,
		maxi(250, budget_usec)
	))
	_contact_warmup_processing_usec += maxi(
		0,
		Time.get_ticks_usec() - started_usec
	)
	_contact_warmup_slices += 1
	if complete:
		_contact_warmup_ready_count += 1
		return OperationResult.pending(
			&"enemy_contact_warmup_ready",
			_contact_warmup_job.plan,
			"The first enemy plan is prepared for contact.",
			_state_store.state.revision
		)
	return OperationResult.pending(
		&"enemy_contact_warmup_pending",
		_contact_warmup_job,
		"The first enemy plan is warming during the contact presentation.",
		_state_store.state.revision
	)


func cancel_contact_ai_warmup() -> void:
	_cancel_contact_warmup()


func _contact_warmup_signature_for_unit(unit: TacticalUnitState) -> String:
	if unit == null or _state_store == null or _state_store.state == null:
		return ""
	var state: TacticalState = _state_store.state
	var squad: TacticalSquadState = state.get_squad(unit.squad_id)
	var parts: Array[String] = [
		"g:%d" % state.geometry_revision(),
		"o:%d" % state.spatial_occupancy_revision(),
		"v:%d" % state.spatial_visibility_blocker_revision(),
		"p:%d" % _perception_revision_for_squad(unit.squad_id),
		"u:%s:%d:%d" % [
			String(unit.unit_id), unit.grid_position.x, unit.grid_position.y,
		],
		"b:%d:%d:%d" % [
			unit.action_budget.remaining_turn_capacity_feet,
			unit.diagonal_steps_used,
			1 if unit.can_take_actions() else 0,
		],
		"l:%s:%d:%d" % [
			String(unit.life_state_id()), unit.current_hp, unit.nonlethal_damage,
		],
		"s:%s:%s" % [
			String(unit.squad_id),
			String(squad.awareness if squad != null else &""),
		],
	]
	var hostiles: Array[TacticalUnitState] = []
	for other: TacticalUnitState in state.get_units():
		if (
			other != null
			and other.team_id != unit.team_id
			and not other.is_defeated()
			and other.is_revealed_to_squad(unit.squad_id)
		):
			hostiles.append(other)
	hostiles.sort_custom(
		func(a: TacticalUnitState, b: TacticalUnitState) -> bool:
			return String(a.unit_id) < String(b.unit_id)
	)
	for hostile: TacticalUnitState in hostiles:
		parts.append(
			"h:%s:%d:%d:%d" % [
				String(hostile.unit_id),
				hostile.grid_position.x,
				hostile.grid_position.y,
				1 if hostile.stealth_enabled else 0,
			]
		)
	return "|".join(PackedStringArray(parts))


func _take_valid_contact_warmup_job(
		unit: TacticalUnitState
) -> EnemyActivationPlanningJob:
	if (
		unit == null
		or _contact_warmup_job == null
		or _contact_warmup_unit_id != unit.unit_id
	):
		return null
	var prevalidated: bool = (
		_prevalidated_ai_handoff_unit_id == unit.unit_id
		and _prevalidated_ai_handoff_kind == &"contact"
		and _prevalidated_ai_handoff_stamp == _contact_warmup_stamp
	)
	if not prevalidated:
		_warmup_revision_stamp_comparisons += 1
		if (
			_contact_warmup_stamp == null
			or not _contact_warmup_stamp.matches(
				_state_store.state,
				unit,
				unit.action_budget.remaining_turn_capacity_feet,
				unit.diagonal_steps_used,
				&"contact",
				_perception_revision_for_squad(unit.squad_id)
			)
		):
			_contact_warmup_invalidated_count += 1
			_cancel_contact_warmup(false)
			return null
	if not _warmup_perception_is_current(
		unit, _contact_warmup_perception_revision
	):
		_contact_warmup_invalidated_count += 1
		_warmup_invalidated_by_perception_count += 1
		_cancel_contact_warmup(false)
		return null
	var result: EnemyActivationPlanningJob = _contact_warmup_job
	_contact_warmup_job = null
	_contact_warmup_unit_id = &""
	_contact_warmup_signature = ""
	_contact_warmup_stamp = null
	_contact_warmup_reused_count += 1
	_contact_warmup_perception_revision = 0
	_clear_prevalidated_ai_handoff()
	return result


func _cancel_contact_warmup(count_invalidation: bool = true) -> void:
	if (
		_contact_warmup_job != null
		and not _contact_warmup_job.complete
		and _action_planner != null
		and _action_planner.has_method("cancel_plan_job")
	):
		_action_planner.call("cancel_plan_job", _contact_warmup_job)
	if count_invalidation and _contact_warmup_job != null:
		_contact_warmup_invalidated_count += 1
	_contact_warmup_job = null
	_contact_warmup_unit_id = &""
	_contact_warmup_signature = ""
	_contact_warmup_stamp = null
	_contact_warmup_perception_revision = 0
	_clear_prevalidated_ai_handoff()


func resolve_initiative_activation(
		unit_id: StringName,
		budget_usec: int = DEFAULT_AI_PLANNING_BUDGET_USEC
) -> OperationResult:
	if _state_store == null or _state_store.state == null:
		return OperationResult.fail(
			&"initiative_state_missing",
			"The tactical state is unavailable."
		)
	var phase: TacticalPhaseState = _state_store.state.phase_state
	if not phase.is_initiative_combat() or not phase.is_active_unit(unit_id):
		_clear_pending_planning_job()
		_cancel_contact_warmup()
		return OperationResult.fail(
			&"wrong_active_unit",
			"This is not the active initiative unit."
		)
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null or not unit.is_ai_controlled():
		_clear_pending_planning_job()
		_cancel_contact_warmup()
		return OperationResult.fail(
			&"initiative_ai_missing",
			"The active unit is not AI-controlled."
		)
	if is_enemy_plan_ready_to_commit():
		return _plan_ready_result(unit)
	var slice_started_usec: int = Time.get_ticks_usec()
	var result: OperationResult
	if has_pending_enemy_planning():
		if _pending_planning_unit_id != unit_id:
			_clear_pending_planning_job()
			return OperationResult.fail(
				&"initiative_planning_actor_changed",
				"The active initiative actor changed during AI planning."
			)
		result = _continue_pending_planning_activation(budget_usec)
	else:
		_begin_activation_diagnostics(unit, &"initiative")
		_pending_activation_simulation_usec = 0
		if (
			unit.squad_id.is_empty()
			or not _state_store.state.is_squad_aware(unit.squad_id)
		):
			result = _finish_activation(
				unit,
				false,
				"%s belongs to an Unaware squad and passes."
				% unit.display_name
			)
		elif not unit.can_take_actions():
			result = _finish_activation(
				unit,
				false,
				"%s cannot act and passes." % unit.display_name,
				true
			)
		else:
			result = _execute_standard_combat(unit, false, budget_usec)
	_pending_activation_simulation_usec += maxi(
		0,
		Time.get_ticks_usec() - slice_started_usec
	)
	if result.code in [
		&"enemy_planning_pending",
		&"enemy_plan_ready",
	]:
		return result
	_record_activation_timing_elapsed(
		unit_id,
		_pending_activation_simulation_usec,
		result,
		&"initiative"
	)
	_pending_activation_simulation_usec = 0
	return result


func _record_activation_timing(
		unit_id: StringName,
		started_usec: int,
		result: OperationResult,
		mode: StringName
) -> void:
	_record_activation_timing_elapsed(
		unit_id,
		maxi(0, Time.get_ticks_usec() - started_usec),
		result,
		mode
	)


func _record_activation_timing_elapsed(
		unit_id: StringName,
		elapsed_usec: int,
		result: OperationResult,
		mode: StringName
) -> void:
	var safe_elapsed_usec: int = maxi(0, elapsed_usec)
	_activation_timing_samples += 1
	_activation_total_usec += safe_elapsed_usec
	_activation_max_usec = maxi(_activation_max_usec, safe_elapsed_usec)
	_active_activation_breakdown["total"] = safe_elapsed_usec
	_active_activation_breakdown["total_usec"] = safe_elapsed_usec
	_active_activation_breakdown["simulation_usec"] = safe_elapsed_usec
	_active_activation_breakdown["unit_id"] = unit_id
	_active_activation_breakdown["mode"] = mode
	_active_activation_breakdown["result_code"] = (
		result.code if result != null else &"missing_result"
	)
	_active_activation_breakdown["success"] = (
		result.success if result != null else false
	)
	_active_activation_breakdown["planning_yield_count"] = (
		_pending_planning_frame_yield_count
	)
	_active_activation_breakdown["planning_max_slices_per_frame"] = (
		_pending_planning_max_slices_per_frame
	)
	_active_activation_breakdown["hidden_planning_frames"] = (
		_pending_hidden_planning_frames
	)
	_active_activation_breakdown["destination_visibility_yield_count"] = (
		_pending_destination_visibility_yield_count
	)
	_activation_sample_serial += 1
	_active_activation_breakdown["sample_serial"] = _activation_sample_serial
	_last_activation_timing = _active_activation_breakdown.duplicate(true)
	_slow_activation_history.append(_last_activation_timing.duplicate(true))
	_sort_slow_activation_history()


func _sort_slow_activation_history() -> void:
	_slow_activation_history.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var total_a: int = int(a.get("total", 0))
			var total_b: int = int(b.get("total", 0))
			if total_a != total_b:
				return total_a > total_b
			return String(a.get("unit_id", &"")) < String(b.get("unit_id", &""))
	)
	while _slow_activation_history.size() > SLOW_ACTIVATION_HISTORY_LIMIT:
		_slow_activation_history.pop_back()


func _begin_activation_diagnostics(
		unit: TacticalUnitState,
		mode: StringName
) -> void:
	_pending_planning_frame_yield_count = 0
	_pending_planning_max_slices_per_frame = 0
	_pending_hidden_planning_frames = 0
	_pending_destination_visibility_yield_count = 0
	_active_activation_breakdown = {
		"unit_id": unit.unit_id if unit != null else &"",
		"unit_name": unit.display_name if unit != null else "Unknown enemy",
		"unit_type": unit.roster_role if unit != null else &"unknown",
		"ai_profile": unit.ai_profile_id if unit != null else &"",
		"mode": mode,
		"plan_kind": &"none",
		"visible": (
			_event_visibility_for_unit(unit) == &"player" if unit != null else false
		),
		"total": 0,
		"total_usec": 0,
		"simulation_usec": 0,
		"presentation_usec": 0,
		"start_effects": 0,
		"support_and_rescue": 0,
		"perception": 0,
		"ability_selection": 0,
		"planning": 0,
		"planning_processing_usec": 0,
		"planning_wall_clock_usec": 0,
		"planning_slices": 0,
		"planning_yield_count": 0,
		"planning_max_slices_per_frame": 0,
		"hidden_planning_frames": 0,
		"destination_visibility_yield_count": 0,
		"contact_warmup_reused": false,
		"contact_warmup_processing_usec": 0,
		"contact_warmup_slices": 0,
		"handoff_warmup_reused": false,
		"chain_warmup_reused": false,
		"handoff_warmup_processing_usec": 0,
		"handoff_warmup_slices": 0,
		"perception_refresh_skipped": false,
		"perception_skip_reason": &"",
		"perception_current_before_activation": false,
		"activation_perception_gate_usec": 0,
		"warmup_validation_usec": 0,
		"warmup_dependency_comparisons": 0,
		"warmup_full_signature_builds": 0,
		"warmup_invalidated_by_perception": false,
		"cold_replan_after_warmup": false,
		"activation_start_to_plan_consumed_usec": 0,
		"activation_ability_scan_usec": 0,
		"activation_support_scan_usec": 0,
		"target_discovery": 0,
		"direct_attack_check": 0,
		"reachable_field": 0,
		"reachable_field_builds": 0,
		"targeted_melee_search": 0,
		"targeted_melee_search_builds": 0,
		"targeted_melee_attack_searches": 0,
		"targeted_melee_approach_searches": 0,
		"targeted_melee_goal_count": 0,
		"targeted_melee_attack_capacity_feet": 0,
		"targeted_melee_expansions": 0,
		"planning_stage": &"none",
		"candidate_scoring": 0,
		"candidate_count": 0,
		"bounded_shortlist_count": 0,
		"exact_geometry": 0,
		"destination_visibility_prepare": 0,
		"prepared_visibility_cache_hit": false,
		"destination_visibility_slices": 0,
		"destination_visibility_cache_hits": 0,
		"destination_visibility_cache_misses": 0,
		"reaction_scan": 0,
		"movement_commit": 0,
		"attack_commit": 0,
		"finish_activation": 0,
		"target_count": 0,
		"reachable_tile_count": 0,
		"cheap_candidates_considered": 0,
		"exact_candidates_evaluated": 0,
		"pathfinding_expansions": 0,
	}


func _add_activation_stage_time(stage: StringName, started_usec: int) -> void:
	_active_activation_breakdown[stage] = int(
		_active_activation_breakdown.get(stage, 0)
	) + maxi(0, Time.get_ticks_usec() - started_usec)


func _merge_planner_diagnostics() -> void:
	if _action_planner == null or not _action_planner.has_method("last_plan_diagnostics"):
		return
	var diagnostics: Dictionary = _action_planner.call("last_plan_diagnostics")
	_active_activation_breakdown["planning"] = int(
		diagnostics.get("processing_usec", diagnostics.get("total_usec", 0))
	)
	_active_activation_breakdown["planning_processing_usec"] = int(
		diagnostics.get("processing_usec", 0)
	)
	_active_activation_breakdown["planning_wall_clock_usec"] = int(
		diagnostics.get("total_usec", 0)
	)
	_active_activation_breakdown["planning_slices"] = int(
		diagnostics.get("planning_slices", 0)
	)
	_active_activation_breakdown["target_discovery"] = int(
		diagnostics.get("target_discovery_usec", 0)
	)
	_active_activation_breakdown["direct_attack_check"] = int(
		diagnostics.get("direct_attack_check_usec", 0)
	)
	_active_activation_breakdown["reachable_field"] = int(
		diagnostics.get("reachable_field_usec", 0)
	)
	_active_activation_breakdown["candidate_scoring"] = int(
		diagnostics.get("candidate_scoring_usec", 0)
	)
	_active_activation_breakdown["targeted_melee_search"] = int(
		diagnostics.get("targeted_melee_search_usec", 0)
	)
	_active_activation_breakdown["exact_geometry"] = int(
		diagnostics.get("exact_geometry_usec", 0)
	)
	for key: StringName in [
		&"plan_kind",
		&"target_count",
		&"reachable_field_builds",
		&"targeted_melee_search_builds",
		&"targeted_melee_attack_searches",
		&"targeted_melee_approach_searches",
		&"targeted_melee_goal_count",
		&"targeted_melee_attack_capacity_feet",
		&"targeted_melee_expansions",
		&"planning_stage",
		&"reachable_tile_count",
		&"candidate_count",
		&"bounded_shortlist_count",
		&"cheap_candidates_considered",
		&"exact_candidates_evaluated",
		&"pathfinding_expansions",
	]:
		_active_activation_breakdown[key] = diagnostics.get(key, 0)


func _stable_participant_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for unit: TacticalUnitState in _state_store.state.get_enemy_turn_units():
		result.append(unit.unit_id)
	result.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return str(a) < str(b)
	)
	return result


func _record_activation_order(participant_ids: Array[StringName]) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var labels: Array[String] = []
	for unit_id: StringName in participant_ids:
		var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
		if (
			unit != null
			and unit.is_ai_controlled()
			and _event_visibility_for_unit(unit) != &"player"
		):
			labels.append("Unknown enemy")
		else:
			labels.append(unit.display_name if unit != null else str(unit_id))
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"enemy_activation_order",
		phase.round_number,
		phase.current_phase,
		"Enemy activation order established.",
		{
			"category": &"events",
			"details": [
				"Stable order: %s" % " → ".join(PackedStringArray(labels)),
			],
		}
	)


func _try_execute_hidden_auto_pass_batch() -> OperationResult:
	if (
		_state_store == null
		or _state_store.state == null
		or _side_turn_index < 0
		or _side_turn_index >= _side_turn_participant_ids.size()
	):
		return null

	var units: Array[TacticalUnitState] = []
	var unit_ids: Array[StringName] = []
	var summaries: Array[String] = []
	var scan_index: int = _side_turn_index
	while scan_index < _side_turn_participant_ids.size():
		var unit_id: StringName = _side_turn_participant_ids[scan_index]
		var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
		if not _is_hidden_auto_pass_batch_candidate(unit):
			break
		units.append(unit)
		unit_ids.append(unit.unit_id)
		summaries.append(
			"%s has no legal actions and passes." % unit.display_name
		)
		scan_index += 1

	if units.is_empty():
		return null

	var started_usec: int = Time.get_ticks_usec()
	var snapshots: Array[Dictionary] = []
	for unit: TacticalUnitState in units:
		snapshots.append({
			"unit": unit,
			"budget": _budget_snapshot(unit),
		})

	var changes := TacticalChangeSet.new(
		&"hidden_enemy_auto_pass_batch",
		_state_store.state.revision,
		TacticalInvalidationContract.action_budget(unit_ids)
	)
	changes.set_commit_validation_policy(false, false)
	changes.require(
		Callable(self, "_validate_hidden_auto_pass_batch").bind(units),
		"The hidden enemy auto-pass batch produced an invalid action budget.",
		&"hidden_enemy_auto_pass_batch_invalid"
	)
	changes.stage(
		Callable(self, "_apply_hidden_auto_pass_batch").bind(units),
		Callable(self, "_restore_hidden_auto_pass_batch").bind(snapshots),
		"The hidden enemy auto-pass batch could not be committed.",
		&"hidden_enemy_auto_pass_batch_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed

	for index: int in range(units.size()):
		var unit: TacticalUnitState = units[index]
		_record_turn_started(unit, "Automatic Pass")
		_record_turn_finished(unit, false, summaries[index], false)
		_side_turn_summaries.append(summaries[index])

	_side_turn_index = scan_index
	_hidden_auto_pass_actor_count += units.size()
	_hidden_auto_pass_batch_count += 1
	_hidden_auto_pass_transaction_count += 1
	_hidden_auto_pass_max_batch_size = maxi(
		_hidden_auto_pass_max_batch_size,
		units.size()
	)
	var elapsed_usec: int = maxi(0, Time.get_ticks_usec() - started_usec)
	_hidden_auto_pass_total_usec += elapsed_usec

	var representative: TacticalUnitState = units.back()
	_begin_activation_diagnostics(representative, &"side_based_hidden_batch")
	_active_activation_breakdown["plan_kind"] = &"hidden_auto_pass_batch"
	_active_activation_breakdown["batch_size"] = units.size()
	_active_activation_breakdown["hidden_auto_pass_batch"] = true
	var result := OperationResult.new(
		true,
		&"enemy_activation_completed",
		(
			"%d hidden enemies passed without visible actions." % units.size()
			if units.size() > 1
			else summaries[0]
		),
		{
			"unit_id": representative.unit_id,
			"participant_index": _side_turn_index,
			"participant_count": _side_turn_participant_ids.size(),
			"turn_complete": false,
			"hidden_auto_pass_batch": true,
			"batch_size": units.size(),
			"unit_ids": unit_ids.duplicate(),
		},
		OperationResult.STATUS_COMMITTED,
		[],
		_state_store.state.revision
	)
	_record_activation_timing_elapsed(
		representative.unit_id,
		elapsed_usec,
		result,
		&"side_based_hidden_batch"
	)
	return result


func _is_hidden_auto_pass_batch_candidate(
		unit: TacticalUnitState
) -> bool:
	if (
		unit == null
		or not unit.should_receive_enemy_turn()
		or _event_visibility_for_unit(unit) == &"player"
	):
		return false
	if (
		not unit.squad_id.is_empty()
		and not _state_store.state.is_squad_aware(unit.squad_id)
	):
		return true
	return unit.turn_behavior == TacticalUnitState.TURN_BEHAVIOR_AUTO_PASS


func _apply_hidden_auto_pass_batch(
	units: Array[TacticalUnitState]
) -> bool:
	for unit: TacticalUnitState in units:
		if unit == null:
			return false
		unit.refresh_for_new_round()
		unit.mark_activation_ended()
	return true


func _restore_hidden_auto_pass_batch(
	snapshots: Array[Dictionary]
) -> void:
	for snapshot: Dictionary in snapshots:
		var unit: TacticalUnitState = snapshot.get("unit") as TacticalUnitState
		if unit == null:
			continue
		_restore_budget(unit, snapshot.get("budget", {}) as Dictionary)


func _validate_hidden_auto_pass_batch(
	units: Array[TacticalUnitState]
) -> String:
	for unit: TacticalUnitState in units:
		var error: String = _validate_action_budget_state(unit)
		if not error.is_empty():
			return error
		if not unit.action_budget.ended_activation:
			return "A hidden auto-pass actor did not end its activation."
	return ""


func _execute_activation(
		unit_id: StringName,
		budget_usec: int = DEFAULT_AI_PLANNING_BUDGET_USEC
) -> OperationResult:
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return OperationResult.fail(
			&"enemy_turn_unit_missing",
			"An enemy participant no longer exists."
		)
	if not unit.should_receive_enemy_turn():
		return OperationResult.fail(
			&"enemy_turn_unit_ineligible",
			"%s is not eligible for an Enemy Turn activation."
			% unit.display_name
		)

	if unit.is_defeated():
		return _execute_defeated_skip(unit)
	if (
		unit.is_incapacitated()
		and not unit.has_timed_effect(&"condition.hold_person")
	):
		return _execute_incapacitated_skip(unit)
	if (
		not unit.squad_id.is_empty()
		and not _state_store.state.is_squad_aware(unit.squad_id)
	):
		return _execute_auto_pass(unit)
	if unit.turn_behavior == TacticalUnitState.TURN_BEHAVIOR_AUTO_PASS:
		return _execute_auto_pass(unit)
	if unit.turn_behavior == TacticalUnitState.TURN_BEHAVIOR_STANDARD:
		return _execute_standard_combat(unit, true, budget_usec)
	return OperationResult.fail(
		&"enemy_turn_behavior_unimplemented",
		"%s has an unsupported Enemy Turn behaviour." % unit.display_name
	)


func _execute_standard_combat(
		unit: TacticalUnitState,
		refresh_budget: bool = true,
		planning_budget_usec: int = DEFAULT_AI_PLANNING_BUDGET_USEC
) -> OperationResult:
	var activation_gate_started_usec: int = Time.get_ticks_usec()
	var expected_perception_revision: int = 0
	if _contact_warmup_job != null and _contact_warmup_unit_id == unit.unit_id:
		expected_perception_revision = _contact_warmup_perception_revision
	elif _handoff_warmup_job != null and _handoff_warmup_unit_id == unit.unit_id:
		expected_perception_revision = _handoff_warmup_perception_revision

	var started: OperationResult = _begin_activation(unit, "Standard Combat", refresh_budget)
	if not started.success:
		return started

	# Consume a prevalidated warmup immediately after the lightweight budget
	# refresh. Ordinary guards then bypass the former perception/signature gate.
	var plan_job: EnemyActivationPlanningJob = _take_valid_contact_warmup_job(unit)
	if plan_job == null:
		var handoff_was_chain: bool = _handoff_warmup_is_chain
		plan_job = _take_valid_handoff_warmup_job(unit)
		if plan_job != null:
			_active_activation_breakdown["handoff_warmup_reused"] = true
			_active_activation_breakdown["chain_warmup_reused"] = handoff_was_chain
			_active_activation_breakdown["handoff_warmup_processing_usec"] = (
				_handoff_warmup_processing_usec
			)
			_active_activation_breakdown["handoff_warmup_slices"] = (
				_handoff_warmup_slices
			)
	else:
		_active_activation_breakdown["contact_warmup_reused"] = true
		_active_activation_breakdown["contact_warmup_processing_usec"] = (
			_contact_warmup_processing_usec
		)
		_active_activation_breakdown["contact_warmup_slices"] = (
			_contact_warmup_slices
		)
	_active_activation_breakdown["activation_start_to_plan_consumed_usec"] = maxi(
		0, Time.get_ticks_usec() - activation_gate_started_usec
	)

	if _ability_service != null:
		var has_start_work: bool = (
			bool(_ability_service.call(
				"has_start_of_activation_work", unit.unit_id
			))
			if _ability_service.has_method("has_start_of_activation_work")
			else true
		)
		if has_start_work:
			var start_effects_started_usec: int = Time.get_ticks_usec()
			var start_effect_result: OperationResult = (
				_ability_service.resolve_start_of_activation(unit.unit_id)
			)
			_add_activation_stage_time(&"start_effects", start_effects_started_usec)
			if start_effect_result != null and not start_effect_result.success:
				return start_effect_result
			if not unit.can_take_actions():
				return _finish_activation(
					unit,
					false,
					"%s is unable to act after ongoing effects resolve." % unit.display_name
				)
			# Any committed start effect can alter capacity or targets. Discard the
			# read-only forecast and let the responsive planner rebuild from truth.
			if (
				start_effect_result != null
				and start_effect_result.commit_status
				!= OperationResult.STATUS_NO_CHANGE
				and plan_job != null
			):
				_action_planner.call("cancel_plan_job", plan_job)
				plan_job = null
				_cold_replan_after_warmup_count += 1
				_active_activation_breakdown["cold_replan_after_warmup"] = true
		var ability_scan_started_usec: int = Time.get_ticks_usec()
		var has_special_ability: bool = (
			bool(_ability_service.call(
				"has_ai_usable_special_abilities", unit.unit_id
			))
			if _ability_service.has_method("has_ai_usable_special_abilities")
			else true
		)
		_active_activation_breakdown["activation_ability_scan_usec"] = maxi(
			0, Time.get_ticks_usec() - ability_scan_started_usec
		)
		if has_special_ability:
			var ability_started_usec: int = Time.get_ticks_usec()
			var ability_result: OperationResult = (
				_ability_service.execute_best_ai_ability(unit.unit_id)
			)
			_add_activation_stage_time(&"ability_selection", ability_started_usec)
			if ability_result != null:
				if not ability_result.success:
					return ability_result
				return _finish_activation(unit, true, ability_result.message)

	var support_scan_started_usec: int = Time.get_ticks_usec()
	var support_result: OperationResult = null
	var profile: TacticalAIProfileDefinition = (
		_catalogue.ai_profile(unit.ai_profile_id) if _catalogue != null else null
	)
	if (
		profile != null
		and profile.role == TacticalAIProfileDefinition.ROLE_SUPPORT
		and profile.support_priority > 0
	):
		support_result = _try_support_adjacent_ally(unit)
	if support_result == null and _has_adjacent_restrained_ally(unit):
		support_result = _try_untie_adjacent_ally(unit)
	_active_activation_breakdown["activation_support_scan_usec"] = maxi(
		0, Time.get_ticks_usec() - support_scan_started_usec
	)
	_add_activation_stage_time(&"support_and_rescue", support_scan_started_usec)
	if support_result != null:
		if not support_result.success:
			return support_result
		return _finish_activation(unit, true, support_result.message)

	if _action_planner == null:
		return OperationResult.fail(
			&"enemy_action_planner_missing",
			"The enemy action planner is unavailable."
		)

	var perception_started_usec: int = Time.get_ticks_usec()
	var perception_result: OperationResult
	if plan_job != null and _warmup_perception_is_current(
		unit, expected_perception_revision
	):
		perception_result = OperationResult.new(
			true,
			&"perception_current_from_warmup",
			"Squad perception was completed before the enemy handoff.",
			false,
			OperationResult.STATUS_NO_CHANGE,
			[],
			_state_store.state.revision
		)
		_active_activation_breakdown["perception_refresh_skipped"] = true
		_active_activation_breakdown["perception_skip_reason"] = (
			&"warmup_revision_current"
		)
		_active_activation_breakdown["perception_current_before_activation"] = true
	else:
		perception_result = _refresh_squad_perception(unit)
		if plan_job != null:
			_action_planner.call("cancel_plan_job", plan_job)
			plan_job = null
			_warmup_invalidated_by_perception_count += 1
			_cold_replan_after_warmup_count += 1
			_active_activation_breakdown["warmup_invalidated_by_perception"] = true
			_active_activation_breakdown["cold_replan_after_warmup"] = true
	var perception_gate_usec: int = maxi(
		0, Time.get_ticks_usec() - perception_started_usec
	)
	_activation_perception_gate_total_usec += perception_gate_usec
	_active_activation_breakdown["activation_perception_gate_usec"] = (
		perception_gate_usec
	)
	_add_activation_stage_time(&"perception", perception_started_usec)
	if perception_result == null or not perception_result.success:
		return (
			perception_result
			if perception_result != null
			else OperationResult.fail(
				&"perception_result_missing",
				"Enemy perception refresh returned no result."
			)
		)
	if perception_result.code == &"perception_current_from_contact":
		_active_activation_breakdown["perception_refresh_skipped"] = true
		_active_activation_breakdown["perception_skip_reason"] = (
			&"contact_resolution_current"
		)

	if plan_job == null:
		plan_job = _action_planner.call(
			"begin_plan_activation", unit
		) as EnemyActivationPlanningJob
	if plan_job == null:
		return OperationResult.fail(
			&"enemy_planning_job_missing",
			"The enemy action planner returned no planning job."
		)
	var planning_complete: bool = plan_job.complete
	if not planning_complete:
		planning_complete = bool(_action_planner.call(
			"step_plan_job",
			plan_job,
			maxi(250, planning_budget_usec)
		))
	if not planning_complete:
		_pending_planning_job = plan_job
		_pending_planning_unit_id = unit.unit_id
		_pending_planning_side_based = refresh_budget
		_pending_planning_refresh_budget = refresh_budget
		_pending_planning_mode = (
			&"side_based" if refresh_budget else &"initiative"
		)
		return _planning_pending_result(unit)
	_merge_planner_diagnostics()
	return _begin_destination_visibility_without_blocking(
		unit,
		plan_job.plan,
		refresh_budget
	)


func _continue_pending_planning_activation(
		budget_usec: int = DEFAULT_AI_PLANNING_BUDGET_USEC
) -> OperationResult:
	if _pending_planning_unit_id.is_empty():
		return OperationResult.fail(
			&"enemy_planning_context_missing",
			"No enemy planning context is available to continue."
		)
	var unit: TacticalUnitState = _state_store.state.get_unit(
		_pending_planning_unit_id
	)
	if unit == null:
		_clear_pending_planning_job()
		return OperationResult.fail(
			&"enemy_planning_unit_missing",
			"The enemy being planned no longer exists."
		)

	if _pending_planning_job != null and not _pending_planning_job.complete:
		var planning_complete: bool = bool(_action_planner.call(
			"step_plan_job",
			_pending_planning_job,
			maxi(250, budget_usec)
		))
		if not planning_complete:
			return _planning_pending_result(unit)
		var completed_plan: RefCounted = _pending_planning_job.plan
		_pending_planning_job = null
		_merge_planner_diagnostics()
		return _begin_destination_visibility_without_blocking(
			unit,
			completed_plan,
			_pending_planning_refresh_budget
		)

	if _pending_completed_plan == null:
		return OperationResult.fail(
			&"enemy_planning_plan_missing",
			"Enemy planning completed without an action plan."
		)
	return _plan_ready_result(unit)


func _plan_ready_result(
		unit: TacticalUnitState
) -> OperationResult:
	return OperationResult.pending(
		&"enemy_plan_ready",
		{
			"unit_id": unit.unit_id if unit != null else _pending_planning_unit_id,
			"mode": _pending_planning_mode,
			"destination_visibility_pending": has_pending_enemy_destination_visibility(),
		},
		"%s has completed its action plan." % (
			unit.display_name
			if unit != null and _event_visibility_for_unit(unit) == &"player"
			else "An enemy"
		),
		_state_store.state.revision
	)


func _planning_pending_result(
		unit: TacticalUnitState
) -> OperationResult:
	return OperationResult.pending(
		&"enemy_planning_pending",
		_pending_planning_job,
		"%s is planning its activation." % (
			unit.display_name
			if unit != null and _event_visibility_for_unit(unit) == &"player"
			else "An enemy"
		),
		_state_store.state.revision
	)


func _clear_pending_planning_job(
		cancel_job: bool = true,
		cancel_visibility_job: bool = true
) -> void:
	if (
		cancel_job
		and _pending_planning_job != null
		and not _pending_planning_job.complete
		and _action_planner != null
		and _action_planner.has_method("cancel_plan_job")
	):
		_action_planner.call("cancel_plan_job", _pending_planning_job)
	if cancel_visibility_job:
		_cancel_pending_enemy_destination_visibility()
	_pending_planning_job = null
	_pending_completed_plan = null
	_pending_planning_unit_id = &""
	_pending_planning_side_based = false
	_pending_planning_refresh_budget = true
	_pending_planning_mode = &""


func _begin_destination_visibility_without_blocking(
		unit: TacticalUnitState,
		plan: RefCounted,
		refresh_budget: bool
) -> OperationResult:
	# The old 5f path completed this job before movement could commit. Cold centre
	# and Peek/Lean fields therefore created responsive but visibly empty frames.
	# Start the immutable job now, then let the screen advance it during the tween.
	_cancel_pending_enemy_destination_visibility()
	if (
		unit != null
		and plan != null
		and bool(plan.get("valid"))
		and bool(plan.get("move_required"))
		and _visibility_service != null
		and _visibility_service.has_method(
			"begin_visibility_preparation_for_destination"
		)
	):
		_pending_visibility_job = _visibility_service.call(
			"begin_visibility_preparation_for_destination",
			unit.unit_id,
			Vector2i(plan.get("move_destination"))
		) as RefCounted
		if (
			_pending_visibility_job != null
			and bool(_pending_visibility_job.get("complete"))
		):
			_capture_destination_visibility_job_diagnostics(
				_pending_visibility_job
			)
			_pending_visibility_job = null
	_store_completed_plan_for_commit(unit, plan, refresh_budget)
	return _plan_ready_result(unit)


func _store_completed_plan_for_commit(
		unit: TacticalUnitState,
		plan: RefCounted,
		refresh_budget: bool
) -> void:
	_pending_completed_plan = plan
	_pending_planning_job = null
	_pending_planning_unit_id = unit.unit_id if unit != null else &""
	_pending_planning_side_based = refresh_budget
	_pending_planning_refresh_budget = refresh_budget
	_pending_planning_mode = (
		&"side_based" if refresh_budget else &"initiative"
	)


func _reconcile_destination_visibility_after_commit(
		unit: TacticalUnitState,
		result: OperationResult
) -> void:
	if _pending_visibility_job == null:
		return
	if (
		result == null
		or not result.success
		or result.code == &"reaction_pending"
		or unit == null
		or unit.grid_position != Vector2i(_pending_visibility_job.get("destination"))
	):
		_cancel_pending_enemy_destination_visibility()


func _capture_destination_visibility_job_diagnostics(job: RefCounted) -> void:
	if job == null:
		return
	_active_activation_breakdown["prepared_visibility_cache_hit"] = (
		bool(job.get("valid"))
		and int(job.get("cache_misses")) == 0
	)
	_active_activation_breakdown["destination_visibility_slices"] = int(
		job.get("processing_slices")
	)
	_active_activation_breakdown["destination_visibility_cache_hits"] = int(
		job.get("cache_hits")
	)
	_active_activation_breakdown["destination_visibility_cache_misses"] = int(
		job.get("cache_misses")
	)


func _execute_planned_combat(
		unit: TacticalUnitState,
		plan: RefCounted,
		refresh_budget: bool
) -> OperationResult:
	if plan == null or not bool(plan.get("valid")):
		var reason: String = (
			str(plan.get("reason"))
			if plan != null
			else "%s could not construct an action plan." % unit.display_name
		)
		var reaction_started_usec: int = Time.get_ticks_usec()
		var reservation_result: OperationResult = _try_prepare_ai_reaction(unit)
		_add_activation_stage_time(&"reaction_scan", reaction_started_usec)
		if reservation_result != null and reservation_result.success:
			return _finish_activation(unit, true, reservation_result.message)
		return _finish_activation(unit, false, reason + " The unit passes.")

	var plan_kind := StringName(plan.get("kind"))
	_active_activation_breakdown["plan_kind"] = plan_kind
	if plan_kind in [
		EnemyActionPlan.KIND_SEARCH,
		EnemyActionPlan.KIND_RETURN_TO_TASK,
	]:
		return _execute_search_or_return_plan(unit, plan, plan_kind)

	var target_id: StringName = plan.get("target_id")
	var action_id: StringName = plan.get("action_id")
	var target: TacticalUnitState = _state_store.state.get_unit(target_id)
	if target == null or target.is_defeated():
		var reaction_started_usec: int = Time.get_ticks_usec()
		var reservation_result: OperationResult = _try_prepare_ai_reaction(unit)
		_add_activation_stage_time(&"reaction_scan", reaction_started_usec)
		if reservation_result != null and reservation_result.success:
			return _finish_activation(unit, true, reservation_result.message)
		return _finish_activation(
			unit,
			false,
			"%s found no active hostile target and passes." % unit.display_name
		)

	var acted: bool = false
	if bool(plan.get("move_required")):
		var destination: Vector2i = plan.get("move_destination")
		var post_move: Dictionary = {
			"kind": &"combat",
			"target_id": target_id,
			"action_id": action_id,
			"attack_after_move": bool(plan.get("attack_after_move")),
		}
		var movement_started_usec: int = Time.get_ticks_usec()
		var movement_result: OperationResult = _commit_enemy_move(
			unit,
			destination,
			post_move,
			refresh_budget,
			_move_path_from_plan(plan)
		)
		_add_activation_stage_time(&"movement_commit", movement_started_usec)
		if (
			not movement_result.success
			or movement_result.code == &"reaction_pending"
		):
			return movement_result
		acted = true

	if bool(plan.get("attack_after_move")):
		var attack_preview: Variant = _preview_attack(unit, target, action_id)
		if _preview_succeeds(attack_preview):
			var attack_started_usec: int = Time.get_ticks_usec()
			var attack_result: OperationResult = (
				_execute_attack_with_player_reaction(
					unit,
					attack_preview,
					refresh_budget
				)
			)
			_add_activation_stage_time(&"attack_commit", attack_started_usec)
			if (
				not attack_result.success
				or attack_result.code == &"reaction_pending"
			):
				return attack_result
			acted = true

	if not acted:
		var reaction_started_usec: int = Time.get_ticks_usec()
		var reservation_result: OperationResult = _try_prepare_ai_reaction(unit)
		_add_activation_stage_time(&"reaction_scan", reaction_started_usec)
		if reservation_result != null and reservation_result.success:
			return _finish_activation(unit, true, reservation_result.message)
	return _finish_activation(
		unit,
		acted,
		(
			"%s completed its combat activation." % unit.display_name
			if acted
			else "%s has no legal actions and passes." % unit.display_name
		)
	)


func _try_prepare_ai_reaction(unit: TacticalUnitState) -> OperationResult:
	if _reaction_service == null or unit == null:
		return null
	var result: OperationResult = _reaction_service.prepare_best_ai_reservation(
		unit.unit_id
	)
	return result if result.success else null


func _try_support_adjacent_ally(
		unit: TacticalUnitState
) -> OperationResult:
	if _body_action_handler == null or unit == null or _catalogue == null:
		return null
	var profile: TacticalAIProfileDefinition = _catalogue.ai_profile(
		unit.ai_profile_id
	)
	if (
		profile == null
		or profile.role != TacticalAIProfileDefinition.ROLE_SUPPORT
		or profile.support_priority <= 0
	):
		return null
	var medical_item: TacticalItemInstanceState = null
	for item: TacticalItemInstanceState in _state_store.state.get_items():
		if item == null or item.location == null or item.definition == null:
			continue
		if item.location.owner_id != unit.unit_id:
			continue
		if (
			item.definition.permits_first_aid
			or item.definition.permits_administered_healing
		):
			medical_item = item
			break
	if medical_item == null:
		return null
	for ally: TacticalUnitState in _state_store.state.get_units():
		if ally == null or ally.team_id != unit.team_id or ally.unit_id == unit.unit_id:
			continue
		if ally.is_dead() or not ally.is_defeated():
			continue
		var body_item: TacticalItemInstanceState = _state_store.state.body_item_for_unit(
			ally.unit_id
		)
		if body_item == null or body_item.location == null:
			continue
		if body_item.location.location_type != TacticalItemLocationState.LOCATION_TACTICAL_GROUND:
			continue
		var delta: Vector2i = body_item.location.map_position - unit.grid_position
		if maxi(absi(delta.x), absi(delta.y)) > 1:
			continue
		var result: OperationResult = _body_action_handler.apply_item_to_body(
			unit.unit_id, medical_item.item_id, body_item.item_id
		)
		if result.success:
			return result
	return null


func _has_adjacent_restrained_ally(unit: TacticalUnitState) -> bool:
	if unit == null:
		return false
	for ally: TacticalUnitState in _state_store.state.get_units():
		if (
			ally == null
			or ally.team_id != unit.team_id
			or not ally.restrained
		):
			continue
		var delta: Vector2i = ally.grid_position - unit.grid_position
		if maxi(absi(delta.x), absi(delta.y)) <= 1:
			return true
	return false


func _try_untie_adjacent_ally(
		unit: TacticalUnitState
) -> OperationResult:
	if _body_action_handler == null or unit == null:
		return null
	for ally: TacticalUnitState in _state_store.state.get_units():
		if ally.team_id != unit.team_id or not ally.restrained:
			continue
		var body_item: TacticalItemInstanceState = _state_store.state.body_item_for_unit(
			ally.unit_id
		)
		if body_item == null:
			continue
		var reason: String = _body_action_handler.unavailable_reason(
			unit.unit_id, body_item.item_id, TacticalBodyActionHandler.ACTION_UNTIE
		)
		if reason.is_empty():
			return _body_action_handler.untie(unit.unit_id, body_item.item_id)
	return null


func _execute_search_or_return_plan(
		unit: TacticalUnitState,
		plan: RefCounted,
		plan_kind: StringName
) -> OperationResult:
	var acted: bool = false
	if bool(plan.get("move_required")):
		var destination: Vector2i = plan.get("move_destination")
		var post_move: Dictionary = {
			"kind": plan_kind,
			"attack_after_move": false,
		}
		var movement_started_usec: int = Time.get_ticks_usec()
		var movement_result: OperationResult = _commit_enemy_move(
			unit,
			destination,
			post_move,
			true,
			_move_path_from_plan(plan)
		)
		_add_activation_stage_time(&"movement_commit", movement_started_usec)
		if not movement_result.success or movement_result.code == &"reaction_pending":
			return movement_result
		acted = true

	var perception_started_usec: int = Time.get_ticks_usec()
	var perception_result: OperationResult = _refresh_squad_perception(unit)
	_add_activation_stage_time(&"perception", perception_started_usec)
	if not perception_result.success:
		return perception_result

	if plan_kind == EnemyActionPlan.KIND_SEARCH:
		var reacquired: bool = _squad_has_revealed_hostile(unit.squad_id)
		var attack_after_search: bool = false
		if reacquired:
			attack_after_search = _attack_reacquired_target_if_ready(unit)
			acted = acted or attack_after_search
		return _finish_activation(
			unit,
			acted,
			(
				"%s reacquired a hostile while searching." % unit.display_name
				if reacquired
				else "%s searched the Last Seen Position." % unit.display_name
			)
		)

	return _finish_activation(
		unit,
		acted,
		"%s returned toward its prior guard task." % unit.display_name
	)


func _refresh_squad_perception(unit: TacticalUnitState) -> OperationResult:
	if _detection_service == null or unit == null or unit.squad_id.is_empty():
		return OperationResult.ok(false, "No squad perception refresh was required.")
	# AI planning owns an authoritative perception boundary separate from the
	# player-facing fog presentation deferral. The detection service skips the
	# refresh when its deterministic squad signature is unchanged.
	if _detection_service.has_method(
		"refresh_current_perception_for_ai_planning"
	):
		return _detection_service.call(
			"refresh_current_perception_for_ai_planning",
			unit.squad_id
		) as OperationResult
	_detection_service.request_current_perception_for_squad(unit.squad_id)
	return _detection_service.flush_requested_perception_refreshes()


func _squad_has_revealed_hostile(squad_id: StringName) -> bool:
	for player: TacticalUnitState in _state_store.state.get_player_units():
		if (
			not player.is_defeated()
			and player.is_revealed_to_squad(squad_id)
		):
			return true
	return false


func _attack_reacquired_target_if_ready(unit: TacticalUnitState) -> bool:
	var follow_up: RefCounted = _action_planner.call(
		"plan_activation",
		unit
	) as RefCounted
	if (
		follow_up == null
		or not bool(follow_up.get("valid"))
		or StringName(follow_up.get("kind")) != EnemyActionPlan.KIND_COMBAT
		or bool(follow_up.get("move_required"))
		or not bool(follow_up.get("attack_after_move"))
	):
		return false
	var target: TacticalUnitState = _state_store.state.get_unit(
		StringName(follow_up.get("target_id"))
	)
	if target == null or target.is_defeated():
		return false
	var attack_preview: Variant = _preview_attack(
		unit,
		target,
		StringName(follow_up.get("action_id"))
	)
	if not _preview_succeeds(attack_preview):
		return false
	var attack_result: OperationResult = _execute_attack(attack_preview)
	return attack_result.success


func _forget_last_seen(
		squad_id: StringName,
		unit_id: StringName
) -> OperationResult:
	var squad: TacticalSquadState = _state_store.state.get_squad(squad_id)
	if squad == null or unit_id.is_empty():
		return OperationResult.ok(false, "No Last Seen Position needed clearing.")
	var previous: Dictionary = squad.last_seen_positions_by_unit_id.duplicate(true)
	var changes := TacticalChangeSet.new(
		&"last_seen_position_searched",
		_state_store.state.revision,
		TacticalInvalidationContract.token_status([unit_id])
	)
	changes.stage(
		Callable(self, "_apply_forget_last_seen").bind(squad, unit_id),
		Callable(self, "_restore_last_seen").bind(squad, previous),
		"The searched Last Seen Position could not be cleared.",
		&"last_seen_clear_failed"
	)
	return _state_store.commit(changes, _map_definition)


func _apply_forget_last_seen(
		squad: TacticalSquadState,
		unit_id: StringName
) -> bool:
	squad.forget_last_seen(unit_id)
	return true


func _restore_last_seen(
		squad: TacticalSquadState,
		previous: Dictionary
) -> void:
	squad.last_seen_positions_by_unit_id = previous.duplicate(true)


func _preview_attack(
		unit: TacticalUnitState,
		target: TacticalUnitState,
		action_id: StringName
) -> Variant:
	if _attack_preview_query == null:
		return null
	var attack: AttackDefinition = _catalogue.attack_definition(action_id)
	var channel: StringName = (
		attack.default_damage_channel()
		if attack != null
		else TacticalUnitState.DAMAGE_CHANNEL_LETHAL
	)
	return _attack_preview_query.call(
		"execute",
		unit.unit_id,
		target.unit_id,
		action_id,
		0,
		channel
	)


func _preview_succeeds(preview: Variant) -> bool:
	return preview != null and bool(preview.get("success"))


func _execute_attack_with_player_reaction(
		unit: TacticalUnitState,
		preview: Variant,
		side_based: bool,
		movement_action_id: StringName = &""
) -> OperationResult:
	if (
		_reaction_service != null
		and preview != null
		and bool(preview.get("success"))
	):
		var candidate: ReactionCandidate = (
			_reaction_service.first_player_reaction_for_provoking_action(
				unit.unit_id,
				StringName(preview.get("action_id"))
			)
		)
		if candidate != null:
			var action_event_id: StringName = (
				movement_action_id
				if not movement_action_id.is_empty()
				else candidate.movement_action_id
			)
			var payload: Dictionary = {
				"target_id": StringName(preview.get("target_id")),
				"action_id": StringName(preview.get("action_id")),
				"post_move": {},
				"side_based": side_based,
				"side_turn_participant_ids": _side_turn_participant_ids.duplicate(),
				"side_turn_index": _side_turn_index,
			}
			var pending_state: PendingMovementReactionState = (
				_movement_coordinator.build_pending_state(
					unit,
					[],
					[unit.grid_position],
					candidate,
					action_event_id,
					PendingMovementReactionState.CONTINUATION_ENEMY_PROVOKING_ACTION,
					payload,
					0,
					0,
					false,
					_state_store.state.revision
				)
			)
			var pending_commit: OperationResult = (
				_reaction_service.commit_pending_movement_reaction(pending_state)
			)
			if not pending_commit.success:
				return pending_commit
			return OperationResult.pending(
				&"reaction_pending",
				pending_state,
				"The provoking action paused for a player Reaction decision.",
				_state_store.state.revision
			)
	return _execute_attack(preview)


func _execute_attack(preview: Variant) -> OperationResult:
	if _attack_handler == null:
		return OperationResult.fail(
			&"enemy_attack_handler_missing",
			"The enemy attack resolver is unavailable."
		)
	var value: Variant = _attack_handler.call("execute_preview", preview)
	var result: OperationResult = value as OperationResult
	return (
		result
		if result != null
		else OperationResult.fail(
			&"enemy_attack_result_missing",
			"The enemy attack resolver returned no result."
		)
	)


func _move_path_from_plan(plan: RefCounted) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if plan == null:
		return result
	var raw_path: Variant = plan.get("move_path")
	if not (raw_path is Array):
		return result
	for tile_value: Variant in raw_path:
		if tile_value is Vector2i:
			result.append(Vector2i(tile_value))
	return result


func _commit_enemy_move(
		unit: TacticalUnitState,
		destination: Vector2i,
		post_move: Dictionary = {},
		side_based: bool = false,
		planned_path: Array[Vector2i] = []
) -> OperationResult:
	if _reaction_service != null:
		_reaction_service.cancel_reservation_for_voluntary_move(unit.unit_id)
	var navigation := TacticalNavigationSnapshot.new(
		_map_definition, _state_store.state, unit.unit_id
	)
	var path: MovementPathResult
	if (
		planned_path.size() > 0
		and planned_path[0] == unit.grid_position
		and planned_path.back() == destination
	):
		path = MovementRules.calculate_path_cost(
			planned_path,
			navigation,
			unit.diagonal_steps_used
		)
	else:
		path = MovementRules.find_path(
			unit.grid_position,
			destination,
			navigation,
			unit.diagonal_steps_used
		)
	if not path.success:
		return OperationResult.fail(&"enemy_move_invalid", path.failure_reason)
	if path.cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		return OperationResult.fail(
			&"enemy_move_capacity",
			"%s cannot afford its chosen route." % unit.display_name
		)
	var movement_action_id: StringName = (
		_reaction_service.begin_movement_action_id(unit.unit_id)
		if _reaction_service != null
		else &""
	)
	return _commit_enemy_path_with_reactions(
		unit, path.path, movement_action_id, post_move, side_based
	)


func _commit_enemy_path_with_reactions(
		unit: TacticalUnitState,
		planned_path: Array[Vector2i],
		movement_action_id: StringName,
		post_move: Dictionary,
		side_based: bool
) -> OperationResult:
	if planned_path.size() <= 1:
		return OperationResult.no_change(planned_path, "No movement was required.")
	if _reaction_service != null and _movement_coordinator != null:
		var boundary: Dictionary = _movement_coordinator.first_reaction_boundary(
			unit.unit_id,
			planned_path,
			&"normal",
			movement_action_id,
			TacticalMovementResolutionCoordinator.CONTROLLER_PLAYER
		)
		var candidate: ReactionCandidate = boundary.get("candidate") as ReactionCandidate
		if candidate != null:
			var prefix_path: Array[Vector2i] = []
			for tile_value: Variant in boundary.get("prefix_path", []):
				if tile_value is Vector2i:
					prefix_path.append(Vector2i(tile_value))
			if prefix_path.is_empty():
				prefix_path.append(unit.grid_position)
			var prefix_result: OperationResult = _commit_enemy_path(unit, prefix_path)
			if not prefix_result.success:
				return prefix_result

			var step_cost_feet: int = 0
			var step_diagonal_steps: int = 0
			var step_cost_prepaid: bool = false
			if candidate.timing_kind == ReactionCandidate.TIMING_BEFORE_ENTRY:
				var cost_result: OperationResult = _commit_enemy_step_cost(
					unit,
					candidate.trigger_origin,
					candidate.trigger_destination
				)
				if not cost_result.success:
					return cost_result
				var step_path: MovementPathResult = cost_result.data as MovementPathResult
				step_cost_feet = step_path.cost_feet
				step_diagonal_steps = step_path.diagonal_steps
				step_cost_prepaid = true

			var payload: Dictionary = {
				"post_move": post_move.duplicate(true),
				"side_based": side_based,
				"side_turn_participant_ids": _side_turn_participant_ids.duplicate(),
				"side_turn_index": _side_turn_index,
			}
			var pending_state: PendingMovementReactionState = (
				_movement_coordinator.build_pending_state(
					unit,
					planned_path,
					prefix_path,
					candidate,
					movement_action_id,
					PendingMovementReactionState.CONTINUATION_ENEMY_MOVEMENT,
					payload,
					step_cost_feet,
					step_diagonal_steps,
					step_cost_prepaid,
					_state_store.state.revision
				)
			)
			pending_state.movement_spent_feet = unit.action_budget.normal_capacity_spent_feet
			pending_state.diagonal_steps_spent = unit.diagonal_steps_used
			var previous_pending: PendingMovementReactionState = _pending_reaction_state()
			if (
				previous_pending != null
				and previous_pending.movement_action_id == movement_action_id
			):
				pending_state.suppressed_candidate_keys = (
					previous_pending.suppressed_candidate_keys.duplicate(true)
				)
			var pending_commit: OperationResult = (
				_reaction_service.commit_pending_movement_reaction(pending_state)
			)
			if not pending_commit.success:
				return pending_commit
			return OperationResult.pending(
				&"reaction_pending",
				pending_state,
				"Enemy movement paused for a player Reaction decision.",
				_state_store.state.revision
			)
	return _commit_enemy_path(unit, planned_path)


func _commit_enemy_step_cost(
		unit: TacticalUnitState,
		origin: Vector2i,
		destination: Vector2i
) -> OperationResult:
	if unit == null or unit.grid_position != origin:
		return OperationResult.fail(
			&"enemy_movement_step_stale",
			"The enemy is no longer on the tile that provoked the Reaction."
		)
	var navigation := TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	var step: MovementPathResult = MovementRules.calculate_path_cost(
		[origin, destination],
		navigation,
		unit.diagonal_steps_used
	)
	if not step.success:
		return OperationResult.fail(&"enemy_movement_step_invalid", step.failure_reason)
	if step.cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		return OperationResult.fail(
			&"enemy_move_capacity",
			"%s cannot afford the provoking step." % unit.display_name
		)
	var budget_before: Dictionary = _budget_snapshot(unit)
	var changes := TacticalChangeSet.new(
		&"enemy_movement_step_cost_committed",
		_state_store.state.revision,
		TacticalInvalidationContract.movement_cost(unit.unit_id)
	)
	changes.set_allow_while_pending(true)
	changes.set_commit_validation_policy(false, false)
	changes.require(
		Callable(self, "_validate_action_budget_state").bind(unit),
		"The prepaid enemy movement budget is invalid.",
		&"enemy_movement_step_budget_invalid"
	)
	changes.stage(
		Callable(self, "_spend_move_budget").bind(
			unit,
			step.cost_feet,
			step.diagonal_steps
		),
		Callable(self, "_restore_budget").bind(unit, budget_before),
		"The provoking movement cost could not be committed.",
		&"enemy_movement_step_cost_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	return OperationResult.committed(
		step,
		"Provoking enemy movement cost committed before entry.",
		_state_store.state.revision
	)


func _commit_enemy_entry_without_budget(
		unit: TacticalUnitState,
		origin: Vector2i,
		destination: Vector2i,
		prepaid_cost_feet: int = 0,
		prepaid_diagonal_steps: int = 0
) -> OperationResult:
	if unit == null or unit.grid_position != origin:
		return OperationResult.fail(
			&"enemy_movement_entry_stale",
			"The enemy is no longer at the authoritative interruption tile."
		)
	var dragged_before: Dictionary = _state_store.state.dragged_body_cell_snapshot(
		unit.unit_id
	)
	var changes := TacticalChangeSet.new(
		&"enemy_movement_step_entered",
		_state_store.state.revision,
		TacticalInvalidationContract.movement(unit.unit_id, unit.team_id)
	)
	changes.set_allow_while_pending(true)
	changes.stage(
		Callable(self, "_set_unit_position").bind(
			unit.unit_id,
			destination,
			origin
		),
		Callable(self, "_restore_unit_position").bind(
			unit.unit_id,
			origin,
			dragged_before
		),
		"The enemy could not enter the tile after the Reaction resolved.",
		&"enemy_movement_entry_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	var path := MovementPathResult.completed(
		[origin, destination],
		prepaid_cost_feet,
		prepaid_diagonal_steps
	)
	movement_committed.emit({
		"unit_id": unit.unit_id,
		"path": path.path.duplicate(),
		"dragged_body_cells_before": dragged_before.duplicate(true),
	})
	_request_post_move_perception_refresh(unit)
	_record_movement_event(unit, origin, destination, path, _budget_snapshot(unit))
	return OperationResult.committed(
		path,
		"Enemy entered the triggering tile after the leaving-tile Reaction.",
		_state_store.state.revision
	)


func _commit_enemy_path(
		unit: TacticalUnitState,
		path_tiles: Array[Vector2i]
) -> OperationResult:
	if path_tiles.is_empty():
		return OperationResult.fail(&"enemy_move_path_empty", "The enemy route is empty.")
	var navigation := TacticalNavigationSnapshot.new(
		_map_definition, _state_store.state, unit.unit_id
	)
	var path: MovementPathResult = MovementRules.calculate_path_cost(
		path_tiles, navigation, unit.diagonal_steps_used
	)
	if not path.success:
		return OperationResult.fail(&"enemy_move_invalid", path.failure_reason)
	if path.cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		return OperationResult.fail(
			&"enemy_move_capacity",
			"%s cannot afford its chosen route." % unit.display_name
		)
	if path.path.size() <= 1:
		return OperationResult.ok(path, "Enemy movement paused before entering the next tile.")
	var origin: Vector2i = unit.grid_position
	var destination: Vector2i = path.path.back()
	var budget_snapshot: Dictionary = _budget_snapshot(unit)
	var dragged_body_cells_before: Dictionary = _state_store.state.dragged_body_cell_snapshot(unit.unit_id)
	var dragged_body_destination: Vector2i = path.path[path.path.size() - 2]
	var changes := TacticalChangeSet.new(
		&"enemy_unit_moved",
		_state_store.state.revision,
		TacticalInvalidationContract.movement(unit.unit_id, unit.team_id)
	)
	changes.set_allow_while_pending(true)
	changes.stage(
		Callable(self, "_set_unit_position").bind(
			unit.unit_id, destination, dragged_body_destination
		),
		Callable(self, "_restore_unit_position").bind(
			unit.unit_id, origin, dragged_body_cells_before
		),
		"The enemy destination became invalid.",
		&"enemy_move_destination_failed"
	)
	changes.stage(
		Callable(self, "_spend_move_budget").bind(
			unit, path.cost_feet, path.diagonal_steps
		),
		Callable(self, "_restore_budget").bind(unit, budget_snapshot),
		"The enemy movement cost could not be paid.",
		&"enemy_move_cost_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	movement_committed.emit({
		"unit_id": unit.unit_id,
		"path": path.path.duplicate(),
		"dragged_body_cells_before": dragged_body_cells_before.duplicate(true),
	})
	_request_post_move_perception_refresh(unit)
	_record_movement_event(unit, origin, destination, path, budget_snapshot)
	return OperationResult.ok(path, "%s moved %d ft." % [unit.display_name, path.cost_feet])


func _request_post_move_perception_refresh(unit: TacticalUnitState) -> void:
	if (
		_detection_service == null
		or unit == null
		or unit.squad_id.is_empty()
	):
		return
	# The request is coalesced by squad and resolved at the presentation boundary.
	# The deterministic perception signature prevents duplicate observer-target
	# scans when another actor has not changed relevant state.
	_detection_service.request_current_perception_for_squad(unit.squad_id)


func _complete_post_move_context(
		unit: TacticalUnitState,
		post_move: Dictionary,
		side_based: bool = false,
		movement_action_id: StringName = &""
) -> OperationResult:
	var kind: StringName = StringName(post_move.get("kind", &"combat"))
	if kind in [EnemyActionPlan.KIND_SEARCH, EnemyActionPlan.KIND_RETURN_TO_TASK]:
		var perception_result: OperationResult = _refresh_squad_perception(unit)
		if not perception_result.success:
			return perception_result
		return _finish_activation(
			unit, true,
			"%s completed its search movement." % unit.display_name
		)
	var acted: bool = true
	if bool(post_move.get("attack_after_move", false)):
		var target: TacticalUnitState = _state_store.state.get_unit(
			StringName(post_move.get("target_id", &""))
		)
		if target != null and not target.is_defeated():
			var preview: Variant = _preview_attack(
				unit, target, StringName(post_move.get("action_id", &""))
			)
			if _preview_succeeds(preview):
				var attack_result: OperationResult = _execute_attack_with_player_reaction(
					unit, preview, side_based, movement_action_id
				)
				if not attack_result.success or attack_result.code == &"reaction_pending":
					return attack_result
	return _finish_activation(
		unit, acted, "%s completed its combat activation." % unit.display_name
	)


func _begin_activation(
		unit: TacticalUnitState,
		behavior_label: String,
		refresh_budget: bool = true
) -> OperationResult:
	if not refresh_budget:
		unit.reactivate_without_refresh()
		_record_turn_started(unit, behavior_label)
		return OperationResult.ok(unit.unit_id, "%s began its activation." % unit.display_name)
	var budget_snapshot: Dictionary = _budget_snapshot(unit)
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"enemy_unit_started",
		_state_store.state.revision,
		TacticalInvalidationContract.action_budget([unit.unit_id])
	)
	changes.set_commit_validation_policy(false, false)
	changes.require(
		Callable(self, "_validate_action_budget_state").bind(unit),
		"The refreshed enemy action budget is invalid.",
		&"enemy_activation_budget_invalid"
	)
	changes.stage(
		Callable(self, "_refresh_activation").bind(unit),
		Callable(self, "_restore_budget").bind(unit, budget_snapshot),
		"%s could not begin its Enemy Turn activation." % unit.display_name,
		&"enemy_activation_start_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	_record_turn_started(unit, behavior_label)
	return OperationResult.ok(unit.unit_id, "%s began its activation." % unit.display_name)


func _recover_activation_failure(
		unit_id: StringName,
		failure: OperationResult
) -> OperationResult:
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return failure

	_record_ai_failure(unit, failure)
	var summary: String = (
		"%s encountered an AI execution error and safely ends its activation: %s"
		% [unit.display_name, failure.message]
	)
	var finalized: OperationResult = _finish_activation(unit, false, summary)
	if finalized.success:
		return OperationResult.ok(unit.unit_id, summary)
	return OperationResult.fail(
		&"enemy_activation_recovery_failed",
		"%s The activation also could not be finalized: %s"
		% [failure.message, finalized.message]
	)


func _execute_auto_pass(unit: TacticalUnitState) -> OperationResult:
	var started: OperationResult = _begin_activation(unit, "Automatic Pass")
	if not started.success:
		return started
	return _finish_activation(
		unit,
		false,
		"%s has no legal actions and passes." % unit.display_name
	)


func _execute_incapacitated_skip(unit: TacticalUnitState) -> OperationResult:
	return _finish_activation(
		unit,
		false,
		"%s is incapacitated and skips its activation." % unit.display_name,
		true
	)


func _execute_defeated_skip(unit: TacticalUnitState) -> OperationResult:
	var started: OperationResult = _begin_activation(unit, "Defeated — Skip")
	if not started.success:
		return started
	return _finish_activation(
		unit,
		false,
		"%s is Defeated and skips its activation." % unit.display_name,
		true
	)


func _finish_activation(
		unit: TacticalUnitState,
		acted: bool,
		summary: String,
		defeated_skip: bool = false
) -> OperationResult:
	var finish_started_usec: int = Time.get_ticks_usec()
	if not unit.action_budget.ended_activation:
		var ended_before: bool = unit.action_budget.ended_activation
		var changes: TacticalChangeSet = TacticalChangeSet.new(
			&"enemy_unit_ended",
			_state_store.state.revision,
			TacticalInvalidationContract.action_budget([unit.unit_id])
		)
		changes.set_allow_while_pending(true)
		changes.set_commit_validation_policy(false, false)
		changes.require(
			Callable(self, "_validate_action_budget_state").bind(unit),
			"The ended enemy action budget is invalid.",
			&"enemy_activation_end_budget_invalid"
		)
		changes.stage(
			Callable(self, "_set_activation_ended").bind(unit, true),
			Callable(self, "_set_activation_ended_rollback").bind(
				unit,
				ended_before
			),
			"%s could not end its activation." % unit.display_name,
			&"enemy_activation_end_failed"
		)
		var committed: OperationResult = _state_store.commit(
			changes,
			_map_definition
		)
		if not committed.success:
			return committed

	_record_turn_finished(unit, acted, summary, defeated_skip)
	_add_activation_stage_time(&"finish_activation", finish_started_usec)
	return OperationResult.ok(unit.unit_id, summary)


func _refresh_activation(unit: TacticalUnitState) -> bool:
	unit.refresh_for_new_round()
	return true


func _set_activation_ended(
		unit: TacticalUnitState,
		ended: bool
) -> bool:
	if ended:
		unit.mark_activation_ended()
	else:
		unit.action_budget.ended_activation = false
	return true


func _set_activation_ended_rollback(
		unit: TacticalUnitState,
		ended: bool
) -> void:
	unit.action_budget.ended_activation = ended


func _set_unit_position(
		unit_id: StringName,
		destination: Vector2i,
		dragged_body_destination: Vector2i
) -> bool:
	var moved: bool = _state_store.state.set_unit_position(
		unit_id,
		destination,
		_map_definition,
		false
	)
	if moved and dragged_body_destination.x >= 0:
		_state_store.state.move_dragged_bodies_to_cell(
			unit_id,
			dragged_body_destination
		)
	return moved


func _restore_unit_position(
		unit_id: StringName,
		destination: Vector2i,
		dragged_body_cells_before: Dictionary
) -> void:
	_state_store.state.set_unit_position(
		unit_id,
		destination,
		_map_definition,
		false
	)
	_state_store.state.restore_dragged_body_cells(
		dragged_body_cells_before
	)


func _spend_move_budget(
		unit: TacticalUnitState,
		cost_feet: int,
		diagonal_steps: int
) -> bool:
	if cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		return false
	unit.action_budget.spend_normal_capacity(cost_feet)
	unit.diagonal_steps_used += diagonal_steps
	return true


func _validate_action_budget_state(unit: TacticalUnitState) -> String:
	if unit == null or unit.action_budget == null:
		return "The enemy action budget is unavailable."
	var budget: ActionBudgetState = unit.action_budget
	if budget.maximum_turn_capacity_feet < 0:
		return "Maximum turn capacity cannot be negative."
	if (
		budget.remaining_turn_capacity_feet < 0
		or budget.remaining_turn_capacity_feet
		> budget.maximum_turn_capacity_feet
	):
		return "Remaining turn capacity is outside its legal bounds."
	if (
		budget.normal_capacity_spent_feet < 0
		or budget.normal_capacity_spent_feet
		> budget.maximum_turn_capacity_feet
	):
		return "Spent turn capacity is outside its legal bounds."
	if (
		budget.remaining_turn_capacity_feet
		+ budget.normal_capacity_spent_feet
		!= budget.maximum_turn_capacity_feet
	):
		return "Remaining and spent turn capacity do not reconcile."
	return ""


func _budget_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"reaction": unit.action_budget.reaction_snapshot(),
		"ordinary_attack": unit.action_budget.ordinary_attack_available,
		"ended": unit.action_budget.ended_activation,
		"diagonal": unit.diagonal_steps_used,
	}


func _restore_budget(
		unit: TacticalUnitState,
		snapshot: Dictionary
) -> void:
	unit.action_budget.remaining_turn_capacity_feet = int(snapshot["remaining"])
	unit.action_budget.normal_capacity_spent_feet = int(snapshot["spent"])
	unit.action_budget.quick_action_available = bool(snapshot["quick"])
	unit.action_budget.restore_reaction_snapshot(snapshot.get("reaction", {}))
	unit.action_budget.ordinary_attack_available = bool(
		snapshot["ordinary_attack"]
	)
	unit.action_budget.ended_activation = bool(snapshot["ended"])
	unit.diagonal_steps_used = int(snapshot["diagonal"])


func _record_turn_started(
		unit: TacticalUnitState,
		behavior_label: String
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"unit_turn_started",
		phase.round_number,
		phase.current_phase,
		"%s begins its Enemy Turn activation." % unit.display_name,
		{
			"category": &"events",
			"visibility": _event_visibility_for_unit(unit),
			"source_actor_id": unit.unit_id,
			"details": [
				"Team: Enemy",
				"Controller: AI",
				"Turn behaviour: %s" % behavior_label,
			],
		}
	)


func _record_turn_finished(
		unit: TacticalUnitState,
		acted: bool,
		summary: String,
		defeated_skip: bool
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	var event_type: StringName = &"unit_turn_ended" if acted else &"unit_passed"
	var details: Array[String] = [
		"Remaining capacity: %d ft"
		% unit.action_budget.remaining_turn_capacity_feet,
		"Normal attack: %s"
		% (
			"Ready"
			if unit.action_budget.ordinary_attack_available
			else "Spent"
		),
	]
	if defeated_skip:
		details.append("Combat state: Defeated")
	elif not acted:
		details.append("No movement or attack was taken.")
	_event_journal.call(
		"record_event",
		event_type,
		phase.round_number,
		phase.current_phase,
		summary,
		{
			"category": &"events",
			"visibility": _event_visibility_for_unit(unit),
			"source_actor_id": unit.unit_id,
			"details": details,
		}
	)


func _record_ai_failure(
		unit: TacticalUnitState,
		failure: OperationResult
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"enemy_ai_failure",
		phase.round_number,
		phase.current_phase,
		"%s encountered an AI execution error and will pass." % unit.display_name,
		{
			"category": &"events",
			"visibility": _event_visibility_for_unit(unit),
			"source_actor_id": unit.unit_id,
			"details": [
				"Failure code: %s" % str(failure.code),
				failure.message,
				"The Enemy Turn will continue with the next participant.",
			],
		}
	)


func _record_movement_event(
		unit: TacticalUnitState,
		origin: Vector2i,
		destination: Vector2i,
		path: MovementPathResult,
		budget_snapshot: Dictionary
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"movement",
		phase.round_number,
		phase.current_phase,
		"%s moved %d ft." % [unit.display_name, path.cost_feet],
		{
			"category": &"events",
			"visibility": _event_visibility_for_unit(unit),
			"source_actor_id": unit.unit_id,
			"action_id": &"action.move",
			"details": [
				"From: (%d, %d)" % [origin.x, origin.y],
				"To: (%d, %d)" % [destination.x, destination.y],
				"Distance: %d ft" % path.cost_feet,
				"Capacity: %d → %d ft" % [
					int(budget_snapshot.get("remaining", 0)),
					unit.action_budget.remaining_turn_capacity_feet,
				],
			],
			"resource_changes": [
				{
					"resource": &"normal_capacity",
					"before": int(budget_snapshot.get("remaining", 0)),
					"after": unit.action_budget.remaining_turn_capacity_feet,
				},
			],
		}
	)


func _event_visibility_for_unit(unit: TacticalUnitState) -> StringName:
	if unit == null:
		return &"hidden"
	if unit.is_player_controlled():
		return &"player"
	if (
		_visibility_service != null
		and _visibility_service.has_method("is_unit_visible_to_team")
		and bool(_visibility_service.call(
			"is_unit_visible_to_team",
			&"player",
			unit
		))
	):
		return &"player"
	return &"hidden"
