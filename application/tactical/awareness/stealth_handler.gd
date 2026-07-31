class_name StealthHandler
extends RefCounted

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _event_journal: RefCounted
var _detection_service: TacticalDetectionService
var _dice_roller: TacticalDiceRoller


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		event_journal_value: RefCounted,
		detection_service: TacticalDetectionService,
		dice_roller: TacticalDiceRoller = null
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_event_journal = event_journal_value
	_detection_service = detection_service
	_dice_roller = dice_roller


func unavailable_reason(unit_id: StringName) -> String:
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return "The selected unit does not exist."
	if not unit.is_player_controlled():
		return "Only player-controlled units can enter Stealth."
	if not _state_store.state.can_player_unit_act(unit_id):
		return "This unit is not currently active."
	if unit.stealth_enabled and unit.shows_hidden_badge():
		return "This unit is already in Stealth."
	if not unit.action_budget.quick_action_available:
		return "The Quick Action has already been spent."
	if not _detection_service.can_enter_stealth(unit_id):
		return "Break every guard's current line of perception before entering Stealth."
	return ""


func enter_stealth(unit_id: StringName) -> OperationResult:
	var unavailable: String = unavailable_reason(unit_id)
	if not unavailable.is_empty():
		return OperationResult.fail(&"stealth_unavailable", unavailable)
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	var quick_before: bool = unit.action_budget.quick_action_available
	var stealth_before: bool = unit.stealth_enabled
	var roll_valid_before: bool = unit.current_stealth_roll_valid
	var roll_value_before: int = unit.current_stealth_roll_value
	var roll_total_before: int = unit.current_stealth_total
	var dice_snapshot: Dictionary = (
		_dice_roller.snapshot_state() if _dice_roller != null else {}
	)
	var stealth_roll: int = (
		_dice_roller.roll_die(20) if _dice_roller != null else 10
	)
	var stealth_total: int = stealth_roll + unit.stealth_bonus()
	var revealed_before: Array[StringName] = unit.revealed_to_squad_ids.duplicate()
	var last_seen_before: Dictionary = {}
	for squad: TacticalSquadState in _state_store.state.get_squads():
		last_seen_before[squad.squad_id] = (
			squad.last_seen_positions_by_unit_id.duplicate(true)
		)
	var changes := TacticalChangeSet.new(
		&"unit_entered_stealth",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_apply_stealth").bind(
			unit,
			stealth_roll,
			stealth_total
		),
		Callable(self, "_restore_stealth").bind(
			unit,
			stealth_before,
			quick_before,
			roll_valid_before,
			roll_value_before,
			roll_total_before,
			revealed_before,
			last_seen_before
		),
		"Stealth could not be entered.",
		&"stealth_commit_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		if _dice_roller != null:
			_dice_roller.restore_state(dice_snapshot)
		return committed
	_record_event(
		&"stealth_entered",
		"%s entered Stealth." % unit.display_name,
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"action_id": &"action.enter_stealth",
			"details": [
				"Raw d20: %d" % stealth_roll,
				"Stealth modifier: %+d" % unit.stealth_bonus(),
				"Current Stealth total: %d" % stealth_total,
				"Cost: Quick Action",
				"The unit is outside every guard's current perception.",
			],
		}
	)
	return OperationResult.ok(null, "%s entered Stealth." % unit.display_name)


func _apply_stealth(
		unit: TacticalUnitState,
		raw_roll: int,
		total: int
) -> bool:
	# Re-entering Stealth after detection is legal once the unit has broken all
	# current perception. The squad keeps the last position it actually saw;
	# only the exact live position is removed from its target knowledge.
	for squad_id: StringName in unit.revealed_to_squad_ids.duplicate():
		var squad: TacticalSquadState = _state_store.state.get_squad(squad_id)
		if squad != null and not squad.has_last_seen_position(unit.unit_id):
			squad.remember_last_seen(unit.unit_id, unit.grid_position)
		unit.conceal_from_squad(squad_id)
	unit.enter_stealth()
	unit.set_current_stealth_roll(raw_roll, total)
	unit.action_budget.spend_quick_action()
	return true


func _restore_stealth(
		unit: TacticalUnitState,
		stealth_before: bool,
		quick_before: bool,
		roll_valid_before: bool,
		roll_value_before: int,
		roll_total_before: int,
		revealed_before: Array[StringName],
		last_seen_before: Dictionary
) -> void:
	unit.stealth_enabled = stealth_before
	unit.current_stealth_roll_valid = roll_valid_before
	unit.current_stealth_roll_value = roll_value_before
	unit.current_stealth_total = roll_total_before
	unit.action_budget.quick_action_available = quick_before
	unit.revealed_to_squad_ids = revealed_before.duplicate()
	for squad_value: Variant in last_seen_before.keys():
		var squad: TacticalSquadState = _state_store.state.get_squad(
			StringName(squad_value)
		)
		var memory_value: Variant = last_seen_before[squad_value]
		if squad != null and memory_value is Dictionary:
			squad.last_seen_positions_by_unit_id = memory_value.duplicate(true)


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
