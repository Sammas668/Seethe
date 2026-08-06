class_name RegionAuthoringDocument
extends RefCounted

const FORMAT_VERSION: int = 3

var region: RegionMapDefinition
var label_offsets_by_site_id: Dictionary = {}
var editor_metadata: Dictionary = {
	"camera_zoom": 1.0,
	"camera_pan_x": 0.0,
	"camera_pan_y": 0.0,
	"active_tool": "select",
}
var source_runtime_id: StringName = &"region.life.starter"


static func from_runtime(definition: RegionMapDefinition) -> RegionAuthoringDocument:
	var document := RegionAuthoringDocument.new()
	document.region = _clone_region(definition)
	document.source_runtime_id = definition.id if definition != null else &""
	document._normalise_legacy_symbols()
	document._migrate_removed_route_data()
	return document


static func from_dictionary(data: Dictionary) -> RegionAuthoringDocument:
	var document := RegionAuthoringDocument.new()
	document.region = _region_from_dictionary(data.get("region", {}) as Dictionary)
	document.source_runtime_id = StringName(data.get("source_runtime_id", ""))
	document.label_offsets_by_site_id.clear()
	var labels: Dictionary = data.get("label_offsets_by_site_id", {}) as Dictionary
	for raw_id: Variant in labels.keys():
		var pair: Variant = labels[raw_id]
		if pair is Array and (pair as Array).size() >= 2:
			document.label_offsets_by_site_id[StringName(raw_id)] = Vector2(
				float((pair as Array)[0]),
				float((pair as Array)[1])
			)
	var metadata: Variant = data.get("editor_metadata", {})
	if metadata is Dictionary:
		document.editor_metadata.merge(metadata as Dictionary, true)
	document._normalise_legacy_symbols()
	document._migrate_removed_route_data()
	document.apply_label_offsets_to_region()
	return document


func to_dictionary() -> Dictionary:
	var labels: Dictionary = {}
	for raw_id: Variant in label_offsets_by_site_id.keys():
		var offset: Vector2 = label_offsets_by_site_id[raw_id]
		labels[String(raw_id)] = [offset.x, offset.y]
	return {
		"format_version": FORMAT_VERSION,
		"source_runtime_id": String(source_runtime_id),
		"region": _region_to_dictionary(region),
		"label_offsets_by_site_id": labels,
		"editor_metadata": editor_metadata.duplicate(true),
	}


func snapshot_text() -> String:
	return JSON.stringify(to_dictionary(), "\t", false)


func restore_snapshot(snapshot: String) -> bool:
	var parsed: Variant = JSON.parse_string(snapshot)
	if not (parsed is Dictionary):
		return false
	var restored := RegionAuthoringDocument.from_dictionary(parsed as Dictionary)
	region = restored.region
	label_offsets_by_site_id = restored.label_offsets_by_site_id
	editor_metadata = restored.editor_metadata
	source_runtime_id = restored.source_runtime_id
	return true


func _normalise_legacy_symbols() -> void:
	if region == null:
		return
	for site: RegionSiteDefinition in region.all_sites():
		if site.site_type != &"district":
			continue
		match site.icon_id:
			&"district_textiles":
				site.icon_id = RegionSymbolCatalogue.TEXTILES_WAREHOUSE
			&"district_craftsman":
				site.icon_id = RegionSymbolCatalogue.CRAFTSMANS_DISTRICT
			&"district_guild", &"district_civic":
				site.icon_id = RegionSymbolCatalogue.GUILD_HOUSE
			&"district_noble":
				site.icon_id = RegionSymbolCatalogue.NOBLE_HOUSING
			&"district_merchant":
				site.icon_id = RegionSymbolCatalogue.MARKET
			&"district_industry":
				if "lumber" in String(site.id).to_lower():
					site.icon_id = RegionSymbolCatalogue.LUMBERMILL
				else:
					site.icon_id = RegionSymbolCatalogue.CRAFTSMANS_DISTRICT
			&"district_warehouse":
				if "textile" in String(site.id).to_lower():
					site.icon_id = RegionSymbolCatalogue.TEXTILES_WAREHOUSE
				else:
					site.icon_id = RegionSymbolCatalogue.WHEAT_WAREHOUSE
			_:
				pass


