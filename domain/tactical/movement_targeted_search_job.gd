class_name MovementTargetedSearchJob
extends RefCounted

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

const INF_COST: int = 1_000_000_000

var origin: Vector2i = Vector2i.ZERO
var starting_parity: int = 0
var maximum_cost_feet: int = -1
var navigation: TacticalNavigationSnapshot
var goal_tiles: Array[Vector2i] = []
var goal_set: Dictionary = {}

# Hotfix 5f8 keeps the hottest heap entries in parallel typed arrays rather
# than allocating one Dictionary per push/pop operation.
var open_keys: Array[Vector3i] = []
var open_priorities: PackedInt64Array = PackedInt64Array()
var closed_set: Dictionary = {}
var predecessor_by_key: Dictionary = {}
var cost_by_key: Dictionary = {}
var priority_by_key: Dictionary = {}

var pathfinding_expansions: int = 0
var processing_slices: int = 0
var complete: bool = false
var success: bool = false
var invalid: bool = false
var _popped_priority: int = INF_COST
var _result: MovementPathResult


func configure(
		start: Vector2i,
		navigation_value: TacticalNavigationSnapshot,
		goal_tiles_value: Array[Vector2i],
		maximum_cost_feet_value: int = -1,
		diagonal_steps_already_used: int = 0
) -> void:
	origin = start
	navigation = navigation_value
	maximum_cost_feet = maximum_cost_feet_value
	starting_parity = diagonal_steps_already_used % 2
	goal_tiles.clear()
	goal_set.clear()
	open_keys.clear()
	open_priorities = PackedInt64Array()
	closed_set.clear()
	predecessor_by_key.clear()
	cost_by_key.clear()
	priority_by_key.clear()
	pathfinding_expansions = 0
	processing_slices = 0
	complete = false
	success = false
	invalid = navigation == null or not navigation.is_inside(origin)
	_result = null
	if invalid:
		complete = true
		_result = MovementPathResult.failed("The targeted search origin is invalid.")
		return

	for candidate: Vector2i in goal_tiles_value:
		if goal_set.has(candidate):
			continue
		if not navigation.is_inside(candidate):
			continue
		if candidate != origin and navigation.is_blocked(candidate):
			continue
		goal_tiles.append(candidate)
		goal_set[candidate] = true
	goal_tiles.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	if goal_tiles.is_empty():
		complete = true
		_result = MovementPathResult.failed("No legal targeted-search goal is available.")
		return

	var start_key := Vector3i(origin.x, origin.y, starting_parity)
	cost_by_key[start_key] = 0
	var start_priority: int = _heuristic_to_goals(origin)
	priority_by_key[start_key] = start_priority
	_heap_push(start_key, start_priority)


func step(deadline_usec: int, maximum_expansions: int = 1024) -> bool:
	if complete:
		return true
	processing_slices += 1
	var expansions_this_slice: int = 0
	while not open_keys.is_empty():
		if expansions_this_slice >= maxi(1, maximum_expansions):
			return false
		if Time.get_ticks_usec() >= deadline_usec:
			return false

		var current_key: Vector3i = _heap_pop_key()
		var current_priority: int = _popped_priority
		if current_priority != int(priority_by_key.get(current_key, INF_COST)):
			continue
		if closed_set.has(current_key):
			continue
		var current_cost: int = int(cost_by_key.get(current_key, INF_COST))
		if maximum_cost_feet >= 0 and current_cost > maximum_cost_feet:
			continue
		var current_tile := Vector2i(current_key.x, current_key.y)
		if goal_set.has(current_tile):
			_build_success(current_key, current_cost)
			return true

		closed_set[current_key] = true
		pathfinding_expansions += 1
		expansions_this_slice += 1
		var current_parity: int = current_key.z
		for direction: Vector2i in ALL_DIRECTIONS:
			var next_tile: Vector2i = current_tile + direction
			var step_cost: int = MovementRules.movement_step_cost(
				current_tile,
				next_tile,
				navigation,
				current_parity
			)
			if step_cost < 0:
				continue
			var diagonal: bool = direction.x != 0 and direction.y != 0
			var next_parity: int = 1 - current_parity if diagonal else current_parity
			var tentative_cost: int = current_cost + step_cost
			if maximum_cost_feet >= 0 and tentative_cost > maximum_cost_feet:
				continue
			var next_key := Vector3i(next_tile.x, next_tile.y, next_parity)
			if tentative_cost >= int(cost_by_key.get(next_key, INF_COST)):
				continue
			cost_by_key[next_key] = tentative_cost
			predecessor_by_key[next_key] = current_key
			closed_set.erase(next_key)
			var priority: int = tentative_cost + _heuristic_to_goals(next_tile)
			priority_by_key[next_key] = priority
			_heap_push(next_key, priority)

	complete = true
	success = false
	_result = MovementPathResult.failed("No legal path reaches a targeted goal.")
	return true


