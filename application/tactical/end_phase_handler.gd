class_name EndPhaseHandler
extends RefCounted

var _state_store: TacticalStateStore
var _event_journal: RefCounted


func _init(
		state_store: TacticalStateStore,
		event_journal_value: RefCounted = null
) -> void:
	_state_store = state_store
	_event_journal = event_journal_value


func begin_world_phase(command: EndPhaseCommand) -> OperationResult:
	if not _state_store.state.phase_state.is_player_phase():
		return OperationResult.fail(
			&"wrong_phase",
			"The Player Phase is not currently active."
		)
	if command.requested_from_phase != TacticalPhaseState.PLAYER_PHASE:
		return OperationResult.fail(
			&"invalid_request",
			"The phase-change request did not originate from the Player Phase."
		)

	var phase_before: StringName = _state_store.state.phase_state.current_phase
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"world_phase_started",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_set_phase").bind(TacticalPhaseState.WORLD_PHASE),
		Callable(self, "_restore_phase").bind(
			phase_before,
			_state_store.state.phase_state.round_number
		),
		"The World Phase could not begin."
	)
	var committed: OperationResult = _state_store.commit(changes)
	if not committed.success:
		return committed

	_record_phase_event(
		"Round %d — Enemy Turn."
		% _state_store.state.phase_state.round_number,
		[
			"The player ended the Player Phase.",
			"AI-controlled enemy units are now activating.",
		]
	)
	return OperationResult.ok(null, "Enemy Turn started.")


func complete_world_phase() -> OperationResult:
	if not _state_store.state.phase_state.is_world_phase():
		return OperationResult.fail(
			&"wrong_phase",
			"The World Phase is not currently active."
		)

	var phase_snapshot: Dictionary = {
		"phase": _state_store.state.phase_state.current_phase,
		"round": _state_store.state.phase_state.round_number,
	}
	var unit_snapshots: Array[Dictionary] = []
	for unit: TacticalUnitState in _state_store.state.get_player_units():
		unit_snapshots.append({
			"unit": unit,
			"remaining": unit.action_budget.remaining_turn_capacity_feet,
			"spent": unit.action_budget.normal_capacity_spent_feet,
			"quick": unit.action_budget.quick_action_available,
			"reaction": unit.action_budget.reaction_available,
			"ordinary_attack": unit.action_budget.ordinary_attack_available,
			"ended": unit.action_budget.ended_activation,
			"diagonal": unit.diagonal_steps_used,
		})

	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"player_phase_started",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_begin_next_player_phase").bind(unit_snapshots),
		Callable(self, "_restore_round_state").bind(
			phase_snapshot,
			unit_snapshots
		),
		"The next Player Phase could not begin."
	)
	var committed: OperationResult = _state_store.commit(changes)
	if not committed.success:
		return committed

	_record_phase_event(
		"Round %d — Player Phase."
		% _state_store.state.phase_state.round_number,
		[
			"All friendly action budgets refreshed.",
			"Normal capacity, Quick Actions and Reactions are ready.",
		]
	)
	return OperationResult.ok(
		null,
		"Round %d began. All friendly action budgets refreshed."
		% _state_store.state.phase_state.round_number
	)


func _set_phase(phase_id: StringName) -> bool:
	_state_store.state.phase_state.current_phase = phase_id
	return true


func _restore_phase(
		phase_id: StringName,
		round_number: int
) -> void:
	_state_store.state.phase_state.current_phase = phase_id
	_state_store.state.phase_state.round_number = round_number


func _begin_next_player_phase(unit_snapshots: Array[Dictionary]) -> bool:
	for snapshot: Dictionary in unit_snapshots:
		var unit: TacticalUnitState = snapshot.get("unit") as TacticalUnitState
		if unit != null:
			unit.refresh_for_new_round()
	_state_store.state.phase_state.begin_next_player_phase()
	return true


func _restore_round_state(
		phase_snapshot: Dictionary,
		unit_snapshots: Array[Dictionary]
) -> void:
	_state_store.state.phase_state.current_phase = StringName(
		phase_snapshot.get("phase", TacticalPhaseState.WORLD_PHASE)
	)
	_state_store.state.phase_state.round_number = int(
		phase_snapshot.get("round", 1)
	)
	for snapshot: Dictionary in unit_snapshots:
		var unit: TacticalUnitState = snapshot.get("unit") as TacticalUnitState
		if unit == null:
			continue
		unit.action_budget.remaining_turn_capacity_feet = int(snapshot["remaining"])
		unit.action_budget.normal_capacity_spent_feet = int(snapshot["spent"])
		unit.action_budget.quick_action_available = bool(snapshot["quick"])
		unit.action_budget.reaction_available = bool(snapshot["reaction"])
		unit.action_budget.ordinary_attack_available = bool(
			snapshot["ordinary_attack"]
		)
		unit.action_budget.ended_activation = bool(snapshot["ended"])
		unit.diagonal_steps_used = int(snapshot["diagonal"])


func _record_phase_event(
		summary: String,
		details: Array
) -> void:
	if _event_journal == null:
		return
	if not _event_journal.has_method("record_event"):
		return

	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"phase_started",
		phase.round_number,
		phase.current_phase,
		summary,
		{
			"category": &"events",
			"details": details,
		}
	)