func _migrate_removed_route_data() -> void:
	if region == null:
		return
	for site: RegionSiteDefinition in region.all_sites():
		site.tags.erase(&"STRONGHOLD_APPROACH")
	for edge: RegionMapEdgeDefinition in region.all_road_edges():
		edge.style_id = RegionRoadType.normalize(edge.style_id)


func apply_label_offsets_to_region() -> void:
	if region != null:
		region.label_offsets_by_site_id = label_offsets_by_site_id.duplicate(true)


func selected_hex(column: int, row: int) -> RegionHexDefinition:
	return region.hex_at_offset(column, row) if region != null else null


func site_at_offset(column: int, row: int) -> RegionSiteDefinition:
	if region == null:
		return null
	var sites: Array[RegionSiteDefinition] = region.sites_at_offset(column, row)
	for site: RegionSiteDefinition in sites:
		if site.site_type == &"district":
			return site
	for site: RegionSiteDefinition in sites:
		if site.site_type == &"settlement":
			return site
	return sites[0] if not sites.is_empty() else null


func settlement_at_offset(column: int, row: int) -> RegionSiteDefinition:
	if region == null:
		return null
	for site: RegionSiteDefinition in region.all_sites():
		if site.site_type == &"settlement" and site.contains_offset(column, row):
			return site
	return null


func district_at_offset(column: int, row: int) -> RegionSiteDefinition:
	if region == null:
		return null
	for site: RegionSiteDefinition in region.all_sites():
		if site.site_type == &"district" and site.contains_offset(column, row):
			return site
	return null


func toggle_settlement_footprint(
	settlement_id: StringName,
	column: int,
	row: int,
	add_hex: bool
) -> bool:
	if region == null:
		return false
	var settlement: RegionSiteDefinition = region.site(settlement_id)
	var hex: RegionHexDefinition = region.hex_at_offset(column, row)
	if settlement == null or settlement.site_type != &"settlement" or hex == null or not hex.playable:
		return false
	if add_hex:
		for other: RegionSiteDefinition in region.all_sites():
			if other.site_type == &"settlement" and other.id != settlement_id and other.contains_offset(column, row):
				return false
		if not _footprint_contains(settlement.footprint, column, row):
			settlement.footprint.append(RegionHexCoord.from_offset(column, row))
		if settlement.coord == null:
			settlement.coord = RegionHexCoord.from_offset(column, row)
		hex.site_id = settlement.id
		return true
	if _footprint_contains(settlement.footprint, column, row):
		_remove_coord(settlement.footprint, column, row)
		var district: RegionSiteDefinition = district_at_offset(column, row)
		if district != null and district.parent_settlement_id == settlement.id:
			region.sites_by_id.erase(district.id)
		hex.site_id = &""
		if settlement.coord != null and settlement.coord.offset_col == column and settlement.coord.offset_row == row:
			settlement.coord = settlement.footprint[0].duplicate_coord() if not settlement.footprint.is_empty() else null
		return true
	return false


func assign_district(
	settlement_id: StringName,
	column: int,
	row: int,
	symbol_id: StringName
) -> bool:
	var settlement: RegionSiteDefinition = region.site(settlement_id) if region != null else null
	if settlement == null or settlement.site_type != &"settlement":
		return false
	if not settlement.contains_offset(column, row) or not RegionSymbolCatalogue.is_valid(symbol_id):
		return false
	var existing: RegionSiteDefinition = district_at_offset(column, row)
	if existing != null:
		if existing.parent_settlement_id != settlement_id:
			return false
		existing.icon_id = symbol_id
		existing.display_name = RegionSymbolCatalogue.display_name(symbol_id)
		return true
	var district := RegionSiteDefinition.new()
	district.id = StringName("%s.district.%d_%d" % [settlement_id, column, row])
	district.display_name = RegionSymbolCatalogue.display_name(symbol_id)
	district.site_type = &"district"
	district.coord = RegionHexCoord.from_offset(column, row)
	district.footprint = [district.coord.duplicate_coord()]
	district.parent_settlement_id = settlement_id
	district.subregion_id = settlement.subregion_id
	district.description = "%s district of %s." % [district.display_name, settlement.display_name]
	district.icon_id = symbol_id
	district.inspectable = true
	district.label_priority = 0
	return region.add_site(district)


