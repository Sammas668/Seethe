class_name TacticalInventoryTransferHandler
extends RefCounted

const KIND_PRIMARY_HAND: StringName = TacticalInventoryState.KIND_PRIMARY_HAND
const KIND_SECONDARY_HAND: StringName = TacticalInventoryState.KIND_SECONDARY_HAND
const KIND_BELT: StringName = TacticalInventoryState.KIND_BELT
const KIND_BACKPACK: StringName = TacticalInventoryState.KIND_BACKPACK
const KIND_GROUND: StringName = TacticalItemLocationState.CONTAINER_GROUND

const BELT_WIDTH: int = TacticalInventoryState.BELT_WIDTH
const BACKPACK_WIDTH: int = TacticalInventoryState.BACKPACK_WIDTH

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _event_journal: RefCounted
var _post_commit_test_hook: Callable


func _init(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition = null,
		event_journal_value: RefCounted = null
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_event_journal = event_journal_value


func set_post_commit_test_hook_for_tests(hook: Callable) -> void:
	# One-shot test seam used only to prove rollback after mutation begins.
	_post_commit_test_hook = hook


func preview(
		command: TacticalInventoryTransferCommand
) -> TacticalInventoryTransferPreview:
	var plan_result := _build_plan(command)
	if not plan_result.success:
		return TacticalInventoryTransferPreview.rejected(plan_result.message)

	var plan := plan_result.data as TacticalInventoryTransferPlan
	var unit := _state_store.state.get_unit(plan.unit_id)
	var item := _state_store.state.get_item(plan.item_id)
	if unit == null or item == null:
		return TacticalInventoryTransferPreview.rejected(
			"The transfer changed before it could be previewed."
		)

	var feet := plan.action_cost.resolved_normal_capacity_feet(
		unit.action_budget.maximum_turn_capacity_feet
	)
	var remaining := unit.action_budget.remaining_turn_capacity_feet - feet

	return TacticalInventoryTransferPreview.accepted(
		plan.action_name,
		item.display_name,
		plan.action_cost,
		plan.requires_quick_action,
		plan.provokes,
		feet,
		remaining,
		plan
	)


func execute(command: TacticalInventoryTransferCommand) -> OperationResult:
	var transfer_preview := preview(command)
	if not transfer_preview.success or transfer_preview.plan == null:
		return OperationResult.fail(
			&"inventory_transfer_invalid",
			transfer_preview.reason
		)
	return execute_plan(transfer_preview.plan, transfer_preview)


func execute_plan(
		plan: TacticalInventoryTransferPlan,
		transfer_preview: TacticalInventoryTransferPreview = null
) -> OperationResult:
	if plan == null:
		return OperationResult.fail(
			&"inventory_plan_missing",
			"No validated inventory-transfer plan was supplied."
		)

	var state: TacticalState = _state_store.state
	var unit: TacticalUnitState = state.get_unit(plan.unit_id)
	var item: TacticalItemInstanceState = state.get_item(plan.item_id)
	if unit == null or item == null:
		return OperationResult.fail(
			&"inventory_transfer_stale",
			"The unit or item no longer exists."
		)
	if state.revision != plan.expected_state_revision:
		return OperationResult.fail(
			&"inventory_transfer_stale",
			"The tactical state changed. Try the transfer again."
		)
	if not item.location.matches(plan.source_location):
		return OperationResult.fail(
			&"inventory_source_changed",
			"The item is no longer in the expected source location."
		)

	if transfer_preview == null:
		transfer_preview = _preview_from_plan(plan, unit, item)

	var budget_snapshot: Dictionary = {
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"reaction": unit.action_budget.reaction_available,
		"ended": unit.action_budget.ended_activation,
	}
	var source_snapshot: TacticalItemLocationState = item.location.clone()

	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"inventory_transfer",
		plan.expected_state_revision
	)
	changes.stage(
		Callable(self, "_apply_inventory_cost").bind(unit, plan),
		Callable(self, "_restore_budget").bind(unit, budget_snapshot),
		"The inventory-transfer action cost could not be paid.",
		&"inventory_cost_failed"
	)
	changes.stage(
		Callable(self, "_move_item").bind(
			item.item_id,
			plan.target_location
		),
		Callable(self, "_restore_item_location").bind(
			item.item_id,
			source_snapshot
		),
		"The item could not be placed in that destination.",
		&"inventory_destination_failed"
	)
	changes.require(
		Callable(self, "_run_post_commit_test_hook").bind(
			state,
			unit,
			item,
			plan
		),
		"Inventory transfer failed post-commit validation.",
		&"inventory_invariant_failed"
	)

	var committed: OperationResult = _state_store.commit(
		changes,
		_map_definition
	)
	if not committed.success:
		return committed

	_record_transfer_event(
		unit,
		item,
		plan,
		transfer_preview,
		budget_snapshot
	)
	return OperationResult.ok(
		transfer_preview,
		_format_success_message(transfer_preview)
	)


