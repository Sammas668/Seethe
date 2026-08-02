class_name TacticalVisibilityService
extends RefCounted

const TacticalGridDistance: Script = preload(
	"res://domain/tactical/tactical_grid_distance.gd"
)
const TacticalLineOfSightRules: Script = preload(
	"res://domain/tactical/visibility/tactical_line_of_sight_rules.gd"
)
const VISIBILITY_STATE_SCRIPT: Script = preload(
	"res://domain/tactical/visibility/tactical_visibility_state.gd"
)
const OBSERVATION_ORIGIN_QUERY_SCRIPT: Script = preload(
	"res://domain/tactical/geometry/tactical_observation_origin_query.gd"
)
const VISIBILITY_RAY_CACHE_SCRIPT: Script = preload(
	"res://domain/tactical/visibility/tactical_visibility_ray_cache.gd"
)
const VISIBILITY_FIELD_SCRIPT: Script = preload(
	"res://domain/tactical/visibility/tactical_visibility_field.gd"
)
const EDGE_SHADOWCAST_FOV_SCRIPT: Script = preload(
	"res://domain/tactical/visibility/tactical_edge_shadowcast_fov.gd"
)
const VISIBILITY_PREPARATION_JOB_SCRIPT: Script = preload(
	"res://application/tactical/visibility/tactical_visibility_preparation_job.gd"
)

const TILE_UNSEEN: int = 0
const TILE_EXPLORED: int = 1
const TILE_VISIBLE: int = 2

const VISIBILITY_AFFECTING_REASONS: Dictionary = {
	&"runtime_spawn": true,
	&"unit_moved": true,
	&"unit_sprinted": true,
	&"enemy_unit_moved": true,
	&"character_resolved": true,
	&"vision_blocker_changed": true,
	&"environment_geometry_changed": true,
	&"opening_state_changed": true,
	&"structure_state_changed": true,
	&"structure_attacked": true,
	&"unit_peeked": true,
	&"unit_removed": true,
}

signal visibility_changed(revision: int)
signal visibility_delta_changed(team_id: StringName, delta: Dictionary)

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _visibility_state: RefCounted
var _recalculation_count: int = 0
var _full_recalculation_count: int = 0
var _incremental_recalculation_count: int = 0
var _skipped_change_count: int = 0
var _last_recalculation_usec: int = 0
var _last_incremental_recalculation_usec: int = 0
var _last_incremental_unit_count: int = 0
var _pending_explored_by_team: Dictionary = {}
var _centre_los_trace_count: int = 0
var _peek_additional_los_trace_count: int = 0
var _recalculation_deferral_depth: int = 0
var _deferred_recalculation_pending: bool = false
var _deferred_force_full_recalculation: bool = false
var _deferred_unit_ids: Dictionary = {}
var _ray_cache: TacticalVisibilityRayCache
var _edge_fov: TacticalEdgeShadowcastFov
var _centre_field_cache: Array = []
var _peek_field_cache: Dictionary = {}
var _peek_field_cache_order: Array[String] = []
var _visibility_field_cache_hits: int = 0
var _visibility_field_cache_misses: int = 0
var _prebaked_centre_field_count: int = 0
var _prebaked_peek_field_count: int = 0
var _prebake_usec: int = 0
var _prebaked_bitset_bytes: int = 0
var _startup_prewarm_field_limit_hits: int = 0
var _startup_full_map_bake_skipped: bool = true
var _destination_prewarm_count: int = 0
var _destination_prewarm_cache_hits: int = 0
var _last_destination_prewarm_usec: int = 0
var _direct_delta_update_count: int = 0
var _direct_delta_cancelled_crossing_count: int = 0
var _prepared_fields_by_unit: Dictionary = {}
var _prepared_field_hits: int = 0
var _prepared_field_misses: int = 0
var _last_delta_by_team: Dictionary = {}
var _last_exploration_commit_usec: int = 0
var _last_newly_explored_count: int = 0
var _lightweight_exploration_commit_count: int = 0
var _last_visibility_delta_cell_count: int = 0
var _last_visibility_delta_build_usec: int = 0
var _last_destination_prepare_cache_hit: bool = false
var _prepared_field_invalidations: int = 0
var _last_prepare_visibility_for_units_usec: int = 0
var _last_visibility_merge_usec: int = 0
var _destination_preparation_jobs_started: int = 0
var _destination_preparation_jobs_completed: int = 0
var _destination_preparation_jobs_cancelled: int = 0
var _destination_preparation_job_slices: int = 0
var _last_destination_preparation_processing_usec: int = 0
# Legacy Stage 4.4e validator marker: centre_visible. Runtime now stores the
# centre contribution as a TacticalVisibilityField bitset.

const PEEK_FIELD_CACHE_LIMIT: int = 512
# Stage 4.5e7a startup safety: mission construction may warm only the fields
# required by currently deployed observers. A full-map bake is deliberately not
# permitted on the startup call stack.
const STARTUP_PREWARM_MAX_FIELD_COUNT: int = 96


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_visibility_state = VISIBILITY_STATE_SCRIPT.new() as RefCounted
	# The legacy relative-ray cache remains available for comparison tests and
	# combat geometry, but movement FOV no longer traces every destination ray.
	_ray_cache = VISIBILITY_RAY_CACHE_SCRIPT.new() as TacticalVisibilityRayCache
	_ray_cache.configure(TacticalGridDistance.GENERAL_SIGHT_RADIUS_TILES)
	_edge_fov = EDGE_SHADOWCAST_FOV_SCRIPT.new() as TacticalEdgeShadowcastFov
	_edge_fov.configure(
		_state_store,
		_map_definition,
		TacticalGridDistance.GENERAL_SIGHT_RADIUS_TILES,
		_ray_cache
	)
	_centre_field_cache.clear()
	_centre_field_cache.resize(
		maxi(0, _map_definition.grid_size.x * _map_definition.grid_size.y)
		if _map_definition != null
		else 0
	)
	_peek_field_cache.clear()
	_peek_field_cache_order.clear()
	_prepared_fields_by_unit.clear()
	_last_delta_by_team.clear()
	_visibility_state.call(
		"configure",
		_map_definition.grid_size if _map_definition != null else Vector2i.ZERO
	)
	if _state_store != null and _state_store.state != null:
		_state_store.state.configure_knowledge_grid(
			_map_definition.grid_size
			if _map_definition != null
			else Vector2i.ZERO
		)
		_state_store.state_changed_with_flags.connect(_on_tactical_state_changed_with_flags)
	_prewarm_active_unit_visibility_fields()
	recalculate_all_teams(true)


func state() -> RefCounted:
	return _visibility_state


func revision() -> int:
	return int(_visibility_state.get("revision")) if _visibility_state != null else 0


