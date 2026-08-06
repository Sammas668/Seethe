class_name MapZoneDefinition
extends Resource

const KIND_DEPLOYMENT: StringName = &"deployment"
const KIND_OBJECTIVE: StringName = &"objective"
const KIND_REINFORCEMENT: StringName = &"reinforcement"
const KIND_WORK_AREA: StringName = &"work_area"

@export var zone_id: StringName = &""
@export var display_name: String = "Map zone"
@export var zone_kind: StringName = KIND_DEPLOYMENT
@export var tile_coordinates: Array[Vector2i] = []
@export var allowed_team_ids: Array[StringName] = []
@export var tags: Array[StringName] = []


func contains(tile: Vector2i) -> bool:
	return tile_coordinates.has(tile)


func validate_definition(map_definition: TacticalMapDefinition) -> Array[String]:
	var errors: Array[String] = []
	if zone_id.is_empty():
		errors.append("Map zone has no ID.")
	if tile_coordinates.is_empty():
		errors.append("Map zone %s has no tiles." % zone_id)
	var seen: Dictionary = {}
	for tile: Vector2i in tile_coordinates:
		if seen.has(tile):
			errors.append("Map zone %s duplicates tile %s." % [zone_id, tile])
		seen[tile] = true
		if map_definition == null or not map_definition.is_inside(tile) or map_definition.is_blocked(tile):
			errors.append("Map zone %s contains illegal tile %s." % [zone_id, tile])
	return errors
