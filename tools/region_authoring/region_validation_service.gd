class_name RegionValidationService
extends RefCounted

const ERROR: StringName = &"error"
const WARNING: StringName = &"warning"
const INFORMATION: StringName = &"information"


static func validate(document: RegionAuthoringDocument) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	if document == null or document.region == null:
		messages.append(_message(ERROR, "No region authoring document is loaded."))
		return messages
	var region: RegionMapDefinition = document.region
	for error_text: String in region.validate_definition():
		messages.append(_message(ERROR, error_text))
	_validate_settlements(region, messages)
	_validate_sites(region, messages)
	_validate_edges(region, messages)
	_validate_labels(document, messages)
	if messages.is_empty():
		messages.append(_message(INFORMATION, "The region passed all authoring validation checks."))
	return messages


static func has_errors(messages: Array[Dictionary]) -> bool:
	for message: Dictionary in messages:
		if StringName(message.get("severity", "")) == ERROR:
			return true
	return false


static func _validate_settlements(region: RegionMapDefinition, messages: Array[Dictionary]) -> void:
	var occupied: Dictionary = {}
	for settlement: RegionSiteDefinition in region.all_sites():
		if settlement.site_type != &"settlement":
			continue
		if settlement.footprint.is_empty():
			messages.append(_message(ERROR, "Settlement %s has no occupied hexes." % settlement.display_name, &"site", settlement.id))
			continue
		for coord: RegionHexCoord in settlement.footprint:
			var key: StringName = coord.key()
			if occupied.has(key):
				messages.append(_message(
					ERROR,
					"Settlement %s overlaps settlement %s at %s." % [settlement.display_name, occupied[key], key],
					&"hex",
					key,
					coord
				))
			else:
				occupied[key] = settlement.display_name
		if not _is_contiguous(settlement.footprint):
			messages.append(_message(WARNING, "Settlement %s has a disconnected footprint." % settlement.display_name, &"site", settlement.id))
	for district: RegionSiteDefinition in region.all_sites():
		if district.site_type != &"district":
			continue
		var parent: RegionSiteDefinition = region.site(district.parent_settlement_id)
		if parent == null or parent.site_type != &"settlement":
			messages.append(_message(ERROR, "District %s has no valid parent settlement." % district.display_name, &"site", district.id))
			continue
		if district.coord == null or not parent.contains_offset(district.coord.offset_col, district.coord.offset_row):
			messages.append(_message(ERROR, "District %s is outside %s's footprint." % [district.display_name, parent.display_name], &"site", district.id, district.coord))
		if not RegionSymbolCatalogue.is_valid(district.icon_id):
			messages.append(_message(ERROR, "District %s uses unknown symbol %s." % [district.display_name, district.icon_id], &"site", district.id, district.coord))


static func _validate_sites(region: RegionMapDefinition, messages: Array[Dictionary]) -> void:
	var stronghold: RegionSiteDefinition = region.site(region.fifth_god_ruin_site_id)
	if stronghold != null and stronghold.coord != null:
		var hex: RegionHexDefinition = region.hex_at_offset(stronghold.coord.offset_col, stronghold.coord.offset_row)
		if hex == null or hex.terrain_type != RegionTerrainType.DEEP_FOREST:
			messages.append(_message(ERROR, "The Fifth-God stronghold must occupy Deep Forest terrain.", &"site", stronghold.id, stronghold.coord))
		for edge: RegionMapEdgeDefinition in region.all_road_edges():
			if edge.touches_offset(stronghold.coord.offset_col, stronghold.coord.offset_row):
				messages.append(_message(ERROR, "A public road touches the concealed Fifth-God stronghold.", &"edge", edge.id, stronghold.coord))
	var ruin_count: int = 0
	for site: RegionSiteDefinition in region.all_sites():
		if site.site_type == &"ruin":
			ruin_count += 1
	if ruin_count < 1:
		messages.append(_message(ERROR, "The region needs a separate ancient forest ruin in addition to the stronghold."))
	if stronghold != null:
		for site: RegionSiteDefinition in region.all_sites():
			if site.site_type == &"ruin" and site.coord != null and stronghold.coord != null and site.coord.key() == stronghold.coord.key():
				messages.append(_message(ERROR, "The ancient ruin and the Fifth-God stronghold occupy the same hex.", &"site", site.id, site.coord))


static func _validate_edges(region: RegionMapDefinition, messages: Array[Dictionary]) -> void:
	for edge: RegionMapEdgeDefinition in region.all_border_edges():
		if edge.coord == null or edge.neighbour_coord == null:
			continue
		var first: RegionHexDefinition = region.hex_at_offset(edge.coord.offset_col, edge.coord.offset_row)
		var second: RegionHexDefinition = region.hex_at_offset(edge.neighbour_coord.offset_col, edge.neighbour_coord.offset_row)
		if first != null and second != null and first.subregion_id == second.subregion_id:
			messages.append(_message(WARNING, "Border %s separates two hexes assigned to the same subregion." % edge.id, &"edge", edge.id, edge.coord))


static func _validate_labels(document: RegionAuthoringDocument, messages: Array[Dictionary]) -> void:
	for raw_id: Variant in document.label_offsets_by_site_id.keys():
		var site_id := StringName(raw_id)
		if document.region.site(site_id) == null:
			messages.append(_message(WARNING, "Label override references missing site %s." % site_id, &"site", site_id))


static func _is_contiguous(footprint: Array[RegionHexCoord]) -> bool:
	if footprint.size() <= 1:
		return true
	var by_key: Dictionary = {}
	for coord: RegionHexCoord in footprint:
		by_key[coord.key()] = coord
	var open: Array[RegionHexCoord] = [footprint[0]]
	var visited: Dictionary = {}
	while not open.is_empty():
		var current: RegionHexCoord = open.pop_back()
		if visited.has(current.key()):
			continue
		visited[current.key()] = true
		for neighbour: RegionHexCoord in current.neighbours():
			if by_key.has(neighbour.key()) and not visited.has(neighbour.key()):
				open.append(by_key[neighbour.key()] as RegionHexCoord)
	return visited.size() == footprint.size()


static func _message(
	severity: StringName,
	text: String,
	target_kind: StringName = &"",
	target_id: StringName = &"",
	coord: RegionHexCoord = null
) -> Dictionary:
	return {
		"severity": String(severity),
		"message": text,
		"target_kind": String(target_kind),
		"target_id": String(target_id),
		"coord": [coord.offset_col, coord.offset_row] if coord != null else [],
	}
