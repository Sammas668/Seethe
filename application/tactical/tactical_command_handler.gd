class_name TacticalCommandHandler
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


func execute_move(command: MoveCommand) -> OperationResult:
	if _state_store.state.pending_movement_reaction != null:
		return OperationResult.fail(
			&"pending_tactical_decision",
			"Resolve the interrupted movement Reaction before moving another unit."
		)
	var unit: TacticalUnitState = _state_store.state.get_unit(command.unit_id)
	if unit == null:
		return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")
	if not _state_store.state.can_unit_act(command.unit_id):
		return OperationResult.fail(
			&"wrong_active_unit",
			"This unit is not currently allowed to move."
		)
	if unit.is_unconscious() or unit.is_dead():
		return OperationResult.fail(
			&"unit_downed",
			"Unconscious or dead units cannot move."
		)
	if unit.action_budget.ended_activation:
		return OperationResult.fail(
			&"unit_ended",
			"This unit is marked as ended. Reactivate it before moving."
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

	var navigation := TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	var path_result: MovementPathResult = MovementRules.find_path(
		unit.grid_position,
		command.destination,
		navigation,
		unit.diagonal_steps_used
	)
	if not path_result.success:
		return OperationResult.fail(&"invalid_path", path_result.failure_reason)
	if path_result.cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		return OperationResult.fail(
			&"insufficient_capacity",
			"The route costs %d ft, but the unit has only %d ft remaining."
			% [
				path_result.cost_feet,
				unit.action_budget.remaining_turn_capacity_feet,
			]
		)

	var opening_plan: Dictionary = _opening_plan_for_path(unit, path_result, navigation)
	var planned_opening_ids: Array[StringName] = []
	for opening_value: Variant in opening_plan.get("opening_ids", []):
		planned_opening_ids.append(StringName(opening_value))
	var paused_for_new_information: bool = bool(
		opening_plan.get("paused_for_new_information", false)
	)
	if paused_for_new_information:
		path_result = opening_plan.get("committed_path_result") as MovementPathResult
		if path_result == null or not path_result.success:
			return OperationResult.fail(
				&"door_pause_path_invalid",
				"The route could not stop safely beside the opening."
			)

	# Only cancel a reservation after the move itself has passed static validation.
	if _reaction_service != null:
		var cancelled: OperationResult = (
			_reaction_service.cancel_reservation_for_voluntary_move(unit.unit_id)
		)
		if not cancelled.success:
			return cancelled

	var origin: Vector2i = unit.grid_position
	var capacity_before: int = unit.action_budget.remaining_turn_capacity_feet
	var movement_action_id: StringName = (
		_reaction_service.begin_movement_action_id(unit.unit_id)
		if _reaction_service != null
		else StringName("movement.%s.r%d" % [unit.unit_id, _state_store.state.revision])
	)
	var aggregate := MovementPathResult.completed([origin], 0, 0)
	var remaining_path: Array[Vector2i] = path_result.path.duplicate()
	var base_cost_result: MovementPathResult = MovementRules.calculate_path_cost(
		path_result.path,
		navigation,
		unit.diagonal_steps_used
	)
	var final_extra_cost: int = maxi(
		0,
		path_result.cost_feet - base_cost_result.cost_feet
	) if base_cost_result.success else 0
	var reaction_interrupted: bool = false
	var detection_interrupted: bool = false
	var warning_codes: Array[StringName] = []
	var openings_committed: bool = false

	while remaining_path.size() > 1:
		var boundary: Dictionary = (
			_movement_coordinator.first_reaction_boundary(
				unit.unit_id,
				remaining_path,
				&"normal",
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
			var final_segment: OperationResult = _commit_player_movement_segment(
				unit,
				remaining_path,
				final_extra_cost,
				planned_opening_ids,
				true
			)
			if not final_segment.success:
				if aggregate.cost_feet <= 0:
					return final_segment
				warning_codes.append(final_segment.code)
				break
			var final_path: MovementPathResult = final_segment.data as MovementPathResult
			_append_movement_result(aggregate, final_path)
			openings_committed = not planned_opening_ids.is_empty()
			detection_interrupted = bool(
				final_segment.message == "movement_interrupted_by_detection"
			)
			break

		var step_index: int = first_candidate.path_index
		var safe_prefix: Array[Vector2i] = (
			_movement_coordinator.prefix_before_step(remaining_path, step_index)
			if _movement_coordinator != null
			else [remaining_path[0]]
		)
		if safe_prefix.size() > 1:
			var safe_segment: OperationResult = _commit_player_movement_segment(
				unit,
				safe_prefix,
				0,
				[],
				true
			)
			if not safe_segment.success:
				if aggregate.cost_feet <= 0:
					return safe_segment
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
				&"normal",
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

		var step_prepaid: bool = false
		if not ai_before.is_empty():
			var cost_commit: OperationResult = _commit_player_step_cost(
				unit,
				step_origin,
				step_destination
			)
			if not cost_commit.success:
				if aggregate.cost_feet <= 0:
					return cost_commit
				warning_codes.append(cost_commit.code)
				break
			var cost_result: MovementPathResult = cost_commit.data as MovementPathResult
			aggregate.cost_feet += cost_result.cost_feet
			aggregate.diagonal_steps += cost_result.diagonal_steps
			step_prepaid = true
			for candidate: ReactionCandidate in ai_before:
				var attack_result: OperationResult = _reaction_service.execute_candidate(candidate)
				_append_reaction_event(aggregate, candidate, attack_result)
				if attack_result.success and not unit.can_take_actions():
					reaction_interrupted = true
					break
			if reaction_interrupted:
				break

		var entry_result: OperationResult
		if step_prepaid:
			entry_result = _commit_player_entry_without_budget(
				unit,
				step_origin,
				step_destination
			)
		else:
			entry_result = _commit_player_movement_segment(
				unit,
				[step_origin, step_destination],
				0,
				[],
				false
			)
		if not entry_result.success:
			warning_codes.append(entry_result.code)
			break
		var entry_path: MovementPathResult = entry_result.data as MovementPathResult
		if step_prepaid:
			_append_path_unique(aggregate.path, entry_path.path)
		else:
			_append_movement_result(aggregate, entry_path)

		for candidate: ReactionCandidate in ai_after:
			var attack_result: OperationResult = _reaction_service.execute_candidate(candidate)
			_append_reaction_event(aggregate, candidate, attack_result)
			if attack_result.success and not unit.can_take_actions():
				reaction_interrupted = true
				break

		var detection_result: OperationResult = _commit_player_detection_for_step(
			unit,
			step_origin,
			step_destination
		)
		if not detection_result.success:
			warning_codes.append(detection_result.code)
			break
		if bool(detection_result.data):
			detection_interrupted = true
		if reaction_interrupted or detection_interrupted:
			break

		remaining_path = (
			_movement_coordinator.continuation_from_entered_step(
				remaining_path,
				step_index
			)
			if _movement_coordinator != null
			else [step_destination]
		)

	# A door interaction can legitimately have a one-tile committed path.
	if (
		remaining_path.size() <= 1
		and not planned_opening_ids.is_empty()
		and not openings_committed
		and not reaction_interrupted
		and not detection_interrupted
	):
		var door_commit: OperationResult = _commit_player_movement_segment(
			unit,
			[unit.grid_position],
			final_extra_cost,
			planned_opening_ids,
			false
		)
		if door_commit.success:
			_append_movement_result(aggregate, door_commit.data as MovementPathResult)
			openings_committed = true
		else:
			warning_codes.append(door_commit.code)

	aggregate.success = true
	var actual_destination: Vector2i = aggregate.path.back()
	var movement_summary: String
	if reaction_interrupted:
		movement_summary = "%s moved %d ft before a Reaction stopped movement." % [
			unit.display_name,
			aggregate.cost_feet,
		]
	elif detection_interrupted:
		movement_summary = "%s moved %d ft before detection interrupted movement." % [
			unit.display_name,
			aggregate.cost_feet,
		]
	elif paused_for_new_information and openings_committed:
		movement_summary = "%s opened a door and paused before crossing the opening." % unit.display_name
	else:
		movement_summary = "%s moved %d ft." % [unit.display_name, aggregate.cost_feet]

	_record_event(
		&"movement",
		movement_summary,
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"action_id": &"action.move",
			"details": [
				"From: (%d, %d)" % [origin.x, origin.y],
				"To: (%d, %d)" % [actual_destination.x, actual_destination.y],
				"Planned destination: (%d, %d)" % [
					command.destination.x,
					command.destination.y,
				],
				"Distance: %d ft" % aggregate.cost_feet,
				"Capacity: %d → %d ft" % [
					capacity_before,
					unit.action_budget.remaining_turn_capacity_feet,
				],
			],
			"resource_changes": [{
				"resource": &"normal_capacity",
				"before": capacity_before,
				"after": unit.action_budget.remaining_turn_capacity_feet,
			}],
		}
	)
	if _detection_service != null and not unit.squad_id.is_empty():
		_detection_service.request_current_perception_for_squad(unit.squad_id)
	if not warning_codes.is_empty():
		return OperationResult.committed_with_warning(
			aggregate,
			movement_summary,
			_state_store.state.revision,
			warning_codes
		)
	return OperationResult.committed(
		aggregate,
		movement_summary,
		_state_store.state.revision
	)


func _commit_player_movement_segment(
		unit: TacticalUnitState,
		requested_path: Array[Vector2i],
		extra_cost_feet: int,
		opening_ids: Array[StringName],
		apply_detection: bool
) -> OperationResult:
	if unit == null or requested_path.is_empty() or requested_path[0] != unit.grid_position:
		return OperationResult.fail(
			&"movement_segment_stale",
			"The movement segment no longer begins at the mover's authoritative position."
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
		return OperationResult.fail(&"movement_segment_invalid", segment.failure_reason)
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
			extra_cost_feet = 0
			opening_ids = []
	if not segment.success:
		if _dice_roller != null:
			_dice_roller.restore_state(dice_checkpoint)
		return OperationResult.fail(&"movement_segment_invalid", segment.failure_reason)
	segment.cost_feet += maxi(0, extra_cost_feet)
	if segment.cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		if _dice_roller != null:
			_dice_roller.restore_state(dice_checkpoint)
		return OperationResult.fail(
			&"insufficient_capacity",
			"The next movement segment costs %d ft, but only %d ft remain."
			% [segment.cost_feet, unit.action_budget.remaining_turn_capacity_feet]
		)

	var origin: Vector2i = unit.grid_position
	var facing_before: Vector2i = unit.facing_direction
	var capacity_before: int = unit.action_budget.remaining_turn_capacity_feet
	var spent_before: int = unit.action_budget.normal_capacity_spent_feet
	var diagonal_before: int = unit.diagonal_steps_used
	var dragged_before: Dictionary = _state_store.state.dragged_body_cell_snapshot(
		unit.unit_id
	)
	var opening_snapshots: Dictionary = {}
	for opening_id: StringName in opening_ids:
		opening_snapshots[opening_id] = _state_store.state.environment_state.snapshot_source(
			opening_id
		)
	var destination: Vector2i = segment.path.back()
	var facing_after: Vector2i = facing_before
	var dragged_destination := Vector2i(-1, -1)
	if segment.path.size() > 1:
		facing_after = TacticalPerceptionRules.normalized_facing(
			segment.path.back() - segment.path[segment.path.size() - 2]
		)
		dragged_destination = segment.path[segment.path.size() - 2]
	var movement_contract := TacticalInvalidationContract.movement(
		unit.unit_id, unit.team_id
	)
	if not opening_ids.is_empty():
		movement_contract.geometry_changed = true
		movement_contract.environment_visuals_changed = true
		movement_contract.justification = "Movement opened authored path boundaries."
	var changes := TacticalChangeSet.new(
		&"unit_moved",
		_state_store.state.revision,
		movement_contract
	)
	if not opening_ids.is_empty():
		changes.stage(
			Callable(self, "_open_path_openings").bind(opening_ids),
			Callable(self, "_restore_path_openings").bind(opening_snapshots),
			"A door on the movement boundary could not be opened.",
			&"movement_door_open_failed"
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
			"The destination became invalid before movement could commit.",
			&"invalid_destination"
		)
	if segment.cost_feet > 0:
		changes.stage(
			Callable(self, "_apply_move_budget").bind(
				unit,
				segment.cost_feet,
				segment.diagonal_steps
			),
			Callable(self, "_restore_move_budget").bind(
				unit,
				capacity_before,
				spent_before,
				diagonal_before
			),
			"Movement cost could not be committed.",
			&"movement_cost_failed"
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
	var message: String = (
		"movement_interrupted_by_detection"
		if detection_resolution != null and detection_resolution.movement_interrupted()
		else "movement_segment_committed"
	)
	return OperationResult.committed(
		segment,
		message,
		_state_store.state.revision
	)


func _commit_player_step_cost(
		unit: TacticalUnitState,
		origin: Vector2i,
		destination: Vector2i
) -> OperationResult:
	if unit == null or unit.grid_position != origin:
		return OperationResult.fail(
			&"movement_step_stale",
			"The mover is no longer on the tile that provoked the Reaction."
		)
	var navigation := TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	var step_result: MovementPathResult = MovementRules.calculate_path_cost(
		[origin, destination],
		navigation,
		unit.diagonal_steps_used
	)
	if not step_result.success:
		return OperationResult.fail(&"movement_step_invalid", step_result.failure_reason)
	if step_result.cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		return OperationResult.fail(
			&"insufficient_capacity",
			"The provoking step can no longer be afforded."
		)
	var capacity_before: int = unit.action_budget.remaining_turn_capacity_feet
	var spent_before: int = unit.action_budget.normal_capacity_spent_feet
	var diagonal_before: int = unit.diagonal_steps_used
	var changes := TacticalChangeSet.new(
		&"movement_step_cost_committed",
		_state_store.state.revision,
		TacticalInvalidationContract.movement_cost(unit.unit_id)
	)
	changes.stage(
		Callable(self, "_apply_move_budget").bind(
			unit,
			step_result.cost_feet,
			step_result.diagonal_steps
		),
		Callable(self, "_restore_move_budget").bind(
			unit,
			capacity_before,
			spent_before,
			diagonal_before
		),
		"The provoking step cost could not be committed.",
		&"movement_step_cost_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	return OperationResult.committed(
		step_result,
		"Provoking movement cost committed before entry.",
		_state_store.state.revision
	)


func _commit_player_entry_without_budget(
		unit: TacticalUnitState,
		origin: Vector2i,
		destination: Vector2i
) -> OperationResult:
	if unit == null or unit.grid_position != origin:
		return OperationResult.fail(
			&"movement_entry_stale",
			"The mover is no longer at the authoritative interruption tile."
		)
	var facing_before: Vector2i = unit.facing_direction
	var dragged_before: Dictionary = _state_store.state.dragged_body_cell_snapshot(
		unit.unit_id
	)
	var facing_after: Vector2i = TacticalPerceptionRules.normalized_facing(
		destination - origin
	)
	var changes := TacticalChangeSet.new(
		&"unit_movement_step_entered",
		_state_store.state.revision,
		TacticalInvalidationContract.movement(unit.unit_id, unit.team_id)
	)
	changes.stage(
		Callable(self, "_set_unit_position_and_facing").bind(
			unit.unit_id,
			destination,
			facing_after,
			origin
		),
		Callable(self, "_restore_unit_position_and_facing").bind(
			unit.unit_id,
			origin,
			facing_before,
			dragged_before
		),
		"The mover could not enter the tile after the Reaction resolved.",
		&"movement_entry_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	return OperationResult.committed(
		MovementPathResult.completed([origin, destination], 0, 0),
		"Movement entered the triggering tile after the leaving-tile Reaction.",
		_state_store.state.revision
	)


func _commit_player_detection_for_step(
		unit: TacticalUnitState,
		origin: Vector2i,
		destination: Vector2i
) -> OperationResult:
	if _detection_service == null or unit == null:
		return OperationResult.no_change(false, "No movement detection was required.")
	var dice_checkpoint: Dictionary = (
		_dice_roller.snapshot_state() if _dice_roller != null else {}
	)
	var resolution: TacticalDetectionResolution = (
		_detection_service.prepare_path_resolution(
			unit.unit_id,
			[origin, destination]
		)
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
		"Detection after entering the Reaction tile could not be committed.",
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
		"Movement detection resolved after entering the triggering tile.",
		_state_store.state.revision
	)


func _append_movement_result(
		aggregate: MovementPathResult,
		segment: MovementPathResult
) -> void:
	if aggregate == null or segment == null:
		return
	_append_path_unique(aggregate.path, segment.path)
	aggregate.cost_feet += segment.cost_feet
	aggregate.diagonal_steps += segment.diagonal_steps
	for event: Dictionary in segment.reaction_events:
		aggregate.reaction_events.append(event.duplicate(true))


func _append_path_unique(
		target_path: Array[Vector2i],
		additional_path: Array[Vector2i]
) -> void:
	for tile: Vector2i in additional_path:
		if target_path.is_empty() or target_path.back() != tile:
			target_path.append(tile)


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


func _opening_plan_for_path(
		unit: TacticalUnitState,
		path_result: MovementPathResult,
		navigation: TacticalNavigationSnapshot
) -> Dictionary:
	var opening_ids: Array[StringName] = []
	var pause_index: int = -1
	if (
		unit == null
		or path_result == null
		or not path_result.success
		or path_result.path.size() <= 1
	):
		return {
			"opening_ids": opening_ids,
			"paused_for_new_information": false,
			"committed_path_result": path_result,
		}
	for index: int in range(1, path_result.path.size()):
		var previous: Vector2i = path_result.path[index - 1]
		var current: Vector2i = path_result.path[index]
		if not TacticalEdgeKey.are_adjacent(previous, current):
			continue
		var opening_id: StringName = navigation.auto_opening_id(previous, current)
		if opening_id.is_empty():
			continue
		if not opening_ids.has(opening_id):
			opening_ids.append(opening_id)
		# Stage 4.4e2 correction: a newly opened door always commits as a separate
		# path boundary. The unit remains on the near side, visibility/detection
		# refresh against the now-open geometry, and a new movement command is
		# required to cross. This prevents closed-door geometry being used for a
		# route that has already crossed the opening.
		pause_index = index
		break
	if pause_index < 0:
		return {
			"opening_ids": opening_ids,
			"paused_for_new_information": false,
			"committed_path_result": path_result,
		}
	var committed_path: Array[Vector2i] = []
	for index: int in range(0, pause_index):
		committed_path.append(path_result.path[index])
	if committed_path.is_empty():
		committed_path.append(path_result.path[0])
	var base_result: MovementPathResult = MovementRules.calculate_path_cost(
		committed_path,
		navigation,
		unit.diagonal_steps_used
	)
	if not base_result.success:
		return {
			"opening_ids": opening_ids,
			"paused_for_new_information": true,
			"committed_path_result": base_result,
		}
	var pause_opening_id: StringName = opening_ids.back()
	var definition: TacticalOpeningDefinition = _map_definition.opening_definition(
		pause_opening_id
	)
	base_result.cost_feet += maxi(0, definition.operation_cost_feet) if definition != null else 5
	return {
		"opening_ids": opening_ids,
		"paused_for_new_information": true,
		"committed_path_result": base_result,
	}


func _open_path_openings(opening_ids: Array[StringName]) -> bool:
	var environment: TacticalEnvironmentState = _state_store.state.environment_state
	if environment == null:
		return opening_ids.is_empty()
	for opening_id: StringName in opening_ids:
		var runtime: TacticalOpeningState = environment.opening_state(opening_id)
		if runtime == null:
			return false
		if runtime.is_open():
			continue
		if not environment.open_door(opening_id):
			return false
	return true


func _restore_path_openings(snapshots: Dictionary) -> void:
	var environment: TacticalEnvironmentState = _state_store.state.environment_state
	if environment == null:
		return
	for opening_value: Variant in snapshots.keys():
		var opening_id := StringName(opening_value)
		var snapshot_value: Variant = snapshots.get(opening_value, {})
		if snapshot_value is Dictionary:
			environment.restore_source(opening_id, snapshot_value)


func mark_unit_ended(unit_id: StringName) -> OperationResult:
	if not _state_store.state.phase_state.is_side_based() or not _state_store.state.phase_state.is_player_phase():
		return OperationResult.fail(
			&"wrong_phase",
			"Team-phase unit ending is unavailable during initiative combat."
		)

	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")

	var ended_before: bool = unit.action_budget.ended_activation
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"unit_ended",
		_state_store.state.revision,
		TacticalInvalidationContract.action_budget([unit.unit_id])
	)
	changes.stage(
		Callable(self, "_set_activation_ended").bind(unit, true),
		Callable(self, "_restore_activation_ended").bind(unit, ended_before),
		"The unit could not end its activation."
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed

	_record_event(
		&"unit_ended",
		"%s ended its activation." % unit.display_name,
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"details": [
				"Remaining capacity: %d ft"
				% unit.action_budget.remaining_turn_capacity_feet,
				"Quick Action: %s"
				% (
					"Ready"
					if unit.action_budget.quick_action_available
					else "Spent"
				),
				"Reaction: %s"
				% (
					"Ready"
					if unit.action_budget.reaction_available
					else "Spent"
				),
			],
		}
	)
	return OperationResult.ok(
		null,
		"%s is marked as ended. Select it again to reactivate its unspent options."
		% unit.display_name
	)


func reactivate_unit(unit_id: StringName) -> OperationResult:
	if not _state_store.state.phase_state.is_side_based() or not _state_store.state.phase_state.is_player_phase():
		return OperationResult.fail(
			&"wrong_phase",
			"Team-phase reactivation is unavailable during initiative combat."
		)

	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")
	if unit.is_defeated():
		return OperationResult.fail(
			&"unit_defeated",
			"Defeated units cannot be reactivated."
		)
	if not unit.action_budget.ended_activation:
		return OperationResult.ok(null, "%s is already active." % unit.display_name)

	var ended_before: bool = unit.action_budget.ended_activation
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"unit_reactivated",
		_state_store.state.revision,
		TacticalInvalidationContract.action_budget([unit.unit_id])
	)
	changes.stage(
		Callable(self, "_set_activation_ended").bind(unit, false),
		Callable(self, "_restore_activation_ended").bind(unit, ended_before),
		"The unit could not be reactivated."
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed

	_record_event(
		&"unit_reactivated",
		"%s reactivated." % unit.display_name,
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"details": [
				"Existing unspent capacity was preserved.",
			],
		}
	)
	return OperationResult.ok(
		null,
		"%s reactivated with its existing unspent budget." % unit.display_name
	)


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
	_state_store.state.restore_dragged_body_cells(
		dragged_body_cells_before
	)


func _apply_move_budget(
	unit: TacticalUnitState,
	cost_feet: int,
	diagonal_steps: int
) -> bool:
	# Ordinary movement at exactly 0 HP uses the reduced Disabled capacity but
	# is not automatically a strenuous action.
	unit.action_budget.spend_normal_capacity(cost_feet)
	unit.diagonal_steps_used += diagonal_steps
	return true


func _restore_move_budget(
	unit: TacticalUnitState,
	remaining_feet: int,
	spent_feet: int,
	diagonal_steps: int
) -> void:
	unit.action_budget.remaining_turn_capacity_feet = remaining_feet
	unit.action_budget.normal_capacity_spent_feet = spent_feet
	unit.diagonal_steps_used = diagonal_steps


func _set_activation_ended(
		unit: TacticalUnitState,
		ended: bool
) -> bool:
	unit.action_budget.ended_activation = ended
	return true


func _restore_activation_ended(
		unit: TacticalUnitState,
		ended: bool
) -> void:
	unit.action_budget.ended_activation = ended


func _record_event(
		event_type: StringName,
		summary: String,
		options: Dictionary
) -> void:
	if _event_journal == null:
		return
	if not _event_journal.has_method("record_event"):
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
