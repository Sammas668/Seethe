class_name Stage432BodyItemTests
extends RefCounted

const BODY_TILE := Vector2i(3, 3)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_disabled_and_body_occupancy(failures)
	_test_body_carry_and_drag_use_inventory_locations(failures)
	_test_first_aid_item_healing_potion_and_search(failures)
	_test_rope_restraint_and_allied_untie(failures)
	_test_body_status_badge_provider(failures)
	_test_carrier_downing_drops_bodies(failures)
	return failures


static func _test_disabled_and_body_occupancy(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var target: TacticalUnitState = _place_target(session)
	if target == null:
		failures.append("The body occupancy fixture needs the first enemy guard.")
		return

	target.restore_damage_state(0, 0)
	state.synchronise_body_items(session.map_definition)
	_expect(target.is_disabled(), "Exactly 0 HP must remain Disabled.", failures)
	_expect(
		state.body_item_for_unit(target.unit_id) == null,
		"A Disabled character must not create a body item.",
		failures
	)
	_expect(
		state.get_unit_at_tile(BODY_TILE) == target,
		"A Disabled character must continue to block standing occupancy.",
		failures
	)

	target.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	var body: TacticalItemInstanceState = state.body_item_for_unit(target.unit_id)
	_expect(target.is_dying(), "Negative HP must enter Dying.", failures)
	_expect(body != null and body.is_body(), "Dying must create one linked body item.", failures)
	_expect(
		body != null and body.location.location_type == TacticalItemLocationState.LOCATION_TACTICAL_GROUND,
		"A newly fallen body item must be placed on the ground.",
		failures
	)
	_expect(
		state.get_unit_at_tile(BODY_TILE) == null,
		"A Dying body must release standing occupancy.",
		failures
	)
	_expect(state.has_ground_body_at(BODY_TILE), "A ground body must remain indexed on its tile.", failures)
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	_expect(
		actor != null and state.can_place_unit(actor, BODY_TILE, session.map_definition, actor.unit_id),
		"A standing unit must be allowed to end movement on a body tile.",
		failures
	)


static func _test_body_carry_and_drag_use_inventory_locations(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var target: TacticalUnitState = _place_target(session)
	if actor == null or target == null:
		failures.append("The Carry/Drag fixture needs the Marauder and enemy guard.")
		return
	_clear_actor_inventory_to_ground(state, actor)
	actor.inventory.maximum_weight_lb = 500.0
	actor.refresh_for_new_round()
	target.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	var body: TacticalItemInstanceState = state.body_item_for_unit(target.unit_id)
	if body == null:
		failures.append("The Carry/Drag fixture could not create its body item.")
		return
	var body_weight: float = state.effective_item_weight(body)

	var carry := TacticalInventoryTransferCommand.new(
		actor.unit_id,
		TacticalItemLocationState.CONTAINER_GROUND,
		body.item_id,
		TacticalInventoryState.KIND_BACKPACK,
		0
	)
	var carry_result: OperationResult = session.inventory_transfer_handler.execute(carry)
	_expect(carry_result.success, "Dropping a body into valid Backpack cells must carry it.", failures)
	_expect(
		body.location.location_type == TacticalItemLocationState.LOCATION_UNIT_INVENTORY
		and body.location.container_kind == TacticalInventoryState.KIND_BACKPACK,
		"A carried body must be an ordinary Backpack item location.",
		failures
	)
	_expect(body.footprint == Vector2i(4, 3), "A Medium body must consume a real 4×3 Backpack footprint.", failures)
	_expect(
		state.calculated_carried_weight(actor.unit_id) >= body_weight - 0.001,
		"A carried body must contribute full body-plus-equipment weight.",
		failures
	)
	_expect(
		state.body_ground_cell(body).x < 0,
		"A body packed in the Backpack must no longer have a ground token cell.",
		failures
	)

	var drag := TacticalInventoryTransferCommand.new(
		actor.unit_id,
		TacticalInventoryState.KIND_BACKPACK,
		body.item_id,
		TacticalInventoryState.KIND_PRIMARY_HAND,
		-1
	)
	var drag_result: OperationResult = session.inventory_transfer_handler.execute(drag)
	_expect(drag_result.success, "Moving a body into an empty Hand must begin dragging.", failures)
	_expect(
		body.location.location_type == TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT
		and body.location.container_kind == TacticalInventoryState.KIND_PRIMARY_HAND
		and body.location.transport_mode == &"dragging",
		"A dragged body must occupy the real Hand slot with dragging transport mode.",
		failures
	)
	_expect(
		state.hand_display_name(actor.unit_id, TacticalInventoryState.KIND_PRIMARY_HAND).begins_with("Dragging "),
		"The occupied Hand must display the dragged body.",
		failures
	)
	_expect(
		state.body_ground_cell(body) == actor.grid_position,
		"A body in a Hand must remain physically represented on the ground.",
		failures
	)
	_expect(
		state.calculated_carried_weight(actor.unit_id) < body_weight,
		"Dragging must not count the body's full mass as packed carried weight.",
		failures
	)

	actor.refresh_for_new_round()
	var drag_path: MovementPathResult = _find_multi_tile_path(session, actor)
	if drag_path == null:
		failures.append("The Drag movement fixture needs a legal route of at least two tiles.")
		return
	var moved: OperationResult = session.movement_handler.execute_move(
		MoveCommand.new(actor.unit_id, drag_path.path.back())
	)
	_expect(moved.success, "A character dragging a body must be able to complete a multi-tile move.", failures)
	if moved.success:
		var committed_path := moved.data as MovementPathResult
		var expected_body_cell: Vector2i = committed_path.path[
			committed_path.path.size() - 2
		]
		_expect(
			state.body_ground_cell(body) == expected_body_cell,
			"After a multi-tile move, the dragged body must finish in the carrier's penultimate path tile.",
			failures
		)
		_expect(
			target.grid_position == expected_body_cell,
			"The linked fallen character position must follow the dragged body item.",
			failures
		)


static func _test_first_aid_item_healing_potion_and_search(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var target: TacticalUnitState = _place_target(session)
	if actor == null or target == null:
		failures.append("The body medical fixture needs the Marauder and enemy guard.")
		return

	# Right-click First Aid deliberately works without an item.
	target.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	var body: TacticalItemInstanceState = state.body_item_for_unit(target.unit_id)
	session.screen_facade.set_combat_scripted_rolls_for_tests([20])
	actor.refresh_for_new_round()
	var improvised: OperationResult = session.body_action_handler.administer_first_aid(
		actor.unit_id, body.item_id
	)
	_expect(improvised.success and target.is_stable_unconscious(), "Improvised First Aid must stabilise on a successful Medicine check.", failures)

	# Dragged medical supplies use exactly that item's authored bonus and one use.
	target.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	body = state.body_item_for_unit(target.unit_id)
	var bandage: TacticalItemInstanceState = _find_item(state, &"item.bandage", &"instance.ground.bandages")
	if bandage == null:
		failures.append("The body medical fixture needs the sandbox Bandage stack.")
		return
	bandage.location = TacticalItemLocationState.ground(actor.grid_position, "Test medical item")
	state.rebuild_ground_item_index()
	var bandage_quantity_before: int = bandage.quantity
	actor.refresh_for_new_round()
	session.screen_facade.set_combat_scripted_rolls_for_tests([20])
	var assisted: OperationResult = session.body_action_handler.apply_item_to_body(
		actor.unit_id, bandage.item_id, body.item_id
	)
	_expect(assisted.success and target.is_stable_unconscious(), "Dragging a medical item onto a Dying body must perform First Aid.", failures)
	var assisted_data: Dictionary = assisted.data if assisted.data is Dictionary else {}
	_expect(int(assisted_data.get("item_bonus", 0)) == 2, "The First Aid roll must include only the dragged Bandage's +2 bonus.", failures)
	_expect(bandage.quantity == bandage_quantity_before - 1, "A valid medical-item attempt must consume one use.", failures)

	# Search bulk-drops all linked character inventory onto the same body tile.
	target.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	body = state.body_item_for_unit(target.unit_id)
	var removable_before: Array[TacticalItemInstanceState] = session.body_action_handler.equipment_for_body(body.item_id)
	actor.refresh_for_new_round()
	var searched: OperationResult = session.body_action_handler.search_body(actor.unit_id, body.item_id)
	_expect(searched.success, "Search must atomically place all removable body inventory on the floor.", failures)
	for item: TacticalItemInstanceState in removable_before:
		_expect(
			item.location.location_type == TacticalItemLocationState.LOCATION_TACTICAL_GROUND
			and item.location.map_position == BODY_TILE,
			"Search must preserve each item instance and move it to the body tile.",
			failures
		)

	# A dragged potion applies authored healing without a Medicine roll.
	target.restore_damage_state(-3, 0)
	state.synchronise_body_items(session.map_definition)
	body = state.body_item_for_unit(target.unit_id)
	var potion: TacticalItemInstanceState = _find_item(
		state, &"item.minor_healing_potion", &"instance.ground.healing_potion"
	)
	if potion == null:
		failures.append("The body medical fixture needs the sandbox healing potion.")
		return
	potion.location = TacticalItemLocationState.ground(actor.grid_position, "Test potion")
	state.rebuild_ground_item_index()
	actor.refresh_for_new_round()
	var healed: OperationResult = session.body_action_handler.apply_item_to_body(
		actor.unit_id, potion.item_id, body.item_id
	)
	_expect(healed.success, "Dragging a healing potion onto a living body must administer it.", failures)
	_expect(target.current_hp == 2, "The 5 HP potion must heal from the character's real -3 HP to 2 HP.", failures)
	_expect(state.body_item_for_unit(target.unit_id) == null, "A recovered character on a free legal tile must stop using a body item.", failures)


static func _test_rope_restraint_and_allied_untie(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var target: TacticalUnitState = _place_target(session)
	var ally: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_TWO_ID)
	if actor == null or target == null or ally == null:
		failures.append("The restraint fixture needs the Marauder and both enemy guards.")
		return
	state.set_unit_position(ally.unit_id, Vector2i(4, 3), session.map_definition, false)
	target.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	var body: TacticalItemInstanceState = state.body_item_for_unit(target.unit_id)
	var rope: TacticalItemInstanceState = _find_owned_item(state, actor.unit_id, &"item.rope")
	if body == null or rope == null:
		failures.append("The restraint fixture needs a body and the Marauder's rope.")
		return
	actor.refresh_for_new_round()
	var restrained: OperationResult = session.body_action_handler.apply_item_to_body(
		actor.unit_id, rope.item_id, body.item_id
	)
	_expect(restrained.success, "Dragging rope onto a helpless living body must restrain it.", failures)
	_expect(target.restrained and target.captive, "A restrained living body must become a Captive.", failures)
	_expect(target.is_dying(), "Restraining a Dying body must not stabilise it.", failures)
	_expect(
		rope.location.location_type == TacticalItemLocationState.LOCATION_BODY_ATTACHMENT
		and rope.location.owner_id == target.unit_id,
		"Restraint must use the same real rope item as a body attachment.",
		failures
	)

	_clear_hands_to_ground(state, ally)
	ally.refresh_for_new_round()
	var untied: OperationResult = session.body_action_handler.untie(
		ally.unit_id, body.item_id
	)
	_expect(untied.success, "An adjacent enemy ally must be able to use the same Untie action.", failures)
	_expect(not target.restrained and not target.captive, "Untie must remove only restraint and Captive state.", failures)
	_expect(target.is_dying(), "Untie must not change the body's Dying state.", failures)
	_expect(
		rope.location.location_type == TacticalItemLocationState.LOCATION_TACTICAL_GROUND
		and rope.location.map_position == BODY_TILE,
		"Untie must return the exact same rope item to the body tile.",
		failures
	)


static func _test_body_status_badge_provider(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var target: TacticalUnitState = _place_target(session)
	if target == null:
		failures.append("The body badge fixture needs the first enemy guard.")
		return
	target.restore_damage_state(-1, 0)
	target.dying_successes = 2
	target.dying_failures = 1
	target.restrained = true
	state.synchronise_body_items(session.map_definition)
	var body: TacticalItemInstanceState = state.body_item_for_unit(target.unit_id)
	var dying_badges: Dictionary = TacticalStatusBadgeProvider.for_body_item(
		state,
		body
	)
	_expect(
		StringName(dying_badges.get("primary_kind", &""))
		== TacticalStatusBadgeProvider.BADGE_KIND_DYING,
		"A Dying body item must use the shared Dying badge kind.",
		failures
	)
	_expect(
		int(dying_badges.get("dying_successes", 0)) == 2
		and int(dying_badges.get("dying_failures", 0)) == 1,
		"Inventory Dying pips must come from the linked character.",
		failures
	)
	_expect(
		bool(dying_badges.get("restrained", false)),
		"A restrained body item must show the shared restraint badge.",
		failures
	)

	target.restrained = false
	target.become_stable()
	state.synchronise_body_items(session.map_definition)
	var stable_badges: Dictionary = TacticalStatusBadgeProvider.for_body_item(
		state,
		state.body_item_for_unit(target.unit_id)
	)
	_expect(
		StringName(stable_badges.get("primary_kind", &""))
		== TacticalStatusBadgeProvider.BADGE_KIND_UNCONSCIOUS
		and bool(stable_badges.get("stable", false)),
		"A Stable body must retain the Unconscious badge and Stable marker.",
		failures
	)


static func _test_carrier_downing_drops_bodies(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var carrier: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var packed_target: TacticalUnitState = _place_target(session)
	var dragged_target: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.ENEMY_TWO_ID
	)
	if carrier == null or packed_target == null or dragged_target == null:
		failures.append("The carrier-downing fixture needs the Marauder and both guards.")
		return
	_clear_actor_inventory_to_ground(state, carrier)
	carrier.inventory.maximum_weight_lb = 600.0
	carrier.refresh_for_new_round()
	state.set_unit_position(
		dragged_target.unit_id,
		BODY_TILE + Vector2i(-1, 0),
		session.map_definition,
		false
	)
	packed_target.restore_damage_state(-1, 0)
	dragged_target.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	var packed_body: TacticalItemInstanceState = state.body_item_for_unit(
		packed_target.unit_id
	)
	var dragged_body: TacticalItemInstanceState = state.body_item_for_unit(
		dragged_target.unit_id
	)
	if packed_body == null or dragged_body == null:
		failures.append("The carrier-downing fixture could not create both body items.")
		return

	var carry_result: OperationResult = session.inventory_transfer_handler.execute(
		TacticalInventoryTransferCommand.new(
			carrier.unit_id,
			TacticalItemLocationState.CONTAINER_GROUND,
			packed_body.item_id,
			TacticalInventoryState.KIND_BACKPACK,
			0
		)
	)
	_expect(carry_result.success, "The fixture must be able to pack one body.", failures)
	var drag_result: OperationResult = session.inventory_transfer_handler.execute(
		TacticalInventoryTransferCommand.new(
			carrier.unit_id,
			TacticalItemLocationState.CONTAINER_GROUND,
			dragged_body.item_id,
			TacticalInventoryState.KIND_PRIMARY_HAND,
			-1
		)
	)
	_expect(drag_result.success, "The fixture must be able to drag one body.", failures)
	if not carry_result.success or not drag_result.success:
		return

	var dragged_cell_before: Vector2i = state.body_ground_cell(dragged_body)
	var ordinary_item: TacticalItemInstanceState = _first_ordinary_item_on_ground(
		state,
		carrier.grid_position
	)
	if ordinary_item != null:
		ordinary_item.location = TacticalItemLocationState.unit_grid(
			carrier.unit_id,
			TacticalInventoryState.KIND_BACKPACK,
			Vector2i(5, 0)
		)
	state.rebuild_ground_item_index()

	var carrier_before: Dictionary = carrier.life_state_snapshot()
	var changes := TacticalChangeSet.new(
		&"test_carrier_downed_with_bodies",
		state.revision,
		TacticalInvalidationContract.no_visual_change()
	)
	changes.stage(
		func() -> bool:
			carrier.restore_damage_state(-1, 0)
			return true,
		func() -> void:
			carrier.restore_life_state(carrier_before),
		"The carrier could not be downed for the body-drop test."
	)
	var downed_result: OperationResult = session.state_store.commit(
		changes,
		session.map_definition
	)
	_expect(downed_result.success, "Carrier downing with bodies must commit.", failures)
	if not downed_result.success:
		return

	_expect(
		state.get_packed_body_items(carrier.unit_id).is_empty(),
		"A downed carrier must retain no packed body items.",
		failures
	)
	_expect(
		packed_body.location.location_type
		== TacticalItemLocationState.LOCATION_TACTICAL_GROUND,
		"A packed body must be moved onto tactical ground when its carrier falls.",
		failures
	)
	_expect(
		state.should_body_token_be_visible(packed_body),
		"A dropped packed body must immediately regain its tactical token.",
		failures
	)
	_expect(
		_max_axis_distance(
			packed_body.location.map_position,
			carrier.grid_position
		) <= 1,
		"A packed body must drop onto an adjacent tile or the carrier tile fallback.",
		failures
	)
	_expect(
		dragged_body.location.location_type
		== TacticalItemLocationState.LOCATION_TACTICAL_GROUND
		and dragged_body.location.map_position == dragged_cell_before,
		"A dragged body must release on its existing valid ground cell.",
		failures
	)
	_expect(
		state.should_body_token_be_visible(dragged_body),
		"A released dragged body must keep its tactical token visible.",
		failures
	)
	if ordinary_item != null:
		_expect(
			ordinary_item.location.location_type
			== TacticalItemLocationState.LOCATION_UNIT_INVENTORY
			and ordinary_item.location.owner_id == carrier.unit_id,
			"Carrier downing must not drop ordinary inventory items.",
			failures
		)
	_expect(
		state.body_item_for_unit(carrier.unit_id) != null,
		"The carrier's own linked body item must still be created.",
		failures
	)


static func _place_target(session: TacticalSession) -> TacticalUnitState:
	var state: TacticalState = session.state_store.state
	var target: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	if target == null:
		return null
	state.set_unit_position(target.unit_id, BODY_TILE, session.map_definition, false)
	return target


static func _find_multi_tile_path(
		session: TacticalSession,
		actor: TacticalUnitState
) -> MovementPathResult:
	var navigation := TacticalNavigationSnapshot.new(
		session.map_definition,
		session.state_store.state,
		actor.unit_id
	)
	for y: int in range(session.map_definition.grid_size.y):
		for x: int in range(session.map_definition.grid_size.x):
			var destination := Vector2i(x, y)
			var path: MovementPathResult = MovementRules.find_path(
				actor.grid_position,
				destination,
				navigation,
				actor.diagonal_steps_used
			)
			if (
				path.success
				and path.path.size() >= 3
				and path.cost_feet <= actor.action_budget.remaining_turn_capacity_feet
			):
				return path
	return null


static func _clear_actor_inventory_to_ground(
		state: TacticalState,
		actor: TacticalUnitState
) -> void:
	for item: TacticalItemInstanceState in state.get_items():
		if item.location == null or item.location.owner_id != actor.unit_id:
			continue
		if item.location.location_type not in [
			TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
			TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
		]:
			continue
		item.location = TacticalItemLocationState.ground(actor.grid_position, "Test setup")
	state.rebuild_ground_item_index()


static func _clear_hands_to_ground(
		state: TacticalState,
		actor: TacticalUnitState
) -> void:
	for hand_kind: StringName in [
		TacticalInventoryState.KIND_PRIMARY_HAND,
		TacticalInventoryState.KIND_SECONDARY_HAND,
	]:
		var item: TacticalItemInstanceState = state.get_hand_item(actor.unit_id, hand_kind)
		if item != null:
			item.location = TacticalItemLocationState.ground(actor.grid_position, "Test setup")
	state.rebuild_ground_item_index()


static func _find_owned_item(
		state: TacticalState,
		owner_id: StringName,
		definition_id: StringName
) -> TacticalItemInstanceState:
	for item: TacticalItemInstanceState in state.get_items():
		if item.definition_id == definition_id and item.location != null and item.location.owner_id == owner_id:
			return item
	return null


static func _find_item(
		state: TacticalState,
		definition_id: StringName,
		preferred_item_id: StringName = &""
) -> TacticalItemInstanceState:
	if not preferred_item_id.is_empty():
		var preferred: TacticalItemInstanceState = state.get_item(preferred_item_id)
		if preferred != null:
			return preferred
	for item: TacticalItemInstanceState in state.get_items():
		if item.definition_id == definition_id:
			return item
	return null


static func _first_ordinary_item_on_ground(
		state: TacticalState,
		cell: Vector2i
) -> TacticalItemInstanceState:
	for item: TacticalItemInstanceState in state.get_ground_items():
		if item.is_body() or item.location.map_position != cell:
			continue
		if item.footprint.x <= 5 and item.footprint.y <= 4:
			return item
	return null


static func _max_axis_distance(a: Vector2i, b: Vector2i) -> int:
	var delta: Vector2i = a - b
	return maxi(absi(delta.x), absi(delta.y))


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
