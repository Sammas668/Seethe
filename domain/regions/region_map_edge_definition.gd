class_name RegionMapEdgeDefinition
extends RefCounted

const ROAD: StringName = &"road"
const BORDER: StringName = &"border"
const VALID_EDGE_TYPES: Array[StringName] = [ROAD, BORDER]

var id: StringName = &""
var coord: RegionHexCoord
var neighbour_coord: RegionHexCoord
var edge_index: int = -1
var edge_type: StringName = &""
var style_id: StringName = &""
var visual_variant: int = 0


func touches_offset(column: int, row: int) -> bool:
	if coord != null and coord.offset_col == column and coord.offset_row == row:
		return true
	return neighbour_coord != null \
		and neighbour_coord.offset_col == column \
		and neighbour_coord.offset_row == row


func canonical_key() -> StringName:
	if coord == null:
		return &""
	if neighbour_coord == null:
		return StringName("%d,%d:e%d" % [coord.offset_col, coord.offset_row, edge_index])
	var first: String = "%d,%d" % [coord.offset_col, coord.offset_row]
	var second: String = "%d,%d" % [neighbour_coord.offset_col, neighbour_coord.offset_row]
	if second < first:
		var swap: String = first
		first = second
		second = swap
	return StringName("%s|%s" % [first, second])


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Region map edge has no ID.")
	if coord == null:
		errors.append("Region map edge %s has no owner coordinate." % id)
	if edge_index < 0 or edge_index > 5:
		errors.append("Region map edge %s has invalid edge index %d." % [id, edge_index])
	if edge_type not in VALID_EDGE_TYPES:
		errors.append("Region map edge %s has invalid edge type %s." % [id, edge_type])
	if style_id.is_empty():
		errors.append("Region map edge %s has no style ID." % id)
	if coord != null and neighbour_coord != null and not coord.is_adjacent_to(neighbour_coord):
		errors.append("Region map edge %s references a non-adjacent neighbour." % id)
	return errors
