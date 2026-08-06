class_name RegionRouteDefinition
extends RefCounted

const PRIMARY_ROAD: StringName = &"primary_road"
const LOCAL_ROAD: StringName = &"local_road"
const FOREST_TRACK: StringName = &"forest_track"
const HIDDEN_TRACK: StringName = &"hidden_track"
const STRONGHOLD_APPROACH: StringName = &"stronghold_approach"

const VALID_CLASSES: Array[StringName] = [
	PRIMARY_ROAD,
	LOCAL_ROAD,
	FOREST_TRACK,
	HIDDEN_TRACK,
	STRONGHOLD_APPROACH,
]

var id: StringName = &""
var route_class: StringName = LOCAL_ROAD
var ordered_hexes: Array[RegionHexCoord] = []
var connected_site_ids: Array[StringName] = []
var movement_profile: StringName = &""
var visible_by_default: bool = true
var tags: Array[StringName] = []
var tactical_entry_direction: StringName = &""
var raid_eligible: bool = false


func has_tag(tag: StringName) -> bool:
	return tag in tags


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Region route has no ID.")
	if route_class not in VALID_CLASSES:
		errors.append("Region route %s has invalid class %s." % [id, route_class])
	if ordered_hexes.size() < 2:
		errors.append("Region route %s has fewer than two hexes." % id)
	for index: int in range(1, ordered_hexes.size()):
		var previous: RegionHexCoord = ordered_hexes[index - 1]
		var current: RegionHexCoord = ordered_hexes[index]
		if previous == null or current == null or not previous.is_adjacent_to(current):
			errors.append("Region route %s contains a non-adjacent path step at index %d." % [id, index])
	return errors
