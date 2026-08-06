class_name Stage4254FacingPerceptionTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_movement_faces_last_completed_step(failures)
	_test_manual_facing_costs_five_feet(failures)
	_test_stationary_hidden_enemy_reuses_stealth_result(failures)
	_test_player_perception_reveals_without_starting_initiative(failures)
	return failures


static func _test_movement_faces_last_completed_step(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var unit: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	if unit == null:
		failures.append("The movement-facing fixture needs the Marauder.")
		return
	_move_enemy_units_far_away(session)
	state.set_unit_position(unit.unit_id, Vector2i(10, 10), session.map_definition, false)
	unit.set_facing(Vector2i(0, -1))
	var result: OperationResult = session.screen_facade.execute_movement(
		unit.unit_id,
		Vector2i(13, 12),
		&"normal"
	)
	_expect(result.success, "The movement-facing route must commit.", failures)
	var completed: MovementPathResult = result.data as MovementPathResult
	if completed == null or completed.path.size() <= 1:
		failures.append("Movement-facing must return a completed multi-tile path.")
		return
	var expected: Vector2i = TacticalPerceptionRules.normalized_facing(
		completed.path.back() - completed.path[completed.path.size() - 2]
	)
	_expect(
		unit.facing_direction == expected,
		"Voluntary movement must face the final completed path step.",
		failures
	)


static func _test_manual_facing_costs_five_feet(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var unit: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	if unit == null:
		failures.append("The manual-facing fixture needs the Marauder.")
		return
	_move_enemy_units_far_away(session)
	state.set_unit_position(unit.unit_id, Vector2i(20, 20), session.map_definition, false)
	unit.set_facing(Vector2i(0, -1))
	unit.enter_stealth()
	unit.set_current_stealth_roll(15, 15 + unit.stealth_bonus())
	var capacity_before: int = unit.action_budget.remaining_turn_capacity_feet
	var result: OperationResult = session.screen_facade.face_direction(
		unit.unit_id,
		Vector2i(24, 20)
	)
	_expect(result.success, "Right-click facing must commit for an active player.", failures)
	_expect(
		unit.facing_direction == Vector2i(1, 0),
		"Manual facing must quantise to one of eight directions.",
		failures
	)
	_expect(
		unit.action_budget.remaining_turn_capacity_feet == capacity_before - 5,
		"Face Direction must cost exactly 5 feet of turn capacity.",
		failures
	)
	_expect(unit.stealth_enabled, "Manual facing must preserve Stealth.", failures)


static func _test_stationary_hidden_enemy_reuses_stealth_result(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var observer: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var hidden_enemy: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	if observer == null or hidden_enemy == null:
		failures.append("The symmetric-perception fixture is incomplete.")
		return
	_prepare_hidden_enemy_fixture(session, observer, hidden_enemy)
	hidden_enemy.set_current_stealth_roll(20, 99)
	session.combat_dice_roller.call("set_scripted_results", [1, 1, 1])
	var before: Dictionary = session.combat_dice_roller.call("snapshot_state")
	var first: OperationResult = session.screen_facade.face_direction(
		observer.unit_id,
		hidden_enemy.grid_position
	)
	_expect(first.success, "The observer must be able to face the hidden enemy.", failures)
	_expect(hidden_enemy.stealth_enabled, "A high retained Stealth total must remain hidden.", failures)
	var after_first: Dictionary = session.combat_dice_roller.call("snapshot_state")
	_expect(
		int(after_first.get("scripted_index", -1)) == int(before.get("scripted_index", -2)),
		"Turning into a stationary hidden enemy must reuse its existing Stealth result.",
		failures
	)
	var away: OperationResult = session.screen_facade.face_direction(
		observer.unit_id,
		observer.grid_position + Vector2i(0, -4)
	)
	var back: OperationResult = session.screen_facade.face_direction(
		observer.unit_id,
		hidden_enemy.grid_position
	)
	_expect(away.success and back.success, "The observer must be able to turn away and back.", failures)
	var after_back: Dictionary = session.combat_dice_roller.call("snapshot_state")
	_expect(
		int(after_back.get("scripted_index", -1)) == int(before.get("scripted_index", -2)),
		"Repeated orientation must not fish for fresh passive Perception rolls.",
		failures
	)


static func _test_player_perception_reveals_without_starting_initiative(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var observer: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var hidden_enemy: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	if observer == null or hidden_enemy == null:
		failures.append("The player-detection fixture is incomplete.")
		return
	_prepare_hidden_enemy_fixture(session, observer, hidden_enemy)
	hidden_enemy.set_current_stealth_roll(1, 1 + hidden_enemy.stealth_bonus())
	var result: OperationResult = session.screen_facade.face_direction(
		observer.unit_id,
		hidden_enemy.grid_position
	)
	_expect(result.success, "Facing should resolve player passive perception.", failures)
	_expect(not hidden_enemy.stealth_enabled, "A failed retained Stealth result must reveal the enemy.", failures)
	_expect(
		hidden_enemy.is_revealed_to_squad(TacticalSquadState.PLAYER_TEAM_SQUAD_ID),
		"A detected hidden enemy must be revealed to the player team squad.",
		failures
	)
	_expect(
		state.phase_state.is_side_based(),
		"Player detection of a hidden enemy must not start enemy-alert initiative by itself.",
		failures
	)
	var player_squad: TacticalSquadState = state.get_squad(
		TacticalSquadState.PLAYER_TEAM_SQUAD_ID
	)
	_expect(
		player_squad != null
		and player_squad.last_seen_position(hidden_enemy.unit_id) == hidden_enemy.grid_position,
		"The player team must remember the enemy's confirmed last-seen tile.",
		failures
	)
	var roll_events: Array = session.event_journal.call("events", &"rolls", false)
	var found_perception_detail: bool = false
	for event_value: Variant in roll_events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		var summary: String = str(event.get("summary", ""))
		var details_text: String = str(event.get("details", []))
		if (
			summary.contains("PERCEPTION")
			and details_text.contains("Raw d20:")
			and details_text.contains("required natural roll")
		):
			found_perception_detail = true
			break
	_expect(
		found_perception_detail,
		"Detected hidden enemies must produce attack-style detailed Perception roll logs.",
		failures
	)


static func _prepare_hidden_enemy_fixture(
		session: TacticalSession,
		observer: TacticalUnitState,
		hidden_enemy: TacticalUnitState
) -> void:
	var state: TacticalState = session.state_store.state
	state.set_unit_position(observer.unit_id, Vector2i(30, 30), session.map_definition, false)
	observer.set_facing(Vector2i(0, -1))
	state.set_unit_position(hidden_enemy.unit_id, Vector2i(35, 30), session.map_definition, false)
	hidden_enemy.enter_stealth()
	hidden_enemy.clear_revelation()
	var offset: int = 0
	for unit: TacticalUnitState in state.get_units():
		if unit.unit_id in [observer.unit_id, hidden_enemy.unit_id]:
			continue
		state.set_unit_position(
			unit.unit_id,
			Vector2i(50 + offset, 50),
			session.map_definition,
			false
		)
		unit.set_facing(Vector2i(0, 1))
		offset += 2
	session.visibility_service.call("recalculate_all_teams")


static func _move_enemy_units_far_away(session: TacticalSession) -> void:
	var offset: int = 0
	for unit: TacticalUnitState in session.state_store.state.get_enemy_units():
		session.state_store.state.set_unit_position(
			unit.unit_id,
			Vector2i(50 + offset, 50),
			session.map_definition,
			false
		)
		offset += 2
	session.visibility_service.call("recalculate_all_teams")


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
