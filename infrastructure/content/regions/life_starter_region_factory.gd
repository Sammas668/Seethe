class_name LifeStarterRegionFactory
extends RefCounted

const REGION_METADATA_PATH: String = "res://content/regions/life_starter/life_starter_region.json"
const REGION_HEXES_PATH: String = "res://content/regions/life_starter/life_starter_region_hexes.csv"
const REGION_SITES_PATH: String = "res://content/regions/life_starter/life_starter_region_sites.json"
const REGION_ROAD_EDGES_PATH: String = "res://content/regions/life_starter/life_starter_region_road_edges.json"
const REGION_BORDER_EDGES_PATH: String = "res://content/regions/life_starter/life_starter_region_border_edges.json"


static func create_definition() -> RegionMapDefinition:
	var metadata: Dictionary = _read_json_dictionary(REGION_METADATA_PATH)
	if metadata.is_empty():
		push_error("Life starter region metadata could not be loaded.")
		return null
	var definition := RegionMapDefinition.new()
	definition.id = StringName(metadata.get("id", ""))
	definition.display_name = String(metadata.get("display_name", ""))
	definition.width = int(metadata.get("width", 0))
	definition.height = int(metadata.get("height", 0))
	definition.hex_orientation = StringName(metadata.get("hex_orientation", "flat_top_even_q"))
	definition.main_settlement_site_id = StringName(metadata.get("main_settlement_site_id", ""))
	definition.fifth_god_ruin_site_id = StringName(metadata.get("fifth_god_ruin_site_id", ""))
	definition.military_site_id = StringName(metadata.get("military_site_id", ""))
	definition.religious_site_ids = _string_name_array(metadata.get("religious_site_ids", []))
	definition.mission_site_ids = _string_name_array(metadata.get("mission_site_ids", []))
	definition.aliases = _string_name_array(metadata.get("aliases", []))
	var label_offsets: Variant = metadata.get("label_offsets", {})
	if label_offsets is Dictionary:
		for raw_site_id: Variant in (label_offsets as Dictionary).keys():
			var pair: Variant = (label_offsets as Dictionary)[raw_site_id]
			if pair is Array and (pair as Array).size() >= 2:
				definition.label_offsets_by_site_id[StringName(raw_site_id)] = Vector2(
					float((pair as Array)[0]),
					float((pair as Array)[1])
				)
	for raw_subregion: Variant in metadata.get("subregions", []):
		if raw_subregion is Dictionary:
			var entry: Dictionary = raw_subregion as Dictionary
			var subregion_id := StringName(entry.get("id", ""))
			if not subregion_id.is_empty():
				definition.subregions_by_id[subregion_id] = String(entry.get("display_name", subregion_id))
	if not _load_hexes(definition):
		return null
	if not _load_sites(definition):
		return null
	if not _load_map_edges(definition, REGION_ROAD_EDGES_PATH, "road_edges", RegionMapEdgeDefinition.ROAD):
		return null
	if not _load_map_edges(definition, REGION_BORDER_EDGES_PATH, "border_edges", RegionMapEdgeDefinition.BORDER):
		return null
	var errors: Array[String] = definition.validate_definition()
	if not errors.is_empty():
		push_error("Life starter region is invalid: %s" % errors[0])
		return null
	return definition


