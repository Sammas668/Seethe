class_name TacticalGridDistance
extends RefCounted

const TILE_SIZE_FEET: int = 5
const GENERAL_SIGHT_RADIUS_TILES: int = 40
const UNAWARE_FOCUSED_RANGE_TILES: int = 25
const CLOSE_AWARENESS_RADIUS_TILES: int = 1


static func steps_between(origin: Vector2i, target: Vector2i) -> int:
	var delta: Vector2i = (target - origin).abs()
	return delta.x + delta.y


static func feet_between(origin: Vector2i, target: Vector2i) -> int:
	return steps_between(origin, target) * TILE_SIZE_FEET


static func is_within_steps(
		origin: Vector2i,
		target: Vector2i,
		maximum_steps: int
) -> bool:
	return steps_between(origin, target) <= maxi(0, maximum_steps)


static func minimum_steps_between_sets(
		first_cells: Array[Vector2i],
		second_cells: Array[Vector2i]
) -> int:
	if first_cells.is_empty() or second_cells.is_empty():
		return 1_000_000_000
	var best_steps: int = 1_000_000_000
	for first_cell: Vector2i in first_cells:
		for second_cell: Vector2i in second_cells:
			best_steps = mini(
				best_steps,
				steps_between(first_cell, second_cell)
			)
	return maxi(0, best_steps)
