class_name Stage45E7PrecomputedShadowcastVisibilityTests
extends RefCounted

const MARAUDER_ID: StringName = TacticalSandboxFactory.MARAUDER_ID


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	# Mission-load FOV baking is deliberately substantial one-time work. Reuse one
	# session so the runtime suite tests gameplay behaviour rather than paying the
	# loading bake five times.
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	_test_startup_prewarm_is_bounded(session, failures)
	_test_hybrid_field_matches_authoritative_los(session, failures)
	_test_incremental_recalculation_uses_direct_deltas(session, failures)
	_test_movement_can_prepare_a_cached_field(session, failures)
	_test_geometry_chunks_invalidate_locally(session, failures)
	return failures


static func _test_startup_prewarm_is_bounded(
		session: TacticalSession,
		failures: Array[String]
) -> void:
	var visibility: Dictionary = (
		session.screen_facade.performance_snapshot().get("visibility", {})
	)
	var walkable_count: int = 0
	for y: int in range(session.map_definition.grid_size.y):
		for x: int in range(session.map_definition.grid_size.x):
			if not session.map_definition.is_blocked(Vector2i(x, y)):
				walkable_count += 1
	var centre_count: int = int(visibility.get(
		"prebaked_centre_field_count",
		0
	))
	var peek_count: int = int(visibility.get("prebaked_peek_field_count", 0))
	var field_limit: int = int(visibility.get("startup_prewarm_field_limit", 0))
	_expect(
		bool(visibility.get("startup_full_map_bake_skipped", false)),
		"Mission construction must skip the unsafe all-walkable-origin bake.",
		failures
	)
	_expect(
		centre_count > 0 and centre_count < walkable_count,
		"Mission startup must prewarm active observers without calculating every walkable origin.",
		failures
	)
	_expect(
		centre_count + peek_count <= field_limit,
		"Startup visibility prewarm must obey its hard field-count limit.",
		failures
	)
	_expect(
		int(visibility.get("prebaked_bitset_bytes", 0))
		<= field_limit * 512,
		"Bounded startup prewarm must retain only compact visibility masks.",
		failures
	)
	var edge_fov: Dictionary = visibility.get("edge_fov", {})
	_expect(
		String(edge_fov.get("algorithm", ""))
		== "hybrid_shadowcast_exact_refinement",
		"Movement FOV must retain the hybrid shadowcast core.",
		failures
	)


static func _test_hybrid_field_matches_authoritative_los(
		session: TacticalSession,
		failures: Array[String]
) -> void:
	var service: RefCounted = session.visibility_service
	var state: TacticalState = session.state_store.state
	var map_definition: TacticalMapDefinition = session.map_definition
	var origins: Array[Vector2i] = [
		Vector2i(7, 4),
		Vector2i(20, 20),
		Vector2i(40, 40),
	]
	for origin: Vector2i in origins:
		var field_value: Variant = service.call(
			"_visible_tiles_from_origin",
			origin,
			Vector2i.ZERO,
			{},
			false
		)
		var field: Dictionary = (
			field_value as Dictionary
			if field_value is Dictionary
			else {}
		)
		for offset_y: int in range(-40, 41):
			for offset_x: int in range(-40, 41):
				if absi(offset_x) + absi(offset_y) > 40:
					continue
				var target := origin + Vector2i(offset_x, offset_y)
				if not map_definition.is_inside(target):
					continue
				var expected: bool = TacticalLineOfSightRules.has_line_of_sight(
					origin,
					target,
					map_definition,
					state
				)
				_expect(
					field.has(target) == expected,
					"Precomputed FOV differs from authoritative LOS: %s → %s."
					% [origin, target],
					failures
				)
				if failures.size() >= 20:
					return


