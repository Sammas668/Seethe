class_name Stage44e2CriticalInteractionCoverMovementTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_runtime_map_index_matches_authored_map(failures)
	_test_local_wall_cover_uses_full_shield_category(failures)
	_test_committed_result_cannot_be_reported_as_rejected(failures)
	_test_closed_door_is_a_separate_movement_boundary(failures)
	_test_exploration_batch_commits_through_state_store(failures)
	_test_edge_native_interaction_hit_target(failures)
	return failures


static func _test_runtime_map_index_matches_authored_map(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var map_definition: TacticalMapDefinition = session.map_definition
	_expect(
		map_definition.runtime_index() != null,
		"Mission assembly must compile a tactical-map runtime index.",
		failures
	)
	_expect(
		map_definition.is_wall(Vector2i(8, 2)),
		"Compiled tile flags must preserve authored stone walls.",
		failures
	)
	var opening: TacticalOpeningDefinition = map_definition.opening_at_edge(
		Vector2i(10, 4),
		Vector2i(11, 4)
	)
	_expect(
		opening != null and opening.opening_id == &"opening.farm.ordinary_door",
		"Compiled edge lookup must resolve the authored ordinary door directly.",
		failures
	)


static func _test_local_wall_cover_uses_full_shield_category(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var defended_tile := Vector2i(7, 2)
	state.knowledge_state.mark_many_explored(
		&"player",
		[defended_tile, Vector2i(8, 2)]
	)
	TacticalLocalCoverQuery.clear_cache()
	var local: TacticalLocalCoverResult = TacticalLocalCoverQuery.evaluate_position(
		state,
		session.map_definition,
		defended_tile,
		&"player"
	)
	_expect(
		local.strongest_local_cover == TacticalCombatGeometryResult.COVER_HEAVY,
		"A substantial adjacent wall must produce the full-shield local cover category.",
		failures
	)
	_expect(
		local.category_for(Vector2i.RIGHT) == TacticalCombatGeometryResult.COVER_HEAVY,
		"The local cover query must preserve the wall's protected direction.",
		failures
	)


static func _test_committed_result_cannot_be_reported_as_rejected(
		failures: Array[String]
) -> void:
	var result: OperationResult = OperationResult.committed(
		&"payload",
		"Committed.",
		12
	)
	_expect(result.success, "Committed command results must remain successful.", failures)
	_expect(
		result.commit_status == OperationResult.STATUS_COMMITTED,
		"Committed commands must be distinguishable from pre-commit rejection.",
		failures
	)
	_expect(
		result.committed_revision == 12,
		"Committed results must preserve the authoritative revision.",
		failures
	)


static func _test_closed_door_is_a_separate_movement_boundary(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var unit: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	_expect(unit != null, "Door movement test requires the Marauder.", failures)
	if unit == null:
		return
	var near_tile := Vector2i(10, 4)
	var far_tile := Vector2i(11, 4)
	state.set_unit_position(unit.unit_id, near_tile, session.map_definition, false)
	state.knowledge_state.mark_many_explored(&"player", [near_tile, far_tile])
	var opening: TacticalOpeningState = state.environment_state.opening_state(
		&"opening.farm.ordinary_door"
	)
	_expect(opening != null and not opening.is_open(), "Door fixture must begin closed.", failures)
	if opening == null:
		return
	session.screen_facade.begin_visibility_recalculation_deferral()
	var result: OperationResult = session.screen_facade.execute_movement(
		unit.unit_id,
		far_tile,
		&"normal"
	)
	session.screen_facade.end_visibility_recalculation_deferral()
	_expect(result.success, "Opening a route door must commit successfully.", failures)
	_expect(opening.is_open(), "The movement boundary must open the door.", failures)
	_expect(
		unit.grid_position == near_tile,
		"The unit must remain on the near side until detection uses open-door geometry.",
		failures
	)


static func _test_exploration_batch_commits_through_state_store(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var tile := Vector2i(63, 63)
	var revision_before: int = state.revision
	session.visibility_service.set(
		"_pending_explored_by_team",
		{&"player": {tile: true}}
	)
	session.visibility_service.call("_commit_exploration_batch")
	_expect(
		state.revision == revision_before + 1,
		"Explored mission knowledge must commit through TacticalStateStore.",
		failures
	)
	_expect(
		state.is_tile_explored(&"player", tile),
		"Committed exploration must remain authoritative mission state.",
		failures
	)


static func _test_edge_native_interaction_hit_target(
		failures: Array[String]
) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		failures.append("Interaction hit testing requires a SceneTree.")
		return
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var unit: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	if unit == null:
		failures.append("Interaction hit test requires the Marauder.")
		return
	state.set_unit_position(unit.unit_id, Vector2i(10, 4), session.map_definition, false)
	var board := TacticalBoardView.new()
	tree.root.add_child(board)
	board.configure(session.map_definition, session.screen_facade)
	board.update_presentation(
		unit.unit_id,
		Vector2i(10, 4),
		null,
		&"normal",
		false,
		[],
		&"",
		null,
		Vector2i.ZERO,
		null,
		null,
		&"",
		null,
		null,
		true
	)
	var midpoint: Vector2 = board.call(
		"_edge_midpoint",
		Vector2i(10, 4),
		Vector2i(11, 4)
	)
	var target: Dictionary = board.call(
		"_interaction_target_at_screen_position",
		board.to_global(midpoint)
	)
	_expect(
		StringName(target.get("target_id", &"")) == &"opening.farm.ordinary_door",
		"Interact hit testing must return the exact highlighted edge feature ID.",
		failures
	)
	board.queue_free()


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
