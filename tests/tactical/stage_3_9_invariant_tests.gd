class_name Stage39InvariantTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_catalogue_is_valid(failures)
	_test_item_identity_round_trip(failures)
	_test_planning_rejection_is_atomic(failures)
	_test_post_commit_failure_rolls_back(failures)
	_test_two_handed_reserves_secondary(failures)
	_test_stack_quantity_survives_transfer(failures)
	_test_stack_rules_reject_invalid_quantities(failures)
	_test_duplicate_item_ids_are_rejected(failures)
	_test_weight_is_derived(failures)
	_test_same_grid_rearrangement_is_free(failures)
	_test_ground_access_range(failures)
	_test_dynamic_occupancy_blocks_paths(failures)
	_test_invalid_unit_placements_are_rejected(failures)
	_test_unit_validator_detects_corruption(failures)
	_test_item_location_validator_is_exhaustive(failures)
	_test_transfer_replay_cannot_duplicate(failures)
	_test_stale_transfer_plan_is_rejected(failures)
	_test_typed_actions_come_from_equipment(failures)
	return failures


static func _test_catalogue_is_valid(failures: Array[String]) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	_expect(
		session.content_catalogue.validate_catalogue().is_empty(),
		"The sandbox ContentCatalogue must validate without errors.",
		failures
	)
	_expect(
		session.validate_session().is_empty(),
		"The complete TacticalSession must satisfy all invariants.",
		failures
	)


static func _test_item_identity_round_trip(failures: Array[String]) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	var unit_id := TacticalSandboxFactory.MARAUDER_ID
	var item_id: StringName = &"instance.ground.spear"

	var pickup := TacticalInventoryTransferCommand.new(
		unit_id,
		TacticalItemLocationState.CONTAINER_GROUND,
		item_id,
		TacticalInventoryState.KIND_SECONDARY_HAND,
		-1
	)
	var result := session.inventory_transfer_handler.execute(pickup)
	_expect(result.success, "Ground → Hand should succeed.", failures)
	_expect(
		state.get_item(item_id) != null,
		"Picked-up item must keep the same ID.",
		failures
	)

	var drop := TacticalInventoryTransferCommand.new(
		unit_id,
		TacticalInventoryState.KIND_SECONDARY_HAND,
		item_id,
		TacticalItemLocationState.CONTAINER_GROUND,
		-1
	)
	result = session.inventory_transfer_handler.execute(drop)
	_expect(result.success, "Hand → Ground should succeed.", failures)
	var item := state.get_item(item_id)
	_expect(item != null, "Dropped item must keep the same ID.", failures)
	if item != null:
		_expect(
			item.location.location_type
			== TacticalItemLocationState.LOCATION_TACTICAL_GROUND,
			"Round-trip item must end on tactical ground.",
			failures
		)


