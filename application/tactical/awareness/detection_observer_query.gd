class_name DetectionObserverQuery
extends RefCounted

const TEAM_RELATIONS_SCRIPT: Script = preload(
	"res://domain/tactical/tactical_team_relations.gd"
)
const OBSERVATION_ORIGIN_QUERY_SCRIPT: Script = preload(
	"res://domain/tactical/geometry/tactical_observation_origin_query.gd"
)
const GRID_DISTANCE_SCRIPT: Script = preload(
	"res://domain/tactical/tactical_grid_distance.gd"
)
const LOS_RULES_SCRIPT: Script = preload(
	"res://domain/tactical/visibility/tactical_line_of_sight_rules.gd"
)

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _visibility_service: RefCounted
var _perception_tile_cache: Dictionary = {}
var _cache_hits: int = 0
var _cache_misses: int = 0


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		visibility_service: RefCounted
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_visibility_service = visibility_service
	_perception_tile_cache.clear()
	_cache_hits = 0
	_cache_misses = 0


func collect_tile_exposures(
		unit: TacticalUnitState,
		tile: Vector2i,
		path_index: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if unit == null or _map_definition == null or _state_store == null:
		return result
	for observer: TacticalUnitState in _state_store.state.get_units():
		if (
			observer == null
			or observer.is_defeated()
			or observer.squad_id.is_empty()
			or not TEAM_RELATIONS_SCRIPT.are_hostile(
				observer.team_id,
				unit.team_id
			)
			or unit.is_revealed_to_squad(observer.squad_id)
		):
			continue
		var observer_squad: TacticalSquadState = (
			_state_store.state.get_squad(observer.squad_id)
		)
		var use_ordinary_sight: bool = (
			observer_squad != null
			and observer_squad.is_aware()
			and not unit.stealth_enabled
		)
		if not observer_perceives_tile(
			observer,
			tile,
			use_ordinary_sight
		):
			continue
		result.append({
			"observer": observer,
			"dc": TacticalPerceptionRules.detection_dc(observer, tile),
			"automatic": not unit.stealth_enabled,
			"path_index": path_index,
			"tile": tile,
		})
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var observer_a: TacticalUnitState = a.get("observer") as TacticalUnitState
			var observer_b: TacticalUnitState = b.get("observer") as TacticalUnitState
			return String(observer_a.unit_id) < String(observer_b.unit_id)
	)
	return result


func perceiving_observers_for_squad(
		unit: TacticalUnitState,
		squad_id: StringName,
		tile: Vector2i,
		assume_revealed: bool = false
) -> Array[TacticalUnitState]:
	var result: Array[TacticalUnitState] = []
	if unit == null or _state_store == null:
		return result
	var squad: TacticalSquadState = _state_store.state.get_squad(squad_id)
	if squad == null:
		return result
	var use_ordinary_sight: bool = (
		squad.is_aware()
		and (
			unit.is_revealed_to_squad(squad_id)
			or assume_revealed
		)
	)
	for observer: TacticalUnitState in _state_store.state.get_units_in_squad(
		squad_id
	):
		if observer.is_defeated():
			continue
		if observer_perceives_tile(observer, tile, use_ordinary_sight):
			result.append(observer)
	return result


func observer_perceives_tile(
		observer: TacticalUnitState,
		tile: Vector2i,
		use_ordinary_sight: bool
) -> bool:
	if observer == null or _map_definition == null:
		return false
	if use_ordinary_sight:
		if not GRID_DISTANCE_SCRIPT.is_within_steps(
			observer.grid_position, tile, TacticalPerceptionRules.aware_sight_radius_tiles()
		):
			return false
		return _has_los_from_observation_origins(observer, tile)
	if GRID_DISTANCE_SCRIPT.is_within_steps(
		observer.grid_position, tile, TacticalPerceptionRules.CLOSE_AWARENESS_TILES
	):
		return _has_los_from_observation_origins(observer, tile)
	var delta: Vector2i = tile - observer.grid_position
	if delta == Vector2i.ZERO:
		return true
	if GRID_DISTANCE_SCRIPT.steps_between(observer.grid_position, tile) > TacticalPerceptionRules.focused_range_tiles(observer):
		return false
	var facing: Vector2 = Vector2(
		TacticalPerceptionRules.normalized_facing(observer.facing_direction)
	).normalized()
	if facing.dot(Vector2(delta).normalized()) + 0.0001 < TacticalPerceptionRules.CONE_DOT_THRESHOLD:
		return false
	return _has_los_from_observation_origins(observer, tile)