func _apply_inventory_cost(
		unit: TacticalUnitState,
		plan: TacticalInventoryTransferPlan
) -> bool:
	var spent: int = ActionEconomyRules.spend(unit, plan.action_cost)
	if spent < 0:
		return false
	if plan.requires_quick_action:
		var quick_spent: int = ActionEconomyRules.spend(
			unit,
			ActionCost.quick_action()
		)
		if quick_spent < 0:
			return false
	return true


func _move_item(
		item_id: StringName,
		target_location: TacticalItemLocationState
) -> bool:
	return _state_store.state.move_item(item_id, target_location, false)


func _restore_item_location(
		item_id: StringName,
		source_location: TacticalItemLocationState
) -> void:
	_state_store.state.move_item(item_id, source_location, false)


func _run_post_commit_test_hook(
		state: TacticalState,
		unit: TacticalUnitState,
		item: TacticalItemInstanceState,
		plan: TacticalInventoryTransferPlan
) -> String:
	if not _post_commit_test_hook.is_valid():
		return ""
	var hook: Callable = _post_commit_test_hook
	_post_commit_test_hook = Callable()
	return String(hook.call(state, unit, item, plan))


func _preview_from_plan(
		plan: TacticalInventoryTransferPlan,
		unit: TacticalUnitState,
		item: TacticalItemInstanceState
) -> TacticalInventoryTransferPreview:
	var feet := plan.action_cost.resolved_normal_capacity_feet(
		unit.action_budget.maximum_turn_capacity_feet
	)
	return TacticalInventoryTransferPreview.accepted(
		plan.action_name,
		item.display_name,
		plan.action_cost,
		plan.requires_quick_action,
		plan.provokes,
		feet,
		unit.action_budget.remaining_turn_capacity_feet - feet,
		plan
	)


func resolve_source_item(
		command: TacticalInventoryTransferCommand
) -> TacticalItemInstanceState:
	if command == null:
		return null
	var item := _state_store.state.get_item(command.source_item_id)
	if item == null:
		return null
	if item.location.container_kind != command.source_kind:
		return null
	if command.source_kind != KIND_GROUND and item.location.owner_id != command.unit_id:
		return null
	return item


func first_fit_for_item(
		unit_id: StringName,
		item: TacticalItemInstanceState,
		target_kind: StringName
) -> int:
	var unit := _state_store.state.get_unit(unit_id)
	if unit == null or item == null:
		return -1

	var position := _state_store.state.first_fit(unit, item, target_kind)
	if position.x < 0:
		return -1

	var width := BELT_WIDTH if target_kind == KIND_BELT else BACKPACK_WIDTH
	return position.y * width + position.x