func recalculate_all_teams(force: bool = false) -> void:
	if not _can_recalculate():
		return
	if _recalculation_deferral_depth > 0:
		_deferred_recalculation_pending = true
		_deferred_force_full_recalculation = true
		return
	if not force and _active_team_ids().is_empty():
		return

	var started_usec: int = Time.get_ticks_usec()
	var teams: Array[StringName] = _active_team_ids()
	var visible_before: Dictionary = _visible_indices_snapshot(teams)
	_pending_explored_by_team.clear()
	_visibility_state.call("begin_recalculation", teams)
	for unit: TacticalUnitState in _state_store.state.get_units():
		if unit == null or unit.is_defeated() or unit.team_id.is_empty():
			continue
		_replace_visibility_from_unit(unit)
	# Full rebuilds are rare and may safely enumerate each final team field once.
	# Incremental movement below never performs this complete visible-index scan.
	for team_id: StringName in teams:
		var visible_indices: PackedInt32Array = _visibility_state.call(
			"visible_indices",
			team_id
		)
		for index: int in visible_indices:
			_queue_explored_tile(
				team_id,
				Vector2i(_visibility_state.call("tile_from_index", index))
			)
	var newly_explored_by_team: Dictionary = _commit_exploration_batch()
	_visibility_state.call("complete_recalculation")
	_publish_visibility_deltas(
		teams,
		visible_before,
		newly_explored_by_team,
		true
	)
	_recalculation_count += 1
	_full_recalculation_count += 1
	_last_recalculation_usec = Time.get_ticks_usec() - started_usec
	visibility_changed.emit(revision())


# Stage 4.4e3: ordinary movement updates only the moved observers' visibility
# contributions. The rest of each team's contributions remain intact.
func recalculate_units(
		unit_ids: Array[StringName],
		force: bool = false
) -> void:
	if not _can_recalculate():
		return
	if unit_ids.is_empty():
		if force:
			recalculate_all_teams(true)
		return
	if _recalculation_deferral_depth > 0:
		_deferred_recalculation_pending = true
		for unit_id: StringName in unit_ids:
			if not unit_id.is_empty():
				_deferred_unit_ids[unit_id] = true
		return

	var started_usec: int = Time.get_ticks_usec()
	var unique_ids: Array[StringName] = []
	var changed_teams: Array[StringName] = []
	for unit_id: StringName in unit_ids:
		if unit_id.is_empty() or unique_ids.has(unit_id):
			continue
		unique_ids.append(unit_id)
		var current_unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
		var contribution_team := StringName(
			_visibility_state.call("team_id_for_unit", unit_id)
		)
		var changed_team: StringName = (
			current_unit.team_id
			if current_unit != null and not current_unit.team_id.is_empty()
			else contribution_team
		)
		if not changed_team.is_empty() and not changed_teams.has(changed_team):
			changed_teams.append(changed_team)
	unique_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	changed_teams.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	if changed_teams.is_empty():
		changed_teams = _active_team_ids()

	_pending_explored_by_team.clear()
	var boundary_deltas: Dictionary = {}
	for unit_id: StringName in unique_ids:
		var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
		var unit_delta: Dictionary = {}
		if unit == null or unit.is_defeated() or unit.team_id.is_empty():
			unit_delta = _visibility_state.call(
				"remove_unit_visibility_with_delta",
				unit_id
			)
		else:
			unit_delta = _replace_visibility_from_unit(unit)
		_merge_boundary_deltas(boundary_deltas, unit_delta)

	_queue_exploration_from_boundary_deltas(boundary_deltas)
	var newly_explored_by_team: Dictionary = _commit_exploration_batch()
	_visibility_state.call("complete_recalculation")
	_publish_direct_visibility_deltas(
		changed_teams,
		boundary_deltas,
		newly_explored_by_team,
		false
	)
	_recalculation_count += 1
	_incremental_recalculation_count += 1
	_direct_delta_update_count += 1
	_last_incremental_unit_count = unique_ids.size()
	_last_incremental_recalculation_usec = Time.get_ticks_usec() - started_usec
	_last_recalculation_usec = _last_incremental_recalculation_usec
	_last_visibility_merge_usec = _last_incremental_recalculation_usec
	visibility_changed.emit(revision())

func begin_recalculation_deferral() -> void:
	_recalculation_deferral_depth += 1


# Compatibility path for non-movement callers. Without exact changed observers,
# the safe fallback remains a full rebuild.
func end_recalculation_deferral() -> void:
	end_recalculation_deferral_for_units([], true)


func end_recalculation_deferral_for_units(
		unit_ids: Array[StringName],
		force_full: bool = false
) -> void:
	for unit_id: StringName in unit_ids:
		if not unit_id.is_empty():
			_deferred_unit_ids[unit_id] = true
	_deferred_force_full_recalculation = (
		_deferred_force_full_recalculation or force_full
	)
	_recalculation_deferral_depth = maxi(0, _recalculation_deferral_depth - 1)
	if _recalculation_deferral_depth > 0:
		return
	if (
		not _deferred_recalculation_pending
		and _deferred_unit_ids.is_empty()
		and not _deferred_force_full_recalculation
	):
		return

	var pending_ids: Array[StringName] = []
	for unit_id_value: Variant in _deferred_unit_ids.keys():
		pending_ids.append(StringName(unit_id_value))
	var perform_full: bool = (
		_deferred_force_full_recalculation
		or (_deferred_recalculation_pending and pending_ids.is_empty())
	)
	_deferred_recalculation_pending = false
	_deferred_force_full_recalculation = false
	_deferred_unit_ids.clear()
	if perform_full:
		recalculate_all_teams(true)
	else:
		recalculate_units(pending_ids, true)


func invalidate_for_map_change() -> void:
	if _recalculation_deferral_depth > 0:
		_deferred_recalculation_pending = true
		_deferred_force_full_recalculation = true
		return
	recalculate_all_teams(true)


func is_tile_visible(team_id: StringName, tile: Vector2i) -> bool:
	return (
		_visibility_state != null
		and bool(_visibility_state.call("is_visible", team_id, tile))
	)


func is_tile_explored(team_id: StringName, tile: Vector2i) -> bool:
	return (
		_state_store != null
		and _state_store.state != null
		and _state_store.state.is_tile_explored(team_id, tile)
	)


func tile_state(team_id: StringName, tile: Vector2i) -> int:
	if is_tile_visible(team_id, tile):
		return TILE_VISIBLE
	if is_tile_explored(team_id, tile):
		return TILE_EXPLORED
	return TILE_UNSEEN


func is_unit_visible_to_team(
		team_id: StringName,
		unit: TacticalUnitState
) -> bool:
	if unit == null:
		return false
	if unit.team_id == team_id:
		return true
	if (
		unit.stealth_enabled
		and not _state_store.state.is_unit_revealed_to_team(unit.unit_id, team_id)
	):
		return false
	for cell: Vector2i in _state_store.state.occupied_cells_for_unit(unit):
		if is_tile_visible(team_id, cell):
			return true
	return false


