class_name RegionHexCoord
extends RefCounted

var q: int = 0
var r: int = 0
var offset_col: int = 0
var offset_row: int = 0


static func from_offset(column: int, row: int) -> RegionHexCoord:
	var result := RegionHexCoord.new()
	result.offset_col = column
	result.offset_row = row
	result.q = column
	result.r = row - floori(float(column + (column & 1)) / 2.0)
	return result


static func from_axial(q_value: int, r_value: int) -> RegionHexCoord:
	var result := RegionHexCoord.new()
	result.q = q_value
	result.r = r_value
	result.offset_col = q_value
	result.offset_row = r_value + floori(float(q_value + (q_value & 1)) / 2.0)
	return result


func key() -> StringName:
	return StringName("%d,%d" % [offset_col, offset_row])


func duplicate_coord() -> RegionHexCoord:
	return RegionHexCoord.from_offset(offset_col, offset_row)


func neighbours() -> Array[RegionHexCoord]:
	var axial_directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(1, -1),
		Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1),
	]
	var result: Array[RegionHexCoord] = []
	for direction: Vector2i in axial_directions:
		result.append(RegionHexCoord.from_axial(q + direction.x, r + direction.y))
	return result


func is_adjacent_to(other: RegionHexCoord) -> bool:
	if other == null:
		return false
	var dq: int = q - other.q
	var dr: int = r - other.r
	var ds: int = (-q - r) - (-other.q - other.r)
	return maxi(abs(dq), maxi(abs(dr), abs(ds))) == 1


func to_dictionary() -> Dictionary:
	return {
		"q": q,
		"r": r,
		"offset_col": offset_col,
		"offset_row": offset_row,
	}
