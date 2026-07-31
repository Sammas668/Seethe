class_name TacticalDirectionalCoverFieldQuery
extends RefCounted

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]
# Retained as the Stage 4.4e compatibility ceiling. Stage 4.4e1 no longer scans
# every tile in this radius; it projects compact directional wedges instead.
const FIELD_RADIUS_TILES: int = 18
const PROJECTION_LENGTH_TILES: int = 8
const PROJECTION_HALF_WIDTH_TILES: int = 4
const MAX_CACHE_ENTRIES: int = 256

static var _field_cache: Dictionary = {}
static var _cache_hits: int = 0
static var _cache_misses: int = 0
static var _projected_tile_checks: int = 0


static func build(
		state: TacticalState,
		map_definition: TacticalMapDefinition,
		defended_tile: Vector2i,
		knowledge_team_id: StringName = &"player"
) -> TacticalDirectionalCoverField:
	var result := TacticalDirectionalCoverField.new()
	result.defended_tile = defended_tile
	if (
		state == null
		or map_definition == null
		or not map_definition.is_inside(defended_tile)
	):
		return result
	var key: String = _cache_key(state, defended_tile, knowledge_team_id)
	if _field_cache.has(key):
		_cache_hits += 1
		return _field_cache[key] as TacticalDirectionalCoverField
	_cache_misses += 1
	result.geometry_revision = state.geometry_revision()
	result.knowledge_revision = state.knowledge_state.revision
	var local_result: TacticalLocalCoverResult = TacticalLocalCoverQuery.evaluate_position(
		state,
		map_definition,
		defended_tile,
		knowledge_team_id
	)
	result.strongest_local_cover = local_result.strongest_local_cover
	result.directional_cover_by_sector = local_result.directional_cover_by_sector.duplicate()
	var local_cover: Dictionary = result.directional_cover_by_sector
	for direction_value: Variant in local_cover.keys():
		if not (direction_value is Vector2i):
			continue
		var direction := Vector2i(direction_value)
		var category := StringName(local_cover[direction_value])
		_project_directional_wedge(
			result,
			state,
			map_definition,
			defended_tile,
			direction,
			category,
			knowledge_team_id
		)
	_store(key, result)
	return result


static func clear_cache() -> void:
	_field_cache.clear()


static func performance_snapshot() -> Dictionary:
	return {
		"cache_entries": _field_cache.size(),
		"cache_hits": _cache_hits,
		"cache_misses": _cache_misses,
		"field_radius_tiles": FIELD_RADIUS_TILES,
		"projection_length_tiles": PROJECTION_LENGTH_TILES,
		"projected_tile_checks": _projected_tile_checks,
	}


static func _project_directional_wedge(
		result: TacticalDirectionalCoverField,
		state: TacticalState,
		map_definition: TacticalMapDefinition,
		defended_tile: Vector2i,
		direction: Vector2i,
		category: StringName,
		knowledge_team_id: StringName
) -> void:
	# A local barrier protects the defended character against attacks arriving
	# from that barrier's side. This is a cheap explanatory field, not the
	# authoritative five-sample attack calculation.
	var tangent := Vector2i(-direction.y, direction.x)
	for distance: int in range(1, PROJECTION_LENGTH_TILES + 1):
		var half_width: int = mini(
			PROJECTION_HALF_WIDTH_TILES,
			maxi(1, int(ceil(float(distance) * 0.65)))
		)
		for lateral: int in range(-half_width, half_width + 1):
			_projected_tile_checks += 1
			var attacker_tile: Vector2i = (
				defended_tile
				+ direction * distance
				+ tangent * lateral
			)
			if not map_definition.is_inside(attacker_tile):
				continue
			if not state.is_tile_explored(knowledge_team_id, attacker_tile):
				continue
			if map_definition.is_blocked(attacker_tile):
				continue
			var existing: StringName = result.category_at(attacker_tile)
			if _cover_rank(category) > _cover_rank(existing):
				result.categories_by_tile[attacker_tile] = category


static func _store(
		key: String,
		field: TacticalDirectionalCoverField
) -> void:
	if _field_cache.size() >= MAX_CACHE_ENTRIES:
		_field_cache.clear()
	_field_cache[key] = field


static func _cache_key(
		state: TacticalState,
		defended_tile: Vector2i,
		knowledge_team_id: StringName
) -> String:
	return "%d|%d,%d|%s|%d|%d" % [
		state.get_instance_id(),
		defended_tile.x,
		defended_tile.y,
		String(knowledge_team_id),
		state.geometry_revision(),
		state.knowledge_state.revision,
	]


static func _category_from_direction(
		local_cover: Dictionary,
		delta: Vector2i
) -> StringName:
	# Compatibility helper retained for older tests/content tools. The live field
	# now uses projected wedges and does not scan a bounding square.
	var candidates: Array[StringName] = []
	if delta.x < 0 and local_cover.has(Vector2i.LEFT):
		candidates.append(StringName(local_cover[Vector2i.LEFT]))
	elif delta.x > 0 and local_cover.has(Vector2i.RIGHT):
		candidates.append(StringName(local_cover[Vector2i.RIGHT]))
	if delta.y < 0 and local_cover.has(Vector2i.UP):
		candidates.append(StringName(local_cover[Vector2i.UP]))
	elif delta.y > 0 and local_cover.has(Vector2i.DOWN):
		candidates.append(StringName(local_cover[Vector2i.DOWN]))
	var best: StringName = TacticalCombatGeometryResult.COVER_NONE
	for candidate: StringName in candidates:
		if _cover_rank(candidate) > _cover_rank(best):
			best = candidate
	return best


static func _cover_rank(category: StringName) -> int:
	match category:
		TacticalCombatGeometryResult.COVER_LIGHT:
			return 1
		TacticalCombatGeometryResult.COVER_HEAVY:
			return 2
		TacticalCombatGeometryResult.COVER_TOTAL:
			return 3
		_:
			return 0
