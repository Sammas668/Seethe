class_name TacticalBodyActionHandler
extends RefCounted

const ACTION_LOOT: StringName = &"loot_equipment"
const ACTION_FIRST_AID: StringName = &"administer_first_aid"
const ACTION_FINISH_OFF: StringName = &"finish_off"
const ACTION_UNTIE: StringName = &"untie"

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _event_journal: RefCounted
var _life_state_handler


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		event_journal: RefCounted,
		life_state_handler
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_event_journal = event_journal
	_life_state_handler = life_state_handler


func unavailable_reason(
		actor_id: StringName,
		body_item_id: StringName,
		action_id: StringName
) -> String:
	var actor: TacticalUnitState = _unit(actor_id)
	var body_item: TacticalItemInstanceState = _body_item(body_item_id)
	var target: TacticalUnitState = _body_unit(body_item)
	if actor == null:
		return "The acting character is missing."
	if body_item == null or target == null:
		return "The selected body is no longer available."
	if not _state_store.state.body_is_accessible_to_unit(body_item, actor):
		return "The body is outside the acting character's reach."
	match action_id:
		ACTION_LOOT:
			return "" if _has_removable_equipment(target.unit_id) else "The body carries no removable items."
		ACTION_FIRST_AID:
			return _life_state_handler.first_aid_unavailable_reason(
				actor_id, target.unit_id
			)
		ACTION_FINISH_OFF:
			if target.is_dead():
				return "The character is already dead."
			if not target.is_helpless_body():
				return "Finish Off requires a helpless living body."
			return ActionEconomyRules.unavailable_reason(actor, ActionCost.full_action())
		ACTION_UNTIE:
			if not target.restrained or target.restraint_item_id.is_empty():
				return "The character is not restrained."
			if actor.team_id != target.team_id:
				return "Untie is available only for an allied captive."
			if _state_store.state.get_hand_item(
				actor.unit_id, TacticalInventoryState.KIND_PRIMARY_HAND
			) != null and _state_store.state.get_hand_item(
				actor.unit_id, TacticalInventoryState.KIND_SECONDARY_HAND
			) != null:
				return "Untie requires a free usable hand."
			return ActionEconomyRules.unavailable_reason(actor, ActionCost.half_action())
	return "That body action is unavailable."


func administer_first_aid(
		actor_id: StringName,
		body_item_id: StringName
) -> OperationResult:
	var target: TacticalUnitState = _body_unit(_body_item(body_item_id))
	if target == null:
		return OperationResult.fail(&"body_missing", "The selected body is missing.")
	return _life_state_handler.first_aid(actor_id, target.unit_id)


func apply_item_to_body(
		actor_id: StringName,
		item_id: StringName,
		body_item_id: StringName
) -> OperationResult:
	var item: TacticalItemInstanceState = _state_store.state.get_item(item_id)
	var body_item: TacticalItemInstanceState = _body_item(body_item_id)
	var target: TacticalUnitState = _body_unit(body_item)
	if item == null or target == null:
		return OperationResult.fail(&"body_item_interaction_missing", "The item or body is missing.")
	if item.is_body():
		return OperationResult.fail(&"body_on_body_invalid", "A body cannot be applied to another body.")
	if item.definition == null:
		return OperationResult.fail(&"item_definition_missing", "The item has no usable definition.")
	if item.definition.permits_first_aid:
		return _life_state_handler.first_aid(actor_id, target.unit_id, item.item_id)
	if item.definition.permits_administered_healing:
		return _life_state_handler.administer_healing_item(
			actor_id, target.unit_id, item.item_id
		)
	if item.definition.is_restraint or item.definition.has_tag(&"rope"):
		return restrain(actor_id, body_item_id, item.item_id)
	return OperationResult.fail(
		&"item_not_applicable_to_body",
		"That item cannot be applied directly to a body."
	)


