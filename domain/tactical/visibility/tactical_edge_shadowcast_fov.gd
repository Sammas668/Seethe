class_name TacticalEdgeShadowcastFov
extends RefCounted

const VISIBILITY_FIELD_SCRIPT: Script = preload(
	"res://domain/tactical/visibility/tactical_visibility_field.gd"
)

const OCTANT_TRANSFORMS: Array[Vector4i] = [
	Vector4i(1, 0, 0, 1),
	Vector4i(0, 1, 1, 0),
	Vector4i(0, -1, 1, 0),
	Vector4i(-1, 0, 0, 1),
	Vector4i(-1, 0, 0, -1),
	Vector4i(0, -1, -1, 0),
	Vector4i(0, 1, -1, 0),
	Vector4i(1, 0, 0, -1),
]

const CHUNK_SIZE_TILES: int = 8
const EPSILON: float = 0.000001

var _map_definition: TacticalMapDefinition
var _state_store: TacticalStateStore
var _ray_cache: TacticalVisibilityRayCache
var _radius_tiles: int = 0
var _relative_offsets: Array[Vector3i] = []
var _blocking_edges: Array[Dictionary] = []
var _chunk_grid_size: Vector2i = Vector2i.ZERO
var _chunk_hashes: PackedInt32Array = PackedInt32Array()
var _chunk_revisions: PackedInt32Array = PackedInt32Array()
var _last_geometry_revision: int = -1
var _calculation_count: int = 0
var _last_calculation_usec: int = 0
var _last_shadowcast_visited_count: int = 0
var _last_conservative_candidate_count: int = 0
var _last_uncertain_tile_count: int = 0
var _last_exact_refinement_count: int = 0
var _total_exact_refinement_count: int = 0
var _geometry_sync_count: int = 0
var _geometry_sync_usec: int = 0
var _changed_chunk_count: int = 0


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		radius_tiles_value: int,
		ray_cache: TacticalVisibilityRayCache = null
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_ray_cache = ray_cache
	_radius_tiles = maxi(0, radius_tiles_value)
	_build_relative_offsets()
	_chunk_grid_size = Vector2i(
		int(ceil(float(_map_definition.grid_size.x) / float(CHUNK_SIZE_TILES)))
		if _map_definition != null
		else 0,
		int(ceil(float(_map_definition.grid_size.y) / float(CHUNK_SIZE_TILES)))
		if _map_definition != null
		else 0
	)
	var chunk_count: int = maxi(0, _chunk_grid_size.x * _chunk_grid_size.y)
	_chunk_hashes.resize(chunk_count)
	_chunk_hashes.fill(0)
	_chunk_revisions.resize(chunk_count)
	_chunk_revisions.fill(0)
	_last_geometry_revision = -1
	synchronise_geometry()


func calculate(
		origin: Vector2i,
		direction: Vector2i = Vector2i.ZERO
) -> TacticalVisibilityField:
	var started_usec: int = Time.get_ticks_usec()
	synchronise_geometry()
	var shadow_field: TacticalVisibilityField = _shadowcast_superset(
		origin,
		direction
	)
	var conservative_field: TacticalVisibilityField = (
		_conservative_angular_field(origin, direction)
	)
	var result: TacticalVisibilityField = conservative_field.duplicate_field()
	_last_uncertain_tile_count = 0
	_last_exact_refinement_count = 0
	for index: int in shadow_field.visible_indices():
		if conservative_field.has_index(index):
			continue
		_last_uncertain_tile_count += 1
		var tile := Vector2i(
			index % _map_definition.grid_size.x,
			floori(float(index) / float(_map_definition.grid_size.x))
		)
		var ray: Dictionary = (
			_ray_cache.ray_for_offset(tile - origin)
			if _ray_cache != null
			else {}
		)
		_last_exact_refinement_count += 1
		if not ray.is_empty() and _exact_ray_has_line_of_sight(origin, ray):
			result.set_index(index)

	for adjacent_y: int in range(-1, 2):
		for adjacent_x: int in range(-1, 2):
			var adjacent := origin + Vector2i(adjacent_x, adjacent_y)
			if _map_definition != null and _map_definition.is_inside(adjacent):
				result.set_tile(adjacent)

	_calculation_count += 1
	_total_exact_refinement_count += _last_exact_refinement_count
	_last_calculation_usec = Time.get_ticks_usec() - started_usec
	return result