func visible_tile_count(team_id: StringName) -> int:
	return (
		int(_visibility_state.call("visible_tile_count", team_id))
		if _visibility_state != null
		else 0
	)


func explored_tile_count(team_id: StringName) -> int:
	return (
		_state_store.state.explored_tile_count(team_id)
		if _state_store != null and _state_store.state != null
		else 0
	)


func performance_snapshot() -> Dictionary:
	return {
		"recalculation_count": _recalculation_count,
		"full_recalculation_count": _full_recalculation_count,
		"incremental_recalculation_count": _incremental_recalculation_count,
		"skipped_change_count": _skipped_change_count,
		"last_recalculation_usec": _last_recalculation_usec,
		"last_incremental_recalculation_usec": _last_incremental_recalculation_usec,
		"last_incremental_unit_count": _last_incremental_unit_count,
		"visibility_revision": revision(),
		"knowledge_revision": (
			int(_state_store.state.knowledge_state.revision)
			if _state_store != null and _state_store.state != null
			else 0
		),
		"centre_los_traces": _centre_los_trace_count,
		"peek_additional_los_traces": _peek_additional_los_trace_count,
		"recalculation_deferral_depth": _recalculation_deferral_depth,
		"deferred_recalculation_pending": _deferred_recalculation_pending,
		"deferred_force_full_recalculation": _deferred_force_full_recalculation,
		"deferred_unit_count": _deferred_unit_ids.size(),
		"ray_cache": (
			_ray_cache.performance_snapshot()
			if _ray_cache != null
			else {}
		),
		"visibility_field_cache_entries": (
			_prebaked_centre_field_count + _peek_field_cache.size()
		),
		"visibility_field_cache_hits": _visibility_field_cache_hits,
		"visibility_field_cache_misses": _visibility_field_cache_misses,
		"prebaked_centre_field_count": _prebaked_centre_field_count,
		"prebaked_peek_field_count": _prebaked_peek_field_count,
		"prebake_usec": _prebake_usec,
		"prebaked_bitset_bytes": _prebaked_bitset_bytes,
		"startup_prewarm_field_limit": STARTUP_PREWARM_MAX_FIELD_COUNT,
		"startup_prewarm_field_limit_hits": _startup_prewarm_field_limit_hits,
		"startup_full_map_bake_skipped": _startup_full_map_bake_skipped,
		"destination_prewarm_count": _destination_prewarm_count,
		"destination_prewarm_cache_hits": _destination_prewarm_cache_hits,
		"last_destination_prewarm_usec": _last_destination_prewarm_usec,
		"direct_delta_update_count": _direct_delta_update_count,
		"direct_delta_cancelled_crossing_count": (
			_direct_delta_cancelled_crossing_count
		),
		"prepared_field_hits": _prepared_field_hits,
		"prepared_field_misses": _prepared_field_misses,
		"prepared_field_invalidations": _prepared_field_invalidations,
		"last_destination_prepare_cache_hit": (
			_last_destination_prepare_cache_hit
		),
		"last_prepare_visibility_for_units_usec": (
			_last_prepare_visibility_for_units_usec
		),
		"last_visibility_merge_usec": _last_visibility_merge_usec,
		"destination_preparation_jobs_started": (
			_destination_preparation_jobs_started
		),
		"destination_preparation_jobs_completed": (
			_destination_preparation_jobs_completed
		),
		"destination_preparation_jobs_cancelled": (
			_destination_preparation_jobs_cancelled
		),
		"destination_preparation_job_slices": (
			_destination_preparation_job_slices
		),
		"last_destination_preparation_processing_usec": (
			_last_destination_preparation_processing_usec
		),
		"edge_fov": (
			_edge_fov.performance_snapshot()
			if _edge_fov != null
			else {}
		),
		"last_exploration_commit_usec": _last_exploration_commit_usec,
		"last_newly_explored_count": _last_newly_explored_count,
		"lightweight_exploration_commit_count": _lightweight_exploration_commit_count,
		"last_visibility_delta_cell_count": _last_visibility_delta_cell_count,
		"last_visibility_delta_build_usec": _last_visibility_delta_build_usec,
		"observation_origin_cache": OBSERVATION_ORIGIN_QUERY_SCRIPT.performance_snapshot(),
	}


func _on_tactical_state_changed_with_flags(
		reason: StringName,
		flags: TacticalInvalidationFlags
) -> void:
	# Perception/reveal records and facing affect who is detected, not the
	# geometric set of visible tiles. Rebuilding all team sight here was the
	# largest hidden cost immediately after the targeted movement refresh.
	if reason in [&"current_perception_resolved", &"unit_faced_direction"]:
		_skipped_change_count += 1
		return
	if flags == null:
		_on_tactical_state_changed(reason)
		return
	# Visibility invalidation is explicit. Occupancy and combat-geometry changes
	# do not automatically imply that the fog field changed. Movement, spawning,
	# removed sight blockers and other true sight changes set visibility_changed.
	if not flags.visibility_changed:
		_skipped_change_count += 1
		return
	if flags is TacticalInvalidationContract:
		var contract := flags as TacticalInvalidationContract
		if not contract.geometry_changed and not contract.moved_observer_ids.is_empty():
			recalculate_units(contract.moved_observer_ids, true)
			return
	if _recalculation_deferral_depth > 0:
		_deferred_recalculation_pending = true
		if flags.geometry_changed:
			_deferred_force_full_recalculation = true
		return
	recalculate_all_teams(true)


func _on_tactical_state_changed(reason: StringName) -> void:
	if reason in [&"current_perception_resolved", &"unit_faced_direction"]:
		_skipped_change_count += 1
		return
	if not VISIBILITY_AFFECTING_REASONS.has(reason):
		_skipped_change_count += 1
		return
	if _recalculation_deferral_depth > 0:
		_deferred_recalculation_pending = true
		if reason in [
			&"vision_blocker_changed",
			&"environment_geometry_changed",
			&"opening_state_changed",
			&"structure_state_changed",
			&"structure_attacked",
		]:
			_deferred_force_full_recalculation = true
		return
	recalculate_all_teams(true)


func _active_team_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for unit: TacticalUnitState in _state_store.state.get_units():
		if unit == null or unit.team_id.is_empty():
			continue
		if not result.has(unit.team_id):
			result.append(unit.team_id)
	result.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return str(a) < str(b)
	)
	return result


func _replace_visibility_from_unit(unit: TacticalUnitState) -> Dictionary:
	var visible_field: TacticalVisibilityField = _prepared_field_for_unit(unit)
	if visible_field == null:
		visible_field = _visible_field_for_unit(unit)
	return _visibility_state.call(
		"replace_unit_visibility_field",
		unit.unit_id,
		unit.team_id,
		visible_field
	)


