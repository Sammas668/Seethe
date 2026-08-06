class_name RegionHexDefinition
extends RefCounted

var coord: RegionHexCoord
var playable: bool = true
var terrain_type: StringName = RegionTerrainType.GRASSLAND
var subregion_id: StringName = &""
var site_id: StringName = &""
var visual_variant: int = 0


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if coord == null:
		errors.append("Region hex has no coordinate.")
	if not RegionTerrainType.is_valid(terrain_type):
		errors.append("Region hex uses invalid terrain %s." % terrain_type)
	if subregion_id.is_empty():
		errors.append("Region hex %s has no subregion." % (coord.key() if coord != null else &"unknown"))
	if visual_variant < 0:
		errors.append("Region hex %s has a negative visual variant." % (coord.key() if coord != null else &"unknown"))
	return errors