func _build_plan(command: TacticalInventoryTransferCommand) -> OperationResult:
	if command == null:
		return OperationResult.fail(
			&"inventory_command_missing",
			"No inventory transfer has been selected."
		)

	var state := _state_store.state
	if not state.phase_state.is_player_phase():
		return OperationResult.fail(
			&"wrong_phase",
			"Inventory changes are unavailable outside the Player Phase."
		)

	var unit := state.get_unit(command.unit_id)
	if unit == null:
		return OperationResult.fail(
			&"inventory_unit_missing",
			"The selected unit does not exist."
		)

	var item := resolve_source_item(command)
	if item == null:
		return OperationResult.fail(
			&"inventory_source_missing",
			"The selected source item no longer exists."
		)

	if command.source_kind == command.target_kind:
		if command.source_kind in [KIND_PRIMARY_HAND, KIND_SECONDARY_HAND]:
			return OperationResult.fail(
				&"same_hand",
				"The item is already in that hand."
			)
		if command.source_kind == KIND_GROUND:
			return OperationResult.fail(
				&"already_grounded",
				"The item is already in Items in Reach."
			)

	var target_location_result := _target_location(unit, item, command)
	if not target_location_result.success:
		return target_location_result
	var target_location := target_location_result.data as TacticalItemLocationState

	if (
		command.source_kind == KIND_GROUND
		and not state.item_is_accessible_to_unit(item, unit)
	):
		return OperationResult.fail(
			&"outside_reach",
			"The item is outside the unit's reach."
		)

	var current_weight := state.calculated_carried_weight(unit.unit_id)
	var resulting_weight := current_weight
	var source_is_carried := item.location.owner_id == unit.unit_id
	var target_is_carried := target_location.owner_id == unit.unit_id
	if not source_is_carried and target_is_carried:
		resulting_weight += item.weight_lb
	elif source_is_carried and not target_is_carried:
		resulting_weight -= item.weight_lb

	if resulting_weight > unit.inventory.maximum_weight_lb + 0.001:
		return OperationResult.fail(
			&"carrying_limit",
			"Picking up this item would exceed the carrying limit."
		)

	var cost := _normal_cost(command, item)
	var requires_quick := _requires_additional_quick(command)
	var unavailable_reason := ActionEconomyRules.unavailable_reason(unit, cost)
	if not unavailable_reason.is_empty():
		return OperationResult.fail(&"action_unavailable", unavailable_reason)

	if requires_quick:
		var quick_reason := ActionEconomyRules.unavailable_reason(
			unit,
			ActionCost.quick_action()
		)
		if not quick_reason.is_empty():
			return OperationResult.fail(&"quick_unavailable", quick_reason)

	var plan := TacticalInventoryTransferPlan.new(
		item.item_id,
		unit.unit_id,
		item.location.clone(),
		target_location,
		cost,
		requires_quick,
		_provokes(command),
		state.revision,
		resulting_weight,
		_action_name(command, item.display_name)
	)
	return OperationResult.ok(plan, "Transfer plan prepared.")


