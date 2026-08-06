class_name MovementReachableFieldJob
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

var origin: Vector2i = Vector2i.ZERO
var starting_parity: int = 0
var maximum_cost_feet: int = 0
var navigation: TacticalNavigationSnapshot
var open_heap: Array = []
var closed_set: Dictionary = {}
var predecessor_by_key: Dictionary = {}
var cost_by_key: Dictionary = {}
var best_key_by_tile: Dictionary = {}
var pathfinding_expansions: int = 0
var processing_slices: int = 0
var complete: bool = false
var invalid: bool = false


func configure(
	start: Vector2i,
	navigation_value: TacticalNavigationSnapshot,
	maximum_cost_feet_value: int,
	diagonal_steps_already_used: int = 0
) -> void:
	origin = start
	navigation = navigation_value
	maximum_cost_feet = maxi(0, maximum_cost_feet_value)
	starting_parity = diagonal_steps_already_used % 2
	open_heap.clear()
	closed_set.clear()
	predecessor_by_key.clear()
	cost_by_key.clear()
	best_key_by_tile.clear()
	pathfinding_expansions = 0
	processing_slices = 0
	complete = false
	invalid = (
		navigation == null
		or not navigation.is_inside(origin)
	)
	if invalid:
		complete = true
		return
	var start_key := Vector3i(origin.x, origin.y, starting_parity)
	cost_by_key[start_key] = 0
	best_key_by_tile[origin] = start_key
	_heap_push(start_key, 0)


func step(deadline_usec: int, maximum_expansions: int = 64) -> bool:
	if complete:
		return true
	processing_slices += 1
	var expansions_this_slice: int = 0
	while not open_heap.is_empty():
		if expansions_this_slice >= maxi(1, maximum_expansions):
			return false
		if Time.get_ticks_usec() >= deadline_usec:
			return false
		var entry: Dictionary = _heap_pop()
		var current_key: Vector3i = entry.get(
			"key", Vector3i(origin.x, origin.y, starting_parity)
		)
		var current_cost: int = int(entry.get("priority", 1_000_000_000))
		if current_cost != int(cost_by_key.get(current_key, 1_000_000_000)):
			continue
		if current_cost > maximum_cost_feet or closed_set.has(current_key):
			continue
		closed_set[current_key] = true
		pathfinding_expansions += 1
		expansions_this_slice += 1
		var current_tile := Vector2i(current_key.x, current_key.y)
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
			if tentative_cost > maximum_cost_feet:
				continue
			var next_key := Vector3i(next_tile.x, next_tile.y, next_parity)
			if tentative_cost >= int(cost_by_key.get(next_key, 1_000_000_000)):
				continue
			cost_by_key[next_key] = tentative_cost
			predecessor_by_key[next_key] = current_key
			closed_set.erase(next_key)
			_heap_push(next_key, tentative_cost)
			var previous_value: Variant = best_key_by_tile.get(next_tile, null)
			if previous_value == null:
				best_key_by_tile[next_tile] = next_key
			else:
				var previous_key: Vector3i = previous_value
				var previous_cost: int = int(
					cost_by_key.get(previous_key, 1_000_000_000)
				)
				if (
					tentative_cost < previous_cost
					or (
						tentative_cost == previous_cost
						and next_key.z < previous_key.z
					)
				):
					best_key_by_tile[next_tile] = next_key
	complete = true
	return true


func result() -> MovementReachableField:
	var field := MovementReachableField.new()
	field.configure(
		origin,
		starting_parity,
		maximum_cost_feet,
		cost_by_key,
		predecessor_by_key,
		best_key_by_tile,
		pathfinding_expansions
	)
	return field


func _heap_push(key: Vector3i, priority: int) -> void:
	open_heap.append({"key": key, "priority": priority})
	var index: int = open_heap.size() - 1
	while index > 0:
		var parent: int = int((index - 1) / 2)
		if not _heap_entry_precedes(open_heap[index], open_heap[parent]):
			break
		var temporary: Variant = open_heap[parent]
		open_heap[parent] = open_heap[index]
		open_heap[index] = temporary
		index = parent


func _heap_pop() -> Dictionary:
	var result_entry: Dictionary = open_heap[0]
	var last: Variant = open_heap.pop_back()
	if open_heap.is_empty():
		return result_entry
	open_heap[0] = last
	var index: int = 0
	while true:
		var left: int = index * 2 + 1
		var right: int = left + 1
		var best: int = index
		if left < open_heap.size() and _heap_entry_precedes(
			open_heap[left], open_heap[best]
		):
			best = left
		if right < open_heap.size() and _heap_entry_precedes(
			open_heap[right], open_heap[best]
		):
			best = right
		if best == index:
			break
		var temporary: Variant = open_heap[index]
		open_heap[index] = open_heap[best]
		open_heap[best] = temporary
		index = best
	return result_entry


func _heap_entry_precedes(a: Dictionary, b: Dictionary) -> bool:
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
