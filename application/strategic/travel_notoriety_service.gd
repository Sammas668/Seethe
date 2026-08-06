class_name TravelNotorietyService
extends RefCounted

const CATEGORY_DEEP_WILDERNESS: StringName = &"deep_wilderness"
const CATEGORY_FOREST_OFF_ROAD: StringName = &"forest_off_road"
const CATEGORY_REMOTE_TRACK: StringName = &"remote_track"
const CATEGORY_OPEN_FARMLAND: StringName = &"open_farmland"
const CATEGORY_LOCAL_ROAD: StringName = &"local_road"
const CATEGORY_PRIMARY_ROAD: StringName = &"primary_road"
const CATEGORY_VILLAGE_OUTSKIRTS: StringName = &"village_outskirts"
const CATEGORY_OCCUPIED_VILLAGE: StringName = &"occupied_village"
const CATEGORY_MAJOR_TOWN_DISTRICT: StringName = &"major_town_district"
const CATEGORY_REGIONAL_CAPITAL_DISTRICT: StringName = &"regional_capital_district"

const EXPOSURE_BY_CATEGORY: Dictionary = {
	CATEGORY_DEEP_WILDERNESS: 0,
	CATEGORY_FOREST_OFF_ROAD: 0,
	CATEGORY_REMOTE_TRACK: 1,
	CATEGORY_OPEN_FARMLAND: 1,
	CATEGORY_LOCAL_ROAD: 1,
	CATEGORY_PRIMARY_ROAD: 2,
	CATEGORY_VILLAGE_OUTSKIRTS: 2,
	CATEGORY_OCCUPIED_VILLAGE: 3,
	CATEGORY_MAJOR_TOWN_DISTRICT: 5,
	CATEGORY_REGIONAL_CAPITAL_DISTRICT: 6,
}


func build_exposure_entries(
	region: RegionMapDefinition,
	route: SquadRoutePlan,
	visibility: SquadVisibilitySnapshot,
	operation_id: StringName
) -> Array[TravelExposureEntry]:
	var started_usec: int = RuntimeStallAttribution.begin()
	var result: Array[TravelExposureEntry] = []
	if region == null or route == null or visibility == null:
		RuntimeStallAttribution.end(&"travel_exposure_planning", started_usec, "missing_input")
		return result
	var road_type_by_segment: Dictionary = _road_type_by_segment(region)
	var segments: Array[Dictionary] = []
	for index: int in range(1, route.route_points.size()):
		var first: Vector2 = route.route_points[index - 1]
		var second: Vector2 = route.route_points[index]
		if first.distance_squared_to(second) < 0.000001:
			continue
		var midpoint: Vector2 = first.lerp(second, 0.5)
		var nearest_hex: RegionHexDefinition = _nearest_hex(region, midpoint)
		if nearest_hex == null or nearest_hex.coord == null:
			continue
		var road_type: StringName = StringName(
			road_type_by_segment.get(_segment_key(first, second), &"")
		)
		var category: StringName = _category_for_segment(region, nearest_hex, road_type)
		var start_minutes: float = route.cumulative_minutes[index - 1]
		var end_minutes: float = route.cumulative_minutes[index]
		segments.append({
			"subregion_id": nearest_hex.subregion_id,
			"category": category,
			"start_minutes": start_minutes,
			"end_minutes": end_minutes,
		})
	var grouped: Array[Dictionary] = []
	for segment: Dictionary in segments:
		if grouped.is_empty():
			grouped.append(_new_group(segment))
			continue
		var current: Dictionary = grouped[-1]
		if (
			StringName(current.get("subregion_id", ""))
			== StringName(segment.get("subregion_id", ""))
			and StringName(current.get("category", ""))
			== StringName(segment.get("category", ""))
		):
			current["segment_count"] = int(current.get("segment_count", 0)) + 1
			current["end_minutes"] = float(segment.get("end_minutes", 0.0))
			grouped[-1] = current
		else:
			grouped.append(_new_group(segment))
	var entry_index: int = 0
	for group: Dictionary in grouped:
		var category := StringName(group.get("category", CATEGORY_DEEP_WILDERNESS))
		var per_unit: int = int(EXPOSURE_BY_CATEGORY.get(category, 0))
		if per_unit <= 0:
			continue
		var quantity: int = maxi(1, ceili(float(int(group.get("segment_count", 1))) / 3.0))
		var base_subtotal: int = quantity * per_unit
		var adjusted: int = ceili(float(base_subtotal) * visibility.travel_multiplier)
		var entry := TravelExposureEntry.new()
		entry.entry_id = StringName("%s.exposure.%03d" % [operation_id, entry_index])
		entry.subregion_id = StringName(group.get("subregion_id", ""))
		entry.start_route_minutes = float(group.get("start_minutes", 0.0))
		entry.end_route_minutes = float(group.get("end_minutes", 0.0))
		entry.completion_tick = route.start_tick + ceili(entry.end_route_minutes)
		entry.geographic_category = category
		entry.quantity = quantity
		entry.value_per_unit = per_unit
		entry.base_subtotal = base_subtotal
		entry.visibility_category = visibility.category
		entry.visibility_multiplier = visibility.travel_multiplier
		entry.applied_subtotal = adjusted
		entry.report_text = "%s ×%d" % [_category_display_name(category), quantity]
		result.append(entry)
		entry_index += 1
	RuntimeStallAttribution.end(&"travel_exposure_planning", started_usec, "entries=%d" % result.size())
	return result


