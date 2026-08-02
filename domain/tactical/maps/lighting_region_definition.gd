class_name LightingRegionDefinition
extends Resource

@export var region_id: StringName = &""
@export var light_category: StringName = &"bright"
@export var tile_coordinates: Array[Vector2i] = []


func validate_definition(map_definition: TacticalMapDefinition) -> Array[String]:
	var errors: Array[String] = []
	if region_id.is_empty():
		errors.append("Lighting region has no ID.")
	for tile: Vector2i in tile_coordinates:
		if map_definition == null or not map_definition.is_inside(tile):
			errors.append("Lighting region %s contains out-of-map tile %s." % [region_id, tile])
	return errors