func geometry_stamp_for_origin(origin: Vector2i) -> int:
	synchronise_geometry()
	if _chunk_grid_size.x <= 0 or _chunk_grid_size.y <= 0:
		return 0
	var minimum_tile := origin - Vector2i(_radius_tiles, _radius_tiles)
	var maximum_tile := origin + Vector2i(_radius_tiles, _radius_tiles)
	var minimum_chunk := Vector2i(
		clampi(
			int(floor(float(minimum_tile.x) / CHUNK_SIZE_TILES)),
			0,
			_chunk_grid_size.x - 1
		),
		clampi(
			int(floor(float(minimum_tile.y) / CHUNK_SIZE_TILES)),
			0,
			_chunk_grid_size.y - 1
		)
	)
	var maximum_chunk := Vector2i(
		clampi(
			int(floor(float(maximum_tile.x) / CHUNK_SIZE_TILES)),
			0,
			_chunk_grid_size.x - 1
		),
		clampi(
			int(floor(float(maximum_tile.y) / CHUNK_SIZE_TILES)),
			0,
			_chunk_grid_size.y - 1
		)
	)
	var stamp: int = 486187739
	for chunk_y: int in range(minimum_chunk.y, maximum_chunk.y + 1):
		for chunk_x: int in range(minimum_chunk.x, maximum_chunk.x + 1):
			var chunk_index: int = chunk_y * _chunk_grid_size.x + chunk_x
			stamp = int(
				((stamp ^ int(_chunk_revisions[chunk_index])) * 16777619)
				% 2147483647
			)
	return stamp


func synchronise_geometry() -> void:
	if (
		_state_store == null
		or _state_store.state == null
		or _map_definition == null
	):
		return
	var geometry_revision: int = _state_store.state.geometry_revision()
	if geometry_revision == _last_geometry_revision:
		return
	var started_usec: int = Time.get_ticks_usec()
	var next_hashes := PackedInt32Array()
	next_hashes.resize(_chunk_hashes.size())
	next_hashes.fill(486187739)
	_blocking_edges.clear()
	var environment: TacticalEnvironmentState = _state_store.state.environment_state
	for y: int in range(_map_definition.grid_size.y):
		for x: int in range(_map_definition.grid_size.x):
			var tile := Vector2i(x, y)
			var chunk_index: int = _chunk_index_for_tile(tile)
			var value: int = 1 if _map_definition.blocks_vision(tile) else 0
			if x + 1 < _map_definition.grid_size.x and environment != null:
				var right := tile + Vector2i.RIGHT
				if environment.edge_blocks_sight(_map_definition, tile, right):
					value |= 1 << 1
					_blocking_edges.append({
						"first_point": Vector2(float(x + 1), float(y)),
						"second_point": Vector2(float(x + 1), float(y + 1)),
					})
			if y + 1 < _map_definition.grid_size.y and environment != null:
				var below := tile + Vector2i.DOWN
				if environment.edge_blocks_sight(_map_definition, tile, below):
					value |= 1 << 2
					_blocking_edges.append({
						"first_point": Vector2(float(x), float(y + 1)),
						"second_point": Vector2(float(x + 1), float(y + 1)),
					})
			next_hashes[chunk_index] = int(
				(
					(int(next_hashes[chunk_index]) ^ (value + x * 17 + y * 31))
					* 16777619
				)
				% 2147483647
			)

	_changed_chunk_count = 0
	for index: int in range(next_hashes.size()):
		if int(next_hashes[index]) == int(_chunk_hashes[index]):
			continue
		_chunk_hashes[index] = next_hashes[index]
		_chunk_revisions[index] = int(_chunk_revisions[index]) + 1
		_changed_chunk_count += 1
	_last_geometry_revision = geometry_revision
	_geometry_sync_count += 1
	_geometry_sync_usec = Time.get_ticks_usec() - started_usec


