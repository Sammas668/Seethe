class_name SprintMoveHandler
extends RefCounted

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _event_journal: RefCounted


func _init(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		event_journal_value: RefCounted = null
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_event_journal = event_journal_value


func preview(unit: TacticalUnitState, destination: Vector2i) -> MovementPathResult:
	if unit == null:
		return MovementPathResult.failed("No unit is selected.")
	if unit.is_defeated():
		return MovementPathResult.failed("Defeated units cannot Sprint.")
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
		var tile: Vector2i = path_result.path[index]
		if _map_definition.is_difficult(tile):
			return MovementPathResult.failed(
				"The prototype Sprint cannot cross difficult terrain."
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
	if not _state_store.state.phase_state.is_player_phase():
		return OperationResult.fail(
			&"wrong_phase",
			"Sprint is unavailable outside the Player Phase."
		)

	var unit: TacticalUnitState = _state_store.state.get_unit(command.unit_id)
	if unit == null:
		return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")

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
	var capacity_before: int = unit.action_budget.remaining_turn_capacity_feet
	var spent_before: int = unit.action_budget.normal_capacity_spent_feet
	var reaction_before: bool = unit.action_budget.reaction_available
	var diagonal_before: int = unit.diagonal_steps_used

	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"unit_sprinted",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_set_unit_position").bind(
			unit.unit_id,
			command.destination
		),
		Callable(self, "_restore_unit_position").bind(
			unit.unit_id,
			origin
		),
		"The destination became invalid before Sprint could commit.",
		&"invalid_destination"
	)
	changes.stage(
		Callable(self, "_apply_sprint_budget").bind(
			unit,
			path_result.diagonal_steps
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

	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed

	_record_event(
		&"sprint",
		"%s sprinted %d ft."
		% [unit.display_name, path_result.cost_feet],
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"action_id": &"action.sprint",
			"details": [
				"From: (%d, %d)" % [origin.x, origin.y],
				"To: (%d, %d)"
				% [command.destination.x, command.destination.y],
				"Distance: %d ft" % path_result.cost_feet,
				"Cost: Full Action",
				"Capacity: %d → %d ft"
				% [
					capacity_before,
					unit.action_budget.remaining_turn_capacity_feet,
				],
				"Reaction: %s → Spent"
				% ("Ready" if reaction_before else "Spent"),
			],
			"resource_changes": [
				{
					"resource": &"normal_capacity",
					"before": capacity_before,
					"after": unit.action_budget.remaining_turn_capacity_feet,
				},
				{
					"resource": &"reaction",
					"before": reaction_before,
					"after": unit.action_budget.reaction_available,
				},
			],
		}
	)
	return OperationResult.ok(
		path_result,
		"%s sprinted %d ft and spent its Full Action. Reaction lost until refresh."
		% [unit.display_name, path_result.cost_feet]
	)


func _set_unit_position(
		unit_id: StringName,
		destination: Vector2i
) -> bool:
	return _state_store.state.set_unit_position(
		unit_id,
		destination,
		_map_definition,
		false
	)


func _restore_unit_position(
		unit_id: StringName,
		destination: Vector2i
) -> void:
	_state_store.state.set_unit_position(
		unit_id,
		destination,
		_map_definition,
		false
	)


func _apply_sprint_budget(
		unit: TacticalUnitState,
		diagonal_steps: int
) -> bool:
	unit.diagonal_steps_used += diagonal_steps
	unit.action_budget.spend_normal_capacity(
		unit.action_budget.maximum_turn_capacity_feet
	)
	unit.action_budget.reaction_available = false
	return true


func _restore_sprint_budget(
		unit: TacticalUnitState,
		remaining_feet: int,
		spent_feet: int,
		reaction_available: bool,
		diagonal_steps: int
) -> void:
	unit.action_budget.remaining_turn_capacity_feet = remaining_feet
	unit.action_budget.normal_capacity_spent_feet = spent_feet
	unit.action_budget.reaction_available = reaction_available
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