func clear_district(column: int, row: int) -> bool:
	var district: RegionSiteDefinition = district_at_offset(column, row)
	if district == null or region == null:
		return false
	region.sites_by_id.erase(district.id)
	return true


func move_site(site_id: StringName, column: int, row: int) -> bool:
	if region == null:
		return false
	var site: RegionSiteDefinition = region.site(site_id)
	var hex: RegionHexDefinition = region.hex_at_offset(column, row)
	if site == null or hex == null or not hex.playable:
		return false
	if site.site_type == &"settlement":
		return false
	if site.site_type == &"district":
		return assign_district(site.parent_settlement_id, column, row, site.icon_id)
	var old_coord: RegionHexCoord = site.coord.duplicate_coord() if site.coord != null else null
	if old_coord != null:
		var old_hex: RegionHexDefinition = region.hex_at_offset(old_coord.offset_col, old_coord.offset_row)
		if old_hex != null and old_hex.site_id == site.id:
			old_hex.site_id = &""
	site.coord = RegionHexCoord.from_offset(column, row)
	site.footprint = [site.coord.duplicate_coord()]
	site.subregion_id = hex.subregion_id
	if hex.site_id.is_empty():
		hex.site_id = site.id
	return true


func create_settlement(
	settlement_id: StringName,
	display_name: String,
	column: int,
	row: int,
	subregion_id: StringName,
	icon_id: StringName
) -> bool:
	if region == null or settlement_id.is_empty() or region.site(settlement_id) != null:
		return false
	var hex: RegionHexDefinition = region.hex_at_offset(column, row)
	if hex == null or not hex.playable or settlement_at_offset(column, row) != null:
		return false
	var settlement := RegionSiteDefinition.new()
	settlement.id = settlement_id
	settlement.display_name = display_name
	settlement.site_type = &"settlement"
	settlement.coord = RegionHexCoord.from_offset(column, row)
	settlement.footprint = [settlement.coord.duplicate_coord()]
	settlement.subregion_id = subregion_id
	settlement.icon_id = icon_id
	settlement.inspectable = true
	settlement.label_priority = 60
	if not region.add_site(settlement):
		return false
	hex.site_id = settlement.id
	return true


func create_site(
	site_id: StringName,
	display_name: String,
	site_type: StringName,
	column: int,
	row: int,
	icon_id: StringName
) -> bool:
	if region == null or site_id.is_empty() or region.site(site_id) != null:
		return false
	var hex: RegionHexDefinition = region.hex_at_offset(column, row)
	if hex == null or not hex.playable:
		return false
	var site := RegionSiteDefinition.new()
	site.id = site_id
	site.display_name = display_name
	site.site_type = site_type
	site.coord = RegionHexCoord.from_offset(column, row)
	site.footprint = [site.coord.duplicate_coord()]
	site.subregion_id = hex.subregion_id
	site.icon_id = icon_id
	site.inspectable = true
	site.label_priority = 70
	if not region.add_site(site):
		return false
	if hex.site_id.is_empty():
		hex.site_id = site.id
	return true


func delete_site(site_id: StringName) -> bool:
	if region == null or not region.sites_by_id.has(site_id):
		return false
	var site: RegionSiteDefinition = region.site(site_id)
	if site != null:
		for coord: RegionHexCoord in site.footprint:
			var occupied_hex: RegionHexDefinition = region.hex_at_offset(coord.offset_col, coord.offset_row)
			if occupied_hex != null and occupied_hex.site_id == site.id:
				occupied_hex.site_id = &""
	if site != null and site.site_type == &"settlement":
		var children: Array[StringName] = []
		for child: RegionSiteDefinition in region.all_sites():
			if child.parent_settlement_id == site_id:
				children.append(child.id)
		for child_id: StringName in children:
			region.sites_by_id.erase(child_id)
	region.sites_by_id.erase(site_id)
	label_offsets_by_site_id.erase(site_id)
	return true


