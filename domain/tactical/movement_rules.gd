class_name MovementRules
extends RefCounted

const ORTHOGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

const DIAGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]

const ALL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]


static func find_path(
		start: Vector2i,
		goal: Vector2i,
		navigation: TacticalNavigationSnapshot,
		diagonal_steps_already_used: int = 0
) -> MovementPathResult:
	if not navigation.is_inside(start):
		return MovementPathResult.failed("The unit is outside the tactical map.")
	if not navigation.is_inside(goal):
		return MovementPathResult.failed("The destination is outside the tactical map.")
	if navigation.is_blocked(goal):
		return MovementPathResult.failed("The destination is blocked.")
	if start == goal:
		return MovementPathResult.completed([start], 0, 0)

	var starting_parity: int = diagonal_steps_already_used % 2
	var start_key := _make_key(start, starting_parity)
	var open_heap: Array = []
	var closed_set: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_key: 0}
	var f_score: Dictionary = {start_key: _heuristic(start, goal)}
	_heap_push(open_heap, start_key, int(f_score[start_key]))

	while not open_heap.is_empty():
		var entry: Dictionary = _heap_pop(open_heap)
		var current_key: Vector3i = entry.get("key", start_key)
		var current_priority: int = int(entry.get("priority", 1_000_000_000))
		if current_priority != int(f_score.get(current_key, 1_000_000_000)):
			continue
		if closed_set.has(current_key):
			continue
		var current_tile := Vector2i(current_key.x, current_key.y)
		var current_parity: int = current_key.z

		if current_tile == goal:
			return _build_result(start_key, current_key, came_from, g_score)

		closed_set[current_key] = true
		for direction: Vector2i in ALL_DIRECTIONS:
			var next_tile := current_tile + direction
			if navigation.is_blocked(next_tile):
				continue
			var diagonal: bool = direction.x != 0 and direction.y != 0
			if not diagonal and navigation.is_step_blocked(current_tile, next_tile):
				continue
			if diagonal and _diagonal_corner_is_sealed(current_tile, direction, navigation):
				continue

			var next_parity: int = current_parity
			var base_cost: int = 5
			if diagonal:
				base_cost = 5 if current_parity == 0 else 10
				next_parity = 1 - current_parity
			var step_cost: int = (
				base_cost * navigation.movement_multiplier(next_tile)
				+ navigation.additional_step_cost(current_tile, next_tile)
			)
			var next_key := _make_key(next_tile, next_parity)
			var tentative_cost: int = int(g_score[current_key]) + step_cost
			var known_cost: int = int(g_score.get(next_key, 1_000_000_000))
			if tentative_cost >= known_cost:
				continue
			came_from[next_key] = current_key
			g_score[next_key] = tentative_cost
			var priority: int = tentative_cost + _heuristic(next_tile, goal)
			f_score[next_key] = priority
			closed_set.erase(next_key)
			_heap_push(open_heap, next_key, priority)

	return MovementPathResult.failed("No legal path reaches that tile.")


