class_name RegionBoundaryPathfinder
extends RefCounted

const SQRT_THREE: float = 1.7320508075688772
const QUANTIZE_SCALE: float = 100000.0
const MIN_CONNECTOR_MINUTES: float = 8.0

static var _graph_cache_by_key: Dictionary = {}
static var _route_tree_cache_by_key: Dictionary = {}


static func build_plan(
	definition: RegionMapDefinition,
	agent_id: StringName,
	origin: RegionHexCoord,
	destination: RegionHexCoord,
	start_tick: int,
	deployment_sequence: int
) -> AgentTravelPlan:
	if definition == null or origin == null or destination == null:
		return null
	if origin.key() == destination.key():
		return null
	var destination_hex: RegionHexDefinition = definition.hex_at_offset(
		destination.offset_col,
		destination.offset_row
	)
	if destination_hex == null or not destination_hex.playable:
		return null
	if destination_hex.terrain_type == RegionTerrainType.LAKE:
		return null

	var graph: Dictionary = _build_graph(definition)
	var nodes: Dictionary = graph.get("nodes", {}) as Dictionary
	var adjacency: Dictionary = graph.get("adjacency", {}) as Dictionary
	var goal_keys: Dictionary = {}
	for key: StringName in _corner_keys(destination):
		goal_keys[key] = true
	var route: Dictionary = _route_from_cached_tree(
		definition,
		origin,
		goal_keys,
		adjacency
	)
	var raw_node_keys: Variant = route.get("node_keys", [])
	if not raw_node_keys is Array or (raw_node_keys as Array).is_empty():
		return null
	var node_keys: Array = raw_node_keys as Array
	var segment_minutes: Array = route.get("segment_minutes", []) as Array
	var plan := AgentTravelPlan.new()
	plan.agent_id = agent_id
	plan.origin_hex = origin.duplicate_coord()
	plan.destination_hex = destination.duplicate_coord()
	plan.start_tick = maxi(0, start_tick)
	plan.plan_id = StringName("agent_travel.%s.%04d" % [agent_id, deployment_sequence])
	# The accepted route includes explicit centre-to-boundary and
	# boundary-to-centre connectors. These connectors use the destination/origin
	# terrain pace instead of a tiny fixed duration, so the token visibly walks
	# out of its current hex and into the centre of the destination even at high
	# strategic speeds.
	plan.route_points.append(_map_center(origin))
	plan.cumulative_minutes.append(0.0)
	var elapsed: float = _connector_minutes(definition, origin)
	for index: int in range(node_keys.size()):
		var key := StringName(node_keys[index])
		if not nodes.has(key):
			return null
		plan.route_points.append(nodes[key] as Vector2)
		if index == 0:
			plan.cumulative_minutes.append(elapsed)
		else:
			elapsed += float(segment_minutes[index - 1])
			plan.cumulative_minutes.append(elapsed)
	elapsed += _connector_minutes(definition, destination)
	plan.route_points.append(_map_center(destination))
	plan.cumulative_minutes.append(elapsed)
	plan.arrival_tick = plan.start_tick + maxi(1, ceili(elapsed))
	return plan


static func covered_hexes(
	definition: RegionMapDefinition,
	centre: RegionHexCoord,
	radius: int = 2
) -> Array[RegionHexCoord]:
	var result: Array[RegionHexCoord] = []
	if definition == null or centre == null:
		return result
	for hex: RegionHexDefinition in definition.all_hexes():
		if not hex.playable or hex.coord == null:
			continue
		if _hex_distance(centre, hex.coord) <= radius:
			result.append(hex.coord.duplicate_coord())
	return result


static func map_center(coord: RegionHexCoord) -> Vector2:
	return _map_center(coord)


static func hex_corners(coord: RegionHexCoord) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var centre: Vector2 = _map_center(coord)
	for index: int in range(6):
		var angle: float = deg_to_rad(float(index) * 60.0)
		result.append(centre + Vector2(cos(angle), sin(angle)))
	return result