func _target_location(
		unit: TacticalUnitState,
		item: TacticalItemInstanceState,
		command: TacticalInventoryTransferCommand
) -> OperationResult:
	var state := _state_store.state
	match command.target_kind:
		KIND_PRIMARY_HAND:
			if item.definition == null or not item.definition.can_equip_in_hand():
				return OperationResult.fail(
					&"not_hand_equipment",
					"That item cannot be equipped in a hand."
				)
			var primary := state.get_hand_item(unit.unit_id, KIND_PRIMARY_HAND)
			if primary != null and primary.item_id != item.item_id:
				return OperationResult.fail(
					&"primary_occupied",
					"Primary Hand is already occupied."
				)
			var secondary := state.get_hand_item(unit.unit_id, KIND_SECONDARY_HAND)
			if item.two_handed and secondary != null and secondary.item_id != item.item_id:
				return OperationResult.fail(
					&"two_hand_blocked",
					"A two-handed item requires both hands to be empty."
				)
			return OperationResult.ok(
				TacticalItemLocationState.unit_hand(unit.unit_id, KIND_PRIMARY_HAND)
			)
		KIND_SECONDARY_HAND:
			if item.definition == null or not item.definition.can_equip_in_hand():
				return OperationResult.fail(
					&"not_hand_equipment",
					"That item cannot be equipped in a hand."
				)
			if item.two_handed:
				return OperationResult.fail(
					&"two_hand_primary_only",
					"Two-handed items must be equipped through Primary Hand."
				)
			var primary_item := state.get_hand_item(unit.unit_id, KIND_PRIMARY_HAND)
			if primary_item != null and primary_item.two_handed:
				return OperationResult.fail(
					&"secondary_reserved",
					"Secondary Hand is reserved by the two-handed Primary item."
				)
			var secondary_item := state.get_hand_item(unit.unit_id, KIND_SECONDARY_HAND)
			if secondary_item != null and secondary_item.item_id != item.item_id:
				return OperationResult.fail(
					&"secondary_occupied",
					"Secondary Hand is already occupied."
				)
			return OperationResult.ok(
				TacticalItemLocationState.unit_hand(unit.unit_id, KIND_SECONDARY_HAND)
			)
		KIND_BELT, KIND_BACKPACK:
			if command.target_kind == KIND_BELT and not item.belt_allowed:
				return OperationResult.fail(
					&"belt_forbidden",
					"That item is too large or unsuitable for the Belt."
				)
			if command.target_kind == KIND_BACKPACK and not item.backpack_allowed:
				return OperationResult.fail(
					&"backpack_forbidden",
					"That bulky item cannot be packed into a backpack."
				)
			var position := _cell_to_position(
				command.target_kind,
				command.target_cell_index
			)
			if position.x < 0:
				return OperationResult.fail(
					&"target_cell_missing",
					"Choose an empty cell in that inventory grid."
				)
			var ignore_item_id := (
				item.item_id
				if command.source_kind == command.target_kind
				else &""
			)
			if not state.can_place_item(
				unit,
				item,
				command.target_kind,
				position,
				ignore_item_id
			):
				return OperationResult.fail(
					&"item_does_not_fit",
					"The item does not fit in that position."
				)
			return OperationResult.ok(
				TacticalItemLocationState.unit_grid(
					unit.unit_id,
					command.target_kind,
					position
				)
			)
		KIND_GROUND:
			if command.source_kind == KIND_GROUND:
				return OperationResult.fail(
					&"already_grounded",
					"The item is already on the ground."
				)
			return OperationResult.ok(
				TacticalItemLocationState.ground(
					unit.grid_position,
					"Current tile"
				)
			)
		_:
			return OperationResult.fail(
				&"destination_unavailable",
				"That inventory destination is unavailable."
			)


func _cell_to_position(
		container_kind: StringName,
		cell_index: int
) -> Vector2i:
	if cell_index < 0:
		return Vector2i(-1, -1)
	var width := BELT_WIDTH if container_kind == KIND_BELT else BACKPACK_WIDTH
	return Vector2i(cell_index % width, int(cell_index / width))


func _normal_cost(
		command: TacticalInventoryTransferCommand,
		item: TacticalItemInstanceState
) -> ActionCost:
	if command.target_kind == KIND_GROUND:
		return ActionCost.fixed_capacity(0)

	if command.source_kind == KIND_GROUND:
		if command.target_kind == KIND_BACKPACK:
			return ActionCost.half_action()
		if item.weight_lb >= 15.0:
			return ActionCost.half_action()
		return ActionCost.minor_interaction()

	if command.source_kind == command.target_kind:
		if command.source_kind in [KIND_BELT, KIND_BACKPACK]:
			return ActionCost.fixed_capacity(0)

	if (
		command.source_kind == KIND_BELT
		and command.target_kind in [KIND_PRIMARY_HAND, KIND_SECONDARY_HAND]
	):
		return ActionCost.quick_action()

	if (
		command.target_kind == KIND_BELT
		and command.source_kind in [KIND_PRIMARY_HAND, KIND_SECONDARY_HAND]
	):
		return ActionCost.quick_action()

	if (
		command.source_kind == KIND_BACKPACK
		or command.target_kind == KIND_BACKPACK
	):
		return ActionCost.half_action()

	return ActionCost.quick_action()


