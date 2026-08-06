class_name TacticalLocalCoverQuery
extends RefCounted

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]
const MAX_CACHE_ENTRIES: int = 256

static var _cache: Dictionary = {}
static var _cache_hits: int = 0
static var _cache_misses: int = 0


static func evaluate_position(
		state: TacticalState,
		map_definition: TacticalMapDefinition,
		position: Vector2i,
		knowledge_team_id: StringName = &"player"
) -> TacticalLocalCoverResult:
	var result := TacticalLocalCoverResult.new()
	result.defended_tile = position
	if (
		state == null
		or map_definition == null
		or not map_definition.is_inside(position)
	):
		return result
	var key: String = _cache_key(state, position, knowledge_team_id)
	if _cache.has(key):
		_cache_hits += 1
		return _cache[key] as TacticalLocalCoverResult
	_cache_misses += 1
	result.geometry_revision = state.geometry_revision()
	result.knowledge_revision = state.knowledge_state.revision
	var environment: TacticalEnvironmentState = state.environment_state
	for direction: Vector2i in CARDINAL_DIRECTIONS:
		var neighbour: Vector2i = position + direction
		if not map_definition.is_inside(neighbour):
			continue
		# Presentation never reveals unknown adjacent geometry. A known wall or
		# opening is available as soon as either side of its edge is explored.
		if (
			not state.is_tile_explored(knowledge_team_id, position)
			and not state.is_tile_explored(knowledge_team_id, neighbour)
		):
			continue
		var category: StringName = TacticalCombatGeometryResult.COVER_NONE
		var source_id: StringName = &""
		if map_definition.is_wall(neighbour) or map_definition.blocks_vision(neighbour):
			category = TacticalCombatGeometryResult.COVER_HEAVY
			source_id = StringName("tile:%d,%d" % [neighbour.x, neighbour.y])
		elif environment != null:
			var height: StringName = environment.cover_height_at_edge(
				map_definition,
				position,
				neighbour
			)
			match height:
				TacticalBarrierSegmentDefinition.HEIGHT_LOW:
					category = TacticalCombatGeometryResult.COVER_LIGHT
				TacticalBarrierSegmentDefinition.HEIGHT_HIGH, TacticalBarrierSegmentDefinition.HEIGHT_FULL:
					category = TacticalCombatGeometryResult.COVER_HEAVY
			if category != TacticalCombatGeometryResult.COVER_NONE:
				source_id = environment.cover_source_id_at_edge(
					map_definition,
					position,
					neighbour
				)
		if category == TacticalCombatGeometryResult.COVER_NONE:
			continue
		result.directional_cover_by_sector[direction] = category
		if not source_id.is_empty() and not result.source_feature_ids.has(source_id):
			result.source_feature_ids.append(source_id)
		if _cover_rank(category) > _cover_rank(result.strongest_local_cover):
			result.strongest_local_cover = category
	_store(key, result)
	return result


static func clear_cache() -> void:
	_cache.clear()


static func performance_snapshot() -> Dictionary:
	return {
		"cache_entries": _cache.size(),
		"cache_hits": _cache_hits,
		"cache_misses": _cache_misses,
	}


static func _store(key: String, result: TacticalLocalCoverResult) -> void:
	if _cache.size() >= MAX_CACHE_ENTRIES:
		_cache.clear()
	_cache[key] = result


static func _cache_key(
		state: TacticalState,
		position: Vector2i,
		knowledge_team_id: StringName
) -> String:
	return "%d|%d,%d|%s|%d|%d" % [
		state.get_instance_id(),
		position.x,
		position.y,
		String(knowledge_team_id),
		state.geometry_revision(),
		state.knowledge_state.revision,
	]


static func _cover_rank(category: StringName) -> int:
	match category:
		TacticalCombatGeometryResult.COVER_LIGHT:
			return 1
		TacticalCombatGeometryResult.COVER_HEAVY:
			return 2
		_:
			return 0