func performance_snapshot() -> Dictionary:
	return {
		"algorithm": "hybrid_shadowcast_exact_refinement",
		"radius_tiles": _radius_tiles,
		"calculation_count": _calculation_count,
		"last_calculation_usec": _last_calculation_usec,
		"last_shadowcast_visited_count": _last_shadowcast_visited_count,
		"last_conservative_candidate_count": _last_conservative_candidate_count,
		"last_uncertain_tile_count": _last_uncertain_tile_count,
		"last_exact_refinement_count": _last_exact_refinement_count,
		"total_exact_refinement_count": _total_exact_refinement_count,
		"relative_offset_count": _relative_offsets.size(),
		"blocking_edge_count": _blocking_edges.size(),
		"geometry_sync_count": _geometry_sync_count,
		"geometry_sync_usec": _geometry_sync_usec,
		"chunk_size_tiles": CHUNK_SIZE_TILES,
		"chunk_count": _chunk_revisions.size(),
		"changed_chunk_count": _changed_chunk_count,
		"geometry_revision": _last_geometry_revision,
	}


func _shadowcast_superset(
		origin: Vector2i,
		direction: Vector2i
) -> TacticalVisibilityField:
	var result: TacticalVisibilityField = (
		VISIBILITY_FIELD_SCRIPT.new() as TacticalVisibilityField
	)
	result.configure(
		_map_definition.grid_size if _map_definition != null else Vector2i.ZERO
	)
	_last_shadowcast_visited_count = 0
	if _map_definition == null or not _map_definition.is_inside(origin):
		return result
	result.set_tile(origin)
	for octant: Vector4i in OCTANT_TRANSFORMS:
		_cast_light(
			origin,
			1,
			1.0,
			0.0,
			octant.x,
			octant.y,
			octant.z,
			octant.w,
			direction,
			result
		)
	return result


func _cast_light(
		origin: Vector2i,
		row: int,
		start_slope: float,
		end_slope: float,
		xx: int,
		xy: int,
		yx: int,
		yy: int,
		direction: Vector2i,
		field: TacticalVisibilityField
) -> void:
	if start_slope < end_slope or row > _radius_tiles:
		return
	var next_start_slope: float = start_slope
	var blocked: bool = false
	var distance: int = row
	while distance <= _radius_tiles:
		var delta_x: int = -distance
		var delta_y: int = -distance
		while delta_x <= 0:
			var tile := Vector2i(
				origin.x + delta_x * xx + delta_y * xy,
				origin.y + delta_x * yx + delta_y * yy
			)
			var left_slope: float = (
				(float(delta_x) - 0.5) / (float(delta_y) + 0.5)
			)
			var right_slope: float = (
				(float(delta_x) + 0.5) / (float(delta_y) - 0.5)
			)
			delta_x += 1
			if start_slope < right_slope:
				continue
			if end_slope > left_slope:
				break
			if not _map_definition.is_inside(tile):
				continue
			var offset: Vector2i = tile - origin
			if absi(offset.x) + absi(offset.y) > _radius_tiles:
				continue
			_last_shadowcast_visited_count += 1
			var opaque: bool = _map_definition.blocks_vision(tile)
			if _direction_allows(direction, offset):
				field.set_tile(tile)
			if blocked:
				if opaque:
					next_start_slope = right_slope
					continue
				blocked = false
				start_slope = next_start_slope
			elif opaque and distance < _radius_tiles:
				blocked = true
				_cast_light(
					origin,
					distance + 1,
					start_slope,
					left_slope,
					xx,
					xy,
					yx,
					yy,
					direction,
					field
				)
				next_start_slope = right_slope
		if blocked:
			break
		distance += 1


func _conservative_angular_field(
		origin: Vector2i,
		direction: Vector2i
) -> TacticalVisibilityField:
	var result: TacticalVisibilityField = (
		VISIBILITY_FIELD_SCRIPT.new() as TacticalVisibilityField
	)
	result.configure(
		_map_definition.grid_size if _map_definition != null else Vector2i.ZERO
	)
	_last_conservative_candidate_count = 0
	if _map_definition == null or not _map_definition.is_inside(origin):
		return result
	result.set_tile(origin)
	var blocked_intervals: Array[Vector2] = []
	var edge_events: Array[Dictionary] = _edge_events_for_origin(origin)
	var edge_index: int = 0
	for packed_offset: Vector3i in _relative_offsets:
		var offset := Vector2i(packed_offset.x, packed_offset.y)
		if offset == Vector2i.ZERO:
			continue
		var tile: Vector2i = origin + offset
		if not _map_definition.is_inside(tile):
			continue
		_last_conservative_candidate_count += 1
		var tile_distance_squared: float = float(packed_offset.z)
		while (
			edge_index < edge_events.size()
			and float(edge_events[edge_index].get("distance_squared", INF))
			<= tile_distance_squared + EPSILON
		):
			_add_edge_occluder(
				blocked_intervals,
				origin,
				edge_events[edge_index]
			)
			edge_index += 1
		var angle: float = _normalised_angle(Vector2(offset))
		if (
			not _angle_is_blocked(blocked_intervals, angle)
			and _direction_allows(direction, offset)
		):
			result.set_tile(tile)
		if _map_definition.blocks_vision(tile):
			_add_tile_occluder(blocked_intervals, offset)
	return result