func result() -> MovementPathResult:
	if _result != null:
		return _result
	return MovementPathResult.failed("The targeted search has not completed.")


func _heuristic_to_goals(tile: Vector2i) -> int:
	var best_steps: int = INF_COST
	for goal: Vector2i in goal_tiles:
		var delta: Vector2i = goal - tile
		var steps: int = maxi(absi(delta.x), absi(delta.y))
		best_steps = mini(best_steps, steps)
	return 0 if best_steps == INF_COST else best_steps * 5


func _build_success(goal_key: Vector3i, total_cost: int) -> void:
	var reversed_tiles: Array[Vector2i] = []
	var current_key: Vector3i = goal_key
	while true:
		reversed_tiles.append(Vector2i(current_key.x, current_key.y))
		if not predecessor_by_key.has(current_key):
			break
		current_key = predecessor_by_key[current_key]
	reversed_tiles.reverse()
	var diagonal_steps: int = 0
	for index: int in range(1, reversed_tiles.size()):
		var delta: Vector2i = reversed_tiles[index] - reversed_tiles[index - 1]
		if delta.x != 0 and delta.y != 0:
			diagonal_steps += 1
	_result = MovementPathResult.completed(reversed_tiles, total_cost, diagonal_steps)
	success = true
	complete = true


func _heap_push(key: Vector3i, priority: int) -> void:
	open_keys.append(key)
	open_priorities.append(priority)
	var index: int = open_keys.size() - 1
	while index > 0:
		var parent: int = int((index - 1) / 2)
		if not _entry_precedes(
			int(open_priorities[index]),
			open_keys[index],
			int(open_priorities[parent]),
			open_keys[parent]
		):
			break
		_swap_heap_entries(index, parent)
		index = parent


func _heap_pop_key() -> Vector3i:
	var result_key: Vector3i = open_keys[0]
	_popped_priority = int(open_priorities[0])
	var last_index: int = open_keys.size() - 1
	var last_key: Vector3i = open_keys[last_index]
	var last_priority: int = int(open_priorities[last_index])
	open_keys.remove_at(last_index)
	open_priorities.remove_at(last_index)
	if open_keys.is_empty():
		return result_key
	open_keys[0] = last_key
	open_priorities[0] = last_priority
	var index: int = 0
	while true:
		var left: int = index * 2 + 1
		var right: int = left + 1
		var best: int = index
		if left < open_keys.size() and _entry_precedes(
			int(open_priorities[left]),
			open_keys[left],
			int(open_priorities[best]),
			open_keys[best]
		):
			best = left
		if right < open_keys.size() and _entry_precedes(
			int(open_priorities[right]),
			open_keys[right],
			int(open_priorities[best]),
			open_keys[best]
		):
			best = right
		if best == index:
			break
		_swap_heap_entries(index, best)
		index = best
	return result_key


func _swap_heap_entries(first: int, second: int) -> void:
	var temporary_key: Vector3i = open_keys[first]
	open_keys[first] = open_keys[second]
	open_keys[second] = temporary_key
	var temporary_priority: int = int(open_priorities[first])
	open_priorities[first] = int(open_priorities[second])
	open_priorities[second] = temporary_priority


func _entry_precedes(
		priority_a: int,
		key_a: Vector3i,
		priority_b: int,
		key_b: Vector3i
) -> bool:
	if priority_a != priority_b:
		return priority_a < priority_b
	if key_a.y != key_b.y:
		return key_a.y < key_b.y
	if key_a.x != key_b.x:
		return key_a.x < key_b.x
	return key_a.z < key_b.z
