class_name TacticalObservationOriginQuery
extends RefCounted

const MAX_CACHE_ENTRIES: int = 512

static var _origin_cache: Dictionary = {}
static var _cache_hits: int = 0
static var _cache_misses: int = 0


static func legal_origins(
		state: TacticalState,
		map_definition: TacticalMapDefinition,
		observer: TacticalUnitState,
		position_override: Variant = null
) -> Array[TacticalObservationOrigin]:
	var result: Array[TacticalObservationOrigin] = []
	if state == null or map_definition == null or observer == null:
		return result
	if observer.is_incapacitated():
		return result
	var origin_tile: Vector2i = (
		Vector2i(position_override)
		if position_override is Vector2i
		else observer.grid_position
	)
	var key: String = _cache_key(state, observer, origin_tile)
	if _origin_cache.has(key):
		_cache_hits += 1
		return _duplicate_origins(_origin_cache[key])
	_cache_misses += 1
	result.append(TacticalObservationOrigin.centre(origin_tile))
	var environment: TacticalEnvironmentState = state.environment_state
	if environment == null:
		_store(key, result)
		return result

	# Openings expose a far-side observation origin automatically. The free Peek rule
	# is preserved; the cache prevents every hover and visibility check from
	# rebuilding these identical origins.
	for direction: Vector2i in [
		Vector2i.UP,
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
	]:
		var other: Vector2i = origin_tile + direction
		if not map_definition.is_inside(other):
			continue
		var opening: TacticalOpeningDefinition = map_definition.opening_at_edge(
			origin_tile,
			other
		)
		if opening == null:
			continue
		if environment.edge_blocks_sight(map_definition, origin_tile, other):
			continue
		var opening_origin := TacticalObservationOrigin.new()
		opening_origin.origin_kind = TacticalObservationOrigin.KIND_OPENING_PEEK
		opening_origin.origin_tile = other
		opening_origin.world_position = (
			Vector2(origin_tile)
			+ Vector2(0.5, 0.5)
			+ Vector2(direction) * 0.46
		)
		opening_origin.source_edge_id = opening.opening_id
		opening_origin.uses_automatic_peek = true
		opening_origin.direction = direction
		_append_unique(result, opening_origin)

	for toward_wall: Vector2i in [
		Vector2i.UP,
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
	]:
		var wall_tile: Vector2i = origin_tile + toward_wall
		if (
			not map_definition.is_inside(wall_tile)
			or not map_definition.blocks_vision(wall_tile)
		):
			continue
		var sides: Array[Vector2i] = [
			Vector2i(-toward_wall.y, toward_wall.x),
			Vector2i(toward_wall.y, -toward_wall.x),
		]
		for side: Vector2i in sides:
			var side_tile: Vector2i = origin_tile + side
			if (
				not map_definition.is_inside(side_tile)
				or map_definition.is_blocked(side_tile)
			):
				continue
			if environment.edge_blocks_sight(
				map_definition,
				origin_tile,
				side_tile
			):
				continue
			var corner_origin := TacticalObservationOrigin.new()
			corner_origin.origin_kind = TacticalObservationOrigin.KIND_CORNER_PEEK
			corner_origin.origin_tile = side_tile
			corner_origin.world_position = (
				Vector2(origin_tile)
				+ Vector2(0.5, 0.5)
				+ Vector2(side) * 0.46
			)
			corner_origin.source_edge_id = StringName(
				"corner:%d,%d:%d,%d"
				% [wall_tile.x, wall_tile.y, side.x, side.y]
			)
			corner_origin.uses_automatic_peek = true
			corner_origin.direction = side
			_append_unique(result, corner_origin)
	_store(key, result)
	return _duplicate_origins(result)


static func clear_cache() -> void:
	_origin_cache.clear()


static func performance_snapshot() -> Dictionary:
	return {
		"cache_entries": _origin_cache.size(),
		"cache_hits": _cache_hits,
		"cache_misses": _cache_misses,
	}


static func _store(
		key: String,
		origins: Array[TacticalObservationOrigin]
) -> void:
	if _origin_cache.size() >= MAX_CACHE_ENTRIES:
		_origin_cache.clear()
	_origin_cache[key] = _duplicate_origins(origins)


static func _cache_key(
		state: TacticalState,
		observer: TacticalUnitState,
		origin_tile: Vector2i
) -> String:
	return "%d|%s|%d,%d|%s|%d" % [
		state.get_instance_id(),
		observer.unit_id,
		origin_tile.x,
		origin_tile.y,
		String(observer.life_state_id()),
		state.geometry_revision(),
	]


static func _duplicate_origins(
		source_value: Variant
) -> Array[TacticalObservationOrigin]:
	var result: Array[TacticalObservationOrigin] = []
	if not (source_value is Array):
		return result
	for origin_value: Variant in source_value:
		var origin: TacticalObservationOrigin = (
			origin_value as TacticalObservationOrigin
		)
		if origin == null:
			continue
		var copy := TacticalObservationOrigin.new()
		copy.origin_kind = origin.origin_kind
		copy.origin_tile = origin.origin_tile
		copy.world_position = origin.world_position
		copy.source_edge_id = origin.source_edge_id
		copy.uses_automatic_peek = origin.uses_automatic_peek
		copy.direction = origin.direction
		result.append(copy)
	return result


static func _append_unique(
		origins: Array[TacticalObservationOrigin],
		candidate: TacticalObservationOrigin
) -> void:
	for existing: TacticalObservationOrigin in origins:
		if (
			existing.origin_tile == candidate.origin_tile
			and existing.direction == candidate.direction
		):
			return
	origins.append(candidate)
