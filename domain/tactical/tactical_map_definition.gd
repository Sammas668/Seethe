class_name TacticalMapDefinition
extends Resource

@export var definition_id: StringName = &""
@export var grid_size: Vector2i = Vector2i(20, 20)
@export var blocked_tiles: Array[Vector2i] = []
@export var difficult_tiles: Array[Vector2i] = []
@export var starting_tile: Vector2i = Vector2i(2, 2)
@export var player_starting_tiles: Array[Vector2i] = []


func is_inside(tile: Vector2i) -> bool:
	return (
		tile.x >= 0
		and tile.y >= 0
		and tile.x < grid_size.x
		and tile.y < grid_size.y
	)


func is_blocked(tile: Vector2i) -> bool:
	return not is_inside(tile) or blocked_tiles.has(tile)


func is_difficult(tile: Vector2i) -> bool:
	return difficult_tiles.has(tile)


func movement_multiplier(tile: Vector2i) -> int:
	return 2 if is_difficult(tile) else 1


func get_player_starting_tile(index: int, fallback: Vector2i) -> Vector2i:
	if index >= 0 and index < player_starting_tiles.size():
		return player_starting_tiles[index]
	if index == 0:
		return starting_tile
	return fallback