static func _build_graph(definition: RegionMapDefinition) -> Dictionary:
	var cache_key: StringName = _graph_cache_key(definition)
	if _graph_cache_by_key.has(cache_key):
		return _graph_cache_by_key[cache_key] as Dictionary
	var graph: Dictionary = _compile_graph(definition)
	_graph_cache_by_key[cache_key] = graph
	return graph


static func clear_cached_definition(region_id: StringName) -> void:
	var prefix: String = "%s:" % String(region_id)
	for raw_key: Variant in _graph_cache_by_key.keys():
		if String(raw_key).begins_with(prefix):
			_graph_cache_by_key.erase(raw_key)
	for raw_key: Variant in _route_tree_cache_by_key.keys():
		if String(raw_key).begins_with(prefix):
			_route_tree_cache_by_key.erase(raw_key)


static func debug_navigation_segments(definition: RegionMapDefinition) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if definition == null:
		return result
	var graph: Dictionary = _build_graph(definition)
	var nodes: Dictionary = graph.get("nodes", {}) as Dictionary
	var adjacency: Dictionary = graph.get("adjacency", {}) as Dictionary
	var seen: Dictionary = {}
	for raw_from: Variant in adjacency.keys():
		var from_key := StringName(raw_from)
		for raw_connection: Variant in adjacency[from_key] as Array:
			var connection: Dictionary = raw_connection as Dictionary
			var to_key := StringName(connection.get("to", ""))
			var segment_key: StringName = _segment_key(from_key, to_key)
			if seen.has(segment_key) or not nodes.has(from_key) or not nodes.has(to_key):
				continue
			seen[segment_key] = true
			result.append(PackedVector2Array([
				nodes[from_key] as Vector2,
				nodes[to_key] as Vector2,
			]))
	return result


static func _graph_cache_key(definition: RegionMapDefinition) -> StringName:
	if definition == null:
		return &"missing"
	return StringName("%s:%d:%d:%d:%d" % [
		definition.id,
		definition.hexes_by_key.size(),
		definition.road_edges_by_id.size(),
		definition.width,
		definition.height,
	])


static func _compile_graph(definition: RegionMapDefinition) -> Dictionary:
	var nodes: Dictionary = {}
	var segments: Dictionary = {}
	for hex: RegionHexDefinition in definition.all_hexes():
		if not hex.playable or hex.coord == null:
			continue
		var corners: Array[Vector2] = hex_corners(hex.coord)
		for edge_index: int in range(6):
			var first: Vector2 = corners[edge_index]
			var second: Vector2 = corners[(edge_index + 1) % 6]
			var first_key: StringName = _point_key(first)
			var second_key: StringName = _point_key(second)
			nodes[first_key] = first
			nodes[second_key] = second
			var segment_key: StringName = _segment_key(first_key, second_key)
			var segment: Dictionary = segments.get(segment_key, {
				"first": first_key,
				"second": second_key,
				"terrains": [],
				"road_type": &"",
			}) as Dictionary
			var terrains: Array = segment.get("terrains", []) as Array
			terrains.append(hex.terrain_type)
			segment["terrains"] = terrains
			segments[segment_key] = segment
	for road: RegionMapEdgeDefinition in definition.all_road_edges():
		if road.coord == null or road.edge_index < 0 or road.edge_index > 5:
			continue
		var corners: Array[Vector2] = hex_corners(road.coord)
		var first_key: StringName = _point_key(corners[road.edge_index])
		var second_key: StringName = _point_key(corners[(road.edge_index + 1) % 6])
		var segment_key: StringName = _segment_key(first_key, second_key)
		if segments.has(segment_key):
			var segment: Dictionary = segments[segment_key] as Dictionary
			segment["road_type"] = RegionRoadType.normalize(road.style_id)
			segments[segment_key] = segment
	var adjacency: Dictionary = {}
	for raw_segment: Variant in segments.values():
		var segment: Dictionary = raw_segment as Dictionary
		var terrains: Array = segment.get("terrains", []) as Array
		# Agents stay within the authored region. Exterior perimeter segments are
		# omitted so boundary walking cannot shortcut through off-map space.
		if terrains.size() < 2:
			continue
		var minutes: float = _segment_minutes(
			StringName(segment.get("road_type", "")),
			terrains
		)
		if minutes < 0.0:
			continue
		var first := StringName(segment.get("first", ""))
		var second := StringName(segment.get("second", ""))
		if not adjacency.has(first):
			adjacency[first] = []
		if not adjacency.has(second):
			adjacency[second] = []
		(adjacency[first] as Array).append({"to": second, "minutes": minutes})
		(adjacency[second] as Array).append({"to": first, "minutes": minutes})
	return {"nodes": nodes, "adjacency": adjacency}


