class_name TacticalCommandHandler
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


func execute_move(command: MoveCommand) -> OperationResult:
	if not _state_store.state.phase_state.is_player_phase():
		return OperationResult.fail(
			&"wrong_phase",
			"Movement is unavailable outside the Player Phase."
		)

	var unit: TacticalUnitState = _state_store.state.get_unit(command.unit_id)
	if unit == null:
		return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")
	if unit.is_defeated():
		return OperationResult.fail(
			&"unit_defeated",
			"Defeated units cannot move."
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

	var origin: Vector2i = unit.grid_position
	var capacity_before: int = unit.action_budget.remaining_turn_capacity_feet
	var spent_before: int = unit.action_budget.normal_capacity_spent_feet
	var diagonal_before: int = unit.diagonal_steps_used

	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"unit_moved",
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
		"The destination became invalid before movement could commit.",
		&"invalid_destination"
	)
	changes.stage(
		Callable(self, "_apply_move_budget").bind(
			unit,
			path_result.cost_feet,
			path_result.diagonal_steps
		),
		Callable(self, "_restore_move_budget").bind(
			unit,
			capacity_before,
			spent_before,
			diagonal_before
		),
		"Movement cost could not be committed."
	)

	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed

	_record_event(
		&"movement",
		"%s moved %d ft."
		% [unit.display_name, path_result.cost_feet],
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"action_id": &"action.move",
			"details": [
				"From: (%d, %d)" % [origin.x, origin.y],
				"To: (%d, %d)"
				% [command.destination.x, command.destination.y],
				"Distance: %d ft" % path_result.cost_feet,
				"Capacity: %d → %d ft"
				% [
					capacity_before,
					unit.action_budget.remaining_turn_capacity_feet,
				],
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
	return OperationResult.ok(
		path_result,
		"%s moved %d ft."
		% [unit.display_name, path_result.cost_feet]
	)


func mark_unit_ended(unit_id: StringName) -> OperationResult:
	if not _state_store.state.phase_state.is_player_phase():
		return OperationResult.fail(
			&"wrong_phase",
			"Units can only be ended during the Player Phase."
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
	if not _state_store.state.phase_state.is_player_phase():
		return OperationResult.fail(
			&"wrong_phase",
			"Units can only be reactivated during the Player Phase."
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


func _apply_move_budget(
		unit: TacticalUnitState,
		cost_feet: int,
		diagonal_steps: int
) -> bool:
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