static func _load_hexes(definition: RegionMapDefinition) -> bool:
	var file := FileAccess.open(REGION_HEXES_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open the authored Life-region hex transcription.")
		return false
	var header: PackedStringArray = file.get_csv_line(",")
	var indices: Dictionary = {}
	for index: int in range(header.size()):
		indices[String(header[index]).strip_edges()] = index
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line(",")
		if row.is_empty() or String(row[0]).strip_edges().is_empty():
			continue
		var column: int = int(_csv_value(row, indices, "offset_col"))
		var offset_row: int = int(_csv_value(row, indices, "offset_row"))
		var hex := RegionHexDefinition.new()
		hex.coord = RegionHexCoord.from_offset(column, offset_row)
		hex.playable = _csv_value(row, indices, "playable").to_lower() == "true"
		hex.terrain_type = StringName(_csv_value(row, indices, "terrain"))
		hex.subregion_id = StringName(_csv_value(row, indices, "subregion"))
		hex.site_id = StringName(_csv_value(row, indices, "site_id"))
		hex.visual_variant = int(_csv_value(row, indices, "visual_variant"))
		if not definition.add_hex(hex):
			push_error("Duplicate or invalid authored region hex %d,%d." % [column, offset_row])
			return false
	return true


static func _load_sites(definition: RegionMapDefinition) -> bool:
	var data: Dictionary = _read_json_dictionary(REGION_SITES_PATH)
	for raw_site: Variant in data.get("sites", []):
		if not raw_site is Dictionary:
			continue
		var entry: Dictionary = raw_site as Dictionary
		var site := RegionSiteDefinition.new()
		site.id = StringName(entry.get("id", ""))
		site.display_name = String(entry.get("display_name", ""))
		site.site_type = StringName(entry.get("site_type", ""))
		site.coord = _coord_from_pair(entry.get("coord", []))
		for raw_coord: Variant in entry.get("footprint", []):
			var footprint_coord: RegionHexCoord = _coord_from_pair(raw_coord)
			if footprint_coord != null:
				site.footprint.append(footprint_coord)
		site.parent_settlement_id = StringName(entry.get("parent_settlement_id", ""))
		site.subregion_id = StringName(entry.get("subregion_id", ""))
		site.description = String(entry.get("description", ""))
		site.tags = _string_name_array(entry.get("tags", []))
		site.icon_id = StringName(entry.get("icon_id", ""))
		site.mission_definition_ids = _string_name_array(entry.get("mission_definition_ids", []))
		site.inspectable = bool(entry.get("inspectable", true))
		site.label_priority = int(entry.get("label_priority", 0))
		site.aliases = _string_name_array(entry.get("aliases", []))
		if not definition.add_site(site):
			push_error("Duplicate or invalid authored region site %s." % site.id)
			return false
	return not definition.sites_by_id.is_empty()


static func _load_map_edges(
	definition: RegionMapDefinition,
	path: String,
	collection_key: String,
	edge_type: StringName
) -> bool:
	var data: Dictionary = _read_json_dictionary(path)
	for raw_edge: Variant in data.get(collection_key, []):
		if not raw_edge is Dictionary:
			continue
		var entry: Dictionary = raw_edge as Dictionary
		var edge := RegionMapEdgeDefinition.new()
		edge.id = StringName(entry.get("id", ""))
		edge.coord = _coord_from_pair(entry.get("coord", []))
		edge.neighbour_coord = _coord_from_pair(entry.get("neighbour_coord", []))
		edge.edge_index = int(entry.get("edge_index", -1))
		edge.edge_type = edge_type
		edge.visual_variant = int(entry.get("visual_variant", 0))
		if edge_type == RegionMapEdgeDefinition.ROAD:
			edge.style_id = RegionRoadType.normalize(StringName(entry.get("road_class", RegionRoadType.LOCAL_ROAD)))
			if not definition.add_road_edge(edge):
				push_error("Duplicate or invalid authored road edge %s." % edge.id)
				return false
		else:
			edge.style_id = StringName(entry.get("border_class", "subregion_border"))
			if not definition.add_border_edge(edge):
				push_error("Duplicate or invalid authored border edge %s." % edge.id)
				return false
	if edge_type == RegionMapEdgeDefinition.ROAD:
		return definition.road_edges_by_id.size() > 0
	return definition.border_edges_by_id.size() > 0


static func _read_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func _coord_from_pair(raw_value: Variant) -> RegionHexCoord:
	if not raw_value is Array:
		return null
	var pair: Array = raw_value as Array
	if pair.size() < 2:
		return null
	return RegionHexCoord.from_offset(int(pair[0]), int(pair[1]))


static func _string_name_array(raw_value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if raw_value is Array:
		var raw_entries: Array = raw_value as Array
		for raw_entry: Variant in raw_entries:
			var entry := StringName(raw_entry)
			if not entry.is_empty():
				result.append(entry)
	return result


static func _csv_value(row: PackedStringArray, indices: Dictionary, column_name: String) -> String:
	var index: int = int(indices.get(column_name, -1))
	return String(row[index]).strip_edges() if index >= 0 and index < row.size() else ""
