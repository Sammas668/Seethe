class_name RegionMapDefinition
extends RefCounted

var id: StringName = &""
var display_name: String = ""
var width: int = 0
var height: int = 0
var hex_orientation: StringName = &"flat_top_even_q"
var hexes_by_key: Dictionary = {}
var sites_by_id: Dictionary = {}
var road_edges_by_id: Dictionary = {}
var border_edges_by_id: Dictionary = {}
var subregions_by_id: Dictionary = {}
var aliases: Array[StringName] = []
var site_aliases: Dictionary = {}
var main_settlement_site_id: StringName = &""
var fifth_god_ruin_site_id: StringName = &""
var military_site_id: StringName = &""
var religious_site_ids: Array[StringName] = []
var mission_site_ids: Array[StringName] = []
var label_offsets_by_site_id: Dictionary = {}


func label_offset_for_site(site_id: StringName, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var value: Variant = label_offsets_by_site_id.get(site_id, fallback)
	return value if value is Vector2 else fallback


func add_hex(definition: RegionHexDefinition) -> bool:
	if definition == null or definition.coord == null:
		return false
	var key: StringName = definition.coord.key()
	if hexes_by_key.has(key):
		return false
	hexes_by_key[key] = definition
	return true


func add_site(definition: RegionSiteDefinition) -> bool:
	if definition == null or definition.id.is_empty() or sites_by_id.has(definition.id):
		return false
	sites_by_id[definition.id] = definition
	for alias_id: StringName in definition.aliases:
		if not alias_id.is_empty() and not site_aliases.has(alias_id):
			site_aliases[alias_id] = definition.id
	return true


func add_road_edge(definition: RegionMapEdgeDefinition) -> bool:
	if definition == null or definition.id.is_empty() or road_edges_by_id.has(definition.id):
		return false
	definition.edge_type = RegionMapEdgeDefinition.ROAD
	definition.style_id = RegionRoadType.normalize(definition.style_id)
	road_edges_by_id[definition.id] = definition
	return true


func add_border_edge(definition: RegionMapEdgeDefinition) -> bool:
	if definition == null or definition.id.is_empty() or border_edges_by_id.has(definition.id):
		return false
	definition.edge_type = RegionMapEdgeDefinition.BORDER
	border_edges_by_id[definition.id] = definition
	return true


func hex_at_offset(column: int, row: int) -> RegionHexDefinition:
	return hexes_by_key.get(StringName("%d,%d" % [column, row])) as RegionHexDefinition


func site(site_id: StringName) -> RegionSiteDefinition:
	var canonical_id: StringName = StringName(site_aliases.get(site_id, site_id))
	return sites_by_id.get(canonical_id) as RegionSiteDefinition


func all_hexes() -> Array[RegionHexDefinition]:
	var result: Array[RegionHexDefinition] = []
	for row: int in range(height):
		for column: int in range(width):
			var definition: RegionHexDefinition = hex_at_offset(column, row)
			if definition != null:
				result.append(definition)
	return result


func all_sites() -> Array[RegionSiteDefinition]:
	var result: Array[RegionSiteDefinition] = []
	for raw_site: Variant in sites_by_id.values():
		var definition: RegionSiteDefinition = raw_site as RegionSiteDefinition
		if definition != null:
			result.append(definition)
	result.sort_custom(
		func(a: RegionSiteDefinition, b: RegionSiteDefinition) -> bool:
			if a.label_priority != b.label_priority:
				return a.label_priority > b.label_priority
			return String(a.id) < String(b.id)
	)
	return result


func all_road_edges() -> Array[RegionMapEdgeDefinition]:
	return _sorted_edges(road_edges_by_id)


func all_border_edges() -> Array[RegionMapEdgeDefinition]:
	return _sorted_edges(border_edges_by_id)


func _sorted_edges(source: Dictionary) -> Array[RegionMapEdgeDefinition]:
	var result: Array[RegionMapEdgeDefinition] = []
	for raw_edge: Variant in source.values():
		var definition: RegionMapEdgeDefinition = raw_edge as RegionMapEdgeDefinition
		if definition != null:
			result.append(definition)
	result.sort_custom(
		func(a: RegionMapEdgeDefinition, b: RegionMapEdgeDefinition) -> bool:
			return String(a.id) < String(b.id)
	)
	return result


func sites_at_offset(column: int, row: int) -> Array[RegionSiteDefinition]:
	var result: Array[RegionSiteDefinition] = []
	for definition: RegionSiteDefinition in all_sites():
		if definition.contains_offset(column, row):
			result.append(definition)
	return result


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Region definition has no ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Region %s has no display name." % id)
	if width != 20 or height != 15:
		errors.append("Starter region %s must remain 20 by 15 hexes." % id)
	if hexes_by_key.size() != width * height:
		errors.append("Region %s has %d hexes; expected %d." % [id, hexes_by_key.size(), width * height])
	for definition: RegionHexDefinition in all_hexes():
		errors.append_array(definition.validate_definition())
		if definition.coord.offset_col < 0 or definition.coord.offset_col >= width:
			errors.append("Region hex %s is outside the authored width." % definition.coord.key())
		if definition.coord.offset_row < 0 or definition.coord.offset_row >= height:
			errors.append("Region hex %s is outside the authored height." % definition.coord.key())
		if not subregions_by_id.has(definition.subregion_id):
			errors.append("Region hex %s references unknown subregion %s." % [definition.coord.key(), definition.subregion_id])
	for definition: RegionSiteDefinition in all_sites():
		errors.append_array(definition.validate_definition())
		if definition.coord != null and hex_at_offset(definition.coord.offset_col, definition.coord.offset_row) == null:
			errors.append("Region site %s is outside the playable map." % definition.id)
		for footprint_coord: RegionHexCoord in definition.footprint:
			if footprint_coord == null or hex_at_offset(footprint_coord.offset_col, footprint_coord.offset_row) == null:
				errors.append("Region site %s has a footprint hex outside the playable map." % definition.id)
		if not subregions_by_id.has(definition.subregion_id):
			errors.append("Region site %s references unknown subregion %s." % [definition.id, definition.subregion_id])
		if not definition.parent_settlement_id.is_empty() and site(definition.parent_settlement_id) == null:
			errors.append("Region site %s references missing parent settlement %s." % [definition.id, definition.parent_settlement_id])
	var road_keys: Dictionary = {}
	for edge_definition: RegionMapEdgeDefinition in all_road_edges():
		errors.append_array(_validate_map_edge(edge_definition))
		if edge_definition.style_id not in RegionRoadType.ALL:
			errors.append("Road edge %s has invalid road type %s." % [edge_definition.id, edge_definition.style_id])
		var road_key: StringName = edge_definition.canonical_key()
		if road_keys.has(road_key):
			errors.append("Duplicate authored road edge %s." % road_key)
		road_keys[road_key] = true
	var border_keys: Dictionary = {}
	for edge_definition: RegionMapEdgeDefinition in all_border_edges():
		errors.append_array(_validate_map_edge(edge_definition))
		var border_key: StringName = edge_definition.canonical_key()
		if border_keys.has(border_key):
			errors.append("Duplicate authored subregion border edge %s." % border_key)
		border_keys[border_key] = true
	for required_site_id: StringName in [main_settlement_site_id, fifth_god_ruin_site_id, military_site_id]:
		if site(required_site_id) == null:
			errors.append("Region %s references missing required site %s." % [id, required_site_id])
	return errors


func _validate_map_edge(definition: RegionMapEdgeDefinition) -> Array[String]:
	var errors: Array[String] = []
	if definition == null:
		errors.append("Region contains a null map edge definition.")
		return errors
	errors.append_array(definition.validate_definition())
	if definition.coord != null and hex_at_offset(
		definition.coord.offset_col,
		definition.coord.offset_row
	) == null:
		errors.append("Region map edge %s starts outside the playable map." % definition.id)
	if definition.neighbour_coord != null and hex_at_offset(
		definition.neighbour_coord.offset_col,
		definition.neighbour_coord.offset_row
	) == null:
		errors.append("Region map edge %s ends outside the playable map." % definition.id)
	return errors
