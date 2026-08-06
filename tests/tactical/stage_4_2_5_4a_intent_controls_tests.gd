class_name Stage4254aIntentControlsTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_movement_preview_is_non_mutating(failures)
	_test_facing_preview_is_non_mutating_and_direction_based(failures)
	_test_authoritative_confirmation_still_commits(failures)
	return failures


static func _test_movement_preview_is_non_mutating(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var unit: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	if unit == null:
		failures.append("The intent-control fixture needs the Marauder.")
		return
	_move_enemies_away(session)
	state.set_unit_position(
		unit.unit_id,
		Vector2i(20, 20),
		session.map_definition,
		false
	)
	unit.set_facing(Vector2i(0, -1))
	var position_before: Vector2i = unit.grid_position
	var facing_before: Vector2i = unit.facing_direction
	var capacity_before: int = (
		unit.action_budget.remaining_turn_capacity_feet
	)
	var preview: MovementPathResult = session.screen_facade.preview_movement(
		unit.unit_id,
		Vector2i(23, 20),
		&"normal"
	)
	_expect(preview.success, "A legal first-click movement preview must exist.", failures)
	_expect(
		unit.grid_position == position_before,
		"Movement preview must not move the unit.",
		failures
	)
	_expect(
		unit.facing_direction == facing_before,
		"Movement preview must not change authoritative facing.",
		failures
	)
	_expect(
		unit.action_budget.remaining_turn_capacity_feet == capacity_before,
		"Movement preview must not spend turn capacity.",
		failures
	)


static func _test_facing_preview_is_non_mutating_and_direction_based(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var unit: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	if unit == null:
		failures.append("The facing-preview fixture needs the Marauder.")
		return
	_move_enemies_away(session)
	state.set_unit_position(
		unit.unit_id,
		Vector2i(20, 20),
		session.map_definition,
		false
	)
	unit.set_facing(Vector2i(0, -1))
	var capacity_before: int = (
		unit.action_budget.remaining_turn_capacity_feet
	)
	var near_east: Vector2i = session.screen_facade.preview_facing_direction(
		unit.unit_id,
		Vector2i(22, 20)
	)
	var far_east: Vector2i = session.screen_facade.preview_facing_direction(
		unit.unit_id,
		Vector2i(30, 20)
	)
	_expect(
		near_east == Vector2i(1, 0) and far_east == near_east,
		"Facing confirmation must compare quantised direction, not exact tile.",
		failures
	)
	_expect(
		unit.facing_direction == Vector2i(0, -1),
		"Facing preview must not mutate authoritative facing.",
		failures
	)
	_expect(
		unit.action_budget.remaining_turn_capacity_feet == capacity_before,
		"Facing preview must not spend the 5-foot committed cost.",
		failures
	)


static func _test_authoritative_confirmation_still_commits(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var unit: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	if unit == null:
		failures.append("The intent-confirmation fixture needs the Marauder.")
		return
	_move_enemies_away(session)
	state.set_unit_position(
		unit.unit_id,
		Vector2i(20, 20),
		session.map_definition,
		false
	)
	unit.set_facing(Vector2i(0, -1))
	var capacity_before: int = (
		unit.action_budget.remaining_turn_capacity_feet
	)
	var result: OperationResult = session.screen_facade.face_direction(
		unit.unit_id,
		Vector2i(24, 20)
	)
	_expect(result.success, "Second-click facing confirmation must commit.", failures)
	_expect(
		unit.facing_direction == Vector2i(1, 0),
		"Confirmed facing must become authoritative.",
		failures
	)
	_expect(
		unit.action_budget.remaining_turn_capacity_feet == capacity_before - 5,
		"Only authoritative confirmation may spend the 5-foot facing cost.",
		failures
	)


static func _move_enemies_away(session: TacticalSession) -> void:
	var offset: int = 0
	for enemy: TacticalUnitState in session.state_store.state.get_enemy_units():
		session.state_store.state.set_unit_position(
			enemy.unit_id,
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
