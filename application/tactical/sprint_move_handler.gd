class_name SprintMoveHandler
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


func preview(unit: TacticalUnitState, destination: Vector2i) -> MovementPathResult:
	if unit == null:
		return MovementPathResult.failed("No unit is selected.")
	if unit.is_unconscious() or unit.is_dead():
		return MovementPathResult.failed("Unconscious or dead units cannot Sprint.")
	if unit.is_disabled():
		return MovementPathResult.failed("Disabled characters cannot take Full Actions or Sprint.")
	if unit.action_budget.ended_activation:
		return MovementPathResult.failed("This unit is marked as ended.")
	if unit.action_budget.has_spent_normal_capacity():
		return MovementPathResult.failed(
			"Sprint is a Full Action and requires an untouched normal-action budget."
		)

	var navigation: TacticalNavigationSnapshot = TacticalNavigationSnapshot.new(
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

	var sprint_allowance: int = int(
		floor(unit.action_budget.maximum_turn_capacity_feet * 1.5 / 5.0)
	) * 5
	if path_result.cost_feet > sprint_allowance:
		return MovementPathResult.failed(
			"Sprint route costs %d ft; the unit's Sprint limit is %d ft."
			% [path_result.cost_feet, sprint_allowance]
		)

	return path_result


func execute(command: SprintMoveCommand) -> OperationResult:
	var unit: TacticalUnitState = _state_store.state.get_unit(command.unit_id)
	if unit == null:
		return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")
	if not _state_store.state.can_unit_act(command.unit_id):
		return OperationResult.fail(
			&"wrong_active_unit",
			"This unit is not currently allowed to Sprint."
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

	var path_result: MovementPathResult = preview(unit, command.destination)
	if not path_result.success:
		return OperationResult.fail(&"invalid_sprint", path_result.failure_reason)

	var origin: Vector2i = unit.grid_position
	var facing_before: Vector2i = unit.facing_direction
	var capacity_before: int = unit.action_budget.remaining_turn_capacity_feet
	var spent_before: int = unit.action_budget.normal_capacity_spent_feet
	var reaction_before: Dictionary = unit.action_budget.reaction_snapshot()
	var diagonal_before: int = unit.diagonal_steps_used
	var dice_snapshot: Dictionary = (
		_dice_roller.snapshot_state() if _dice_roller != null else {}
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

	var navigation := TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit.unit_id
	)
	var reaction_resolution: Dictionary = {}
	if _reaction_service != null:
		reaction_resolution = _reaction_service.resolve_ai_reactions_along_path(
			unit.unit_id, path_result.path, &"sprint", detection_resolution
		)
	var committed_path_result: MovementPathResult = path_result
	var reaction_path: Array[Vector2i] = []
	for tile_value: Variant in reaction_resolution.get("committed_path", []):
		reaction_path.append(tile_value as Vector2i)
	if not reaction_path.is_empty() and reaction_path.size() < path_result.path.size():
		committed_path_result = MovementRules.calculate_path_cost(
			reaction_path, navigation, unit.diagonal_steps_used
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
				&"interrupted_sprint_path_invalid",
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
		&"unit_sprinted",
		_state_store.state.revision
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
		"The destination became invalid before Sprint could commit.",
		&"invalid_destination"
	)
	changes.stage(
		Callable(self, "_apply_sprint_budget").bind(
			unit,
			committed_path_result.diagonal_steps
		),
		Callable(self, "_restore_sprint_budget").bind(
			unit,
			capacity_before,
			spent_before,
			reaction_before,
			diagonal_before
		),
		"Sprint cost could not be committed."
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
	)
	var reaction_interrupted: bool = bool(reaction_resolution.get("stopped", false))
	var sprint_summary: String = (
		"%s sprinted %d ft before a Reaction stopped movement."
		% [unit.display_name, committed_path_result.cost_feet]
		if reaction_interrupted
		else "%s sprinted %d ft before detection interrupted movement."
		% [unit.display_name, committed_path_result.cost_feet]
		if interrupted
		else "%s sprinted %d ft." % [unit.display_name, committed_path_result.cost_feet]
	)
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
				"Planned destination: (%d, %d)"
				% [command.destination.x, command.destination.y],
				"Distance: %d ft" % committed_path_result.cost_feet,
				"Facing after movement: (%d, %d)"
				% [actual_facing.x, actual_facing.y],
				"Cost: Full Action",
				"Capacity: %d → %d ft"
				% [
					capacity_before,
					unit.action_budget.remaining_turn_capacity_feet,
				],
				"Reaction: %s → Spent"
				% ReactionResourceState.display_label(StringName(reaction_before.get(
					"state", ReactionResourceState.AVAILABLE
				))),
				(
					"Sprint stopped on the first failed Stealth tile."
					if interrupted
					else "Sprint reached the planned destination."
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
					"before": reaction_before.get("state", ReactionResourceState.AVAILABLE),
					"after": unit.action_budget.reaction_state,
				},
			],
		}
	)
	if _detection_service != null and detection_resolution != null:
		_detection_service.record_resolution(detection_resolution)
	if _detection_service != null and not unit.squad_id.is_empty():
		_detection_service.request_current_perception_for_squad(unit.squad_id)
	var result_message: String = sprint_summary + (
		" Full Action and Reaction remain spent."
		if interrupted
		else " Full Action spent; Reaction lost until refresh."
	)
	return OperationResult.committed(
		committed_path_result,
		result_message,
		_state_store.state.revision
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


func _apply_sprint_budget(
		unit: TacticalUnitState,
		diagonal_steps: int
) -> bool:
	unit.diagonal_steps_used += diagonal_steps
	unit.action_budget.spend_normal_capacity(
		unit.action_budget.maximum_turn_capacity_feet
	)
	unit.action_budget.spend_reaction()
	return true


func _restore_sprint_budget(
		unit: TacticalUnitState,
		remaining_feet: int,
		spent_feet: int,
		reaction_snapshot: Dictionary,
		diagonal_steps: int
) -> void:
	unit.action_budget.remaining_turn_capacity_feet = remaining_feet
	unit.action_budget.normal_capacity_spent_feet = spent_feet
	unit.action_budget.restore_reaction_snapshot(reaction_snapshot)
	unit.diagonal_steps_used = diagonal_steps


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