static func build_reachable_field(
		start: Vector2i,
		navigation: TacticalNavigationSnapshot,
		maximum_cost_feet: int,
		diagonal_steps_already_used: int = 0
) -> MovementReachableField:
	var result := MovementReachableField.new()
	var starting_parity: int = diagonal_steps_already_used % 2
	if navigation == null or not navigation.is_inside(start):
		result.configure(
			start, starting_parity, maximum_cost_feet, {}, {}, {}, 0
		)
		return result

	var start_key := _make_key(start, starting_parity)
	var open_heap: Array = []
	var closed_set: Dictionary = {}
	var came_from: Dictionary = {}
	var cost_by_key: Dictionary = {start_key: 0}
	var best_key_by_tile: Dictionary = {start: start_key}
	var expansions: int = 0
	_heap_push(open_heap, start_key, 0)

	while not open_heap.is_empty():
		var entry: Dictionary = _heap_pop(open_heap)
		var current_key: Vector3i = entry.get("key", start_key)
		var current_cost: int = int(entry.get("priority", 1_000_000_000))
		if current_cost != int(cost_by_key.get(current_key, 1_000_000_000)):
			continue
		if current_cost > maximum_cost_feet or closed_set.has(current_key):
			continue
		closed_set[current_key] = true
		expansions += 1
		var current_tile := Vector2i(current_key.x, current_key.y)
		var current_parity: int = current_key.z

		for direction: Vector2i in ALL_DIRECTIONS:
			var next_tile := current_tile + direction
			if navigation.is_blocked(next_tile):
				continue
			var diagonal: bool = direction.x != 0 and direction.y != 0
			if not diagonal and navigation.is_step_blocked(current_tile, next_tile):
				continue
			if diagonal and _diagonal_corner_is_sealed(current_tile, direction, navigation):
				continue
			var next_parity: int = current_parity
			var base_cost: int = 5
			if diagonal:
				base_cost = 5 if current_parity == 0 else 10
				next_parity = 1 - current_parity
			var step_cost: int = (
				base_cost * navigation.movement_multiplier(next_tile)
				+ navigation.additional_step_cost(current_tile, next_tile)
			)
			var tentative_cost: int = current_cost + step_cost
			if tentative_cost > maximum_cost_feet:
				continue
			var next_key := _make_key(next_tile, next_parity)
			if tentative_cost >= int(cost_by_key.get(next_key, 1_000_000_000)):
				continue
			cost_by_key[next_key] = tentative_cost
			came_from[next_key] = current_key
			closed_set.erase(next_key)
			_heap_push(open_heap, next_key, tentative_cost)
			var previous_best: Variant = best_key_by_tile.get(next_tile, null)
			if previous_best == null:
				best_key_by_tile[next_tile] = next_key
			else:
				var previous_key: Vector3i = previous_best
				var previous_cost: int = int(cost_by_key.get(previous_key, 1_000_000_000))
				if (
					tentative_cost < previous_cost
					or (
						tentative_cost == previous_cost
						and next_key.z < previous_key.z
					)
				):
					best_key_by_tile[next_tile] = next_key

	result.configure(
		start,
		starting_parity,
		maximum_cost_feet,
		cost_by_key,
		came_from,
		best_key_by_tile,
		expansions
	)
	return result


static func calculate_path_cost(
		path: Array[Vector2i],
		navigation: TacticalNavigationSnapshot,
		diagonal_steps_already_used: int = 0
) -> MovementPathResult:
	if path.is_empty():
		return MovementPathResult.failed("The path is empty.")

	var cost := 0
	var diagonal_steps := 0
	var parity := diagonal_steps_already_used % 2

	for index: int in range(1, path.size()):
		var previous := path[index - 1]
		var current := path[index]
		var delta := current - previous

		if abs(delta.x) > 1 or abs(delta.y) > 1 or delta == Vector2i.ZERO:
			return MovementPathResult.failed("The path contains a non-adjacent step.")
		if navigation.is_blocked(current):
			return MovementPathResult.failed("The path crosses a blocked tile.")

		var diagonal := delta.x != 0 and delta.y != 0
		if not diagonal and navigation.is_step_blocked(previous, current):
			return MovementPathResult.failed("The path crosses a closed or blocked opening.")
		if diagonal and _diagonal_corner_is_sealed(previous, delta, navigation):
			return MovementPathResult.failed("The path cuts through a sealed corner.")

		var base_cost := 5
		if diagonal:
			base_cost = 5 if parity == 0 else 10
			parity = 1 - parity
			diagonal_steps += 1

		cost += (
			base_cost * navigation.movement_multiplier(current)
			+ navigation.additional_step_cost(previous, current)
		)

	return MovementPathResult.completed(path, cost, diagonal_steps)


static func movement_step_cost(
		previous: Vector2i,
		current: Vector2i,
		navigation: TacticalNavigationSnapshot,
		diagonal_parity: int = 0
) -> int:
	if navigation == null:
		return -1
	var delta: Vector2i = current - previous
	if absi(delta.x) > 1 or absi(delta.y) > 1 or delta == Vector2i.ZERO:
		return -1
	if navigation.is_blocked(current):
		return -1
	var diagonal: bool = delta.x != 0 and delta.y != 0
	if not diagonal and navigation.is_step_blocked(previous, current):
		return -1
	if diagonal and _diagonal_corner_is_sealed(previous, delta, navigation):
		return -1
	var base_cost: int = 5
	if diagonal:
		base_cost = 5 if diagonal_parity % 2 == 0 else 10
	return (
		base_cost * navigation.movement_multiplier(current)
		+ navigation.additional_step_cost(previous, current)
	)


