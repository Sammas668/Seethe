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


func begin_enemy_phase(command: EndPhaseCommand) -> OperationResult:
	if not _state_store.state.phase_state.is_side_based():
		return OperationResult.fail(
			&"initiative_active",
			"Team phases are unavailable during initiative combat."
		)
	if not _state_store.state.phase_state.is_player_phase():
		return OperationResult.fail(
			&"wrong_phase",
			"The Player Phase is not currently active."
		)
	if command == null or command.requested_from_phase != TacticalPhaseState.PLAYER_PHASE:
		return OperationResult.fail(
			&"invalid_request",
			"The phase-change request did not originate from the Player Phase."
		)

	var phase_before: StringName = _state_store.state.phase_state.current_phase
	var round_before: int = _state_store.state.phase_state.round_number
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"enemy_phase_started",
		_state_store.state.revision,
		TacticalInvalidationContract.initiative()
	)
	changes.stage(
		Callable(self, "_set_phase").bind(TacticalPhaseState.ENEMY_PHASE),
		Callable(self, "_restore_phase").bind(phase_before, round_before),
		"The Enemy Phase could not begin."
	)
	var committed: OperationResult = _state_store.commit(changes)
	if not committed.success:
		return committed

	_record_phase_event(
		"Round %d — Enemy Phase."
		% _state_store.state.phase_state.round_number,
		[
			"The player ended the Player Phase.",
			"AI-controlled enemy units now activate in stable order.",
		]
	)
	return OperationResult.ok(null, "Enemy Phase started.")


# Compatibility entry point retained for Stage 4.0/4.1 callers. Supplying a
# command begins the Enemy Phase; calling without one advances Enemy -> World.
func begin_world_phase(command: EndPhaseCommand = null) -> OperationResult:
	if command != null:
		return begin_enemy_phase(command)
	return begin_environment_phase()


func begin_environment_phase() -> OperationResult:
	if not _state_store.state.phase_state.is_side_based():
		return OperationResult.fail(
			&"initiative_active",
			"The side-based World Phase is unavailable during initiative combat."
		)
	if (
		_state_store.state.phase_state.current_phase
		!= TacticalPhaseState.ENEMY_PHASE
	):
		return OperationResult.fail(
			&"wrong_phase",
			"The Enemy Phase must finish before the World Phase begins."
		)

	var phase_before: StringName = _state_store.state.phase_state.current_phase
	var round_before: int = _state_store.state.phase_state.round_number
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"world_phase_started",
		_state_store.state.revision,
		TacticalInvalidationContract.initiative()
	)
	changes.stage(
		Callable(self, "_set_phase").bind(TacticalPhaseState.WORLD_PHASE),
		Callable(self, "_restore_phase").bind(phase_before, round_before),
		"The World Phase could not begin."
	)
	var committed: OperationResult = _state_store.commit(changes)
	if not committed.success:
		return committed

	_record_phase_event(
		"Round %d — World Phase."
		% _state_store.state.phase_state.round_number,
		[
			"All Enemy Phase activations are complete.",
			"No world actors are configured in the current combat slice.",
		]
	)
	return OperationResult.ok(null, "World Phase started.")


func complete_world_phase() -> OperationResult:
	if not _state_store.state.phase_state.is_side_based():
		return OperationResult.fail(
			&"initiative_active",
			"The side-based World Phase is unavailable during initiative combat."
		)
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
			"reaction": unit.action_budget.reaction_snapshot(),
			"ordinary_attack": unit.action_budget.ordinary_attack_available,
			"ended": unit.action_budget.ended_activation,
			"diagonal": unit.diagonal_steps_used,
		})

	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"player_phase_started",
		_state_store.state.revision,
		TacticalInvalidationContract.initiative()
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
			"Normal capacity, Quick Actions, Reactions and the normal attack are ready.",
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


func _begin_next_player_phase(_unit_snapshots: Array[Dictionary]) -> bool:
	for unit: TacticalUnitState in _state_store.state.get_player_units():
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
		unit.action_budget.restore_reaction_snapshot(snapshot.get("reaction", {}))
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
