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

const TILE_UNSEEN: int = 0
const TILE_EXPLORED: int = 1
const TILE_VISIBLE: int = 2

const VISIBILITY_AFFECTING_REASONS: Dictionary = {
	&"runtime_spawn": true,
	&"unit_moved": true,
	&"unit_sprinted": true,
	&"enemy_unit_moved": true,
	&"attack_resolved": true,
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


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_visibility_state = VISIBILITY_STATE_SCRIPT.new() as RefCounted
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
	_pending_explored_by_team.clear()
	_visibility_state.call("begin_recalculation", teams)
	for unit: TacticalUnitState in _state_store.state.get_units():
		if unit == null or unit.is_defeated() or unit.team_id.is_empty():
			continue
		_replace_visibility_from_unit(unit)
	_commit_exploration_batch()
	_visibility_state.call("complete_recalculation")
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
	for unit_id: StringName in unit_ids:
		if unit_id.is_empty() or unique_ids.has(unit_id):
			continue
		unique_ids.append(unit_id)
	unique_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	_pending_explored_by_team.clear()
	for unit_id: StringName in unique_ids:
		var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
		if unit == null or unit.is_defeated() or unit.team_id.is_empty():
			_visibility_state.call("remove_unit_visibility", unit_id)
			continue
		_replace_visibility_from_unit(unit)
	_commit_exploration_batch()
	_visibility_state.call("complete_recalculation")
	_recalculation_count += 1
	_incremental_recalculation_count += 1
	_last_incremental_unit_count = unique_ids.size()
	_last_incremental_recalculation_usec = Time.get_ticks_usec() - started_usec
	_last_recalculation_usec = _last_incremental_recalculation_usec
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
	if not (
		flags.visibility_changed
		or flags.geometry_changed
		or flags.occupancy_changed
	):
		_skipped_change_count += 1
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


func _replace_visibility_from_unit(unit: TacticalUnitState) -> void:
	var visible_tiles: Dictionary = _visible_tiles_for_unit(unit)
	var typed_tiles: Array[Vector2i] = []
	for tile_value: Variant in visible_tiles.keys():
		if tile_value is Vector2i:
			var tile := Vector2i(tile_value)
			typed_tiles.append(tile)
			_queue_explored_tile(unit.team_id, tile)
	_visibility_state.call(
		"replace_unit_visibility",
		unit.unit_id,
		unit.team_id,
		typed_tiles
	)


func _visible_tiles_for_unit(unit: TacticalUnitState) -> Dictionary:
	var result: Dictionary = {}
	if unit == null or unit.is_defeated():
		return result
	var occupied_cells: Array[Vector2i] = (
		_state_store.state.occupied_cells_for_unit(unit)
	)
	for occupied_origin: Vector2i in occupied_cells:
		var centre_visible: Dictionary = _visible_tiles_from_origin(
			occupied_origin,
			Vector2i.ZERO,
			{},
			false
		)
		for tile_value: Variant in centre_visible.keys():
			result[Vector2i(tile_value)] = true

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
				var additional: Dictionary = _visible_tiles_from_origin(
					observation_origin.origin_tile,
					observation_origin.direction,
					result,
					true
				)
				for tile_value: Variant in additional.keys():
					result[Vector2i(tile_value)] = true

	# Locked Seethe rule: a unit always sees its own and adjacent tiles.
	for cell: Vector2i in occupied_cells:
		for adjacent_y: int in range(-1, 2):
			for adjacent_x: int in range(-1, 2):
				var adjacent := cell + Vector2i(adjacent_x, adjacent_y)
				if _map_definition.is_inside(adjacent):
					result[adjacent] = true
	return result


# Compatibility helper retained for older callers. Peek is automatic and this
# now refreshes the supplied observer's contribution rather than all teams.
func _reveal_from_origin(
		unit: TacticalUnitState,
		_origin: TacticalObservationOrigin
) -> void:
	if unit == null:
		return
	recalculate_units([unit.unit_id], true)


func _visible_tiles_from_origin(
		origin: Vector2i,
		peek_direction: Vector2i,
		skip_tiles: Dictionary,
		additional_peek_only: bool
) -> Dictionary:
	var result: Dictionary = {}
	var radius_tiles: int = TacticalGridDistance.GENERAL_SIGHT_RADIUS_TILES
	var direction_vector: Vector2 = Vector2(peek_direction).normalized()
	for offset_y: int in range(-radius_tiles, radius_tiles + 1):
		for offset_x: int in range(-radius_tiles, radius_tiles + 1):
			var target: Vector2i = origin + Vector2i(offset_x, offset_y)
			if not _map_definition.is_inside(target):
				continue
			if skip_tiles.has(target):
				continue
			if not TacticalGridDistance.is_within_steps(
				origin,
				target,
				radius_tiles
			):
				continue
			if additional_peek_only and target != origin:
				var target_direction: Vector2 = Vector2(target - origin).normalized()
				if direction_vector.dot(target_direction) < 0.15:
					continue
			if additional_peek_only:
				_peek_additional_los_trace_count += 1
			else:
				_centre_los_trace_count += 1
			if TacticalLineOfSightRules.has_line_of_sight(
				origin,
				target,
				_map_definition,
				_state_store.state
			):
				result[target] = true
	return result


func _queue_explored_tile(team_id: StringName, tile: Vector2i) -> void:
	if not _map_definition.is_inside(tile):
		return
	var team_tiles: Dictionary = _pending_explored_by_team.get(team_id, {})
	team_tiles[tile] = true
	_pending_explored_by_team[team_id] = team_tiles


func _commit_exploration_batch() -> void:
	if _pending_explored_by_team.is_empty():
		return
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
			batches[team_id] = tiles
	_pending_explored_by_team.clear()
	if batches.is_empty():
		return
	var snapshot: Dictionary = _state_store.state.knowledge_snapshot()
	var changes := TacticalChangeSet.new(
		&"exploration_updated",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_apply_exploration_batches").bind(batches),
		Callable(_state_store.state, "restore_knowledge_snapshot").bind(snapshot),
		"Newly explored tactical knowledge could not be committed.",
		&"exploration_commit_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		push_warning(committed.message)


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