func _visible_tiles_for_unit(unit: TacticalUnitState) -> Dictionary:
	# Compatibility wrapper for detection and legacy tests. Runtime movement uses
	# the compact field directly and does not allocate one Vector2i dictionary key
	# per visible tile.
	var result: Dictionary = {}
	var field: TacticalVisibilityField = _visible_field_for_unit(unit)
	for index: int in field.visible_indices():
		result[Vector2i(_visibility_state.call("tile_from_index", index))] = true
	return result

func _reveal_from_origin(
		unit: TacticalUnitState,
		_origin: TacticalObservationOrigin
) -> void:
	if unit == null:
		return
	recalculate_units([unit.unit_id], true)


func _visible_field_for_unit(unit: TacticalUnitState) -> TacticalVisibilityField:
	var result: TacticalVisibilityField = (
		VISIBILITY_FIELD_SCRIPT.new() as TacticalVisibilityField
	)
	result.configure(
		_map_definition.grid_size if _map_definition != null else Vector2i.ZERO
	)
	if unit == null or unit.is_defeated():
		return result
	var occupied_cells: Array[Vector2i] = (
		_state_store.state.occupied_cells_for_unit(unit)
	)
	for occupied_origin: Vector2i in occupied_cells:
		result.merge_from(_cached_visibility_field(
			occupied_origin,
			Vector2i.ZERO,
			false
		))

		var origins_value: Variant = (
			OBSERVATION_ORIGIN_QUERY_SCRIPT.legal_origins(
				_state_store.state,
				_map_definition,
				unit,
				occupied_origin
			)
		)
		if origins_value is Array:
			for origin_value: Variant in origins_value:
				var observation_origin: TacticalObservationOrigin = (
					origin_value as TacticalObservationOrigin
				)
				if (
					observation_origin == null
					or not observation_origin.uses_automatic_peek
				):
					continue
				result.merge_from(_cached_visibility_field(
					observation_origin.origin_tile,
					observation_origin.direction,
					true
				))

	# Locked Seethe rule: a unit always sees its own and adjacent tiles.
	for cell: Vector2i in occupied_cells:
		for adjacent_y: int in range(-1, 2):
			for adjacent_x: int in range(-1, 2):
				var adjacent := cell + Vector2i(adjacent_x, adjacent_y)
				if _map_definition.is_inside(adjacent):
					result.set_tile(adjacent)
	return result


func _visible_tiles_from_origin(
		origin: Vector2i,
		peek_direction: Vector2i,
		skip_tiles: Dictionary,
		additional_peek_only: bool
) -> Dictionary:
	var field: TacticalVisibilityField = _cached_visibility_field(
		origin,
		peek_direction if additional_peek_only else Vector2i.ZERO,
		additional_peek_only
	)
	var result: Dictionary = {}
	for index: int in field.visible_indices():
		var tile := Vector2i(_visibility_state.call("tile_from_index", index))
		if not skip_tiles.has(tile):
			result[tile] = true
	return result


func _cached_visibility_field(
		origin: Vector2i,
		peek_direction: Vector2i,
		additional_peek_only: bool,
		allow_calculation: bool = true
) -> TacticalVisibilityField:
	if _edge_fov == null or _map_definition == null:
		var empty_field: TacticalVisibilityField = (
			VISIBILITY_FIELD_SCRIPT.new() as TacticalVisibilityField
		)
		empty_field.configure(
			_map_definition.grid_size if _map_definition != null else Vector2i.ZERO
		)
		return empty_field
	var stamp: int = _edge_fov.geometry_stamp_for_origin(origin)
	if not additional_peek_only or peek_direction == Vector2i.ZERO:
		var cache_index: int = _tile_index(origin)
		if cache_index >= 0 and cache_index < _centre_field_cache.size():
			var entry_value: Variant = _centre_field_cache[cache_index]
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				var cached_field := entry.get("field") as TacticalVisibilityField
				if cached_field != null and int(entry.get("stamp", -1)) == stamp:
					_visibility_field_cache_hits += 1
					return cached_field
		if not allow_calculation:
			return null
		_visibility_field_cache_misses += 1
		var calculated: TacticalVisibilityField = _edge_fov.calculate(origin)
		if cache_index >= 0 and cache_index < _centre_field_cache.size():
			_centre_field_cache[cache_index] = {
				"stamp": stamp,
				"field": calculated,
			}
		return calculated

	var cache_key: String = "%d:%d:%d:%d:%d" % [
		origin.x,
		origin.y,
		peek_direction.x,
		peek_direction.y,
		stamp,
	]
	if _peek_field_cache.has(cache_key):
		_visibility_field_cache_hits += 1
		var cached_peek := _peek_field_cache.get(cache_key) as TacticalVisibilityField
		if cached_peek != null:
			return cached_peek
	if not allow_calculation:
		return null
	_visibility_field_cache_misses += 1
	var result: TacticalVisibilityField = _edge_fov.calculate(
		origin,
		peek_direction
	)
	_peek_additional_los_trace_count += result.visible_count
	_peek_field_cache[cache_key] = result
	_peek_field_cache_order.append(cache_key)
	while _peek_field_cache_order.size() > PEEK_FIELD_CACHE_LIMIT:
		var stale_key: String = _peek_field_cache_order.pop_front()
		_peek_field_cache.erase(stale_key)
	return result


func prepare_visibility_for_destination(
	unit_id: StringName,
	destination: Vector2i
) -> bool:
	# Compatibility entry point. Runtime enemy planning uses the resumable job
	# API so cache-miss FOV work is split across rendered frames.
	var job: TacticalVisibilityPreparationJob = (
		begin_visibility_preparation_for_destination(unit_id, destination)
	)
	if job == null:
		return false
	while not job.complete:
		step_visibility_preparation_job(job, 1_000_000)
	return job.valid


