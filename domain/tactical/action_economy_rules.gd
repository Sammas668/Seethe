class_name ActionEconomyRules
extends RefCounted


static func unavailable_reason(unit: TacticalUnitState, cost: ActionCost) -> String:
	if unit == null:
		return "No unit is selected."
	if cost == null:
		return "The action has no valid cost."
	if unit.is_defeated():
		return "Defeated units cannot take actions."

	var budget := unit.action_budget
	if budget.ended_activation:
		return "This unit is marked as ended. Reactivate it before acting."

	if cost.is_quick_action():
		if not budget.quick_action_available:
			return "The unit has already used its Quick Action this round."
		return ""

	var required_feet := cost.resolved_normal_capacity_feet(
		budget.maximum_turn_capacity_feet
	)

	if cost.category == ActionCost.Category.FULL and budget.has_spent_normal_capacity():
		return "A Full Action requires the unit to have spent no normal capacity this turn."

	if required_feet > budget.remaining_turn_capacity_feet:
		return (
			"This action costs %d ft, but only %d ft remain."
			% [required_feet, budget.remaining_turn_capacity_feet]
		)

	return ""


static func attack_unavailable_reason(
		unit: TacticalUnitState,
		attack: AttackDefinition
) -> String:
	if attack == null:
		return "The attack definition is missing."
	var reason: String = unavailable_reason(unit, attack.resolved_cost())
	if not reason.is_empty():
		return reason
	if (
		attack.attack_sequence_kind == AttackDefinition.SEQUENCE_NORMAL
		and not unit.action_budget.ordinary_attack_available
	):
		return (
			"This unit has already made its normal attack this activation. "
			+ "Only a Full Attack can make multiple attacks."
		)
	return ""


static func can_spend(unit: TacticalUnitState, cost: ActionCost) -> bool:
	return unavailable_reason(unit, cost).is_empty()


static func spend_attack(
		unit: TacticalUnitState,
		attack: AttackDefinition
) -> int:
	var reason: String = attack_unavailable_reason(unit, attack)
	if not reason.is_empty():
		return -1
	var spent: int = spend(unit, attack.resolved_cost())
	if spent >= 0 and attack.attack_sequence_kind == AttackDefinition.SEQUENCE_NORMAL:
		unit.action_budget.spend_ordinary_attack()
	return spent


static func spend(unit: TacticalUnitState, cost: ActionCost) -> int:
	var reason := unavailable_reason(unit, cost)
	if not reason.is_empty():
		return -1

	if cost.is_quick_action():
		unit.action_budget.spend_quick_action()
		return 0

	var required_feet := cost.resolved_normal_capacity_feet(
		unit.action_budget.maximum_turn_capacity_feet
	)
	unit.action_budget.spend_normal_capacity(required_feet)
	return required_feet
