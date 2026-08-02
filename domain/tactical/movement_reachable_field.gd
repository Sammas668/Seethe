class_name MovementReachableField
extends RefCounted

var origin: Vector2i = Vector2i.ZERO
var starting_parity: int = 0
var maximum_cost_feet: int = 0
var cost_by_key: Dictionary = {}
var predecessor_by_key: Dictionary = {}
var best_key_by_tile: Dictionary = {}
var pathfinding_expansions: int = 0
var _reachable_tiles_cache: Array[Vector2i] = []


func configure(
		origin_value: Vector2i,
		starting_parity_value: int,
		maximum_cost_feet_value: int,
		cost_by_key_value: Dictionary,
		predecessor_by_key_value: Dictionary,
		best_key_by_tile_value: Dictionary,
		pathfinding_expansions_value: int
) -> void:
	origin = origin_value
	starting_parity = starting_parity_value % 2
	maximum_cost_feet = maxi(0, maximum_cost_feet_value)
	cost_by_key = cost_by_key_value.duplicate(true)
	predecessor_by_key = predecessor_by_key_value.duplicate(true)
	best_key_by_tile = best_key_by_tile_value.duplicate(true)
	pathfinding_expansions = maxi(0, pathfinding_expansions_value)
	_reachable_tiles_cache.clear()
	for tile_value: Variant in best_key_by_tile.keys():
		if tile_value is Vector2i:
			_reachable_tiles_cache.append(Vector2i(tile_value))
	_reachable_tiles_cache.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x)
	)


func has_tile(tile: Vector2i) -> bool:
	return best_key_by_tile.has(tile)


func reachable_tile_count() -> int:
	return best_key_by_tile.size()


func cost_to(tile: Vector2i) -> int:
	if not best_key_by_tile.has(tile):
		return -1
	var key: Vector3i = best_key_by_tile[tile]
	return int(cost_by_key.get(key, -1))


func path_to(tile: Vector2i) -> MovementPathResult:
	if not best_key_by_tile.has(tile):
		return MovementPathResult.failed("The tile is outside the reachable movement field.")
	var goal_key: Vector3i = best_key_by_tile[tile]
	var start_key := Vector3i(origin.x, origin.y, starting_parity)
	var reversed_path: Array[Vector2i] = []
	var current_key: Vector3i = goal_key
	while current_key != start_key:
		reversed_path.append(Vector2i(current_key.x, current_key.y))
		if not predecessor_by_key.has(current_key):
			return MovementPathResult.failed(
				"The reachable movement field could not reconstruct its route."
			)
		current_key = predecessor_by_key[current_key]
	reversed_path.append(origin)
	reversed_path.reverse()

	var diagonal_steps: int = 0
	for index: int in range(1, reversed_path.size()):
		var delta: Vector2i = reversed_path[index] - reversed_path[index - 1]
		if delta.x != 0 and delta.y != 0:
			diagonal_steps += 1
	return MovementPathResult.completed(
		reversed_path,
		int(cost_by_key.get(goal_key, 0)),
		diagonal_steps
	)


func reachable_tiles() -> Array[Vector2i]:
	return _reachable_tiles_cache.duplicate()
