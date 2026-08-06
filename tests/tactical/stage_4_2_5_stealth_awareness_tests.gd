class_name Stage425StealthAwarenessTests
extends RefCounted

const TacticalGridDistance: Script = preload(
	"res://domain/tactical/tactical_grid_distance.gd"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_unified_grid_distance_and_perception_ranges(failures)
	_test_cone_and_wall_blocking(failures)
	_test_close_awareness_uses_a_bonus_not_automatic_detection(failures)
	_test_per_tile_preview_rolls_and_interruption(failures)
	_test_stealth_detection_initiative_and_ai(failures)
	_test_lost_sight_rehide_search_and_return(failures)
	return failures


static func _test_unified_grid_distance_and_perception_ranges(
		failures: Array[String]
) -> void:
	var origin := Vector2i(10, 10)
	_expect(
		TacticalGridDistance.steps_between(origin, Vector2i(10, 35)) == 25,
		"Twenty-five orthogonal squares must measure as 25 grid steps.",
		failures
	)
	_expect(
		TacticalGridDistance.steps_between(origin, Vector2i(20, 25)) == 25,
		"Grid distance must add horizontal and vertical offsets.",
		failures
	)
	_expect(
		TacticalGridDistance.steps_between(origin, Vector2i(11, 11)) == 2,
		"A diagonal neighbour must count as two grid steps.",
		failures
	)
	_expect(
		TacticalGridDistance.steps_between(origin, Vector2i(30, 30)) == 40,
		"The aware sight boundary example must measure 40 grid steps.",
		failures
	)
	_expect(
		TacticalGridDistance.steps_between(origin, Vector2i(31, 30)) == 41,
		"The tile beyond the aware sight boundary must measure 41 grid steps.",
		failures
	)

	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var guard: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	if guard == null:
		failures.append("The unified perception fixture needs Guard A.")
		return
	var open_map := TacticalMapDefinition.new()
	open_map.grid_size = Vector2i(80, 80)
	guard.grid_position = Vector2i(30, 30)
	guard.set_facing(Vector2i(0, 1))
	_expect(
		TacticalPerceptionRules.focused_range_tiles(guard) == 25,
		"An unaware guard's focused cone must have a fixed 25-square range.",
		failures
	)
	_expect(
		TacticalPerceptionRules.is_in_focused_cone(
			guard,
			Vector2i(30, 55),
			open_map
		),
		"The forward cone must include its 25-square boundary.",
		failures
	)
	_expect(
		not TacticalPerceptionRules.is_in_focused_cone(
			guard,
			Vector2i(30, 56),
			open_map
		),
		"The forward cone must exclude tiles beyond 25 grid steps.",
		failures
	)
	_expect(
		TacticalPerceptionRules.is_close_awareness(
			guard,
			Vector2i(31, 30),
			open_map
		),
		"Close awareness must include one orthogonal square.",
		failures
	)
	_expect(
		not TacticalPerceptionRules.is_close_awareness(
			guard,
			Vector2i(31, 31),
			open_map
		),
		"Close awareness must exclude a diagonal tile because it is two grid steps away.",
		failures
	)
	_expect(
		TacticalPerceptionRules.is_in_aware_radius(
			guard,
			Vector2i(50, 50),
			open_map
		),
		"Aware perception must include the 40-square all-around boundary.",
		failures
	)
	_expect(
		not TacticalPerceptionRules.is_in_aware_radius(
			guard,
			Vector2i(51, 50),
			open_map
		),
		"Aware perception must exclude tiles beyond 40 grid steps.",
		failures
	)


static func _test_cone_and_wall_blocking(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var guard: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	_expect(guard != null, "The perception fixture needs Guard A.", failures)
	if guard == null:
		return
	state.set_unit_position(guard.unit_id, Vector2i(7, 2), session.map_definition, false)
	guard.set_facing(Vector2i(1, 0))
	_expect(
		not TacticalPerceptionRules.is_in_focused_cone(
			guard,
			Vector2i(9, 2),
			session.map_definition
		),
		"The stone wall at (8, 2) must block Guard A's focused cone.",
		failures
	)
	_expect(
		not TacticalPerceptionRules.is_in_focused_cone(
			guard,
			Vector2i(6, 2),
			session.map_definition
		),
		"A tile behind an unaware guard must be outside its focused cone.",
		failures
	)


static func _test_close_awareness_uses_a_bonus_not_automatic_detection(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var facade = session.screen_facade
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var guard_a: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var guard_b: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_TWO_ID)
	if marauder == null or guard_a == null or guard_b == null:
		failures.append("The close-awareness fixture is incomplete.")
		return

	state.set_unit_position(marauder.unit_id, Vector2i(10, 12), session.map_definition, false)
	state.set_unit_position(guard_a.unit_id, Vector2i(10, 10), session.map_definition, false)
	state.set_unit_position(guard_b.unit_id, Vector2i(40, 40), session.map_definition, false)
	# The Marauder begins two grid steps behind the guard, outside both the
	# focused cone and the one-square close-awareness radius.
	guard_a.set_facing(Vector2i(0, -1))
	session.visibility_service.call("recalculate_all_teams")

	var stealth_result: OperationResult = facade.enter_stealth(marauder.unit_id)
	_expect(stealth_result.success, "The Marauder must enter Stealth before approaching closely.", failures)
	var movement: MovementPathResult = facade.preview_movement(
		marauder.unit_id,
		Vector2i(10, 11)
	)
	var preview: MovementDetectionPreview = facade.preview_movement_detection(
		marauder.unit_id,
		movement
	)
	var expected_dc: int = TacticalPerceptionRules.passive_perception(guard_a) + 4
	var expected_avoid: int = TacticalPerceptionRules.avoid_detection_chance_percent(
		marauder.stealth_bonus(),
		expected_dc
	)
	_expect(movement.success, "The close-awareness test tile must be reachable.", failures)
	_expect(preview.requires_roll, "Close awareness must require the normal Stealth roll.", failures)
	_expect(preview.tile_previews.size() == 1, "The close-awareness path must mark its risky tile.", failures)
	_expect(not preview.automatic_detection, "Close awareness must not cause automatic detection.", failures)
	_expect(preview.effective_detection_dc == expected_dc, "Close awareness must add +4 to the guard's Detection DC.", failures)
	_expect(
		preview.avoid_detection_chance_percent == expected_avoid,
		"The close-awareness tile must show the chance to avoid detection.",
		failures
	)


static func _test_per_tile_preview_rolls_and_interruption(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var facade = session.screen_facade
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var guard_a: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var guard_b: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_TWO_ID)
	if marauder == null or guard_a == null or guard_b == null:
		failures.append("The per-tile Stealth fixture is incomplete.")
		return

	state.set_unit_position(marauder.unit_id, Vector2i(10, 20), session.map_definition, false)
	state.set_unit_position(guard_a.unit_id, Vector2i(20, 25), session.map_definition, false)
	state.set_unit_position(guard_b.unit_id, Vector2i(40, 40), session.map_definition, false)
	guard_a.set_facing(Vector2i(0, -1))
	guard_b.set_facing(Vector2i(1, 0))
	session.visibility_service.call("recalculate_all_teams")

	var stealth_result: OperationResult = facade.enter_stealth(marauder.unit_id)
	_expect(stealth_result.success, "The per-tile fixture must enter Stealth.", failures)
	var path: MovementPathResult = facade.preview_movement(
		marauder.unit_id,
		Vector2i(20, 20)
	)
	var preview: MovementDetectionPreview = facade.preview_movement_detection(
		marauder.unit_id,
		path
	)
	_expect(path.success, "The per-tile Stealth route must be reachable.", failures)
	_expect(
		preview.tile_previews.size() >= 2,
		"The route must show avoidance percentages on at least two risky squares.",
		failures
	)
	if preview.tile_previews.size() < 2:
		return
	for tile_preview: MovementDetectionTilePreview in preview.tile_previews:
		_expect(
			tile_preview.requires_roll,
			"Every marked Stealth trail square must represent its own check.",
			failures
		)
		_expect(
			tile_preview.avoid_detection_chance_percent >= 0
			and tile_preview.avoid_detection_chance_percent <= 100,
			"Every marked square must expose a valid avoidance percentage.",
			failures
		)

	var scripted_rolls: Array[int] = [20, 1]
	var participant_count: int = state.get_player_units().size()
	participant_count += state.get_units_in_squad(
		TacticalSandboxFactory.GUARD_SQUAD_A_ID
	).size()
	for index: int in range(participant_count):
		scripted_rolls.append(maxi(1, 20 - index))
	session.combat_dice_roller.call("set_scripted_results", scripted_rolls)

	var expected_stop: Vector2i = preview.tile_previews[1].tile
	var result: OperationResult = facade.execute_movement(
		marauder.unit_id,
		Vector2i(20, 20),
		&"normal"
	)
	_expect(result.success, "Per-tile movement must commit through the failed square.", failures)
	var completed_path: MovementPathResult = result.data as MovementPathResult
	_expect(completed_path != null, "Interrupted movement must return its completed path.", failures)
	if completed_path != null:
		_expect(
			completed_path.path.back() == expected_stop,
			"Movement must stop on the first square whose Stealth roll fails.",
			failures
		)
		_expect(
			completed_path.path.size() < path.path.size(),
			"A failed intermediate Stealth roll must truncate the planned route.",
			failures
		)
	_expect(
		marauder.grid_position == expected_stop,
		"The unit state must finish on the failed Stealth square.",
		failures
	)

	var roll_events: Array = session.event_journal.call("events", &"rolls", false)
	_expect(
		roll_events.size() == 2,
		"The roll log must contain every Stealth roll made before interruption.",
		failures
	)
	if roll_events.size() >= 2:
		for event_value: Variant in roll_events:
			if not (event_value is Dictionary):
				continue
			var event: Dictionary = event_value
			var details: Array = event.get("details", [])
			var detail_lines: Array[String] = []
			for detail_value: Variant in details:
				detail_lines.append(str(detail_value))
			var detail_text: String = "\n".join(PackedStringArray(detail_lines))
			_expect(
				detail_text.contains("Raw d20:")
				and detail_text.contains("required natural roll"),
				"Every Stealth log entry must show the raw roll and required roll.",
				failures
			)
			var event_roll_records: Array = event.get("roll_records", [])
			_expect(
				not event_roll_records.is_empty(),
				"Every rolled Stealth tile must include structured roll records.",
				failures
			)


static func _test_stealth_detection_initiative_and_ai(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var facade = session.screen_facade
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var guard_a: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var guard_b: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_TWO_ID)
	_expect(marauder != null, "The awareness fixture needs the Marauder.", failures)
	_expect(guard_a != null, "The awareness fixture needs Guard A.", failures)
	_expect(guard_b != null, "The awareness fixture needs Guard B.", failures)
	if marauder == null or guard_a == null or guard_b == null:
		return

	state.set_unit_position(marauder.unit_id, Vector2i(10, 20), session.map_definition, false)
	state.set_unit_position(guard_a.unit_id, Vector2i(20, 25), session.map_definition, false)
	state.set_unit_position(guard_b.unit_id, Vector2i(40, 40), session.map_definition, false)
	guard_a.set_facing(Vector2i(0, -1))
	guard_b.set_facing(Vector2i(1, 0))
	session.visibility_service.call("recalculate_all_teams")

	var stealth_result: OperationResult = facade.enter_stealth(marauder.unit_id)
	_expect(stealth_result.success, "The Marauder must be able to enter Stealth outside guard awareness.", failures)
	_expect(marauder.shows_hidden_badge(), "Entering Stealth must enable the mask badge state.", failures)
	_expect(not marauder.action_budget.quick_action_available, "Entering Stealth must spend the Quick Action.", failures)

	var first_preview: MovementPathResult = facade.preview_movement(
		marauder.unit_id,
		Vector2i(20, 20)
	)
	var first_detection: MovementDetectionPreview = facade.preview_movement_detection(
		marauder.unit_id,
		first_preview
	)
	_expect(first_preview.success, "The first stealth route must be reachable.", failures)
	_expect(first_detection.requires_roll, "Entering Guard A's cone must preview a Stealth roll.", failures)
	_expect(
		first_detection.avoid_detection_chance_percent > 0
		and first_detection.avoid_detection_chance_percent < 100,
		"The risky tile must show a meaningful chance to avoid detection.",
		failures
	)

	var success_rolls: Array[int] = []
	for _tile_preview: MovementDetectionTilePreview in first_detection.tile_previews:
		success_rolls.append(20)
	session.combat_dice_roller.call("set_scripted_results", success_rolls)
	var hidden_move: OperationResult = facade.execute_movement(
		marauder.unit_id,
		Vector2i(20, 20),
		&"normal"
	)
	_expect(hidden_move.success, "The first stealth movement must commit.", failures)
	_expect(marauder.shows_hidden_badge(), "A successful Stealth check must preserve the mask badge.", failures)
	_expect(not state.is_squad_aware(TacticalSandboxFactory.GUARD_SQUAD_A_ID), "Guard Squad A must remain Unaware after a successful check.", failures)

	# One failed Stealth roll, five initiative rolls (three players plus both
	# members of Settlement Watch Squad A), then attack resolution dice.
	var alert_and_attack_rolls: Array[int] = [1, 20, 19, 18, 17, 16, 18, 6]
	session.combat_dice_roller.call(
		"set_scripted_results",
		alert_and_attack_rolls
	)
	var remaining_before_detection: int = marauder.action_budget.remaining_turn_capacity_feet
	var detected_move: OperationResult = facade.execute_movement(
		marauder.unit_id,
		Vector2i(20, 19),
		&"normal"
	)
	_expect(detected_move.success, "The detecting movement must still finish.", failures)
	_expect(state.is_squad_aware(TacticalSandboxFactory.GUARD_SQUAD_A_ID), "Guard Squad A must become Aware after the failed check.", failures)
	_expect(
		guard_a.squad_id == TacticalSandboxFactory.GUARD_SQUAD_A_ID
		and guard_b.squad_id == TacticalSandboxFactory.GUARD_SQUAD_A_ID,
		"The generated guard and archer must share Settlement Watch Squad A.",
		failures
	)
	_expect(
		state.phase_state.initiative_order.has(guard_a.unit_id)
		and state.phase_state.initiative_order.has(guard_b.unit_id),
		"Detection by either member must bring the whole authored squad into initiative.",
		failures
	)
	_expect(not state.is_squad_aware(TacticalSandboxFactory.GUARD_SQUAD_B_ID), "Guard Squad B must remain Unaware.", failures)
	_expect(marauder.is_revealed_to_squad(TacticalSandboxFactory.GUARD_SQUAD_A_ID), "The Marauder must be revealed only to Guard Squad A.", failures)
	_expect(not marauder.shows_hidden_badge(), "A detected unit must lose the mask badge.", failures)
	_expect(facade.is_initiative_combat(), "Failed detection must switch the battle to initiative.", failures)
	_expect(
		marauder.action_budget.remaining_turn_capacity_feet
		== remaining_before_detection - 5,
		"The contact round must preserve the movement already spent.",
		failures
	)
	_expect(
		not marauder.action_budget.quick_action_available,
		"The contact round must preserve the spent Quick Action.",
		failures
	)

	# Advance player initiatives without refreshing until Guard A is active.
	var safety: int = 0
	while facade.active_initiative_unit() != null and facade.active_initiative_unit().is_player_controlled():
		var active_player: TacticalUnitState = facade.active_initiative_unit()
		var advance: OperationResult = facade.end_initiative_turn(active_player.unit_id)
		_expect(advance.success, "A player contact-round turn must advance normally.", failures)
		safety += 1
		if safety > 5:
			break

	var active_enemy: TacticalUnitState = facade.active_initiative_unit()
	_expect(active_enemy == guard_a, "Only the aware guard must receive the first enemy initiative activation.", failures)
	if active_enemy != guard_a:
		return
	var hp_before: int = marauder.current_hp
	var guard_origin: Vector2i = guard_a.grid_position
	var ai_result: OperationResult = facade.resolve_active_ai_initiative()
	_expect(ai_result.success, "The aware guard AI activation must resolve.", failures)
	_expect(guard_a.grid_position != guard_origin, "The aware guard must move toward its closest revealed enemy.", failures)
	_expect(marauder.current_hp < hp_before, "The aware guard must attack the revealed Marauder when it can.", failures)


static func _test_lost_sight_rehide_search_and_return(
	failures: Array[String]
) -> void:
	_test_lost_sight_and_rehide(failures)
	_test_guard_searches_last_seen_then_returns(failures)


static func _test_lost_sight_and_rehide(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var facade = session.screen_facade
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var guard_a: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var guard_b: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_TWO_ID)
	var squad_a: TacticalSquadState = state.get_squad(TacticalSandboxFactory.GUARD_SQUAD_A_ID)
	if marauder == null or guard_a == null or guard_b == null or squad_a == null:
		failures.append("The lost-sight fixture is incomplete.")
		return

	# The opening in the long wall is at y=19–20. The Marauder crosses it and
	# finishes behind the wall where Guard A no longer has line of sight.
	state.set_unit_position(marauder.unit_id, Vector2i(22, 20), session.map_definition, false)
	state.set_unit_position(guard_a.unit_id, Vector2i(22, 19), session.map_definition, false)
	state.set_unit_position(guard_b.unit_id, Vector2i(40, 40), session.map_definition, false)
	squad_a.make_aware()
	marauder.reveal_to_squad(squad_a.squad_id)
	marauder.leave_stealth()
	session.visibility_service.call("recalculate_all_teams")

	var escape: OperationResult = facade.execute_movement(
		marauder.unit_id,
		Vector2i(25, 22),
		&"normal"
	)
	_expect(escape.success, "The revealed Marauder must be able to break line of sight through the wall opening.", failures)
	_expect(
		not marauder.is_revealed_to_squad(squad_a.squad_id),
		"Losing current sight must remove the squad's exact live target position.",
		failures
	)
	_expect(
		squad_a.has_last_seen_position(marauder.unit_id),
		"The aware squad must remember the final tile on which it saw the Marauder.",
		failures
	)
	_expect(
		not session.detection_service.is_unit_currently_perceived_by_squad(
			marauder.unit_id,
			squad_a.squad_id
		),
		"The destination must genuinely be outside Guard A's current perception.",
		failures
	)

	var rehide: OperationResult = facade.enter_stealth(marauder.unit_id)
	_expect(rehide.success, "A detected character must be able to re-enter Stealth after breaking perception.", failures)
	_expect(marauder.shows_hidden_badge(), "Re-entering Stealth must restore the mask badge.", failures)
	_expect(not marauder.action_budget.quick_action_available, "Re-entering Stealth must spend the available Quick Action.", failures)


static func _test_guard_searches_last_seen_then_returns(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var facade = session.screen_facade
	var state: TacticalState = session.state_store.state
	var guard_a: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var squad_a: TacticalSquadState = state.get_squad(TacticalSandboxFactory.GUARD_SQUAD_A_ID)
	if guard_a == null or squad_a == null:
		failures.append("The search fixture is incomplete.")
		return

	# Keep every player well outside the guard's perception so the test exercises
	# Last Seen Position memory rather than live target knowledge.
	var distant_tiles: Array[Vector2i] = [
		Vector2i(2, 50),
		Vector2i(4, 50),
		Vector2i(6, 50),
	]
	var players: Array[TacticalUnitState] = state.get_player_units()
	for index: int in range(mini(players.size(), distant_tiles.size())):
		state.set_unit_position(
			players[index].unit_id,
			distant_tiles[index],
			session.map_definition,
			false
		)
		players[index].clear_revelation()
		players[index].leave_stealth()

	state.set_unit_position(guard_a.unit_id, Vector2i(10, 20), session.map_definition, false)
	guard_a.assigned_task_position = Vector2i(5, 20)
	squad_a.make_aware()
	var remembered_unit_id: StringName = TacticalSandboxFactory.MARAUDER_ID
	var last_seen := Vector2i(15, 20)
	squad_a.remember_last_seen(remembered_unit_id, last_seen)
	session.visibility_service.call("recalculate_all_teams")

	var initiative_totals: Dictionary = {guard_a.unit_id: 20}
	var participants: Array[StringName] = [guard_a.unit_id]
	_expect(
		state.begin_initiative_combat(participants, initiative_totals),
		"The search fixture must enter initiative with Guard A active.",
		failures
	)
	_expect(
		squad_a.is_searching(),
		"An aware squad with a Last Seen Position must begin a bounded search.",
		failures
	)

	var distance_before_search: int = _grid_distance(
		guard_a.grid_position,
		last_seen
	)
	var first_search: OperationResult = facade.resolve_active_ai_initiative()
	_expect(first_search.success, "Guard A must resolve its first search activation.", failures)
	_expect(
		_grid_distance(guard_a.grid_position, last_seen) < distance_before_search,
		"Guard A must move toward the Last Seen Position.",
		failures
	)
	_expect(
		squad_a.has_last_seen_position(remembered_unit_id),
		"Searching must retain the historical Last Seen Position instead of deleting it.",
		failures
	)

	var first_advance: OperationResult = facade.end_initiative_turn(guard_a.unit_id)
	_expect(first_advance.success, "The first search activation must advance safely.", failures)
	_expect(
		state.phase_state.is_initiative_combat(),
		"The bounded search must continue for its remaining search round.",
		failures
	)
	var second_search: OperationResult = facade.resolve_active_ai_initiative()
	_expect(second_search.success, "Guard A must resolve its final search activation.", failures)
	var second_advance: OperationResult = facade.end_initiative_turn(guard_a.unit_id)
	_expect(second_advance.success, "The final search activation must end cleanly.", failures)
	_expect(
		state.phase_state.is_side_based()
		and state.phase_state.is_player_phase(),
		"Combat must return to the side-based Player Team Phase when the bounded search expires.",
		failures
	)
	_expect(squad_a.is_aware(), "The squad must remain Aware after combat ends.", failures)
	_expect(
		squad_a.has_last_seen_position(remembered_unit_id),
		"The squad must retain the Last Seen Position as historical knowledge.",
		failures
	)

	var enemy_phase: OperationResult = facade.begin_enemy_phase()
	_expect(enemy_phase.success, "The side-based Enemy Team Phase must begin after combat.", failures)
	var distance_before_return: int = _grid_distance(
		guard_a.grid_position,
		guard_a.assigned_task_position
	)
	var return_result: OperationResult = facade.resolve_enemy_turn()
	_expect(return_result.success, "Guard A must resolve its return-to-task behaviour.", failures)
	_expect(
		_grid_distance(guard_a.grid_position, guard_a.assigned_task_position)
		< distance_before_return,
		"After the bounded search, Guard A must move back toward its prior task position.",
		failures
	)


static func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return TacticalGridDistance.steps_between(a, b)


static func _expect(
	condition: bool,
	message: String,
	failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