static func _route_from_cached_tree(
	definition: RegionMapDefinition,
	origin: RegionHexCoord,
	goal_keys: Dictionary,
	adjacency: Dictionary
) -> Dictionary:
	var tree_key: StringName = StringName(
		"%s:%s" % [_graph_cache_key(definition), origin.key()]
	)
	var tree: Dictionary = _route_tree_cache_by_key.get(tree_key, {}) as Dictionary
	if tree.is_empty():
		tree = _build_shortest_tree(_corner_keys(origin), adjacency)
		_route_tree_cache_by_key[tree_key] = tree
	var distances: Dictionary = tree.get("distances", {}) as Dictionary
	var reached: StringName = &""
	var best_distance: float = INF
	for raw_goal: Variant in goal_keys.keys():
		var goal := StringName(raw_goal)
		var distance: float = float(distances.get(goal, INF))
		if distance < best_distance:
			best_distance = distance
			reached = goal
	if reached.is_empty() or is_inf(best_distance):
		return {}
	return _reconstruct_route(reached, tree)


static func _build_shortest_tree(
	start_keys: Array[StringName],
	adjacency: Dictionary
) -> Dictionary:
	var distances: Dictionary = {}
	var previous: Dictionary = {}
	var previous_minutes: Dictionary = {}
	var heap: Array[Dictionary] = []
	for key: StringName in start_keys:
		if not adjacency.has(key):
			continue
		distances[key] = 0.0
		_heap_push(heap, {"key": key, "distance": 0.0})
	while not heap.is_empty():
		var entry: Dictionary = _heap_pop(heap)
		var current := StringName(entry.get("key", ""))
		var current_distance: float = float(entry.get("distance", INF))
		if current.is_empty():
			continue
		if current_distance > float(distances.get(current, INF)) + 0.0001:
			continue
		var neighbours: Array = adjacency.get(current, []) as Array
		for raw_connection: Variant in neighbours:
			var connection: Dictionary = raw_connection as Dictionary
			var next := StringName(connection.get("to", ""))
			var minutes: float = float(connection.get("minutes", 0.0))
			var candidate: float = current_distance + minutes
			if candidate + 0.0001 >= float(distances.get(next, INF)):
				continue
			distances[next] = candidate
			previous[next] = current
			previous_minutes[next] = minutes
			_heap_push(heap, {"key": next, "distance": candidate})
	return {
		"distances": distances,
		"previous": previous,
		"previous_minutes": previous_minutes,
	}


static func _reconstruct_route(reached: StringName, tree: Dictionary) -> Dictionary:
	var previous: Dictionary = tree.get("previous", {}) as Dictionary
	var previous_minutes: Dictionary = tree.get("previous_minutes", {}) as Dictionary
	var reverse_keys: Array[StringName] = [reached]
	var reverse_minutes: Array[float] = []
	var cursor: StringName = reached
	while previous.has(cursor):
		reverse_minutes.append(float(previous_minutes.get(cursor, 0.0)))
		cursor = StringName(previous[cursor])
		reverse_keys.append(cursor)
	reverse_keys.reverse()
	reverse_minutes.reverse()
	return {
		"node_keys": reverse_keys,
		"segment_minutes": reverse_minutes,
	}


