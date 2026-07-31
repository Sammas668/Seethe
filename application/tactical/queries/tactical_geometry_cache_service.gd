class_name TacticalGeometryCacheService
extends RefCounted

const MAX_ENTRIES: int = 1024

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _entries: Dictionary = {}
var _cache_hits: int = 0
var _cache_misses: int = 0
var _evictions: int = 0
var _five_sample_trace_count: int = 0


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	clear()


func evaluate(
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		origin_override: Variant = null,
		target_position_override: Variant = null
) -> TacticalCombatGeometryResult:
	if (
		_state_store == null
		or _state_store.state == null
		or _map_definition == null
		or attacker == null
		or target == null
	):
		return TacticalCombatGeometryResult.new()
	var key: String = _cache_key(
		attacker,
		target,
		origin_override,
		target_position_override
	)
	if _entries.has(key):
		_cache_hits += 1
		return _entries[key] as TacticalCombatGeometryResult
	_cache_misses += 1
	_five_sample_trace_count += 5
	var result: TacticalCombatGeometryResult = TacticalCombatGeometryQuery.evaluate(
		_state_store.state,
		_map_definition,
		attacker,
		target,
		origin_override,
		target_position_override
	)
	if _entries.size() >= MAX_ENTRIES:
		_entries.clear()
		_evictions += 1
	_entries[key] = result
	return result


func clear() -> void:
	_entries.clear()


func performance_snapshot() -> Dictionary:
	return {
		"cache_entries": _entries.size(),
		"cache_hits": _cache_hits,
		"cache_misses": _cache_misses,
		"evictions": _evictions,
		"five_sample_traces": _five_sample_trace_count,
	}


func _cache_key(
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		origin_override: Variant,
		target_position_override: Variant
) -> String:
	var state: TacticalState = _state_store.state
	var origin_text: String = _variant_position_text(origin_override)
	var target_text: String = _variant_position_text(target_position_override)
	return "%s|%d,%d|%s|%d,%d|%s|%s|%d|%d|%d" % [
		attacker.unit_id,
		attacker.grid_position.x,
		attacker.grid_position.y,
		target.unit_id,
		target.grid_position.x,
		target.grid_position.y,
		origin_text,
		target_text,
		state.spatial_occupancy_revision(),
		state.geometry_revision(),
		state.spatial_visibility_blocker_revision(),
	]


func _variant_position_text(value: Variant) -> String:
	if value is Vector2:
		var vector := Vector2(value)
		return "v2:%.4f,%.4f" % [vector.x, vector.y]
	if value is Vector2i:
		var tile := Vector2i(value)
		return "v2i:%d,%d" % [tile.x, tile.y]
	return "none"
