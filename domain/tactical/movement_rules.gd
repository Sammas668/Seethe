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
        map_definition: TacticalMapDefinition,
        diagonal_steps_already_used: int = 0
) -> MovementPathResult:
    if not map_definition.is_inside(start):
        return MovementPathResult.failed("The unit is outside the tactical map.")
    if not map_definition.is_inside(goal):
        return MovementPathResult.failed("The destination is outside the tactical map.")
    if map_definition.is_blocked(goal):
        return MovementPathResult.failed("The destination is blocked.")
    if start == goal:
        return MovementPathResult.completed([start], 0, 0)

    var starting_parity := diagonal_steps_already_used % 2
    var start_key := _make_key(start, starting_parity)

    var open_set: Array[Vector3i] = [start_key]
    var closed_set: Dictionary = {}
    var came_from: Dictionary = {}
    var g_score: Dictionary = {start_key: 0}
    var f_score: Dictionary = {start_key: _heuristic(start, goal)}

    while not open_set.is_empty():
        var current_key := _pop_lowest(open_set, f_score)
        var current_tile := Vector2i(current_key.x, current_key.y)
        var current_parity := current_key.z

        if current_tile == goal:
            return _build_result(start_key, current_key, came_from, g_score)

        closed_set[current_key] = true

        for direction: Vector2i in ALL_DIRECTIONS:
            var next_tile := current_tile + direction
            if map_definition.is_blocked(next_tile):
                continue

            var diagonal := direction.x != 0 and direction.y != 0
            if diagonal and _diagonal_corner_is_sealed(current_tile, direction, map_definition):
                continue

            var next_parity := current_parity
            var base_cost := 5
            if diagonal:
                base_cost = 5 if current_parity == 0 else 10
                next_parity = 1 - current_parity

            var step_cost := base_cost * map_definition.movement_multiplier(next_tile)
            var next_key := _make_key(next_tile, next_parity)
            var tentative_cost := int(g_score[current_key]) + step_cost
            var known_cost := int(g_score.get(next_key, 1_000_000_000))

            if closed_set.has(next_key) and tentative_cost >= known_cost:
                continue

            if tentative_cost < known_cost:
                came_from[next_key] = current_key
                g_score[next_key] = tentative_cost
                f_score[next_key] = tentative_cost + _heuristic(next_tile, goal)
                if not open_set.has(next_key):
                    open_set.append(next_key)

    return MovementPathResult.failed("No legal path reaches that tile.")


static func calculate_path_cost(
        path: Array[Vector2i],
        map_definition: TacticalMapDefinition,
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
        if map_definition.is_blocked(current):
            return MovementPathResult.failed("The path crosses a blocked tile.")

        var diagonal := delta.x != 0 and delta.y != 0
        if diagonal and _diagonal_corner_is_sealed(previous, delta, map_definition):
            return MovementPathResult.failed("The path cuts through a sealed corner.")

        var base_cost := 5
        if diagonal:
            base_cost = 5 if parity == 0 else 10
            parity = 1 - parity
            diagonal_steps += 1

        cost += base_cost * map_definition.movement_multiplier(current)

    return MovementPathResult.completed(path, cost, diagonal_steps)


static func _make_key(tile: Vector2i, parity: int) -> Vector3i:
    return Vector3i(tile.x, tile.y, parity)


static func _heuristic(from_tile: Vector2i, to_tile: Vector2i) -> int:
    var difference := (to_tile - from_tile).abs()
    return max(difference.x, difference.y) * 5


static func _pop_lowest(open_set: Array[Vector3i], f_score: Dictionary) -> Vector3i:
    var best_index := 0
    var best_score := int(f_score.get(open_set[0], 1_000_000_000))

    for index: int in range(1, open_set.size()):
        var candidate_score := int(f_score.get(open_set[index], 1_000_000_000))
        if candidate_score < best_score:
            best_index = index
            best_score = candidate_score

    var result := open_set[best_index]
    open_set.remove_at(best_index)
    return result


static func _diagonal_corner_is_sealed(
        current_tile: Vector2i,
        direction: Vector2i,
        map_definition: TacticalMapDefinition
) -> bool:
    var horizontal_side := current_tile + Vector2i(direction.x, 0)
    var vertical_side := current_tile + Vector2i(0, direction.y)
    return (
        map_definition.is_blocked(horizontal_side)
        and map_definition.is_blocked(vertical_side)
    )


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