func _has_los_from_observation_origins(
		observer: TacticalUnitState,
		tile: Vector2i
) -> bool:
	var origins_value: Variant = OBSERVATION_ORIGIN_QUERY_SCRIPT.legal_origins(
		_state_store.state, _map_definition, observer
	)
	if not origins_value is Array:
		return false
	for origin_value: Variant in origins_value:
		var origin: TacticalObservationOrigin = origin_value as TacticalObservationOrigin
		if origin == null:
			continue
		if origin.uses_automatic_peek and origin.direction != Vector2i.ZERO:
			var target_direction: Vector2 = Vector2(
				tile - observer.grid_position
			).normalized()
			var peek_direction: Vector2 = Vector2(origin.direction).normalized()
			# Automatic Peek only contributes the wedge in front of its edge. A
			# corner on the opposite side is rejected before the LOS trace.
			if target_direction != Vector2.ZERO and peek_direction.dot(
				target_direction
			) < 0.15:
				continue
		if LOS_RULES_SCRIPT.has_line_of_sight(
			origin.origin_tile, tile, _map_definition, _state_store.state
		):
			return true
	return false


func perception_tiles_for_observer(
		observer_id: StringName,
		facing_override: Vector2i = Vector2i.ZERO
) -> Dictionary:
	var observer: TacticalUnitState = _unit(observer_id)
	if observer == null:
		return {"close": [], "focused": [], "aware": []}
	var aware: bool = (
		not observer.squad_id.is_empty()
		and _state_store.state.is_squad_aware(observer.squad_id)
	)
	var resolved_facing: Vector2i = (
		observer.facing_direction
		if facing_override == Vector2i.ZERO
		else TacticalPerceptionRules.normalized_facing(facing_override)
	)
	var key: String = _cache_key(observer, resolved_facing, aware)
	if _perception_tile_cache.has(key):
		_cache_hits += 1
		var cached_value: Variant = _perception_tile_cache[key]
		if cached_value is Dictionary:
			var cached: Dictionary = cached_value
			return _duplicate_tiles(cached)
	_cache_misses += 1
	var result: Dictionary = TacticalPerceptionRules.visible_tiles_for_observer(
		observer,
		aware,
		_map_definition,
		resolved_facing,
		_state_store.state
	)
	if _perception_tile_cache.size() >= 256:
		_perception_tile_cache.clear()
	_perception_tile_cache[key] = _duplicate_tiles(result)
	return result


func observer_known_to_player(observer: TacticalUnitState) -> bool:
	if observer == null:
		return false
	if _visibility_service == null:
		return true
	return bool(
		_visibility_service.call("is_unit_visible_to_team", &"player", observer)
	)


func clear_cache() -> void:
	_perception_tile_cache.clear()


func performance_snapshot() -> Dictionary:
	return {
		"cache_entries": _perception_tile_cache.size(),
		"cache_hits": _cache_hits,
		"cache_misses": _cache_misses,
	}


func _cache_key(
		observer: TacticalUnitState,
		facing: Vector2i,
		aware: bool
) -> String:
	return "%s|%d,%d|%d,%d|%d|%d" % [
		observer.unit_id,
		observer.grid_position.x,
		observer.grid_position.y,
		facing.x,
		facing.y,
		1 if aware else 0,
		_map_vision_fingerprint(),
	]


func _map_vision_fingerprint() -> int:
	if _map_definition == null:
		return 0
	return hash([
		_map_definition.grid_size,
		_map_definition.blocked_tiles,
		_map_definition.visibility_blocking_tiles,
		_map_definition.stone_wall_tiles,
		_map_definition.wood_wall_tiles,
		_state_store.state.geometry_revision(),
	])


func _duplicate_tiles(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var categories: Array[String] = ["close", "focused", "aware"]
	for key: String in categories:
		var values: Array[Vector2i] = []
		var source_values: Array = source.get(key, [])
		for value: Variant in source_values:
			if value is Vector2i:
				values.append(Vector2i(value))
		result[key] = values
	return result


func _unit(unit_id: StringName) -> TacticalUnitState:
	return (
		_state_store.state.get_unit(unit_id)
		if _state_store != null and _state_store.state != null
		else null
	)
