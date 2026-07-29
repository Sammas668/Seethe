class_name SpendActionHandler
extends RefCounted

var _state_store: TacticalStateStore
var _event_journal: RefCounted


func _init(
		state_store: TacticalStateStore,
		event_journal_value: RefCounted = null
) -> void:
	_state_store = state_store
	_event_journal = event_journal_value


func execute(command: SpendActionCommand) -> OperationResult:
	if not _state_store.state.phase_state.is_player_phase():
		return OperationResult.fail(
			&"wrong_phase",
			"Actions are unavailable outside the Player Phase."
		)

	var unit: TacticalUnitState = _state_store.state.get_unit(command.unit_id)
	if unit == null:
		return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")

	var reason: String = ActionEconomyRules.unavailable_reason(
		unit,
		command.action_cost
	)
	if not reason.is_empty():
		return OperationResult.fail(&"action_unavailable", reason)

	var budget_snapshot: Dictionary = _budget_snapshot(unit)
	var spent_result: Dictionary = {"value": -1}
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"action_spent",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_apply_action_cost").bind(
			unit,
			command.action_cost,
			spent_result
		),
		Callable(self, "_restore_budget").bind(unit, budget_snapshot),
		"The action cost could not be paid for.",
		&"action_failed"
	)
	var committed: OperationResult = _state_store.commit(changes)
	if not committed.success:
		return committed

	var spent_feet: int = int(spent_result.get("value", 0))
	var capacity_before: int = int(budget_snapshot.get("remaining", 0))
	var quick_before: bool = bool(budget_snapshot.get("quick", true))
	var cost_label: String = _cost_label(
		command.action_cost,
		spent_feet
	)
	_record_event(
		&"action_spent",
		"%s used %s."
		% [unit.display_name, command.action_name],
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"details": [
				"Action: %s" % command.action_name,
				"Cost: %s" % cost_label,
				"Capacity: %d → %d ft"
				% [
					capacity_before,
					unit.action_budget.remaining_turn_capacity_feet,
				],
				"Quick Action: %s → %s"
				% [
					"Ready" if quick_before else "Spent",
					(
						"Ready"
						if unit.action_budget.quick_action_available
						else "Spent"
					),
				],
			],
			"resource_changes": [
				{
					"resource": &"normal_capacity",
					"before": capacity_before,
					"after": unit.action_budget.remaining_turn_capacity_feet,
				},
				{
					"resource": &"quick_action",
					"before": quick_before,
					"after": unit.action_budget.quick_action_available,
				},
			],
		}
	)

	if command.action_cost.is_quick_action():
		return OperationResult.ok(
			spent_feet,
			"%s used. The unit's normal capacity is unchanged."
			% command.action_name
		)

	return OperationResult.ok(
		spent_feet,
		"%s used for %d ft. %d ft remain."
		% [
			command.action_name,
			spent_feet,
			unit.action_budget.remaining_turn_capacity_feet,
		]
	)


func _budget_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"reaction": unit.action_budget.reaction_available,
		"ended": unit.action_budget.ended_activation,
	}


func _apply_action_cost(
		unit: TacticalUnitState,
		action_cost: ActionCost,
		spent_result: Dictionary
) -> bool:
	var spent_feet: int = ActionEconomyRules.spend(unit, action_cost)
	spent_result["value"] = spent_feet
	return spent_feet >= 0


func _restore_budget(
		unit: TacticalUnitState,
		snapshot: Dictionary
) -> void:
	unit.action_budget.remaining_turn_capacity_feet = int(snapshot["remaining"])
	unit.action_budget.normal_capacity_spent_feet = int(snapshot["spent"])
	unit.action_budget.quick_action_available = bool(snapshot["quick"])
	unit.action_budget.reaction_available = bool(snapshot["reaction"])
	unit.action_budget.ended_activation = bool(snapshot["ended"])


func _cost_label(action_cost: ActionCost, spent_feet: int) -> String:
	if action_cost == null:
		return "Unknown"
	if action_cost.is_quick_action():
		return "Quick Action"
	if spent_feet <= 0:
		return "Free"
	return "%d ft" % spent_feet


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