static func _make_key(tile: Vector2i, parity: int) -> Vector3i:
	return Vector3i(tile.x, tile.y, parity)


static func _heuristic(from_tile: Vector2i, to_tile: Vector2i) -> int:
	var difference := (to_tile - from_tile).abs()
	return max(difference.x, difference.y) * 5


static func _heap_push(heap: Array, key: Vector3i, priority: int) -> void:
	heap.append({"key": key, "priority": priority})
	var index: int = heap.size() - 1
	while index > 0:
		var parent: int = int((index - 1) / 2)
		if not _heap_entry_precedes(heap[index], heap[parent]):
			break
		var temporary: Variant = heap[parent]
		heap[parent] = heap[index]
		heap[index] = temporary
		index = parent


static func _heap_pop(heap: Array) -> Dictionary:
	var result: Dictionary = heap[0]
	var last: Variant = heap.pop_back()
	if heap.is_empty():
		return result
	heap[0] = last
	var index: int = 0
	while true:
		var left: int = index * 2 + 1
		var right: int = left + 1
		var best: int = index
		if left < heap.size() and _heap_entry_precedes(heap[left], heap[best]):
			best = left
		if right < heap.size() and _heap_entry_precedes(heap[right], heap[best]):
			best = right
		if best == index:
			break
		var temporary: Variant = heap[index]
		heap[index] = heap[best]
		heap[best] = temporary
		index = best
	return result


static func _heap_entry_precedes(a: Dictionary, b: Dictionary) -> bool:
	var priority_a: int = int(a.get("priority", 1_000_000_000))
	var priority_b: int = int(b.get("priority", 1_000_000_000))
	if priority_a != priority_b:
		return priority_a < priority_b
	var key_a: Vector3i = a.get("key", Vector3i.ZERO)
	var key_b: Vector3i = b.get("key", Vector3i.ZERO)
	if key_a.y != key_b.y:
		return key_a.y < key_b.y
	if key_a.x != key_b.x:
		return key_a.x < key_b.x
	return key_a.z < key_b.z


static func _diagonal_corner_is_sealed(
		current_tile: Vector2i,
		direction: Vector2i,
		navigation: TacticalNavigationSnapshot
) -> bool:
	var horizontal_side := current_tile + Vector2i(direction.x, 0)
	var vertical_side := current_tile + Vector2i(0, direction.y)
	var horizontal_blocked: bool = (
		navigation.is_blocked(horizontal_side)
		or navigation.is_step_blocked(current_tile, horizontal_side)
	)
	var vertical_blocked: bool = (
		navigation.is_blocked(vertical_side)
		or navigation.is_step_blocked(current_tile, vertical_side)
	)
	return horizontal_blocked and vertical_blocked


static func _build_result(
		start_key: Vector3i,
		goal_key: Vector3i,
		came_from: Dictionary,
		g_score: Dictionary
) -> MovementPathResult:
	var reversed_path: Array[Vector2i] = []
	var current_key := goal_key

	while current_key != start_key:
		reversed_path.append(Vector2i(current_key.x, current_key.y))
		if not came_from.has(current_key):
			return MovementPathResult.failed("The generated path could not be reconstructed.")
		current_key = came_from[current_key]

	reversed_path.append(Vector2i(start_key.x, start_key.y))
	reversed_path.reverse()

	var diagonal_steps := 0
	for index: int in range(1, reversed_path.size()):
		var delta := reversed_path[index] - reversed_path[index - 1]
		if delta.x != 0 and delta.y != 0:
			diagonal_steps += 1

	return MovementPathResult.completed(
		reversed_path,
		int(g_score[goal_key]),
		diagonal_steps
	)
