class_name SprintMoveHandler
extends RefCounted

const MOVEMENT_COORDINATOR_SCRIPT: Script = preload(
	"res://application/tactical/movement/tactical_movement_resolution_coordinator.gd"
)

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _event_journal: RefCounted
var _detection_service: TacticalDetectionService
var _dice_roller: TacticalDiceRoller
var _reaction_service: TacticalReactionService
var _movement_coordinator: TacticalMovementResolutionCoordinator


func _init(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		event_journal_value: RefCounted = null
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_event_journal = event_journal_value


func configure_detection(
		detection_service: TacticalDetectionService,
		dice_roller: TacticalDiceRoller
) -> void:
	_detection_service = detection_service
	_dice_roller = dice_roller


func configure_reactions(reaction_service: TacticalReactionService) -> void:
	_reaction_service = reaction_service
	_movement_coordinator = (
		MOVEMENT_COORDINATOR_SCRIPT.new()
		as TacticalMovementResolutionCoordinator
	)
	_movement_coordinator.configure(reaction_service)


func preview(unit: TacticalUnitState, destination: Vector2i) -> MovementPathResult:
	if unit == null:
		return MovementPathResult.failed("No unit is selected.")
	if unit.is_unconscious() or unit.is_dead():
		return MovementPathResult.failed("Unconscious or dead units cannot Sprint.")
	if unit.is_disabled():
		return MovementPathResult.failed("Disabled characters cannot take Full Actions or Sprint.")
	if unit.is_fatigued():
		return MovementPathResult.failed("Sprint unavailable: Fatigued.")
	if unit.load_category in [TacticalUnitState.LOAD_HEAVY, TacticalUnitState.LOAD_OVER_CAPACITY]:
		return MovementPathResult.failed("Sprint unavailable: %s load." % String(unit.load_category).replace("_", " ").capitalize())
	if unit.action_budget.ended_activation:
		return MovementPathResult.failed("This unit is marked as ended.")
	if unit.action_budget.has_spent_normal_capacity():
		return MovementPathResult.failed(
			"Sprint is a Full Action and requires an untouched normal-action budget."
		)

	var navigation := TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	var path_result: MovementPathResult = MovementRules.find_path(
		unit.grid_position,
		destination,
		navigation,
		unit.diagonal_steps_used
	)
	if not path_result.success:
		return path_result

	for index: int in range(1, path_result.path.size()):
		var previous: Vector2i = path_result.path[index - 1]
		var tile: Vector2i = path_result.path[index]
		if _map_definition.is_difficult(tile):
			return MovementPathResult.failed(
				"The prototype Sprint cannot cross difficult terrain."
			)
		if not navigation.auto_opening_id(previous, tile).is_empty():
			return MovementPathResult.failed(
				"Sprint cannot include opening a closed door."
			)

	var sprint_allowance: int = unit.sprint_distance_feet
	if sprint_allowance <= 0:
		sprint_allowance = int(floor(unit.action_budget.maximum_turn_capacity_feet * 1.5 / 5.0)) * 5
	if path_result.cost_feet > sprint_allowance:
		return MovementPathResult.failed(
			"Sprint route costs %d ft; the unit's Sprint limit is %d ft."
			% [path_result.cost_feet, sprint_allowance]
		)
	return path_result


func execute(command: SprintMoveCommand) -> OperationResult:
	if _state_store.state.pending_movement_reaction != null:
		return OperationResult.fail(
			&"pending_tactical_decision",
			"Resolve the interrupted movement Reaction before beginning a Sprint."
		)
	var unit: TacticalUnitState = _state_store.state.get_unit(command.unit_id)
	if unit == null:
		return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")
	if not _state_store.state.can_unit_act(command.unit_id):
		return OperationResult.fail(
			&"wrong_active_unit",
			"This unit is not currently allowed to Sprint."
		)
	var occupying_unit: TacticalUnitState = _state_store.state.get_unit_at_tile(
		command.destination,
		command.unit_id
	)
	if occupying_unit != null:
		return OperationResult.fail(
			&"destination_occupied",
			"%s already occupies that destination." % occupying_unit.display_name
		)
	var planned: MovementPathResult = preview(unit, command.destination)
	if not planned.success:
		return OperationResult.fail(&"invalid_sprint", planned.failure_reason)

	# Cancelling a reservation is itself an authoritative event. Do it only after
	# every static Sprint requirement has passed.
	if _reaction_service != null:
		var cancelled: OperationResult = (
			_reaction_service.cancel_reservation_for_voluntary_move(unit.unit_id)
		)
		if not cancelled.success:
			return cancelled

	var origin: Vector2i = unit.grid_position
	var capacity_before: int = unit.action_budget.remaining_turn_capacity_feet
	var reaction_before: Dictionary = unit.action_budget.reaction_snapshot()
	var sprint_start: OperationResult = _commit_sprint_cost(unit)
	if not sprint_start.success:
		return sprint_start

	var movement_action_id: StringName = (
		_reaction_service.begin_movement_action_id(unit.unit_id)
		if _reaction_service != null
		else StringName("sprint.%s.r%d" % [unit.unit_id, _state_store.state.revision])
	)
	var aggregate := MovementPathResult.completed([origin], 0, 0)
	var remaining_path: Array[Vector2i] = planned.path.duplicate()
	var reaction_interrupted: bool = false
	var detection_interrupted: bool = false
	var warning_codes: Array[StringName] = []

	while remaining_path.size() > 1:
		var boundary: Dictionary = (
			_movement_coordinator.first_reaction_boundary(
				unit.unit_id,
				remaining_path,
				&"sprint",
				movement_action_id,
				TacticalMovementResolutionCoordinator.CONTROLLER_AI
			)
			if _movement_coordinator != null
			else {"candidate": null}
		)
		var first_candidate: ReactionCandidate = (
			boundary.get("candidate") as ReactionCandidate
		)
		if first_candidate == null:
			var final_segment: OperationResult = _commit_sprint_segment(
				unit,
				remaining_path,
				true
			)
			if not final_segment.success:
				warning_codes.append(final_segment.code)
				break
			var final_path: MovementPathResult = final_segment.data as MovementPathResult
			_append_movement_result(aggregate, final_path)
			detection_interrupted = (
				final_segment.message == "sprint_interrupted_by_detection"
			)
			break

		var step_index: int = first_candidate.path_index
		var safe_prefix: Array[Vector2i] = _movement_coordinator.prefix_before_step(
			remaining_path,
			step_index
		)
		if safe_prefix.size() > 1:
			var safe_segment: OperationResult = _commit_sprint_segment(
				unit,
				safe_prefix,
				true
			)
			if not safe_segment.success:
				warning_codes.append(safe_segment.code)
				break
			var safe_path: MovementPathResult = safe_segment.data as MovementPathResult
			_append_movement_result(aggregate, safe_path)
			if safe_path.path.back() != safe_prefix.back():
				detection_interrupted = true
				break

		var step_origin: Vector2i = remaining_path[step_index - 1]
		var step_destination: Vector2i = remaining_path[step_index]
		var step_candidates: Array[ReactionCandidate] = (
			_movement_coordinator.candidates_for_step(
				unit.unit_id,
				step_origin,
				step_destination,
				step_index,
				&"sprint",
				movement_action_id
			)
			if _movement_coordinator != null
			else []
		)
		var ai_before: Array[ReactionCandidate] = []
		var ai_after: Array[ReactionCandidate] = []
		for candidate: ReactionCandidate in step_candidates:
			var reactor: TacticalUnitState = _state_store.state.get_unit(
				candidate.source_unit_id
			)
			if reactor == null or not reactor.is_ai_controlled():
				continue
			if candidate.timing_kind == ReactionCandidate.TIMING_BEFORE_ENTRY:
				ai_before.append(candidate)
			else:
				ai_after.append(candidate)

		for candidate: ReactionCandidate in ai_before:
			var attack_result: OperationResult = _reaction_service.execute_candidate(candidate)
			_append_reaction_event(aggregate, candidate, attack_result)
			if attack_result.success and not unit.can_take_actions():
				reaction_interrupted = true
				break
		if reaction_interrupted:
			break

		var entry_result: OperationResult = _commit_sprint_segment(
			unit,
			[step_origin, step_destination],
			false
		)
		if not entry_result.success:
			warning_codes.append(entry_result.code)
			break
		_append_movement_result(aggregate, entry_result.data as MovementPathResult)

		for candidate: ReactionCandidate in ai_after:
			var attack_result: OperationResult = _reaction_service.execute_candidate(candidate)
			_append_reaction_event(aggregate, candidate, attack_result)
			if attack_result.success and not unit.can_take_actions():
				reaction_interrupted = true
				break
		if reaction_interrupted:
			break

		var detection_result: OperationResult = _commit_sprint_detection_for_step(
			unit,
			step_origin,
			step_destination
		)
		if not detection_result.success:
			warning_codes.append(detection_result.code)
			break
		if bool(detection_result.data):
			detection_interrupted = true
			break

		remaining_path = _movement_coordinator.continuation_from_entered_step(
			remaining_path,
			step_index
		)

	aggregate.success = true
	var actual_destination: Vector2i = aggregate.path.back()
	var sprint_summary: String
	if reaction_interrupted:
		sprint_summary = "%s sprinted %d ft before a Reaction stopped movement." % [
			unit.display_name,
			aggregate.cost_feet,
		]
	elif detection_interrupted:
		sprint_summary = "%s sprinted %d ft before detection interrupted movement." % [
			unit.display_name,
			aggregate.cost_feet,
		]
	else:
		sprint_summary = "%s sprinted %d ft." % [unit.display_name, aggregate.cost_feet]

	_record_event(
		&"sprint",
		sprint_summary,
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"action_id": &"action.sprint",
			"details": [
				"From: (%d, %d)" % [origin.x, origin.y],
				"To: (%d, %d)" % [actual_destination.x, actual_destination.y],
				"Planned destination: (%d, %d)" % [
					command.destination.x,
					command.destination.y,
				],
				"Distance: %d ft" % aggregate.cost_feet,
				"Cost: Full Action",
				"Capacity: %d → %d ft" % [
					capacity_before,
					unit.action_budget.remaining_turn_capacity_feet,
				],
				"Reaction: %s → Spent" % ReactionResourceState.display_label(
					StringName(reaction_before.get(
						"state",
						ReactionResourceState.AVAILABLE
					))
				),
			],
			"resource_changes": [
				{
					"resource": &"normal_capacity",
					"before": capacity_before,
					"after": unit.action_budget.remaining_turn_capacity_feet,
				},
				{
					"resource": &"reaction",
					"before": reaction_before.get(
						"state",
						ReactionResourceState.AVAILABLE
					),
					"after": unit.action_budget.reaction_state,
				},
			],
		}
	)
	if _detection_service != null and not unit.squad_id.is_empty():
		_detection_service.request_current_perception_for_squad(unit.squad_id)
	var result_message: String = sprint_summary + " Full Action and Reaction remain spent."
	if not warning_codes.is_empty():
		return OperationResult.committed_with_warning(
			aggregate,
			result_message,
			_state_store.state.revision,
			warning_codes
		)
	return OperationResult.committed(
		aggregate,
		result_message,
		_state_store.state.revision
	)


