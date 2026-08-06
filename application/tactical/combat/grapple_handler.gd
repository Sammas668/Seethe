class_name GrappleHandler
extends RefCounted

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _event_journal: RefCounted
var _dice_roller: TacticalDiceRoller


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		event_journal: RefCounted,
		dice_roller: TacticalDiceRoller
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_event_journal = event_journal
	_dice_roller = dice_roller


func unavailable_reason(actor_id: StringName, target_id: StringName) -> String:
	var actor: TacticalUnitState = _state_store.state.get_unit(actor_id)
	var target: TacticalUnitState = _state_store.state.get_unit(target_id)
	if actor == null or target == null:
		return "The grappler or target is missing."
	if actor.unit_id == target.unit_id:
		return "A unit cannot Grapple itself."
	if not TacticalTeamRelations.are_hostile(actor.team_id, target.team_id):
		return "Grapple currently requires a hostile target."
	if not actor.can_take_actions() or not target.can_take_actions():
		return "Both characters must be able to resist the Grapple."
	if actor.is_grappled() or actor.is_grappling():
		return "This character is already involved in a Grapple."
	if target.is_grappled() or target.is_grappling():
		return "The target is already involved in a Grapple."
	if not TacticalMeleeReachRules.can_reach(
		_state_store.state.occupied_cells_for_unit(actor),
		_state_store.state.occupied_cells_for_unit(target),
		_map_definition,
		5
	):
		return "Grapple requires an adjacent target with a legal melee path."
	return ActionEconomyRules.unavailable_reason(actor, ActionCost.half_action())


func initiate(actor_id: StringName, target_id: StringName) -> OperationResult:
	var reason: String = unavailable_reason(actor_id, target_id)
	if not reason.is_empty():
		return OperationResult.fail(&"grapple_unavailable", reason)
	var actor: TacticalUnitState = _state_store.state.get_unit(actor_id)
	var target: TacticalUnitState = _state_store.state.get_unit(target_id)
	var dice_before: Dictionary = _dice_roller.snapshot_state()
	var actor_budget_before: Dictionary = _budget_snapshot(actor)
	var actor_life_before: Dictionary = actor.life_state_snapshot()
	var target_life_before: Dictionary = target.life_state_snapshot()
	var actor_roll: int = _dice_roller.roll_die(20)
	var actor_bonus: int = actor.resolved_character.stat_value(&"grapple", 0)
	var target_defence: int = target.resolved_character.stat_value(
		&"manoeuvre_defence", 10
	)
	var actor_total: int = actor_roll + actor_bonus
	var success: bool = actor_total >= target_defence

	var changes := TacticalChangeSet.new(
		&"grapple_resolved",
		_state_store.state.revision,
		TacticalInvalidationContract.body_action(
			actor.unit_id, target.unit_id, [], false, false, false, target.team_id
		)
	)
	changes.stage(
		Callable(self, "_spend_half_action").bind(actor),
		Callable(self, "_restore_budget").bind(actor, actor_budget_before),
		"The Grapple action cost could not be paid."
	)
	if success:
		changes.stage(
			Callable(self, "_apply_grapple_pair").bind(actor, target),
			Callable(self, "_restore_pair").bind(
				actor, actor_life_before, target, target_life_before
			),
			"The Grapple state could not be applied."
		)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		_dice_roller.restore_state(dice_before)
		return committed
	_record_event(actor, target, actor_roll, actor_bonus, target_defence, success)
	return OperationResult.ok(
		target,
		("%s Grappled %s." if success else "%s failed to Grapple %s.")
		% [actor.display_name, target.display_name]
	)


func release(actor_id: StringName) -> OperationResult:
	var actor: TacticalUnitState = _state_store.state.get_unit(actor_id)
	if actor == null or actor.grappling_target_unit_id.is_empty():
		return OperationResult.fail(
			&"grapple_release_missing",
			"This character is not controlling a Grapple."
		)
	var target: TacticalUnitState = _state_store.state.get_unit(
		actor.grappling_target_unit_id
	)
	if target == null:
		return OperationResult.fail(
			&"grapple_target_missing", "The Grapple target is missing."
		)
	return _clear_pair(
		actor,
		target,
		&"grapple_released",
		"%s released %s." % [actor.display_name, target.display_name]
	)