func add_or_replace_edge(
	is_road: bool,
	owner: RegionHexCoord,
	neighbour: RegionHexCoord,
	edge_index: int,
	style_id: StringName
) -> bool:
	if region == null or owner == null:
		return false
	if neighbour != null and not owner.is_adjacent_to(neighbour):
		return false
	if neighbour == null and (edge_index < 0 or edge_index > 5):
		return false
	var canonical: StringName = _canonical_edge_key(owner, neighbour, edge_index)
	var source: Dictionary = region.road_edges_by_id if is_road else region.border_edges_by_id
	var existing_id: StringName = &""
	for raw_edge: Variant in source.values():
		var existing: RegionMapEdgeDefinition = raw_edge as RegionMapEdgeDefinition
		if existing != null and existing.canonical_key() == canonical:
			existing_id = existing.id
			break
	var edge := RegionMapEdgeDefinition.new()
	edge.id = existing_id if not existing_id.is_empty() else StringName(
		("road." if is_road else "border.") + String(canonical).replace(",", "_").replace("|", "__").replace(":", "_")
	)
	edge.coord = owner.duplicate_coord()
	edge.neighbour_coord = neighbour.duplicate_coord() if neighbour != null else null
	edge.edge_index = edge_index
	edge.edge_type = RegionMapEdgeDefinition.ROAD if is_road else RegionMapEdgeDefinition.BORDER
	edge.style_id = RegionRoadType.normalize(style_id) if is_road else style_id
	edge.visual_variant = 0
	if is_road:
		region.road_edges_by_id[edge.id] = edge
	else:
		region.border_edges_by_id[edge.id] = edge
	return true


func remove_edge(is_road: bool, owner: RegionHexCoord, neighbour: RegionHexCoord, edge_index: int = -1) -> bool:
	if region == null or owner == null:
		return false
	var canonical: StringName = _canonical_edge_key(owner, neighbour, edge_index)
	var source: Dictionary = region.road_edges_by_id if is_road else region.border_edges_by_id
	for raw_id: Variant in source.keys():
		var edge: RegionMapEdgeDefinition = source[raw_id] as RegionMapEdgeDefinition
		if edge != null and edge.canonical_key() == canonical:
			source.erase(raw_id)
			return true
	return false


func paint_subregion(column: int, row: int, subregion_id: StringName) -> bool:
	if region == null or not region.subregions_by_id.has(subregion_id):
		return false
	var hex: RegionHexDefinition = region.hex_at_offset(column, row)
	if hex == null or not hex.playable or hex.subregion_id == subregion_id:
		return false
	hex.subregion_id = subregion_id
	for site: RegionSiteDefinition in region.sites_at_offset(column, row):
		if site.coord != null and site.coord.offset_col == column and site.coord.offset_row == row:
			site.subregion_id = subregion_id
	return true


func set_label_offset(site_id: StringName, offset: Vector2) -> bool:
	if region == null or region.site(site_id) == null:
		return false
	label_offsets_by_site_id[site_id] = offset
	apply_label_offsets_to_region()
	return true


static func _clone_region(definition: RegionMapDefinition) -> RegionMapDefinition:
	if definition == null:
		return null
	return _region_from_dictionary(_region_to_dictionary(definition))