func _commit_sprint_cost(unit: TacticalUnitState) -> OperationResult:
	var budget_before: Dictionary = {
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"reaction": unit.action_budget.reaction_snapshot(),
	}
	var changes := TacticalChangeSet.new(
		&"sprint_started",
		_state_store.state.revision,
		TacticalInvalidationContract.action_budget([unit.unit_id])
	)
	changes.stage(
		Callable(self, "_apply_sprint_cost").bind(unit),
		Callable(self, "_restore_sprint_cost").bind(unit, budget_before),
		"Sprint cost could not be committed.",
		&"sprint_cost_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	return OperationResult.committed(
		unit.unit_id,
		"Sprint Full Action and Reaction committed.",
		_state_store.state.revision
	)


func _commit_sprint_segment(
		unit: TacticalUnitState,
		requested_path: Array[Vector2i],
		apply_detection: bool
) -> OperationResult:
	if unit == null or requested_path.is_empty() or requested_path[0] != unit.grid_position:
		return OperationResult.fail(
			&"sprint_segment_stale",
			"The Sprint segment no longer begins at the mover's authoritative position."
		)
	var navigation := TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	var segment: MovementPathResult = MovementRules.calculate_path_cost(
		requested_path,
		navigation,
		unit.diagonal_steps_used
	)
	if not segment.success:
		return OperationResult.fail(&"sprint_segment_invalid", segment.failure_reason)
	var dice_checkpoint: Dictionary = (
		_dice_roller.snapshot_state() if _dice_roller != null else {}
	)
	var detection_resolution: TacticalDetectionResolution = null
	var detection_snapshot: Dictionary = {}
	if apply_detection and _detection_service != null and requested_path.size() > 1:
		detection_resolution = _detection_service.prepare_path_resolution(
			unit.unit_id,
			requested_path
		)
		detection_snapshot = _detection_service.snapshot_for_resolution(
			detection_resolution
		)
		if detection_resolution.movement_interrupted():
			var committed_path: Array[Vector2i] = detection_resolution.committed_path(
				requested_path
			)
			segment = MovementRules.calculate_path_cost(
				committed_path,
				navigation,
				unit.diagonal_steps_used
			)
	if not segment.success:
		if _dice_roller != null:
			_dice_roller.restore_state(dice_checkpoint)
		return OperationResult.fail(&"sprint_segment_invalid", segment.failure_reason)

	var origin: Vector2i = unit.grid_position
	var facing_before: Vector2i = unit.facing_direction
	var diagonal_before: int = unit.diagonal_steps_used
	var dragged_before: Dictionary = _state_store.state.dragged_body_cell_snapshot(
		unit.unit_id
	)
	var destination: Vector2i = segment.path.back()
	var facing_after: Vector2i = facing_before
	var dragged_destination := Vector2i(-1, -1)
	if segment.path.size() > 1:
		facing_after = TacticalPerceptionRules.normalized_facing(
			segment.path.back() - segment.path[segment.path.size() - 2]
		)
		dragged_destination = segment.path[segment.path.size() - 2]
	var changes := TacticalChangeSet.new(
		&"unit_sprint_segment_moved",
		_state_store.state.revision,
		TacticalInvalidationContract.movement(unit.unit_id, unit.team_id)
	)
	if segment.path.size() > 1:
		changes.stage(
			Callable(self, "_set_unit_position_and_facing").bind(
				unit.unit_id,
				destination,
				facing_after,
				dragged_destination
			),
			Callable(self, "_restore_unit_position_and_facing").bind(
				unit.unit_id,
				origin,
				facing_before,
				dragged_before
			),
			"The Sprint destination became invalid.",
			&"sprint_destination_failed"
		)
	changes.stage(
		Callable(self, "_set_diagonal_steps").bind(
			unit,
			diagonal_before + segment.diagonal_steps
		),
		Callable(self, "_set_diagonal_steps").bind(unit, diagonal_before),
		"Sprint diagonal movement state could not be committed.",
		&"sprint_diagonal_commit_failed"
	)
	if detection_resolution != null:
		changes.stage(
			Callable(_detection_service, "apply_resolution").bind(detection_resolution),
			Callable(_detection_service, "restore_resolution_snapshot").bind(
				detection_snapshot
			),
			"Detection and alert state could not be committed.",
			&"detection_commit_failed"
		)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		if _dice_roller != null:
			_dice_roller.restore_state(dice_checkpoint)
		return committed
	if _detection_service != null and detection_resolution != null:
		_detection_service.record_resolution(detection_resolution)
	return OperationResult.committed(
		segment,
		(
			"sprint_interrupted_by_detection"
			if detection_resolution != null and detection_resolution.movement_interrupted()
			else "sprint_segment_committed"
		),
		_state_store.state.revision
	)


