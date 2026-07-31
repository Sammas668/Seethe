class_name TacticalLineOfSightRules
extends RefCounted


static func trace_line(
		start: Vector2i,
		finish: Vector2i
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current: Vector2i = start
	var delta_x: int = absi(finish.x - start.x)
	var step_x: int = 1 if start.x < finish.x else -1
	var delta_y: int = -absi(finish.y - start.y)
	var step_y: int = 1 if start.y < finish.y else -1
	var error: int = delta_x + delta_y

	while true:
		result.append(current)
		if current == finish:
			break
		var doubled_error: int = 2 * error
		if doubled_error >= delta_y:
			error += delta_y
			current.x += step_x
		if doubled_error <= delta_x:
			error += delta_x
			current.y += step_y
	return result


static func first_blocking_tile(
		origin: Vector2i,
		target: Vector2i,
		map_definition: TacticalMapDefinition,
		include_target: bool = false
) -> Vector2i:
	if map_definition == null or origin == target:
		return Vector2i(-1, -1)
	var line: Array[Vector2i] = trace_line(origin, target)
	var final_exclusive: int = line.size() if include_target else maxi(1, line.size() - 1)
	for index: int in range(1, final_exclusive):
		if map_definition.blocks_vision(line[index]):
			return line[index]
	return Vector2i(-1, -1)


static func has_line_of_sight(
		origin: Vector2i,
		target: Vector2i,
		map_definition: TacticalMapDefinition,
		tactical_state: TacticalState = null
) -> bool:
	if map_definition == null:
		return false
	if origin == target:
		return true
	if tactical_state != null:
		return TacticalCombatGeometryQuery.cheap_has_line_of_sight(
			tactical_state,
			map_definition,
			origin,
			target
		)
	return first_blocking_tile(
		origin,
		target,
		map_definition,
		false
	) == Vector2i(-1, -1)