func projected_total(entries: Array[TravelExposureEntry]) -> int:
	var total: int = 0
	for entry: TravelExposureEntry in entries:
		if entry != null:
			total += entry.applied_subtotal
	return total


func projected_by_subregion(entries: Array[TravelExposureEntry]) -> Dictionary:
	var result: Dictionary = {}
	for entry: TravelExposureEntry in entries:
		if entry == null:
			continue
		result[entry.subregion_id] = int(result.get(entry.subregion_id, 0)) + entry.applied_subtotal
	return result


func _new_group(segment: Dictionary) -> Dictionary:
	return {
		"subregion_id": segment.get("subregion_id", &""),
		"category": segment.get("category", CATEGORY_DEEP_WILDERNESS),
		"start_minutes": segment.get("start_minutes", 0.0),
		"end_minutes": segment.get("end_minutes", 0.0),
		"segment_count": 1,
	}


func _category_for_segment(
	region: RegionMapDefinition,
	hex: RegionHexDefinition,
	road_type: StringName
) -> StringName:
	var capital: RegionSiteDefinition = region.site(region.main_settlement_site_id)
	if capital != null and capital.contains_offset(hex.coord.offset_col, hex.coord.offset_row):
		return CATEGORY_REGIONAL_CAPITAL_DISTRICT
	var settlement: RegionSiteDefinition = _settlement_at(region, hex.coord)
	if settlement != null:
		if settlement.footprint.size() > 1:
			return CATEGORY_MAJOR_TOWN_DISTRICT
		return CATEGORY_OCCUPIED_VILLAGE
	if _is_adjacent_to_settlement(region, hex.coord):
		return CATEGORY_VILLAGE_OUTSKIRTS
	match RegionRoadType.normalize(road_type):
		RegionRoadType.PRIMARY_ROAD:
			return CATEGORY_PRIMARY_ROAD
		RegionRoadType.LOCAL_ROAD:
			return CATEGORY_LOCAL_ROAD
		RegionRoadType.FOREST_TRACK:
			return CATEGORY_REMOTE_TRACK
	if hex.terrain_type == RegionTerrainType.FARMLAND:
		return CATEGORY_OPEN_FARMLAND
	if hex.terrain_type in [RegionTerrainType.FOREST, RegionTerrainType.DEEP_FOREST]:
		return CATEGORY_FOREST_OFF_ROAD
	return CATEGORY_DEEP_WILDERNESS


func _settlement_at(region: RegionMapDefinition, coord: RegionHexCoord) -> RegionSiteDefinition:
	for site: RegionSiteDefinition in region.all_sites():
		if site.site_type == &"settlement" and site.contains_offset(coord.offset_col, coord.offset_row):
			return site
	return null


func _is_adjacent_to_settlement(region: RegionMapDefinition, coord: RegionHexCoord) -> bool:
	for site: RegionSiteDefinition in region.all_sites():
		if site.site_type != &"settlement":
			continue
		for occupied: RegionHexCoord in site.footprint:
			if _hex_distance(coord, occupied) == 1:
				return true
	return false


func _nearest_hex(region: RegionMapDefinition, point: Vector2) -> RegionHexDefinition:
	var best: RegionHexDefinition = null
	var best_distance: float = INF
	for hex: RegionHexDefinition in region.all_hexes():
		if not hex.playable or hex.coord == null:
			continue
		var distance: float = RegionBoundaryPathfinder.map_center(hex.coord).distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = hex
	return best


func _road_type_by_segment(region: RegionMapDefinition) -> Dictionary:
	var result: Dictionary = {}
	for edge: RegionMapEdgeDefinition in region.all_road_edges():
		if edge.coord == null or edge.edge_index < 0 or edge.edge_index > 5:
			continue
		var corners: Array[Vector2] = RegionBoundaryPathfinder.hex_corners(edge.coord)
		result[_segment_key(corners[edge.edge_index], corners[(edge.edge_index + 1) % 6])] = RegionRoadType.normalize(edge.style_id)
	return result


func _segment_key(first: Vector2, second: Vector2) -> StringName:
	var a: String = "%d,%d" % [roundi(first.x * 100000.0), roundi(first.y * 100000.0)]
	var b: String = "%d,%d" % [roundi(second.x * 100000.0), roundi(second.y * 100000.0)]
	if b < a:
		var swap: String = a
		a = b
		b = swap
	return StringName("%s|%s" % [a, b])


func _category_display_name(category: StringName) -> String:
	match category:
		CATEGORY_REMOTE_TRACK:
			return "Remote track"
		CATEGORY_OPEN_FARMLAND:
			return "Open farmland"
		CATEGORY_LOCAL_ROAD:
			return "Local road"
		CATEGORY_PRIMARY_ROAD:
			return "Primary road"
		CATEGORY_VILLAGE_OUTSKIRTS:
			return "Village outskirts"
		CATEGORY_OCCUPIED_VILLAGE:
			return "Occupied village"
		CATEGORY_MAJOR_TOWN_DISTRICT:
			return "Major town district"
		CATEGORY_REGIONAL_CAPITAL_DISTRICT:
			return "Regional-capital district"
	return String(category).replace("_", " ").capitalize()


func _hex_distance(first: RegionHexCoord, second: RegionHexCoord) -> int:
	var dq: int = first.q - second.q
	var dr: int = first.r - second.r
	var ds: int = (-first.q - first.r) - (-second.q - second.r)
	return maxi(abs(dq), maxi(abs(dr), abs(ds)))