func _requires_additional_quick(
		command: TacticalInventoryTransferCommand
) -> bool:
	return (
		command.source_kind == KIND_GROUND
		and command.target_kind == KIND_BELT
	)


func _provokes(command: TacticalInventoryTransferCommand) -> bool:
	if command.source_kind == command.target_kind:
		return false
	return (
		command.source_kind == KIND_BACKPACK
		or command.target_kind == KIND_BACKPACK
	)


func _action_name(
		command: TacticalInventoryTransferCommand,
		item_name: String
) -> String:
	if command.source_kind == KIND_GROUND:
		if command.target_kind == KIND_BELT:
			return "Pick up %s and stow it on the Belt" % item_name
		if command.target_kind == KIND_BACKPACK:
			return "Pack %s from Items in Reach" % item_name
		return "Pick up %s" % item_name
	if command.target_kind == KIND_GROUND:
		return "Drop %s into Items in Reach" % item_name
	if command.target_kind == KIND_PRIMARY_HAND:
		return "Move %s to Primary Hand" % item_name
	if command.target_kind == KIND_SECONDARY_HAND:
		return "Move %s to Secondary Hand" % item_name
	if command.target_kind == KIND_BELT:
		return "Move %s to the Belt" % item_name
	if command.target_kind == KIND_BACKPACK:
		return "Move %s to the Backpack" % item_name
	return "Move %s" % item_name


func _format_success_message(
		transfer_preview: TacticalInventoryTransferPreview
) -> String:
	var cost_parts: Array[String] = []
	if transfer_preview.action_cost.is_quick_action():
		cost_parts.append("Quick Action")
	elif transfer_preview.cost_feet <= 0:
		cost_parts.append("free")
	else:
		cost_parts.append("%d ft" % transfer_preview.cost_feet)
	if transfer_preview.requires_quick_action:
		cost_parts.append("Quick Action")
	if transfer_preview.provokes:
		cost_parts.append("normally Provokes")
	return "%s — %s." % [
		transfer_preview.action_name,
		" + ".join(PackedStringArray(cost_parts)),
	]


func _restore_budget(unit: TacticalUnitState, snapshot: Dictionary) -> void:
	unit.action_budget.remaining_turn_capacity_feet = int(snapshot["remaining"])
	unit.action_budget.normal_capacity_spent_feet = int(snapshot["spent"])
	unit.action_budget.quick_action_available = bool(snapshot["quick"])
	unit.action_budget.reaction_available = bool(snapshot["reaction"])
	unit.action_budget.ended_activation = bool(snapshot["ended"])