func _edge_events_for_origin(origin: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var origin_world := Vector2(origin) + Vector2(0.5, 0.5)
	for edge: Dictionary in _blocking_edges:
		var first_point := Vector2(edge.get("first_point", Vector2.ZERO))
		var second_point := Vector2(edge.get("second_point", Vector2.ZERO))
		var midpoint: Vector2 = (first_point + second_point) * 0.5
		if (
			absf(midpoint.x - origin_world.x)
			+ absf(midpoint.y - origin_world.y)
			> float(_radius_tiles) + 1.0
		):
			continue
		result.append({
			"distance_squared": origin_world.distance_squared_to(midpoint) - EPSILON,
			"first_point": first_point,
			"second_point": second_point,
		})
	result.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return float(first.get("distance_squared", 0.0)) < float(
				second.get("distance_squared", 0.0)
			)
	)
	return result


func _add_tile_occluder(
		intervals: Array[Vector2],
		offset: Vector2i
) -> void:
	var angles: Array[float] = [
		_normalised_angle(Vector2(float(offset.x) - 0.5, float(offset.y) - 0.5)),
		_normalised_angle(Vector2(float(offset.x) + 0.5, float(offset.y) - 0.5)),
		_normalised_angle(Vector2(float(offset.x) + 0.5, float(offset.y) + 0.5)),
		_normalised_angle(Vector2(float(offset.x) - 0.5, float(offset.y) + 0.5)),
	]
	_add_occluder_angles(intervals, angles)


func _add_edge_occluder(
		intervals: Array[Vector2],
		origin: Vector2i,
		edge: Dictionary
) -> void:
	var origin_world := Vector2(origin) + Vector2(0.5, 0.5)
	var first_point := Vector2(edge.get("first_point", Vector2.ZERO))
	var second_point := Vector2(edge.get("second_point", Vector2.ZERO))
	_add_occluder_angles(intervals, [
		_normalised_angle(first_point - origin_world),
		_normalised_angle(second_point - origin_world),
	])


func _add_occluder_angles(
		intervals: Array[Vector2],
		angles: Array[float]
) -> void:
	if angles.size() < 2:
		return
	angles.sort()
	var largest_gap: float = -1.0
	var largest_gap_index: int = 0
	for index: int in range(angles.size()):
		var current: float = angles[index]
		var following: float = (
			angles[(index + 1) % angles.size()]
			+ (TAU if index == angles.size() - 1 else 0.0)
		)
		var gap: float = following - current
		if gap > largest_gap:
			largest_gap = gap
			largest_gap_index = index
	var start_angle: float = angles[(largest_gap_index + 1) % angles.size()]
	var end_angle: float = angles[largest_gap_index]
	if start_angle <= end_angle:
		_add_interval_part(intervals, start_angle, end_angle)
	else:
		_add_interval_part(intervals, 0.0, end_angle)
		_add_interval_part(intervals, start_angle, TAU)


func _add_interval_part(
		intervals: Array[Vector2],
		start_angle: float,
		end_angle: float
) -> void:
	var merged: Array[Vector2] = []
	var inserted: bool = false
	var next_start: float = start_angle
	var next_end: float = end_angle
	for interval: Vector2 in intervals:
		if interval.y < next_start - EPSILON:
			merged.append(interval)
		elif next_end < interval.x - EPSILON:
			if not inserted:
				merged.append(Vector2(next_start, next_end))
				inserted = true
			merged.append(interval)
		else:
			next_start = minf(next_start, interval.x)
			next_end = maxf(next_end, interval.y)
	if not inserted:
		merged.append(Vector2(next_start, next_end))
	intervals.clear()
	intervals.append_array(merged)