func begin_visibility_preparation_for_destination(
	unit_id: StringName,
	destination: Vector2i
) -> TacticalVisibilityPreparationJob:
	var started_usec: int = Time.get_ticks_usec()
	if (
		_state_store == null
		or _state_store.state == null
		or _map_definition == null
		or not _map_definition.is_inside(destination)
	):
		_last_destination_prewarm_usec = maxi(
			0, Time.get_ticks_usec() - started_usec
		)
		return null
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null or unit.is_defeated() or unit.team_id.is_empty():
		_last_destination_prewarm_usec = maxi(
			0, Time.get_ticks_usec() - started_usec
		)
		return null
	var geometry_revision: int = _state_store.state.geometry_revision()
	var existing_value: Variant = _prepared_fields_by_unit.get(unit_id, {})
	if existing_value is Dictionary:
		var existing: Dictionary = existing_value
		if (
			Vector2i(existing.get("position", Vector2i(-1, -1)))
			== destination
			and int(existing.get("geometry_revision", -1))
			== geometry_revision
			and existing.get("field") is TacticalVisibilityField
		):
			_destination_prewarm_cache_hits += 1
			_last_destination_prepare_cache_hit = true
			var completed_job := (
				VISIBILITY_PREPARATION_JOB_SCRIPT.new()
				as TacticalVisibilityPreparationJob
			)
			completed_job.configure(
				unit_id,
				destination,
				geometry_revision,
				_occupied_cells_at(unit, destination),
				[],
				existing.get("field") as TacticalVisibilityField
			)
			completed_job.cache_hits = 1
			completed_job.mark_complete(true)
			_last_destination_prewarm_usec = maxi(
				0, Time.get_ticks_usec() - started_usec
			)
			return completed_job
	_last_destination_prepare_cache_hit = false
	var occupied_cells: Array[Vector2i] = _occupied_cells_at(unit, destination)
	var requests: Array[Dictionary] = []
	var seen_requests: Dictionary = {}
	for occupied_origin: Vector2i in occupied_cells:
		_append_visibility_preparation_request(
			requests,
			seen_requests,
			occupied_origin,
			Vector2i.ZERO,
			false
		)
		var origins_value: Variant = OBSERVATION_ORIGIN_QUERY_SCRIPT.legal_origins(
			_state_store.state,
			_map_definition,
			unit,
			occupied_origin
		)
		if not (origins_value is Array):
			continue
		for origin_value: Variant in origins_value:
			var observation_origin := origin_value as TacticalObservationOrigin
			if (
				observation_origin == null
				or not observation_origin.uses_automatic_peek
			):
				continue
			_append_visibility_preparation_request(
				requests,
				seen_requests,
				observation_origin.origin_tile,
				observation_origin.direction,
				true
			)
	var field := VISIBILITY_FIELD_SCRIPT.new() as TacticalVisibilityField
	field.configure(_map_definition.grid_size)
	var job := (
		VISIBILITY_PREPARATION_JOB_SCRIPT.new()
		as TacticalVisibilityPreparationJob
	)
	job.configure(
		unit_id,
		destination,
		geometry_revision,
		occupied_cells,
		requests,
		field
	)
	_destination_preparation_jobs_started += 1
	_last_destination_prewarm_usec = maxi(
		0, Time.get_ticks_usec() - started_usec
	)
	return job


func step_visibility_preparation_job(
	job: TacticalVisibilityPreparationJob,
	budget_usec: int = 3000
) -> bool:
	if job == null or job.complete:
		return true
	if (
		_state_store == null
		or _state_store.state == null
		or job.geometry_revision != _state_store.state.geometry_revision()
	):
		_prepared_field_invalidations += 1
		job.mark_complete(false)
		return true
	var slice_started_usec: int = Time.get_ticks_usec()
	var deadline_usec: int = slice_started_usec + maxi(250, budget_usec)
	job.processing_slices += 1
	_destination_preparation_job_slices += 1
	while job.request_index < job.requests.size():
		if Time.get_ticks_usec() >= deadline_usec:
			break
		var request: Dictionary = job.requests[job.request_index]
		job.request_index += 1
		var hits_before: int = _visibility_field_cache_hits
		var misses_before: int = _visibility_field_cache_misses
		var field: TacticalVisibilityField = _cached_visibility_field(
			Vector2i(request.get("origin", Vector2i.ZERO)),
			Vector2i(request.get("direction", Vector2i.ZERO)),
			bool(request.get("peek", false)),
			true
		)
		job.cache_hits += maxi(0, _visibility_field_cache_hits - hits_before)
		job.cache_misses += maxi(0, _visibility_field_cache_misses - misses_before)
		if field == null:
			job.mark_complete(false)
			break
		job.result_field.merge_from(field)
	var elapsed_usec: int = maxi(0, Time.get_ticks_usec() - slice_started_usec)
	job.processing_usec += elapsed_usec
	_last_destination_preparation_processing_usec = job.processing_usec
	if job.complete:
		return true
	if job.request_index < job.requests.size():
		return false
	for cell: Vector2i in job.occupied_cells:
		for adjacent_y: int in range(-1, 2):
			for adjacent_x: int in range(-1, 2):
				var adjacent := cell + Vector2i(adjacent_x, adjacent_y)
				if _map_definition.is_inside(adjacent):
					job.result_field.set_tile(adjacent)
	if job.geometry_revision != _state_store.state.geometry_revision():
		_prepared_field_invalidations += 1
		job.mark_complete(false)
		return true
	_prepared_fields_by_unit[job.unit_id] = {
		"position": job.destination,
		"geometry_revision": job.geometry_revision,
		"field": job.result_field,
	}
	_destination_prewarm_count += 1
	_destination_preparation_jobs_completed += 1
	_last_destination_prepare_cache_hit = job.cache_misses == 0
	_last_destination_prewarm_usec = maxi(
		0, Time.get_ticks_usec() - job.started_usec
	)
	job.mark_complete(true)
	return true


func cancel_visibility_preparation_job(
	job: TacticalVisibilityPreparationJob
) -> void:
	if job == null or job.complete:
		return
	job.cancel()
	_destination_preparation_jobs_cancelled += 1


func _append_visibility_preparation_request(
	requests: Array[Dictionary],
	seen: Dictionary,
	origin: Vector2i,
	direction: Vector2i,
	peek: bool
) -> void:
	var key: String = "%d:%d:%d:%d:%d" % [
		origin.x,
		origin.y,
		direction.x,
		direction.y,
		1 if peek else 0,
	]
	if seen.has(key):
		return
	seen[key] = true
	requests.append({
		"origin": origin,
		"direction": direction,
		"peek": peek,
	})


func prepare_visibility_for_units(unit_ids: Array[StringName]) -> void:
	var started_usec: int = Time.get_ticks_usec()
	for unit_id: StringName in unit_ids:
		var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
		if unit == null or unit.is_defeated() or unit.team_id.is_empty():
			continue
		var existing_value: Variant = _prepared_fields_by_unit.get(unit_id, {})
		if existing_value is Dictionary:
			var existing: Dictionary = existing_value
			if (
				Vector2i(existing.get("position", Vector2i(-1, -1)))
				== unit.grid_position
				and int(existing.get("geometry_revision", -1))
				== _state_store.state.geometry_revision()
				and existing.get("field") is TacticalVisibilityField
			):
				_prepared_field_hits += 1
				continue
		var prepared: TacticalVisibilityField = _try_build_prepared_field(unit)
		if prepared == null:
			_prepared_field_misses += 1
			continue
		_prepared_fields_by_unit[unit_id] = {
			"position": unit.grid_position,
			"geometry_revision": _state_store.state.geometry_revision(),
			"field": prepared,
		}
		_prepared_field_hits += 1
	_last_prepare_visibility_for_units_usec = maxi(
		0,
		Time.get_ticks_usec() - started_usec
	)


