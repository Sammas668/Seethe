class_name AgentTravelPlan
extends RefCounted

var plan_id: StringName = &""
var agent_id: StringName = &""
var origin_hex: RegionHexCoord
var destination_hex: RegionHexCoord
var route_points: Array[Vector2] = []
var cumulative_minutes: Array[float] = []
var start_tick: int = 0
var arrival_tick: int = 0
var discovery_seed: int = 0


func total_minutes() -> float:
	return cumulative_minutes[-1] if not cumulative_minutes.is_empty() else 0.0


func progress_at_tick(campaign_tick: int) -> float:
	return progress_at_time(float(campaign_tick))


func progress_at_time(campaign_time: float) -> float:
	var duration: float = maxf(1.0, float(arrival_tick - start_tick))
	return clampf((campaign_time - float(start_tick)) / duration, 0.0, 1.0)


func map_position_at_tick(campaign_tick: int) -> Vector2:
	return map_position_at_time(float(campaign_tick))


func map_position_at_time(campaign_time: float) -> Vector2:
	if route_points.is_empty():
		return Vector2.ZERO
	if route_points.size() == 1 or cumulative_minutes.size() != route_points.size():
		return route_points[-1]
	var elapsed: float = clampf(
		campaign_time - float(start_tick),
		0.0,
		total_minutes()
	)
	for index: int in range(1, cumulative_minutes.size()):
		var segment_end: float = cumulative_minutes[index]
		if elapsed > segment_end:
			continue
		var segment_start: float = cumulative_minutes[index - 1]
		var span: float = maxf(0.001, segment_end - segment_start)
		var weight: float = clampf((elapsed - segment_start) / span, 0.0, 1.0)
		return route_points[index - 1].lerp(route_points[index], weight)
	return route_points[-1]


func direction_at_tick(campaign_tick: int) -> Vector2:
	return direction_at_time(float(campaign_tick))


func direction_at_time(campaign_time: float) -> Vector2:
	if route_points.size() < 2 or cumulative_minutes.size() != route_points.size():
		return Vector2.RIGHT
	var elapsed: float = clampf(
		campaign_time - float(start_tick),
		0.0,
		total_minutes()
	)
	for index: int in range(1, cumulative_minutes.size()):
		if elapsed <= cumulative_minutes[index]:
			var direction: Vector2 = route_points[index] - route_points[index - 1]
			return direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	var final_direction: Vector2 = route_points[-1] - route_points[-2]
	return final_direction.normalized() if final_direction.length_squared() > 0.0001 else Vector2.RIGHT


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if plan_id.is_empty():
		errors.append("Agent travel plan has no ID.")
	if agent_id.is_empty():
		errors.append("Agent travel plan %s has no Agent ID." % plan_id)
	if origin_hex == null or destination_hex == null:
		errors.append("Agent travel plan %s has incomplete endpoints." % plan_id)
	if route_points.size() < 2:
		errors.append("Agent travel plan %s has no traversable route." % plan_id)
	if cumulative_minutes.size() != route_points.size():
		errors.append("Agent travel plan %s has inconsistent route timing." % plan_id)
	elif not cumulative_minutes.is_empty():
		var previous: float = -1.0
		for value: float in cumulative_minutes:
			if value < previous:
				errors.append("Agent travel plan %s has non-monotonic timing." % plan_id)
				break
			previous = value
	if start_tick < 0 or arrival_tick < start_tick:
		errors.append("Agent travel plan %s has invalid campaign timing." % plan_id)
	return errors


func to_dictionary() -> Dictionary:
	var serialized_points: Array = []
	for point: Vector2 in route_points:
		serialized_points.append([point.x, point.y])
	return {
		"plan_id": String(plan_id),
		"agent_id": String(agent_id),
		"origin_hex": _coord_pair(origin_hex),
		"destination_hex": _coord_pair(destination_hex),
		"route_points": serialized_points,
		"cumulative_minutes": cumulative_minutes.duplicate(),
		"start_tick": start_tick,
		"arrival_tick": arrival_tick,
		"discovery_seed": discovery_seed,
	}


static func from_dictionary(data: Dictionary) -> AgentTravelPlan:
	var result := AgentTravelPlan.new()
	result.plan_id = StringName(data.get("plan_id", ""))
	result.agent_id = StringName(data.get("agent_id", ""))
	result.origin_hex = _coord_from_pair(data.get("origin_hex", []))
	result.destination_hex = _coord_from_pair(data.get("destination_hex", []))
	var raw_points: Variant = data.get("route_points", [])
	if raw_points is Array:
		for raw_point: Variant in raw_points as Array:
			if raw_point is Array and (raw_point as Array).size() >= 2:
				result.route_points.append(Vector2(
					float((raw_point as Array)[0]),
					float((raw_point as Array)[1])
				))
	var raw_minutes: Variant = data.get("cumulative_minutes", [])
	if raw_minutes is Array:
		for raw_value: Variant in raw_minutes as Array:
			result.cumulative_minutes.append(maxf(0.0, float(raw_value)))
	result.start_tick = maxi(0, int(data.get("start_tick", 0)))
	result.arrival_tick = maxi(result.start_tick, int(data.get("arrival_tick", result.start_tick)))
	result.discovery_seed = int(data.get("discovery_seed", 0))
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