func _record_transfer_event(
		unit: TacticalUnitState,
		item: TacticalItemInstanceState,
		plan: TacticalInventoryTransferPlan,
		transfer_preview: TacticalInventoryTransferPreview,
		budget_snapshot: Dictionary
) -> void:
	if _event_journal == null:
		return
	if not _event_journal.has_method("record_event"):
		return
	if not _should_record_transfer(plan):
		return

	var summary := _transfer_summary(unit, item, plan)
	var details: Array[String] = [
		"Item: %s" % item.display_name,
		"From: %s" % _location_label(plan.source_location),
		"To: %s" % _location_label(plan.target_location),
		"Cost: %s" % _transfer_cost_text(transfer_preview),
		"Capacity: %d → %d ft"
		% [
			int(budget_snapshot.get("remaining", 0)),
			unit.action_budget.remaining_turn_capacity_feet,
		],
	]

	var quick_before := bool(budget_snapshot.get("quick", true))
	if quick_before != unit.action_budget.quick_action_available:
		details.append(
			"Quick Action: %s → %s"
			% [
				"Ready" if quick_before else "Spent",
				(
					"Ready"
					if unit.action_budget.quick_action_available
					else "Spent"
				),
			]
		)
	if transfer_preview.provokes:
		details.append("Threat consequence: normally Provokes")

	var phase := _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"inventory_transfer",
		phase.round_number,
		phase.current_phase,
		summary,
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"item_id": item.item_id,
			"details": details,
			"resource_changes": [
				{
					"resource": &"normal_capacity",
					"before": int(budget_snapshot.get("remaining", 0)),
					"after": unit.action_budget.remaining_turn_capacity_feet,
				},
				{
					"resource": &"quick_action",
					"before": quick_before,
					"after": unit.action_budget.quick_action_available,
				},
			],
			"metadata": {
				"source_container": plan.source_location.container_kind,
				"target_container": plan.target_location.container_kind,
				"provokes": transfer_preview.provokes,
			},
		}
	)


func _should_record_transfer(
		plan: TacticalInventoryTransferPlan
) -> bool:
	if plan == null:
		return false

	var source := plan.source_location
	var target := plan.target_location
	if source == null or target == null:
		return false

	var same_grid := (
		source.location_type
		== TacticalItemLocationState.LOCATION_UNIT_INVENTORY
		and target.location_type
		== TacticalItemLocationState.LOCATION_UNIT_INVENTORY
		and source.owner_id == target.owner_id
		and source.container_kind == target.container_kind
	)
	return not same_grid


func _transfer_summary(
		unit: TacticalUnitState,
		item: TacticalItemInstanceState,
		plan: TacticalInventoryTransferPlan
) -> String:
	var source := plan.source_location
	var target := plan.target_location

	if (
		source.location_type
		== TacticalItemLocationState.LOCATION_TACTICAL_GROUND
	):
		return "%s picked up %s." % [
			unit.display_name,
			item.display_name,
		]

	if (
		target.location_type
		== TacticalItemLocationState.LOCATION_TACTICAL_GROUND
	):
		return "%s dropped %s." % [
			unit.display_name,
			item.display_name,
		]

	if target.container_kind == KIND_PRIMARY_HAND:
		return "%s equipped %s in Primary Hand." % [
			unit.display_name,
			item.display_name,
		]

	if target.container_kind == KIND_SECONDARY_HAND:
		return "%s equipped %s in Secondary Hand." % [
			unit.display_name,
			item.display_name,
		]

	return "%s moved %s to %s." % [
		unit.display_name,
		item.display_name,
		_location_label(target),
	]


func _location_label(
		location: TacticalItemLocationState
) -> String:
	if location == null:
		return "Unknown"

	match location.container_kind:
		KIND_PRIMARY_HAND:
			return "Primary Hand"
		KIND_SECONDARY_HAND:
			return "Secondary Hand"
		KIND_BELT:
			return "Belt"
		KIND_BACKPACK:
			return "Backpack"
		KIND_GROUND:
			var source := (
				location.source_label
				if not location.source_label.is_empty()
				else "Items in Reach"
			)
			return "%s at (%d, %d)" % [
				source,
				location.map_position.x,
				location.map_position.y,
			]
		_:
			return String(location.container_kind).capitalize()


func _transfer_cost_text(
		transfer_preview: TacticalInventoryTransferPreview
) -> String:
	var parts: Array[String] = []

	if transfer_preview.action_cost.is_quick_action():
		parts.append("Quick Action")
	elif transfer_preview.cost_feet <= 0:
		parts.append("Free")
	else:
		parts.append("%d ft" % transfer_preview.cost_feet)

	if transfer_preview.requires_quick_action:
		parts.append("Quick Action")
	if transfer_preview.provokes:
		parts.append("normally Provokes")

	return " + ".join(PackedStringArray(parts))
