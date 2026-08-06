class_name RegionSiteDefinition
extends RefCounted

var id: StringName = &""
var display_name: String = ""
var site_type: StringName = &""
var coord: RegionHexCoord
var footprint: Array[RegionHexCoord] = []
var parent_settlement_id: StringName = &""
var subregion_id: StringName = &""
var description: String = ""
var tags: Array[StringName] = []
var icon_id: StringName = &""
var mission_definition_ids: Array[StringName] = []
var inspectable: bool = true
var label_priority: int = 0
var aliases: Array[StringName] = []


func has_tag(tag: StringName) -> bool:
	return tag in tags


func contains_offset(column: int, row: int) -> bool:
	for footprint_coord: RegionHexCoord in footprint:
		if footprint_coord.offset_col == column and footprint_coord.offset_row == row:
			return true
	return coord != null and coord.offset_col == column and coord.offset_row == row


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Region site has no ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Region site %s has no display name." % id)
	if site_type.is_empty():
		errors.append("Region site %s has no site type." % id)
	if coord == null:
		errors.append("Region site %s has no coordinate." % id)
	if subregion_id.is_empty():
		errors.append("Region site %s has no subregion." % id)
	if footprint.is_empty() and coord != null:
		errors.append("Region site %s has no footprint." % id)
	return errors
