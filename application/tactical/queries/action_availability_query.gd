class_name ActionAvailabilityQuery
extends RefCounted

var _state_store: TacticalStateStore
var _catalogue: ContentCatalogue


func _init() -> void:
	pass


func configure(
		state_store: TacticalStateStore,
		catalogue: ContentCatalogue
) -> void:
	_state_store = state_store
	_catalogue = catalogue


func unavailable_reason(
		unit_id: StringName,
		action_id: StringName
) -> String:
	if _state_store == null:
		return "Tactical state is unavailable."
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return "Select a unit first."
	if not _state_store.state.can_unit_act(unit_id):
		return "This unit is not active in the current turn mode."
	var definition: ActionDefinition = (
		_catalogue.action_definition(action_id)
		if _catalogue != null
		else null
	)
	if definition is AttackDefinition:
		return ActionEconomyRules.attack_unavailable_reason(
			unit,
			definition as AttackDefinition
		)
	var cost: ActionCost = cost_for_action(action_id)
	if cost == null:
		return "This action is not yet executable."
	return ActionEconomyRules.unavailable_reason(unit, cost)


func cost_for_action(action_id: StringName) -> ActionCost:
	if _catalogue != null:
		var definition: ActionDefinition = _catalogue.action_definition(action_id)
		if definition != null:
			return definition.resolved_cost()
	match action_id:
		&"ready_stance", &"rage_toggle":
			return ActionCost.quick_action()
		&"sprint":
			return ActionCost.full_action()
		&"disengage":
			return ActionCost.half_action()
		_:
			return null


func half_action_cost_feet(unit_id: StringName) -> int:
	if _state_store == null:
		return 0
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return 0
	return ActionCost.half_action().resolved_normal_capacity_feet(
		unit.action_budget.maximum_turn_capacity_feet
	)
