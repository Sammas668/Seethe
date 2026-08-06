class_name TacticalExtractionZoneDefinition
extends Resource

@export var zone_id: StringName = &""
@export var display_name: String = "Extraction Zone"
@export var tile_coordinates: Array[Vector2i] = []
@export var permitted_faction_id: StringName = &"player"
@export var route_kind: StringName = &"mission_zone"
@export var enabled_from_start: bool = true
@export var allows_characters: bool = true
@export var allows_items: bool = true
@export var allows_bodies: bool = true
@export var allows_captives: bool = true


func contains_tile(tile: Vector2i) -> bool:
	return tile_coordinates.has(tile)


func contains_complete_footprint(
		origin: Vector2i,
		footprint: Vector2i
) -> bool:
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			if not contains_tile(origin + Vector2i(x, y)):
				return false
	return true


func validate_definition(map_definition: TacticalMapDefinition = null) -> Array[String]:
	var errors: Array[String] = []
	if zone_id.is_empty():
		errors.append("Extraction zone has no ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Extraction zone %s has no display name." % zone_id)
	if tile_coordinates.is_empty():
		errors.append("Extraction zone %s has no tiles." % zone_id)
	var seen: Dictionary = {}
	for tile: Vector2i in tile_coordinates:
		if seen.has(tile):
			errors.append("Extraction zone %s duplicates tile %s." % [zone_id, tile])
		seen[tile] = true
		if map_definition != null:
			if not map_definition.is_inside(tile):
				errors.append("Extraction zone %s contains out-of-map tile %s." % [zone_id, tile])
			elif map_definition.is_blocked(tile):
				errors.append("Extraction zone %s contains blocked tile %s." % [zone_id, tile])
	return errors


func to_dictionary() -> Dictionary:
	var tiles: Array = []
	for tile: Vector2i in tile_coordinates:
		tiles.append([tile.x, tile.y])
	return {
		"zone_id": String(zone_id),
		"display_name": display_name,
		"tile_coordinates": tiles,
		"permitted_faction_id": String(permitted_faction_id),
		"route_kind": String(route_kind),
		"enabled_from_start": enabled_from_start,
		"allows_characters": allows_characters,
		"allows_items": allows_items,
		"allows_bodies": allows_bodies,
		"allows_captives": allows_captives,
	}


static func from_dictionary(data: Dictionary) -> TacticalExtractionZoneDefinition:
	var result := TacticalExtractionZoneDefinition.new()
	result.zone_id = StringName(data.get("zone_id", ""))
	result.display_name = String(data.get("display_name", "Extraction Zone"))
	result.permitted_faction_id = StringName(data.get("permitted_faction_id", "player"))
	result.route_kind = StringName(data.get("route_kind", "mission_zone"))
	result.enabled_from_start = bool(data.get("enabled_from_start", true))
	result.allows_characters = bool(data.get("allows_characters", true))
	result.allows_items = bool(data.get("allows_items", true))
	result.allows_bodies = bool(data.get("allows_bodies", true))
	result.allows_captives = bool(data.get("allows_captives", true))
	var raw_tiles: Variant = data.get("tile_coordinates", [])
	if raw_tiles is Array:
		for raw_tile: Variant in raw_tiles as Array:
			if typeof(raw_tile) == TYPE_VECTOR2I:
				result.tile_coordinates.append(raw_tile)
			elif raw_tile is Array and (raw_tile as Array).size() >= 2:
				var values: Array = raw_tile as Array
				result.tile_coordinates.append(Vector2i(int(values[0]), int(values[1])))
	return result
