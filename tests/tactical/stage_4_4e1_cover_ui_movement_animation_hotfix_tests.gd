class_name Stage44e1CoverUiMovementAnimationHotfixTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_cover_token_accepts_only_context_categories(failures)
	_test_movement_view_starts_without_authoritative_snap(failures)
	_test_directional_cover_field_uses_bounded_projection(failures)
	_test_visibility_and_perception_deferral_is_balanced(failures)
	_test_automatic_peek_remains_free_after_hotfix(failures)
	return failures


static func _test_cover_token_accepts_only_context_categories(
		failures: Array[String]
) -> void:
	var view := TacticalUnitView.new()
	view.set_cover_category(TacticalCombatGeometryResult.COVER_LIGHT)
	_expect(
		StringName(view.get("_cover_category")) == TacticalCombatGeometryResult.COVER_LIGHT,
		"Light Cover must remain available to the single contextual token shield.",
		failures
	)
	view.set_cover_category(TacticalCombatGeometryResult.COVER_HEAVY)
	_expect(
		StringName(view.get("_cover_category")) == TacticalCombatGeometryResult.COVER_HEAVY,
		"Heavy Cover must remain available to the single contextual token shield.",
		failures
	)
	view.set_cover_category(&"")
	_expect(
		StringName(view.get("_cover_category")).is_empty(),
		"Exposed, Total and no-threat presentation must be able to clear the shield.",
		failures
	)
	view.free()


static func _test_movement_view_starts_without_authoritative_snap(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var unit: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_expect(unit != null, "The movement fixture requires the Marauder.", failures)
	if unit == null:
		return
	var view := TacticalUnitView.new()
	var tree := Engine.get_main_loop() as SceneTree
	_expect(tree != null, "Movement presentation tests require a SceneTree.", failures)
	if tree == null:
		view.free()
		return
	tree.root.add_child(view)
	view.configure(unit, Vector2.ZERO, 32.0, Color.WHITE)
	var origin: Vector2i = unit.grid_position
	var path: Array[Vector2i] = [origin, origin + Vector2i.RIGHT, origin + Vector2i(2, 0)]
	var started: bool = view.animate_path(path)
	_expect(started, "A multi-tile committed path must start a movement tween.", failures)
	_expect(view.is_movement_animating(), "The view must report its active movement tween.", failures)
	var position_before_snap: Vector2 = view.position
	view.snap_to_tile(origin + Vector2i(8, 0))
	_expect(
		view.position == position_before_snap,
		"Authoritative synchronisation must not snap an animating token early.",
		failures
	)
	view.queue_free()


static func _test_directional_cover_field_uses_bounded_projection(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	TacticalDirectionalCoverFieldQuery.clear_cache()
	var before: Dictionary = TacticalDirectionalCoverFieldQuery.performance_snapshot()
	var field: TacticalDirectionalCoverField = TacticalDirectionalCoverFieldQuery.build(
		state,
		session.map_definition,
		Vector2i(5, 4),
		&"player"
	)
	var after: Dictionary = TacticalDirectionalCoverFieldQuery.performance_snapshot()
	_expect(field != null, "Movement hover must still provide a cyan cover field.", failures)
	_expect(
		int(after.get("projection_length_tiles", 0)) == 8,
		"The correction field must use the bounded eight-tile projection.",
		failures
	)
	_expect(
		int(after.get("projected_tile_checks", 0)) >= int(before.get("projected_tile_checks", 0)),
		"The performance snapshot must expose bounded projected-tile work.",
		failures
	)


static func _test_visibility_and_perception_deferral_is_balanced(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	session.screen_facade.begin_visibility_recalculation_deferral()
	var deferred: Dictionary = session.visibility_service.call("performance_snapshot")
	_expect(
		int(deferred.get("recalculation_deferral_depth", 0)) == 1,
		"Movement presentation must be able to defer visibility rebuilding.",
		failures
	)
	session.screen_facade.end_visibility_recalculation_deferral()
	var released: Dictionary = session.visibility_service.call("performance_snapshot")
	_expect(
		int(released.get("recalculation_deferral_depth", -1)) == 0,
		"Visibility deferral must return to zero after movement presentation.",
		failures
	)


static func _test_automatic_peek_remains_free_after_hotfix(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var unit: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_expect(unit != null, "The automatic-Peek fixture requires the Marauder.", failures)
	if unit == null:
		return
	var capacity_before: int = unit.action_budget.remaining_turn_capacity_feet
	TacticalObservationOriginQuery.legal_origins(
		session.state_store.state,
		session.map_definition,
		unit
	)
	_expect(
		unit.action_budget.remaining_turn_capacity_feet == capacity_before,
		"Removing hypothetical hover Peek must not charge real automatic Peek.",
		failures
	)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
