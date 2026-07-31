class_name TacticalLifeStateHandler
extends RefCounted

const TacticalGridDistance: Script = preload(
	"res://domain/tactical/tactical_grid_distance.gd"
)
const LIFE_STATE_RULES_SCRIPT: Script = preload(
	"res://domain/tactical/life/tactical_life_state_rules.gd"
)
const ROLL_RECORD_SCRIPT: Script = preload(
	"res://domain/tactical/events/tactical_roll_record.gd"
)
const MODIFIER_RECORD_SCRIPT: Script = preload(
	"res://domain/tactical/events/tactical_modifier_record.gd"
)
const EFFECT_RECORD_SCRIPT: Script = preload(
	"res://domain/tactical/events/tactical_effect_record.gd"
)

const FIRST_AID_DC: int = 10

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


func dying_check_unavailable_reason(unit_id: StringName) -> String:
	var unit: TacticalUnitState = _unit(unit_id)
	if unit == null:
		return "The Dying character is missing."
	if not _state_store.state.phase_state.is_initiative_combat():
		return "Dying checks resolve during initiative combat."
	if not _state_store.state.phase_state.is_active_unit(unit_id):
		return "The Dying check resolves at the start of this character's turn."
	if not unit.is_dying():
		return "This character is not Dying."
	if unit.last_dying_check_round >= _state_store.state.phase_state.round_number:
		return "This character has already made its Dying check this round."
	return ""


func resolve_dying_check(unit_id: StringName) -> OperationResult:
	var reason: String = dying_check_unavailable_reason(unit_id)
	if not reason.is_empty():
		return OperationResult.fail(&"dying_check_unavailable", reason)
	if _dice_roller == null:
		return OperationResult.fail(&"dice_missing", "The tactical dice roller is unavailable.")

	var unit: TacticalUnitState = _unit(unit_id)
	var phase: TacticalPhaseState = _state_store.state.phase_state
	var dc: int = unit.dying_check_dc()
	var modifier: int = unit.fortitude_bonus()
	var required_roll: int = int(LIFE_STATE_RULES_SCRIPT.call(
		"required_natural_roll", dc, modifier
	))
	var dice_checkpoint: Dictionary = _dice_roller.snapshot_state()
	var raw_roll: int = _dice_roller.roll_die(20)
	var total: int = raw_roll + modifier
	var natural_twenty: bool = raw_roll == 20
	var natural_one: bool = raw_roll == 1
	var success: bool = natural_twenty or (not natural_one and total >= dc)
	var successes_gained: int = 2 if natural_twenty else (1 if success else 0)
	var failures_gained: int = 2 if natural_one else (0 if success else 1)
	var before: Dictionary = unit.life_state_snapshot()

	var changes := TacticalChangeSet.new(
		&"dying_check_resolved",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_apply_dying_check").bind(
			unit,
			phase.round_number,
			natural_twenty,
			successes_gained,
			failures_gained
		),
		Callable(unit, "restore_life_state").bind(before),
		"The Dying check result could not be applied.",
		&"dying_check_apply_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		_dice_roller.restore_state(dice_checkpoint)
		return committed

	_record_dying_check(
		unit,
		raw_roll,
		modifier,
		total,
		dc,
		required_roll,
		success,
		natural_twenty,
		natural_one,
		before
	)
	return OperationResult.ok(
		{
			"unit_id": unit.unit_id,
			"raw_roll": raw_roll,
			"modifier": modifier,
			"total": total,
			"dc": dc,
			"required_roll": required_roll,
			"success": success,
			"life_state": unit.life_state_id(),
		},
		_dying_result_message(unit, success)
	)


func first_aid_unavailable_reason(
		actor_id: StringName,
		target_id: StringName,
		medical_item_id: StringName = &""
) -> String:
	var actor: TacticalUnitState = _unit(actor_id)
	var target: TacticalUnitState = _unit(target_id)
	if actor == null:
		return "The acting character is missing."
	if target == null:
		return "Choose a Dying character to treat."
	if not _state_store.state.can_unit_act(actor_id):
		return "This character cannot act in the current turn."
	if not target.is_dying():
		return "First Aid can only stabilise a Dying character."
	if actor.unit_id == target.unit_id:
		return "A Dying character cannot treat themselves."
	var body_item: TacticalItemInstanceState = _state_store.state.body_item_for_unit(
		target.unit_id
	)
	if (
		body_item == null
		or not _state_store.state.body_is_accessible_to_unit(body_item, actor)
	):
		return "First Aid requires an accessible Dying body."
	if not medical_item_id.is_empty():
		var medical_item: TacticalItemInstanceState = _state_store.state.get_item(
			medical_item_id
		)
		if (
			medical_item == null
			or medical_item.definition == null
			or not medical_item.definition.permits_first_aid
		):
			return "That item cannot be used for First Aid."
		if not _item_is_usable_by_actor(medical_item, actor):
			return "The selected medical item is outside the acting character's reach."
	var cost_reason: String = ActionEconomyRules.unavailable_reason(
		actor,
		ActionCost.half_action()
	)
	return cost_reason