func break_hold(target_id: StringName) -> OperationResult:
	var target: TacticalUnitState = _state_store.state.get_unit(target_id)
	if target == null or target.grappled_by_unit_id.is_empty():
		return OperationResult.fail(
			&"break_hold_missing", "This character is not Grappled."
		)
	var actor: TacticalUnitState = _state_store.state.get_unit(
		target.grappled_by_unit_id
	)
	if actor == null:
		return OperationResult.fail(
			&"grappler_missing", "The controlling grappler is missing."
		)
	var unavailable: String = ActionEconomyRules.unavailable_reason(
		target, ActionCost.half_action()
	)
	if not unavailable.is_empty():
		return OperationResult.fail(&"break_hold_unavailable", unavailable)
	var dice_before: Dictionary = _dice_roller.snapshot_state()
	var target_roll: int = _dice_roller.roll_die(20)
	var target_total: int = target_roll + target.resolved_character.stat_value(
		&"grapple", 0
	)
	var actor_defence: int = actor.resolved_character.stat_value(
		&"manoeuvre_defence", 10
	)
	var budget_before: Dictionary = _budget_snapshot(target)
	var actor_before: Dictionary = actor.life_state_snapshot()
	var target_before: Dictionary = target.life_state_snapshot()
	var success: bool = target_total >= actor_defence
	var changes := TacticalChangeSet.new(
		&"grapple_break_attempted",
		_state_store.state.revision,
		TacticalInvalidationContract.body_action(
			target.unit_id, actor.unit_id, [], false
		)
	)
	changes.stage(
		Callable(self, "_spend_half_action").bind(target),
		Callable(self, "_restore_budget").bind(target, budget_before),
		"Break Hold could not spend its action."
	)
	if success:
		changes.stage(
			Callable(self, "_clear_grapple_pair").bind(actor, target),
			Callable(self, "_restore_pair").bind(
				actor, actor_before, target, target_before
			),
			"The Grapple could not be cleared."
		)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		_dice_roller.restore_state(dice_before)
		return committed
	return OperationResult.ok(
		target,
		"Break Hold succeeded." if success else "Break Hold failed."
	)


func _clear_pair(
		actor: TacticalUnitState,
		target: TacticalUnitState,
		reason: StringName,
		message: String
) -> OperationResult:
	var actor_before: Dictionary = actor.life_state_snapshot()
	var target_before: Dictionary = target.life_state_snapshot()
	var changes := TacticalChangeSet.new(
		reason,
		_state_store.state.revision,
		TacticalInvalidationContract.body_action(
			actor.unit_id, target.unit_id, [], false
		)
	)
	changes.stage(
		Callable(self, "_clear_grapple_pair").bind(actor, target),
		Callable(self, "_restore_pair").bind(
			actor, actor_before, target, target_before
		),
		"The Grapple could not be released."
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	return OperationResult.ok(target, message)


func _spend_half_action(unit: TacticalUnitState) -> bool:
	return ActionEconomyRules.spend(unit, ActionCost.half_action()) >= 0


func _budget_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"ordinary": unit.action_budget.ordinary_attack_available,
		"ended": unit.action_budget.ended_activation,
	}


func _restore_budget(unit: TacticalUnitState, snapshot: Dictionary) -> void:
	unit.action_budget.remaining_turn_capacity_feet = int(
		snapshot.get("remaining", unit.action_budget.remaining_turn_capacity_feet)
	)
	unit.action_budget.normal_capacity_spent_feet = int(
		snapshot.get("spent", unit.action_budget.normal_capacity_spent_feet)
	)
	unit.action_budget.quick_action_available = bool(
		snapshot.get("quick", unit.action_budget.quick_action_available)
	)
	unit.action_budget.ordinary_attack_available = bool(
		snapshot.get("ordinary", unit.action_budget.ordinary_attack_available)
	)
	unit.action_budget.ended_activation = bool(
		snapshot.get("ended", unit.action_budget.ended_activation)
	)


func _apply_grapple_pair(
		actor: TacticalUnitState,
		target: TacticalUnitState
) -> bool:
	if not actor.apply_grapple(actor.unit_id, target.unit_id):
		return false
	if not target.apply_grapple(actor.unit_id, target.unit_id):
		actor.clear_grapple()
		return false
	return (
		actor.grappling_target_unit_id == target.unit_id
		and target.grappled_by_unit_id == actor.unit_id
	)


func _clear_grapple_pair(
		actor: TacticalUnitState,
		target: TacticalUnitState
) -> bool:
	actor.clear_grapple()
	target.clear_grapple()
	return true


func _restore_pair(
		actor: TacticalUnitState,
		actor_snapshot: Dictionary,
		target: TacticalUnitState,
		target_snapshot: Dictionary
) -> void:
	actor.restore_life_state(actor_snapshot)
	target.restore_life_state(target_snapshot)


func _record_event(
		actor: TacticalUnitState,
		target: TacticalUnitState,
		actor_roll: int,
		actor_bonus: int,
		target_defence: int,
		success: bool
) -> void:
	if _event_journal == null:
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"grapple_resolved",
		phase.round_number,
		phase.current_phase,
		("%s Grappled %s." if success else "%s failed to Grapple %s.")
		% [actor.display_name, target.display_name],
		{
			"category": &"combat",
			"source_actor_id": actor.unit_id,
			"target_actor_ids": [target.unit_id],
			"details": [
				"Grapple: d20 %d %+d = %d"
				% [actor_roll, actor_bonus, actor_roll + actor_bonus],
				"Target Manoeuvre Defence: %d" % target_defence,
			],
		}
	)