func last_destination_prepare_cache_hit() -> bool:
	return _last_destination_prepare_cache_hit


func _try_build_prepared_field(
		unit: TacticalUnitState
) -> TacticalVisibilityField:
	return _build_visibility_field_for_unit_at(
		unit,
		unit.grid_position if unit != null else Vector2i.ZERO,
		true
	)


func _build_visibility_field_for_unit_at(
		unit: TacticalUnitState,
		position: Vector2i,
		allow_calculation: bool
) -> TacticalVisibilityField:
	if unit == null or _map_definition == null:
		return null
	var result: TacticalVisibilityField = (
		VISIBILITY_FIELD_SCRIPT.new() as TacticalVisibilityField
	)
	result.configure(_map_definition.grid_size)
	var occupied_cells: Array[Vector2i] = _occupied_cells_at(unit, position)
	for occupied_origin: Vector2i in occupied_cells:
		var centre: TacticalVisibilityField = _cached_visibility_field(
			occupied_origin,
			Vector2i.ZERO,
			false,
			allow_calculation
		)
		if centre == null:
			return null
		result.merge_from(centre)
		var origins_value: Variant = OBSERVATION_ORIGIN_QUERY_SCRIPT.legal_origins(
			_state_store.state,
			_map_definition,
			unit,
			occupied_origin
		)
		if origins_value is Array:
			for origin_value: Variant in origins_value:
				var observation_origin := origin_value as TacticalObservationOrigin
				if (
					observation_origin == null
					or not observation_origin.uses_automatic_peek
				):
					continue
				var peek_field: TacticalVisibilityField = _cached_visibility_field(
					observation_origin.origin_tile,
					observation_origin.direction,
					true,
					allow_calculation
				)
				if peek_field == null:
					return null
				result.merge_from(peek_field)
	for cell: Vector2i in occupied_cells:
		for adjacent_y: int in range(-1, 2):
			for adjacent_x: int in range(-1, 2):
				var adjacent := cell + Vector2i(adjacent_x, adjacent_y)
				if _map_definition.is_inside(adjacent):
					result.set_tile(adjacent)
	return result