static func _test_planning_rejection_is_atomic(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	var unit := state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var item := state.get_item(&"instance.ground.grain_crate")
	var before_location := item.location.clone()
	var before_capacity := unit.action_budget.remaining_turn_capacity_feet
	var before_quick := unit.action_budget.quick_action_available

	var command := TacticalInventoryTransferCommand.new(
		unit.unit_id,
		TacticalItemLocationState.CONTAINER_GROUND,
		item.item_id,
		TacticalInventoryState.KIND_BACKPACK,
		0
	)
	var result := session.inventory_transfer_handler.execute(command)
	_expect(not result.success, "Bulky crate transfer to Backpack must fail.", failures)
	_expect(
		item.location.matches(before_location),
		"Rejected plan must preserve item location.",
		failures
	)
	_expect(
		unit.action_budget.remaining_turn_capacity_feet == before_capacity,
		"Rejected plan must preserve normal capacity.",
		failures
	)
	_expect(
		unit.action_budget.quick_action_available == before_quick,
		"Rejected plan must preserve Quick Action.",
		failures
	)


static func _test_post_commit_failure_rolls_back(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	var unit := state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var item := state.get_item(&"instance.ground.spear")
	var before_location := item.location.clone()
	var before_capacity := unit.action_budget.remaining_turn_capacity_feet
	var before_quick := unit.action_budget.quick_action_available
	var before_revision := state.revision

	session.inventory_transfer_handler.set_post_commit_test_hook_for_tests(
		func(
				_state: TacticalState,
				_unit: TacticalUnitState,
				_item: TacticalItemInstanceState,
				_plan: TacticalInventoryTransferPlan
		) -> String:
			return "Forced post-commit test failure."
	)

	var command := TacticalInventoryTransferCommand.new(
		unit.unit_id,
		TacticalItemLocationState.CONTAINER_GROUND,
		item.item_id,
		TacticalInventoryState.KIND_SECONDARY_HAND,
		-1
	)
	var result := session.inventory_transfer_handler.execute(command)
	_expect(not result.success, "Forced post-commit failure must reject transfer.", failures)
	_expect(item.location.matches(before_location), "Rollback must restore item location.", failures)
	_expect(
		unit.action_budget.remaining_turn_capacity_feet == before_capacity,
		"Rollback must restore normal capacity.",
		failures
	)
	_expect(
		unit.action_budget.quick_action_available == before_quick,
		"Rollback must restore Quick Action.",
		failures
	)
	_expect(state.revision == before_revision, "Rollback must restore revision.", failures)
	var original_ids: Array = state.ground_item_ids_by_cell.get(
		before_location.map_position,
		[]
	)
	_expect(
		original_ids.has(item.item_id),
		"Rollback must restore the original ground index.",
		failures
	)


static func _test_two_handed_reserves_secondary(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var command := TacticalInventoryTransferCommand.new(
		TacticalSandboxFactory.ARCHER_ID,
		TacticalInventoryState.KIND_BACKPACK,
		&"instance.archer.dagger",
		TacticalInventoryState.KIND_SECONDARY_HAND,
		-1
	)
	var result := session.inventory_transfer_handler.execute(command)
	_expect(
		not result.success,
		"Secondary Hand must reject an item while a two-handed Primary item is equipped.",
		failures
	)


static func _test_stack_quantity_survives_transfer(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	state.set_unit_position(
		TacticalSandboxFactory.MARAUDER_ID,
		Vector2i(3, 3),
		session.map_definition
	)
	var item := state.get_item(&"instance.ground.bandages")
	var target_index := session.inventory_transfer_handler.first_fit_for_item(
		TacticalSandboxFactory.MARAUDER_ID,
		item,
		TacticalInventoryState.KIND_BACKPACK
	)
	var command := TacticalInventoryTransferCommand.new(
		TacticalSandboxFactory.MARAUDER_ID,
		TacticalItemLocationState.CONTAINER_GROUND,
		item.item_id,
		TacticalInventoryState.KIND_BACKPACK,
		target_index
	)
	var result := session.inventory_transfer_handler.execute(command)
	_expect(result.success, "Bandage stack pickup should succeed.", failures)
	_expect(item.quantity == 2, "Stack quantity must remain 2 after pickup.", failures)


static func _test_stack_rules_reject_invalid_quantities(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state

	var spear := state.get_item(&"instance.ground.spear")
	spear.quantity = 2
	var errors := state.validate_item_invariants(session.map_definition)
	_expect(
		_contains_text(errors, "Non-stackable item"),
		"Validator must reject stacked non-stackable equipment.",
		failures
	)

	spear.quantity = 1
	var bandages := state.get_item(&"instance.ground.bandages")
	bandages.quantity = bandages.definition.maximum_stack_size + 1
	errors = state.validate_item_invariants(session.map_definition)
	_expect(
		_contains_text(errors, "exceeds maximum stack size"),
		"Validator must reject stacks above their authored maximum.",
		failures
	)


static func _test_duplicate_item_ids_are_rejected(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	var existing := state.get_item(&"instance.marauder.axe")
	var duplicate := TacticalItemInstanceState.new(
		existing.item_id,
		existing.definition,
		1,
		1.0,
		TacticalItemLocationState.ground(Vector2i.ZERO)
	)
	_expect(
		not state.add_item(duplicate, session.map_definition),
		"Duplicate item IDs must be rejected.",
		failures
	)


static func _test_weight_is_derived(failures: Array[String]) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	var total := 0.0
	for item: TacticalItemInstanceState in state.get_items():
		if item.location.owner_id == TacticalSandboxFactory.MARAUDER_ID:
			total += item.weight_lb
	_expect(
		is_equal_approx(
			total,
			state.calculated_carried_weight(TacticalSandboxFactory.MARAUDER_ID)
		),
		"Calculated weight must equal the authoritative carried-item sum.",
		failures
	)


static func _test_same_grid_rearrangement_is_free(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	var unit := state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var before_capacity := unit.action_budget.remaining_turn_capacity_feet
	var command := TacticalInventoryTransferCommand.new(
		unit.unit_id,
		TacticalInventoryState.KIND_BACKPACK,
		&"instance.marauder.manacles",
		TacticalInventoryState.KIND_BACKPACK,
		20
	)
	var result := session.inventory_transfer_handler.execute(command)
	_expect(result.success, "Same-grid rearrangement should succeed.", failures)
	_expect(
		unit.action_budget.remaining_turn_capacity_feet == before_capacity,
		"Same-grid rearrangement must be free.",
		failures
	)


static func _test_ground_access_range(failures: Array[String]) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	var item := state.get_item(&"instance.ground.spear")
	item.location.map_position = Vector2i(10, 10)
	state.rebuild_ground_item_index()
	var command := TacticalInventoryTransferCommand.new(
		TacticalSandboxFactory.MARAUDER_ID,
		TacticalItemLocationState.CONTAINER_GROUND,
		item.item_id,
		TacticalInventoryState.KIND_SECONDARY_HAND,
		-1
	)
	var result := session.inventory_transfer_handler.execute(command)
	_expect(not result.success, "Items beyond local reach must not be picked up.", failures)


static func _test_dynamic_occupancy_blocks_paths(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	var mover := state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var blocker := state.get_unit(TacticalSandboxFactory.SCOUT_ID)
	state.set_unit_position(mover.unit_id, Vector2i(1, 1), session.map_definition)
	state.set_unit_position(blocker.unit_id, Vector2i(2, 1), session.map_definition)
	var navigation := session.navigation_for(mover.unit_id)
	var result := MovementRules.find_path(
		mover.grid_position,
		Vector2i(3, 1),
		navigation,
		mover.diagonal_steps_used
	)
	_expect(result.success, "Pathfinder should route around an occupied tile.", failures)
	if result.success:
		_expect(
			not result.path.has(Vector2i(2, 1)),
			"Path must not cross another actor's occupied tile.",
			failures
		)


static func _test_invalid_unit_placements_are_rejected(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	var marauder := state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var scout := state.get_unit(TacticalSandboxFactory.SCOUT_ID)
	var before := marauder.grid_position

	_expect(
		not state.set_unit_position(
			marauder.unit_id,
			scout.grid_position,
			session.map_definition
		),
		"Movement must reject an overlapping destination.",
		failures
	)
	_expect(marauder.grid_position == before, "Rejected overlap must not move unit.", failures)
	_expect(
		not state.set_unit_position(
			marauder.unit_id,
			Vector2i(-1, 0),
			session.map_definition
		),
		"Movement must reject out-of-bounds placement.",
		failures
	)
	_expect(
		not state.set_unit_position(
			marauder.unit_id,
			Vector2i(8, 2),
			session.map_definition
		),
		"Movement must reject statically blocked terrain.",
		failures
	)


static func _test_unit_validator_detects_corruption(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	var marauder := state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var scout := state.get_unit(TacticalSandboxFactory.SCOUT_ID)
	scout.grid_position = marauder.grid_position
	scout.footprint = Vector2i.ZERO
	state.rebuild_unit_occupancy()
	var errors := state.validate_unit_invariants(session.map_definition)
	_expect(
		_contains_text(errors, "non-positive footprint"),
		"Unit validator must reject non-positive footprints.",
		failures
	)

	scout.footprint = Vector2i.ONE
	state.rebuild_unit_occupancy()
	errors = state.validate_unit_invariants(session.map_definition)
	_expect(
		_contains_text(errors, "overlap"),
		"Unit validator must detect overlapping footprints.",
		failures
	)


static func _test_item_location_validator_is_exhaustive(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	var item := state.get_item(&"instance.ground.spear")

	item.location.location_type = &"unknown_location"
	var errors := state.validate_item_invariants(session.map_definition)
	_expect(
		_contains_text(errors, "unknown location type"),
		"Item validator must reject unknown location types.",
		failures
	)

	item.location = TacticalItemLocationState.ground(Vector2i(99, 99))
	item.location.owner_id = TacticalSandboxFactory.MARAUDER_ID
	errors = state.validate_item_invariants(session.map_definition)
	_expect(
		_contains_text(errors, "still has an owner"),
		"Ground items must not retain an owner.",
		failures
	)
	_expect(
		_contains_text(errors, "outside the tactical map"),
		"Ground items outside the map must be rejected.",
		failures
	)

	item.location = TacticalItemLocationState.unit_grid(
		TacticalSandboxFactory.MARAUDER_ID,
		&"unknown_container",
		Vector2i.ZERO
	)
	errors = state.validate_item_invariants(session.map_definition)
	_expect(
		_contains_text(errors, "invalid inventory container"),
		"Unit inventory items must use Belt or Backpack.",
		failures
	)


static func _test_transfer_replay_cannot_duplicate(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var command := TacticalInventoryTransferCommand.new(
		TacticalSandboxFactory.MARAUDER_ID,
		TacticalItemLocationState.CONTAINER_GROUND,
		&"instance.ground.spear",
		TacticalInventoryState.KIND_SECONDARY_HAND,
		-1
	)
	var item_count_before := session.state_store.state.items_by_id.size()
	var first := session.inventory_transfer_handler.execute(command)
	var second := session.inventory_transfer_handler.execute(command)
	_expect(first.success, "First transfer should succeed.", failures)
	_expect(not second.success, "Replaying the same command must fail.", failures)
	_expect(
		session.state_store.state.items_by_id.size() == item_count_before,
		"Transfer replay must not create another item instance.",
		failures
	)


static func _test_stale_transfer_plan_is_rejected(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	var unit := state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var item := state.get_item(&"instance.ground.spear")
	var command := TacticalInventoryTransferCommand.new(
		unit.unit_id,
		TacticalItemLocationState.CONTAINER_GROUND,
		item.item_id,
		TacticalInventoryState.KIND_SECONDARY_HAND,
		-1
	)
	var preview := session.inventory_transfer_handler.preview(command)
	_expect(preview.success, "Stale-plan test requires a valid preview.", failures)
	if not preview.success:
		return

	var source_before := item.location.clone()
	var capacity_before := unit.action_budget.remaining_turn_capacity_feet
	var revision_change: TacticalChangeSet = TacticalChangeSet.new(
		&"test_revision_change",
		state.revision
	)
	session.state_store.commit(revision_change, session.map_definition)
	var result := session.inventory_transfer_handler.execute_plan(
		preview.plan,
		preview
	)
	_expect(not result.success, "A stale transfer plan must be rejected.", failures)
	_expect(item.location.matches(source_before), "Stale plan must not move item.", failures)
	_expect(
		unit.action_budget.remaining_turn_capacity_feet == capacity_before,
		"Stale plan must not spend capacity.",
		failures
	)


static func _test_typed_actions_come_from_equipment(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var state := session.state_store.state
	var action_ids := state.granted_action_ids_for_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_expect(
		action_ids.has(&"action.training_axe_attack"),
		"Equipped Training Axe must grant its typed attack.",
		failures
	)
	_expect(
		action_ids.has(&"action.unarmed_strike"),
		"Character sheet innate actions must remain available.",
		failures
	)
	var attack := session.content_catalogue.attack_definition(
		&"action.training_axe_attack"
	)
	_expect(attack != null, "Training Axe action must resolve as AttackDefinition.", failures)
	if attack != null:
		_expect(
			attack.damage_profile.notation() == "1d8",
			"Training Axe damage must come from its typed DamageProfile.",
			failures
		)


static func _contains_text(entries: Array[String], fragment: String) -> bool:
	for entry: String in entries:
		if fragment.to_lower() in entry.to_lower():
			return true
	return false


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
