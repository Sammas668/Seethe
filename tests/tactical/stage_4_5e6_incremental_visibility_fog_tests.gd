class_name Stage45E6IncrementalVisibilityFogTests
extends RefCounted

const MARAUDER_ID: StringName = TacticalSandboxFactory.MARAUDER_ID


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_mission_start_ray_bake(failures)
	_test_cached_visibility_matches_authoritative_los(failures)
	_test_exploration_uses_lightweight_commit(failures)
	_test_visibility_delta_is_published(failures)
	return failures


static func _test_mission_start_ray_bake(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var performance: Dictionary = session.screen_facade.performance_snapshot()
	var visibility: Dictionary = performance.get("visibility", {})
	var ray_cache: Dictionary = visibility.get("ray_cache", {})
	_expect(
		int(ray_cache.get("ray_count", 0)) == 3281,
		"The 40-tile Manhattan sight radius must bake 3,281 relative rays.",
		failures
	)
	_expect(
		int(ray_cache.get("relative_tile_step_count", 0)) > 0,
		"Mission setup must bake reusable relative LOS steps.",
		failures
	)


static func _test_cached_visibility_matches_authoritative_los(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var service: RefCounted = session.visibility_service
	var map_definition: TacticalMapDefinition = session.map_definition
	var state: TacticalState = session.state_store.state
	var origin := Vector2i(
		mini(20, map_definition.grid_size.x - 2),
		mini(20, map_definition.grid_size.y - 2)
	)
	var before: Dictionary = service.call("performance_snapshot")
	var field_value: Variant = service.call(
		"_visible_tiles_from_origin",
		origin,
		Vector2i.ZERO,
		{},
		false
	)
	var field: Dictionary = field_value as Dictionary if field_value is Dictionary else {}
	var targets: Array[Vector2i] = [
		origin,
		origin + Vector2i(1, 0),
		origin + Vector2i(4, 3),
		origin + Vector2i(-5, 2),
		origin + Vector2i(7, -4),
	]
	for target: Vector2i in targets:
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
			"Cached FOV must preserve authoritative LOS for %s." % target,
			failures
		)
	service.call(
		"_visible_tiles_from_origin",
		origin,
		Vector2i.ZERO,
		{},
		false
	)
	var after: Dictionary = service.call("performance_snapshot")
	_expect(
		int(after.get("visibility_field_cache_hits", 0))
		> int(before.get("visibility_field_cache_hits", 0)),
		"Repeating an unchanged origin must hit the bounded FOV cache.",
		failures
	)


static func _test_exploration_uses_lightweight_commit(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var service: RefCounted = session.visibility_service
	var state: TacticalState = session.state_store.state
	var map_definition: TacticalMapDefinition = session.map_definition
	var unexplored := Vector2i(-1, -1)
	for y: int in range(map_definition.grid_size.y - 1, -1, -1):
		for x: int in range(map_definition.grid_size.x - 1, -1, -1):
			var tile := Vector2i(x, y)
			if not state.is_tile_explored(&"player", tile):
				unexplored = tile
				break
		if unexplored.x >= 0:
			break
	_expect(
		unexplored.x >= 0,
		"The exploration test requires one initially unseen tile.",
		failures
	)
	if unexplored.x < 0:
		return
	var before: Dictionary = service.call("performance_snapshot")
	service.call("_queue_explored_tile", &"player", unexplored)
	var batches_value: Variant = service.call("_commit_exploration_batch")
	var after: Dictionary = service.call("performance_snapshot")
	_expect(
		batches_value is Dictionary and not (batches_value as Dictionary).is_empty(),
		"The queued exploration batch must commit.",
		failures
	)
	_expect(
		state.is_tile_explored(&"player", unexplored),
		"The lightweight exploration transaction must update knowledge.",
		failures
	)
	_expect(
		int(after.get("lightweight_exploration_commit_count", 0))
		== int(before.get("lightweight_exploration_commit_count", 0)) + 1,
		"Exploration must use the targeted lightweight commit path.",
		failures
	)


static func _test_visibility_delta_is_published(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var service: RefCounted = session.visibility_service
	var state: TacticalState = session.state_store.state
	var unit: TacticalUnitState = state.get_unit(MARAUDER_ID)
	if unit == null:
		failures.append("The visibility-delta fixture is missing the Marauder.")
		return
	var deltas: Array[Dictionary] = []
	service.connect(
		"visibility_delta_changed",
		func(team_id: StringName, delta: Dictionary) -> void:
			if team_id == &"player":
				deltas.append(delta.duplicate(true))
	)
	var original_position: Vector2i = unit.grid_position
	var destination: Vector2i = original_position
	for direction: Vector2i in [
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.UP,
	]:
		var candidate: Vector2i = original_position + direction
		if state.can_place_unit(unit, candidate, session.map_definition, unit.unit_id):
			destination = candidate
			break
	_expect(
		destination != original_position,
		"The visibility-delta fixture requires one legal adjacent tile.",
		failures
	)
	if destination == original_position:
		return
	unit.grid_position = destination
	service.call("recalculate_units", [unit.unit_id], true)
	var delta_value: Variant = service.call("last_delta_for_team", &"player")
	var delta: Dictionary = delta_value as Dictionary if delta_value is Dictionary else {}
	_expect(
		not deltas.is_empty(),
		"A player visibility recalculation must publish one tile delta.",
		failures
	)
	_expect(
		int(delta.get("visibility_revision", 0))
		== int(service.call("revision")),
		"The published fog delta must match the authoritative visibility revision.",
		failures
	)
	_expect(
		delta.has("newly_visible")
		and delta.has("no_longer_visible")
		and delta.has("newly_explored"),
		"Visibility deltas must contain visible, hidden and explored cell lists.",
		failures
	)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
