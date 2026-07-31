class_name TacticalEdgeKey
extends RefCounted

var first_tile: Vector2i
var second_tile: Vector2i


func _init(
		first_tile_value: Vector2i = Vector2i.ZERO,
		second_tile_value: Vector2i = Vector2i.ZERO
) -> void:
	var normalized: Array[Vector2i] = normalize_pair(
		first_tile_value,
		second_tile_value
	)
	first_tile = normalized[0]
	second_tile = normalized[1]


func id() -> StringName:
	return make_id(first_tile, second_tile)


static func make_id(first: Vector2i, second: Vector2i) -> StringName:
	var normalized: Array[Vector2i] = normalize_pair(first, second)
	var a: Vector2i = normalized[0]
	var b: Vector2i = normalized[1]
	return StringName("%d,%d|%d,%d" % [a.x, a.y, b.x, b.y])


static func normalize_pair(
		first: Vector2i,
		second: Vector2i
) -> Array[Vector2i]:
	if _comes_before(second, first):
		return [second, first]
	return [first, second]


static func are_adjacent(first: Vector2i, second: Vector2i) -> bool:
	var delta: Vector2i = (second - first).abs()
	return delta.x + delta.y == 1


static func _comes_before(first: Vector2i, second: Vector2i) -> bool:
	if first.y != second.y:
		return first.y < second.y
	return first.x < second.x