func finish_off(
		actor_id: StringName,
		body_item_id: StringName
) -> OperationResult:
	var reason: String = unavailable_reason(actor_id, body_item_id, ACTION_FINISH_OFF)
	if not reason.is_empty():
		return OperationResult.fail(&"finish_off_unavailable", reason)
	var actor: TacticalUnitState = _unit(actor_id)
	var target: TacticalUnitState = _body_unit(_body_item(body_item_id))
	var actor_budget_before: Dictionary = _budget_snapshot(actor)
	var actor_life_before: Dictionary = actor.life_state_snapshot()
	var target_before: Dictionary = target.life_state_snapshot()
	var changes := TacticalChangeSet.new(&"body_finished_off", _state_store.state.revision)
	changes.stage(
		Callable(self, "_spend_action").bind(actor, ActionCost.full_action()),
		Callable(self, "_restore_actor").bind(actor, actor_budget_before, actor_life_before),
		"The Finish Off action cost could not be paid."
	)
	changes.stage(
		Callable(target, "finish_off"),
		Callable(target, "restore_life_state").bind(target_before),
		"The target could not be finished off."
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	_record_event(
		&"finish_off",
		"%s finished off %s." % [actor.display_name, target.display_name],
		actor.unit_id,
		target.unit_id
	)
	return OperationResult.ok(target, "%s is dead." % target.display_name)


func restrain(
		actor_id: StringName,
		body_item_id: StringName,
		rope_item_id: StringName
) -> OperationResult:
	var actor: TacticalUnitState = _unit(actor_id)
	var body_item: TacticalItemInstanceState = _body_item(body_item_id)
	var target: TacticalUnitState = _body_unit(body_item)
	var rope: TacticalItemInstanceState = _state_store.state.get_item(rope_item_id)
	if actor == null or target == null or rope == null:
		return OperationResult.fail(&"restrain_missing", "The actor, body or rope is missing.")
	if target.is_dead() or not target.is_helpless_body():
		return OperationResult.fail(&"restrain_target_invalid", "Only a helpless living character can be restrained.")
	if target.restrained:
		return OperationResult.fail(&"already_restrained", "The character is already restrained.")
	if not _state_store.state.body_is_accessible_to_unit(body_item, actor):
		return OperationResult.fail(&"body_outside_reach", "The body is outside reach.")
	if rope.definition == null or not (rope.definition.is_restraint or rope.definition.has_tag(&"rope")):
		return OperationResult.fail(&"rope_invalid", "That item cannot restrain a character.")
	if not _item_is_usable(actor, rope):
		return OperationResult.fail(&"rope_outside_reach", "The rope is outside reach.")
	var cost_reason: String = ActionEconomyRules.unavailable_reason(actor, ActionCost.half_action())
	if not cost_reason.is_empty():
		return OperationResult.fail(&"restrain_action_unavailable", cost_reason)

	var actor_budget_before: Dictionary = _budget_snapshot(actor)
	var actor_life_before: Dictionary = actor.life_state_snapshot()
	var target_before: Dictionary = target.life_state_snapshot()
	var rope_before: TacticalItemLocationState = rope.location.clone()
	var changes := TacticalChangeSet.new(&"body_restrained", _state_store.state.revision)
	changes.stage(
		Callable(self, "_spend_action").bind(actor, ActionCost.half_action()),
		Callable(self, "_restore_actor").bind(actor, actor_budget_before, actor_life_before),
		"The Restrain action cost could not be paid."
	)
	changes.stage(
		Callable(self, "_attach_restraint").bind(target, rope),
		Callable(self, "_restore_restraint").bind(target, target_before, rope, rope_before),
		"The rope could not be attached as a restraint."
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	_record_event(
		&"body_restrained",
		"%s restrained %s with %s." % [actor.display_name, target.display_name, rope.display_name],
		actor.unit_id,
		target.unit_id
	)
	return OperationResult.ok(target, "%s is now a Captive." % target.display_name)


func untie(
		actor_id: StringName,
		body_item_id: StringName
) -> OperationResult:
	var reason: String = unavailable_reason(actor_id, body_item_id, ACTION_UNTIE)
	if not reason.is_empty():
		return OperationResult.fail(&"untie_unavailable", reason)
	var actor: TacticalUnitState = _unit(actor_id)
	var body_item: TacticalItemInstanceState = _body_item(body_item_id)
	var target: TacticalUnitState = _body_unit(body_item)
	var rope: TacticalItemInstanceState = _state_store.state.get_item(target.restraint_item_id)
	if rope == null:
		return OperationResult.fail(&"restraint_item_missing", "The restraint item is missing.")
	var body_cell: Vector2i = _state_store.state.body_ground_cell(body_item)
	if body_cell.x < 0:
		body_cell = actor.grid_position
	var actor_budget_before: Dictionary = _budget_snapshot(actor)
	var actor_life_before: Dictionary = actor.life_state_snapshot()
	var target_before: Dictionary = target.life_state_snapshot()
	var rope_before: TacticalItemLocationState = rope.location.clone()
	var changes := TacticalChangeSet.new(&"body_untied", _state_store.state.revision)
	changes.stage(
		Callable(self, "_spend_action").bind(actor, ActionCost.half_action()),
		Callable(self, "_restore_actor").bind(actor, actor_budget_before, actor_life_before),
		"The Untie action cost could not be paid."
	)
	changes.stage(
		Callable(self, "_release_restraint").bind(target, rope, body_cell),
		Callable(self, "_restore_restraint").bind(target, target_before, rope, rope_before),
		"The restraint could not be removed."
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	_record_event(
		&"body_untied",
		"%s untied %s." % [actor.display_name, target.display_name],
		actor.unit_id,
		target.unit_id
	)
	return OperationResult.ok(target, "%s is no longer restrained." % target.display_name)


func search_body(
		actor_id: StringName,
		body_item_id: StringName
) -> OperationResult:
	var actor: TacticalUnitState = _unit(actor_id)
	var body_item: TacticalItemInstanceState = _body_item(body_item_id)
	var target: TacticalUnitState = _body_unit(body_item)
	if actor == null or target == null or body_item == null:
		return OperationResult.fail(&"search_body_missing", "The actor or body is missing.")
	if body_item.location.location_type != TacticalItemLocationState.LOCATION_TACTICAL_GROUND:
		return OperationResult.fail(&"search_body_not_grounded", "Drop the body before searching it.")
	if not _state_store.state.body_is_accessible_to_unit(body_item, actor):
		return OperationResult.fail(&"body_outside_reach", "The body is outside reach.")
	var cost_reason: String = ActionEconomyRules.unavailable_reason(actor, ActionCost.full_action())
	if not cost_reason.is_empty():
		return OperationResult.fail(&"search_action_unavailable", cost_reason)
	var removable: Array[TacticalItemInstanceState] = _removable_equipment(target.unit_id)
	if removable.is_empty():
		return OperationResult.fail(&"body_empty", "The body carries no removable items.")

	var actor_budget_before: Dictionary = _budget_snapshot(actor)
	var actor_life_before: Dictionary = actor.life_state_snapshot()
	var locations_before: Dictionary = {}
	for item: TacticalItemInstanceState in removable:
		locations_before[item.item_id] = item.location.clone()
	var changes := TacticalChangeSet.new(&"body_searched", _state_store.state.revision)
	changes.stage(
		Callable(self, "_spend_action").bind(actor, ActionCost.full_action()),
		Callable(self, "_restore_actor").bind(actor, actor_budget_before, actor_life_before),
		"The Search action cost could not be paid."
	)
	changes.stage(
		Callable(self, "_drop_body_inventory").bind(removable, body_item.location.map_position),
		Callable(self, "_restore_item_locations").bind(locations_before),
		"The body's inventory could not be placed on the floor."
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	_record_event(
		&"body_searched",
		"%s searched %s; %d items were placed on the floor." % [
			actor.display_name, target.display_name, removable.size()
		],
		actor.unit_id,
		target.unit_id
	)
	return OperationResult.ok(removable, "The body's inventory was placed on the floor.")


func equipment_for_body(body_item_id: StringName) -> Array[TacticalItemInstanceState]:
	var target: TacticalUnitState = _body_unit(_body_item(body_item_id))
	if target == null:
		return []
	return _removable_equipment(target.unit_id)


func _attach_restraint(
		target: TacticalUnitState,
		rope: TacticalItemInstanceState
) -> bool:
	if not target.apply_restraint(rope.item_id):
		return false
	rope.location = TacticalItemLocationState.body_attachment(target.unit_id)
	_state_store.state.rebuild_ground_item_index()
	return true


func _release_restraint(
		target: TacticalUnitState,
		rope: TacticalItemInstanceState,
		body_cell: Vector2i
) -> bool:
	if target.remove_restraint() != rope.item_id:
		return false
	rope.location = TacticalItemLocationState.ground(body_cell, "Released restraint")
	_state_store.state.rebuild_ground_item_index()
	return true


func _restore_restraint(
		target: TacticalUnitState,
		target_snapshot: Dictionary,
		rope: TacticalItemInstanceState,
		rope_location: TacticalItemLocationState
) -> void:
	target.restore_life_state(target_snapshot)
	rope.location = rope_location.clone()
	_state_store.state.rebuild_ground_item_index()


func _drop_body_inventory(
		items: Array[TacticalItemInstanceState],
		cell: Vector2i
) -> bool:
	for item: TacticalItemInstanceState in items:
		if item == null or item.is_body():
			return false
		item.location = TacticalItemLocationState.ground(cell, "Searched body")
	_state_store.state.rebuild_ground_item_index()
	return true


func _restore_item_locations(locations: Dictionary) -> void:
	for key: Variant in locations.keys():
		var item: TacticalItemInstanceState = _state_store.state.get_item(StringName(key))
		var location := locations[key] as TacticalItemLocationState
		if item != null and location != null:
			item.location = location.clone()
	_state_store.state.rebuild_ground_item_index()


func _spend_action(actor: TacticalUnitState, cost: ActionCost) -> bool:
	var actor_was_disabled: bool = actor.is_disabled()
	if ActionEconomyRules.spend(actor, cost) < 0:
		return false
	if actor_was_disabled and ActionEconomyRules.is_disabled_strenuous_cost(cost):
		actor.apply_disabled_strain()
	return true


func _restore_actor(
		actor: TacticalUnitState,
		budget: Dictionary,
		life: Dictionary
) -> void:
	actor.action_budget.remaining_turn_capacity_feet = int(budget.get("remaining", 0))
	actor.action_budget.normal_capacity_spent_feet = int(budget.get("spent", 0))
	actor.action_budget.quick_action_available = bool(budget.get("quick", false))
	actor.action_budget.restore_reaction_snapshot(budget.get("reaction", {}))
	actor.action_budget.ordinary_attack_available = bool(budget.get("ordinary_attack", false))
	actor.action_budget.ended_activation = bool(budget.get("ended", false))
	actor.restore_life_state(life)


func _budget_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"reaction": unit.action_budget.reaction_snapshot(),
		"ordinary_attack": unit.action_budget.ordinary_attack_available,
		"ended": unit.action_budget.ended_activation,
	}


func _item_is_usable(
		actor: TacticalUnitState,
		item: TacticalItemInstanceState
) -> bool:
	if item.location == null:
		return false
	if item.location.owner_id == actor.unit_id:
		return true
	return _state_store.state.item_is_accessible_to_unit(item, actor)


func _has_removable_equipment(unit_id: StringName) -> bool:
	return not _removable_equipment(unit_id).is_empty()


func _removable_equipment(unit_id: StringName) -> Array[TacticalItemInstanceState]:
	var result: Array[TacticalItemInstanceState] = []
	for item: TacticalItemInstanceState in _state_store.state.get_items():
		if item.is_body() or item.location == null:
			continue
		if item.location.owner_id != unit_id:
			continue
		if item.location.location_type not in [
			TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
			TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
		]:
			continue
		result.append(item)
	return result


func _unit(unit_id: StringName) -> TacticalUnitState:
	return _state_store.state.get_unit(unit_id) if _state_store != null else null


func _body_item(item_id: StringName) -> TacticalItemInstanceState:
	var item: TacticalItemInstanceState = _state_store.state.get_item(item_id)
	return item if item != null and item.is_body() else null


func _body_unit(body_item: TacticalItemInstanceState) -> TacticalUnitState:
	return (
		_state_store.state.get_unit(body_item.linked_unit_id)
		if body_item != null
		else null
	)


func _record_event(
		event_type: StringName,
		summary: String,
		actor_id: StringName,
		target_id: StringName
) -> void:
	if _event_journal == null:
		return
	_event_journal.call(
		"record_event",
		event_type,
		_state_store.state.phase_state.round_number,
		_state_store.state.phase_state.current_phase,
		summary,
		{
			"category": &"events",
			"source_actor_id": actor_id,
			"target_actor_id": target_id,
		}
	)