static func _region_to_dictionary(definition: RegionMapDefinition) -> Dictionary:
	if definition == null:
		return {}
	var hexes: Array[Dictionary] = []
	for hex: RegionHexDefinition in definition.all_hexes():
		hexes.append({
			"coord": [hex.coord.offset_col, hex.coord.offset_row],
			"playable": hex.playable,
			"terrain_type": String(hex.terrain_type),
			"subregion_id": String(hex.subregion_id),
			"site_id": String(hex.site_id),
			"visual_variant": hex.visual_variant,
		})
	var sites: Array[Dictionary] = []
	for site: RegionSiteDefinition in definition.all_sites():
		var footprint: Array = []
		for coord: RegionHexCoord in site.footprint:
			footprint.append([coord.offset_col, coord.offset_row])
		sites.append({
			"id": String(site.id),
			"display_name": site.display_name,
			"site_type": String(site.site_type),
			"coord": [site.coord.offset_col, site.coord.offset_row] if site.coord != null else [],
			"footprint": footprint,
			"parent_settlement_id": String(site.parent_settlement_id),
			"subregion_id": String(site.subregion_id),
			"description": site.description,
			"tags": _string_name_array_to_strings(site.tags),
			"icon_id": String(site.icon_id),
			"mission_definition_ids": _string_name_array_to_strings(site.mission_definition_ids),
			"inspectable": site.inspectable,
			"label_priority": site.label_priority,
			"aliases": _string_name_array_to_strings(site.aliases),
		})
	return {
		"id": String(definition.id),
		"display_name": definition.display_name,
		"width": definition.width,
		"height": definition.height,
		"hex_orientation": String(definition.hex_orientation),
		"hexes": hexes,
		"sites": sites,
		"road_edges": _edges_to_array(definition.all_road_edges()),
		"border_edges": _edges_to_array(definition.all_border_edges()),
		"subregions": definition.subregions_by_id.duplicate(true),
		"aliases": _string_name_array_to_strings(definition.aliases),
		"site_aliases": definition.site_aliases.duplicate(true),
		"main_settlement_site_id": String(definition.main_settlement_site_id),
		"fifth_god_ruin_site_id": String(definition.fifth_god_ruin_site_id),
		"military_site_id": String(definition.military_site_id),
		"religious_site_ids": _string_name_array_to_strings(definition.religious_site_ids),
		"mission_site_ids": _string_name_array_to_strings(definition.mission_site_ids),
	}


static func _region_from_dictionary(data: Dictionary) -> RegionMapDefinition:
	var definition := RegionMapDefinition.new()
	definition.id = StringName(data.get("id", ""))
	definition.display_name = String(data.get("display_name", ""))
	definition.width = int(data.get("width", 0))
	definition.height = int(data.get("height", 0))
	definition.hex_orientation = StringName(data.get("hex_orientation", "flat_top_even_q"))
	definition.subregions_by_id = (data.get("subregions", {}) as Dictionary).duplicate(true)
	definition.aliases = _to_string_name_array(data.get("aliases", []))
	definition.site_aliases = (data.get("site_aliases", {}) as Dictionary).duplicate(true)
	definition.main_settlement_site_id = StringName(data.get("main_settlement_site_id", ""))
	definition.fifth_god_ruin_site_id = StringName(data.get("fifth_god_ruin_site_id", ""))
	definition.military_site_id = StringName(data.get("military_site_id", ""))
	definition.religious_site_ids = _to_string_name_array(data.get("religious_site_ids", []))
	definition.mission_site_ids = _to_string_name_array(data.get("mission_site_ids", []))
	for raw_hex: Variant in data.get("hexes", []):
		if not (raw_hex is Dictionary):
			continue
		var entry: Dictionary = raw_hex as Dictionary
		var hex := RegionHexDefinition.new()
		hex.coord = _coord_from_pair(entry.get("coord", []))
		hex.playable = bool(entry.get("playable", true))
		hex.terrain_type = StringName(entry.get("terrain_type", RegionTerrainType.GRASSLAND))
		hex.subregion_id = StringName(entry.get("subregion_id", ""))
		hex.site_id = StringName(entry.get("site_id", ""))
		hex.visual_variant = int(entry.get("visual_variant", 0))
		definition.add_hex(hex)
	for raw_site: Variant in data.get("sites", []):
		if not (raw_site is Dictionary):
			continue
		var entry: Dictionary = raw_site as Dictionary
		var site := RegionSiteDefinition.new()
		site.id = StringName(entry.get("id", ""))
		site.display_name = String(entry.get("display_name", ""))
		site.site_type = StringName(entry.get("site_type", ""))
		site.coord = _coord_from_pair(entry.get("coord", []))
		for raw_coord: Variant in entry.get("footprint", []):
			var coord: RegionHexCoord = _coord_from_pair(raw_coord)
			if coord != null:
				site.footprint.append(coord)
		site.parent_settlement_id = StringName(entry.get("parent_settlement_id", ""))
		site.subregion_id = StringName(entry.get("subregion_id", ""))
		site.description = String(entry.get("description", ""))
		site.tags = _to_string_name_array(entry.get("tags", []))
		site.icon_id = StringName(entry.get("icon_id", ""))
		site.mission_definition_ids = _to_string_name_array(entry.get("mission_definition_ids", []))
		site.inspectable = bool(entry.get("inspectable", true))
		site.label_priority = int(entry.get("label_priority", 0))
		site.aliases = _to_string_name_array(entry.get("aliases", []))
		definition.add_site(site)
	_load_edges(definition, data.get("road_edges", []), true)
	_load_edges(definition, data.get("border_edges", []), false)
	return definition