func first_aid(
		actor_id: StringName,
		target_id: StringName,
		medical_item_id: StringName = &""
) -> OperationResult:
	var reason: String = first_aid_unavailable_reason(
		actor_id, target_id, medical_item_id
	)
	if not reason.is_empty():
		return OperationResult.fail(&"first_aid_unavailable", reason)
	if _dice_roller == null:
		return OperationResult.fail(&"dice_missing", "The tactical dice roller is unavailable.")

	var actor: TacticalUnitState = _unit(actor_id)
	var target: TacticalUnitState = _unit(target_id)
	var medical_item: TacticalItemInstanceState = (
		_state_store.state.get_item(medical_item_id)
		if not medical_item_id.is_empty()
		else null
	)
	var item_bonus: int = (
		medical_item.definition.first_aid_bonus
		if medical_item != null and medical_item.definition != null
		else 0
	)
	var modifier: int = actor.medicine_bonus() + item_bonus
	# First Aid is an ordinary 3.5-style skill check: natural 1 and natural 20
	# are not automatic results. Only the Dying check uses special natural rolls.
	var required_roll: int = clampi(FIRST_AID_DC - modifier, 1, 20)
	var dice_checkpoint: Dictionary = _dice_roller.snapshot_state()
	var raw_roll: int = _dice_roller.roll_die(20)
	var total: int = raw_roll + modifier
	var success: bool = total >= FIRST_AID_DC
	var actor_budget_before: Dictionary = _budget_snapshot(actor)
	var actor_life_before: Dictionary = actor.life_state_snapshot()
	var target_life_before: Dictionary = target.life_state_snapshot()
	var actor_was_disabled: bool = actor.is_disabled()
	var medical_quantity_before: int = medical_item.quantity if medical_item != null else 0
	var medical_location_before: TacticalItemLocationState = (
		medical_item.location.clone() if medical_item != null else null
	)

	var changes := TacticalChangeSet.new(
		&"first_aid_resolved",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_spend_first_aid").bind(actor, actor_was_disabled),
		Callable(self, "_restore_actor_after_first_aid").bind(
			actor,
			actor_budget_before,
			actor_life_before
		),
		"The First Aid action cost could not be paid.",
		&"first_aid_cost_failed"
	)
	if medical_item != null:
		changes.stage(
			Callable(self, "_consume_item_use").bind(
				medical_item, medical_item.definition.first_aid_uses_consumed
			),
			Callable(self, "_restore_item_use").bind(
				medical_item, medical_quantity_before, medical_location_before
			),
			"The medical item could not be consumed.",
			&"first_aid_item_consume_failed"
		)
	if success:
		changes.stage(
			Callable(self, "_stabilise_target").bind(target),
			Callable(target, "restore_life_state").bind(target_life_before),
			"The Dying character could not be stabilised.",
			&"first_aid_stabilise_failed"
		)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		_dice_roller.restore_state(dice_checkpoint)
		return committed

	_record_first_aid(
		actor,
		target,
		raw_roll,
		modifier,
		total,
		required_roll,
		success,
		target_life_before,
		actor_budget_before
	)
	return OperationResult.ok(
		{
			"actor_id": actor.unit_id,
			"target_id": target.unit_id,
			"success": success,
			"raw_roll": raw_roll,
			"total": total,
			"medical_item_id": medical_item_id,
			"item_bonus": item_bonus,
		},
		(
			"%s stabilised %s."
			% [actor.display_name, target.display_name]
			if success
			else "%s failed to stabilise %s."
			% [actor.display_name, target.display_name]
		)
	)


