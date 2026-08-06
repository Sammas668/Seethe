class_name DetectionBatchTransactionSupport
extends RefCounted

var _state_store: TacticalStateStore


func configure(state_store: TacticalStateStore) -> void:
	_state_store = state_store


func snapshot_for_resolutions(
		resolutions: Array[TacticalDetectionResolution]
) -> Dictionary:
	var snapshot: Dictionary = {
		"phase": _state_store.state.phase_state.snapshot(),
		"units": {},
		"squads": {},
		"budgets": [],
	}
	var unit_snapshots: Dictionary = {}
	for resolution: TacticalDetectionResolution in resolutions:
		if resolution == null:
			continue
		var unit: TacticalUnitState = _state_store.state.get_unit(
			resolution.unit_id
		)
		if unit == null or unit_snapshots.has(unit.unit_id):
			continue
		unit_snapshots[unit.unit_id] = {
			"stealth_enabled": unit.stealth_enabled,
			"stealth_roll_valid": unit.current_stealth_roll_valid,
			"stealth_roll_value": unit.current_stealth_roll_value,
			"stealth_total": unit.current_stealth_total,
			"revealed": unit.revealed_to_squad_ids.duplicate(),
		}
	snapshot["units"] = unit_snapshots
	var squad_snapshots: Dictionary = {}
	var affected_squad_ids: Array[StringName] = (
		_affected_squad_ids_for_resolutions(resolutions)
	)
	for squad_id: StringName in affected_squad_ids:
		var squad: TacticalSquadState = _state_store.state.get_squad(squad_id)
		if squad == null:
			continue
		squad_snapshots[squad.squad_id] = {
			"awareness": squad.awareness,
			"last_seen": squad.last_seen_positions_by_unit_id.duplicate(true),
			"search_rounds": squad.search_rounds_remaining,
		}
	snapshot["squads"] = squad_snapshots
	var budget_snapshots: Array[Dictionary] = []
	var participant_ids: Array[StringName] = []
	for resolution: TacticalDetectionResolution in resolutions:
		if resolution == null:
			continue
		for participant_value: Variant in resolution.initiative_totals_by_unit_id.keys():
			var participant_id := StringName(participant_value)
			if not participant_ids.has(participant_id):
				participant_ids.append(participant_id)
	for participant_id: StringName in participant_ids:
		var participant: TacticalUnitState = _state_store.state.get_unit(
			participant_id
		)
		if participant != null:
			budget_snapshots.append(_budget_snapshot(participant))
	snapshot["budgets"] = budget_snapshots
	return snapshot


func _affected_squad_ids_for_resolutions(
		resolutions: Array[TacticalDetectionResolution]
) -> Array[StringName]:
	var result: Array[StringName] = []
	for resolution: TacticalDetectionResolution in resolutions:
		if resolution == null:
			continue
		for squad_id: StringName in resolution.detected_squad_ids:
			_append_unique(result, squad_id)
		for squad_id: StringName in resolution.newly_aware_squad_ids:
			_append_unique(result, squad_id)
		for squad_id: StringName in resolution.revealed_at_destination_squad_ids:
			_append_unique(result, squad_id)
		for squad_id: StringName in resolution.lost_sight_squad_ids:
			_append_unique(result, squad_id)
		for squad_value: Variant in resolution.last_seen_tile_by_squad_id.keys():
			_append_unique(result, StringName(squad_value))
	return result


func _append_unique(values: Array[StringName], value: StringName) -> void:
	if not value.is_empty() and not values.has(value):
		values.append(value)


func restore_snapshot(snapshot: Dictionary) -> void:
	_state_store.state.phase_state.restore(snapshot.get("phase", {}))
	_restore_unit_snapshots(snapshot.get("units", {}))
	_restore_squad_snapshots(snapshot.get("squads", {}))
	for budget_value: Variant in snapshot.get("budgets", []):
		if budget_value is Dictionary:
			_restore_budget_snapshot(budget_value)


func _restore_unit_snapshots(snapshot_value: Variant) -> void:
	if not (snapshot_value is Dictionary):
		return
	var unit_snapshots: Dictionary = snapshot_value
	for unit_value: Variant in unit_snapshots.keys():
		var unit: TacticalUnitState = _state_store.state.get_unit(
			StringName(unit_value)
		)
		var unit_snapshot_value: Variant = unit_snapshots[unit_value]
		if unit == null or not (unit_snapshot_value is Dictionary):
			continue
		var unit_snapshot: Dictionary = unit_snapshot_value
		unit.stealth_enabled = bool(
			unit_snapshot.get("stealth_enabled", false)
		)
		unit.current_stealth_roll_valid = bool(
			unit_snapshot.get("stealth_roll_valid", false)
		)
		unit.current_stealth_roll_value = int(
			unit_snapshot.get("stealth_roll_value", 0)
		)
		unit.current_stealth_total = int(
			unit_snapshot.get("stealth_total", 0)
		)
		unit.revealed_to_squad_ids.clear()
		for squad_value: Variant in unit_snapshot.get("revealed", []):
			unit.revealed_to_squad_ids.append(StringName(squad_value))


func _restore_squad_snapshots(snapshot_value: Variant) -> void:
	if not (snapshot_value is Dictionary):
		return
	var squad_snapshots: Dictionary = snapshot_value
	for squad_value: Variant in squad_snapshots.keys():
		var squad: TacticalSquadState = _state_store.state.get_squad(
			StringName(squad_value)
		)
		var squad_snapshot_value: Variant = squad_snapshots[squad_value]
		if squad == null or not (squad_snapshot_value is Dictionary):
			continue
		var squad_snapshot: Dictionary = squad_snapshot_value
		squad.awareness = StringName(
			squad_snapshot.get(
				"awareness",
				TacticalSquadState.AWARENESS_UNAWARE
			)
		)
		var last_seen_value: Variant = squad_snapshot.get("last_seen", {})
		squad.last_seen_positions_by_unit_id = (
			last_seen_value.duplicate(true)
			if last_seen_value is Dictionary
			else {}
		)
		squad.search_rounds_remaining = maxi(0, int(
			squad_snapshot.get("search_rounds", 0)
		))


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
	var unit: TacticalUnitState = _state_store.state.get_unit(
		StringName(snapshot.get("unit_id", &""))
	)
	if unit == null:
		return
	unit.action_budget.remaining_turn_capacity_feet = int(
		snapshot.get("remaining", 0)
	)
	unit.action_budget.normal_capacity_spent_feet = int(
		snapshot.get("spent", 0)
	)
	unit.action_budget.quick_action_available = bool(snapshot.get("quick", true))
	unit.action_budget.restore_reaction_snapshot(snapshot.get("reaction", {}))
	unit.action_budget.ordinary_attack_available = bool(
		snapshot.get("ordinary_attack", true)
	)
	unit.action_budget.ended_activation = bool(snapshot.get("ended", false))
	unit.diagonal_steps_used = int(snapshot.get("diagonal", 0))