static func _edges_to_array(edges: Array[RegionMapEdgeDefinition]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for edge: RegionMapEdgeDefinition in edges:
		result.append({
			"id": String(edge.id),
			"coord": [edge.coord.offset_col, edge.coord.offset_row] if edge.coord != null else [],
			"neighbour_coord": [edge.neighbour_coord.offset_col, edge.neighbour_coord.offset_row] if edge.neighbour_coord != null else [],
			"edge_index": edge.edge_index,
			"edge_type": String(edge.edge_type),
			"style_id": String(edge.style_id),
		})
	return result


static func _load_edges(definition: RegionMapDefinition, raw_edges: Variant, is_road: bool) -> void:
	if not (raw_edges is Array):
		return
	var edge_entries: Array = raw_edges as Array
	for raw_edge: Variant in edge_entries:
		if not (raw_edge is Dictionary):
			continue
		var entry: Dictionary = raw_edge as Dictionary
		var edge := RegionMapEdgeDefinition.new()
		edge.id = StringName(entry.get("id", ""))
		edge.coord = _coord_from_pair(entry.get("coord", []))
		edge.neighbour_coord = _coord_from_pair(entry.get("neighbour_coord", []))
		edge.edge_index = int(entry.get("edge_index", -1))
		edge.edge_type = RegionMapEdgeDefinition.ROAD if is_road else RegionMapEdgeDefinition.BORDER
		edge.style_id = RegionRoadType.normalize(StringName(entry.get("style_id", RegionRoadType.LOCAL_ROAD))) if is_road else StringName(entry.get("style_id", "subregion_border"))
		edge.visual_variant = int(entry.get("visual_variant", 0))
		if is_road:
			definition.add_road_edge(edge)
		else:
			definition.add_border_edge(edge)


static func _coord_from_pair(raw_value: Variant) -> RegionHexCoord:
	if not (raw_value is Array):
		return null
	var pair: Array = raw_value as Array
	if pair.size() < 2:
		return null
	return RegionHexCoord.from_offset(int(pair[0]), int(pair[1]))


static func _to_string_name_array(raw_value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not (raw_value is Array):
		return result
	var entries: Array = raw_value as Array
	for raw_entry: Variant in entries:
		var entry := StringName(raw_entry)
		if not entry.is_empty():
			result.append(entry)
	return result


static func _string_name_array_to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _footprint_contains(footprint: Array[RegionHexCoord], column: int, row: int) -> bool:
	for coord: RegionHexCoord in footprint:
		if coord.offset_col == column and coord.offset_row == row:
			return true
	return false


static func _remove_coord(footprint: Array[RegionHexCoord], column: int, row: int) -> void:
	for index: int in range(footprint.size() - 1, -1, -1):
		var coord: RegionHexCoord = footprint[index]
		if coord.offset_col == column and coord.offset_row == row:
			footprint.remove_at(index)


static func _canonical_edge_key(first: RegionHexCoord, second: RegionHexCoord, edge_index: int = -1) -> StringName:
	if first == null:
		return &""
	if second == null:
		return StringName("%d,%d:e%d" % [first.offset_col, first.offset_row, edge_index])
	var a: String = "%d,%d" % [first.offset_col, first.offset_row]
	var b: String = "%d,%d" % [second.offset_col, second.offset_row]
	if b < a:
		var swap: String = a
		a = b
		b = swap
	return StringName("%s|%s" % [a, b])