static func _heap_push(heap: Array[Dictionary], entry: Dictionary) -> void:
	heap.append(entry)
	var index: int = heap.size() - 1
	while index > 0:
		var parent: int = floori(float(index - 1) / 2.0)
		if float(heap[parent].get("distance", INF)) <= float(heap[index].get("distance", INF)):
			break
		var swap: Dictionary = heap[parent]
		heap[parent] = heap[index]
		heap[index] = swap
		index = parent


static func _heap_pop(heap: Array[Dictionary]) -> Dictionary:
	if heap.is_empty():
		return {}
	var result: Dictionary = heap[0]
	var tail: Dictionary = heap.pop_back()
	if heap.is_empty():
		return result
	heap[0] = tail
	var index: int = 0
	while true:
		var left: int = index * 2 + 1
		var right: int = left + 1
		var smallest: int = index
		if left < heap.size() and float(heap[left].get("distance", INF)) < float(heap[smallest].get("distance", INF)):
			smallest = left
		if right < heap.size() and float(heap[right].get("distance", INF)) < float(heap[smallest].get("distance", INF)):
			smallest = right
		if smallest == index:
			break
		var swap: Dictionary = heap[index]
		heap[index] = heap[smallest]
		heap[smallest] = swap
		index = smallest
	return result


static func _connector_minutes(
	definition: RegionMapDefinition,
	coord: RegionHexCoord
) -> float:
	if definition == null or coord == null:
		return MIN_CONNECTOR_MINUTES
	var hex_definition: RegionHexDefinition = definition.hex_at_offset(
		coord.offset_col,
		coord.offset_row
	)
	if hex_definition == null:
		return MIN_CONNECTOR_MINUTES
	return maxf(
		MIN_CONNECTOR_MINUTES,
		_terrain_minutes(hex_definition.terrain_type)
	)


static func _segment_minutes(road_type: StringName, terrains: Array) -> float:
	var normalized_road: StringName = &""
	if not road_type.is_empty():
		normalized_road = RegionRoadType.normalize(road_type)
	match normalized_road:
		RegionRoadType.PRIMARY_ROAD:
			return 8.0
		RegionRoadType.LOCAL_ROAD:
			return 12.0
		RegionRoadType.FOREST_TRACK:
			return 18.0
	var best: float = INF
	for raw_terrain: Variant in terrains:
		var value: float = _terrain_minutes(StringName(raw_terrain))
		if value < 0.0:
			continue
		best = minf(best, value)
	if is_inf(best):
		return -1.0
	return best


static func _terrain_minutes(terrain: StringName) -> float:
	match terrain:
		RegionTerrainType.LAKE:
			return -1.0
		RegionTerrainType.FOREST:
			return 30.0
		RegionTerrainType.MARSH:
			return 36.0
		RegionTerrainType.DEEP_FOREST:
			return 45.0
		RegionTerrainType.GRASSLAND, RegionTerrainType.FARMLAND:
			return 20.0
	return 20.0


static func _corner_keys(coord: RegionHexCoord) -> Array[StringName]:
	var result: Array[StringName] = []
	for point: Vector2 in hex_corners(coord):
		result.append(_point_key(point))
	return result


static func _map_center(coord: RegionHexCoord) -> Vector2:
	var vertical_offset: float = 0.5 if coord.offset_col % 2 == 0 else 0.0
	return Vector2(
		float(coord.offset_col) * 1.5,
		(float(coord.offset_row) + vertical_offset) * SQRT_THREE
	)


static func _point_key(point: Vector2) -> StringName:
	return StringName("%d,%d" % [
		roundi(point.x * QUANTIZE_SCALE),
		roundi(point.y * QUANTIZE_SCALE),
	])


static func _segment_key(first: StringName, second: StringName) -> StringName:
	var a: String = String(first)
	var b: String = String(second)
	if b < a:
		var swap: String = a
		a = b
		b = swap
	return StringName("%s|%s" % [a, b])


static func _hex_distance(first: RegionHexCoord, second: RegionHexCoord) -> int:
	var dq: int = first.q - second.q
	var dr: int = first.r - second.r
	var ds: int = (-first.q - first.r) - (-second.q - second.r)
	return maxi(abs(dq), maxi(abs(dr), abs(ds)))
