class_name InitiativeTurnHandler
extends RefCounted

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _event_journal: RefCounted
var _life_state_handler


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		event_journal_value: RefCounted,
		life_state_handler = null
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_event_journal = event_journal_value
	_life_state_handler = life_state_handler


func end_active_turn(unit_id: StringName) -> OperationResult:
	var phase: TacticalPhaseState = _state_store.state.phase_state
	if not phase.is_initiative_combat():
		return OperationResult.fail(&"initiative_inactive", "Initiative combat is not active.")
	if not phase.is_active_unit(unit_id):
		return OperationResult.fail(&"wrong_active_unit", "Only the active initiative unit can end its turn.")
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return OperationResult.fail(&"unknown_unit", "The active initiative unit is missing.")

	var phase_before: Dictionary = phase.snapshot()
	var ended_before: bool = unit.action_budget.ended_activation
	var budget_snapshots: Array[Dictionary] = []
	for participant: TacticalUnitState in _state_store.state.get_units():
		budget_snapshots.append(_budget_snapshot(participant))
	var squad_snapshots: Array[Dictionary] = _squad_snapshots()
	var changes := TacticalChangeSet.new(
		&"initiative_turn_advanced",
		_state_store.state.revision,
		TacticalInvalidationContract.initiative()
	)
	changes.stage(
		Callable(self, "_advance_turn").bind(unit),
		Callable(self, "_restore_turn").bind(
			phase_before,
			budget_snapshots,
			squad_snapshots,
			unit,
			ended_before
		),
		"The initiative turn could not advance.",
		&"initiative_advance_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	var combat_ended: bool = not phase.is_initiative_combat()
	_record_event(
		&"initiative_combat_ended" if combat_ended else &"initiative_turn_ended",
		(
			"Combat ended and team turns resumed."
			if combat_ended
			else "%s ended its initiative turn." % unit.display_name
		),
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"details": [
				(
					"Player Team Phase resumed."
					if combat_ended
					else "Next active unit: %s" % String(phase.active_unit_id())
				),
			],
		}
	)
	return OperationResult.ok(
		phase.active_unit_id(),
		"Combat ended. Player Team Phase resumed."
		if combat_ended
		else "Initiative advanced."
	)


func normalize_active_turn() -> OperationResult:
	var phase: TacticalPhaseState = _state_store.state.phase_state
	if not phase.is_initiative_combat():
		return OperationResult.ok(null, "Initiative combat is not active.")
	var active_id: StringName = phase.active_unit_id()
	var active: TacticalUnitState = _state_store.state.get_unit(active_id)
	if active != null and active.is_dying():
		if _life_state_handler == null:
			return OperationResult.fail(
				&"life_state_handler_missing",
				"The Dying turn cannot resolve because its handler is missing."
			)
		if active.last_dying_check_round < phase.round_number:
			var dying_result: OperationResult = (
				_life_state_handler.resolve_dying_check(active_id)
			)
			if not dying_result.success:
				return dying_result
		# A natural 20 at -1 HP can restore the character to Disabled. In that
		# specific case the character may use its limited turn immediately.
		if active.can_take_actions():
			active.reactivate_without_refresh()
			return OperationResult.ok(
				active_id,
				"%s recovered enough to act while Disabled."
				% active.display_name
			)
		# Stable, dead, or still Dying, the participant now advances
		# automatically after the check.
		if phase.is_initiative_combat() and phase.is_active_unit(active_id):
			var advance_result: OperationResult = end_active_turn(active_id)
			if not advance_result.success:
				return advance_result
		return OperationResult.ok(
			phase.active_unit_id(),
			"%s resolved a Dying check and its turn advanced."
			% active.display_name
		)
	if active != null and active.can_take_actions():
		return OperationResult.ok(active_id, "The active initiative unit is valid.")

	var phase_before: Dictionary = phase.snapshot()
	var budget_snapshots: Array[Dictionary] = []
	for unit: TacticalUnitState in _state_store.state.get_units():
		budget_snapshots.append(_budget_snapshot(unit))
	var squad_snapshots: Array[Dictionary] = _squad_snapshots()
	var changes := TacticalChangeSet.new(
		&"initiative_ineligible_unit_skipped",
		_state_store.state.revision,
		TacticalInvalidationContract.initiative()
	)
	changes.stage(
		Callable(self, "_skip_ineligible_active"),
		Callable(self, "_restore_normalize").bind(
			phase_before,
			budget_snapshots,
			squad_snapshots
		),
		"The invalid initiative participant could not be skipped.",
		&"initiative_skip_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	return OperationResult.ok(
		phase.active_unit_id(),
		"An ineligible initiative participant was skipped safely."
	)