func _occupied_cells_at(
		unit: TacticalUnitState,
		position: Vector2i
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null:
		return result
	for y: int in range(maxi(1, unit.footprint.y)):
		for x: int in range(maxi(1, unit.footprint.x)):
			var cell := position + Vector2i(x, y)
			if _map_definition == null or _map_definition.is_inside(cell):
				result.append(cell)
	return result


func _prepared_field_for_unit(
		unit: TacticalUnitState
) -> TacticalVisibilityField:
	if unit == null or not _prepared_fields_by_unit.has(unit.unit_id):
		return null
	var entry_value: Variant = _prepared_fields_by_unit.get(unit.unit_id, {})
	_prepared_fields_by_unit.erase(unit.unit_id)
	if not (entry_value is Dictionary):
		return null
	var entry: Dictionary = entry_value
	if (
		Vector2i(entry.get("position", Vector2i(-1, -1))) != unit.grid_position
		or int(entry.get("geometry_revision", -1))
		!= _state_store.state.geometry_revision()
	):
		_prepared_field_invalidations += 1
		return null
	return entry.get("field") as TacticalVisibilityField


func _prewarm_active_unit_visibility_fields() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_prebaked_centre_field_count = 0
	_prebaked_peek_field_count = 0
	_prebaked_bitset_bytes = 0
	_startup_prewarm_field_limit_hits = 0
	_startup_full_map_bake_skipped = true
	if (
		_edge_fov == null
		or _map_definition == null
		or _state_store == null
		or _state_store.state == null
	):
		_prebake_usec = Time.get_ticks_usec() - started_usec
		return
	_edge_fov.synchronise_geometry()
	var seen_centres: Dictionary = {}
	var seen_peeks: Dictionary = {}
	var fields_built: int = 0
	for unit: TacticalUnitState in _state_store.state.get_units():
		if unit == null or unit.is_defeated() or unit.team_id.is_empty():
			continue
		for occupied_origin: Vector2i in _occupied_cells_at(unit, unit.grid_position):
			if fields_built >= STARTUP_PREWARM_MAX_FIELD_COUNT:
				_startup_prewarm_field_limit_hits += 1
				break
			var centre_index: int = _tile_index(occupied_origin)
			if not seen_centres.has(centre_index):
				var centre: TacticalVisibilityField = _cached_visibility_field(
					occupied_origin,
					Vector2i.ZERO,
					false,
					true
				)
				seen_centres[centre_index] = true
				fields_built += 1
				_prebaked_centre_field_count += 1
				_prebaked_bitset_bytes += centre.bits.size()
			var origins_value: Variant = OBSERVATION_ORIGIN_QUERY_SCRIPT.legal_origins(
				_state_store.state,
				_map_definition,
				unit,
				occupied_origin
			)
			if not (origins_value is Array):
				continue
			for origin_value: Variant in origins_value:
				if fields_built >= STARTUP_PREWARM_MAX_FIELD_COUNT:
					_startup_prewarm_field_limit_hits += 1
					break
				var observation_origin := origin_value as TacticalObservationOrigin
				if (
					observation_origin == null
					or not observation_origin.uses_automatic_peek
				):
					continue
				var peek_key: String = "%d:%d:%d:%d" % [
					observation_origin.origin_tile.x,
					observation_origin.origin_tile.y,
					observation_origin.direction.x,
					observation_origin.direction.y,
				]
				if seen_peeks.has(peek_key):
					continue
				var peek_field: TacticalVisibilityField = _cached_visibility_field(
					observation_origin.origin_tile,
					observation_origin.direction,
					true,
					true
				)
				seen_peeks[peek_key] = true
				fields_built += 1
				_prebaked_peek_field_count += 1
				_prebaked_bitset_bytes += peek_field.bits.size()
		if fields_built >= STARTUP_PREWARM_MAX_FIELD_COUNT:
			break
	_prebake_usec = Time.get_ticks_usec() - started_usec


# Compatibility entry point retained for older test harnesses. It intentionally
# performs only the bounded active-observer prewarm; it must never loop across
# every walkable map tile during mission construction.
func _prebake_walkable_visibility_fields() -> void:
	_prewarm_active_unit_visibility_fields()


# Return the exact virtual origin/direction pairs that the automatic-opening and
# automatic-corner Peek query can request from a unit standing on observer_tile.
# Prebaking these pairs avoids an unexpected directional-FOV calculation at the
# end of movement while retaining a much smaller cache than four directions for
# every walkable tile.
func _peek_field_requests(observer_tile: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	var environment: TacticalEnvironmentState = _state_store.state.environment_state
	if environment == null:
		return result

	for direction: Vector2i in [
		Vector2i.UP,
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
	]:
		var other: Vector2i = observer_tile + direction
		if not _map_definition.is_inside(other):
			continue
		if (
			_map_definition.opening_at_edge(observer_tile, other) != null
			and not environment.edge_blocks_sight(
				_map_definition,
				observer_tile,
				other
			)
		):
			_append_peek_field_request(result, seen, other, direction)

	for toward_wall: Vector2i in [
		Vector2i.UP,
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
	]:
		var wall_tile: Vector2i = observer_tile + toward_wall
		if (
			not _map_definition.is_inside(wall_tile)
			or not _map_definition.blocks_vision(wall_tile)
		):
			continue
		for side: Vector2i in [
			Vector2i(-toward_wall.y, toward_wall.x),
			Vector2i(toward_wall.y, -toward_wall.x),
		]:
			var side_tile: Vector2i = observer_tile + side
			if (
				not _map_definition.is_inside(side_tile)
				or _map_definition.is_blocked(side_tile)
				or environment.edge_blocks_sight(
					_map_definition,
					observer_tile,
					side_tile
				)
			):
				continue
			_append_peek_field_request(result, seen, side_tile, side)
	return result


func _append_peek_field_request(
		result: Array[Dictionary],
		seen: Dictionary,
		origin: Vector2i,
		direction: Vector2i
) -> void:
	var key: String = "%d:%d:%d:%d" % [
		origin.x,
		origin.y,
		direction.x,
		direction.y,
	]
	if seen.has(key):
		return
	seen[key] = true
	result.append({
		"origin": origin,
		"direction": direction,
	})


func _tile_index(tile: Vector2i) -> int:
	if _map_definition == null or not _map_definition.is_inside(tile):
		return -1
	return tile.y * _map_definition.grid_size.x + tile.x


func _queue_explored_tile(team_id: StringName, tile: Vector2i) -> void:
	if not _map_definition.is_inside(tile):
		return
	var team_tiles: Dictionary = _pending_explored_by_team.get(team_id, {})
	team_tiles[tile] = true
	_pending_explored_by_team[team_id] = team_tiles


func _commit_exploration_batch() -> Dictionary:
	var started_usec: int = Time.get_ticks_usec()
	_last_newly_explored_count = 0
	if _pending_explored_by_team.is_empty():
		_last_exploration_commit_usec = Time.get_ticks_usec() - started_usec
		return {}
	var batches: Dictionary = {}
	for team_value: Variant in _pending_explored_by_team.keys():
		var team_id := StringName(team_value)
		var tiles: Array[Vector2i] = []
		var team_tiles_value: Variant = _pending_explored_by_team.get(team_id, {})
		if not (team_tiles_value is Dictionary):
			continue
		var team_tiles: Dictionary = team_tiles_value
		for tile_value: Variant in team_tiles.keys():
			if tile_value is Vector2i:
				var tile := Vector2i(tile_value)
				if not _state_store.state.is_tile_explored(team_id, tile):
					tiles.append(tile)
		if not tiles.is_empty():
			tiles.sort_custom(
				func(first: Vector2i, second: Vector2i) -> bool:
					if first.y != second.y:
						return first.y < second.y
					return first.x < second.x
			)
			batches[team_id] = tiles
			_last_newly_explored_count += tiles.size()
	_pending_explored_by_team.clear()
	if batches.is_empty():
		_last_exploration_commit_usec = Time.get_ticks_usec() - started_usec
		return {}
	var snapshot: Dictionary = _state_store.state.knowledge_snapshot()
	var exploration_teams: Array[StringName] = []
	for raw_team_id: Variant in batches.keys():
		exploration_teams.append(StringName(raw_team_id))
	var changes := TacticalChangeSet.new(
		&"exploration_updated",
		_state_store.state.revision,
		TacticalInvalidationContract.exploration(exploration_teams)
	)
	changes.set_deferred_deduplication_key(&"exploration_batch")
	# Exploration changes only the compact knowledge grid. It cannot affect body
	# items, occupancy, inventories, initiative or geometry, so the global
	# transaction audit is deliberately excluded from the movement handoff.
	changes.set_commit_validation_policy(false, false)
	changes.set_allow_while_pending(true)
	changes.require(
		Callable(self, "_validate_exploration_batches").bind(batches),
		"Newly explored tactical knowledge is invalid.",
		&"exploration_batch_invalid"
	)
	changes.stage(
		Callable(self, "_apply_exploration_batches").bind(batches),
		Callable(_state_store.state, "restore_knowledge_snapshot").bind(snapshot),
		"Newly explored tactical knowledge could not be committed.",
		&"exploration_commit_failed"
	)
	var committed: OperationResult = _state_store.commit_after_notifications(
		changes,
		_map_definition
	)
	_last_exploration_commit_usec = Time.get_ticks_usec() - started_usec
	if not committed.success:
		push_warning(committed.message)
		return {}
	_lightweight_exploration_commit_count += 1
	return batches


func _validate_exploration_batches(batches: Dictionary) -> bool:
	if _state_store == null or _state_store.state == null or _map_definition == null:
		return false
	for team_value: Variant in batches.keys():
		var team_id := StringName(team_value)
		if team_id.is_empty():
			return false
		var tiles_value: Variant = batches.get(team_value, [])
		if not (tiles_value is Array):
			return false
		for tile_value: Variant in tiles_value:
			if not (tile_value is Vector2i):
				return false
			if not _map_definition.is_inside(Vector2i(tile_value)):
				return false
	return true


func _apply_exploration_batches(batches: Dictionary) -> bool:
	for team_value: Variant in batches.keys():
		var team_id := StringName(team_value)
		var tiles_value: Variant = batches.get(team_value, [])
		if not (tiles_value is Array):
			continue
		var tiles: Array[Vector2i] = []
		for tile_value: Variant in tiles_value:
			if tile_value is Vector2i:
				tiles.append(Vector2i(tile_value))
		_state_store.state.knowledge_state.mark_many_explored(team_id, tiles)
	return true


func last_delta_for_team(team_id: StringName) -> Dictionary:
	var delta_value: Variant = _last_delta_by_team.get(team_id, {})
	if not (delta_value is Dictionary):
		return {}
	var delta: Dictionary = delta_value
	return {
		"team_id": team_id,
		"visibility_revision": int(delta.get("visibility_revision", 0)),
		"knowledge_revision": int(delta.get("knowledge_revision", 0)),
		"newly_visible": (delta.get("newly_visible", []) as Array).duplicate(),
		"no_longer_visible": (delta.get("no_longer_visible", []) as Array).duplicate(),
		"newly_explored": (delta.get("newly_explored", []) as Array).duplicate(),
		"full_recalculation": bool(delta.get("full_recalculation", false)),
	}


func _visible_indices_snapshot(team_ids: Array[StringName]) -> Dictionary:
	var result: Dictionary = {}
	for team_id: StringName in team_ids:
		result[team_id] = _visibility_state.call("visible_indices", team_id)
	return result


func _publish_visibility_deltas(
		team_ids: Array[StringName],
		visible_before: Dictionary,
		newly_explored_by_team: Dictionary,
		full_recalculation: bool
) -> void:
	var started_usec: int = Time.get_ticks_usec()
	_last_visibility_delta_cell_count = 0
	for team_id: StringName in team_ids:
		var before_indices: PackedInt32Array = visible_before.get(
			team_id,
			PackedInt32Array()
		)
		var after_indices: PackedInt32Array = _visibility_state.call(
			"visible_indices",
			team_id
		)
		var before_set: Dictionary = {}
		var after_set: Dictionary = {}
		for index: int in before_indices:
			before_set[index] = true
		for index: int in after_indices:
			after_set[index] = true

		var newly_visible: Array[Vector2i] = []
		var no_longer_visible: Array[Vector2i] = []
		for index: int in after_indices:
			if not before_set.has(index):
				newly_visible.append(
					Vector2i(_visibility_state.call("tile_from_index", index))
				)
		for index: int in before_indices:
			if not after_set.has(index):
				no_longer_visible.append(
					Vector2i(_visibility_state.call("tile_from_index", index))
				)

		var newly_explored: Array = []
		var explored_value: Variant = newly_explored_by_team.get(team_id, [])
		if explored_value is Array:
			newly_explored = (explored_value as Array).duplicate()
		var delta: Dictionary = {
			"team_id": team_id,
			"visibility_revision": revision(),
			"knowledge_revision": int(_state_store.state.knowledge_state.revision),
			"newly_visible": newly_visible,
			"no_longer_visible": no_longer_visible,
			"newly_explored": newly_explored,
			"full_recalculation": full_recalculation,
		}
		_last_delta_by_team[team_id] = delta
		_last_visibility_delta_cell_count += (
			newly_visible.size()
			+ no_longer_visible.size()
			+ newly_explored.size()
		)
		visibility_delta_changed.emit(team_id, last_delta_for_team(team_id))
	_last_visibility_delta_build_usec = Time.get_ticks_usec() - started_usec



func _merge_boundary_deltas(
		aggregate: Dictionary,
		incoming_by_team: Dictionary
) -> void:
	for team_value: Variant in incoming_by_team.keys():
		var team_id := StringName(team_value)
		if team_id.is_empty():
			continue
		var entry: Dictionary = aggregate.get(team_id, {
			"newly_visible": {},
			"no_longer_visible": {},
		})
		var newly_visible: Dictionary = entry.get("newly_visible", {})
		var no_longer_visible: Dictionary = entry.get("no_longer_visible", {})
		var incoming_value: Variant = incoming_by_team.get(team_value, {})
		if not (incoming_value is Dictionary):
			continue
		var incoming: Dictionary = incoming_value
		var incoming_new: PackedInt32Array = incoming.get(
			"newly_visible_indices",
			PackedInt32Array()
		)
		var incoming_hidden: PackedInt32Array = incoming.get(
			"no_longer_visible_indices",
			PackedInt32Array()
		)
		for index: int in incoming_new:
			if no_longer_visible.erase(index):
				_direct_delta_cancelled_crossing_count += 1
			else:
				newly_visible[index] = true
		for index: int in incoming_hidden:
			if newly_visible.erase(index):
				_direct_delta_cancelled_crossing_count += 1
			else:
				no_longer_visible[index] = true
		aggregate[team_id] = {
			"newly_visible": newly_visible,
			"no_longer_visible": no_longer_visible,
		}


func _queue_exploration_from_boundary_deltas(
		boundary_deltas: Dictionary
) -> void:
	for team_value: Variant in boundary_deltas.keys():
		var team_id := StringName(team_value)
		var entry_value: Variant = boundary_deltas.get(team_value, {})
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var newly_visible_value: Variant = entry.get("newly_visible", {})
		if not (newly_visible_value is Dictionary):
			continue
		var newly_visible: Dictionary = newly_visible_value
		for index_value: Variant in newly_visible.keys():
			_queue_explored_tile(
				team_id,
				Vector2i(
					_visibility_state.call(
						"tile_from_index",
						int(index_value)
					)
				)
			)


func _publish_direct_visibility_deltas(
		team_ids: Array[StringName],
		boundary_deltas: Dictionary,
		newly_explored_by_team: Dictionary,
		full_recalculation: bool
) -> void:
	var started_usec: int = Time.get_ticks_usec()
	_last_visibility_delta_cell_count = 0
	for team_id: StringName in team_ids:
		var entry_value: Variant = boundary_deltas.get(team_id, {})
		var entry: Dictionary = (
			entry_value as Dictionary
			if entry_value is Dictionary
			else {}
		)
		var newly_visible_set: Dictionary = entry.get("newly_visible", {})
		var no_longer_visible_set: Dictionary = entry.get(
			"no_longer_visible",
			{}
		)
		var newly_visible: Array[Vector2i] = _tiles_from_index_set(
			newly_visible_set
		)
		var no_longer_visible: Array[Vector2i] = _tiles_from_index_set(
			no_longer_visible_set
		)
		var newly_explored: Array = []
		var explored_value: Variant = newly_explored_by_team.get(team_id, [])
		if explored_value is Array:
			newly_explored = (explored_value as Array).duplicate()
		var delta: Dictionary = {
			"team_id": team_id,
			"visibility_revision": revision(),
			"knowledge_revision": int(_state_store.state.knowledge_state.revision),
			"newly_visible": newly_visible,
			"no_longer_visible": no_longer_visible,
			"newly_explored": newly_explored,
			"full_recalculation": full_recalculation,
		}
		_last_delta_by_team[team_id] = delta
		_last_visibility_delta_cell_count += (
			newly_visible.size()
			+ no_longer_visible.size()
			+ newly_explored.size()
		)
		visibility_delta_changed.emit(team_id, last_delta_for_team(team_id))
	_last_visibility_delta_build_usec = Time.get_ticks_usec() - started_usec


func _tiles_from_index_set(index_set: Dictionary) -> Array[Vector2i]:
	var indices: Array[int] = []
	for index_value: Variant in index_set.keys():
		indices.append(int(index_value))
	indices.sort()
	var result: Array[Vector2i] = []
	for index: int in indices:
		result.append(Vector2i(_visibility_state.call("tile_from_index", index)))
	return result

func _can_recalculate() -> bool:
	return (
		_state_store != null
		and _state_store.state != null
		and _map_definition != null
		and _visibility_state != null
	)


# Compatibility wrapper retained for older callers. Peek is now an automatic,
# free observation origin and refreshes only that observer's contribution.
# so requesting it refreshes only that observer's contribution.
func reveal_from_peek(unit: TacticalUnitState, _origin_tile: Vector2i) -> void:
	if unit == null:
		return
	recalculate_units([unit.unit_id], true)