func _angle_is_blocked(
		intervals: Array[Vector2],
		angle: float
) -> bool:
	for interval: Vector2 in intervals:
		if angle >= interval.x - EPSILON and angle <= interval.y + EPSILON:
			return true
		if angle < interval.x:
			return false
	return false


func _exact_ray_has_line_of_sight(
		origin: Vector2i,
		ray: Dictionary
) -> bool:
	var intermediate_value: Variant = ray.get("intermediate_tiles", [])
	if intermediate_value is Array:
		for offset_value: Variant in intermediate_value:
			if (
				offset_value is Vector2i
				and _map_definition.blocks_vision(origin + Vector2i(offset_value))
			):
				return false

	var environment: TacticalEnvironmentState = _state_store.state.environment_state
	var corner_value: Variant = ray.get("corner_pairs", [])
	if corner_value is Array:
		for pair_value: Variant in corner_value:
			if not (pair_value is Dictionary):
				continue
			var pair: Dictionary = pair_value
			var from_tile: Vector2i = origin + Vector2i(
				pair.get("from", Vector2i.ZERO)
			)
			var first_side: Vector2i = origin + Vector2i(
				pair.get("first", Vector2i.ZERO)
			)
			var second_side: Vector2i = origin + Vector2i(
				pair.get("second", Vector2i.ZERO)
			)
			var first_solid: bool = _map_definition.blocks_vision(first_side)
			var second_solid: bool = _map_definition.blocks_vision(second_side)
			if environment != null:
				first_solid = first_solid or environment.edge_blocks_sight(
					_map_definition,
					from_tile,
					first_side
				)
				second_solid = second_solid or environment.edge_blocks_sight(
					_map_definition,
					from_tile,
					second_side
				)
			if first_solid and second_solid:
				return false

	if environment != null:
		var crossings_value: Variant = ray.get("crossings", [])
		if crossings_value is Array:
			for crossing_value: Variant in crossings_value:
				if not (crossing_value is Dictionary):
					continue
				var crossing: Dictionary = crossing_value
				var from_tile: Vector2i = origin + Vector2i(
					crossing.get("from", Vector2i.ZERO)
				)
				var to_tile: Vector2i = origin + Vector2i(
					crossing.get("to", Vector2i.ZERO)
				)
				if environment.edge_blocks_sight(
					_map_definition,
					from_tile,
					to_tile
				):
					return false
	return true


func _direction_allows(direction: Vector2i, offset: Vector2i) -> bool:
	if direction == Vector2i.ZERO or offset == Vector2i.ZERO:
		return true
	var direction_vector: Vector2 = Vector2(direction).normalized()
	var offset_vector: Vector2 = Vector2(offset).normalized()
	return direction_vector.dot(offset_vector) >= 0.15 - EPSILON


func _normalised_angle(vector: Vector2) -> float:
	var angle: float = atan2(vector.y, vector.x)
	return angle + TAU if angle < 0.0 else angle


func _build_relative_offsets() -> void:
	_relative_offsets.clear()
	for offset_y: int in range(-_radius_tiles, _radius_tiles + 1):
		for offset_x: int in range(-_radius_tiles, _radius_tiles + 1):
			if absi(offset_x) + absi(offset_y) > _radius_tiles:
				continue
			_relative_offsets.append(Vector3i(
				offset_x,
				offset_y,
				offset_x * offset_x + offset_y * offset_y
			))
	_relative_offsets.sort_custom(
		func(first: Vector3i, second: Vector3i) -> bool:
			if first.z != second.z:
				return first.z < second.z
			if first.y != second.y:
				return first.y < second.y
			return first.x < second.x
	)


func _chunk_index_for_tile(tile: Vector2i) -> int:
	var chunk_x: int = clampi(
		int(floor(float(tile.x) / CHUNK_SIZE_TILES)),
		0,
		maxi(0, _chunk_grid_size.x - 1)
	)
	var chunk_y: int = clampi(
		int(floor(float(tile.y) / CHUNK_SIZE_TILES)),
		0,
		maxi(0, _chunk_grid_size.y - 1)
	)
	return chunk_y * _chunk_grid_size.x + chunk_x
