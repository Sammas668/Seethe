extends RefCounted

const NORTH: int = 1
const EAST: int = 2
const SOUTH: int = 4
const WEST: int = 8


func connections_for(
	map_definition: TacticalMapDefinition,
	tile: Vector2i
) -> int:
	if map_definition == null or not map_definition.is_wall(tile):
		return 0
	var material_id: StringName = map_definition.wall_material_id(tile)
	var result: int = 0
	if map_definition.wall_material_id(tile + Vector2i.UP) == material_id:
		result |= NORTH
	if map_definition.wall_material_id(tile + Vector2i.RIGHT) == material_id:
		result |= EAST
	if map_definition.wall_material_id(tile + Vector2i.DOWN) == material_id:
		result |= SOUTH
	if map_definition.wall_material_id(tile + Vector2i.LEFT) == material_id:
		result |= WEST
	return result


func segment_kind(connections: int) -> StringName:
	if connections == 0:
		return &"isolated"
	if connections == (EAST | WEST):
		return &"horizontal"
	if connections == (NORTH | SOUTH):
		return &"vertical"
	if connections in [
		NORTH | EAST,
		EAST | SOUTH,
		SOUTH | WEST,
		WEST | NORTH,
	]:
		return &"corner"
	if connections in [
		NORTH | EAST | SOUTH,
		EAST | SOUTH | WEST,
		SOUTH | WEST | NORTH,
		WEST | NORTH | EAST,
	]:
		return &"t_junction"
	if connections == (NORTH | EAST | SOUTH | WEST):
		return &"cross"
	return &"end_cap"