func administer_healing_item(
		actor_id: StringName,
		target_id: StringName,
		item_id: StringName
) -> OperationResult:
	var actor: TacticalUnitState = _unit(actor_id)
	var target: TacticalUnitState = _unit(target_id)
	var item: TacticalItemInstanceState = _state_store.state.get_item(item_id)
	if actor == null or target == null:
		return OperationResult.fail(&"healing_actor_missing", "The actor or target is missing.")
	if target.is_dead():
		return OperationResult.fail(&"target_dead", "Ordinary healing cannot restore a dead character.")
	if (
		item == null
		or item.definition == null
		or not item.definition.permits_administered_healing
		or item.definition.healing_amount <= 0
	):
		return OperationResult.fail(&"healing_item_invalid", "That item cannot be administered as healing.")
	var body_item: TacticalItemInstanceState = _state_store.state.body_item_for_unit(target_id)
	if body_item == null or not _state_store.state.body_is_accessible_to_unit(body_item, actor):
		return OperationResult.fail(&"body_outside_reach", "The body is outside the acting character's reach.")
	if not _item_is_usable_by_actor(item, actor):
		return OperationResult.fail(&"healing_item_outside_reach", "The healing item is outside reach.")
	var cost_reason: String = ActionEconomyRules.unavailable_reason(
		actor, ActionCost.half_action()
	)
	if not cost_reason.is_empty():
		return OperationResult.fail(&"healing_action_unavailable", cost_reason)

	var actor_budget_before: Dictionary = _budget_snapshot(actor)
	var actor_life_before: Dictionary = actor.life_state_snapshot()
	var target_before: Dictionary = target.life_state_snapshot()
	var quantity_before: int = item.quantity
	var location_before: TacticalItemLocationState = item.location.clone()
	var changes := TacticalChangeSet.new(
		&"healing_item_administered", _state_store.state.revision
	)
	changes.stage(
		Callable(self, "_spend_first_aid").bind(actor, actor.is_disabled()),
		Callable(self, "_restore_actor_after_first_aid").bind(
			actor, actor_budget_before, actor_life_before
		),
		"The administered healing action cost could not be paid."
	)
	changes.stage(
		Callable(self, "_consume_item_use").bind(item, 1),
		Callable(self, "_restore_item_use").bind(item, quantity_before, location_before),
		"The healing item could not be consumed."
	)
	changes.stage(
		Callable(self, "_apply_healing_amount").bind(
			target, item.definition.healing_amount
		),
		Callable(target, "restore_life_state").bind(target_before),
		"The healing effect could not be applied."
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	_record_healing(target, item.definition.healing_amount, item.definition_id, target_before)
	return OperationResult.ok(
		{
			"actor_id": actor_id,
			"target_id": target_id,
			"item_id": item_id,
			"amount": item.definition.healing_amount,
		},
		"%s administered %s to %s." % [
			actor.display_name, item.display_name, target.display_name
		]
	)


func apply_healing(
		target_id: StringName,
		amount: int,
		source_id: StringName = &""
) -> OperationResult:
	var target: TacticalUnitState = _unit(target_id)
	if target == null:
		return OperationResult.fail(&"healing_target_missing", "The healing target is missing.")
	if amount <= 0:
		return OperationResult.fail(&"healing_amount_invalid", "Healing must be greater than zero.")
	if target.is_dead():
		return OperationResult.fail(&"target_dead", "Ordinary healing cannot restore a dead character.")

	var before: Dictionary = target.life_state_snapshot()
	var changes := TacticalChangeSet.new(
		&"healing_applied",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_apply_healing_amount").bind(target, amount),
		Callable(target, "restore_life_state").bind(before),
		"Healing could not be applied.",
		&"healing_apply_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	_record_healing(target, amount, source_id, before)
	return OperationResult.ok(
		{
			"target_id": target.unit_id,
			"amount": amount,
			"hp_before": int(before.get("current_hp", 0)),
			"hp_after": target.current_hp,
			"life_state": target.life_state_id(),
		},
		"%s recovered %d HP." % [target.display_name, amount]
	)


func _apply_dying_check(
		unit: TacticalUnitState,
		round_number: int,
		natural_twenty: bool,
		successes_gained: int,
		failures_gained: int
) -> bool:
	unit.last_dying_check_round = round_number
	if natural_twenty:
		unit.add_dying_successes(successes_gained)
		if not unit.is_dead():
			unit.apply_healing(1)
		return true
	if successes_gained > 0:
		unit.add_dying_successes(successes_gained)
	elif failures_gained > 0:
		unit.add_dying_failures(failures_gained)
	return true


func _spend_first_aid(actor: TacticalUnitState, actor_was_disabled: bool) -> bool:
	if ActionEconomyRules.spend(actor, ActionCost.half_action()) < 0:
		return false
	if actor_was_disabled:
		actor.apply_disabled_strain()
	return true


func _stabilise_target(target: TacticalUnitState) -> bool:
	target.become_stable()
	return target.is_stable_unconscious()


func _apply_healing_amount(target: TacticalUnitState, amount: int) -> bool:
	return target.apply_healing(amount) > 0


func _restore_actor_after_first_aid(
		actor: TacticalUnitState,
		budget_snapshot: Dictionary,
		life_snapshot: Dictionary
) -> void:
	_restore_budget(actor, budget_snapshot)
	actor.restore_life_state(life_snapshot)


func _item_is_usable_by_actor(
		item: TacticalItemInstanceState,
		actor: TacticalUnitState
) -> bool:
	if item == null or actor == null or item.location == null:
		return false
	if item.location.owner_id == actor.unit_id:
		return true
	return _state_store.state.item_is_accessible_to_unit(item, actor)


func _consume_item_use(
		item: TacticalItemInstanceState,
		amount: int
) -> bool:
	if item == null or item.quantity < amount or amount < 1:
		return false
	item.quantity -= amount
	if item.quantity <= 0:
		item.quantity = 1
		item.location = TacticalItemLocationState.new(
			TacticalItemLocationState.LOCATION_DESTROYED
		)
	_state_store.state.rebuild_ground_item_index()
	return true


func _restore_item_use(
		item: TacticalItemInstanceState,
		quantity: int,
		location: TacticalItemLocationState
) -> void:
	if item == null:
		return
	item.quantity = quantity
	item.location = location.clone() if location != null else null
	_state_store.state.rebuild_ground_item_index()


func _minimum_distance_steps(
		actor: TacticalUnitState,
		target: TacticalUnitState
) -> int:
	return int(TacticalGridDistance.call(
		"minimum_steps_between_sets",
		_state_store.state.occupied_cells_for_unit(actor),
		_state_store.state.occupied_cells_for_unit(target)
	))


func _unit(unit_id: StringName) -> TacticalUnitState:
	if _state_store == null or _state_store.state == null:
		return null
	return _state_store.state.get_unit(unit_id)


func _budget_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"reaction": unit.action_budget.reaction_snapshot(),
		"ordinary_attack": unit.action_budget.ordinary_attack_available,
		"ended": unit.action_budget.ended_activation,
	}


func _restore_budget(unit: TacticalUnitState, snapshot: Dictionary) -> void:
	unit.action_budget.remaining_turn_capacity_feet = int(snapshot.get("remaining", 0))
	unit.action_budget.normal_capacity_spent_feet = int(snapshot.get("spent", 0))
	unit.action_budget.quick_action_available = bool(snapshot.get("quick", false))
	unit.action_budget.restore_reaction_snapshot(snapshot.get("reaction", {}))
	unit.action_budget.ordinary_attack_available = bool(
		snapshot.get("ordinary_attack", false)
	)
	unit.action_budget.ended_activation = bool(snapshot.get("ended", false))


func _record_dying_check(
		unit: TacticalUnitState,
		raw_roll: int,
		modifier: int,
		total: int,
		dc: int,
		required_roll: int,
		success: bool,
		natural_twenty: bool,
		natural_one: bool,
		before: Dictionary
) -> void:
	var successes_gained: int = 2 if natural_twenty else (1 if success else 0)
	var failures_gained: int = 2 if natural_one else (0 if success else 1)
	var resolved_successes: int = mini(
		3,
		int(before.get("dying_successes", 0)) + successes_gained
	)
	var resolved_failures: int = mini(
		3,
		int(before.get("dying_failures", 0)) + failures_gained
	)
	var details: Array[String] = [
		"HP: %d · Death threshold: %d" % [unit.current_hp, unit.death_threshold_hp()],
		"Required natural roll: %d+" % required_roll,
		"Dying track: %d/3 successes · %d/3 failures"
		% [resolved_successes, resolved_failures],
	]
	if natural_twenty:
		details.append("Natural 20: two successes and 1 HP restored.")
	elif natural_one:
		details.append("Natural 1: two failures.")
	if unit.is_stable_unconscious():
		details.append("Stable: the Dying track is now cleared.")
	elif unit.is_dead():
		details.append("Dead: the Dying track is complete.")

	_record_event(
		&"dying_check",
		"DYING CHECK — %s — %s."
		% [unit.display_name, "SUCCESS" if success else "FAILURE"],
		{
			"category": &"rolls",
			"source_actor_id": unit.unit_id,
			"details": details,
			"roll_records": [
				ROLL_RECORD_SCRIPT.call(
					"create",
					&"dying_check",
					"1d20",
					[raw_roll],
					total,
					dc,
					&"success" if success else &"failure",
					[
						MODIFIER_RECORD_SCRIPT.call(
							"create",
							"Fortitude",
							modifier,
							&"fortitude",
							&"saving_throw"
						),
					]
				),
			],
			"effect_records": [
				EFFECT_RECORD_SCRIPT.call(
					"create",
					"Dying successes",
					&"dying_successes",
					int(before.get("dying_successes", 0)),
					unit.dying_successes,
					&"rule.dying_check"
				),
				EFFECT_RECORD_SCRIPT.call(
					"create",
					"Dying failures",
					&"dying_failures",
					int(before.get("dying_failures", 0)),
					unit.dying_failures,
					&"rule.dying_check"
				),
			],
			"metadata": {
				"required_natural_roll": required_roll,
				"life_state": unit.life_state_id(),
			},
		}
	)


func _record_first_aid(
		actor: TacticalUnitState,
		target: TacticalUnitState,
		raw_roll: int,
		modifier: int,
		total: int,
		required_roll: int,
		success: bool,
		target_before: Dictionary,
		budget_before: Dictionary
) -> void:
	_record_event(
		&"first_aid",
		"FIRST AID — %s treats %s — %s."
		% [actor.display_name, target.display_name, "SUCCESS" if success else "FAILURE"],
		{
			"category": &"rolls",
			"source_actor_id": actor.unit_id,
			"target_actor_ids": [target.unit_id],
			"action_id": &"first_aid",
			"details": [
				"Required natural roll: %d+" % required_roll,
				"%s" % (
					"Target becomes Stable."
					if success
					else "The Dying track is unchanged."
				),
			],
			"roll_records": [
				ROLL_RECORD_SCRIPT.call(
					"create",
					&"medicine_check",
					"1d20",
					[raw_roll],
					total,
					FIRST_AID_DC,
					&"success" if success else &"failure",
					[
						MODIFIER_RECORD_SCRIPT.call(
							"create",
							"Medicine",
							modifier,
							&"medicine",
							&"skill"
						),
					]
				),
			],
			"effect_records": [
				EFFECT_RECORD_SCRIPT.call(
					"create",
					"%s Life State" % target.display_name,
					&"life_state",
					_life_state_from_snapshot(target, target_before),
					target.life_state_id(),
					&"first_aid"
				),
			],
			"resource_changes": [
				{
					"resource": &"normal_capacity",
					"before": int(budget_before.get("remaining", 0)),
					"after": actor.action_budget.remaining_turn_capacity_feet,
				},
			],
			"metadata": {"required_natural_roll": required_roll},
		}
	)


func _record_healing(
		target: TacticalUnitState,
		amount: int,
		source_id: StringName,
		before: Dictionary
) -> void:
	_record_event(
		&"healing",
		"HEALING — %s recovers %d HP." % [target.display_name, amount],
		{
			"category": &"combat",
			"source_actor_id": source_id,
			"target_actor_ids": [target.unit_id],
			"details": [
				"HP: %d → %d"
				% [int(before.get("current_hp", 0)), target.current_hp],
				"Result: %s"
				% String(target.life_state_id()).replace("_", " ").capitalize(),
			],
			"effect_records": [
				EFFECT_RECORD_SCRIPT.call(
					"create",
					"%s HP" % target.display_name,
					&"hit_points",
					int(before.get("current_hp", 0)),
					target.current_hp,
					source_id
				),
			],
		}
	)


func _life_state_from_snapshot(
		unit: TacticalUnitState,
		snapshot: Dictionary
) -> StringName:
	return StringName(LIFE_STATE_RULES_SCRIPT.call(
		"resolve_state",
		int(snapshot.get("current_hp", unit.current_hp)),
		unit.constitution_score(),
		bool(snapshot.get("stable", false)),
		bool(snapshot.get("dead", false)),
		int(snapshot.get("nonlethal_damage", 0))
	))


func _dying_result_message(unit: TacticalUnitState, success: bool) -> String:
	if unit.is_dead():
		return "%s died." % unit.display_name
	if unit.is_stable_unconscious():
		return "%s became Stable." % unit.display_name
	return (
		"%s gained a Dying %s."
		% [unit.display_name, "success" if success else "failure"]
	)


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
