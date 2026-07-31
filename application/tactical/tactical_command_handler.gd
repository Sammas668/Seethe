class_name TacticalCommandHandler
extends RefCounted

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _event_journal: RefCounted
var _detection_service: TacticalDetectionService
var _dice_roller: TacticalDiceRoller
var _reaction_service: TacticalReactionService


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


func execute_move(command: MoveCommand) -> OperationResult:
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
	if _reaction_service != null:
		_reaction_service.cancel_reservation_for_voluntary_move(unit.unit_id)

	var occupying_unit: TacticalUnitState = _state_store.state.get_unit_at_tile(
		command.destination,
		command.unit_id
	)
	if occupying_unit != null:
		return OperationResult.fail(
			&"destination_occupied",
			"%s already occupies that destination." % occupying_unit.display_name
		)

	var navigation: TacticalNavigationSnapshot = TacticalNavigationSnapshot.new(
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
	var opening_snapshots: Dictionary = {}
	for opening_id: StringName in planned_opening_ids:
		opening_snapshots[opening_id] = _state_store.state.environment_state.snapshot_source(
			opening_id
		)
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

	var origin: Vector2i = unit.grid_position
	var facing_before: Vector2i = unit.facing_direction
	var capacity_before: int = unit.action_budget.remaining_turn_capacity_feet
	var spent_before: int = unit.action_budget.normal_capacity_spent_feet
	var diagonal_before: int = unit.diagonal_steps_used
	var dice_snapshot: Dictionary = (
		_dice_roller.snapshot_state()
		if _dice_roller != null
		else {}
	)
	var detection_resolution: TacticalDetectionResolution = null
	var detection_snapshot: Dictionary = {}
	if _detection_service != null:
		detection_resolution = _detection_service.prepare_path_resolution(
			unit.unit_id,
			path_result.path
		)
		detection_snapshot = _detection_service.snapshot_for_resolution(
			detection_resolution
		)

	var reaction_resolution: Dictionary = {}
	if _reaction_service != null:
		reaction_resolution = _reaction_service.resolve_ai_reactions_along_path(
			unit.unit_id,
			path_result.path,
			&"normal",
			detection_resolution
		)
	var committed_path_result: MovementPathResult = path_result
	var reaction_path: Array[Vector2i] = []
	for tile_value: Variant in reaction_resolution.get("committed_path", []):
		reaction_path.append(tile_value as Vector2i)
	if not reaction_path.is_empty() and reaction_path.size() < path_result.path.size():
		committed_path_result = MovementRules.calculate_path_cost(
			reaction_path, navigation, unit.diagonal_steps_used
		)
		if not committed_path_result.success:
			if _dice_roller != null:
				_dice_roller.restore_state(dice_snapshot)
			return OperationResult.fail(
				&"reaction_interrupted_path_invalid",
				committed_path_result.failure_reason
			)
	if detection_resolution != null and detection_resolution.movement_interrupted():
		var committed_path: Array[Vector2i] = detection_resolution.committed_path(
			path_result.path
		)
		if committed_path.size() < committed_path_result.path.size():
			committed_path_result = MovementRules.calculate_path_cost(
				committed_path,
				navigation,
				unit.diagonal_steps_used
			)
		if not committed_path_result.success:
			if _dice_roller != null:
				_dice_roller.restore_state(dice_snapshot)
			return OperationResult.fail(
				&"interrupted_path_invalid",
				committed_path_result.failure_reason
			)
	committed_path_result.reaction_events.clear()
	for event_value: Variant in reaction_resolution.get("reaction_resolutions", []):
		if not (event_value is Dictionary):
			continue
		var reaction_event: Dictionary = (event_value as Dictionary).duplicate(true)
		var event_path_index: int = int(reaction_event.get("path_index", -1))
		if event_path_index < committed_path_result.path.size():
			committed_path_result.reaction_events.append(reaction_event)
	var actual_destination: Vector2i = committed_path_result.path.back()
	var actual_facing: Vector2i = facing_before
	if committed_path_result.path.size() > 1:
		actual_facing = TacticalPerceptionRules.normalized_facing(
			committed_path_result.path.back()
			- committed_path_result.path[committed_path_result.path.size() - 2]
		)
	var dragged_body_cells_before: Dictionary = (
		_state_store.state.dragged_body_cell_snapshot(unit.unit_id)
	)
	var dragged_body_destination := Vector2i(-1, -1)
	if committed_path_result.path.size() > 1:
		dragged_body_destination = committed_path_result.path[
			committed_path_result.path.size() - 2
		]

	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"unit_moved",
		_state_store.state.revision
	)
	if not planned_opening_ids.is_empty():
		changes.stage(
			Callable(self, "_open_path_openings").bind(planned_opening_ids),
			Callable(self, "_restore_path_openings").bind(opening_snapshots),
			"A door on the route could not be opened.",
			&"movement_door_open_failed"
		)
	changes.stage(
		Callable(self, "_set_unit_position_and_facing").bind(
			unit.unit_id,
			actual_destination,
			actual_facing,
			dragged_body_destination
		),
		Callable(self, "_restore_unit_position_and_facing").bind(
			unit.unit_id,
			origin,
			facing_before,
			dragged_body_cells_before
		),
		"The destination became invalid before movement could commit.",
		&"invalid_destination"
	)
	changes.stage(
		Callable(self, "_apply_move_budget").bind(
			unit,
			committed_path_result.cost_feet,
			committed_path_result.diagonal_steps
		),
		Callable(self, "_restore_move_budget").bind(
			unit,
			capacity_before,
			spent_before,
			diagonal_before
		),
		"Movement cost could not be committed."
	)
	if _detection_service != null and detection_resolution != null:
		changes.stage(
			Callable(_detection_service, "apply_resolution").bind(detection_resolution),
			Callable(_detection_service, "restore_resolution_snapshot").bind(detection_snapshot),
			"Detection and alert state could not be committed.",
			&"detection_commit_failed"
		)

	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		if _dice_roller != null:
			_dice_roller.restore_state(dice_snapshot)
		return committed

	var interrupted: bool = (
		detection_resolution != null
		and detection_resolution.movement_interrupted()
		and committed_path_result.path.size() <= detection_resolution.committed_path(path_result.path).size()
	)
	var reaction_interrupted: bool = bool(reaction_resolution.get("stopped", false))
	var movement_summary: String = ""
	if reaction_interrupted:
		movement_summary = (
			"%s moved %d ft before a Reaction stopped movement."
			% [unit.display_name, committed_path_result.cost_feet]
		)
	elif interrupted:
		movement_summary = (
			"%s moved %d ft before detection interrupted movement."
			% [unit.display_name, committed_path_result.cost_feet]
		)
	elif paused_for_new_information:
		movement_summary = (
			"%s opened a door and paused before crossing the opening."
			% unit.display_name
		)
	else:
		movement_summary = "%s moved %d ft." % [
			unit.display_name, committed_path_result.cost_feet
		]
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
				"Planned destination: (%d, %d)"
				% [command.destination.x, command.destination.y],
				"Distance: %d ft" % committed_path_result.cost_feet,
				"Facing after movement: (%d, %d)"
				% [actual_facing.x, actual_facing.y],
				"Capacity: %d → %d ft"
				% [
					capacity_before,
					unit.action_budget.remaining_turn_capacity_feet,
				],
				(
					"Movement stopped because a Reaction left the mover unable to continue."
					if reaction_interrupted
					else "Movement stopped on the first failed Stealth tile."
					if interrupted
					else "The door opened and movement paused before crossing the opening."
					if paused_for_new_information
					else "Movement reached the planned destination."
				),
			],
			"resource_changes": [
				{
					"resource": &"normal_capacity",
					"before": capacity_before,
					"after": unit.action_budget.remaining_turn_capacity_feet,
				},
			],
		}
	)
	if _detection_service != null and detection_resolution != null:
		_detection_service.record_resolution(detection_resolution)
	if _detection_service != null and not unit.squad_id.is_empty():
		_detection_service.request_current_perception_for_squad(unit.squad_id)
	return OperationResult.committed(
		committed_path_result,
		movement_summary,
		_state_store.state.revision
	)


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
		_state_store.state.revision
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
		_state_store.state.revision
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