static func _test_incremental_recalculation_uses_direct_deltas(
		session: TacticalSession,
		failures: Array[String]
) -> void:
	var service: RefCounted = session.visibility_service
	var unit: TacticalUnitState = session.state_store.state.get_unit(MARAUDER_ID)
	if unit == null:
		failures.append("The direct-delta fixture is missing the Marauder.")
		return
	var destination: Vector2i = _legal_adjacent_destination(session, unit)
	if destination == unit.grid_position:
		failures.append("The direct-delta fixture requires one legal adjacent tile.")
		return
	var before: Dictionary = service.call("performance_snapshot")
	unit.grid_position = destination
	session.state_store.state.rebuild_unit_occupancy()
	service.call("recalculate_units", [unit.unit_id], true)
	var after: Dictionary = service.call("performance_snapshot")
	_expect(
		int(after.get("direct_delta_update_count", 0))
		== int(before.get("direct_delta_update_count", 0)) + 1,
		"Moved-observer visibility must publish reference-count boundary crossings directly.",
		failures
	)
	var delta_value: Variant = service.call("last_delta_for_team", &"player")
	var delta: Dictionary = (
		delta_value as Dictionary
		if delta_value is Dictionary
		else {}
	)
	_expect(
		delta.has("newly_visible") and delta.has("no_longer_visible"),
		"Direct visibility replacement must still publish fog-mask delta cells.",
		failures
	)


static func _test_movement_can_prepare_a_cached_field(
		session: TacticalSession,
		failures: Array[String]
) -> void:
	var service: RefCounted = session.visibility_service
	var unit: TacticalUnitState = session.state_store.state.get_unit(MARAUDER_ID)
	if unit == null:
		failures.append("The prepared-field fixture is missing the Marauder.")
		return
	var destination: Vector2i = _legal_adjacent_destination(session, unit)
	if destination == unit.grid_position:
		failures.append("The prepared-field fixture requires one legal adjacent tile.")
		return
	var before: Dictionary = service.call("performance_snapshot")
	var prepared_value: Variant = service.call(
		"prepare_visibility_for_destination",
		unit.unit_id,
		destination
	)
	_expect(
		bool(prepared_value),
		"A clicked movement destination must prepare its centre and Peek masks during planning.",
		failures
	)
	var after_preview: Dictionary = service.call("performance_snapshot")
	_expect(
		int(after_preview.get("destination_prewarm_count", 0))
		== int(before.get("destination_prewarm_count", 0)) + 1,
		"Destination planning must build exactly one prepared visibility field on a cache miss.",
		failures
	)
	unit.grid_position = destination
	session.state_store.state.rebuild_unit_occupancy()
	service.call("prepare_visibility_for_units", [unit.unit_id])
	var after_move: Dictionary = service.call("performance_snapshot")
	_expect(
		int(after_move.get("prepared_field_hits", 0))
		== int(after_preview.get("prepared_field_hits", 0)) + 1,
		"Movement presentation must reuse the field prepared for the clicked destination.",
		failures
	)
	service.call("recalculate_units", [unit.unit_id], true)


static func _test_geometry_chunks_invalidate_locally(
		session: TacticalSession,
		failures: Array[String]
) -> void:
	var service: RefCounted = session.visibility_service
	var edge_fov := service.get("_edge_fov") as TacticalEdgeShadowcastFov
	if edge_fov == null:
		failures.append("The visibility service has no edge-aware FOV core.")
		return
	var near_origin := Vector2i(10, 4)
	var far_origin := Vector2i(60, 60)
	var near_before: int = edge_fov.geometry_stamp_for_origin(near_origin)
	var far_before: int = edge_fov.geometry_stamp_for_origin(far_origin)
	var environment: TacticalEnvironmentState = (
		session.state_store.state.environment_state
	)
	_expect(
		environment.open_door(&"opening.farm.ordinary_door"),
		"The local-invalidation fixture must be able to open the ordinary door.",
		failures
	)
	edge_fov.synchronise_geometry()
	var near_after: int = edge_fov.geometry_stamp_for_origin(near_origin)
	var far_after: int = edge_fov.geometry_stamp_for_origin(far_origin)
	_expect(
		near_after != near_before,
		"Opening a door must invalidate nearby origin masks.",
		failures
	)
	_expect(
		far_after == far_before,
		"Opening a distant door must not invalidate unrelated origin masks.",
		failures
	)


static func _legal_adjacent_destination(
		session: TacticalSession,
		unit: TacticalUnitState
) -> Vector2i:
	for direction: Vector2i in [
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.UP,
	]:
		var candidate: Vector2i = unit.grid_position + direction
		if session.state_store.state.can_place_unit(
			unit,
			candidate,
			session.map_definition,
			unit.unit_id
		):
			return candidate
	return unit.grid_position


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
