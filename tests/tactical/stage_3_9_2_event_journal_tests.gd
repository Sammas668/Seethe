extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_session_starts_with_phase_event(failures)
	_test_movement_publishes_one_event(failures)
	_test_failed_movement_publishes_nothing(failures)
	_test_inventory_pickup_is_recorded(failures)
	_test_same_grid_rearrangement_is_not_recorded(failures)
	_test_phase_changes_are_recorded(failures)
	_test_filters_and_hidden_visibility(failures)
	_test_returned_events_are_copies(failures)
	return failures


static func _test_session_starts_with_phase_event(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var events: Array = session.event_journal.call(
		"events",
		&"all",
		false
	)
	_expect(
		events.size() == 1,
		"A new tactical session should begin with exactly one visible phase event.",
		failures
	)
	if not events.is_empty():
		_expect(
			StringName(events[0].get("event_type", &""))
			== &"phase_started",
			"The first journal entry should be a phase-start event.",
			failures
		)


static func _test_movement_publishes_one_event(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var before := int(session.event_journal.call("event_count", true))

	var result := session.movement_handler.execute_move(
		MoveCommand.new(
			TacticalSandboxFactory.MARAUDER_ID,
			Vector2i(2, 1)
		)
	)
	_expect(result.success, "Journal movement fixture should succeed.", failures)

	var after := int(session.event_journal.call("event_count", true))
	_expect(
		after == before + 1,
		"One committed move should create exactly one journal event.",
		failures
	)

	var latest: Dictionary = session.event_journal.call(
		"latest_event",
		&"all",
		false
	)
	_expect(
		StringName(latest.get("event_type", &"")) == &"movement",
		"Committed movement should publish a movement event.",
		failures
	)
	_expect(
		String(latest.get("summary", "")).contains("moved"),
		"Movement summary should explain what happened.",
		failures
	)


static func _test_failed_movement_publishes_nothing(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var before := int(session.event_journal.call("event_count", true))

	var result := session.movement_handler.execute_move(
		MoveCommand.new(
			TacticalSandboxFactory.MARAUDER_ID,
			Vector2i(-1, -1)
		)
	)
	_expect(not result.success, "Out-of-bounds movement should fail.", failures)

	var after := int(session.event_journal.call("event_count", true))
	_expect(
		after == before,
		"A failed movement command must not create a committed event.",
		failures
	)


static func _test_inventory_pickup_is_recorded(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var before := int(session.event_journal.call("event_count", true))

	var result := session.inventory_transfer_handler.execute(
		TacticalInventoryTransferCommand.new(
			TacticalSandboxFactory.MARAUDER_ID,
			TacticalItemLocationState.CONTAINER_GROUND,
			&"instance.ground.spear",
			TacticalInventoryState.KIND_SECONDARY_HAND,
			-1
		)
	)
	_expect(result.success, "Ground spear pickup should succeed.", failures)

	var after := int(session.event_journal.call("event_count", true))
	_expect(
		after == before + 1,
		"A committed ground pickup should create one journal event.",
		failures
	)

	var latest: Dictionary = session.event_journal.call(
		"latest_event",
		&"all",
		false
	)
	_expect(
		StringName(latest.get("event_type", &""))
		== &"inventory_transfer",
		"The pickup should publish an inventory-transfer event.",
		failures
	)
	_expect(
		String(latest.get("summary", "")).contains("picked up"),
		"Pickup summary should state that the item was picked up.",
		failures
	)


static func _test_same_grid_rearrangement_is_not_recorded(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var before := int(session.event_journal.call("event_count", true))

	var result := session.inventory_transfer_handler.execute(
		TacticalInventoryTransferCommand.new(
			TacticalSandboxFactory.MARAUDER_ID,
			TacticalInventoryState.KIND_BACKPACK,
			&"instance.marauder.manacles",
			TacticalInventoryState.KIND_BACKPACK,
			20
		)
	)
	_expect(
		result.success,
		"Free Backpack rearrangement fixture should succeed.",
		failures
	)

	var after := int(session.event_journal.call("event_count", true))
	_expect(
		after == before,
		"Free rearrangement within the same grid should not clutter the log.",
		failures
	)


static func _test_phase_changes_are_recorded(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var before := int(session.event_journal.call("event_count", true))

	var begin_result := session.end_phase_handler.begin_world_phase(
		EndPhaseCommand.new()
	)
	_expect(begin_result.success, "World Phase should begin.", failures)

	var complete_result := session.end_phase_handler.complete_world_phase()
	_expect(
		complete_result.success,
		"The next Player Phase should begin.",
		failures
	)

	var after := int(session.event_journal.call("event_count", true))
	_expect(
		after == before + 2,
		"A complete phase cycle should record World and Player phase events.",
		failures
	)


static func _test_filters_and_hidden_visibility(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var journal := session.event_journal

	journal.call(
		"record_event",
		&"attack",
		1,
		&"player",
		"Visible attack fixture.",
		{
			"category": &"combat",
			"roll_records": [
				{
					"roll_type": &"attack",
					"dice_expression": "1d20",
					"die_results": [12],
					"modifiers": [],
					"final_total": 12,
					"opposing_value": 10,
					"outcome": &"hit",
				},
			],
		}
	)
	journal.call(
		"record_event",
		&"hidden_check",
		1,
		&"world",
		"Hidden trap check.",
		{
			"category": &"rolls",
			"visibility": &"hidden",
		}
	)

	var combat_events: Array = journal.call("events", &"combat", false)
	var roll_events: Array = journal.call("events", &"rolls", false)
	var visible_events: Array = journal.call("events", &"all", false)
	var all_events: Array = journal.call("events", &"all", true)

	_expect(
		combat_events.size() == 1,
		"Combat filter should return the visible combat event.",
		failures
	)
	_expect(
		roll_events.size() == 1,
		"Roll filter should include events containing roll records.",
		failures
	)
	_expect(
		all_events.size() == visible_events.size() + 1,
		"Hidden events must remain unavailable to the player-facing log.",
		failures
	)


static func _test_returned_events_are_copies(
		failures: Array[String]
) -> void:
	var session := TacticalSandboxFactory.create_session(false)
	var first: Dictionary = session.event_journal.call(
		"latest_event",
		&"all",
		false
	)
	first["summary"] = "Corrupted external copy."

	var second: Dictionary = session.event_journal.call(
		"latest_event",
		&"all",
		false
	)
	_expect(
		String(second.get("summary", ""))
		!= "Corrupted external copy.",
		"Callers must not be able to mutate the stored journal history.",
		failures
	)


static func _expect(
		condition: bool,
		failure_message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(failure_message)
