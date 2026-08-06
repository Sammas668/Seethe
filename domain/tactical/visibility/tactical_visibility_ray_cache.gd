class_name TacticalVisibilityRayCache
extends RefCounted

const EPSILON: float = 0.00001

var radius_tiles: int = 0
var _all_rays: Array[Dictionary] = []
var _ray_by_offset: Dictionary = {}
var _directional_rays: Dictionary = {}
var _bake_usec: int = 0
var _ray_count: int = 0
var _relative_tile_step_count: int = 0
var _crossing_count: int = 0
var _corner_pair_count: int = 0


func configure(radius_tiles_value: int) -> void:
	var started_usec: int = Time.get_ticks_usec()
	radius_tiles = maxi(0, radius_tiles_value)
	_all_rays.clear()
	_ray_by_offset.clear()
	_directional_rays.clear()
	_relative_tile_step_count = 0
	_crossing_count = 0
	_corner_pair_count = 0

	for offset_y: int in range(-radius_tiles, radius_tiles + 1):
		for offset_x: int in range(-radius_tiles, radius_tiles + 1):
			var offset := Vector2i(offset_x, offset_y)
			if absi(offset.x) + absi(offset.y) > radius_tiles:
				continue
			var ray: Dictionary = _build_relative_ray(offset)
			_all_rays.append(ray)
			_ray_by_offset[offset] = ray
			_relative_tile_step_count += (
				(ray.get("intermediate_tiles", []) as Array).size()
			)
			_crossing_count += (ray.get("crossings", []) as Array).size()
			_corner_pair_count += (ray.get("corner_pairs", []) as Array).size()

	_all_rays.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			var first_offset := Vector2i(first.get("target_offset", Vector2i.ZERO))
			var second_offset := Vector2i(second.get("target_offset", Vector2i.ZERO))
			var first_steps: int = absi(first_offset.x) + absi(first_offset.y)
			var second_steps: int = absi(second_offset.x) + absi(second_offset.y)
			if first_steps != second_steps:
				return first_steps < second_steps
			if first_offset.y != second_offset.y:
				return first_offset.y < second_offset.y
			return first_offset.x < second_offset.x
	)
	_ray_count = _all_rays.size()
	_bake_usec = Time.get_ticks_usec() - started_usec


func all_rays() -> Array[Dictionary]:
	return _all_rays


func ray_for_offset(offset: Vector2i) -> Dictionary:
	var ray_value: Variant = _ray_by_offset.get(offset, {})
	return ray_value as Dictionary if ray_value is Dictionary else {}


func rays_for_direction(direction: Vector2i) -> Array[Dictionary]:
	if direction == Vector2i.ZERO:
		return _all_rays
	var normalised_direction: Vector2 = Vector2(direction).normalized()
	var direction_key: String = "%d,%d" % [direction.x, direction.y]
	if _directional_rays.has(direction_key):
		var cached_result: Array[Dictionary] = []
		var cached_value: Variant = _directional_rays.get(direction_key, [])
		if cached_value is Array:
			for ray_value: Variant in cached_value:
				if ray_value is Dictionary:
					cached_result.append(ray_value as Dictionary)
		return cached_result

	var result: Array[Dictionary] = []
	for ray: Dictionary in _all_rays:
		var offset := Vector2i(ray.get("target_offset", Vector2i.ZERO))
		if offset == Vector2i.ZERO:
			result.append(ray)
			continue
		var target_direction: Vector2 = Vector2(offset).normalized()
		if normalised_direction.dot(target_direction) >= 0.15:
			result.append(ray)
	_directional_rays[direction_key] = result
	return result


func performance_snapshot() -> Dictionary:
	return {
		"radius_tiles": radius_tiles,
		"ray_count": _ray_count,
		"relative_tile_step_count": _relative_tile_step_count,
		"crossing_count": _crossing_count,
		"corner_pair_count": _corner_pair_count,
		"directional_bucket_count": _directional_rays.size(),
		"offset_lookup_count": _ray_by_offset.size(),
		"bake_usec": _bake_usec,
	}


func _build_relative_ray(target_offset: Vector2i) -> Dictionary:
	var tiles: Array[Vector2i] = []
	var crossings: Array[Dictionary] = []
	var corner_pairs: Array[Dictionary] = []
	var start := Vector2(0.5, 0.5)
	var finish := Vector2(target_offset) + Vector2(0.5, 0.5)
	var current := Vector2i.ZERO
	var target := target_offset
	tiles.append(current)
	if current == target:
		return {
			"target_offset": target_offset,
			"intermediate_tiles": [],
			"crossings": crossings,
			"corner_pairs": corner_pairs,
		}

	var delta: Vector2 = finish - start
	var step_x: int = 1 if delta.x > 0.0 else -1
	var step_y: int = 1 if delta.y > 0.0 else -1
	var t_delta_x: float = absf(1.0 / delta.x) if absf(delta.x) > EPSILON else INF
	var t_delta_y: float = absf(1.0 / delta.y) if absf(delta.y) > EPSILON else INF
	var next_boundary_x: float = float(current.x + 1) if step_x > 0 else float(current.x)
	var next_boundary_y: float = float(current.y + 1) if step_y > 0 else float(current.y)
	var t_max_x: float = (
		(next_boundary_x - start.x) / delta.x
		if absf(delta.x) > EPSILON
		else INF
	)
	var t_max_y: float = (
		(next_boundary_y - start.y) / delta.y
		if absf(delta.y) > EPSILON
		else INF
	)
	var guard: int = 0
	while current != target and guard < 4096:
		guard += 1
		if absf(t_max_x - t_max_y) <= EPSILON:
			var horizontal := current + Vector2i(step_x, 0)
			var vertical := current + Vector2i(0, step_y)
			corner_pairs.append({
				"from": current,
				"first": horizontal,
				"second": vertical,
			})
			current += Vector2i(step_x, step_y)
			t_max_x += t_delta_x
			t_max_y += t_delta_y
		elif t_max_x < t_max_y:
			var next_x := current + Vector2i(step_x, 0)
			crossings.append({"from": current, "to": next_x})
			current = next_x
			t_max_x += t_delta_x
		else:
			var next_y := current + Vector2i(0, step_y)
			crossings.append({"from": current, "to": next_y})
			current = next_y
			t_max_y += t_delta_y
		if not tiles.has(current):
			tiles.append(current)

	var intermediate_tiles: Array[Vector2i] = []
	for index: int in range(1, maxi(1, tiles.size() - 1)):
		intermediate_tiles.append(tiles[index])
	return {
		"target_offset": target_offset,
		"intermediate_tiles": intermediate_tiles,
		"crossings": crossings,
		"corner_pairs": corner_pairs,
	}
