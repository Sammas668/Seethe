class_name TacticalMeleeReachRules
extends RefCounted

const TILE_SIZE_FEET: int = 5
const UNREACHABLE_DISTANCE_FEET: int = 1_000_000_000


static func can_reach(
		attacker_cells: Array[Vector2i],
		target_cells: Array[Vector2i],
		map_definition: TacticalMapDefinition,
		reach_feet: int
) -> bool:
	return minimum_reach_distance_feet(
		attacker_cells,
		target_cells,
		map_definition
	) <= maxi(TILE_SIZE_FEET, reach_feet)


static func minimum_reach_distance_feet(
		attacker_cells: Array[Vector2i],
		target_cells: Array[Vector2i],
		map_definition: TacticalMapDefinition
) -> int:
	if attacker_cells.is_empty() or target_cells.is_empty():
		return UNREACHABLE_DISTANCE_FEET
	var best_distance_feet: int = UNREACHABLE_DISTANCE_FEET
	for attacker_cell: Vector2i in attacker_cells:
		for target_cell: Vector2i in target_cells:
			var pair_distance: int = _pair_reach_distance_feet(
				attacker_cell,
				target_cell,
				map_definition
			)
			best_distance_feet = mini(best_distance_feet, pair_distance)
	return best_distance_feet


static func has_sealed_diagonal_contact(
		attacker_cells: Array[Vector2i],
		target_cells: Array[Vector2i],
		map_definition: TacticalMapDefinition
) -> bool:
	if map_definition == null:
		return false
	for attacker_cell: Vector2i in attacker_cells:
		for target_cell: Vector2i in target_cells:
			var delta: Vector2i = target_cell - attacker_cell
			if absi(delta.x) != 1 or absi(delta.y) != 1:
				continue
			if _diagonal_corner_is_sealed(
				attacker_cell,
				target_cell,
				map_definition
			):
				return true
	return false


static func _pair_reach_distance_feet(
		attacker_cell: Vector2i,
		target_cell: Vector2i,
		map_definition: TacticalMapDefinition
) -> int:
	if attacker_cell == target_cell:
		return 0
	var delta: Vector2i = (target_cell - attacker_cell).abs()
	if delta.x <= 1 and delta.y <= 1:
		if (
			delta.x == 1
			and delta.y == 1
			and _diagonal_corner_is_sealed(
				attacker_cell,
				target_cell,
				map_definition
			)
		):
			return UNREACHABLE_DISTANCE_FEET
		return TILE_SIZE_FEET
	return (delta.x + delta.y) * TILE_SIZE_FEET


static func _diagonal_corner_is_sealed(
		attacker_cell: Vector2i,
		target_cell: Vector2i,
		map_definition: TacticalMapDefinition
) -> bool:
	if map_definition == null:
		return false
	var delta: Vector2i = target_cell - attacker_cell
	if absi(delta.x) != 1 or absi(delta.y) != 1:
		return false
	var horizontal_step := Vector2i(target_cell.x, attacker_cell.y)
	var vertical_step := Vector2i(attacker_cell.x, target_cell.y)
	return (
		map_definition.is_blocked(horizontal_step)
		and map_definition.is_blocked(vertical_step)
	)