func _commit_sprint_detection_for_step(
		unit: TacticalUnitState,
		origin: Vector2i,
		destination: Vector2i
) -> OperationResult:
	if _detection_service == null or unit == null:
		return OperationResult.no_change(false, "No Sprint detection was required.")
	var dice_checkpoint: Dictionary = (
		_dice_roller.snapshot_state() if _dice_roller != null else {}
	)
	var resolution: TacticalDetectionResolution = _detection_service.prepare_path_resolution(
		unit.unit_id,
		[origin, destination]
	)
	var snapshot: Dictionary = _detection_service.snapshot_for_resolution(resolution)
	var changes := TacticalChangeSet.new(
		&"current_perception_resolved",
		_state_store.state.revision,
		TacticalInvalidationContract.token_status()
	)
	changes.set_commit_validation_policy(false, false)
	changes.stage(
		Callable(_detection_service, "apply_resolution").bind(resolution),
		Callable(_detection_service, "restore_resolution_snapshot").bind(snapshot),
		"Detection after entering the Sprint Reaction tile could not be committed.",
		&"detection_commit_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		if _dice_roller != null:
			_dice_roller.restore_state(dice_checkpoint)
		return committed
	_detection_service.record_resolution(resolution)
	return OperationResult.committed(
		resolution.movement_interrupted(),
		"Sprint detection resolved after entering the triggering tile.",
		_state_store.state.revision
	)


func _apply_sprint_cost(unit: TacticalUnitState) -> bool:
	if unit == null or unit.action_budget.has_spent_normal_capacity():
		return false
	unit.action_budget.spend_normal_capacity(
		unit.action_budget.maximum_turn_capacity_feet
	)
	if unit.action_budget.reaction_state != ReactionResourceState.SPENT:
		unit.action_budget.spend_reaction()
	return true


func _restore_sprint_cost(unit: TacticalUnitState, snapshot: Dictionary) -> void:
	if unit == null:
		return
	unit.action_budget.remaining_turn_capacity_feet = int(snapshot.get(
		"remaining",
		unit.action_budget.remaining_turn_capacity_feet
	))
	unit.action_budget.normal_capacity_spent_feet = int(snapshot.get(
		"spent",
		unit.action_budget.normal_capacity_spent_feet
	))
	unit.action_budget.restore_reaction_snapshot(snapshot.get("reaction", {}) as Dictionary)


func _set_diagonal_steps(unit: TacticalUnitState, value: int) -> bool:
	if unit == null:
		return false
	unit.diagonal_steps_used = value
	return true


func _set_unit_position_and_facing(
		unit_id: StringName,
		destination: Vector2i,
		facing: Vector2i,
		dragged_body_destination: Vector2i
) -> bool:
	var moved: bool = _state_store.state.set_unit_position(
		unit_id,
		destination,
		_map_definition,
		false
	)
	if not moved:
		return false
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit != null:
		unit.set_facing(facing)
		if dragged_body_destination.x >= 0:
			_state_store.state.move_dragged_bodies_to_cell(
				unit_id,
				dragged_body_destination
			)
	return unit != null


func _restore_unit_position_and_facing(
		unit_id: StringName,
		destination: Vector2i,
		facing: Vector2i,
		dragged_body_cells_before: Dictionary
) -> void:
	_state_store.state.set_unit_position(
		unit_id,
		destination,
		_map_definition,
		false
	)
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit != null:
		unit.facing_direction = facing
	_state_store.state.restore_dragged_body_cells(dragged_body_cells_before)


func _append_movement_result(
		aggregate: MovementPathResult,
		segment: MovementPathResult
) -> void:
	if aggregate == null or segment == null:
		return
	for tile: Vector2i in segment.path:
		if aggregate.path.is_empty() or aggregate.path.back() != tile:
			aggregate.path.append(tile)
	aggregate.cost_feet += segment.cost_feet
	aggregate.diagonal_steps += segment.diagonal_steps
	for event: Dictionary in segment.reaction_events:
		aggregate.reaction_events.append(event.duplicate(true))


func _append_reaction_event(
		aggregate: MovementPathResult,
		candidate: ReactionCandidate,
		attack_result: OperationResult
) -> void:
	if aggregate == null or candidate == null:
		return
	aggregate.reaction_events.append({
		"candidate": candidate,
		"result": attack_result,
		"path_index": aggregate.path.size() - 1,
		"timing_kind": candidate.timing_kind,
		"reaction_kind": candidate.reaction_kind,
		"source_unit_id": candidate.source_unit_id,
		"target_unit_id": candidate.target_unit_id,
		"hit_chance_percent": candidate.predicted_hit_chance,
	})


func _record_event(
		event_type: StringName,
		summary: String,
		options: Dictionary
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		event_type,
		phase.round_number,
		phase.current_phase,
		summary,
		options
	)
