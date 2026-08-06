class_name SquadRoutePlan
extends RefCounted

var route_id: StringName = &""
var mission_instance_id: StringName = &""
var origin_hex: RegionHexCoord
var destination_hex: RegionHexCoord
var waypoint_hexes: Array[RegionHexCoord] = []
var route_points: Array[Vector2] = []
var cumulative_minutes: Array[float] = []
var start_tick: int = 0
var arrival_tick: int = 0
var fastest_route_minutes: float = 0.0


func total_minutes() -> float:
	return cumulative_minutes[-1] if not cumulative_minutes.is_empty() else 0.0


func progress_at_time(campaign_time: float) -> float:
	var duration: float = maxf(1.0, float(arrival_tick - start_tick))
	return clampf((campaign_time - float(start_tick)) / duration, 0.0, 1.0)


func map_position_at_time(campaign_time: float) -> Vector2:
	if route_points.is_empty():
		return Vector2.ZERO
	if route_points.size() == 1 or cumulative_minutes.size() != route_points.size():
		return route_points[-1]
	var elapsed: float = clampf(campaign_time - float(start_tick), 0.0, total_minutes())
	for index: int in range(1, cumulative_minutes.size()):
		if elapsed > cumulative_minutes[index]:
			continue
		var segment_start: float = cumulative_minutes[index - 1]
		var span: float = maxf(0.001, cumulative_minutes[index] - segment_start)
		return route_points[index - 1].lerp(
			route_points[index],
			clampf((elapsed - segment_start) / span, 0.0, 1.0)
		)
	return route_points[-1]


func direction_at_time(campaign_time: float) -> Vector2:
	if route_points.size() < 2 or cumulative_minutes.size() != route_points.size():
		return Vector2.RIGHT
	var elapsed: float = clampf(campaign_time - float(start_tick), 0.0, total_minutes())
	for index: int in range(1, cumulative_minutes.size()):
		if elapsed <= cumulative_minutes[index]:
			var direction: Vector2 = route_points[index] - route_points[index - 1]
			return direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	var final_direction: Vector2 = route_points[-1] - route_points[-2]
	return final_direction.normalized() if final_direction.length_squared() > 0.0001 else Vector2.RIGHT


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if route_id.is_empty():
		errors.append("Squad route has no ID.")
	if mission_instance_id.is_empty():
		errors.append("Squad route %s has no mission." % route_id)
	if origin_hex == null or destination_hex == null:
		errors.append("Squad route %s has incomplete endpoints." % route_id)
	if route_points.size() < 2 or cumulative_minutes.size() != route_points.size():
		errors.append("Squad route %s has invalid path geometry." % route_id)
	var previous: float = -1.0
	for value: float in cumulative_minutes:
		if value < previous:
			errors.append("Squad route %s has non-monotonic timing." % route_id)
			break
		previous = value
	if start_tick < 0 or arrival_tick < start_tick:
		errors.append("Squad route %s has invalid campaign timing." % route_id)
	return errors


func to_dictionary() -> Dictionary:
	var serialized_points: Array = []
	for point: Vector2 in route_points:
		serialized_points.append([point.x, point.y])
	var serialized_waypoints: Array = []
	for coord: RegionHexCoord in waypoint_hexes:
		serialized_waypoints.append(_coord_pair(coord))
	return {
		"route_id": String(route_id),
		"mission_instance_id": String(mission_instance_id),
		"origin_hex": _coord_pair(origin_hex),
		"destination_hex": _coord_pair(destination_hex),
		"waypoint_hexes": serialized_waypoints,
		"route_points": serialized_points,
		"cumulative_minutes": cumulative_minutes.duplicate(),
		"start_tick": start_tick,
		"arrival_tick": arrival_tick,
		"fastest_route_minutes": fastest_route_minutes,
	}


static func from_dictionary(data: Dictionary) -> SquadRoutePlan:
	var result := SquadRoutePlan.new()
	result.route_id = StringName(data.get("route_id", ""))
	result.mission_instance_id = StringName(data.get("mission_instance_id", ""))
	result.origin_hex = _coord_from_pair(data.get("origin_hex", []))
	result.destination_hex = _coord_from_pair(data.get("destination_hex", []))
	var raw_waypoints: Variant = data.get("waypoint_hexes", [])
	if raw_waypoints is Array:
		for raw_coord: Variant in raw_waypoints as Array:
			var coord: RegionHexCoord = _coord_from_pair(raw_coord)
			if coord != null:
				result.waypoint_hexes.append(coord)
	var raw_points: Variant = data.get("route_points", [])
	if raw_points is Array:
		for raw_point: Variant in raw_points as Array:
			if raw_point is Array and (raw_point as Array).size() >= 2:
				result.route_points.append(Vector2(float((raw_point as Array)[0]), float((raw_point as Array)[1])))
	var raw_minutes: Variant = data.get("cumulative_minutes", [])
	if raw_minutes is Array:
		for raw_value: Variant in raw_minutes as Array:
			result.cumulative_minutes.append(maxf(0.0, float(raw_value)))
	result.start_tick = maxi(0, int(data.get("start_tick", 0)))
	result.arrival_tick = maxi(result.start_tick, int(data.get("arrival_tick", result.start_tick)))
	result.fastest_route_minutes = maxf(0.0, float(data.get("fastest_route_minutes", 0.0)))
	return result


static func _coord_pair(coord: RegionHexCoord) -> Array[int]:
	return [coord.offset_col, coord.offset_row] if coord != null else []


static func _coord_from_pair(raw_value: Variant) -> RegionHexCoord:
	if not raw_value is Array:
		return null
	var pair: Array = raw_value as Array
	if pair.size() < 2:
		return null
	return RegionHexCoord.from_offset(int(pair[0]), int(pair[1]))