func _restore_normalize(
		phase_before: Dictionary,
		budget_snapshots: Array[Dictionary],
		squad_snapshots: Array[Dictionary]
) -> void:
	_state_store.state.phase_state.restore(phase_before)
	for snapshot: Dictionary in budget_snapshots:
		_restore_budget_snapshot(snapshot)
	_restore_squad_snapshots(squad_snapshots)


func _skip_ineligible_active() -> bool:
	return _state_store.state.skip_ineligible_active_initiative_unit()


func _advance_turn(unit: TacticalUnitState) -> bool:
	unit.mark_activation_ended()
	return _state_store.state.advance_initiative_turn()


func _restore_turn(
		phase_before: Dictionary,
		budget_snapshots: Array[Dictionary],
		squad_snapshots: Array[Dictionary],
		unit: TacticalUnitState,
		ended_before: bool
) -> void:
	_state_store.state.phase_state.restore(phase_before)
	for snapshot: Dictionary in budget_snapshots:
		_restore_budget_snapshot(snapshot)
	_restore_squad_snapshots(squad_snapshots)
	unit.action_budget.ended_activation = ended_before


func _budget_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"unit_id": unit.unit_id,
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"reaction": unit.action_budget.reaction_snapshot(),
		"ordinary_attack": unit.action_budget.ordinary_attack_available,
		"ended": unit.action_budget.ended_activation,
		"diagonal": unit.diagonal_steps_used,
	}


func _restore_budget_snapshot(snapshot: Dictionary) -> void:
	var unit: TacticalUnitState = _state_store.state.get_unit(StringName(snapshot.get("unit_id", &"")))
	if unit == null:
		return
	unit.action_budget.remaining_turn_capacity_feet = int(snapshot.get("remaining", 0))
	unit.action_budget.normal_capacity_spent_feet = int(snapshot.get("spent", 0))
	unit.action_budget.quick_action_available = bool(snapshot.get("quick", false))
	unit.action_budget.restore_reaction_snapshot(snapshot.get("reaction", {}))
	unit.action_budget.ordinary_attack_available = bool(snapshot.get("ordinary_attack", false))
	unit.action_budget.ended_activation = bool(snapshot.get("ended", false))
	unit.diagonal_steps_used = int(snapshot.get("diagonal", 0))


func _squad_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for squad: TacticalSquadState in _state_store.state.get_squads():
		result.append({
			"squad_id": squad.squad_id,
			"search_rounds": squad.search_rounds_remaining,
			"last_seen": squad.last_seen_positions_by_unit_id.duplicate(true),
		})
	return result


func _restore_squad_snapshots(snapshots: Array[Dictionary]) -> void:
	for snapshot: Dictionary in snapshots:
		var squad: TacticalSquadState = _state_store.state.get_squad(
			StringName(snapshot.get("squad_id", &""))
		)
		if squad == null:
			continue
		squad.search_rounds_remaining = maxi(0, int(
			snapshot.get("search_rounds", 0)
		))
		var last_seen_value: Variant = snapshot.get("last_seen", {})
		squad.last_seen_positions_by_unit_id = (
			last_seen_value.duplicate(true)
			if last_seen_value is Dictionary
			else {}
		)


func _record_event(event_type: StringName, summary: String, options: Dictionary) -> void:
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
